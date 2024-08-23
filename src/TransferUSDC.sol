// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TransferUSDC
 * @dev Example contract for transferring USDC across chains using Chainlink's CCIP.
 *      Not audited; not for production use.
 */
contract TransferUSDC is OwnerIsCreator {
    using SafeERC20 for IERC20;

    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees);
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    error NothingToWithdraw();

    IRouterClient private immutable i_ccipRouter;
    IERC20 private immutable i_linkToken;
    IERC20 private immutable i_usdcToken;

    // Mapping to track allowlisted destination chains
    mapping(uint64 => bool) public allowlistedChains;

    // Modifier to check if the destination chain is allowlisted
    modifier onlyAllowlistedChain(uint64 _destinationChainSelector) {
        if (!allowlistedChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

    // Event emitted when USDC is transferred
    event UsdcTransferred(
        bytes32 messageId,
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount,
        uint256 ccipFee
    );

    /**
     * @dev Constructor to initialize the contract with CCIP router, LINK token, and USDC token addresses.
     * @param ccipRouter Address of the Chainlink CCIP Router.
     * @param linkToken Address of the LINK token.
     * @param usdcToken Address of the USDC token.
     */
    constructor(address ccipRouter, address linkToken, address usdcToken) {
        i_ccipRouter = IRouterClient(ccipRouter);
        i_linkToken = IERC20(linkToken);
        i_usdcToken = IERC20(usdcToken);
    }

    /**
     * @dev Allowlist or remove a destination chain.
     * @param _destinationChainSelector Chain ID of the destination.
     * @param _allowed Boolean indicating whether the chain is allowlisted.
     */
    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool _allowed
    ) external onlyOwner {
        allowlistedChains[_destinationChainSelector] = _allowed;
    }

    /**
     * @dev Transfer USDC across chains using Chainlink's CCIP.
     * @param _destinationChainSelector Chain ID of the destination.
     * @param _receiver Address of the receiver on the destination chain.
     * @param _amount Amount of USDC to transfer.
     * @param _gasLimit Gas limit for the transaction on the destination chain.
     * @param _iterations Data passed to the receiver on the destination chain.
     * @return messageId The ID of the sent CCIP message.
     */
    function transferUsdc(
        uint64 _destinationChainSelector,
        address _receiver,
        uint256 _amount,
        uint64 _gasLimit,
        uint256 _iterations
    )
        external
        onlyOwner
        onlyAllowlistedChain(_destinationChainSelector)
        returns (bytes32 messageId)
    {
        // Prepare USDC transfer details
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount({
            token: address(i_usdcToken),
            amount: _amount
        });
        tokenAmounts[0] = tokenAmount;

        // Create CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: abi.encode(_iterations),
            tokenAmounts: tokenAmounts,
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: _gasLimit})
            ),
            feeToken: address(i_linkToken)
        });

        // Calculate CCIP fee
        uint256 ccipFee = i_ccipRouter.getFee(
            _destinationChainSelector,
            message
        );

        // Check for sufficient LINK balance
        if (ccipFee > i_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(
                i_linkToken.balanceOf(address(this)),
                ccipFee
            );

        // Approve and send USDC and LINK for CCIP transfer
        i_linkToken.approve(address(i_ccipRouter), ccipFee);
        i_usdcToken.safeTransferFrom(msg.sender, address(this), _amount);
        i_usdcToken.approve(address(i_ccipRouter), _amount);

        // Send CCIP Message
        messageId = i_ccipRouter.ccipSend(_destinationChainSelector, message);

        // Emit event after successful transfer
        emit UsdcTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _amount,
            ccipFee
        );
    }

    /**
     * @dev Withdraw any ERC20 token from the contract.
     * @param _beneficiary Address to receive the withdrawn tokens.
     * @param _token Address of the token to withdraw.
     */
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        uint256 amount = IERC20(_token).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).transfer(_beneficiary, amount);
    }
}