const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
chai.use(solidity);

const deployContract = async function () {
  const [...addr] = await ethers.getSigners()

  const C250GoldPresale = await ethers.getContractFactory("C250GoldPresale2");
  const contract = await C250GoldPresale.deploy(addr[0].address);
  await contract.deployed();

  const C250GoldPresaleCoordinator = await ethers.getContractFactory("C250GoldPresaleCoordinator");
  const coordinator = await C250GoldPresaleCoordinator.deploy(process.env.TREASURY);
  await coordinator.deployed();
  return coordinator;
};

// it = 3MATIC
// 1M = 1/3T

describe("Buy Presale", async function () {
  it("Should send the right amount of ticket to the buyer", async function () {return
    const [...addr] = await ethers.getSigners()
    const C250GoldPresale = await ethers.getContractFactory("C250GoldPresale2");
    const contract = await C250GoldPresale.deploy(addr[0].address);
    await contract.deployed();

    await contract.setRate(33333333, 100000000)

    const initBal = await contract.balanceOf(addr[0].address)

    const C250GoldPresaleCoordinator = await ethers.getContractFactory("C250GoldPresaleCoordinator");
    const coordinator = await C250GoldPresaleCoordinator.deploy(process.env.TREASURY, contract.address);
    await coordinator.deployed();

    await contract.transfer(coordinator.address, initBal)

    await coordinator.setRate(33333333, 100000000)
    const amount = ethers.utils.parseEther('10')

    await coordinator.buy(addr[1].address, {value: amount})

    const bal = await contract.balanceOf(addr[0].address)
    expect(bal).to.be.equal(ethers.utils.parseEther("3.3333333"))

    const bal1 = await contract.balanceOf(addr[1].address)
    expect(bal1, "First level").to.be.equal(ethers.utils.parseEther("0.166666665"))

    await coordinator.connect(addr[2]).buy(addr[0].address, {value: ethers.utils.parseEther('10')})
    const bal2 = await contract.balanceOf(addr[2].address)
    expect(bal2).to.be.equal(ethers.utils.parseEther("3.3333333"))


    const bal1Af = await contract.balanceOf(addr[1].address)
    expect(bal1Af, "Secound level").to.be.equal(ethers.utils.parseEther("0.33333333"))
  })
})