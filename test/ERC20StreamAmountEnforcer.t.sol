pragma solidity 0.8.23;

import { BaseTest, ERC20Mintable } from "test/utils/BaseTest.t.sol";
import { ERC20StreamAmountEnforcer } from "src/enforcers/ERC20StreamAmountEnforcer.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { Delegation, Caveat, Execution, PackedUserOperation, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { ERC1271Lib } from "delegation-framework/src/libraries/ERC1271Lib.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";

contract ERC20StreamAmountEnforcer_Test is BaseTest {
    using ModeLib for ModeCode;

    ERC20StreamAmountEnforcer streamAmountEnforcer;
    ModeCode[] _oneSingularMode;

    function setUp() public virtual override {
        super.setUp();

        streamAmountEnforcer = new ERC20StreamAmountEnforcer();
        _oneSingularMode = new ModeCode[](1);
        _oneSingularMode[0] = ModeLib.encodeSimpleSingle();
    }

    function test_getTermsInfo() external {
        // Test the getTermsInfo function with human-readable timestamps
        bytes memory terms = abi.encodePacked(
            address(erc20),
            uint256(100e18),
            uint128(1733011200), // 2024-12-01T00:00:00Z
            uint128(1734134400)  // 2024-12-14T00:00:00Z
        );

        (address allowedContract, uint256 maxTokens, uint128 startEpoch, uint128 endEpoch) = streamAmountEnforcer.getTermsInfo(terms);

        assertEq(allowedContract, address(erc20));
        assertEq(maxTokens, 100e18);
        assertEq(startEpoch, 1733011200);
        assertEq(endEpoch, 1734134400);
    }

    function test_validateAndIncrease() external {
        // Test the _validateAndIncrease function with human-readable timestamps
        bytes memory terms = abi.encodePacked(
            address(erc20),
            uint256(100e18),
            uint128(1733011200), // 2024-12-01T00:00:00Z
            uint128(1734134400)  // 2024-12-14T00:00:00Z
        );

        bytes memory callData = abi.encodeWithSelector(
            ERC20Mintable.mint.selector,
            address(users.alice.wallet),
            10e18
        );

        bytes memory executionCallData = ExecutionLib.encodeSingle(
            address(erc20),
            0,
            callData
        );

        bytes32 delegationHash = keccak256("delegationHash");

        vm.warp(1733011200 + 1000000); // Move to a time within the stream period

        (uint256 limit, uint256 spent) = streamAmountEnforcer._validateAndIncrease(terms, executionCallData, delegationHash);

        assertEq(limit, 100e18);
        assertEq(spent, 10e18);
    }

    function test_validateAndIncrease_streamNotStarted() external {
        // Test the _validateAndIncrease function when the stream has not started
        bytes memory terms = abi.encodePacked(
            address(erc20),
            uint256(100e18),
            uint128(1733011200), // 2024-12-01T00:00:00Z
            uint128(1734134400)  // 2024-12-14T00:00:00Z
        );

        bytes memory callData = abi.encodeWithSelector(
            ERC20Mintable.mint.selector,
            address(users.alice.wallet),
            10e18
        );

        bytes memory executionCallData = ExecutionLib.encodeSingle(
            address(erc20),
            0,
            callData
        );

        bytes32 delegationHash = keccak256("delegationHash");

        vm.warp(1733011199); // Move to a time before the stream period

        vm.expectRevert("ERC20StreamAmountEnforcer:stream-not-started");
        streamAmountEnforcer._validateAndIncrease(terms, executionCallData, delegationHash);
    }

    function test_validateAndIncrease_streamEnded() external {
        // Test the _validateAndIncrease function when the stream has ended
        bytes memory terms = abi.encodePacked(
            address(erc20),
            uint256(100e18),
            uint128(1733011200), // 2024-12-01T00:00:00Z
            uint128(1734134400)  // 2024-12-14T00:00:00Z
        );

        bytes memory callData = abi.encodeWithSelector(
            ERC20Mintable.mint.selector,
            address(users.alice.wallet),
            10e18
        );

        bytes memory executionCallData = ExecutionLib.encodeSingle(
            address(erc20),
            0,
            callData
        );

        bytes32 delegationHash = keccak256("delegationHash");

        vm.warp(1734134401); // Move to a time after the stream period

        vm.expectRevert("ERC20StreamAmountEnforcer:stream-ended");
        streamAmountEnforcer._validateAndIncrease(terms, executionCallData, delegationHash);
    }

    function test_validateAndIncrease_allowanceExceeded() external {
        // Test the _validateAndIncrease function when the allowance is exceeded
        bytes memory terms = abi.encodePacked(
            address(erc20),
            uint256(100e18),
            uint128(1733011200), // 2024-12-01T00:00:00Z
            uint128(1734134400)  // 2024-12-14T00:00:00Z
        );

        bytes memory callData = abi.encodeWithSelector(
            ERC20Mintable.mint.selector,
            address(users.alice.wallet),
            50e18
        );

        bytes memory executionCallData = ExecutionLib.encodeSingle(
            address(erc20),
            0,
            callData
        );

        bytes32 delegationHash = keccak256("delegationHash");

        vm.warp(1733011200 + 1000000); // Move to a time within the stream period

        streamAmountEnforcer._validateAndIncrease(terms, executionCallData, delegationHash);

        callData = abi.encodeWithSelector(
            ERC20Mintable.mint.selector,
            address(users.alice.wallet),
            60e18
        );

        executionCallData = ExecutionLib.encodeSingle(
            address(erc20),
            0,
            callData
        );

        vm.expectRevert("ERC20StreamAmountEnforcer:allowance-exceeded");
        streamAmountEnforcer._validateAndIncrease(terms, executionCallData, delegationHash);
    }
}
