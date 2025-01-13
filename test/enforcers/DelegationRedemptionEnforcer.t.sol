// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";
import { Execution, ModeCode, Delegation, Caveat } from "delegation-framework/src/utils/Types.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { BaseTest } from "test/utils/BaseTest.t.sol";
import { MockCall } from "test/utils/MockCall.sol";
import { DelegationRedemptionEnforcer } from "../../src/enforcers/DelegationRedemptionEnforcer.sol";

contract DelegationRedemptionEnforcer_Test is BaseTest {
    using ModeLib for ModeCode;

    ////////////////////////////// State //////////////////////////////

    // Contracts
    MockCall public mockCall;
    DelegationRedemptionEnforcer public delegationRedemptionEnforcer;

    // Mode
    ModeCode public singleExecutionMode = ModeLib.encodeSimpleSingle();
    ModeCode public batchExecutionMode = ModeLib.encodeSimpleBatch();

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        mockCall = new MockCall();
        delegationRedemptionEnforcer = new DelegationRedemptionEnforcer();
    }

    ////////////////////////////// Success Tests //////////////////////////////

    function test_DelegationRedemptionEnforcer_getTermsInfo_getCorrectTerms() external {
        uint16 expectedExecutionCallIndex = 3;
        address expectedDelegationManager = address(delegationManager);
        bytes32 expectedDelegationHash = bytes32(keccak256("delegation"));

        bytes memory terms =
            abi.encodePacked(expectedExecutionCallIndex, expectedDelegationManager, expectedDelegationHash);

        (uint16 executionCallIndex, address delegationManager, bytes32 delegationHash) =
            delegationRedemptionEnforcer.getTermsInfo(terms);

        assertEq(executionCallIndex, expectedExecutionCallIndex);
        assertEq(delegationManager, expectedDelegationManager);
        assertEq(delegationHash, expectedDelegationHash);
    }

    function test_DelegationRedemptionEnforcer_beforeHook_validateCorrectExecution() external { }

    ////////////////////////////// Failure Tests //////////////////////////////

    function test_DelegationRedemptionEnforcer_getTermsInfo_RevertIf_invalidTermsLength(uint16 termsLength) external {
        // Terms should be exactly 54 bytes long.
        vm.assume(termsLength != 54);

        bytes memory wrongTerms = new bytes(termsLength);

        vm.expectRevert(
            abi.encodeWithSelector(DelegationRedemptionEnforcer.InvalidTermsLength.selector, wrongTerms.length)
        );
        delegationRedemptionEnforcer.getTermsInfo(wrongTerms);
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_singleExecutionMode() external {
        vm.expectRevert("CaveatEnforcer:invalid-call-type");
        delegationRedemptionEnforcer.beforeHook(
            hex"", hex"", singleExecutionMode, hex"", bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidTarget() external {
        address expectedTarget = address(delegationManager);
        bytes memory terms = abi.encodePacked(uint16(0), expectedTarget, bytes32(0));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            // Invalid execution with a target different from the delegation manager.
            target: address(mockCall),
            value: 0,
            callData: hex""
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                DelegationRedemptionEnforcer.InvalidTarget.selector, executions[0].target, expectedTarget
            )
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidMinCalldataLength() external {
        bytes memory terms = abi.encodePacked(uint16(0), delegationManager, bytes32(0));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(delegationManager),
            value: 0,
            // Invalid execution with a callData length less than 4.
            callData: hex""
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                DelegationRedemptionEnforcer.InvalidMinCalldataLength.selector, executions[0].callData.length
            )
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidMethodSelector() external {
        bytes memory terms = abi.encodePacked(uint16(0), delegationManager, bytes32(0));

        bytes4 expectedMethodSelector = DelegationManager.redeemDelegations.selector;
        bytes4 invalidMethodSelector = DelegationManager.getDomainHash.selector;
        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(delegationManager),
            value: 0,
            // Invalid method signature, should be redeemDelegations(bytes[],ModeCode[],bytes[]).
            callData: abi.encodeWithSelector(DelegationManager.getDomainHash.selector)
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                DelegationRedemptionEnforcer.InvalidMethodSelector.selector,
                invalidMethodSelector,
                expectedMethodSelector
            )
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidPermissionContextsLength() external {
        Caveat[] memory caveats = new Caveat[](0);
        Delegation[] memory delegations = new Delegation[](1);
        delegations[0] = Delegation({
            delegate: address(users.alice.deleGator),
            delegator: address(users.bob.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: caveats,
            salt: 0,
            signature: hex""
        });

        bytes32 delegationHash = EncoderLib._getDelegationHash(delegations[0]);
        // Invalid permission context length, should be 1.
        bytes[] memory permissionContexts = new bytes[](2);
        permissionContexts[0] = abi.encode(delegations);
        permissionContexts[1] = abi.encode(delegations);

        bytes memory terms = abi.encodePacked(uint16(0), delegationManager, delegationHash);
        bytes[] memory executionCallDatas = new bytes[](0);

        ModeCode[] memory executionModes = new ModeCode[](1);
        executionModes[0] = batchExecutionMode;

        bytes memory callData = abi.encodeWithSelector(
            DelegationManager.redeemDelegations.selector, permissionContexts, executionModes, executionCallDatas
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(delegationManager), value: 0, callData: callData });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                DelegationRedemptionEnforcer.InvalidPermissionContextsLength.selector, permissionContexts.length
            )
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidDelegationsLength() external {
        Caveat[] memory caveats = new Caveat[](0);

        Delegation memory delegation = Delegation({
            delegate: address(users.alice.deleGator),
            delegator: address(users.bob.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: caveats,
            salt: 0,
            signature: hex""
        });
        // Invalid delegations length, should be 1.
        Delegation[] memory delegations = new Delegation[](2);
        delegations[0] = delegation;
        delegations[1] = delegation;

        bytes32 delegationHash = EncoderLib._getDelegationHash(delegations[0]);
        bytes[] memory permissionContexts = new bytes[](1);
        permissionContexts[0] = abi.encode(delegations);

        bytes memory terms = abi.encodePacked(uint16(0), delegationManager, delegationHash);
        bytes[] memory executionCallDatas = new bytes[](0);

        ModeCode[] memory executionModes = new ModeCode[](1);
        executionModes[0] = batchExecutionMode;

        bytes memory callData = abi.encodeWithSelector(
            DelegationManager.redeemDelegations.selector, permissionContexts, executionModes, executionCallDatas
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(delegationManager), value: 0, callData: callData });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(DelegationRedemptionEnforcer.InvalidDelegationsLength.selector, delegations.length)
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_DelegationRedemptionEnforcer_beforeHook_RevertIf_invalidDelegationHash() external {
        Caveat[] memory caveats = new Caveat[](0);
        Delegation[] memory delegations = new Delegation[](1);
        delegations[0] = Delegation({
            delegate: address(users.alice.deleGator),
            delegator: address(users.bob.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: caveats,
            salt: 0,
            signature: hex""
        });

        bytes32 expectedDelegationHash = bytes32(keccak256("expected delegation hash"));
        bytes32 delegationHash = EncoderLib._getDelegationHash(delegations[0]);
        bytes[] memory permissionContexts = new bytes[](1);
        permissionContexts[0] = abi.encode(delegations);

        bytes memory terms = abi.encodePacked(uint16(0), delegationManager, expectedDelegationHash);
        bytes[] memory executionCallDatas = new bytes[](0);

        ModeCode[] memory executionModes = new ModeCode[](1);
        executionModes[0] = batchExecutionMode;

        bytes memory callData = abi.encodeWithSelector(
            DelegationManager.redeemDelegations.selector, permissionContexts, executionModes, executionCallDatas
        );

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({ target: address(delegationManager), value: 0, callData: callData });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                DelegationRedemptionEnforcer.InvalidDelegationHash.selector, delegationHash, expectedDelegationHash
            )
        );
        delegationRedemptionEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }
}
