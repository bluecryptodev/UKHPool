const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const UKHToken = artifacts.require('UKHToken');

module.exports = async function (deployer) {
  await deployProxy(UKHToken, {
    deployer,
    initializer: 'initialize',
  });
};
