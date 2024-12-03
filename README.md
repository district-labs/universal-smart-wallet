# Universal Wallet
Universal Wallet is an [ERC-4337](https://eip.tools/eip/4337) smart account.

Inheriting [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework) and the [Base WebAuthn](https://github.com/base-org/webauthn-sol) smart contracts.

Designed to work with the [Universal SDK](https://github.com/district-labs/universal-sdk) stack.

> [!WARNING]  
> The Universal Wallet is still in development and should not be used in production. It is not audited and may contain bugs.
> We're also using an unaudited version of the MetaMask Delegation Framework.

## Deployments
The Universal Wallet is deployed on Base Sepolia.

#### Core
- EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
- DelegationManager: 0x259333aBf1b66309bc1b7B7e76f84681e6852651 x
- UniversalWalletImpl: 0x349d6bd15A486692C223C67dDad8853883998a3d
- UniversalWalletFactory: 0x59ea58813F44aE8BF9246Fe5BA7Ee77966fF22cd
    
#### Enforcers
- AllowedCalldataEnforcer: 0x16F74238A5A0593816ece1d6F5c7063910529866 x
- AllowedMethodsEnforcer: 0xd5d342f4e0d0C3B4A60aD19a2AaCF2cC7513b491 x
- AllowedTargetsEnforcer: 0xCf664Dee9013D988f08CE3C284E6d212C1BBfdFD x
- ArgsEqualityCheckEnforcer: 0x0C7fcF1140441eE967849b26833EDac1673a6987 x
- BlockNumberEnforcer: 0x41AC4f87f1c41A9f65e2a7184a09EF35FB97e1a7
- DeployedEnforcer: 0x8197383Fc911097189174e34437Ad53A185333CD
- ERC20BalanceGteEnforcer: 0x970B0d6912A1FbE1A8Ca078931BDBe9b4b47C574
- ERC20TransferAmountEnforcer: 0xCe09401479B70f31607884321B268Ac550E413AB
- ERC721BalanceGteEnforcer: 0xeFeC78484dc2869D742C48bDa0c8947748f966A5
- ERC721TransferEnforcer: 0xe9Cb0A16F406Dc9f6bF6313392350c26dDe060f1
- ERC1155BalanceGteEnforcer: 0x5532F46847721a6b29E7f54277385110B1E5AC7F
- IdEnforcer: 0x74bB1338bf639520AF4F3B0F5211880bd28709ff
- LimitedCallsEnforcer: 0xe8128C0444E47e5D9c2dA3E913d41203BA0E268D
- NativeBalanceGteEnforcer: 0xf2B0063a7Df6A6e038f95d36A7B9DcA79D400846
- NativeTokenPaymentEnforcer: 0x6af62642f3A7D705CAAbB8F314F72e49f19E51a8
- NativeTokenTransferAmountEnforcer: 0x8EE92De416326625A49cc2B3dFEE5491821C0862
- NonceEnforcer: 0x4Ad3479784Aa92fAa4c6D2A5A37681a2383D3992
- OwnershipTransferEnforcer: 0xa6cAF93F28554eE7846ceD74e521328aadc5790a
- RedeemerEnforcer: 0xFd3ded3600A84DB92accC270A1f592FBe5EcDCfF
- TimestampEnforcer: 0x3CE07E63d72590ba9988FFAbb1F1F788A9dAe228
- ValueLteEnforcer: 0xDa788aF3E906E9ECef331D1E2D12CC81730892c4

## Usage

This is a list of the most frequently needed commands.

### Build

Build the contracts:

```sh
$ forge build
```

### Clean

Delete the build artifacts and cache directories:

```sh
$ forge clean
```

### Compile

Compile the contracts:

```sh
$ forge compile
```

### Coverage

Get a test coverage report:

```sh
$ forge coverage
```

### Format

Format the contracts:

```sh
$ forge fmt
```

## Acknowledgements
The Universal Wallet Smart Contracts heavily use the [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework) so shout-out to [Dan Finlay](https://github.com/danfinlay), [Ryan McOso](https://github.com/McOso), [Dylan DesRosier](https://github.com/dylandesrosier), and the rest of the team, for their incredible work on the Delegation Framework.

## Core Contributors

- [Vitor Marthendal](https://x.com/VitorMarthendal) | [District Labs, Inc](https://www.districtlabs.com/)
- [Kames Geraghty](https://x.com/KamesGeraghty) | [District Labs, Inc](https://www.districtlabs.com/)

## License

This project is licensed under MIT.
