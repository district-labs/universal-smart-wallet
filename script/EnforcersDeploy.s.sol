// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
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
import { NativeTokenTransferAmountEnforcer } from "delegation-framework/src/enforcers/NativeTokenTransferAmountEnforcer.sol";
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
        deployedAddress = address(new AllowedCalldataEnforcer{ salt: salt }());
        console2.log("AllowedCalldataEnforcer: %s", deployedAddress);

        deployedAddress = address(new AllowedMethodsEnforcer{ salt: salt }());
        console2.log("AllowedMethodsEnforcer: %s", deployedAddress);

        deployedAddress = address(new AllowedTargetsEnforcer{ salt: salt }());
        console2.log("AllowedTargetsEnforcer: %s", deployedAddress);

        deployedAddress = address(new ArgsEqualityCheckEnforcer{ salt: salt }());
        console2.log("ArgsEqualityCheckEnforcer: %s", deployedAddress);

        deployedAddress = address(new BlockNumberEnforcer{ salt: salt }());
        console2.log("BlockNumberEnforcer: %s", deployedAddress);

        deployedAddress = address(new DeployedEnforcer{ salt: salt }());
        console2.log("DeployedEnforcer: %s", deployedAddress);

        deployedAddress = address(new ERC20BalanceGteEnforcer{ salt: salt }());
        console2.log("ERC20BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress = address(new ERC20TransferAmountEnforcer{ salt: salt }());
        console2.log("ERC20TransferAmountEnforcer: %s", deployedAddress);

        deployedAddress = address(new ERC721BalanceGteEnforcer{ salt: salt }());
        console2.log("ERC721BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress = address(new ERC721TransferEnforcer{ salt: salt }());
        console2.log("ERC721TransferEnforcer: %s", deployedAddress);

        deployedAddress = address(new ERC1155BalanceGteEnforcer{ salt: salt }());
        console2.log("ERC1155BalanceGteEnforcer: %s", deployedAddress);

        deployedAddress = address(new IdEnforcer{ salt: salt }());
        console2.log("IdEnforcer: %s", deployedAddress);

        deployedAddress = address(new LimitedCallsEnforcer{ salt: salt }());
        console2.log("LimitedCallsEnforcer: %s", deployedAddress);

        deployedAddress = address(new NativeBalanceGteEnforcer{ salt: salt }());
        console2.log("NativeBalanceGteEnforcer: %s", deployedAddress);

        deployedAddress =
            address(new NativeTokenPaymentEnforcer{ salt: salt }(IDelegationManager(delegationManager), deployedAddress));
        console2.log("NativeTokenPaymentEnforcer: %s", deployedAddress);

        deployedAddress = address(new NativeTokenTransferAmountEnforcer{ salt: salt }());
        console2.log("NativeTokenTransferAmountEnforcer: %s", deployedAddress);

        deployedAddress = address(new NonceEnforcer{ salt: salt }());
        console2.log("NonceEnforcer: %s", deployedAddress);

        deployedAddress = address(new OwnershipTransferEnforcer{ salt: salt }());
        console2.log("OwnershipTransferEnforcer: %s", deployedAddress);

        deployedAddress = address(new RedeemerEnforcer{ salt: salt }());
        console2.log("RedeemerEnforcer: %s", deployedAddress);

        deployedAddress = address(new TimestampEnforcer{ salt: salt }());
        console2.log("TimestampEnforcer: %s", deployedAddress);

        deployedAddress = address(new ValueLteEnforcer{ salt: salt }());
        console2.log("ValueLteEnforcer: %s", deployedAddress);
        vm.stopBroadcast();
    }
}
