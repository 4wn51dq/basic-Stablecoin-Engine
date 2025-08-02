//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockAggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/MockAggregatorV3Interface.sol";

abstract contract HelperParameters {
    address internal constant SEPOLIA_wETH_USD_PRICEFEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address internal constant SEPOLIA_wBTC_USD_PRICEFEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address internal constant SEPOLIA_wETH     =           0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address internal constant SEPOLIA_wBTC     =           0x29f2D40B0605204364af54EC677bD022dA425d03;
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

    constructor() {}

    function getSepoliaEthConfig() public view returns (NetworkConfig memory){
        return NetworkConfig({
            wETH_USD_pricefeed: SEPOLIA_wETH_USD_PRICEFEED,
            wBTC_USD_pricefeed: SEPOLIA_wBTC_USD_PRICEFEED,
            wETH: SEPOLIA_wETH,
            wBTC: SEPOLIA_wBTC,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public view returns (NetworkConfig memory) {
        if(activeNetworkConfig.wBTC_USD_pricefeed != address(0)) {
            return activeNetworkConfig;
        }
        
        vm.startBroadcast();
        MockAggregatorV3Interface mockAggregator = new MockAggregatorV3Interface();
        ERC20Mock mockERC = new ERC20Mock();
        vm.stopBroadcast();
    }
}