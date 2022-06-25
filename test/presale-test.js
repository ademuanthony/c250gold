const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
chai.use(solidity);

const deployContract = async function () {
  const C250GoldPresale = await ethers.getContractFactory("C250GoldPresale2");
  const contract = await C250GoldPresale.deploy(process.env.TREASURY);
  await contract.deployed();
  return contract;
};

// it = 3MATIC
// 1M = 1/3T

describe("Buy Presale", async function () {
  it("Should send the right amount of ticket to the buyer", async function () {
    const contract = await deployContract();
    await contract.setRate(33333333, 100000000)
    const amount = ethers.utils.parseEther('10')
    await contract.buy({value: amount})


    const [addr,] = await ethers.getSigners()
    const bal = await contract.balanceOf(addr.address)
    expect(bal).to.be.equal(ethers.utils.parseEther("3.3333333"))
  })
})