// SPDX-License-Identifier: MIT AND Apache-2.0
pragma solidity 0.8.23;

import { console2 } from "forge-std/console2.sol";
// Library Imports
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { DeleGatorCore } from "delegation-framework/src/DeleGatorCore.sol";
import { IDelegationManager } from "delegation-framework/src/interfaces/IDelegationManager.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ERC1271Lib } from "delegation-framework/src/libraries/ERC1271Lib.sol";
import { WebAuthn } from "webauthn-sol/WebAuthn.sol";
import { IERC173 } from "delegation-framework/src/interfaces/IERC173.sol";

// Internal Imports
import { MultiOwnable, MultiOwnableStorage } from "./MultiOwnable.sol";

/**
 * @title UniversalWallet Contract
 * @dev This contract extends the DelegatorCore contracts. It provides functionality to validate P256 and EOA
 * signatures.
 * @dev The signers that control the UniversalWallet are EOA, raw P256 keys or WebAuthn P256 public keys.
 * @notice There can be multiple signers configured for the DeleGator but only one signature is needed for a valid
 * signature.
 * @notice There must be at least one active signer.
 */
contract UniversalWallet is MultiOwnable, DeleGatorCore, IERC173 {
    /// @notice A wrapper struct used for signature validation so that callers
    ///         can identify the owner that signed.
    struct SignatureWrapper {
        /// @dev The index of the owner that signed, see `MultiOwnable.ownerAtIndex`
        uint256 ownerIndex;
        /// @dev If `MultiOwnable.ownerAtIndex` is an Ethereum address, this should be `abi.encodePacked(r, s, v)`
        ///      If `MultiOwnable.ownerAtIndex` is a public key, this should be `abi.encode(WebAuthnAuth)`.
        bytes signatureData;
    }

    ////////////////////////////// State //////////////////////////////

    /// @dev The name of the contract
    string public constant NAME = "Universal Wallet";

    /// @dev The version used in the domainSeparator for EIP712
    string public constant DOMAIN_VERSION = "1";

    /// @dev The version of the contract
    string public constant VERSION = "1.2.0";

    ////////////////////////////// Constructor //////////////////////////////

    /**
     * @notice Constructor for the UniversalWallet
     * @param _delegationManager the address of the trusted DelegationManager contract that will have root access to
     * this contract
     * @param _entryPoint The entry point contract address
     */
    constructor(
        IDelegationManager _delegationManager,
        IEntryPoint _entryPoint
    )
        DeleGatorCore(_delegationManager, _entryPoint, NAME, DOMAIN_VERSION)
    { }

    /// @notice Initializes the account with the `owners`.
    ///
    /// @param owners Array of initial owners for this account. Each item should be
    ///               an ABI encoded Ethereum address, i.e. 32 bytes with 12 leading 0 bytes,
    ///               or a 64 byte public key.
    function initialize(bytes[] calldata owners) external initializer {
        _initializeOwners(owners);
    }

    ////////////////////////////// External Methods //////////////////////////////

    /**
     * @inheritdoc DeleGatorCore
     * @dev Supports the following interfaces: ERC173
     */
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(_interfaceId) || _interfaceId == type(IERC173).interfaceId;
    }

    ////////////////////////////// Internal Methods //////////////////////////////

    /**
     * @notice Verifies if signatures are authorized.
     * @dev This contract supports EOA, raw P256 and WebAuthn P256 signatures.
     * @dev Raw P256 signature bytes: keyId hash, r, s
     * @dev WebAuthn P256 signature bytes: keyId hash, r, s, challenge, authenticatorData, requireUserVerification,
     * clientDataJSON, challengeLocation, responseTypeLocation
     * @param _hash The hash of the data signed
     * @param _signature Signature of the data signed. See above for the format of the signature.
     * @return Returns ERC1271Lib.EIP1271_MAGIC_VALUE if the recovered address matches an authorized address, returns
     * ERC1271Lib.SIG_VALIDATION_FAILED on a signature mismatch or reverts on an error
     */
    function _isValidSignature(bytes32 _hash, bytes calldata _signature) internal view override returns (bytes4) {
        SignatureWrapper memory sigWrapper = abi.decode(_signature, (SignatureWrapper));
        bytes memory ownerBytes = ownerAtIndex(sigWrapper.ownerIndex);
        bool isValidSig;

        if (ownerBytes.length == 32) {
            if (uint256(bytes32(ownerBytes)) > type(uint160).max) {
                // technically should be impossible given owners can only be added with
                // addOwnerAddress and addOwnerPublicKey, but we leave incase of future changes.
                revert InvalidEthereumAddressOwner(ownerBytes);
            }

            address account;
            assembly ("memory-safe") {
                account := mload(add(ownerBytes, 32))
            }

            isValidSig = SignatureCheckerLib.isValidSignatureNow(account, _hash, sigWrapper.signatureData);

            if (isValidSig) {
                return ERC1271Lib.EIP1271_MAGIC_VALUE;
            } else {
                return ERC1271Lib.SIG_VALIDATION_FAILED;
            }
        }

        if (ownerBytes.length == 64) {
            (uint256 x, uint256 y) = abi.decode(ownerBytes, (uint256, uint256));

            WebAuthn.WebAuthnAuth memory auth = abi.decode(sigWrapper.signatureData, (WebAuthn.WebAuthnAuth));
            isValidSig =
                WebAuthn.verify({ challenge: abi.encode(_hash), requireUV: false, webAuthnAuth: auth, x: x, y: y });
            if (isValidSig) {
                return ERC1271Lib.EIP1271_MAGIC_VALUE;
            } else {
                return ERC1271Lib.SIG_VALIDATION_FAILED;
            }
        }

        revert InvalidOwnerBytesLength(ownerBytes);
    }

    // Abstract implementations of DelegatorCore
    function _clearDeleGatorStorage() internal override {
        MultiOwnableStorage storage s_ = _getMultiOwnableStorage();

        for (uint256 i = 0; i < s_.nextOwnerIndex; i++) {
            bytes memory ownerBytes = s_.ownerAtIndex[i];
            delete s_.ownerAtIndex[i];
            delete s_.isOwner[ownerBytes];
        }

        delete s_.nextOwnerIndex;
        delete s_.removedOwnersCount;

        emit ClearedStorage();
    }

    function transferOwnership(address) external pure override {
        revert Unauthorized();
    }

    function owner() external pure override returns (address) {
        return address(0);
    }
}
