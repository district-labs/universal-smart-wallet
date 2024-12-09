// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { CaveatEnforcer } from "delegation-framework/src/enforcers/CaveatEnforcer.sol";
import { ModeCode } from "delegation-framework/src/utils/Types.sol";
import { UniversalWallet } from "../UniversalWallet.sol";
import { UniversalWalletFactory } from "../UniversalWalletFactory.sol";

/**
 * @title DeployedDelegatorEnforcer
 * @dev This contract enforces the deployment of the Delegator contract as a UniversalWallet proxy using the Universal
 * Wallet Factory.
 */
contract DeployedDelegatorEnforcer is CaveatEnforcer {
    address universalWalletFactory;

    ////////////////////////////// Errors //////////////////////////////
    error DelegatorAddressMismatch(address computedDelegator, address delegator);

    ////////////////////////////// Events //////////////////////////////
    event DelegatorDeployed(address indexed delegator);
    event DelegatorDeploymentSkipped(address indexed delegator);

    ////////////////////////////// Constructor //////////////////////////////

    constructor(address _universalWalletFactory) {
        universalWalletFactory = _universalWalletFactory;
    }

    ////////////////////////////// Internal Methods //////////////////////////////

    /**
     * @notice Deploys the Delegator contract as a UniversalWallet proxy using CREATE2 with Safe's Singleton Factory.
     * @param owners Array of initial owners. Each item should be an ABI encoded address or 64 byte public key.
     * @param nonce The nonce of the account, a caller defined value which allows multiple accounts with the same
     * `owners` to exist at different addresses.
     */
    function _deployDelegator(address delegator, bytes[] memory owners, uint256 nonce) internal {
        // Check if the computed address matches the delegator address
        address computedDelegator = UniversalWalletFactory(universalWalletFactory).getAddress(owners, nonce);
        if (computedDelegator != delegator) {
            revert DelegatorAddressMismatch(computedDelegator, delegator);
        }

        UniversalWallet universalWallet = UniversalWalletFactory(universalWalletFactory).createAccount(owners, nonce);
        emit DelegatorDeployed(address(universalWallet));
    }

    ////////////////////////////// Public Methods //////////////////////////////

    /**
     * @notice Allows the delegator to make sure its contract is deployed before the delegation redemption is performed.
     * @param _terms This is packed bytes where:
     *    the first 32 bytes are the nonce to use for the UniversalWalletFactory deployment
     *    the next bytes are the owners of the UniversalWallet
     */
    function beforeHook(
        bytes calldata _terms,
        bytes calldata,
        ModeCode,
        bytes calldata,
        bytes32,
        address _delegator,
        address
    )
        public
        override
    {
        (uint256 nonce, bytes[] memory owners) = getTermsInfo(_terms);

        // Only deploy the delegator if the code is not set
        if (universalWalletFactory.code.length > 0) {
            emit DelegatorDeploymentSkipped(_delegator);
            return;
        }
        _deployDelegator(_delegator, owners, nonce);
    }

    /**
     * @notice Decodes the terms used in this CaveatEnforcer.
     * @param _terms encoded data that is used during the execution hooks.
     * @return nonce The nonce used to deploy the delegator contract.
     * @return owners The owners of the delegator contract.
     */
    function getTermsInfo(bytes calldata _terms) public pure returns (uint256 nonce, bytes[] memory owners) {
        require(_terms.length > 52, "DeployedEnforcer:invalid-terms-length");
        nonce = uint256(bytes32(_terms[:32]));
        bytes calldata ownersBytes = _terms[32:];
        // TODO: Support 32 bytes owners
        // Split the owners bytes into an array of owners of 64 bytes
        uint256 ownersCount = ownersBytes.length / 64;
        owners = new bytes[](ownersCount);
        for (uint256 i = 0; i < ownersCount; i++) {
            owners[i] = ownersBytes[i * 64:(i + 1) * 64];
        }
    }
}
