
# SanctumLink – Smart Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Solidity](https://img.shields.io/badge/Solidity-blue)
![Foundry](https://img.shields.io/badge/Foundry-gray)
![Avalanche Fuji](https://img.shields.io/badge/Avalanche_Fuji-red)

> Seamless Identity Verification for Web3.

This repository contains the smart contracts for the SanctumLink project at the [Chainlink Block Magic 2024 Hackathon](https://chain.link/hackathon). The smart contracts are written in Solidity, tested with Foundry, and deployed on the Avalanche Fuji testnet.

## Getting Started

> **Pre-requisites:**
>
> - Setup Node.js v18+ (recommended via [nvm](https://github.com/nvm-sh/nvm) with `nvm install 18`)
> - Install [Foundry](https://github.com/gakonst/foundry) by following the official installation guide
> - Clone this repository

```bash
# Install dependencies
npm install
forge install
```

## Development

```bash
# Compile smart contracts
forge build

# Run tests
forge test
```

## Development Tools

- **Solidity**: Programming language for writing smart contracts.
- **Foundry**: Toolchain for testing and deploying smart contracts.
- **Avalanche Fuji**: Testnet for deploying and testing smart contracts.

Check the `ContractHelperConfig.txt` file for information on deployed contracts.
