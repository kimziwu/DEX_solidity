// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


/**
CPMM (xy=k) 방식의 AMM을 사용하는 DEX를 구현

- Swap
Pool 생성 시 지정된 두 종류의 토큰을 서로 교환 가능
수량이 0인 토큰으로 스왑
Input 토큰과 Input 수량, 최소 Output 요구량을 받아서 Output 토큰으로 바꿔주고,
최소 요구량에 미달할 경우 revert 해야함
수수료는 0.1%

    K=XY, fee:0.1%
    x=tokenXAmount, y=tokenYAmount
    X=_tokenX.balanceOf, Y=_tokenY.balanceOf

    ex) x->y swap
    XY=K=(X+x)(Y-y)
    XY-Xy+xY-xy=XY
    y(-X-x)=-xY
    y=xY/X+x
    y=((x*999/1000)*Y)/(X+(x*999/1000))
    
- Add / Remove Liquidity
ERC-20 기반 LP 토큰을 사용
수수료 수입과 Pool에 기부된 금액을 제외하고는 더 많은 토큰을 회수할 수 있는 취약점이 없어야 함
Concentrated Liquidity는 필요 없습니다.

- function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount);
tokenXAmount / tokenYAmount 중 하나는 무조건 0이어야 합니다. 수량이 0인 토큰으로 스왑됨.

- function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount);
- function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external;
- function transfer(address to, uint256 lpAmount) external returns (bool);
*/


import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Dex is ERC20 {
    ERC20 _tokenX;
    ERC20 _tokenY;
    uint _decimal;
    uint liquiditySum; //totalSupply()
    
    mapping(address=>uint) liquidityUser; 

    constructor(address tokenX, address tokenY) ERC20("LPToken","LPT"){
        _tokenX=ERC20(tokenX);
        _tokenY=ERC20(tokenY);
        _decimal=10**18;
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require((tokenXAmount>0 && tokenYAmount==0) || (tokenXAmount==0 && tokenYAmount>0));
        
        uint X=_tokenX.balanceOf(address(this));
        uint Y=_tokenY.balanceOf(address(this));
        require(X>0 && Y>0);

        uint input_amount;
        uint output_amount;
        ERC20 input;
        ERC20 output;


        // swap, fee : 0.1%
        if (tokenXAmount>0){ // swap Y token
            input=_tokenX; 
            output=_tokenY;
            input_amount=tokenXAmount;
            output_amount=Y*(tokenXAmount*999/1000)/(X+(tokenXAmount*999/1000));
            
        }
        else { // swap X token
            input=_tokenY;
            output=_tokenX;
            input_amount=tokenYAmount;
            output_amount=X*(tokenYAmount*999/1000)/(Y+(tokenYAmount*999/1000));
        }

        require(output_amount>=tokenMinimumOutputAmount);
        
        input.transferFrom(msg.sender, address(this), input_amount);
        output.transfer(msg.sender, output_amount);        
        
        return output_amount;
    }


    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        require(tokenXAmount>0 && tokenYAmount>0);
        require(_tokenX.allowance(msg.sender, address(this))>=tokenXAmount,"ERC20: insufficient allowance");
        require(_tokenY.allowance(msg.sender, address(this))>=tokenYAmount,"ERC20: insufficient allowance");
        require(_tokenX.balanceOf(msg.sender)>=tokenXAmount,"ERC20: transfer amount exceeds balance");
        require(_tokenY.balanceOf(msg.sender)>=tokenYAmount,"ERC20: transfer amount exceeds balance");

        uint lpToken; 
        if (liquiditySum==0){
            lpToken=tokenXAmount*tokenYAmount/_decimal;
        }
        else {
            uint X=_tokenX.balanceOf(address(this));
            uint Y=_tokenY.balanceOf(address(this));
            
            uint liquidityX=liquiditySum*tokenXAmount/X;
            uint liquidityY=liquiditySum*tokenYAmount/Y;
            lpToken=(liquidityX<liquidityY)?liquidityX:liquidityY;
        }

        require(lpToken>=minimumLPTokenAmount);

        liquiditySum+=lpToken;
        liquidityUser[msg.sender]+=lpToken;

        _tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        _tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
        transfer(msg.sender, lpToken);
        
        return lpToken;
    }


    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint, uint) {
        require(LPTokenAmount>0);
        require(liquidityUser[msg.sender]>=LPTokenAmount);

        uint tokenXAmount=_tokenX.balanceOf(address(this));
        uint tokenYAmount=_tokenY.balanceOf(address(this));
        uint X=tokenXAmount*LPTokenAmount/liquiditySum;
        uint Y=tokenYAmount*LPTokenAmount/liquiditySum;

        require(X>=minimumTokenXAmount,"less than minimum tokenX");
        require(Y>=minimumTokenYAmount,"less than mininum tokenY");

        liquiditySum-=LPTokenAmount;
        liquidityUser[msg.sender]-=LPTokenAmount;

        _tokenX.transfer(msg.sender, X);
        _tokenY.transfer(msg.sender, Y);
        _burn(msg.sender, LPTokenAmount);

        return (X,Y);
    }

  
    function transfer(address to, uint256 lpAmount) override public returns (bool){
        _mint(to, lpAmount);
        return true;
    }
}