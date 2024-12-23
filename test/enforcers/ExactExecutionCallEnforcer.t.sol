// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import {
    ModeCode,
    Execution,
    ExecType,
    CallType,
    ModePayload,
    ModeSelector
} from "delegation-framework/src/utils/Types.sol";
import { BaseTest } from "test/utils/BaseTest.t.sol";
import { MockCall } from "test/utils/MockCall.sol";
import {
    ExactExecutionCallEnforcerHarness, ExactExecutionCallEnforcer
} from "./mock/ExactExecutionCallEnforcerHarness.sol";

contract ExactExecutionCallEnforcer_Test is BaseTest {
    using ModeLib for ModeCode;

    ////////////////////////////// State //////////////////////////////

    // Contracts
    MockCall public mockCall;
    ExactExecutionCallEnforcerHarness public exactExecutionCallEnforcer;

    // Mode
    ModeCode public singleMode = ModeLib.encodeSimpleSingle();
    ModeCode public batchMode = ModeLib.encodeSimpleBatch();

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        mockCall = new MockCall();
        exactExecutionCallEnforcer = new ExactExecutionCallEnforcerHarness();
    }

    ////////////////////////////// Success Tests //////////////////////////////

    function test_ExactExecutionCallEnforcer_beforeHook_validateCorrectExecution() external {
        address expectedTarget = address(mockCall);
        bytes memory expectedCalldata = abi.encodeWithSelector(MockCall.success.selector);

        bytes memory terms = abi.encodePacked(uint16(0), expectedTarget, expectedCalldata);

        Execution memory execution = Execution({ target: expectedTarget, value: 0, callData: expectedCalldata });
        bytes memory executionCallData =
            ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData);

        // Should not revert since the execution target and calldata are correct.
        exactExecutionCallEnforcer.beforeHook(
            terms, hex"", singleMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallEnforcer_getTermsInfo_getCorrectTerms() external {
        uint16 executionCallIndex = 3;
        address target = address(mockCall);
        bytes memory callData = abi.encodeWithSelector(MockCall.success.selector);

        bytes memory terms = abi.encodePacked(executionCallIndex, target, callData);

        (uint16 _executionCallIndex, address _target, bytes memory _callData) =
            exactExecutionCallEnforcer.getTermsInfo(terms);

        assertEq(_executionCallIndex, executionCallIndex);
        assertEq(_target, target);
        assertTrue(exactExecutionCallEnforcer.exposed_compareBytes(_callData, callData));
    }

    function test_ExactExecutionCallEnforcer_getExecutionCall_getSingleExecution() external {
        Execution memory execution = Execution({
            target: address(mockCall),
            value: 1000,
            callData: abi.encodeWithSelector(MockCall.success.selector)
        });
        bytes memory executionCallData =
            ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData);

        Execution memory returnedExecution = exactExecutionCallEnforcer.exposed_getExecutionCall(
            singleMode,
            executionCallData,
            // The execution index is not used in single mode.
            0
        );

        assertEq(returnedExecution.target, execution.target);
        assertEq(returnedExecution.value, execution.value);
        assertTrue(exactExecutionCallEnforcer.exposed_compareBytes(returnedExecution.callData, execution.callData));
    }

    function test_ExactExecutionCallEnforcer_getExecutionCall_getBatchExecution() external {
        uint16 executionCallIndex = 1;
        Execution[] memory executions = new Execution[](2);
        executions[0] =
            Execution({ target: address(0), value: 0, callData: abi.encodeWithSelector(MockCall.throwError.selector) });
        executions[1] = Execution({
            target: address(mockCall),
            value: 1000,
            callData: abi.encodeWithSelector(MockCall.success.selector)
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);
        Execution memory returnedExecution =
            exactExecutionCallEnforcer.exposed_getExecutionCall(batchMode, executionCallData, executionCallIndex);

        assertEq(returnedExecution.target, executions[executionCallIndex].target);
        assertEq(returnedExecution.value, executions[executionCallIndex].value);
        assertTrue(
            exactExecutionCallEnforcer.exposed_compareBytes(
                returnedExecution.callData, executions[executionCallIndex].callData
            )
        );
    }

    function test_ExactExecutionCallEnforcer_compareBytes_compareBytesCorrectly() external {
        bytes memory a = abi.encodePacked(uint256(1));
        bytes memory b = abi.encodePacked(uint256(1));
        bytes memory c = abi.encodePacked(uint256(2));

        assertTrue(exactExecutionCallEnforcer.exposed_compareBytes(a, b));
        assertFalse(exactExecutionCallEnforcer.exposed_compareBytes(a, c));
    }

    ////////////////////////////// Failure Tests //////////////////////////////

    function test_ExactExecutionCallEnforcer_beforeHook_RevertIf_InvalidTarget() external {
        address expectedTarget = address(mockCall);

        bytes memory terms = abi.encodePacked(uint16(0), expectedTarget, hex"");

        Execution memory execution = Execution({
            // Invalid execution with a different target than the expected one in the terms.
            target: address(0),
            value: 0,
            callData: hex""
        });
        bytes memory executionCallData =
            ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData);

        vm.expectRevert(
            abi.encodeWithSelector(ExactExecutionCallEnforcer.InvalidTarget.selector, execution.target, expectedTarget)
        );
        exactExecutionCallEnforcer.beforeHook(
            terms, hex"", singleMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallEnforcer_beforeHook_RevertIf_InvalidCalldata() external {
        bytes memory expectedCalldata = abi.encodeWithSelector(MockCall.success.selector);

        bytes memory terms = abi.encodePacked(uint16(0), address(mockCall), expectedCalldata);

        Execution memory execution = Execution({
            target: address(mockCall),
            value: 0,
            // Invalid execution with a different callData than the expected one in the terms.
            callData: abi.encodeWithSelector(MockCall.throwError.selector)
        });
        bytes memory executionCallData =
            ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExactExecutionCallEnforcer.InvalidCalldata.selector, execution.callData, expectedCalldata
            )
        );
        exactExecutionCallEnforcer.beforeHook(
            terms, hex"", singleMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallEnforcer_getTermsInfo_RevertIf_InvalidTermsLength() external {
        // Terms should be at least 22 bytes long.
        bytes memory emptyTerms = new bytes(0);
        bytes memory shorterTerms = new bytes(20);

        vm.expectRevert(
            abi.encodeWithSelector(ExactExecutionCallEnforcer.InvalidTermsLength.selector, emptyTerms.length)
        );
        exactExecutionCallEnforcer.getTermsInfo(emptyTerms);

        vm.expectRevert(
            abi.encodeWithSelector(ExactExecutionCallEnforcer.InvalidTermsLength.selector, shorterTerms.length)
        );
        exactExecutionCallEnforcer.getTermsInfo(shorterTerms);
    }

    function test_ExactExecutionCallEnforcer_getExecutionCall_RevertIf_InvalidExecutionMode() external {
        CallType invalidCallType = CallType.wrap(0x02);
        ModeCode invalidMode =
            ModeLib.encode(invalidCallType, ExecType.wrap(0), ModeSelector.wrap(0), ModePayload.wrap(0x00));

        bytes memory executionCallData = new bytes(0);

        vm.expectRevert(abi.encodeWithSelector(ExactExecutionCallEnforcer.InvalidExecutionMode.selector, invalidMode));
        exactExecutionCallEnforcer.exposed_getExecutionCall(invalidMode, executionCallData, 0);
    }
}
