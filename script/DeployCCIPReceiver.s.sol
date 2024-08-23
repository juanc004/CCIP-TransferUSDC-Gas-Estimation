// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";

/// @dev Function of script to deploy CrossChainReceiver contract
contract DeployCCIPReceiver is Script {
    // Addresses for the CCIP router, Comet protocol, and SwapTestnetUSDC contract on the target network
    address public ccipRouterAddress = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;
    address public cometAddress = 0xAec1F48e02Cfb822Be958B68C7957156EB3F0b6e;
    address public swapTestnetUsdcAddress = 0x19F07D51e4847e28753cBa4B5AA43AD8f5cE99dc;

    function run() public {
        vm.startBroadcast();
        // Deploy the CrossChainReceiver contract with the specified addresses
        CrossChainReceiver crossChainReceiver = new CrossChainReceiver(
            ccipRouterAddress,
            cometAddress,
            swapTestnetUsdcAddress
        );

        console.log("Deployed contract at address: ", address(crossChainReceiver));

        vm.stopBroadcast();
    }
}
