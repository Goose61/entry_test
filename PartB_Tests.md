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

- **Test file and name:** `test/own.test.js` — `"rejects submitWork from someone who never applied"`
- **What it checks:** You cannot hand in work for a bounty you did not apply to, even if you are a registered freelancer with the matching skill.
- **Steps:** Alice registers as solidity and Bob posts a 1 ETH bounty. Alice does **not** apply. Alice calls `submitWork`.
- **Expected result:** The transaction reverts, and the bounty stays `Open`.
- **Does it pass?** yes

### 1.2 A scenario I did NOT have time to test

The employer can call `approveAndPay(bountyId, freelancer)` with **any** address
that applied, not the person who submitted. I never wrote a test that has Alice
submit and then has the employer pay Bob (who only applied). That should either
revert or, today, succeed — and the fact I am not sure without running it is
the gap.

---

## Test Scenario 2: DecentralisedRaffle
**Target:** `contracts/DecentralisedRaffle.sol`

### 2.1 The test I wrote

- **Test file and name:** `test/own.test.js` — `"resets entry counts so a returning player is unique again next round"`
- **What it checks:** After a draw, `getEntryCount` is 0 for last round's players, and if Alice enters again she is counted as one unique player in the new raffle rather than being skipped.
- **Steps:** Alice, Bob and Carol each enter once. Fast-forward 24 hours. Owner draws. Alice enters the new round.
- **Expected result:** After the draw, Alice's entry count is 0. After she re-enters, unique players = 1 and her entry count = 1. `raffleId` is 2.
- **Does it pass?** yes

### 2.2 The hard one

Testing a raffle is awkward because the winner changes every run. **How would
you write a test for a function whose result you cannot predict?** What can you
assert that is true no matter who wins?

(Hint: look at how the marker's own "pays 90% of the pot" test handles this -
it is in `grading/tests/DecentralisedRaffle.grading.test.js` and you are welcome
to read it.)

Do not assert a specific winner. Snapshot every player's balance, draw, then
check properties that must hold for **whoever** won: exactly one player gained
`(pot * 90) / 100`, the others gained 0, the contract balance is 0, and
`WinnerSelected` was emitted. The marker does that loop over players. You can
also assert the owner received the leftover 10% (plus dust from integer
division) if you snapshot the owner too — but then you have to subtract gas,
because the owner sent the transaction.

---

## Thinking Like An Attacker (3 marks)

Pick **one** of your two contracts. If you wanted to steal from it or break it,
what would you try first?

- **Contract:** FreelanceBountyBoard
- **My attack:** After Alice applies and submits work, I (the employer) call
  `approveAndPay` with Bob's address instead. Bob only needed to apply; he
  never submitted. `submitWork` never stores who handed the work in, and
  `approveAndPay` only checks that the named freelancer applied and that status
  is `Submitted`. So I can send Alice's bounty to Bob (or to a second account I
  control that registered and applied).
- **Does it work against my implementation?** yes
- **If it works, what would fix it?** Store `bounty.submittedBy = msg.sender`
  inside `submitWork`, then in `approveAndPay` require
  `freelancer == bounty.submittedBy`. Even better: drop the freelancer
  argument and always pay `submittedBy`.

A second attack that also works: I never call `approveAndPay` at all. Alice's
work is done, the ETH stays in the contract forever. A timeout (after N days
the submitter can claim, or a refund window) would fix that; I did not build
it.

---

## Checklist

- [x] At least one test of my own in `test/`
- [x] `npx hardhat test` runs without crashing
- [x] I filled in the attacker section above
