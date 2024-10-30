# Universal Wallet
Universal Wallet is an [ERC-4337](https://eip.tools/eip/4337) smart account.

Inheriting [MetaMask Delegation Framework](https://github.com/MetaMask/delegation-framework) and the [Base WebAuthn](https://github.com/base-org/webauthn-sol) smart contracts.

Designed to work with the [Universal SDK](https://github.com/district-labs/universal-sdk) stack.

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
