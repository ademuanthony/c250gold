// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const PriceOracle = await hre.ethers.getContractFactory("C250PriceOracle");
  const priceOracle = await PriceOracle.deploy();

  await priceOracle.deployed()
  console.log("PriceOracle deployed to:", priceOracle.address);

  // TimeProvider
  const TimeProvider = await hre.ethers.getContractFactory("TimeProvider");
  const timeProvider = await TimeProvider.deploy();

  await timeProvider.deployed()
  console.log("timeProvider deployed to:", timeProvider.address);

  // We get the contract to deploy
  const C250Gold = await hre.ethers.getContractFactory("C250Gold");
  const c250Gold = await C250Gold.deploy(priceOracle.address, timeProvider.address, process.env.TREASURY);

  await c250Gold.deployed();

  console.log("C250Gold deployed to:", c250Gold.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
