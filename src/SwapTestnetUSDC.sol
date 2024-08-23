// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IFauceteer {
    function drip(address token) external;
}

/**
 * @title SwapTestnetUSDC
 * @dev Example contract for swapping USDC and Compound USDC on a testnet.
 *      Not audited; not for production use.
 */
contract SwapTestnetUSDC is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Addresses of USDC and Compound USDC tokens
    address private immutable i_usdcToken;
    address private immutable i_compoundUsdcToken;

    // Event emitted when a swap occurs
    event Swap(address tokenIn, address tokenOut, uint256 amount, address trader);

    /**
     * @dev Constructor to initialize the contract with token addresses and fauceteer.
     * @param usdcToken Address of the USDC token.
     * @param compoundUsdcToken Address of the Compound USDC token.
     * @param fauceteer Address of the fauceteer to drip Compound USDC.
     */
    constructor(address usdcToken, address compoundUsdcToken, address fauceteer) {
        i_usdcToken = usdcToken;
        i_compoundUsdcToken = compoundUsdcToken;
        // Drip Compound USDC tokens to the contract
        IFauceteer(fauceteer).drip(compoundUsdcToken);
    }

    /**
     * @dev Swap USDC for Compound USDC or vice versa.
     * @param tokenIn Address of the token being swapped.
     * @param tokenOut Address of the token to receive.
     * @param amount Amount of tokens to swap.
     */
    function swap(address tokenIn, address tokenOut, uint256 amount) external nonReentrant {
        // Ensure only supported tokens can be swapped
        require(tokenIn == i_usdcToken || tokenIn == i_compoundUsdcToken);
        require(tokenOut == i_usdcToken || tokenOut == i_compoundUsdcToken);

        // Transfer tokenIn from the sender to the contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(tokenOut).transfer(msg.sender, amount);

        // Emit swap event
        emit Swap(tokenIn, tokenOut, amount, msg.sender);
    }

    /**
     * @dev Get the addresses of supported tokens (USDC and Compound USDC).
     * @return usdcToken Address of the USDC token.
     * @return compoundUsdcToken Address of the Compound USDC token.
     */
    function getSupportedTokens() external view returns(address usdcToken, address compoundUsdcToken) {
        return(i_usdcToken, i_compoundUsdcToken);
    }
}