//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";

contract DeployStablecoin is Script {
    function run() external returns (DecentralizedStablecoin){
        vm.startBroadcast();
        DecentralizedStablecoin stablecoin = new DecentralizedStablecoin();
        vm.stopBroadcast();

        return stablecoin;
    }
}