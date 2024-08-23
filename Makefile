# Include environment variables from the .env file
-include .env

# Declare phony targets (these are not actual files, but commands)
.PHONY: all test clean deploy fund help install snapshot format 


# Contract and network-specific variables
TRANSFER_USDC_ADDRESS := 0x7158AE09739b5cC461F24282f6564BAFDA3785f0
DESTINATION_CHAIN_SELECTOR := 16015286601757825753
FUJI_LINK_TOKEN_ADDRESS:= 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846
USDC_FUJI_CONTRACT_ADDRESS := 0x5425890298aed601595a70AB815c96711a31Bc65

SWAP_TESTNET_USDC := 0x19F07D51e4847e28753cBa4B5AA43AD8f5cE99dc
CCIP_RECEIVER_ADDRESS := 0x6e024043e124cb03438b07102433d6e66879eb93
SOURCE_CHAIN_SELECTOR := 14767482510784806043


# Main target that will clean, remove modules, install dependencies, update, and build the project
all: clean remove install update build

# Target to clean the project by removing all build artifacts
clean:
	@echo "Cleaning the project..."
	forge clean

# Target to remove Git submodules and libraries
remove:
	@echo "Removing submodules and libraries..."
	git submodule deinit -f --all && \
	rm -rf .git/modules/* && \
	rm -rf lib

# Target to install project dependencies (e.g., OpenZeppelin and Chainlink CCIP)
install:
	@echo "Installing dependencies..."
	forge install OpenZeppelin/openzeppelin-contracts --no-commit && forge install smartcontractkit/ccip@ccip-develop --no-commit   

# Target to update project dependencies to their latest versions
update:
	@echo "Updating dependencies..."
	forge update

# Target to build the project (compile smart contracts)
build:
	@echo "Building the project..."
	forge build

# Target to run tests on the project using Forge
test:
	@echo "Running tests..."
	forge test -vvv

# Target to generate a snapshot of the current state (useful for testing)
snapshot:
	@echo "Creating snapshot..."
	forge snapshot

# Target to format the codebase (smart contracts) according to predefined styles
format:
	@echo "Formatting codebase..."
	forge fmt


# Exercise #1: Cross-Chain Transfer USDC

# Step #1: deploy contract to the Fuji testnet
deployTransferUSDC:
	@echo "Deploying contracts to Fuji testnet..."
	@forge script script/TransferUSDC.s.sol --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(FUJI_API_KEY) -vvvv

# Step #2: Target to allowlist a destination chain (e.g., for cross-chain operations)
allowlistDestinationChain:
	@echo "Allowlisting destination chain on Fuji testnet..."
	@cast send $(TRANSFER_USDC_ADDRESS) "allowlistDestinationChain(uint64,bool)" $(DESTINATION_CHAIN_SELECTOR) true --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY) 

# Step #3: Fund the Deployed Fuji contract address with 3 Link Tokens
fundFujiContract:
	@echo "Funding TransferUSDC.sol contract..."
	@cast send $(FUJI_LINK_TOKEN_ADDRESS) "transfer(address,uint256)" $(TRANSFER_USDC_ADDRESS) 3000000 --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY)

# Step #4: Target to approve a specific contract to spend USDC on behalf of the user
approve:
	@echo "Approving contract to spend USDC on Fuji testnet..."
	@cast send $(USDC_FUJI_CONTRACT_ADDRESS) "approve(address,uint256)" $(TRANSFER_USDC_ADDRESS) 1000000 --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY) 

# Step #5: Target to transfer USDC to a specified address using the contract on Fuji testnet
transferUsdcFuji:
	@echo "Transferring USDC on Fuji testnet..."
	@cast send $(TRANSFER_USDC_ADDRESS) "transferUsdc(uint64,address,uint256,uint64)" $(DESTINATION_CHAIN_SELECTOR) $(SENDER_PUBLIC_KEY) 1000000 0 --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY)


# Step #6: (Optional) Call the TransferUSDC.sol contract address to check Link token balance.
callFujiBalance:
	@cast call $(FUJI_LINK_TOKEN_ADDRESS) "balanceOf(address)(uint256)" $(TRANSFER_USDC_ADDRESS) --rpc-url $(FUJI_RPC_URL)

# Exercise #2: Deposit transferred USDC to Compound V3

# Step #1: Target to deploy SwapTestnetUSDC
deploySwapTestnetUSDC:
	@echo "Deploying contracts to Sepolia testnet..."
	@forge script script/DeploySwapTestnetUSDC.s.sol --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# Step #2-3: Deploy CCIP Receiver contract with SwapTestNetUSDC contract address
deployCCIPReceiver:
	@echo "Deploying CCIPReceiver to Sepolia testnet..."
	@forge script script/DeployCCIPReceiver.s.sol --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

# Step #4: Target to allowlist a source chain
allowlistSourceChain:
	@echo "Allowlisting destination chain on Sepolia testnet..."
	@cast send $(CCIP_RECEIVER_ADDRESS) "allowlistSourceChain(uint64,bool)" $(SOURCE_CHAIN_SELECTOR) true --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY)  

# Step #5: Target to allowlist sender function
allowlistSender:
	@echo "Allowlisting sender function on Sepolia testnet..."
	@cast send $(CCIP_RECEIVER_ADDRESS) "allowlistSender(address,bool)" $(TRANSFER_USDC_ADDRESS) true --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) 

# Step #6: Repeat command `make approve`

# Step #7: Target to transfer USDC to a specified address using the contract on Fuji testnet for CCIP
transferUsdcCCIP:
	@echo "Transferring USDC on Fuji testnet..."
	@cast send $(TRANSFER_USDC_ADDRESS) "transferUsdc(uint64,address,uint256,uint64)" $(DESTINATION_CHAIN_SELECTOR) $(CCIP_RECEIVER_ADDRESS) 1000000 500000 --rpc-url $(FUJI_RPC_URL) --private-key $(PRIVATE_KEY)

# In case of error code 3: execution reverted, data:
decodeBytes:
	@cast 4byte 0x08c379a0



