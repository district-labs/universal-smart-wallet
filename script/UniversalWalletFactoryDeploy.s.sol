// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";
import { UniversalWalletFactory } from "src/UniversalWalletFactory.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";

contract ERC20PaymentAffiliateEnforcerDeploy is Script {
    DelegationManager private delegationManager = DelegationManager(vm.envAddress("DELEGATION_MANAGER"));
    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    IEntryPoint private entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

    UniversalWallet universalWalletImplementation;

    function run() public returns (UniversalWalletFactory universalWalletFactory) {
        vm.startBroadcast(deployerPrivateKey);
        universalWalletImplementation = new UniversalWallet(delegationManager, entryPoint);
        universalWalletFactory = new UniversalWalletFactory(address(universalWalletImplementation));
        vm.stopBroadcast();
    }
}
