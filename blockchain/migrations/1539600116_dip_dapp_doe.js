const LibString = artifacts.require("./LibString.sol");
const DipDappDoe = artifacts.require("./DipDappDoe.sol");
module.exports = function(deployer) {
  deployer.deploy(LibString);
  deployer.link(LibString, DipDappDoe);
  deployer.deploy(DipDappDoe);
};
