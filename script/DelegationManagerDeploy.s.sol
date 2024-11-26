// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { SafeSingletonDeployer } from "safe-singleton-deployer-sol/SafeSingletonDeployer.sol";
import { Script } from "forge-std/Script.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";

contract DelegationManagerDeploy is Script {
    bytes32 salt;
    uint256 private deployerPrivateKey;
    address private delegationManagerOwner;

    function setUp() public {
        salt = bytes32(abi.encodePacked(vm.envString("SALT")));
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        delegationManagerOwner = vm.envAddress("DELEGATION_MANAGER_OWNER");
    }

    function run() public returns (DelegationManager delegationManager) {
        vm.startBroadcast(deployerPrivateKey);
        delegationManager = DelegationManager(
            SafeSingletonDeployer.deploy({
                creationCode: type(DelegationManager).creationCode,
                args: abi.encode(delegationManagerOwner),
                salt: salt
            })
        );
        vm.stopBroadcast();
    }
}
