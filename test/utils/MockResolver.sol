// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockResolver {
    function transfer(address token, address to, uint256 amount) external {
        IERC20(token).transfer(to, amount);
    }
}
