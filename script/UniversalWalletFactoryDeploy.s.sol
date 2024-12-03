// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { SafeSingletonDeployer } from "safe-singleton-deployer-sol/SafeSingletonDeployer.sol";
import { Script } from "forge-std/Script.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";
import { UniversalWalletFactory } from "src/UniversalWalletFactory.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";

contract UniversalWalletFactoryDeploy is Script {
    bytes32 salt;
    uint256 private deployerPrivateKey;
    IEntryPoint private entryPoint;
    DelegationManager private delegationManager;

    function setUp() public {
        salt = vm.envBytes32("SALT");
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        delegationManager = DelegationManager(vm.envAddress("DELEGATION_MANAGER"));
    }

    function run()
        public
        returns (UniversalWallet universalWalletImplementation, UniversalWalletFactory universalWalletFactory)
    {
        vm.startBroadcast(deployerPrivateKey);
        universalWalletImplementation = UniversalWallet(
            payable(
                SafeSingletonDeployer.deploy({
                    creationCode: type(UniversalWallet).creationCode,
                    args: abi.encode(delegationManager, entryPoint),
                    salt: salt
                })
            )
        );
        universalWalletFactory = UniversalWalletFactory(
            SafeSingletonDeployer.deploy({
                creationCode: type(UniversalWalletFactory).creationCode,
                args: abi.encode(address(universalWalletImplementation)),
                salt: salt
            })
        );
        vm.stopBroadcast();
    }
}
