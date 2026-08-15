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

On the bounty board I used mappings because lookups are by address or bounty id:
`freelancerSkills[addr]`, `bounties[id]`, and `applications[id][addr]`. A struct
holds each bounty's fields. I did not need an array there because the marker
never asks to list all bounties.

On the raffle I needed an **array** of every entry (`entries`). Each call to
`enterRaffle` pushes `msg.sender` once, so three tickets means the address
appears three times and is three times as likely to be drawn. Unique players
are a second array (`uniquePlayers`) plus `entryCounts[addr]`: the first time
someone enters this round their count is 0, so I push them onto `uniquePlayers`.
`getPlayerCount` is `entries.length`; `getUniquePlayerCount` is
`uniquePlayers.length`.

---

### 2. Security Measures

- **Reentrancy:** show the order of operations in `approveAndPay`. Which line
  updates the status, and which line sends the ETH? Why that order?
- **Access control:** which functions are owner-only or employer-only, and what
  would go wrong without those checks?
- **Input validation:** what did you reject, and where?

In `approveAndPay` the order is: check employer and `Submitted` status, copy
`amount`, set `bounty.status = Status.Completed`, **then**
`freelancer.call{value: amount}("")`. Status is updated before the send so a
malicious freelancer contract cannot re-enter `approveAndPay` while the bounty
is still `Submitted` and drain the pot a second time.

Owner-only: raffle `pause`, `unpause`, and `selectWinner`. Without those, anyone
could freeze entries, or draw the winner in a block they like. Employer-only:
`approveAndPay`. Without that, any applicant could pay themselves.

Rejected: empty skill; duplicate registration; zero-ETH bounty; unregistered or
wrong-skill or duplicate apply; submit without applying; entry below 0.01 ETH;
draw before 24 hours; draw with fewer than 3 unique players.

---

### 3. Randomness - Be Honest Here (4 marks)

You were allowed to use block data for the raffle draw. This section is where
you show you understand what that costs.

- What exactly does your randomness depend on?
- **Who can manipulate it, and how?** Name the actor and the action.
- What would you use in production instead, and why is that better?

The draw hashes `block.timestamp` and `block.prevrandao`, then takes that modulo
the number of entries. Both inputs are public on-chain data, so anyone can
recompute the same index inside the same block. This is **not** secure
randomness; it is a 3-hour shortcut.

Two actors can tilt it. The **block proposer / validator** can nudge the
timestamp within the protocol's allowed drift, and they choose `prevrandao`
(their previous mix). If the resulting index does not favour them (or a player
they care about), they can withhold or reorder the block and try again. The
**owner**, who is the only one allowed to call `selectWinner`, can also wait
and submit the draw in a block whose hash they have already computed to be
favourable — especially if they bought entries themselves. Any observer in the
same block can compute the outcome before acting.

In production I would use **Chainlink VRF**: request the random word in one
transaction, lock the raffle so nobody can enter while the request is in
flight, then pick the winner in the VRF callback. That value comes from
outside the chain and is verifiable, so neither the proposer nor the owner can
grind blocks to choose the winner. A commit-reveal among players would also
work, but VRF is the practical choice here.

---

### 4. Trade-offs & Future Improvements

- What did you not finish, or knowingly do the quick way?
- What would you add with another day? (dispute resolution, refunds, prize
  tiers, gas optimisation)

I knowingly used block data for the draw, and I did not record *who submitted*
on a bounty — `approveAndPay` takes a freelancer argument, so the employer can
pay any applicant, not necessarily the one who handed in the work.

With another day I would: store `submittedBy` and require it on payout; add a
timeout so a freelancer can reclaim the ETH if the employer never approves;
refund all raffle entries if 24 hours pass with fewer than 3 unique players;
and stop deleting the whole `entries` array on reset (that will hit the gas
limit at large n). Prize tiers (1st/2nd/3rd) would be a later extra.

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

`selectWinner` is the most expensive. It reads the whole entries array for the
index, loops `uniquePlayers` to clear the mapping, deletes both arrays, then
makes two ETH `call`s. That is several storage writes plus the transfers.

A rough figure for a small draw is ~200,000 gas. At 20 gwei that is
200,000 × 20 = 4,000,000 gwei = 0.004 ETH ≈ **$12**. A first-time `enterRaffle`
is cheaper (maybe ~80,000 gas → 0.0016 ETH ≈ **$4.80**) on top of the 0.01 ETH
ticket (~$30). For a hobby raffle on mainnet that is steep. I would deploy on
an L2 (cheaper data) and keep the ticket in the same units.

---

### 2. Scalability

**What happens when the raffle has 10,000 entries?**

- Which part of `selectWinner` gets slower or more expensive as the array grows?
- What breaks first?

The reset. `delete entries` writes a zero to every slot, and the loop over
`uniquePlayers` does a storage delete per address. Both are O(n). The modulo
itself is cheap; the array does not even need to be walked to pick an index.

What breaks first is the **block gas limit**. At a few thousand entries the
reset will revert because the transaction cannot fit. Players' funds would sit
in the contract until a draw that actually succeeds. A production version
should not zero the whole array in one transaction — e.g. increment a
`roundId` and key mappings by round so old entries are simply ignored.

---

### 3. User Experience

**How would you make this usable for someone who has never held a wallet?**

- What is the hardest step for a first-time user?
- If you *were* deploying this for real, which testnet would you try it on
  first, and how would a tester get test ETH? (Describe it - you are not doing
  it.)

The hardest step is **getting a wallet and not losing the seed phrase**. After
that, knowing they must send 0.01 ETH with the entry call, not just click a
button. Account abstraction (a smart account with social recovery, gas
sponsored by us) would hide most of that.

I would try **Sepolia** first. A tester installs a wallet, switches the network
to Sepolia, and uses a public Sepolia faucet (or a faucet that requires a
GitHub/Alchemy login) to receive test ETH. Nothing on that network is real
money; we would only move to mainnet after the flows work there.

---

## MY LEARNING APPROACH

### Resources I Used

- Cyfrin Updraft, Blockchain Basics: The Oracle Problem
- Cyfrin Updraft, Blockchain Basics: wallets, keys and signatures
- `docs/SOLIDITY-PATTERNS.md` in this repo — checks-effects-interactions, pause,
  and `call` vs `transfer`
- `grading/tests/FreelanceBountyBoard.grading.test.js` and
  `DecentralisedRaffle.grading.test.js` as the actual spec
- Solcurity / SWC-120 notes on why `block.timestamp` / `prevrandao` is not
  randomness

---

### Challenges Faced

- The biggest stuck point was keeping unique players and total entries as two
  different numbers, and remembering to clear `entryCounts` on reset so round 2
  does not think returning players are already unique.
- I got unstuck by reading the marker tests: `getPlayerCount` is total tickets,
  `getUniquePlayerCount` is distinct addresses, and the 3-player rule uses the
  second one.
- I now know why you update state before sending ETH, and that "hash the block"
  is a shortcut I have to admit, not a design I can call secure.

---

### What I'd Learn Next

Foundry for faster tests, Chainlink VRF for a real draw, and a simple
commit-reveal so I can implement one without an oracle. After that, reading
how a production raffle handles refunds and gas-limited resets.

---
