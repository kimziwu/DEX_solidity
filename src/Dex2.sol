// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Dex is ERC20 {

    ERC20 public _tokenX;
    ERC20 public _tokenY;
    ERC20 public _tokenLP;
    uint public _demical;
    uint public liquiditySum; //totalSupply()?
    
    mapping(address=>uint) public liquidityUser; //balanceOf() ?

    constructor(address tokenX, address tokenY) ERC20("LPToken","LPT"){
        _tokenX=ERC20(tokenX);
        _tokenY=ERC20(tokenY);
        _tokenLP=ERC20(address(this));

        _demical=10**18;
    }

    function swap(uint256 tokenXAmount, uint256 tokenYAmount, uint256 tokenMinimumOutputAmount) external returns (uint256 outputAmount){
        require((tokenXAmount>0 && tokenYAmount==0) || (tokenXAmount==0 && tokenYAmount>0));
        
        uint X=_tokenX.balanceOf(address(this));
        uint Y=_tokenY.balanceOf(address(this));

        console.log("X,Y",X, Y);
        require(X>0 && Y>0 , "no swap amount");


        uint input_amount;
        uint output_amount;
        ERC20 input;
        ERC20 output;


        // swap 
        // fee : 0.1%
        if (tokenXAmount>0){ // want X token
            input=_tokenX;
            output=_tokenY;
            input_amount=tokenXAmount;
            output_amount=Y*(tokenXAmount*999/1000)/(X+(tokenXAmount*999/1000));
            //console.log("amount:",amount);
        }
        else { // want Y token
            input=_tokenY;
            output=_tokenX;
            input_amount=tokenYAmount;
            output_amount=X*(tokenYAmount*999/1000)/(Y+(tokenYAmount*999/1000));
        }

        require(output_amount>=tokenMinimumOutputAmount,"");
        
        input.transferFrom(msg.sender, address(this), input_amount);
        output.transfer(msg.sender, output_amount);        
        
        return output_amount;
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        require(tokenXAmount>0 && tokenYAmount>0, "amount > 0");
        require(_tokenX.allowance(msg.sender, address(this))>=tokenXAmount,"ERC20: insufficient allowance");
        require(_tokenY.allowance(msg.sender, address(this))>=tokenYAmount,"ERC20: insufficient allowance");
        require(_tokenX.balanceOf(msg.sender)>=tokenXAmount,"ERC20: transfer amount exceeds balance");
        require(_tokenY.balanceOf(msg.sender)>=tokenYAmount,"ERC20: transfer amount exceeds balance");

        uint lpToken; 
        if (liquiditySum==0){
            lpToken=tokenXAmount*tokenYAmount/_demical;
        }
        else {
            uint X=_tokenX.balanceOf(address(this));
            uint Y=_tokenY.balanceOf(address(this));

            uint liquidityX=liquiditySum*tokenXAmount/X;
            uint liquidityY=liquiditySum*tokenYAmount/Y;
            lpToken=(liquidityX<liquidityY)?liquidityX:liquidityY;
        }

        require(lpToken>=minimumLPTokenAmount,"minimum lpToken");
        liquiditySum+=lpToken;
        liquidityUser[msg.sender]+=lpToken;

        _tokenX.transferFrom(msg.sender, address(this), tokenXAmount);
        _tokenY.transferFrom(msg.sender, address(this), tokenYAmount);
        transfer(msg.sender, lpToken);
        
        return lpToken;
    }

    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint, uint) {
        require(LPTokenAmount>0,"amount>0");
        require(liquidityUser[msg.sender]>=LPTokenAmount,"more than liquidity");

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

    // math function
}