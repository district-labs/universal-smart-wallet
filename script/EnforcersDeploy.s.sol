// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";
import { SafeSingletonDeployer } from "safe-singleton-deployer-sol/SafeSingletonDeployer.sol";
import { IDelegationManager } from "delegation-framework/src/interfaces/IDelegationManager.sol";
import { AllowedCalldataEnforcer } from "delegation-framework/src/enforcers/AllowedCalldataEnforcer.sol";
import { AllowedMethodsEnforcer } from "delegation-framework/src/enforcers/AllowedMethodsEnforcer.sol";
import { AllowedTargetsEnforcer } from "delegation-framework/src/enforcers/AllowedTargetsEnforcer.sol";
import { ArgsEqualityCheckEnforcer } from "delegation-framework/src/enforcers/ArgsEqualityCheckEnforcer.sol";
import { BlockNumberEnforcer } from "delegation-framework/src/enforcers/BlockNumberEnforcer.sol";
import { DeployedEnforcer } from "delegation-framework/src/enforcers/DeployedEnforcer.sol";
import { ERC20BalanceGteEnforcer } from "delegation-framework/src/enforcers/ERC20BalanceGteEnforcer.sol";
import { ERC20TransferAmountEnforcer } from "delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";
import { ERC721BalanceGteEnforcer } from "delegation-framework/src/enforcers/ERC721BalanceGteEnforcer.sol";
import { ERC721TransferEnforcer } from "delegation-framework/src/enforcers/ERC721TransferEnforcer.sol";
import { ERC1155BalanceGteEnforcer } from "delegation-framework/src/enforcers/ERC1155BalanceGteEnforcer.sol";
import { IdEnforcer } from "delegation-framework/src/enforcers/IdEnforcer.sol";
import { LimitedCallsEnforcer } from "delegation-framework/src/enforcers/LimitedCallsEnforcer.sol";
import { NativeBalanceGteEnforcer } from "delegation-framework/src/enforcers/NativeBalanceGteEnforcer.sol";
import { NativeTokenPaymentEnforcer } from "delegation-framework/src/enforcers/NativeTokenPaymentEnforcer.sol";
import { NativeTokenTransferAmountEnforcer } from
    "delegation-framework/src/enforcers/NativeTokenTransferAmountEnforcer.sol";
import { NonceEnforcer } from "delegation-framework/src/enforcers/NonceEnforcer.sol";
import { OwnershipTransferEnforcer } from "delegation-framework/src/enforcers/OwnershipTransferEnforcer.sol";
import { RedeemerEnforcer } from "delegation-framework/src/enforcers/RedeemerEnforcer.sol";
import { TimestampEnforcer } from "delegation-framework/src/enforcers/TimestampEnforcer.sol";
import { ValueLteEnforcer } from "delegation-framework/src/enforcers/ValueLteEnforcer.sol";

contract EnforcersDeploy is Script {
    bytes32 salt;
    uint256 private deployerPrivateKey;
    IDelegationManager delegationManager;

    function setUp() public {
        salt = bytes32(abi.encodePacked(vm.envString("SALT")));
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        delegationManager = IDelegationManager(vm.envAddress("DELEGATION_MANAGER"));
    }

    function run() public returns (ERC20TransferAmountEnforcer erc20TransferAmountEnforcer) {
        vm.startBroadcast(deployerPrivateKey);
        address deployedAddress;

        // Caveat Enforcers (in alphabetical order)
        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(AllowedCalldataEnforcer).creationCode, salt: salt });
        console2.log("AllowedCalldataEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(AllowedMethodsEnforcer).creationCode, salt: salt });
        console2.log("AllowedMethodsEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(AllowedTargetsEnforcer).creationCode, salt: salt });
        console2.log("AllowedTargetsEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ArgsEqualityCheckEnforcer).creationCode, salt: salt });
        console2.log("ArgsEqualityCheckEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(BlockNumberEnforcer).creationCode, salt: salt });
        console2.log("BlockNumberEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(DeployedEnforcer).creationCode, salt: salt });
        console2.log("DeployedEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ERC20BalanceGteEnforcer).creationCode, salt: salt });
        console2.log("ERC20BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ERC20TransferAmountEnforcer).creationCode, salt: salt });
        console2.log("ERC20TransferAmountEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ERC721BalanceGteEnforcer).creationCode, salt: salt });
        console2.log("ERC721BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ERC721TransferEnforcer).creationCode, salt: salt });
        console2.log("ERC721TransferEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ERC1155BalanceGteEnforcer).creationCode, salt: salt });
        console2.log("ERC1155BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress = SafeSingletonDeployer.deploy({ creationCode: type(IdEnforcer).creationCode, salt: salt });
        console2.log("IdEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(LimitedCallsEnforcer).creationCode, salt: salt });
        console2.log("LimitedCallsEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(NativeBalanceGteEnforcer).creationCode, salt: salt });
        console2.log("NativeBalanceGteEnforcer: %s", deployedAddress);

        deployedAddress = SafeSingletonDeployer.deploy({
            creationCode: type(NativeTokenPaymentEnforcer).creationCode,
            args: abi.encode(IDelegationManager(delegationManager), deployedAddress),
            salt: salt
        });
        console2.log("NativeTokenPaymentEnforcer: %s", deployedAddress);

        deployedAddress = SafeSingletonDeployer.deploy({
            creationCode: type(NativeTokenTransferAmountEnforcer).creationCode,
            salt: salt
        });
        console2.log("NativeTokenTransferAmountEnforcer: %s", deployedAddress);

        deployedAddress = SafeSingletonDeployer.deploy({ creationCode: type(NonceEnforcer).creationCode, salt: salt });
        console2.log("NonceEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(OwnershipTransferEnforcer).creationCode, salt: salt });
        console2.log("OwnershipTransferEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(RedeemerEnforcer).creationCode, salt: salt });
        console2.log("RedeemerEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(TimestampEnforcer).creationCode, salt: salt });
        console2.log("TimestampEnforcer: %s", deployedAddress);

        deployedAddress =
            SafeSingletonDeployer.deploy({ creationCode: type(ValueLteEnforcer).creationCode, salt: salt });
        console2.log("ValueLteEnforcer: %s", deployedAddress);
        vm.stopBroadcast();
    }
}
