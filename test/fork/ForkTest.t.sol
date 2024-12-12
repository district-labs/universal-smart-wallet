// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";
import { PrizeVault } from "pt-v5-vault/src/PrizeVault.sol";
import { IPool } from "aave-v3-core/interfaces/IPool.sol";

contract ForkTest is BaseTest {
    address internal constant USDC_WHALE = 0x122fDD9fEcbc82F7d4237C0549a5057E31c8EF8D;

    IERC20 internal constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 internal constant AUSDC = IERC20(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB);
    PrizeVault internal constant przUSDC = PrizeVault(0x7f5C2b379b88499aC2B997Db583f8079503f25b9);
    IERC20 internal constant WETH = IERC20(0x4200000000000000000000000000000000000006);

    IPool internal constant AAVE_POOL = IPool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5);

    uint256 internal constant FORK_TIMESTAMP = 23_565_000;

    function setUp() public virtual override {
        super.setUp();
        // Fork Base
        vm.createSelectFork({ blockNumber: FORK_TIMESTAMP, urlOrAlias: "base" });
    }
}
