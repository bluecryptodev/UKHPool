var HDWalletProvider = require('@truffle/hdwallet-provider');
var mnemonic = '';
module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
    },
    rinkeby: {
      provider: function () {
        return new HDWalletProvider(
          mnemonic,
          'https://rinkeby.infura.io/v3/d71b42c01cf54074865369d83e4c239f',
        );
      },
      network_id: 4,
      gas: 4500000,
      gasPrice: 10000000000,
    },
  },
  compilers: {
    solc: {
      version: '^0.6.2',
    },
  },
};
