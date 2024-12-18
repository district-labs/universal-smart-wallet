// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode, Execution } from "delegation-framework/src/utils/Types.sol";

/**
 * @title BatchExecutionCallIndexEnforcer
 * @dev This contract enforces the execution of an external hook in the `afterAllHook` method.
 */
contract BatchExecutionCallIndexEnforcer is CaveatEnforcer {
    using ExecutionLib for bytes;

    ////////////////////////////// Errors //////////////////////////////

    error InvalidTermsLength(uint256 length);
    error InvalidTarget(address target, address expectedAddress);
    error InvalidCalldata(bytes callData, bytes expectedCalldata);

    ////////////////////////////// Public Methods //////////////////////////////

    /**
     * @notice This function enforces that an external hook is executed before the execution has finished.
     * @param _terms packed bytes where: the first 2 bytes are the execution call index and the next 32 bytes are the
     * delegation hash.
     */
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
        (uint16 executionCallIndex, address target, bytes calldata callData) = getTermsInfo(_terms);

        Execution[] calldata executions = _executionCallData.decodeBatch();

        Execution calldata targetExecution = executions[executionCallIndex];

        if (targetExecution.target != target) {
            revert InvalidTarget(targetExecution.target, target);
        }

        if (!_compare(targetExecution.callData, callData)) {
            revert InvalidCalldata(targetExecution.callData, callData);
        }
    }

    /**
     * @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms encoded data that is used during the execution hooks.
     * @return executionCallIndex The execution call index.
     * @return target The target address.
     * @return callData The call data.
     */
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

    /**
     * @dev Compares two byte arrays for equality.
     * @param _a The first byte array.
     * @param _b The second byte array.
     * @return A boolean indicating whether the byte arrays are equal.
     */
    function _compare(bytes memory _a, bytes memory _b) private pure returns (bool) {
        return keccak256(_a) == keccak256(_b);
    }
}
