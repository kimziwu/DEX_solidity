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
        
    }

    function addLiquidity(uint256 tokenXAmount, uint256 tokenYAmount, uint256 minimumLPTokenAmount) external returns (uint256 LPTokenAmount){
        
    }

    function removeLiquidity(uint256 LPTokenAmount, uint256 minimumTokenXAmount, uint256 minimumTokenYAmount) external returns (uint, uint) {
        
    }

  

    function transfer(address to, uint256 lpAmount) override public returns (bool){
        _mint(to, lpAmount);
        return true;
    }
}