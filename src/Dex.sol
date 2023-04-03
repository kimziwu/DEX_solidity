// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";


contract Dex is ERC20 {
    
    ERC20 _tokenX;
    ERC20 _tokenY;
    ERC20 _lp;

    uint liquiditySum; //totalSupply
    mapping(address=>uint) liquidityUser; 

    event Swap(address indexed trader, uint indexed amountX, uint indexed amountY);
    event AddLiquidity(address indexed provider, uint indexed amountX, uint indexed amountY);
    event RemoveLiquidity(address indexed provider, uint indexed amountX, uint indexed amountY);
    
    constructor(address tokenX, address tokenY) ERC20("LPToken","LP"){
        _tokenX = ERC20(tokenX);
        _tokenY = ERC20(tokenY);
        _lp = ERC20(address(this));
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require((tokenXAmount > 0 && tokenYAmount == 0) || (tokenXAmount == 0 && tokenYAmount > 0));
        
        uint reserveX;
        uint reserveY;
        (reserveX, reserveY) = update();
        
        require(reserveX > 0 && reserveY > 0);

        uint input_amount;
        uint output_amount;
        ERC20 input;
        ERC20 output;
        uint fee; 

        if (tokenXAmount>0){  // x->y swap
            input = _tokenX; 
            output = _tokenY;
            input_amount = tokenXAmount;

            // fee = 0.1%
            fee = SafeMath.div(SafeMath.mul(input_amount, 999),1000);
            output_amount = SafeMath.div(SafeMath.mul(reserveY, fee), SafeMath.add(reserveX, fee));
        }
        else {  // y->x swap
            input=_tokenY;
            output=_tokenX;
            input_amount=tokenYAmount;

            // fee = 0.1%
            fee = SafeMath.div(SafeMath.mul(input_amount, 999),1000);
            output_amount = SafeMath.div(SafeMath.mul(reserveX, fee), SafeMath.add(reserveY, fee));
        }

        require(output_amount>=tokenMinimumOutputAmount);

        input.transferFrom(msg.sender, address(this), input_amount); //전송
        output.transfer(msg.sender, output_amount);                  //수신   

        update();
        emit Swap(msg.sender, input_amount, output_amount);
        
        return output_amount;
    }

    
    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        require(tokenXAmount > 0 && tokenYAmount > 0);
        require(_tokenX.allowance(msg.sender, address(this)) >= tokenXAmount, "ERC20: insufficient allowance");
        require(_tokenY.allowance(msg.sender, address(this)) >= tokenYAmount, "ERC20: insufficient allowance");
        require(_tokenX.balanceOf(msg.sender) >= tokenXAmount, "ERC20: transfer amount exceeds balance");
        require(_tokenY.balanceOf(msg.sender) >= tokenYAmount, "ERC20: transfer amount exceeds balance");

        uint lpToken; 
        uint reserveX;
        uint reserveY;

        if (liquiditySum == 0){ // 초기 예치
            lpToken = Math.sqrt(tokenXAmount * tokenYAmount); //initial token amount
        }
        else { // 가격에 비례하는 토큰 예치
            (reserveX, reserveY) = update();

            // 기존 토큰에 대한 새 토큰의 비율로 계산
            uint liquidityX = SafeMath.div(SafeMath.mul(liquiditySum, tokenXAmount), reserveX);
            uint liquidityY = SafeMath.div(SafeMath.mul(liquiditySum, tokenYAmount), reserveY);
            
            lpToken = (liquidityX < liquidityY) ? liquidityX : liquidityY;
        }

        // tokenXAmount : tokenYAmount == reserveX : reserveY, 유동성 비율 체크
        require(tokenXAmount * reserveY == tokenYAmount * reserveX);
        require(lpToken >= minimumLPTokenAmount);

        liquiditySum += lpToken;
        liquidityUser[msg.sender] += lpToken;

        _tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        _tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
        
        update();

        _mint(msg.sender, lpToken);

        emit AddLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        return lpToken;
    }


    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint, uint) {
        require(LPTokenAmount > 0);
        require(liquidityUser[msg.sender] >= LPTokenAmount);

        uint tokenXAmount;
        uint tokenYAmount;
        (tokenXAmount,tokenYAmount) = update();
  
        //소각된 토큰에 비례
        uint X = SafeMath.div(SafeMath.mul(tokenXAmount, LPTokenAmount), liquiditySum);
        uint Y = SafeMath.div(SafeMath.mul(tokenYAmount, LPTokenAmount), liquiditySum);

        require(X >= minimumTokenXAmount,"less than minimum tokenX");
        require(Y >= minimumTokenYAmount,"less than mininum tokenY");

        liquiditySum -= LPTokenAmount;
        liquidityUser[msg.sender] -= LPTokenAmount;

        _tokenX.transfer(msg.sender, X);
        _tokenY.transfer(msg.sender, Y);
        _burn(msg.sender, LPTokenAmount);

        update();
        emit RemoveLiquidity(msg.sender, tokenXAmount, tokenYAmount);
        return (X,Y);
    }

  
    function transfer(address to, uint256 lpAmount) override public returns (bool){
        return true;
    }


    function update() internal view returns (uint, uint){
        uint tokenXAmount=_tokenX.balanceOf(address(this));
        uint tokenYAmount=_tokenY.balanceOf(address(this));

        return (tokenXAmount,tokenYAmount);
    }
}