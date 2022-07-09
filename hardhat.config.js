require('dotenv').config();
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat:{},
    localhost: {
      forking: {
        url: "https://polygon-mainnet.g.alchemy.com/v2/"+process.env.ALCHEMY_KEY,
        blockNumber: 29773646
      }
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY]
    },
    mainnet: {
      url: "https://polygon-rpc.com",
      accounts: [process.env.PRIVATE_KEY]
    },
    bsc: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: process.env.BSC_API_KEY// .POLYGONSCAN_API_KEY
  },
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
}