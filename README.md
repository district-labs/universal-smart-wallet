# Universal Wallet
Universal Wallet is an [ERC-4337](https://eip.tools/eip/4337) smart account.

Inheriting [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework) and the [Base WebAuthn](https://github.com/base-org/webauthn-sol) smart contracts.

Designed to work with the [Universal SDK](https://github.com/district-labs/universal-sdk) stack.

> [!WARNING]  
> The Universal Wallet is still in development and should not be used in production. It is not audited and may contain bugs.
> We're also using an unaudited version of the MetaMask Delegation Framework.

## Deployments
The Universal Wallet is deployed on Base Sepolia using the following salt: 0x6dfc21ac0c8c2db036305d8bc6f887630d35e156f37d5a7e2275bc05bc004846.

#### Core
- EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
- DelegationManager: 0x26e1920510E4d8693524e161380Bbf01318E33c9
- UniversalWalletImpl: 0xd3F1B71597458bcE2A1b56D0987dd31Ff8FF2C36
- UniversalWalletFactory: 0x6c6c2C2afA04E2c8f626223ff900Cce95554E9D8
    
#### Enforcers
- AllowedCalldataEnforcer: 0xe11D4d4e129516E829a17a5aC98cBD243d8D6D97
- AllowedMethodsEnforcer: 0xb99BeAEA994238a196c3fe2ac72bEAD23a300aE9
- AllowedTargetsEnforcer: 0x0Cc8dCA2522E645De7a24d84aa499b37d56EcADd
- ArgsEqualityCheckEnforcer: 0x2118241101a7846A3901062E5FF1d96D76f1879d
- BlockNumberEnforcer: 0x32c454A3a7E54bAf6793995fF1F1b6b996c16519
- DeployedEnforcer: 0x19B8BdF3354Af17a8cD9F35Db3E079Ce9864a10a
- ERC20BalanceGteEnforcer: 0xA1AF62Da13E025E7E0bDc9294F98cD0fB907fC56
- ERC20TransferAmountEnforcer: 0x9Ec6bA1D261F32bA7D11935Af7014455414D32BA
- ERC721BalanceGteEnforcer: 0xbdB11E994668e879e9dae7BddeaE757828CDBF41
- ERC721TransferEnforcer: 0x1Abd29e4A8769Ee581aef8a0cFa688F20a5c355D
- ERC1155BalanceGteEnforcer: 0x8aE8462A3cc592A0Bd96a8E14a9780B3C554F430
- IdEnforcer: 0x1D14da69A0d3C7C65dbCA7001cAFf267384375F4
- LimitedCallsEnforcer: 0xA10A29F7A15595d238875E18DE629964ca745119
- NativeBalanceGteEnforcer: 0x029f9d80B228695611aD14d0665B2f5576E493E5
- NativeTokenPaymentEnforcer: 0xc4eC4a2D7d8Bd206e959664e9991619D104EF064
- NativeTokenTransferAmountEnforcer: 0x62Ec1F7146e4bDdef45e9CBAFA30e33b8b5A0e3F
- NonceEnforcer: 0x8c2708C449097C9D55Ebc47ffF9B06e405DdD2e2
- OwnershipTransferEnforcer: 0x0951C08C75107435B6b5b080AEF9af30d009c98e
- RedeemerEnforcer: 0xbD848E5861825754c809F5b813A72B50691A86A6
- TimestampEnforcer: 0x675b4844E388e329354185cAcBC30E3F93456559
- ValueLteEnforcer: 0x1f7EE6330cc76Bb26Cc490166CcAbf451234A578
- ERC20BalanceGteAfterAllEnforcer: 0x2AB6fed8C074D4Bf4668E46f78a97cCD1FC23686
- ExternalHookEnforcer: 0xF1dF0e6d2d6D307814A086cCdeBdcD1250C53df3

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
