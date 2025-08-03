//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployStablecoin} from "../../script/DeployStablecoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract StablecoinTest is Test {

    DecentralizedStablecoin stablecoin;
    DSCEngine engine;

    DeployStablecoin deployer;
    HelperConfig config;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address private owner;
    address private USER = makeAddr("user");
    uint256 private constant AMOUNT = 1 ether;
    uint256 private constant BALANCE = 5 ether;
    address private depositToken;
    uint256 private constant VALID_AMOUNT = 10;

    
    function setUp() public{
        deployer = new DeployStablecoin();

        (stablecoin, engine, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = config.activeNetworkConfig();

        owner = address(engine);
    }
    /////////////////////////
    // ERC20 test        ////
    /////////////////////////

    function testNonzeroAmountIsBurned() external {
        vm.prank(address(engine));
        vm.expectRevert();
        stablecoin.burn(0);
    }

    function testBurnerHasValidBalance() external {
        vm.deal(owner, AMOUNT - 1);
        vm.prank(owner);
        vm.expectRevert();
        stablecoin.burn(AMOUNT);
    }

    function testAmountIsBurnt() external {
        vm.deal(owner, BALANCE);
        vm.prank(owner);
        
    }

    /////////////////////////
    // Price test        ////
    /////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 2000*ethAmount;

        uint256 actualUsd = engine.getUSDValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    /////////////////////////////////////
    // depositCollateral test        ////
    /////////////////////////////////////

    function testRevertsIfCollateralIsZero() external {
        vm.prank(USER);
        // ERC20Mock(weth).approve(address(engine), VALID_AMOUNT);
        vm.expectRevert();
        engine.depositCollateral(weth, 0);
    }

    function testAcceptedTokenIsDepositedAsCollateral() external {
        vm.prank(USER);
        engine.depositCollateral(depositToken, VALID_AMOUNT);
    }

}