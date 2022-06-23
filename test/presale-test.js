const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
chai.use(solidity);

const deployContract = async function () {
  const C250GoldPresale = await ethers.getContractFactory("C250GoldPresale");
  const contract = await C250GoldPresale.deploy(process.env.TREASURY);
  await contract.deployed();
  return contract;
};

describe("Buy Presale", async function () {
  it("Should send the right amount of ticket to the buyer", async function () {
    const contract = await deployContract();
    const amount = ethers.utils.parseEther('14.5')
    await contract.buy({value: amount})

    const [addr,] = await ethers.getSigners()
    const bal = await contract.balanceOf(addr.address)
    expect(bal).to.be.equal(ethers.utils.parseEther("7.25"))
  })
})