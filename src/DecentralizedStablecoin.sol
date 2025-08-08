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
 * @dev ERC20Burnable is an extension contract for ERC20 that allows users to destroy tokens (owned and 
 * the one for which they have allowance)
 */

contract DecentralizedStablecoin is ERC20Burnable, Ownable {

    error amountNotBurnable();
    error InsufficientBalance();

    constructor() ERC20("Decentralized stablecoin", "DSC") Ownable(msg.sender){
        
    }
    /**
     * @dev mint function returns bool to match the behaviour of transfer and transferFrom (creates a _amount number 
     * of tokens and transfers it from address(0)), while the burn function does return bool because it follows the 
     * OpenZeppelin convention where internal or trust-required actions just revert instead of returning false.
     */

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        require(_amount>0, amountNotBurnable());
        require(balance>= _amount, InsufficientBalance());
        
        super.burn(_amount);

        // return true;
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool){
        require(_to != address(0));
        require(_amount>=0);

        _mint(_to, _amount);

        return true;
    }


}