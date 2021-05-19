require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-solpp");

const prodConfig = {
    
    Mainnet: true,
}

const devConfig = {
    Mainnet: false,
}

const contractDefs = {
  mainnet: prodConfig,
  devnet: devConfig
}

module.exports = {
  solidity: {
    version:  "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }, 
  solpp: {
    defs: contractDefs[process.env.NET]
  },
  networks: {
    env: {
      url: 'http://localhsot:8545' //process.env.RPC_URL
    }
  }
};
