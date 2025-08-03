//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockAggregatorV3Interface.sol";

abstract contract HelperParameters {
    address internal constant SEPOLIA_wETH_USD_PRICEFEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address internal constant SEPOLIA_wBTC_USD_PRICEFEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address internal constant SEPOLIA_wETH     =           0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address internal constant SEPOLIA_wBTC     =           0x29f2D40B0605204364af54EC677bD022dA425d03;
    uint8 internal constant DECIMALS = 18;
    int256 internal constant c_initialAnswerEth = 2000e8;
    int256 internal c_initialAnswerBtc = 100000e8;

    uint256 internal constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
}

contract HelperConfig is Script, HelperParameters {

    struct NetworkConfig {
        address wETH_USD_pricefeed;
        address wBTC_USD_pricefeed;
        address wETH;
        address wBTC;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if(block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory){
        return NetworkConfig({
            wETH_USD_pricefeed: SEPOLIA_wETH_USD_PRICEFEED,
            wBTC_USD_pricefeed: SEPOLIA_wBTC_USD_PRICEFEED,
            wETH: SEPOLIA_wETH,
            wBTC: SEPOLIA_wBTC,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if(activeNetworkConfig.wBTC_USD_pricefeed != address(0)) {
            return activeNetworkConfig;
        }
        
        vm.startBroadcast();

        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            c_initialAnswerEth
        );
        ERC20Mock wETHMockERC20 = new ERC20Mock(
            "WETH",
            "WETH",
            msg.sender,
            1000e8
        );

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            c_initialAnswerBtc
        );
        ERC20Mock wBTCMockERC20 = new ERC20Mock(
            "WBTC",
            "WBTC",
            msg.sender,
            1000e8
        );

        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wETH_USD_pricefeed: address(ethUsdPriceFeed),
            wBTC_USD_pricefeed: address(btcUsdPriceFeed),
            wETH: address(wETHMockERC20),
            wBTC: address(wBTCMockERC20),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}