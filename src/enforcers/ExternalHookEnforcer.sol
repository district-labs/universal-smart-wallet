// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode } from "delegation-framework/src/utils/Types.sol";

/**
 * @title ExternalHookEnforcer
 * @dev This contract enforces the execution of an external hook in the `afterAllHook` method.
 */
contract ExternalHookEnforcer is CaveatEnforcer {
    ////////////////////////////// Errors //////////////////////////////
    error ExternalHookExecutionFailed(bytes revertData);
    error InvalidArgsLength(uint256 length);

    ////////////////////////////// Public Methods //////////////////////////////

    /**
     * @notice This function enforces that an external hook is executed after the execution has finished.
     * @param _args packed bytes where: the first 20 bytes are the address of the target contract, the next bytes
     * are the data that will be used in the call.
     */
    function afterHook(
        bytes calldata,
        bytes calldata _args,
        ModeCode,
        bytes calldata,
        bytes32,
        address,
        address
    )
        public
        override
    {
        (address target, bytes calldata data) = getArgsInfo(_args);

        (bool success, bytes memory revertData) = target.call(data);
        if (!success) {
            revert ExternalHookExecutionFailed(revertData);
        }
    }

    /**
     * @notice Decodes the args used in this CaveatEnforcer.
     * @param _args encoded data that is used during the execution hooks.
     * @return target The address of the contract that will be called.
     * @return data The data that will be used in the call.
     */
    function getArgsInfo(bytes calldata _args) public pure returns (address target, bytes calldata data) {
        if (_args.length < 20) {
            revert InvalidArgsLength(_args.length);
        }
        target = address(bytes20(_args[:20]));
        data = _args[20:];
    }
}
