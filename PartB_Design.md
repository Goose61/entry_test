# Part B: Design Document

**Marks:** 4 of 100 - the **Randomness** section below is read and marked. The
rest of this document is not scored, but it is read when we talk to you, so
answer it properly.

**Section 1: FreelanceBountyBoard**
**Section 2: DecentralisedRaffle**

Short, specific answers beat long vague ones. Three honest sentences score better
than a page of general security talk. If you ran out of time on something, say
so here - describing what you would have done still earns marks. Pretending it
is finished does not.

---

## WHY I BUILT IT THIS WAY

### 1. Data Structure Choices

- Where did you use a `mapping`, and where did you need an array instead?
- How did you record raffle entries so that a player who enters three times has
  three times the chance of winning?
- How did you count unique players separately from total entries?

BountyBoard uses mappings because lookups are by address or bounty id: `_registered`,
`_skills`, `_bounties`, and `_applied[bountyId][freelancer]`. I did not need an
array of bounties because the marker never iterates them.

The raffle needs an array. `_entries` stores one address per ticket, so the same
player appears three times if they bought three entries. `selectWinner` picks
`index % _entries.length`, which gives that player three times the chance.

Unique players are a separate counter. On a player's first entry of the current
`raffleId` I increment `_uniquePlayerCount` and stamp `_lastEnteredRaffleId`.
Total entries is just `_entries.length`. After a draw I `delete _entries` and
zero the unique count; stale per-address counts are ignored because they belong
to an old raffle id.

---

### 2. Security Measures

- **Reentrancy:** show the order of operations in `approveAndPay`. Which line
  updates the status, and which line sends the ETH? Why that order?
- **Access control:** which functions are owner-only or employer-only, and what
  would go wrong without those checks?
- **Input validation:** what did you reject, and where?

`approveAndPay` is checks-effects-interactions (F6 / SWC-107). After the
employer / Submitted / applied checks, I set `bounty.status = Completed` and
`bounty.amount = 0`, emit `BountyPaid`, and only then
`freelancer.call{value: amount}("")`. If a malicious freelancer contract
re-enters during that call, status is already Completed so the second pay
reverts.

Raffle `pause` / `unpause` / `selectWinner` are `onlyOwner`. Without that,
anyone could freeze entries or draw the winner when it suited them. Bounty
`approveAndPay` is employer-only; without it any caller could pay themselves
the escrowed ETH.

I reject an empty skill, a duplicate registration, zero-ETH bounties, missing
bounties, skill mismatches, duplicate applications, applications from
unregistered addresses, submissions from people who did not apply, raffle
entries below 0.01 ETH, draws before 24 hours, and draws with fewer than three
unique players.

---

### 3. Randomness - Be Honest Here (4 marks)

You were allowed to use block data for the raffle draw. This section is where
you show you understand what that costs.

- What exactly does your randomness depend on?
- **Who can manipulate it, and how?** Name the actor and the action.
- What would you use in production instead, and why is that better?

The draw is
`keccak256(abi.encodePacked(block.timestamp, block.prevrandao, raffleId)) % _entries.length`.
Every input is public on-chain data. This is **not** secure randomness
(Solcurity C9 / SWC-120).

The **block proposer** (or an L2 sequencer) can influence `timestamp` and
`prevrandao`, and can withhold or reorder a block if the resulting winner is
not the one they want. **Any player in the same block** can recompute the same
hash and only call `enterRaffle` (or skip) when the index favours them. The
**owner** who calls `selectWinner` also chooses the transaction's timing.

In production I would use **Chainlink VRF**: request in one transaction, lock
entries, receive the proof in a callback. A commit-reveal among players would
also work, with a penalty for anyone who does not reveal. Both take the
outcome off a single proposer's private choice.

---

### 4. Trade-offs & Future Improvements

- What did you not finish, or knowingly do the quick way?
- What would you add with another day? (dispute resolution, refunds, prize
  tiers, gas optimisation)

I knowingly used the block-data shortcut for the raffle because VRF is out of
scope. I also push-pay the winner and owner in `selectWinner`; a reverting
recipient can freeze the draw (C26).

