//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DeployStablecoin} from "../script/DeployStablecoin.s.sol";

contract StablecoinTest is Test {

    DecentralizedStablecoin stablecoin;

    address private USER = makeAddr("user");
    uint256 private constant AMOUNT = 1 ether;
    uint256 private constant BALANCE = 5 ether;

    
    function setUp() public{
        DeployStablecoin deployer = new DeployStablecoin();

        stablecoin = deployer.run();
    }

    function testNonzeroAmountIsBurned() external {
        vm.prank(USER);
        vm.expectRevert();
        stablecoin.burn(0);
    }

    function testBurnerHasValidBalance() external {
        vm.deal(USER, AMOUNT - 1);
        vm.prank(USER);
        vm.expectRevert();
        stablecoin.burn(AMOUNT);
    }

    function testAmountIsBurnt() external {
        vm.deal(USER, BALANCE);
        vm.prank(USER);
        
    }
}