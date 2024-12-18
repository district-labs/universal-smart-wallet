// SPDX-License-Identifier: MIT AND Apache-2.0
pragma solidity 0.8.23;

import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode, Execution } from "delegation-framework/src/utils/Types.sol";

/**
 * @title Exact Execution Calls Length Enforcer Contract
 * @dev This contract extends the CaveatEnforcer contract. It provides functionality to enforce a specific amount of
 * calls that a execution calldata can have.
 */
contract ExactExecutionCallsLengthEnforcer is CaveatEnforcer {
    using ExecutionLib for bytes;
    ////////////////////////////// Error //////////////////////////////

    error InvalidTermsLength(uint256 length);
    error InvalidExecutionCallsLength(uint256 executionCallsLength);

    ////////////////////////////// Public Methods //////////////////////////////

    /**
     * @notice Allows the delegator to specify a maximum number of times the recipient may perform transactions on their
     * behalf.
     * @param _terms - The exact amount of calls that the execution calldata can have.
     */
    function beforeHook(
        bytes calldata _terms,
        bytes calldata,
        ModeCode _mode,
        bytes calldata _executionCallData,
        bytes32,
        address,
        address _redeemer
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
     * @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms encoded data that is used during the execution hooks.
     * @return executionCallsLength The exact amount of calls that the execution calldata can have.
     */
    function getTermsInfo(bytes calldata _terms) public pure returns (uint16 executionCallsLength) {
        if (_terms.length != 2) {
            revert InvalidTermsLength(_terms.length);
        }
        executionCallsLength = uint16(bytes2(_terms));
    }
}
