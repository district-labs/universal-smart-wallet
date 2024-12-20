// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode, Execution } from "delegation-framework/src/utils/Types.sol";

/// @title Exact Execution Calls Length Enforcer
/// @dev This contract enforces the execution of an exact number of calls in the batch execution. It only supports in
/// batch execution mode.
contract ExactExecutionCallsLengthEnforcer is CaveatEnforcer {
    using ExecutionLib for bytes;

    ////////////////////////////// Error //////////////////////////////

    /// @notice Thrown when the length of the execution calls is invalid.
    error InvalidExecutionCallsLength(uint256 executionCallsLength);

    /// @notice Thrown when the length of the terms is invalid.
    error InvalidTermsLength(uint256 length);

    ////////////////////////////// Public Methods //////////////////////////////

    /// @notice Allows the delegator to specify an exact number of calls that the batch execution calldata can have.
    /// @param _terms encoded data that is used during the execution hooks.
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
        onlyBatchExecutionMode(_mode)
    {
        uint256 executionCallsLength = getTermsInfo(_terms);
        Execution[] calldata executions = _executionCallData.decodeBatch();

        if (executions.length != executionCallsLength) {
            revert InvalidExecutionCallsLength(executions.length);
        }
    }

    /**
     * /// @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms data of the execution calls length in uint16 encoded as a bytes.
     * @return executionCallsLength The exact amount of calls that the execution calldata can have.
     */
    function getTermsInfo(bytes calldata _terms) public pure returns (uint16 executionCallsLength) {
        if (_terms.length != 2) {
            revert InvalidTermsLength(_terms.length);
        }
        executionCallsLength = uint16(bytes2(_terms));
    }
}
