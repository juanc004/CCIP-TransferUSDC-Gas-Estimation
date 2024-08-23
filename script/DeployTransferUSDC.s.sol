// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";

/// @dev Function of script to deploy TransferUSDC contract
contract DeployTransferUSDC is Script {
    // Addresses of the CCIP router, LINK token, and USDC token on the target network
    address public ccipRouter = 0xF694E193200268f9a4868e4Aa017A0118C9a8177;
    address public linkToken = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846;
    address public usdcToken = 0x5425890298aed601595a70AB815c96711a31Bc65;

    function run() public {
        vm.startBroadcast();
        // Deploy the TransferUSDC contract with the specified addresses
        TransferUSDC transferUsdc = new TransferUSDC(
            ccipRouter,
            linkToken,
            usdcToken
        );

        console.log("Deployed contract at address: ", address(transferUsdc));

        vm.stopBroadcast();
    }
}
