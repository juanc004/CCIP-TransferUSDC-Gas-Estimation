// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";

interface CometMainInterface {
    function supply(address asset, uint amount) external;
}

interface ISwapTestnetUSDC {
    function swap(address tokenIn, address tokenOut, uint256 amount) external;

    function getSupportedTokens()
        external
        view
        returns (address usdcToken, address compoundUsdcToken);
}

/**
 * @title CrossChainReceiver
 * @dev Example contract to receive and process cross-chain messages, handle token swaps,
 *      and manage failed message recovery. Not for production use.
 */
contract CrossChainReceiver is CCIPReceiver, OwnerIsCreator {
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
    using SafeERC20 for IERC20;

    // Enum representing various error codes
    enum ErrorCode {
        // RESOLVED is first so that the default value is resolved.
        RESOLVED,
        // Could have any number of error codes here.
        BASIC
    }

    error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error OnlySelf(); // Used when a function is called outside of the contract itself.
    error ErrorCase(); // Used when simulating a revert during message processing.
    error MessageNotFailed(bytes32 messageId);

    CometMainInterface internal immutable i_comet;
    ISwapTestnetUSDC internal immutable i_swapTestnetUsdc;

    // This is used to simulate a revert in the processMessage function.
    bool internal s_simRevert = false;

    // Contains failed messages and their state.
    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 chainSelecotor => bool isAllowlisted)
        public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address sender => bool isAllowlisted) public allowlistedSenders;

    // Mapping to keep track of the message contents of failed messages.
    mapping(bytes32 messageId => Client.Any2EVMMessage contents)
        public s_messageContents;

    event MessageFailed(bytes32 indexed messageId, bytes reason);
    event MessageRecovered(bytes32 indexed messageId);

    /**
     * @dev Constructor to initialize the contract with required addresses.
     * @param ccipRouterAddress Address of the CCIP router.
     * @param cometAddress Address of the Comet contract.
     * @param swapTestnetUsdcAddress Address of the SwapTestnetUSDC contract.
     */
    constructor(
        address ccipRouterAddress,
        address cometAddress,
        address swapTestnetUsdcAddress
    ) CCIPReceiver(ccipRouterAddress) {
        i_comet = CometMainInterface(cometAddress);
        i_swapTestnetUsdc = ISwapTestnetUSDC(swapTestnetUsdcAddress);
    }

    /**
     * @dev Modifier to ensure the source chain and sender are allowlisted.
     * @param _sourceChainSelector The chain selector of the source chain.
     * @param _sender The address of the sender.
     */
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowed(_sourceChainSelector);
        if (!allowlistedSenders[_sender]) revert SenderNotAllowed(_sender);
        _;
    }

    /**
     * @dev Modifier to restrict function access to the contract itself.
     * @notice Reverts if called by any account other than the contract.
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    /**
     * @dev Update the allowlist status of a source chain.
     * @notice Only callable by the owner.
     * @param _sourceChainSelector The selector of the source chain.
     * @param _allowed The allowlist status to set.
     */
    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool _allowed
    ) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = _allowed;
    }

    /**
     * @dev Update the allowlist status of a sender.
     * @notice Only callable by the owner.
     * @param _sender The address of the sender.
     * @param _allowed The allowlist status to set.
     */
    function allowlistSender(
        address _sender,
        bool _allowed
    ) external onlyOwner {
        allowlistedSenders[_sender] = _allowed;
    }

    /**
     * @notice Entry point for processing cross-chain messages from the CCIP router.
     * @param any2EvmMessage The cross-chain message received.
     * @dev Handles errors internally without reverting. Ensures only the router calls this function.
     */
    function ccipReceive(
        Client.Any2EVMMessage calldata any2EvmMessage
    )
        external
        override
        onlyRouter
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        /* solhint-disable no-empty-blocks */
        try this.processMessage(any2EvmMessage) {
            // Intentionally empty in this example; no action needed if processMessage succeeds
        } catch (bytes memory err) {
            // Could set different error codes based on the caught error. Each could be
            // handled differently.
            s_failedMessages.set(
                any2EvmMessage.messageId,
                uint256(ErrorCode.BASIC)
            );
            s_messageContents[any2EvmMessage.messageId] = any2EvmMessage;
            // Don't revert so CCIP doesn't revert. Emit event instead.
            // The message can be retried later without having to do manual execution of CCIP.
            emit MessageFailed(any2EvmMessage.messageId, err);
            return;
        }
    }

    /**
     * @notice Processes the incoming cross-chain message.
     * @param any2EvmMessage The cross-chain message received.
     * @dev Transfers tokens specified in the message. Only callable by the contract itself.
     */
    function processMessage(
        Client.Any2EVMMessage calldata any2EvmMessage
    )
        external
        onlySelf
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        // Simulate a revert for testing purposes
        if (s_simRevert) revert ErrorCase();

        _ccipReceive(any2EvmMessage); // process the message - may revert as well
    }

    /**
     * @notice Retries a failed message to recover associated tokens.
     * @param messageId The ID of the failed message.
     * @param tokenReceiver The address to receive the recovered tokens.
     * @dev Marks the message as resolved to prevent multiple retries.
     */
    function retryFailedMessage(
        bytes32 messageId,
        address tokenReceiver
    ) external onlyOwner {
        // Check if the message has failed; if not, revert the transaction.
        if (s_failedMessages.get(messageId) != uint256(ErrorCode.BASIC))
            revert MessageNotFailed(messageId);

        // Set the error code to RESOLVED to disallow reentry and multiple retries of the same failed message.
        s_failedMessages.set(messageId, uint256(ErrorCode.RESOLVED));

        // Retrieve the content of the failed message.
        Client.Any2EVMMessage memory message = s_messageContents[messageId];

        // This example expects one token to have been sent, but you can handle multiple tokens.
        // Transfer the associated tokens to the specified receiver as an escape hatch.
        IERC20(message.destTokenAmounts[0].token).safeTransfer(
            tokenReceiver,
            message.destTokenAmounts[0].amount
        );

        // Emit an event indicating that the message has been recovered.
        emit MessageRecovered(messageId);
    }

    /**
     * @notice Toggles the simulation of a revert for testing.
     * @param simRevert If `true`, enables revert simulation; otherwise disables it.
     * @dev Only callable by the owner.
     */
    function setSimRevert(bool simRevert) external onlyOwner {
        s_simRevert = simRevert;
    }

    /**
     * @dev Internal function to process the received CCIP message.
     * @param any2EvmMessage The cross-chain message received.
     */
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        address usdcToken = any2EvmMessage.destTokenAmounts[0].token;
        (, address compoundUsdcToken) = i_swapTestnetUsdc.getSupportedTokens();
        uint256 amount = any2EvmMessage.destTokenAmounts[0].amount;

        IERC20(usdcToken).approve(address(i_swapTestnetUsdc), amount);

        // Swap actual testnet USDC for Compound V3's version of USDC test token.
        // This step is neccessary on testnets only!
        i_swapTestnetUsdc.swap(usdcToken, compoundUsdcToken, amount);

        IERC20(compoundUsdcToken).approve(address(i_comet), amount);

        i_comet.supply(compoundUsdcToken, amount);
    }

    /**
     * @notice Retrieves the IDs of failed messages.
     * @return ids Array of message IDs.
     */
    function getFailedMessagesIds()
        external
        view
        returns (bytes32[] memory ids)
    {
        uint256 length = s_failedMessages.length();
        bytes32[] memory allKeys = new bytes32[](length);
        for (uint256 i = 0; i < length; i++) {
            (bytes32 key, ) = s_failedMessages.at(i);
            allKeys[i] = key;
        }
        return allKeys;
    }
}
