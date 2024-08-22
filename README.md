# Day #3 Homework: Cross-Chain USDC Transfer and Gas Estimation Test
This repository contains a test suite designed to estimate gas usage for the `transferUsdc` function within the `TransferUSDC` contract. The goal is to measure the gas used during a cross-chain transfer, apply a 10% buffer to the gas limit, and verify that the transaction executes successfully with the adjusted gas limit.

## Cloning the Repository

To get started, clone the repository to your local machine:

```bash
git clone https://github.com/yourusername/cross-chain-usdc-gas-estimation.git
cd cross-chain-usdc-gas-estimation

```

## Running the Test

This test suite is built using Foundry, a smart contract testing framework. Ensure you have Foundry installed on your machine. If not, you can install it by following the instructions on the [Foundry GitHub page](https://github.com/foundry-rs/foundry).

To run the test, use the following command:

```bash
make test

```

## Solution Overview

The test suite focuses on measuring the gas consumption of the `transferUsdc` function from the `TransferUSDC` contract, which is responsible for initiating cross-chain USDC transfers using Chainlink's CCIP protocol. It also involves the `CrossChainReceiver` contract, which handles the received messages and processes the USDC transfer on the destination chain.

### Steps in the Test

1. **Measure the Gas Consumption**:
    - The test measures the gas used by the `transferUsdc` function when sending USDC across chains.
2. **Calculate and Apply a 10% Buffer**:
    - A 10% buffer is added to the measured gas to calculate a new gas limit, ensuring the transaction has enough gas to succeed even if gas usage fluctuates.
3. **Validate with Adjusted Gas Limit**:
    - The function is re-executed with the adjusted gas limit to confirm that the buffer is sufficient and the transaction completes successfully.

### Example Terminal Output

When you run the test, you should see output similar to this:

```
❯ forge test 
[⠊] Compiling...
[⠢] Compiling 1 files with Solc 0.8.20
[⠆] Solc 0.8.20 finished in 3.22s
Compiler run successful!

Ran 1 test for test/Test.t.sol:Test1
[PASS] test_CalculateAndApplyGasLimit() (gas: 833226)
Logs:

----- Start Gas Estimation -----

  Measured gas used: 307950
  Calculated gas limit with 10% buffer: 338745

----- Applying Adjusted Gas Limit -----

  Final gas used with adjusted gas limit: 282050

----- End of Gas Estimation -----

```

### Explanation of Solution and Output

| Step | Description | Output Example |
| --- | --- | --- |
| **Measured Gas Used** | The gas used during the execution of the `transferUsdc` function is measured. | `Measured gas used: 307950` |
| **Calculated Gas Limit with Buffer** | A 10% buffer is added to the measured gas to calculate a new gas limit. | `Calculated gas limit with 10% buffer: 338745` |
| **Final Gas Used with Adjusted Limit** | The transaction is re-run using the adjusted gas limit to verify correctness. | `Final gas used with adjusted gas limit: 282050` |

### Explanation

1. **Measured Gas Used**: This value (`307950` gas units) represents the gas consumed by the `transferUsdc` function when executing a cross-chain USDC transfer.
2. **Calculated Gas Limit with Buffer**: The test applies a 10% buffer to the measured gas to calculate a new gas limit (`338745` gas units). This ensures that the transaction will have sufficient gas even if the gas requirements increase slightly under different conditions.
3. **Final Gas Used with Adjusted Limit**: The `transferUsdc` function is executed again with the adjusted gas limit to confirm that the transaction completes successfully. The final gas used (`282050` gas units) is less than the adjusted limit, confirming that the buffer was sufficient.

This testing approach ensures that the `transferUsdc` function in the `TransferUSDC` contract will not run out of gas during execution, thereby preventing transaction failures due to insufficient gas.