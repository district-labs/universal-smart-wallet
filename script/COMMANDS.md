## Deploy
forge script script/UniversalWalletFactoryDeploy.s.sol:UniversalWalletFactoryDeploy --via-ir --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvv
forge script script/EnforcersDeploy.s.sol:EnforcersDeploy --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvv 

## Verify
forge verify-contract --chain 84532 0xad9A4bE061a4F800CAceCbE69609d465e9a8f298 src/UniversalWallet.sol:UniversalWallet
forge verify-contract --chain 84532 0x6456c9F0B987b71e1c47c34F1A95aB6eED8DA2f0 src/UniversalWalletFactory.sol:UniversalWalletFactory --watch --via-ir

