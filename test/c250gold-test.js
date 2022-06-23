const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { BigNumber } = require("ethers");
chai.use(solidity);

let contract;
let timeProvider;

const deployContract = async function () {
  const PriceOracle = await ethers.getContractFactory("MockC250PriceOracle");
  const oracleContract = await PriceOracle.deploy();

  if (!timeProvider) {
    const TimeProvider = await ethers.getContractFactory("TimeProvider");
    timeProvider = await TimeProvider.deploy();
  }

  const [addr1] = await ethers.getSigners();

  const C250Gold = await ethers.getContractFactory("C250Gold");
  const contract = await C250Gold.deploy(oracleContract.address, timeProvider.address, process.env.TREASURY);
  await contract.deployed();
  return contract;
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

beforeEach(async function () {
  contract = await deployContract();
  await contract.launch();
});

describe("C250Gold classic operation", function () {
  it("Should mint initial supply of 250000 and register first account when deployed", async function () {
    const [addr1] = await ethers.getSigners();

    const bal = await contract.balanceOf(addr1.address);
    expect(parseInt(bal)).to.equal(250000 * 1e18);

    const accounts = await contract.getAccounts(addr1.address);
    expect(parseInt(accounts[0])).to.equal(1);
  });

  it("register Should not create duplicate account", async function () {
    const [addr1] = await ethers.getSigners();
    await expect(contract.register(1, 0, addr1.address)).to.be.revertedWith(
      "Already registered, user add account"
    );
  });

  it("AddAccount Should fail for non-existing address", async function () {
    const [, addr2] = await ethers.getSigners();
    await expect(contract.addAccount(1, 0, addr2.address)).to.be.revertedWith(
      "Account not found, please register"
    );
  });

  it("Should get the correct token amount from dollar", async function () {
    const amount = await contract.amountFromDollar(2);
    expect(amount).to.equal(2);
  });

  it("Should reduce account balance by 'activation fee' when activating an account", async function () {
    const [addr1] = await ethers.getSigners();
    const bal = await contract.balanceOf(addr1.address);
    await contract.activate(1);

    const balAfter = await contract.balanceOf(addr1.address);

    expect(bal.sub(balAfter).eq(ethers.utils.parseEther("2.5")));
  });

  it("Should activate and credit referral", async function () {
    const [, addr2, addr3, addr4] = await ethers.getSigners();
    await contract.register(1, 0, addr2.address);
    await contract.register(2, 0, addr3.address);
    await contract.register(3, 0, addr4.address);

    contract.activate(4);
    const user = await contract.getUser(4);
    expect(user.classicCheckpoint.gt(BigNumber.from("0"))).to.be.equal(true);

    const add2Bal = await contract.balanceOf(addr2.address);
    expect(add2Bal).not.equal(ethers.utils.parseEther("0.125"));

    const add3Bal = await contract.balanceOf(addr3.address);
    expect(add3Bal).not.equal(ethers.utils.parseEther("0.1"));
  });

  it("Should not activate accounts with insuficient fund", async function () {
    const [addr1, addr2] = await ethers.getSigners();
    const bal = await contract.balanceOf(addr1.address);
    await contract.transfer(addr2.address, bal);

    await expect(contract.activate(1)).to.be.revertedWith(
      "Insufficient balance"
    );
  });

  it("Should create a new account and activate it when registerAndActivate is called", async function () {
    const [, addr2] = await ethers.getSigners();
    const lastIndex = await contract.classicIndex();
    await contract.registerAndActivate(1, 0, addr2.address);

    const user = await contract.getUser(2);
    expect(parseInt(user.userClassicIndex)).to.be.equal(
      parseInt(lastIndex) + 1
    );
  });

  it("Should add new account for the sender when add account is call", async function () {
    const [addr] = await ethers.getSigners();
    await contract.addAccount(1, 0, addr.address);

    const accounts = await contract.getAccounts(addr.address);
    expect(accounts.length).to.be.equal(2);
  });

  it("Should not create account with invalid referral", async function () {
    const [addr] = await ethers.getSigners();
    await expect(contract.register(5, 0, addr.address)).to.be.revertedWith(
      "Invalid referrer ID"
    );
  });

  it("Should not create account with upline ID that is not a premium account", async function () {
    const [, addr2, addr3] = await ethers.getSigners();
    await contract.register(1, 0, addr2.address);
    await expect(contract.register(2, 2, addr3.address)).to.be.revertedWith(
      "Upline ID not a premium account"
    );
  });

  it("Should create multiple accounts for the user when registerAndActivateMultipleAccounts is call", async function () {
    const [addr] = await ethers.getSigners();
    const accountsB4 = await contract.getAccounts(addr.address);
    const classicIndex = await contract.classicIndex();

    await contract.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    const accountsAfter = await contract.getAccounts(addr.address);

    expect(accountsAfter.length).to.be.equal(accountsB4.length + 5);

    const lastID = parseInt(accountsAfter[accountsAfter.length - 1]);

    const lastUser = await contract.getUser(lastID);

    expect(parseInt(lastUser.userClassicIndex)).to.be.equal(
      parseInt(classicIndex) + 5
    );
  });

  it("Should add external account with the right properties if importClassicAccount", async function () {
    const contract = await deployContract();
    const [addr] = await ethers.getSigners();
    const id = 2;
    const referralID = 1;
    const level = 4;
    const downlinecount = 10;
    const bal = 550100;

    const classicIndex = await contract.classicIndex();
    await contract.importClassicAccount(
      addr.address,
      id,
      referralID,
      level,
      downlinecount,
      bal
    );

    const user = await contract.getUser(id);

    expect(parseInt(user.importClassicLevel), "level").to.be.equal(level);
    expect(parseInt(user.importedReferralCount), "referral").to.be.equal(
      downlinecount
    );
    expect(parseInt(user.outstandingBalance), "balance").to.be.equal(bal);
    expect(parseInt(user.userClassicIndex), "index").to.be.equal(
      parseInt(classicIndex) + 1
    );
  });

  it("Should get the right classic configuration", async function () {
    const config = await contract.getClassicConfig(1);
    //console.log(config);
    expect(config.earningDays).to.be.equal(10);
  });

  // // !!!! The next test covers this scenario
  // it("Should set the right classic level for users based of the classic rules", async function() {
  //   const [addr,] = await ethers.getSigners();
  //   await contract.activate(1);
  //   for(let i = 0; i < 20; i++) {
  //     await contract.addAndActivateMultipleAccounts(1, 0, addr.address, 50);
  //   }

  //   const classicLevel = await contract.getClassicLevel(1);
  //   expect(parseInt(classicLevel)).to.be.equal(1);
  // });

  it("Should increase the balance of a user by the right amount where withdraw is called", async function () {
    //return;
    await timeProvider.reset();
    const [addr] = await ethers.getSigners();
    await contract.activate(1);
    timeProvider.increaseTime(1*86400)

    for (let i = 0; i < 2; i++) {
      await contract.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    }

    //await network.provider.send("evm_increaseTime", [86400]);
    timeProvider.increaseTime(1*86400)

    for (let i = 0; i < 2; i++) {
      await contract.addAndActivateMultipleAccounts(1, 0, addr.address, 5);
    }
    
    timeProvider.increaseTime(1*86400)

    for (let i = 0; i < 2; i++) {
      await contract.addAndActivateMultipleAccounts(1, 0, addr.address, 10);
    }

    timeProvider.increaseTime(1*86400)

    let res = await contract.withdawable(1);

    expect(res[0], "First 3 days").to.be.equal(ethers.utils.parseEther("0.78"))

    const balanceBefore = await contract.balanceOf(addr.address);
    await contract.withdraw(1);

    const balanceAfter = await contract.balanceOf(addr.address);

    expect(
      balanceAfter.eq(ethers.utils.parseEther("0.702").add(balanceBefore))
    ).to.be.equal(true);

    // check the correctness of next days
    timeProvider.increaseTime(14*86400)
    res = await contract.withdawable(1);

    expect(res[0], "Next day").to.be.equal(ethers.utils.parseEther("3.92"))
  });
});

describe("Upgrade to Premimium", function() {
  it("Should upgrade a user if the sender has enough funds for premium fee", async function() {
    const [, addr2,] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address)
    await contract.upgradeToPremium(2, 176);
    const isPremium = await contract.accountIsInPremium(2);
    expect(isPremium).to.be.true;
  });

  it("Should debit the upgrade fee from the sender", async function() {
    const [addr1, addr2, addr3] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(2, 176);

    const balanceBefore = await contract.balanceOf(addr1.address);
    await contract.upgradeToPremium(3, 176);
    const balanceAfter = await contract.balanceOf(addr1.address);

    expect(balanceBefore).to.be.equal(ethers.utils.parseEther("20").add(balanceAfter));
  });

  it("Should get ancessor as sponsor for upgrade if upline is not in part", async function() {
    const [, addr2, addr3, addr4] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);
    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.registerAndActivate(3, 0, addr4.address);

    await contract.upgradeToPremium(4, 176);

    const uplineID = await contract.getMatrixUpline(4, 1);
    expect(parseInt(uplineID)).to.be.equal(2);
  });

  it("Should fail if caller has insufficient fund", async function() {
    const [addr1, addr2, ] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    const balance = await contract.balanceOf(addr1.address);
    await contract.transfer(addr2.address, balance);

    await expect(contract.upgradeToPremium(2, 43)).to.be.revertedWith("Insufficient balance")
  });

  it("Should fail if account not in classic", async function() {
    const [, addr2, ] = await ethers.getSigners();
    await contract.register(1, 0, addr2.address);

    await expect(contract.upgradeToPremium(2, 43)).to.be.revertedWith("Classic not activated")
  });

  it("Should get the right sponsor id", async function() {
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    await contract.upgradeToPremium(4, 176);

    await contract.registerAndActivate(2, 0, addr5.address);

    const uplineID = await contract.getPremiumSponsor(5, 0);
    expect(parseInt(uplineID)).to.be.equal(2);
  });

  it("Should arrange spill-over from left to right", async function() {
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    await contract.upgradeToPremium(4, 176);

    await contract.registerAndActivate(2, 0, addr5.address);

    await contract.upgradeToPremium(5, 176);

    const uplineID = await contract.getMatrixUpline(5, 1);
    expect(parseInt(uplineID)).to.be.equal(3);
  });

  it("Should transfer referral bonus to the premium upline", async function() {
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    await contract.upgradeToPremium(4, 176);

    await contract.registerAndActivate(2, 0, addr5.address);

    const uplineID = await contract.getPremiumSponsor(5, 0);
    expect(parseInt(uplineID), "right sponsor").to.be.equal(2);

    const balanceBefore = await contract.balanceOf(addr2.address);
    await contract.upgradeToPremium(5, 176);
    const balanceAfter = await contract.balanceOf(addr2.address);

    expect(balanceAfter).to.be.equal(ethers.utils.parseEther("9").add(balanceBefore));
  });

  it("Should transfer matrix bonus to the matrix upline", async function() {
    const [, addr2, addr3, addr4, addr5] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    await contract.upgradeToPremium(4, 176);

    await contract.registerAndActivate(2, 0, addr5.address);

    const balanceBefore = await contract.balanceOf(addr3.address);
    await contract.upgradeToPremium(5, 176);
    const balanceAfter = await contract.balanceOf(addr3.address);

    expect(balanceAfter).to.be.equal(ethers.utils.parseEther("2.25").add(balanceBefore));
  });

  it("Should move the user to the next level current is completed", async function() {
    const [, addr2, addr3, addr4, ] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    await contract.upgradeToPremium(4, 176);

    const user = await contract.getUser(2);
    expect(user.premiumLevel, "moved to next level").to.be.equal(2);

    const legs = await contract.getDirectLegs(1, 1);
    expect(parseInt(legs.left), "Placed under the upline").to.be.equal(2);
  });

  it("Should send matrix bonus of those without beneficiary to the main account", async function() {
    const [addr1, addr2, addr3, addr4, ] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addr2.address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addr3.address);
    await contract.upgradeToPremium(3, 176);

    await contract.registerAndActivate(2, 0, addr4.address);
    
    const balanceBefore = await contract.balanceOf(addr1.address);
    await contract.upgradeToPremium(4, 176);
    const balanceAfter = await contract.balanceOf(addr1.address);

    // the wallet paid 20 for the upgrade and 5 from matrix 2499637825-2499482825
    expect(balanceAfter).to.be.equal(balanceBefore.sub(ethers.utils.parseEther("15.5")));
  });

  it("Should add the user to part 2 when he completes part 1", async function() {
    const [...addresses ] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addresses[1].address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addresses[2].address);
    await contract.upgradeToPremium(3, 176);

    for(let i = 3; i <= 16; i++) {
      await contract.registerAndActivate(3, 0, addresses[i].address);
      await contract.upgradeToPremium(i+1, 176);
    }

    const user = await contract.getUser(3);
    expect(user.premiumLevel, "moved to next level").to.be.equal(3);

    const legs = await contract.getDirectLegs(1, 3);
    expect(parseInt(legs.left), "Placed under the upline").to.be.equal(3);
  });

  it("Should send pending matrix earning when a user enters a new level", async function() {
    const [...addresses ] = await ethers.getSigners();
    await contract.registerAndActivate(1, 0, addresses[1].address);
    await contract.upgradeToPremium(2, 176);

    await contract.registerAndActivate(2, 0, addresses[2].address);
    await contract.upgradeToPremium(3, 176);

    for(let i = 3; i <= 6; i++) {
      await contract.registerAndActivate(3, 0, addresses[i].address);
      await contract.upgradeToPremium(i+1, 176);
    }

    await contract.registerAndActivate(1, 0, addresses[7].address);
    await contract.upgradeToPremium(8, 176);

    await contract.registerAndActivate(1, 0, addresses[8].address);

    const balanceBefore = await contract.balanceOf(addresses[1].address);
    await contract.upgradeToPremium(9, 176);
    const balanceAfter = await contract.balanceOf(addresses[1].address);

    // 5 and 2.5 from matrix
    expect(balanceAfter).to.be.equal(balanceBefore.add(ethers.utils.parseEther("6.75")));

  });

});
