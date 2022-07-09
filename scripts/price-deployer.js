// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  const C250PriceOracle = await hre.ethers.getContractFactory("MockC250PriceOracle");
  const c250Gold = await C250PriceOracle.deploy();

  await c250Gold.deployed();

  console.log("C250PriceOracle deployed to:", c250Gold.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
