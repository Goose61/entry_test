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

[Write your response here]

---

### 2. Security Measures

- **Reentrancy:** show the order of operations in `approveAndPay`. Which line
  updates the status, and which line sends the ETH? Why that order?
- **Access control:** which functions are owner-only or employer-only, and what
  would go wrong without those checks?
- **Input validation:** what did you reject, and where?

[Write your response here]

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
favourable — especially if they bought entries themselves.

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

[Write your response here]

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

[Write your response here]

---

### 2. Scalability

**What happens when the raffle has 10,000 entries?**

- Which part of `selectWinner` gets slower or more expensive as the array grows?
- What breaks first?

[Write your response here]

---

### 3. User Experience

**How would you make this usable for someone who has never held a wallet?**

- What is the hardest step for a first-time user?
- If you *were* deploying this for real, which testnet would you try it on
  first, and how would a tester get test ETH? (Describe it - you are not doing
  it.)

[Write your response here]

---

## MY LEARNING APPROACH

### Resources I Used

Be specific. "The Cyfrin course" is not a resource; "Blockchain Basics, The
Oracle Problem" is. List 3-5.

[List your resources]

---

### Challenges Faced

- The biggest thing you got stuck on
- How you got unstuck
- What you know now that you did not this morning

[Write down your challenges]

---

### What I'd Learn Next

[Write your future learning goals]

---
