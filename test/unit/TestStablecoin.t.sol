//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {DecentralizedStablecoin} from "../../src/DecentralizedStablecoin.sol";
import {DeployStablecoin} from "../../script/DeployStablecoin.s.sol";
import {DSCEngine, EngineErrors} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";



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
    uint256 private constant INITIAL_SUPPLY = 1000 ether;
    uint256 private constant BURN_AMOUNT = 200 ether;
    uint256 private constant STARTING_ERC20_BALANCE = 100 ether;

    
    function setUp() public{
        deployer = new DeployStablecoin();

        (stablecoin, engine, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc, ) = config.activeNetworkConfig();

        // stablecoin.transferOwnership(owner);

        vm.deal(USER, AMOUNT);
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);

        // stablecoin.mint(owner, INITIAL_SUPPLY);
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

    /* 
    function testAmountIsBurntAndRemovedFromSupply() public {
        uint256 balanceBefore = stablecoin.balanceOf(owner);
        uint256 initialSupply = stablecoin.totalSupply();

        

        vm.prank(owner);
        stablecoin.burn(BURN_AMOUNT);

        uint256 balanceAfter = stablecoin.balanceOf(owner);
        uint256 finalSupply = stablecoin.totalSupply();

        assertEq(balanceBefore-BURN_AMOUNT, balanceAfter);
        assertEq(initialSupply-BURN_AMOUNT, finalSupply);
    } 
    */



    /////////////////////////
    // Price test        ////
    /////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 2000*ethAmount;

        uint256 actualUsd = engine.getUSDValue(weth, ethAmount);

        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUSD() public view {
        uint256 usdAmount = 100 ether; // (100*1e18)
        uint256 expectedWeth = 0.05 ether;

        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////////////
    // depositCollateral test        ////
    /////////////////////////////////////

    function testRevertsIfCollateralIsZero() external {
        vm.startPrank(USER);
        // ERC20Mock(weth).approve(address(engine), VALID_AMOUNT);
        vm.expectRevert(EngineErrors.DSCEngine__NonZeroAmountRequired.selector);
        // ERC20Mock(weth).approve(address(engine), VALID_AMOUNT);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapporovedToken() external {
        ERC20Mock dihToken = new ERC20Mock("dihToken", "DIH", USER, STARTING_ERC20_BALANCE);
        vm.startPrank(USER);
        vm.expectRevert(EngineErrors.DSCEngine__noPriceFeedForTheToken.selector);
        engine.depositCollateral(address(dihToken), STARTING_ERC20_BALANCE);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), STARTING_ERC20_BALANCE);
        engine.depositCollateral(weth, STARTING_ERC20_BALANCE);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInformation() external depositedCollateral{
        (uint256 totalDscMinted, uint256 collateralValueInUSD) = engine.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedColateralValueInUsd = engine.getTokenAmountFromUsd(weth, collateralValueInUSD);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(collateralValueInUSD, expectedColateralValueInUsd);
    }

    

    function testUserCanActuallyDepositCollateral() external {
        vm.startPrank(USER);
        // ERC20Mock(weth).approve(address(engine), VALID_AMOUNT);
        // vm.expectRevert(EngineErrors.DSCEngine__NonZeroAmountRequired.selector);
        ERC20Mock(weth).approve(address(engine), VALID_AMOUNT);
        engine.depositCollateral(weth, VALID_AMOUNT);
        vm.stopPrank();
    }

    function testAcceptedTokenIsDepositedAsCollateral() external {
        vm.prank(USER);
        vm.expectRevert(EngineErrors.DSCEngine__noPriceFeedForTheToken.selector);
        engine.depositCollateral(address(10), VALID_AMOUNT);
    }

    /////////////////////////////////////
    // Constructor test //////       ////
    /////////////////////////////////////

    address[] public tokenAddresses;
    address[] public tokenPriceFeeds;

    function testTokensAndPriceFeedAddressesAreMatched() public {
        tokenAddresses.push(weth);
        // tokenAddresses.push(wbtc);
        tokenPriceFeeds.push(wethUsdPriceFeed);
        tokenPriceFeeds.push(wbtcUsdPriceFeed);

        vm.expectRevert(EngineErrors.DSCEngine__tokensAndPriceFeedsAreNotMatched.selector);
        new DSCEngine(tokenAddresses, tokenPriceFeeds, address(stablecoin));
    }
}