# CronaSwap Smart Contracts
This repo contains all of the smart contracts used to run [CronaSwap](https://cronaswap.org).

## Deployed Contracts - Mainnet 
Router address: `0xcd7d16fB918511BF7269eC4f48d61D79Fb26f918`

Factory address: `0x73A48f8f521EB31c55c0e1274dB0898dE599Cb11`


## Running
These contracts are compiled and deployed using [Hardhat](https://hardhat.org/). They can also be run using the Remix IDE.

## Accessing the ABI
If you need to use any of the contract ABIs, you can install this repo as an npm package with `npm install --dev @cronaswap/cronaswap-contracts`. Then import the ABI like so: `import { abi as ICronaSwapPairABI } from '@cronaswap/cronaswap-contracts/artifacts/contracts/interfaces/ICronaSwapPair.sol/ICronaSwapPair.json'`.

## Attribution
These contracts were adapted from these Uniswap repos: [uniswap-v2-core](https://github.com/Uniswap/uniswap-v2-core), [uniswap-v2-periphery](https://github.com/Uniswap/uniswap-v2-core), and [uniswap-lib](https://github.com/Uniswap/uniswap-lib).
