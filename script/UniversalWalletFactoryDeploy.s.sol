// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";
import { UniversalWalletFactory } from "src/UniversalWalletFactory.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";

contract UniversalWalletFactoryDeploy is Script {
    uint256 private deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    IEntryPoint private entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
    DelegationManager private delegationManager = DelegationManager(vm.envAddress("DELEGATION_MANAGER"));

    function run() public returns (UniversalWallet universalWalletImplementation, UniversalWalletFactory universalWalletFactory) {
        vm.startBroadcast(deployerPrivateKey);
        universalWalletImplementation = new UniversalWallet(delegationManager, entryPoint);
        universalWalletFactory = new UniversalWalletFactory(address(universalWalletImplementation));
        vm.stopBroadcast();
    }
}
