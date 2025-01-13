// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { SafeSingletonDeployer } from "safe-singleton-deployer-sol/SafeSingletonDeployer.sol";
import { Multicall } from "test/utils/Multicall.sol";

contract PeripheryDeploy is Script {
    bytes32 salt;
    uint256 private deployerPrivateKey;

    function setUp() public {
        salt = salt = vm.envBytes32("SALT");
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function run() public returns (Multicall multicall) {
        vm.startBroadcast(deployerPrivateKey);
        multicall = Multicall(SafeSingletonDeployer.deploy({ creationCode: type(Multicall).creationCode, salt: salt }));
        vm.stopBroadcast();
    }
}
