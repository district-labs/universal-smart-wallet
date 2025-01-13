// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { ModeLib } from "@erc7579/lib/ModeLib.sol";
import { ModeCode } from "delegation-framework/src/utils/Types.sol";
import { BaseTest } from "test/utils/BaseTest.t.sol";
import { MockCall } from "test/utils/MockCall.sol";
import { ExternalHookEnforcer } from "../../src/enforcers/ExternalHookEnforcer.sol";

contract ExternalHookEnforcer_Test is BaseTest {
    using ModeLib for ModeCode;

    ////////////////////////////// State //////////////////////////////

    // Contracts
    MockCall public mockCall;
    ExternalHookEnforcer public externalHookEnforcer;

    // Mode
    ModeCode public mode = ModeLib.encodeSimpleSingle();

    ////////////////////////////// Setup //////////////////////////////
    function setUp() public virtual override {
        super.setUp();

        mockCall = new MockCall();
        externalHookEnforcer = new ExternalHookEnforcer();
    }

    ////////////////////////////// Success Tests //////////////////////////////

    function test_ExternalHookEnforcer_afterHook_successHookCall() external {
        // Should correctly call the external hook
        bytes memory args = abi.encodePacked(address(mockCall), abi.encodeWithSelector(MockCall.success.selector));

        externalHookEnforcer.afterHook(hex"", args, mode, hex"", bytes32(0), address(0), address(0));
    }

    function test_ExternalHookEnforcer_getArgsInfo_validData() external {
        // Should be valid if target and data are valid
        bytes memory args = abi.encodePacked(address(mockCall), abi.encodeWithSelector(MockCall.success.selector));

        externalHookEnforcer.getArgsInfo(args);
    }

    function test_ExternalHookEnforcer_getArgsInfo_emptyCalldata() external {
        // Should be valid even if the calldata is empty, meaning that the args is only 20 bytes
        bytes memory args = new bytes(20);

        externalHookEnforcer.getArgsInfo(args);
    }

    ////////////////////////////// Failure Tests //////////////////////////////

    function test_ExternalHookEnforcer_getArgsInfo_RevertIf_InvalidArgsLength() external {
        // Should revert if the length of the args is less than 20
        bytes memory args = new bytes(19);

        vm.expectRevert(abi.encodeWithSelector(ExternalHookEnforcer.InvalidArgsLength.selector, args.length));
        externalHookEnforcer.getArgsInfo(args);
    }

    function test_ExternalHookEnforcer_afterHook_RevertIf_ExternalHookExecutionFailed() external {
        // Should revert if the external hook execution fails
        bytes memory args = abi.encodePacked(
            address(mockCall),
            // Encode a function that will revert
            abi.encodeWithSelector(MockCall.throwError.selector)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ExternalHookEnforcer.ExternalHookExecutionFailed.selector, abi.encodePacked(bytes4(0xd8a74f3b))
            )
        );
        externalHookEnforcer.afterHook(hex"", args, mode, hex"", bytes32(0), address(0), address(0));
    }
}
