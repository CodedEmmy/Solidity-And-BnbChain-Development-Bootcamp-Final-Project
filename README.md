# Solidity-And-BnbChain-Development-Bootcamp-Final-Project
Bnb bootcamp final project
**GenXLocker DApp** provides its users with the option of locking up their ERC20 tokens in order to gain rewards.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
- [Smart Contracts](#smart-contracts)
- [Testing](#testing)
- [Frontend](#frontend)
- [License](#license)

## Overview

This is a simple staking DApp that allows the user to stake a specified token for a given time period and earn rewards from that stake.

## Features

- The staking is not pooled and each stake operates independently of the other stakes in the contract.
- A single user can stake multiple time and different tokens at the same time and each stake will have its own duration, APY and rewards without combining or interfering with other stakes.
- Support for new stake tokens is dynamic. That is, the contract owner can add Support for new tokens that adhere to the IERC20 specifications without having to modify the contract.
- Tokens can only be unstaked after the specified duration.
- EVM Wallet Integration: Connect your Ethereum wallet (e.g., MetaMask) to participate directly.

## Getting Started

The target deployment chain is Binance smart chain, although the contract should be usable on most EVM chains.

### Prerequisites

1. MetaMask browser extension. The client-side relies on the availability of web3.js and MetaMask web3 service. This should be available if MetaMask is installed on thr browser.

### Installation

1. Upload the web folder to your web server and access the index.html file to open the DApp.

2. It is best to re-compile the smart contract and redeploy it so as to establish yourself as the contract owner. This is necessary because certain functions, such as addStakeToken(), are only accessible by the contract owner.
3. Update the contract address and ABI variables in the web/js/dappconst.js file to match your deployment details.

## Usage
 
1. Open your browser and navigate to the proper URL to access the DApp. The URL should point to the index.html file in the web folder

2. Connect your Metamask wallet to the DApp.

4. Lock your tokens. 

5. View your stakes and rewards.  

## Smart Contracts

There are two smart contracts used by this DApp. These are;

- `Ownable.sol`: Defines the implementation for the owner only modifier.
- `GenXLocker.sol`: Contaisn all the major functions required by the DApp.

## Testing

Smart contract tests are located in the `test` folder. These tests ensure the correct functioning of the smart contract.

## Frontend

The Frontend consists of a simple UI built using HTML and JavaScript. The frontend is a demo to test and show the functionality of the smart contract. Each primary function of the smart contract can be accessed via the corresponding section in the dApp.


## License

This project is licensed under the [MIT License](LICENSE).

---

This is my first smart contract and dApp so the contracts and integration may not really be optimal since I'm still learning the nuances of Solidity development and deployment.
The code is available to use, modify, upgrade, etc for whatever purpose.
