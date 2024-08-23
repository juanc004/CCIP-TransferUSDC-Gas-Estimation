// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console, Vm} from "forge-std/Test.sol";
import {MockCCIPRouter} from "@chainlink/contracts-ccip/src/v0.8/ccip/test/mocks/MockRouter.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {TransferUSDC} from "../src/TransferUSDC.sol";
import {CrossChainReceiver} from "../src/CrossChainReceiver.sol";
import {BurnMintERC677} from "@chainlink/contracts-ccip/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";


/**
 * @title GasEstimationTest
 * @dev This test suite evaluates gas consumption during a cross-chain USDC transfer and applies a buffer to ensure successful execution.
 */
contract GasEstimationTest is Test {
    // Contracts used in the test suite
    TransferUSDC public transferUSDC;
    CrossChainReceiver public crossChainReceiver;

    // Tokens used in the test suite
    BurnMintERC677 public link;
    BurnMintERC677 public usdcToken;
    MockCCIPRouter public router;

    // Addresses used in the test suite
    address public cometAddress;
    address public swapTestnetUsdcAddress;

    // Chain selector used in the test suite
    uint64 public chainSelector = 16015286601757825753;

    /**
     * @dev Sets up the test environment by deploying and configuring necessary contracts.
     * This includes deploying the mock router and tokens, as well as setting up the TransferUSDC and CrossChainReceiver contracts.
     */
    function setUp() public {
        // Deploy the mock router and tokens
        router = new MockCCIPRouter();
        link = new BurnMintERC677("ChainLink Token", "LINK", 18, 10 ** 27);
        usdcToken = new BurnMintERC677("USDC Token", "USDC", 6, 10 ** 12);

        usdcToken.grantMintRole(address(this));

        // Deploy the CrossChainReceiver and TransferUSDC contracts
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

        // Mint USDC tokens to this contract and approve them for the transferUSDC contract
        usdcToken.mint(address(this), 10000000);
        usdcToken.approve(address(transferUSDC), 10000000);

        // Allowlist the destination chain and sender contracts
        transferUSDC.allowlistDestinationChain(chainSelector, true);
        crossChainReceiver.allowlistSourceChain(chainSelector, true);
        crossChainReceiver.allowlistSender(address(transferUSDC), true);
    }

    /**
     * @dev Sends a cross-chain message and records the gas usage from the logs.
     * @param iterations The number of iterations to perform in the test message.
     * @param gasLimit The gas limit to use for the message.
     * @return The amount of gas used in the transaction.
     */
    function sendMessage(uint256 iterations, uint64 gasLimit) private returns (uint256) {
        vm.recordLogs();  // Start recording logs to capture gas usage

        // Execute the USDC transfer across chains
        transferUSDC.transferUsdc(
            chainSelector,
            address(crossChainReceiver),
            1e6,    // Transfer 1 USDC token
            gasLimit,
            iterations
        );

        // Retrieve the recorded logs and gas used
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

    /**
     * @dev Measures gas usage, calculates a 10% buffer, and re-runs the function with the new gas limit.
     * This test first measures the gas used by the USDC transfer, then adds a 10% buffer to the gas limit,
     * and finally re-runs the transfer with the adjusted gas limit to ensure it completes successfully.
     */
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
