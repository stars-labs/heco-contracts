require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-solpp");

const prodConfig = {
    PosMinMargin : 5000,
    PoaMinMargin : 1,
    JailPeriod : 86400,
    LockPeriod : 86400,
    ValidatorContractAddr: '0x000000000000000000000000000000000000f000',
    PunishContractAddr: '0x000000000000000000000000000000000000F001',
}

const devConfig = {
    PosMinMargin : 5,
    PoaMinMargin : 1,
    JailPeriod : 8,
    LockPeriod : 0,
    ValidatorContractAddr: '0x000000000000000000000000000000000000f000',
    PunishContractAddr: '0x000000000000000000000000000000000000F001',
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
    defs: contractDefs.devnet // contractDefs[process.env.NET]
  },
  networks: {
    env: {
      url: 'http://localhsot:8545' //process.env.RPC_URL
    }
  }
};
