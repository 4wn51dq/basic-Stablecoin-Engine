//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "../lib/forge-std/src/Script.sol";
import {DecentralizedStablecoin} from "../src/DecentralizedStablecoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

contract DeployStablecoin is Script {
    function run() external returns (DecentralizedStablecoin, DSCEngine){
        
        vm.startBroadcast();

        DecentralizedStablecoin stablecoin = new DecentralizedStablecoin();
        DSCEngine engine = new DSCEngine(
            ,
            ,
            address(dsc)
        );

        vm.stopBroadcast();

        return stablecoin;
    }
}