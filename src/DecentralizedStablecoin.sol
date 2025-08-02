//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/* 
 * Collateral: exogenous
 * Minting: collateral based/ algorithmic
 * Relative stability pegged to USD 
 *
 * this contract is to be governed by DSCEngine. ERC20 implementation on our stablecoin system.
 * 
 */

contract DecentralizedStablecoin is ERC20Burnable, Ownable {

    error amountNotBurnable();
    error InsufficientBalance();

    constructor() ERC20("Decentralized stablecoin", "DSC") Ownable(address(this)){
        
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        require(_amount>=0, amountNotBurnable());
        require(balance>= _amount, InsufficientBalance());
        
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool){
        require(_to != address(0));
        require(_amount>=0);

        _mint(_to, _amount);

        return true;
    }


}