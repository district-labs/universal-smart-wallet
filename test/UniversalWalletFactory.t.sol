// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "test/utils/BaseTest.t.sol";
import { UniversalWalletFactory } from "src/UniversalWalletFactory.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";

contract UniversalWalletFactory_Test is BaseTest {
    UniversalWalletFactory universalWalletFactory;

    function setUp() public virtual override {
        super.setUp();
        universalWalletFactory = new UniversalWalletFactory(address(universalWalletImplementation));
    }

    function test_deploy() external {
        uint256 nonce = 0;
        bytes memory publicKey = abi.encodePacked(users.alice.x, users.alice.y);
        bytes[] memory owners = new bytes[](1);
        owners[0] = publicKey;

        address counterfactualAddress = universalWalletFactory.getAddress(owners, nonce);
        console2.log("counterfactualAddress: %s", counterfactualAddress);

        UniversalWallet universalWallet = universalWalletFactory.createAccount(owners, nonce);

        console2.log("universalWallet: %s", address(universalWallet));
        assertEq(counterfactualAddress, address(universalWallet));

        bytes memory owner = universalWallet.ownerAtIndex(0);
        assertEq(owner, publicKey);
    }
}
