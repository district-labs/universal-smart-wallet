// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode, Execution } from "delegation-framework/src/utils/Types.sol";
import { CALLTYPE_SINGLE, CALLTYPE_BATCH } from "delegation-framework/src/utils/Constants.sol";

/// @title Exact Execution Call Enforcer
/// @dev This contract enforces the execution call to contain the exact target and calldata. It supports both single and
/// batch execution modes. In batch execution mode, the index term is used to specify the execution call index.
contract ExactExecutionCallEnforcer is CaveatEnforcer {
    using ModeLib for ModeCode;
    using ExecutionLib for bytes;

    ////////////////////////////// Errors //////////////////////////////

    /// @notice Thrown when the execution calldata is invalid.
    /// @param callData The execution calldata.
    /// @param expectedCalldata The expected calldata.
    error InvalidCalldata(bytes callData, bytes expectedCalldata);

    /// @notice Thrown when the execution target address is invalid.
    /// @param target The execution target address.
    /// @param expectedTarget The expected target address.
    error InvalidTarget(address target, address expectedTarget);

    /// @notice Thrown when the length of the terms is invalid.
    /// @param length The length of the terms.
    error InvalidTermsLength(uint256 length);

    /// @notice Thrown when the execution mode is invalid.
    /// @param mode The execution mode.
    error InvalidExecutionMode(ModeCode mode);

    ////////////////////////////// Public Methods //////////////////////////////

    /// @notice This function enforces a specific execution target and calldata. If in single execution mode, it will
    /// check the target and calldata of the execution. If in batch execution mode, it will check the target and
    /// calldata of the execution at the specified index.
    /// @param _terms packed bytes where: the first 2 bytes are the execution call index, the next 20 bytes are the
    /// target address, and the rest is the calldata.
    /// @param _mode execution mode.
    /// @param _executionCallData encoded calls, either single or batch.
    function beforeHook(
        bytes calldata _terms,
        bytes calldata,
        ModeCode _mode,
        bytes calldata _executionCallData,
        bytes32,
        address,
        address
    )
        public
        override
    {
        (uint16 executionCallIndex, address target, bytes calldata callData) = getTermsInfo(_terms);

        Execution memory execution = _getExecutionCall(_mode, _executionCallData, executionCallIndex);

        if (execution.target != target) {
            revert InvalidTarget(execution.target, target);
        }

        if (!_compareBytes(execution.callData, callData)) {
            revert InvalidCalldata(execution.callData, callData);
        }
    }

    /// @notice Decodes the terms used in this CaveatEnforcer.
    /// @param _terms encoded data that is used during the execution hooks.
    /// @return executionCallIndex The execution call index, only used in batch execution mode.
    /// @return target The target address.
    /// @return callData The call data.
    function getTermsInfo(bytes calldata _terms)
        public
        pure
        returns (uint16 executionCallIndex, address target, bytes calldata callData)
    {
        if (_terms.length < 22) {
            revert InvalidTermsLength(_terms.length);
        }
        executionCallIndex = uint16(bytes2(_terms));
        target = address(bytes20(_terms[2:22]));
        callData = _terms[22:];
    }

    ////////////////////////////// Internal Methods //////////////////////////////

    /// @dev Gets the execution call from the execution callData in both single and batch modes.
    /// @param _mode The execution mode.
    /// @param _executionCallData The execution call data.
    /// @param _index The index of the execution call.
    function _getExecutionCall(
        ModeCode _mode,
        bytes calldata _executionCallData,
        uint16 _index
    )
        internal
        pure
        returns (Execution memory execution)
    {
        if (ModeLib.getCallType(_mode) == CALLTYPE_SINGLE) {
            (address target, uint256 value, bytes calldata callData) = _executionCallData.decodeSingle();
            execution = Execution({ target: target, value: value, callData: callData });
            return execution;
        }

        if (ModeLib.getCallType(_mode) == CALLTYPE_BATCH) {
            Execution[] calldata executions = _executionCallData.decodeBatch();
            execution = executions[_index];
            return execution;
        }

        // If the mode is not single or batch, revert
        revert InvalidExecutionMode(_mode);
    }

    /// @dev Compares two byte arrays for equality.
    /// @param _a The first byte array.
    /// @param _b The second byte array.
    /// @return A boolean indicating whether the byte arrays are equal.
    function _compareBytes(bytes memory _a, bytes memory _b) internal pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }
}
