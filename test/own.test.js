const { expect } = require("chai");
const { ethers, network } = require("hardhat");

const ENTRY = ethers.parseEther("0.01");
const ONE_DAY = 24 * 60 * 60;

describe("Own tests: gaps the marker does not cover", function () {
  describe("FreelanceBountyBoard", function () {
    let board, employer, alice;
    const reward = ethers.parseEther("1");

    beforeEach(async function () {
      [employer, alice] = await ethers.getSigners();
      board = await ethers.deployContract("FreelanceBountyBoard");
      await board.waitForDeployment();
    });

    it("rejects submitWork from someone who never applied", async function () {
      await board.connect(alice).registerFreelancer("solidity");
      await board.connect(employer).postBounty("Build a website", "solidity", { value: reward });

      await expect(
        board.connect(alice).submitWork(1, "https://github.com/alice/work")
      ).to.be.reverted;

      const bounty = await board.getBounty(1);
      expect(Number(bounty[4])).to.equal(0); // still Open
    });
  });

  describe("DecentralisedRaffle", function () {
    let raffle, owner, alice, bob, carol;

    beforeEach(async function () {
      [owner, alice, bob, carol] = await ethers.getSigners();
      raffle = await ethers.deployContract("DecentralisedRaffle");
      await raffle.waitForDeployment();
    });

    it("resets entry counts so a returning player is unique again next round", async function () {
      await raffle.connect(alice).enterRaffle({ value: ENTRY });
      await raffle.connect(bob).enterRaffle({ value: ENTRY });
      await raffle.connect(carol).enterRaffle({ value: ENTRY });

      await network.provider.send("evm_increaseTime", [ONE_DAY + 1]);
      await network.provider.send("evm_mine");
      await raffle.connect(owner).selectWinner();

      expect(await raffle.raffleId()).to.equal(2n);
      expect(await raffle.getEntryCount(alice.address)).to.equal(0n);
      expect(await raffle.getUniquePlayerCount()).to.equal(0n);

      await raffle.connect(alice).enterRaffle({ value: ENTRY });

      expect(await raffle.getEntryCount(alice.address)).to.equal(1n);
      expect(await raffle.getUniquePlayerCount()).to.equal(1n);
      expect(await raffle.getPlayerCount()).to.equal(1n);
    });
  });
});