With another day I would add: a 7-day timeout so a freelancer can reclaim a
Submitted bounty the employer never approved; refunds if a raffle expires with
fewer than three unique players; 1st/2nd/3rd prize tiers; and a pull-payment
pattern so a griefing winner cannot brick `selectWinner`.

---

## REAL-WORLD DEPLOYMENT CONCERNS

> [!NOTE]
> These are **written questions only**. You are not deploying anything, and you
> do not need a wallet, a faucet or any test ETH to answer them. Reason it
> through in prose.

### 1. Gas Costs

- Which of your functions is the most expensive, and why?
- Roughly what would it cost a user at 20 gwei, with ETH at $3,000? (Use the
  same arithmetic as Part A Question 2.)
- Is that affordable for the users you would actually be building this for? If
  not, what would you change?

`selectWinner` is the most expensive: it hashes, writes several storage slots,
deletes the entries array, and makes two ETH calls. A rough ballpark is
~80,000–150,000 gas depending on array size. At 20 gwei that is
100,000 × 20 = 2,000,000 gwei = 0.002 ETH ≈ $6. `enterRaffle` is cheaper, on
the order of a storage write, maybe ~0.001 ETH / ~$3 at the same price.

For a 0.01 ETH raffle, a $3 entry fee on top of the ticket is painful. I would
run it on an L2 (cheaper data) and keep the 0.01 ETH minimum, or raise the
minimum so gas is a small fraction of the ticket.

---

### 2. Scalability

**What happens when the raffle has 10,000 entries?**

- Which part of `selectWinner` gets slower or more expensive as the array grows?
- What breaks first?

Picking the winner is O(1) — one hash and one array read. What grows is
`delete _entries`, which refunds gas per slot but still scales with length, and
the calldata/storage of 10,000 `enterRaffle` calls over the round.

What breaks first is gas on reset, or simply that 10,000 separate entry
transactions are expensive for users. I would switch to a mapping keyed by
round id and not copy/delete a giant array, or cap entries per round.

---

### 3. User Experience

**How would you make this usable for someone who has never held a wallet?**

- What is the hardest step for a first-time user?
- If you *were* deploying this for real, which testnet would you try it on
  first, and how would a tester get test ETH? (Describe it - you are not doing
  it.)

The hardest step is getting a wallet, backing up a seed phrase, and paying gas
in ETH they do not yet have. Account abstraction (smart accounts, a paymaster
sponsoring gas) would let someone enter with an email login and no seed phrase
on day one.

I would try **Sepolia** first (chain id 11155111). A tester would create a
wallet, then use a Sepolia faucet such as the Chainlink faucet, Google Cloud's
Sepolia faucet, or Alchemy's, and send a tiny amount of test ETH before
calling `enterRaffle`. Nothing here is actually deployed.

---

## MY LEARNING APPROACH

### Resources I Used

Be specific. "The Cyfrin course" is not a resource; "Blockchain Basics, The
Oracle Problem" is. List 3-5.

- Cyfrin Updraft, Blockchain Basics — The Oracle Problem; Introduction to Gas;
  L1s, L2s and Rollups; Account Abstraction
- This repo's `docs/SOLIDITY-PATTERNS.md` — checks-effects-interactions and
  Solcurity C9 on randomness
- Solcurity F6 / SWC-107 (reentrancy) and C33 (use `call`, not `transfer`)
- Chainlink VRF docs — what I would use instead of block data
- The marker tests in `grading/tests/` as the spec

---

### Challenges Faced

- The biggest thing you got stuck on
- How you got unstuck
- What you know now that you did not this morning

The unique-player vs total-entry distinction: an array of tickets is not the
same as a set of addresses. I got unstuck by reading the marker's
`getPlayerCount` vs `getUniquePlayerCount` assertions. I also had to be
deliberately honest that the raffle RNG is broken, rather than dressing it up.

---

### What I'd Learn Next

Foundry (fuzzing and invariant tests), a real Chainlink VRF integration, and
writing a pull-payment escrow with a timeout so employers cannot strand funds.

---
