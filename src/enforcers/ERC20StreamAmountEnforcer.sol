pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ExecutionLib } from "@erc7579/lib/ExecutionLib.sol";
import { CaveatEnforcer } from "./CaveatEnforcer.sol";
import { ModeCode } from "../utils/Types.sol";

/**
 * @title ERC20StreamAmountEnforcer
 * @dev This contract enforces the streaming of ERC20 tokens over a specified time period.
 */
contract ERC20StreamAmountEnforcer is CaveatEnforcer {
    using ExecutionLib for bytes;

    ////////////////////////////// State //////////////////////////////

    mapping(address delegationManager => mapping(bytes32 delegationHash => uint256 amount)) public spentMap;

    ////////////////////////////// Functions //////////////////////////////

    /**
     * @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms encoded data that is used during the execution hooks.
     * @return allowedContract_ The address of the ERC20 token contract.
     * @return maxTokens_ The maximum number of tokens that the delegate is allowed to transfer.
     * @return startEpoch_ The start time of the token stream.
     * @return endEpoch_ The end time of the token stream.
     */
    function getTermsInfo(bytes calldata _terms) public pure returns (address allowedContract_, uint256 maxTokens_, uint128 startEpoch_, uint128 endEpoch_) {
        require(_terms.length == 72, "ERC20StreamAmountEnforcer:invalid-terms-length");

        allowedContract_ = address((bytes20(_terms[:20])));
        maxTokens_ = uint256(bytes32(_terms[20:52]));
        startEpoch_ = uint128(bytes16(_terms[52:68]));
        endEpoch_ = uint128(bytes16(_terms[68:]));
    }

    /**
     * @notice Validates and increases the spent amount for the token stream.
     * @param _terms The terms of the token stream.
     * @param _executionCallData The transaction the delegate might try to perform.
     * @param _delegationHash The hash of the delegation being operated on.
     * @return limit_ The maximum amount of tokens that the delegator is allowed to spend.
     * @return spent_ The amount of tokens that the delegator has spent.
     */
    function _validateAndIncrease(
        bytes calldata _terms,
        bytes calldata _executionCallData,
        bytes32 _delegationHash
    )
        internal
        returns (uint256 limit_, uint256 spent_)
    {
        (address target_,, bytes calldata callData_) = _executionCallData.decodeSingle();

        require(callData_.length == 68, "ERC20StreamAmountEnforcer:invalid-execution-length");

        address allowedContract_;
        uint128 startEpoch_;
        uint128 endEpoch_;
        (allowedContract_, limit_, startEpoch_, endEpoch_) = getTermsInfo(_terms);

        require(allowedContract_ == target_, "ERC20StreamAmountEnforcer:invalid-contract");

        require(bytes4(callData_[0:4]) == IERC20.transfer.selector, "ERC20StreamAmountEnforcer:invalid-method");

        require(block.timestamp >= startEpoch_, "ERC20StreamAmountEnforcer:stream-not-started");
        require(block.timestamp <= endEpoch_, "ERC20StreamAmountEnforcer:stream-ended");

        uint256 streamDuration = endEpoch_ - startEpoch_;
        uint256 elapsedTime = block.timestamp - startEpoch_;
        uint256 allowedAmount = (limit_ * elapsedTime) / streamDuration;

        spent_ = spentMap[msg.sender][_delegationHash] += uint256(bytes32(callData_[36:68]));
        require(spent_ <= allowedAmount, "ERC20StreamAmountEnforcer:allowance-exceeded");
    }
}
