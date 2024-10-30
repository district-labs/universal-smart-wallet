// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// Library Imports
import { BaseTest, ERC20Mintable } from "test/utils/BaseTest.t.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { WebAuthnInfo, Utils } from "webauthn-sol/../test/Utils.sol";
import { Delegation, Caveat, Execution, PackedUserOperation, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { ERC1271Lib } from "delegation-framework/src/libraries/ERC1271Lib.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { AllowedTargetsEnforcer } from "delegation-framework/src/enforcers/AllowedTargetsEnforcer.sol";

// Internal Imports
import { SignatureType, TestUser } from "./utils/Types.t.sol";
import { UniversalWallet } from "src/UniversalWallet.sol";

contract UniversalWallet_Test is BaseTest {
    using MessageHashUtils for bytes32;
    using ModeLib for ModeCode;

    ModeCode[] _oneSingularMode;
    AllowedTargetsEnforcer allowedTargetsEnforcer;

    function setUp() public virtual override {
        super.setUp();

        SIGNATURE_TYPE = SignatureType.EOA;
        _oneSingularMode = new ModeCode[](1);
        _oneSingularMode[0] = ModeLib.encodeSimpleSingle();

        allowedTargetsEnforcer = new AllowedTargetsEnforcer();
    }

    function test_initialize() external {
        uint256 ownerCount = users.alice.wallet.ownerCount();
        assertEq(ownerCount, 2);
    }

    function test_isValidSignature() external {
        bytes32 testHash = keccak256("Universal Wallet");
        bytes4 isValid = users.alice.wallet.isValidSignature(testHash, signHash(users.alice, testHash));
        assertEq(isValid, ERC1271Lib.EIP1271_MAGIC_VALUE);
    }

    function test_UserOp_isValidSignature() external {
        bytes memory userOpCallData_ = abi.encodeWithSignature(
            EXECUTE_SINGULAR_SIGNATURE,
            Execution({
                target: address(users.alice.wallet),
                value: 0,
                callData: abi.encodeWithSelector(ERC20Mintable.mint.selector, address(users.alice.wallet), 1e18)
            })
        );
        PackedUserOperation memory userOp_ = createUserOp(address(users.alice.wallet), userOpCallData_);
        bytes32 userOpHash_ = users.alice.wallet.getPackedUserOperationHash(userOp_);
        bytes32 typedDataHash_ = MessageHashUtils.toTypedDataHash(users.alice.wallet.getDomainHash(), userOpHash_);
        bytes4 isValid = users.alice.wallet.isValidSignature(typedDataHash_, signHash(users.alice, typedDataHash_));
        assertEq(isValid, ERC1271Lib.EIP1271_MAGIC_VALUE);
    }

    function test_UserOp_execute() external {
        bytes memory userOpCallData_ = abi.encodeWithSignature(
            EXECUTE_SINGULAR_SIGNATURE,
            Execution({
                target: address(erc20),
                value: 0,
                callData: abi.encodeWithSelector(ERC20Mintable.mint.selector, address(users.alice.wallet), 100e18)
            })
        );
        PackedUserOperation memory userOp_ =
            createAndSignUserOp(users.alice, address(users.alice.wallet), userOpCallData_);
        assertEq(erc20.balanceOf(address(users.alice.wallet)), 0);
        submitUserOp_Bundler(userOp_, false);
        assertEq(erc20.balanceOf(address(users.alice.wallet)), 100e18);
    }

    function test_Delegation_execute() external {
        Delegation memory delegation_ = signDelegation(
            users.alice,
            Delegation({
                delegate: users.bob.addr,
                delegator: address(users.alice.wallet),
                authority: ROOT_AUTHORITY,
                caveats: new Caveat[](0),
                salt: 0,
                signature: hex""
            })
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = delegation_;

        bytes[] memory permissionContexts_ = new bytes[](1);
        permissionContexts_[0] = abi.encode(delegations_);

        bytes[] memory executionCallDatas_ = new bytes[](1);
        executionCallDatas_[0] = ExecutionLib.encodeSingle(
            address(erc20), 0, abi.encodeWithSelector(ERC20Mintable.mint.selector, address(users.alice.wallet), 100e18)
        );

        assertEq(erc20.balanceOf(address(users.alice.wallet)), 0);
        vm.prank(address(users.bob.addr));
        delegationManager.redeemDelegations(permissionContexts_, _oneSingularMode, executionCallDatas_);
        assertEq(erc20.balanceOf(address(users.alice.wallet)), 100e18);
    }

    function test_DelegationWithCaveat_execute() external {
        Caveat[] memory caveats_ = new Caveat[](1);
        caveats_[0] = Caveat({
            enforcer: address(allowedTargetsEnforcer),
            terms: abi.encodePacked(address(erc20)),
            args: bytes("")
        });

        Delegation memory delegation_ = signDelegation(
            users.alice,
            Delegation({
                delegate: users.bob.addr,
                delegator: address(users.alice.wallet),
                authority: ROOT_AUTHORITY,
                caveats: caveats_,
                salt: 0,
                signature: hex""
            })
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = delegation_;

        bytes[] memory permissionContexts_ = new bytes[](1);
        permissionContexts_[0] = abi.encode(delegations_);

        bytes[] memory executionCallDatas_ = new bytes[](1);
        executionCallDatas_[0] = ExecutionLib.encodeSingle(
            address(erc20), 0, abi.encodeWithSelector(ERC20Mintable.mint.selector, address(users.alice.wallet), 100e18)
        );

        assertEq(erc20.balanceOf(address(users.alice.wallet)), 0);
        vm.prank(address(users.bob.addr));
        delegationManager.redeemDelegations(permissionContexts_, _oneSingularMode, executionCallDatas_);
        assertEq(erc20.balanceOf(address(users.alice.wallet)), 100e18);
    }

    function test_DelegationWithCaveat_invalidTerms() external {
        Caveat[] memory caveats_ = new Caveat[](1);
        caveats_[0] = Caveat({
            enforcer: address(allowedTargetsEnforcer),
            terms: abi.encodePacked(address(0xdEaD)),
            args: bytes("")
        });

        Delegation memory delegation_ = signDelegation(
            users.alice,
            Delegation({
                delegate: users.bob.addr,
                delegator: address(users.alice.wallet),
                authority: ROOT_AUTHORITY,
                caveats: caveats_,
                salt: 0,
                signature: hex""
            })
        );

        Delegation[] memory delegations_ = new Delegation[](1);
        delegations_[0] = delegation_;

        bytes[] memory permissionContexts_ = new bytes[](1);
        permissionContexts_[0] = abi.encode(delegations_);

        bytes[] memory executionCallDatas_ = new bytes[](1);
        executionCallDatas_[0] = ExecutionLib.encodeSingle(
            address(erc20), 0, abi.encodeWithSelector(ERC20Mintable.mint.selector, address(users.alice.wallet), 100e18)
        );

        vm.prank(address(users.bob.addr));
        vm.expectRevert();
        delegationManager.redeemDelegations(permissionContexts_, _oneSingularMode, executionCallDatas_);
    }
}
