require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-solpp");
require("hardhat-contract-sizer");

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
        version: "0.6.12",
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
        hardhat: {
            allowUnlimitedContractSize: true,
            accounts: {
                mnemonic: "test test test test test test test test test test test junk",
                count: 20
            }
        }
    }
};
