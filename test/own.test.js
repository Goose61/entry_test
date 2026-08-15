const { expect } = require("chai");
const { ethers, network } = require("hardhat");

/**
 * Own tests for Part B. The auto-marker runs this folder separately from
 * grading/tests and awards marks if at least one of these passes.
 */

describe("FreelanceBountyBoard: unregistered applicants", function () {
  it("reverts when an unregistered address tries to apply", async function () {
    const [employer, alice] = await ethers.getSigners();
    const board = await ethers.deployContract("FreelanceBountyBoard");
    await board.waitForDeployment();

    await board.connect(employer).postBounty("Build a website", "solidity", {
      value: ethers.parseEther("1"),
    });

    await expect(board.connect(alice).applyForBounty(1)).to.be.reverted;
    expect(await board.hasApplied(1, alice.address)).to.equal(false);
  });
});

describe("DecentralisedRaffle: payout split is independent of who wins", function () {
  it("pays 90% to exactly one player and 10% to the owner, then empties", async function () {
    const [owner, alice, bob, carol] = await ethers.getSigners();
    const raffle = await ethers.deployContract("DecentralisedRaffle");
    await raffle.waitForDeployment();

    const entry = ethers.parseEther("0.01");
    const players = [alice, bob, carol];
    for (const p of players) {
      await raffle.connect(p).enterRaffle({ value: entry });
    }

    await network.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
    await network.provider.send("evm_mine");

    const pot = await raffle.getPot();
    const expectedPrize = (pot * 90n) / 100n;
    const expectedOwnerShare = pot - expectedPrize;

    const playerBefore = [];
    for (const p of players) {
      playerBefore.push(await ethers.provider.getBalance(p.address));
    }
    const ownerBefore = await ethers.provider.getBalance(owner.address);

    const tx = await raffle.connect(owner).selectWinner();
    const receipt = await tx.wait();
    const gasPaid = receipt.gasUsed * receipt.gasPrice;

    let winners = 0;
    for (let i = 0; i < players.length; i++) {
      const gained = (await ethers.provider.getBalance(players[i].address)) - playerBefore[i];
      if (gained === expectedPrize) winners++;
      else expect(gained).to.equal(0n);
    }
    expect(winners).to.equal(1);

    const ownerGained =
      (await ethers.provider.getBalance(owner.address)) + gasPaid - ownerBefore;
    expect(ownerGained).to.equal(expectedOwnerShare);
    expect(await ethers.provider.getBalance(await raffle.getAddress())).to.equal(0n);
  });
});
