// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { console2 } from "forge-std/console2.sol";
import { ForkTest } from "test/fork/ForkTest.t.sol";
import { IPool } from "aave-v3-core/interfaces/IPool.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Delegation, Caveat, Execution, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { TestUser } from "test/utils/Types.t.sol";
import { Multicall } from "test/utils/Multicall.sol";

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExternalHookEnforcer } from "src/enforcers/ExternalHookEnforcer.sol";
import { ERC20BalanceGteAfterAllEnforcer } from "src/enforcers/ERC20BalanceGteAfterAllEnforcer.sol";
import { ERC20TransferAmountEnforcer } from "delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";

contract LimitOrder_ForkTest is ForkTest {
    using MessageHashUtils for bytes32;
    using ModeLib for ModeCode;

    // Contracts
    Multicall multicall;

    // Enforcers
    ERC20TransferAmountEnforcer erc20TransferAmountEnforcer;
    ExternalHookEnforcer externalHookEnforcer;
    ERC20BalanceGteAfterAllEnforcer erc20BalanceGteAfterAllEnforcer;

    // Users
    TestUser delegator;
    TestUser resolver;

    // Modes
    ModeCode[] oneSingleMode;

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // Setup Contracts
        multicall = new Multicall();

        // Setup Enforcers
        erc20TransferAmountEnforcer = new ERC20TransferAmountEnforcer();
        externalHookEnforcer = new ExternalHookEnforcer();
        erc20BalanceGteAfterAllEnforcer = new ERC20BalanceGteAfterAllEnforcer();

        // Setup Users
        delegator = users.alice;
        resolver = users.user2;

        // Setup Modes
        oneSingleMode = new ModeCode[](1);
        oneSingleMode[0] = ModeLib.encodeSimpleSingle();
    }

    ////////////////////////////// Utils //////////////////////////////
    function _setupSignLimitOrderDelegation(
        address _tokenOut,
        uint256 _amountOut,
        address _tokenIn,
        uint256 _amountIn,
        TestUser memory _delegator
    )
        internal
        returns (Delegation memory delegation)
    {
        // Limit Order Delegation Caveats //
        Caveat[] memory delegationCaveats = new Caveat[](3);

        // ERC20 Transfer Amount Enforcer
        // Makes sure the amount is transferred to the resolver
        delegationCaveats[0] = Caveat({
            args: hex"",
            enforcer: address(erc20TransferAmountEnforcer),
            terms: abi.encodePacked(_tokenOut, _amountOut)
        });

        // External Hook Enforcer
        // Let the resolver fulfill the delegation
        delegationCaveats[1] = Caveat({ args: hex"", enforcer: address(externalHookEnforcer), terms: hex"" });

        // ERC20 Balance Gte After All Enforcer
        delegationCaveats[2] = Caveat({
            args: hex"",
            enforcer: address(erc20BalanceGteAfterAllEnforcer),
            terms: abi.encodePacked(_tokenIn, _amountIn)
        });

        delegation = Delegation({
            delegate: ANY_DELEGATE,
            delegator: address(_delegator.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: delegationCaveats,
            salt: 0,
            signature: hex""
        });

        // Reassign the delegation with the signature
        delegation = signDelegation(_delegator, delegation);
    }

    function _setupRedeemLimitOrderDelegation(
        address _tokenOut,
        uint256 _amountOut,
        address _tokenIn,
        uint256 _amountIn,
        Delegation memory _delegation
    )
        internal
        returns (bytes[] memory permissionContexts, bytes[] memory executionCallDatas)
    {
        // Setup hook executions
        Execution[] memory hookExecutions = new Execution[](2);
        // Execution 1: Approves the tokenOut to the Aave Pool
        hookExecutions[0] = Execution({
            target: address(_tokenOut),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.approve.selector, address(AAVE_POOL), _amountOut)
        });
        // Execution 2: Deposits the tokenOut to the Aave Pool
        hookExecutions[1] = Execution({
            target: address(AAVE_POOL),
            value: 0,
            callData: abi.encodeWithSelector(IPool.supply.selector, _tokenOut, _amountOut, address(delegator.deleGator), 0)
        });

        // Update the delegation to update the external hook enforcer args
        _delegation.caveats[1].args =
            abi.encodePacked(address(multicall), abi.encodeWithSelector(multicall.multicall.selector, hookExecutions));

        // Setup Permission Contexts
        Delegation[] memory delegations = new Delegation[](1);
        delegations[0] = _delegation;
        permissionContexts = new bytes[](1);
        permissionContexts[0] = abi.encode(delegations);

        // Setup Execution Calldatas
        executionCallDatas = new bytes[](1);
        Execution memory execution = Execution({
            target: address(_tokenOut),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, address(multicall), _amountOut)
        });
        executionCallDatas[0] = ExecutionLib.encodeSingle(execution.target, execution.value, execution.callData);
    }

    ////////////////////////////// Tests //////////////////////////////

    function test_limit_order_success() external {
        address tokenOut = address(USDC);
        address tokenIn = address(AUSDC);
        uint256 amountOut = 1000e6;
        uint256 amountIn = 1000e6;

        // Deal USDC tokens to the delegator
        vm.prank(USDC_WHALE);
        IERC20(tokenOut).transfer(address(delegator.deleGator), amountOut);

        // Check initial balances
        uint256 initialDelegatorTokenOutBalance = IERC20(tokenOut).balanceOf(address(delegator.deleGator));
        uint256 initialMulticallTokenOutBalance = IERC20(tokenOut).balanceOf(address(multicall));
        uint256 initialDelegatorTokenInBalance = IERC20(tokenIn).balanceOf(address(delegator.deleGator));

        console2.log("Initial Delegator Token Out Balance: ", initialDelegatorTokenOutBalance);
        console2.log("Initial Delegator Token In Balance: ", initialDelegatorTokenInBalance);

        // Delegator sets up and signs a limit order delegation
        Delegation memory limitOrderDelegation =
            _setupSignLimitOrderDelegation(tokenOut, amountOut, tokenIn, amountIn, delegator);

        // Delegate Redeems the limit order
        vm.startPrank(resolver.addr);
        (bytes[] memory permissionContexts, bytes[] memory executionCallDatas) =
            _setupRedeemLimitOrderDelegation(tokenOut, amountOut, tokenIn, amountIn, limitOrderDelegation);

        delegationManager.redeemDelegations(permissionContexts, oneSingleMode, executionCallDatas);

        // Check final balances
        uint256 finalDelegatorTokenOutBalance = IERC20(tokenOut).balanceOf(address(delegator.deleGator));
        uint256 finalDelegatorTokenInBalance = IERC20(tokenIn).balanceOf(address(delegator.deleGator));
        uint256 finalMulticallTokenOutBalance = IERC20(tokenOut).balanceOf(address(multicall));

        console2.log("Final Delegator Token Out Balance: ", finalDelegatorTokenOutBalance);
        console2.log("Final Delegator Token In Balance: ", finalDelegatorTokenInBalance);

        // Check the balances
        assertEq(finalDelegatorTokenOutBalance, initialDelegatorTokenOutBalance - amountOut);
        assertEq(finalDelegatorTokenInBalance, initialDelegatorTokenInBalance + amountIn);

        vm.stopPrank();
    }
}
