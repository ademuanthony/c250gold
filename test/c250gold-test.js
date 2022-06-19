const { expect } = require("chai");
const { ethers,  } = require("hardhat");
const { solidity } = require('ethereum-waffle')
const chai = require('chai');
chai.use(solidity);

let contract;

beforeEach(async function () {
  const C250Gold = await ethers.getContractFactory("C250Gold");
  contract = await C250Gold.deploy(
    process.env.FACTORY,
    process.env.WMATIC,
    process.env.USDC,
    3000,
    process.env.TREASURY
  );
  await contract.deployed();
  await contract.launch();
});

describe("C250Gold", function () {
  it("Should mint initial supply of 250000 and register first account and create lp pool when deployed", async function () {
    const bal = await contract.balanceOf(process.env.TREASURY);
    expect(parseInt(bal)).to.equal(250000 * 1e18);

    const accounts = await contract.getAccounts(process.env.TREASURY);
    expect(parseInt(accounts[0])).to.equal(1);

    expect((await contract.C250GoldPool()).toString()).not.equal(process.env.ZERO_ADDRESS);
  });

  it("register Should not create duplicate account", async function () {
    await expect(contract.register(1, process.env.TREASURY)).to.be.reverted
  });

  it("AddAccount Should fail for non-existing address", async function() {
    const [addr1] = await ethers.getSigners();
    await expect(contract.addAccount(1, addr1.address)).to.be.reverted
  });

  it("Should get the correct activation fee", async function() {

  });

  it("Should activate and credit referral", function () {
    //contract.activate(1);
  });

  it("Should not activate accounts with insuficient fund", async function() {

  });
});
