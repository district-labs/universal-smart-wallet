// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

contract MockCall {
    error ThrowError();

    function success() external { }

    function throwError() external {
        revert ThrowError();
    }
}
