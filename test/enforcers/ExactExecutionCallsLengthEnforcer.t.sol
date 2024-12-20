// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { Execution, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { BaseTest } from "test/utils/BaseTest.t.sol";
import { MockCall } from "test/utils/MockCall.sol";
import { ExactExecutionCallsLengthEnforcer } from "../../src/enforcers/ExactExecutionCallsLengthEnforcer.sol";

contract ExactExecutionCallsLengthEnforcer_Test is BaseTest {
    using ModeLib for ModeCode;

    ////////////////////////////// State //////////////////////////////

    // Contracts
    MockCall public mockCall;
    ExactExecutionCallsLengthEnforcer public exactExecutionCallsLengthEnforcer;

    // Mode
    ModeCode public singleExecutionMode = ModeLib.encodeSimpleSingle();
    ModeCode public batchExecutionMode = ModeLib.encodeSimpleBatch();

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        mockCall = new MockCall();
        exactExecutionCallsLengthEnforcer = new ExactExecutionCallsLengthEnforcer();
    }

    ////////////////////////////// Success Tests //////////////////////////////

    function test_ExactExecutionCallsLengthEnforcer_beforeHook_validExecutionCallsLength() external {
        uint16 expectedCallsLength = 2;
        bytes memory terms = abi.encodePacked(uint16(expectedCallsLength));

        Execution[] memory executions = new Execution[](2);
        executions[0] = Execution({
            target: address(mockCall),
            value: 0,
            callData: abi.encodeWithSelector(MockCall.success.selector)
        });

        executions[1] = Execution({
            target: address(mockCall),
            value: 0,
            callData: abi.encodeWithSelector(MockCall.success.selector)
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);
        exactExecutionCallsLengthEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallsLengthEnforcer_getTermsInfo_validTerms() external {
        uint16 executionCallsLength = 3;
        // Should be valid if the terms are 2 bytes
        bytes memory terms = abi.encodePacked(uint16(executionCallsLength));

        uint256 termsExecutionCallsLength = exactExecutionCallsLengthEnforcer.getTermsInfo(terms);

        assertEq(termsExecutionCallsLength, executionCallsLength);
    }

    ////////////////////////////// Failure Tests //////////////////////////////

    function test_ExactExecutionCallsLengthEnforcer_beforeHook_RevertIf_singleExecutionMode() external {
        vm.expectRevert("CaveatEnforcer:invalid-call-type");
        exactExecutionCallsLengthEnforcer.beforeHook(
            hex"", hex"", singleExecutionMode, hex"", bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallsLengthEnforcer_beforeHook_RevertIf_InvalidExecutionCallsLength() external {
        uint16 expectedCallsLength = 3;
        bytes memory terms = abi.encodePacked(uint16(expectedCallsLength));

        Execution[] memory executions = new Execution[](1);
        executions[0] = Execution({
            target: address(mockCall),
            value: 0,
            callData: abi.encodeWithSelector(MockCall.success.selector)
        });

        bytes memory executionCallData = ExecutionLib.encodeBatch(executions);

        vm.expectRevert(
            abi.encodeWithSelector(
                ExactExecutionCallsLengthEnforcer.InvalidExecutionCallsLength.selector, executions.length
            )
        );
        exactExecutionCallsLengthEnforcer.beforeHook(
            terms, hex"", batchExecutionMode, executionCallData, bytes32(0), address(0), address(0)
        );
    }

    function test_ExactExecutionCallsLengthEnforcer_getTermsInfo_RevertIf_InvalidTermsLength() external {
        bytes memory terms = new bytes(0);

        // Should revert if the terms are empty
        vm.expectRevert(
            abi.encodeWithSelector(ExactExecutionCallsLengthEnforcer.InvalidTermsLength.selector, terms.length)
        );
        exactExecutionCallsLengthEnforcer.getTermsInfo(terms);

        // Should revert if the terms are not 2 bytes
        terms = new bytes(3);
        vm.expectRevert(
            abi.encodeWithSelector(ExactExecutionCallsLengthEnforcer.InvalidTermsLength.selector, terms.length)
        );
        exactExecutionCallsLengthEnforcer.getTermsInfo(terms);
    }
}
