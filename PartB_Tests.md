# Part B: Test Scenarios Guide

**Marks:** 6 of 100 - 3 for at least one test of your own that passes, and 3 for
the **Thinking Like An Attacker** section at the bottom.

The auto-marker already runs its own test suite against your contracts. This
section is about whether *you* can think like a tester.

**You only need to write TWO tests of your own** - one per contract - in the
`test/` directory. There is a worked example in `test/example.test.js` you can
copy from. Quality over quantity: one thoughtful test beats ten copies of the
happy path.

Run them with:

```bash
npx hardhat test
```

---

## Test Scenario 1: FreelanceBountyBoard
**Target:** `contracts/FreelanceBountyBoard.sol`

### 1.1 The test I wrote

- **Test file and name:** `test/own.test.js` — `"reverts when an unregistered address tries to apply"`
- **What it checks:** `applyForBounty` rejects a caller who never called `registerFreelancer`, and does not record an application.
- **Steps:** Deploy the board. Employer posts a 1 ETH solidity bounty. Alice (unregistered) calls `applyForBounty(1)`.
- **Expected result:** The transaction reverts. `hasApplied(1, alice)` stays false.
- **Does it pass?** yes

### 1.2 A scenario I did NOT have time to test

Describe one thing that could go wrong with this contract that neither you nor
the auto-marker checked. You do not have to write the code - just show you can
see the gap.

If two freelancers apply and both could submit, the first `submitWork` moves
the bounty to Submitted and the second submit reverts. The marker never checks
that. Worse: the employer can `approveAndPay` any applied address, not
necessarily the one who submitted. I did not write a test that employer pays
Bob after Alice submitted.

---

## Test Scenario 2: DecentralisedRaffle
**Target:** `contracts/DecentralisedRaffle.sol`

### 2.1 The test I wrote

- **Test file and name:** `test/own.test.js` — `"pays 90% to exactly one player and 10% to the owner, then empties"`
- **What it checks:** After 24 hours, exactly one of three players receives 90% of the pot, the owner receives the remaining 10% (minus their own gas), and the contract balance is zero.
- **Steps:** Alice, Bob and Carol each enter with 0.01 ETH. Fast-forward 24 hours. Owner calls `selectWinner`. Compare balances before/after.
- **Expected result:** One player gained exactly `(pot * 90) / 100`; the others gained 0; owner gained the rest; pot is 0.
- **Does it pass?** yes

### 2.2 The hard one

Testing a raffle is awkward because the winner changes every run. **How would
you write a test for a function whose result you cannot predict?** What can you
assert that is true no matter who wins?

(Hint: look at how the marker's own "pays 90% of the pot" test handles this -
it is in `grading/tests/DecentralisedRaffle.grading.test.js` and you are welcome
to read it.)

Do not assert a specific winner. Snapshot every player's balance, draw, then
count how many players gained exactly the 90% prize (must be 1) and that
everyone else gained 0. Also assert the contract is empty and the owner
received the leftover 10%. Those invariants hold whoever the hash picked.

---

## Thinking Like An Attacker (3 marks)

Pick **one** of your two contracts. If you wanted to steal from it or break it,
what would you try first?

- **Contract:** DecentralisedRaffle
- **My attack:** Wait until I am about to call `enterRaffle` (or, if I am the
  block proposer, when `selectWinner` is in the mempool). Recompute
  `keccak256(abi.encodePacked(block.timestamp, block.prevrandao, raffleId)) % entries.length`
  including my extra ticket. Only send the transaction if the index lands on me.
  A proposer can go further: build a block, see the winner, and withhold the
  block if it is not them.
- **Does it work against my implementation?** yes
- **If it works, what would fix it?** Do not derive the winner from block data
  (C9). Request Chainlink VRF in one transaction, pause entries, and fulfil in
  a callback with a verifiable proof. Commit-reveal among players is the other
  honest option. I shipped the shortcut anyway because VRF is out of scope; I
  am not claiming it is secure.

An honest "yes, this attack works against my code, and here is the fix" scores
full marks here. Claiming your contract is perfect scores nothing.

The same class of bug exists on the bounty board if I had sent ETH before
setting status to Completed. I did set status first, so a reentering freelancer
contract should fail the Submitted check. I would still add a reentrancy lock
if this were production money.

---

## Checklist

- [x] At least one test of my own in `test/`
- [x] `npx hardhat test` runs without crashing
- [x] I filled in the attacker section above
