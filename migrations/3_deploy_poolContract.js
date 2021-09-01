const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const UKHPool = artifacts.require('UKHPool');

module.exports = async function (deployer) {
  await deployProxy(UKHPool, [`t`, `amount`], {
    deployer,
    initializer: 'initialize',
  });
};
