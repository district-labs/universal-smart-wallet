// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Execution } from "delegation-framework/src/utils/Types.sol";

contract Multicall {
    error CallReverted(uint256 index, bytes data);

    function multicall(Execution[] calldata _executions) external {
        for (uint256 i = 0; i < _executions.length; i++) {
            (bool success, bytes memory data) =
                _executions[i].target.call{ value: _executions[i].value }(_executions[i].callData);

            if (!success) {
                revert CallReverted(i, data);
            }
        }
    }
}
