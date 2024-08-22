// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {SwapTestnetUSDC} from "../src/SwapTestnetUSDC.sol";

contract DeploySwapTestnetUSDC is Script {
    address public usdcToken = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public fauceteer = 0x68793eA49297eB75DFB4610B68e076D2A5c7646C;
    address public compoundUsdcToken =
        0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() public {
        vm.startBroadcast();
        SwapTestnetUSDC swapTestnetUSDC = new SwapTestnetUSDC(
            usdcToken,
            compoundUsdcToken,
            fauceteer
        );

        console.log("Deployed contract at address: ", address(swapTestnetUSDC));

        vm.stopBroadcast();
    }
}
