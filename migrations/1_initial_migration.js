const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const AdminBox = artifacts.require('MyContract');

module.exports = async function (deployer) {
  await deployProxy(AdminBox, ['0x8dD9c91E7e4CE76FB7d0aBb53e363812abD567f7'], {
    deployer,
    initializer: 'initialize',
  });
};
