// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { console2 } from "forge-std/console2.sol";
import { BaseTest, ERC20Mintable } from "test/utils/BaseTest.t.sol";
import { MockResolver } from "test/utils/MockResolver.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { Delegation, Caveat, Execution, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";

import { TestUser } from "test/utils/Types.t.sol";

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ExactExecutionCallsLengthEnforcer } from "../../src/enforcers/ExactExecutionCallsLengthEnforcer.sol";
import { ExactExecutionCallEnforcer } from "../../src/enforcers/ExactExecutionCallEnforcer.sol";
import { ExternalHookEnforcer } from "../../src/enforcers/ExternalHookEnforcer.sol";
import { DelegationRedemptionEnforcer } from "../../src/enforcers/DelegationRedemptionEnforcer.sol";
import { ERC20BalanceGteAfterAllEnforcer } from "../../src/enforcers/ERC20BalanceGteAfterAllEnforcer.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { ERC20TransferAmountEnforcer } from "delegation-framework/src/enforcers/ERC20TransferAmountEnforcer.sol";
import { NativeBalanceGteEnforcer } from "delegation-framework/src/enforcers/NativeBalanceGteEnforcer.sol";

contract ERC20SwapRecursive_Test is BaseTest {
    using MessageHashUtils for bytes32;
    using ModeLib for ModeCode;

    // Contracts
    ERC20Mintable usdc;
    ERC20Mintable ptusdc;
    MockResolver mockResolver;

    // Enforcers
    ERC20TransferAmountEnforcer erc20TransferAmountEnforcer;
    NativeBalanceGteEnforcer nativeBalanceGteEnforcer;
    ExternalHookEnforcer externalHookEnforcer;
    ERC20BalanceGteAfterAllEnforcer erc20BalanceGteAfterAllEnforcer;
    DelegationRedemptionEnforcer delegationRedemptionEnforcer;
    ExactExecutionCallsLengthEnforcer exactExecutionCallsLengthEnforcer;
    ExactExecutionCallEnforcer exactExecutionCallEnforcer;

    // Users
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
        nativeBalanceGteEnforcer = new NativeBalanceGteEnforcer();
        externalHookEnforcer = new ExternalHookEnforcer();
        erc20BalanceGteAfterAllEnforcer = new ERC20BalanceGteAfterAllEnforcer();
        delegationRedemptionEnforcer = new DelegationRedemptionEnforcer();
        exactExecutionCallsLengthEnforcer = new ExactExecutionCallsLengthEnforcer();
        exactExecutionCallEnforcer = new ExactExecutionCallEnforcer();

        // Setup Users
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
        Caveat[] memory delegationCaveats = new Caveat[](2);

        // ERC20 Transfer Amount Enforcer
        // Makes sure the amount is transferred to the resolver
        delegationCaveats[0] = Caveat({
            args: hex"",
            enforcer: address(erc20TransferAmountEnforcer),
            terms: abi.encodePacked(_tokenOut, _amountOut)
        });

        // Native Balance Gte Enforcer
        // Ensures the redeemer can't use the native token balance of the delegator
        delegationCaveats[1] = Caveat({
            args: hex"",
            enforcer: address(nativeBalanceGteEnforcer),
            terms: abi.encodePacked(address(_delegator.deleGator), uint256(0))
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
        address _tokenOut,
        uint256 _amountOutTotal,
        address _tokenIn,
        uint256 _amountIn,
        TestUser memory _delegator,
        Delegation memory nestedDelegation
    )
        internal
        returns (Delegation memory delegation)
    {
        // Limit Order Delegation Caveats //
        Caveat[] memory delegationCaveats = new Caveat[](6);

        // External Hook Enforcer
        // Let the resolver fulfill the delegation
        delegationCaveats[0] = Caveat({ args: hex"", enforcer: address(externalHookEnforcer), terms: hex"" });

        // ERC20 Balance Gte After All Enforcer
        delegationCaveats[1] = Caveat({
            args: hex"",
            enforcer: address(erc20BalanceGteAfterAllEnforcer),
            terms: abi.encodePacked(_tokenIn, _amountIn)
        });

        // Limit the number of calls to 2
        delegationCaveats[2] = Caveat({
            args: hex"",
            enforcer: address(exactExecutionCallsLengthEnforcer),
            terms: abi.encodePacked(uint16(2))
        });

        // Enforce the redemption of the nested delegation in the first execution call
        delegationCaveats[3] = Caveat({
            args: hex"",
            enforcer: address(delegationRedemptionEnforcer),
            terms: abi.encodePacked(uint16(0), address(delegationManager), EncoderLib._getDelegationHash(nestedDelegation))
        });

        // Enforce the transfer of the delegated amount and the balance amount to the resolver in the second execution
        // call
        delegationCaveats[4] = Caveat({
            args: hex"",
            enforcer: address(exactExecutionCallEnforcer),
            terms: abi.encodePacked(
                uint16(1),
                address(_tokenOut),
                abi.encodeWithSelector(IERC20.transfer.selector, address(mockResolver), _amountOutTotal)
            )
        });

        // Enforce the redeemer can't use the native token balance of the delegator
        delegationCaveats[5] = Caveat({
            args: hex"",
            enforcer: address(nativeBalanceGteEnforcer),
            terms: abi.encodePacked(address(_delegator.deleGator), uint256(0))
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
        uint256 _delegatedAmountOut;
        uint256 _balanceAmountOut;
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
                IERC20.transfer.selector, address(_params._delegation.delegator), _params._delegatedAmountOut
            )
        });
        nestedExecutionCallDatas[0] =
            ExecutionLib.encodeSingle(nestedExecution.target, nestedExecution.value, nestedExecution.callData);

        // Update the delegation external hook enforcer args
        _params._delegation.caveats[0].args = abi.encodePacked(
            address(mockResolver),
            abi.encodeWithSelector(
                mockResolver.transfer.selector, _params._tokenIn, address(users.bob.deleGator), _params._amountIn
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
                IERC20.transfer.selector, address(mockResolver), _params._delegatedAmountOut + _params._balanceAmountOut
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

        vm.deal(address(users.alice.deleGator), 1000);

        // Alice delegates an ERC20 transfer to the delegator
        Delegation memory erc20TransferDelegation =
            _setupSignErc20TransferAmountDelegation(tokenOut, aliceAmountOut, tokenIn, amountIn, users.alice, users.bob);

        // Mint the tokens
        ERC20Mintable(tokenOut).mint(address(users.alice.deleGator), aliceAmountOut);
        ERC20Mintable(tokenOut).mint(address(users.bob.deleGator), delegatorAmountOut);
        ERC20Mintable(tokenIn).mint(address(mockResolver), amountIn);

        // Check initial balances
        uint256 initialAliceTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.alice.deleGator));
        uint256 initialBobTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.bob.deleGator));
        uint256 initialBobTokenInBalance = IERC20(tokenIn).balanceOf(address(users.bob.deleGator));

        console2.log("Initial Alice Token Out Balance: ", initialAliceTokenOutBalance);
        console2.log("Initial Bob Token Out Balance: ", initialBobTokenOutBalance);
        console2.log("Initial Bob Token In Balance: ", initialBobTokenInBalance);

        // Delegator signs an empty delegation (for testing purposes only)
        Delegation memory emptyDelegation = _setupSignMainDelegation(
            tokenOut, aliceAmountOut + delegatorAmountOut, tokenIn, amountIn, users.bob, erc20TransferDelegation
        );

        Params memory params = Params({
            _tokenOut: tokenOut,
            _delegatedAmountOut: aliceAmountOut,
            _balanceAmountOut: delegatorAmountOut,
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
        uint256 finalAliceTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.alice.deleGator));
        uint256 finalBobTokenOutBalance = IERC20(tokenOut).balanceOf(address(users.bob.deleGator));
        uint256 finalBobTokenInBalance = IERC20(tokenIn).balanceOf(address(users.bob.deleGator));

        console2.log("Final Alice Token Out Balance: ", finalAliceTokenOutBalance);
        console2.log("Final Bob Token Out Balance: ", finalBobTokenOutBalance);
        console2.log("Final Bob Token In Balance: ", finalBobTokenInBalance);

        // Check the balances
        assertEq(finalAliceTokenOutBalance, initialAliceTokenOutBalance - aliceAmountOut);
        assertEq(finalBobTokenOutBalance, initialBobTokenOutBalance - delegatorAmountOut);
        assertEq(finalBobTokenInBalance, initialBobTokenInBalance + amountIn);

        vm.stopPrank();
    }
}
