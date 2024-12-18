// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { console2 } from "forge-std/console2.sol";
import { BaseTest, ERC20Mintable } from "test/utils/BaseTest.t.sol";
import { MockResolver } from "test/utils/MockResolver.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { Delegation, Caveat, Execution, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";

import { TestUser } from "test/utils/Types.t.sol";

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExternalHookEnforcer } from "../../src/enforcers/ExternalHookEnforcer.sol";
import { ERC20BalanceGteAfterAllEnforcer } from "../../src/enforcers/ERC20BalanceGteAfterAllEnforcer.sol";
import { ERC20TransferAmountEnforcer } from "delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";

contract LimitOrder_Test is BaseTest {
    using MessageHashUtils for bytes32;
    using ModeLib for ModeCode;

    // Contracts
    ERC20Mintable usdc;
    ERC20Mintable ptusdc;
    MockResolver mockResolver;

    // Enforcers
    ERC20TransferAmountEnforcer erc20TransferAmountEnforcer;
    ExternalHookEnforcer externalHookEnforcer;
    ERC20BalanceGteAfterAllEnforcer erc20BalanceGteAfterAllEnforcer;

    // Users
    TestUser delegator;
    TestUser resolver;

    // Modes
    ModeCode[] oneSingleMode;
    ModeCode[] oneBatchMode;

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        // Setup Contracts
        usdc = new ERC20Mintable("USD Coin", "USDC");
        ptusdc = new ERC20Mintable("PoolTogether USDC", "PTUSDC");
        mockResolver = new MockResolver();

        // Setup Enforcers
        erc20TransferAmountEnforcer = new ERC20TransferAmountEnforcer();
        externalHookEnforcer = new ExternalHookEnforcer();
        erc20BalanceGteAfterAllEnforcer = new ERC20BalanceGteAfterAllEnforcer();

        // Setup Users
        delegator = users.user1;
        resolver = users.user2;

        // Setup Modes
        oneSingleMode = new ModeCode[](1);
        oneSingleMode[0] = ModeLib.encodeSimpleSingle();

        oneBatchMode = new ModeCode[](1);
        oneBatchMode[0] = ModeLib.encodeSimpleBatch();
    }

    ////////////////////////////// Utils //////////////////////////////

    function _setupSignErc20TransferAmountDelegation(
        address _tokenOut,
        uint256 _amountOut,
        address _tokenIn,
        uint256 _amountIn,
        TestUser memory _delegator,
        TestUser memory _delegate
    )
        internal
        returns (Delegation memory delegation)
    {
        // Limit Order Delegation Caveats //
        Caveat[] memory delegationCaveats = new Caveat[](1);

        // ERC20 Transfer Amount Enforcer
        // Makes sure the amount is transferred to the resolver
        delegationCaveats[0] = Caveat({
            args: hex"",
            enforcer: address(erc20TransferAmountEnforcer),
            terms: abi.encodePacked(_tokenOut, _amountOut)
        });

        delegation = Delegation({
            delegate: address(_delegate.deleGator),
            delegator: address(_delegator.deleGator),
            authority: ROOT_AUTHORITY,
            caveats: delegationCaveats,
            salt: 0,
            signature: hex""
        });

        // Reassign the delegation with the signature
        delegation = signDelegation(_delegator, delegation);
    }

    function _setupSignMainDelegation(
        address _tokenIn,
        uint256 _amountIn,
        TestUser memory _delegator
    )
        internal
        returns (Delegation memory delegation)
    {
        // Limit Order Delegation Caveats //
        Caveat[] memory delegationCaveats = new Caveat[](2);

        // External Hook Enforcer
        // Let the resolver fulfill the delegation
        delegationCaveats[0] = Caveat({ args: hex"", enforcer: address(externalHookEnforcer), terms: hex"" });

        // ERC20 Balance Gte After All Enforcer
        delegationCaveats[1] = Caveat({
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

    struct Params {
        address _tokenOut;
        uint256 _delegatedAmountOutOut;
        uint256 _balanceAmountOutOut;
        address _tokenIn;
        uint256 _amountIn;
        Delegation _delegation;
        Delegation _nestedDelegation;
    }

    function _setupRedeemNestedDelegation(Params memory _params)
        internal
        returns (bytes[] memory permissionContexts, bytes[] memory executionCallDatas)
    {
        // Setup Permission Contexts of nested delegation
        Delegation[] memory nestedDelegations = new Delegation[](1);
        nestedDelegations[0] = _params._nestedDelegation;
        bytes[] memory nestedPermissionContexts = new bytes[](1);
        nestedPermissionContexts[0] = abi.encode(nestedDelegations);
        // Setup Execution Calldatas
        bytes[] memory nestedExecutionCallDatas = new bytes[](1);
        Execution memory nestedExecution = Execution({
            target: address(_params._tokenOut),
            value: 0,
            callData: abi.encodeWithSelector(
                IERC20.transfer.selector, address(_params._delegation.delegator), _params._delegatedAmountOutOut
            )
        });
        nestedExecutionCallDatas[0] =
            ExecutionLib.encodeSingle(nestedExecution.target, nestedExecution.value, nestedExecution.callData);

        // Update the delegation external hook enforcer args
        _params._delegation.caveats[0].args = abi.encodePacked(
            address(mockResolver),
            abi.encodeWithSelector(
                mockResolver.transfer.selector, _params._tokenIn, address(delegator.deleGator), _params._amountIn
            )
        );

        // Setup Permission Contexts of main delegation
        Delegation[] memory delegations = new Delegation[](1);
        delegations[0] = _params._delegation;
        permissionContexts = new bytes[](1);
        permissionContexts[0] = abi.encode(delegations);

        // Setup Execution Calldatas
        executionCallDatas = new bytes[](1);
        Execution[] memory executions = new Execution[](2);

        // The first execution will redeem the nested delegation
        executions[0] = Execution({
            target: address(delegationManager),
            value: 0,
            callData: abi.encodeWithSelector(
                DelegationManager.redeemDelegations.selector,
                nestedPermissionContexts,
                oneSingleMode,
                nestedExecutionCallDatas
            )
        });

        // The second execution will send the delegated amount and the balance amount to the mock resolver
        executions[1] = Execution({
            target: address(_params._tokenOut),
            value: 0,
            callData: abi.encodeWithSelector(
                IERC20.transfer.selector,
                address(mockResolver),
                _params._delegatedAmountOutOut + _params._balanceAmountOutOut
            )
        });

        executionCallDatas[0] = ExecutionLib.encodeBatch(executions);
    }

    ////////////////////////////// Tests //////////////////////////////

    function test_limit_order_nested_delegation_success() external {
        address tokenOut = address(usdc);
        address tokenIn = address(ptusdc);

        uint256 aliceAmountOut = 500e6;
        uint256 delegatorAmountOut = 250e6;
        uint256 amountIn = aliceAmountOut + delegatorAmountOut;

        // Alice delegates an ERC20 transfer to the delegator
        Delegation memory erc20TransferDelegation =
            _setupSignErc20TransferAmountDelegation(tokenOut, aliceAmountOut, tokenIn, amountIn, users.alice, delegator);

        // Mint the tokens
        ERC20Mintable(tokenOut).mint(address(users.alice.deleGator), aliceAmountOut);
        ERC20Mintable(tokenOut).mint(address(delegator.deleGator), delegatorAmountOut);
        ERC20Mintable(tokenIn).mint(address(mockResolver), amountIn);

        // Check initial balances
        uint256 initialAliceTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.alice.deleGator));
        uint256 initialDelegatorTokenOutBalance = IERC20(tokenOut).balanceOf(address(delegator.deleGator));
        uint256 initialDelegatorTokenInBalance = IERC20(tokenIn).balanceOf(address(delegator.deleGator));

        console2.log("Initial Alice Token Out Balance: ", initialAliceTokenOutBalance);
        console2.log("Initial Delegator Token Out Balance: ", initialDelegatorTokenOutBalance);
        console2.log("Initial Delegator Token In Balance: ", initialDelegatorTokenInBalance);

        // Delegator signs an empty delegation (for testing purposes only)

        Delegation memory emptyDelegation = _setupSignMainDelegation(tokenIn, amountIn, delegator);

        Params memory params = Params({
            _tokenOut: tokenOut,
            _delegatedAmountOutOut: aliceAmountOut,
            _balanceAmountOutOut: delegatorAmountOut,
            _tokenIn: tokenIn,
            _amountIn: amountIn,
            _delegation: emptyDelegation,
            _nestedDelegation: erc20TransferDelegation
        });
        // Delegate Redeems the limit order
        vm.startPrank(resolver.addr);
        (bytes[] memory permissionContexts, bytes[] memory executionCallDatas) = _setupRedeemNestedDelegation(params);

        delegationManager.redeemDelegations(permissionContexts, oneBatchMode, executionCallDatas);

        // Get final balances
        // uint256 finalAliceTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.alice.deleGator));
        uint256 finalDelegatorTokenOutBalance = IERC20(tokenOut).balanceOf(address(delegator.deleGator));
        uint256 finalDelegatorTokenInBalance = IERC20(tokenIn).balanceOf(address(delegator.deleGator));

        // console2.log("Final Alice Token Out Balance: ", finalAliceTokenOutBalance);
        console2.log("Final Delegator Token Out Balance: ", finalDelegatorTokenOutBalance);
        console2.log("Final Delegator Token In Balance: ", finalDelegatorTokenInBalance);

        // // Check the balances
        // assertEq(finalAliceTokenOutBalance, initialAliceTokenOutBalance - amountOut);
        // assertEq(finalDelegatorTokenInBalance, initialDelegatorTokenInBalance + amountIn);

        vm.stopPrank();
    }
}