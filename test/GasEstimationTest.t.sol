// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
import {BurnMintERC677} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";

/// @title A test suite for Sender and Receiver contracts to estimate ccipReceive gas usage.
contract Test1 is Test {
    // Declaration of contracts used in the tests
    TransferUSDC public transferUSDC;
    CrossChainReceiver public crossChainReceiver;
    BurnMintERC677 public link;
    BurnMintERC677 public usdcToken;
    MockCCIPRouter public router;
    address public cometAddress;
    address public swapTestnetUsdcAddress;
    uint64 public chainSelector = 16015286601757825753;

    /// @dev Sets up the environment by deploying and configuring contracts.
    function setUp() public {
        router = new MockCCIPRouter();
        link = new BurnMintERC677("ChainLink Token", "LINK", 18, 10 ** 27);
        usdcToken = new BurnMintERC677("USDC Token", "USDC", 6, 10 ** 12);

        usdcToken.grantMintRole(address(this));

        crossChainReceiver = new CrossChainReceiver(
            address(router),
            cometAddress,
            swapTestnetUsdcAddress
        );
       
        transferUSDC = new TransferUSDC(
            address(router),
            address(link),
            address(usdcToken)
        );

        usdcToken.mint(address(this), 10000000);
        usdcToken.approve(address(transferUSDC), 10000000);

        transferUSDC.allowlistDestinationChain(chainSelector, true);
        crossChainReceiver.allowlistSourceChain(chainSelector, true);
        crossChainReceiver.allowlistSender(address(transferUSDC), true);
    }

    /// @dev Sends a message and records gas usage from logs.
    function sendMessage(uint256 iterations, uint64 gasLimit) private returns (uint256) {
        vm.recordLogs();  // Start recording logs to capture gas usage
        transferUSDC.transferUsdc(
            chainSelector,
            address(crossChainReceiver),
            1e6,
            gasLimit,
            iterations
        );

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 msgExecutedSignature = keccak256("MsgExecuted(bool,bytes,uint256)");

        uint256 gasUsed = 0;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == msgExecutedSignature) {
                (, , gasUsed) = abi.decode(logs[i].data, (bool, bytes, uint256));
            }
        }

        return gasUsed;
    }

    /// @dev Measures gas used, applies a 10% buffer, and runs the function with the new limit.
    function test_CalculateAndApplyGasLimit() public {
        console.log("\n----- Start Gas Estimation -----\n");

        // Step 1: Measure gas used with initial gas limit
        uint256 gasUsed = sendMessage(50, 500_000);
        console.log("Measured gas used:", gasUsed);

        // Step 2: Calculate the new gas limit by adding a 10% buffer
        uint256 gasLimitWithBuffer = gasUsed + (gasUsed / 10);
        console.log("Calculated gas limit with 10% buffer:", gasLimitWithBuffer);

        console.log("\n----- Applying Adjusted Gas Limit -----\n");

        // Step 3: Run the transfer again with the adjusted gas limit
        uint256 finalGasUsed = sendMessage(50, uint64(gasLimitWithBuffer));
        console.log("Final gas used with adjusted gas limit:", finalGasUsed);

        console.log("\n----- End of Gas Estimation -----\n");
    }
}
