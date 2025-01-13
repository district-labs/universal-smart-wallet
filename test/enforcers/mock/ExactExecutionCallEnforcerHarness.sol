// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ExactExecutionCallEnforcer } from "src/enforcers/ExactExecutionCallEnforcer.sol";
import { ModeCode, Execution } from "delegation-framework/src/utils/Types.sol";

contract ExactExecutionCallEnforcerHarness is ExactExecutionCallEnforcer {
    function exposed_getExecutionCall(
        ModeCode _mode,
        bytes calldata _executionCallData,
        uint16 _index
    )
        external
        pure
        returns (Execution memory execution)
    {
        return _getExecutionCall(_mode, _executionCallData, _index);
    }

    function exposed_compareBytes(bytes memory _a, bytes memory _b) external pure returns (bool) {
        return _compareBytes(_a, _b);
    }
}
