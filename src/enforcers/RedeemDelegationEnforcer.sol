// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2} from "forge-std/Console2.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { IDelegationManager } from "delegation-framework/src/interfaces/IDelegationManager.sol";
import { ModeCode, Delegation,Execution } from "delegation-framework/src/utils/Types.sol";

/**
 * @title RedeemDelegationEnforcer
 * @dev This contract enforces the execution of an external hook in the `afterAllHook` method.
 */
contract RedeemDelegationEnforcer is CaveatEnforcer {
    using ExecutionLib for bytes;
    ////////////////////////////// State //////////////////////////////

    /// @dev The Delegation Manager contract to redeem the delegation
    IDelegationManager public immutable delegationManager;

    ////////////////////////////// Errors //////////////////////////////

    error InvalidTermsLength(uint256 length);
    error InvalidTarget(address target, address expectedAddress);
    error InvalidMinCalldataLength(uint256 length);
    error InvalidMethodSignature(bytes4 signature, bytes4 expectedSig);
    error InvalidPermissionContextsLength(uint256 length);
    error InvalidDelegationsLength(uint256 length);
    error InvalidDelegationHash(bytes32 delegationHash, bytes32 expectedHash);

    ////////////////////////////// Constructor //////////////////////////////

    constructor(address _delegationManager) {
        delegationManager = IDelegationManager(_delegationManager);
    }

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
        (uint16 executionCallIndex, bytes32 expectedDelegationHash) = getTermsInfo(_terms);

        Execution[] calldata executions = _executionCallData.decodeBatch();

        Execution calldata targetExecution = executions[executionCallIndex];

        if (targetExecution.target != address(delegationManager)) {
            revert InvalidTarget(targetExecution.target, address(delegationManager));
        }

        if (targetExecution.callData.length < 4) {
            revert InvalidMinCalldataLength(targetExecution.callData.length);
        }

        bytes4 targetSig_ = bytes4(targetExecution.callData[0:4]);

        if (targetSig_ != IDelegationManager.redeemDelegations.selector) {
            revert InvalidMethodSignature(targetSig_, IDelegationManager.redeemDelegations.selector);
        }

        // TODO: Check delegation hash
        ( bytes[] memory _permissionContexts,, ) = abi.decode(
            targetExecution.callData[4:],
            (bytes[], ModeCode[], bytes[])
        );

        if(_permissionContexts.length !=1) {
            revert InvalidPermissionContextsLength(_permissionContexts.length);
        }

        Delegation[] memory delegations = abi.decode(_permissionContexts[0], (Delegation[]));

        if(delegations.length !=1) {
          revert InvalidDelegationsLength(delegations.length);
        }

      bytes32 delegationHash = EncoderLib._getDelegationHash(delegations[0]);
        
      if (delegationHash != expectedDelegationHash) {
          revert InvalidDelegationHash(delegationHash, expectedDelegationHash);
      }

    }

    /**
     * @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms encoded data that is used during the execution hooks.
     * @return executionCallIndex The index of the execution call.
     * @return delegationHash The hash of the delegation.
     */
    function getTermsInfo(bytes calldata _terms)
        public
        pure
        returns (uint16 executionCallIndex, bytes32 delegationHash)
    {
        if (_terms.length != 34) {
            revert InvalidTermsLength(_terms.length);
        }
        executionCallIndex = uint16(bytes2(_terms[:2]));
        delegationHash = bytes32(_terms[2:]);
    }
}
