// SPDX-License-Identifier: MIT AND Apache-2.0
pragma solidity 0.8.23;

import { DeleGatorCore } from "delegation-framework/src/DeleGatorCore.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";

struct TestUser {
    string name;
    address payable addr;
    uint256 privateKey;
    UniversalWallet wallet;
    DeleGatorCore deleGator;
    uint256 x;
    uint256 y;
}

struct TestUsers {
    TestUser bundler;
    TestUser alice;
    TestUser bob;
    TestUser carol;
    TestUser dave;
    TestUser eve;
    TestUser frank;
    TestUser paymentRouter;
    TestUser affiliate;
    TestUser user1;
    TestUser user2;
    TestUser user3;
}

/**
 * @title Signature Type
 * @dev This enum represents the different types of Signatures.
 */
enum SignatureType {
    EOA,
    RawP256
}
