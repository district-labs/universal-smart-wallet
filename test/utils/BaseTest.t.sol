// SPDX-License-Identifier: MIT AND Apache-2.0
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { EntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { FCL_ecdsa_utils } from "@FCL/FCL_ecdsa_utils.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IEntryPoint } from "@account-abstraction/core/EntryPoint.sol";
import { ModeLib } from "@erc7579/lib/ModeLib.sol";

import { P256SCLVerifierLib } from "delegation-framework/src/libraries/P256SCLVerifierLib.sol";
import { SCL_Wrapper } from "delegation-framework/test/utils/SCLWrapperLib.sol";

import { EXECUTE_SIGNATURE } from "delegation-framework/test/utils/Constants.sol";
import { EncoderLib } from "delegation-framework/src/libraries/EncoderLib.sol";
import { TestUser, TestUsers, SignatureType } from "./Types.t.sol";
import { SigningUtilsLib } from "./SigningUtilsLib.t.sol";
import { Delegation, Execution, PackedUserOperation, ModeCode } from "delegation-framework/src/utils/Types.sol";
import { SimpleFactory } from "delegation-framework/src/utils/SimpleFactory.sol";
import { DelegationManager } from "delegation-framework/src/DelegationManager.sol";
import { MultiSigDeleGator } from "delegation-framework/src/MultiSigDeleGator.sol";

import { UniversalWallet } from "src/UniversalWallet.sol";

import { ERC20Mintable } from "./ERC20Mintable.sol";

abstract contract BaseTest is Test {
    using ModeLib for ModeCode;
    using MessageHashUtils for bytes32;

    SignatureType public SIGNATURE_TYPE;
    string constant EXECUTE_SIGNATURE = "execute(bytes32,bytes)";
    string constant EXECUTE_SINGULAR_SIGNATURE = "execute((address,uint256,bytes))";

    ////////////////////////////// State //////////////////////////////

    // Constants
    bytes32 public ROOT_AUTHORITY;
    address public ANY_DELEGATE;

    // ERC4337
    EntryPoint public entryPoint;

    // Delegation Manager
    DelegationManager public delegationManager;

    // Universal Wallet Implementation
    UniversalWallet public universalWalletImplementation;

    ERC20Mintable public erc20;

    // Users
    TestUsers internal users;
    address payable bundler;

    // Tracks the user's nonce
    mapping(address user => uint256 nonce) public senderNonce;

    ////////////////////////////// Set Up //////////////////////////////

    function setUp() public virtual {
        // Create 4337 EntryPoint
        entryPoint = new EntryPoint();
        vm.label(address(entryPoint), "EntryPoint");

        // DelegationManager
        delegationManager = new DelegationManager(makeAddr("DelegationManager Owner"));
        vm.label(address(delegationManager), "Delegation Manager");

        // Set constant values for easy access
        ROOT_AUTHORITY = delegationManager.ROOT_AUTHORITY();
        ANY_DELEGATE = delegationManager.ANY_DELEGATE();

        // Create P256 Verifier Contract
        vm.etch(P256SCLVerifierLib.VERIFIER, type(SCL_Wrapper).runtimeCode);
        vm.label(P256SCLVerifierLib.VERIFIER, "P256 Verifier");

        // Create Universal Wallet Implementation
        universalWalletImplementation = new UniversalWallet(delegationManager, entryPoint);

        // Create ERC20
        erc20 = new ERC20Mintable("TST", "Test");

        // Create users
        users = _createUsers();

        // Create the bundler
        bundler = payable(makeAddr("Bundler"));
        vm.deal(bundler, 100 ether);
    }

    ////////////////////////////// Public //////////////////////////////

    function signHash(TestUser memory _user, bytes32 _hash) public view returns (bytes memory) {
        return signHash(SIGNATURE_TYPE, _user, _hash);
    }

    function signHash(
        SignatureType _signatureType,
        TestUser memory _user,
        bytes32 _hash
    )
        public
        pure
        returns (bytes memory)
    {
        if (_signatureType == SignatureType.EOA) {
            UniversalWallet.SignatureWrapper memory signatureWrapper = UniversalWallet.SignatureWrapper({
                ownerIndex: 1,
                signatureData: SigningUtilsLib.signHash_EOA(_user.privateKey, _hash)
            });
            return abi.encode(signatureWrapper);
        } else if (_signatureType == SignatureType.RawP256) {
            UniversalWallet.SignatureWrapper memory signatureWrapper = UniversalWallet.SignatureWrapper({
                ownerIndex: 0,
                signatureData: SigningUtilsLib.signHash_P256(_user.privateKey, _hash)
            });
            return abi.encode(signatureWrapper);
        } else {
            revert("Invalid Signature Type");
        }
    }

    /// @notice Uses the private key to sign a delegation.
    /// @dev NOTE: Assumes MultiSigDeleGator has a single signer with a threshold of 1.
    function signDelegation(
        TestUser memory _user,
        Delegation memory _delegation
    )
        public
        view
        returns (Delegation memory delegation_)
    {
        bytes32 domainHash_ = delegationManager.getDomainHash();
        bytes32 delegationHash_ = EncoderLib._getDelegationHash(_delegation);
        bytes32 typedDataHash_ = MessageHashUtils.toTypedDataHash(domainHash_, delegationHash_);
        delegation_ = Delegation({
            delegate: _delegation.delegate,
            delegator: _delegation.delegator,
            authority: _delegation.authority,
            caveats: _delegation.caveats,
            salt: _delegation.salt,
            signature: signHash(_user, typedDataHash_)
        });
    }

    /// @notice Creates an unsigned UserOperation with paymaster with default values.
    function createUserOp(
        address _sender,
        bytes memory _callData
    )
        public
        returns (PackedUserOperation memory PackedUserOperation_)
    {
        return createUserOp(_sender, _callData, hex"", hex"");
    }

    /// @notice Creates an unsigned UserOperation with paymaster with default values.
    function createUserOp(
        address _sender,
        bytes memory _callData,
        bytes memory _initCode
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        return createUserOp(_sender, _callData, _initCode, hex"");
    }

    /// @notice Creates an unsigned UserOperation with paymaster with default values.
    function createUserOp(
        address _sender,
        bytes memory _callData,
        bytes memory _initCode,
        bytes memory _paymasterAndData
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        uint128 verificationGasLimit_ = 30_000_000;
        uint128 callGasLimit_ = 30_000_000;
        uint128 maxPriorityFeePerGas = 1;
        uint128 maxFeePerGas_ = 1;
        bytes32 accountGasLimits_ = bytes32(abi.encodePacked(verificationGasLimit_, callGasLimit_));
        bytes32 gasFees_ = bytes32(abi.encodePacked(maxPriorityFeePerGas, maxFeePerGas_));

        return createUserOp(
            _sender, _callData, _initCode, accountGasLimits_, 30_000_000, gasFees_, _paymasterAndData, hex""
        );
    }

    /// @notice Creates an unsigned UserOperation with the nonce prefilled.
    function createUserOp(
        address _sender,
        bytes memory _callData,
        bytes memory _initCode,
        bytes32 _accountGasLimits,
        uint256 _preVerificationGas,
        bytes32 _gasFees,
        bytes memory _paymasterAndData,
        bytes memory _signature
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        vm.txGasPrice(2);

        userOperation_ = PackedUserOperation({
            sender: _sender,
            nonce: senderNonce[_sender]++,
            initCode: _initCode,
            callData: _callData,
            accountGasLimits: _accountGasLimits,
            preVerificationGas: _preVerificationGas,
            gasFees: _gasFees,
            paymasterAndData: _paymasterAndData,
            signature: _signature
        });
    }

    function signUserOp(
        TestUser memory _user,
        PackedUserOperation memory _userOp
    )
        public
        view
        returns (PackedUserOperation memory)
    {
        return signUserOp(_user, _userOp, entryPoint);
    }

    function signUserOp(
        TestUser memory _user,
        PackedUserOperation memory _userOp,
        IEntryPoint _entryPoint
    )
        public
        view
        returns (PackedUserOperation memory)
    {
        bytes32 userOpHash_ = _user.wallet.getPackedUserOperationHash(_userOp);
        bytes32 typedDataHash_ = MessageHashUtils.toTypedDataHash(_user.wallet.getDomainHash(), userOpHash_);
        _userOp.signature = signHash(_user, typedDataHash_);
        return _userOp;
    }

    function createAndSignUserOp(
        TestUser memory _user,
        address _sender,
        bytes memory _callData
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        userOperation_ = createAndSignUserOp(_user, _sender, _callData, hex"");
    }

    function createAndSignUserOp(
        TestUser memory _user,
        address _sender,
        bytes memory _callData,
        bytes memory _initCode
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        userOperation_ = createUserOp(_sender, _callData, _initCode);
        userOperation_ = signUserOp(_user, userOperation_);
    }

    function createAndSignUserOp(
        TestUser memory _user,
        address _sender,
        bytes memory _callData,
        bytes memory _initCode,
        bytes memory _paymasterAndData
    )
        public
        returns (PackedUserOperation memory userOperation_)
    {
        userOperation_ = createUserOp(_sender, _callData, _initCode, _paymasterAndData);
        userOperation_ = signUserOp(_user, userOperation_);
    }

    function submitUserOp_Bundler(PackedUserOperation memory _userOp) public {
        submitUserOp_Bundler(_userOp, false);
    }

    function submitUserOp_Bundler(PackedUserOperation memory _userOp, bool _shouldFail) public {
        PackedUserOperation[] memory userOps_ = new PackedUserOperation[](1);
        userOps_[0] = _userOp;
        vm.prank(bundler);
        if (_shouldFail) vm.expectRevert();
        entryPoint.handleOps(userOps_, payable(bundler));
    }

    // Name is the seed used to generate the address, private key, and DeleGator.
    function createUser(string memory _name) public returns (TestUser memory user_) {
        (address addr_, uint256 privateKey_) = makeAddrAndKey(_name);
        vm.deal(addr_, 100 ether);
        vm.label(addr_, _name);

        user_.name = _name;
        user_.addr = payable(addr_);
        user_.privateKey = privateKey_;
        (user_.x, user_.y) = FCL_ecdsa_utils.ecdsa_derivKpub(user_.privateKey);
        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encodePacked(user_.x, user_.y);
        owners[1] = abi.encode(user_.addr);
        user_.wallet = _deployUniversalWallet(owners);
        user_.deleGator = _deployUniversalWallet(owners);

        vm.deal(address(user_.wallet), 100 ether);
        vm.label(address(user_.wallet), string.concat(_name, " Universal Wallet"));
    }

    function _deployUniversalWallet(bytes[] memory owners) internal returns (UniversalWallet) {
        UniversalWallet universalWallet = UniversalWallet(
            payable(
                address(
                    new ERC1967Proxy(
                        address(universalWalletImplementation),
                        abi.encodeWithSelector(UniversalWallet.initialize.selector, owners)
                    )
                )
            )
        );
        return universalWallet;
    }

    ////////////////////////////// Private //////////////////////////////

    function _createUsers() private returns (TestUsers memory users_) {
        users_.alice = createUser("Alice");
        users_.bob = createUser("Bob");
        users_.carol = createUser("Carol");
        users_.dave = createUser("Dave");
        users_.eve = createUser("Eve");
        users_.frank = createUser("Frank");
        users_.paymentRouter = createUser("PaymentRouter");
        users_.affiliate = createUser("Affiliate");
        users_.user1 = createUser("User1");
        users_.user2 = createUser("User2");
        users_.user3 = createUser("User3");
    }
}
