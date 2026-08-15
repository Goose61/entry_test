// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title FreelanceBountyBoard
 * @dev A decentralised marketplace for skills and bounties
 * @notice PART 1 - Freelance Bounty Board (MANDATORY)
 *
 * ---------------------------------------------------------------------------
 * IMPORTANT: THE AUTO-MARKER CALLS THESE EXACT FUNCTION AND EVENT SIGNATURES.
 * Do not rename them, reorder their parameters, or change their return types.
 * You may add anything you like alongside them.
 * ---------------------------------------------------------------------------
 */
contract FreelanceBountyBoard {
    /// @notice Open = posted, Submitted = work handed in, Completed = paid
    enum Status {
        Open,
        Submitted,
        Completed
    }

    // --- Events (the marker checks these are emitted) ---

    event FreelancerRegistered(address indexed freelancer, string skill);
    event BountyPosted(uint256 indexed bountyId, address indexed employer, uint256 amount);
    event AppliedForBounty(uint256 indexed bountyId, address indexed freelancer);
    event WorkSubmitted(uint256 indexed bountyId, address indexed freelancer, string submissionUrl);
    event BountyPaid(uint256 indexed bountyId, address indexed freelancer, uint256 amount);

    address public owner;

    /// @notice Total number of bounties ever posted. The first bounty has id 1.
    uint256 public bountyCount;

    // TODO: Define the rest of your state variables here.
    // Consider:
    // - How do you record who is registered, and with which skill?
    // - What does a bounty need to remember? (employer, description, skill,
    //   amount, status) A struct is a good fit here.
    // - How do you remember who applied for which bounty?

    constructor() {
        owner = msg.sender;
    }

    // -----------------------------------------------------------------------
    // TODO 1: registerFreelancer
    // -----------------------------------------------------------------------
    // Requirements:
    // - Store the caller's skill
    // - Revert if the caller is already registered
    // - Revert if the skill string is empty
    // - Emit FreelancerRegistered(msg.sender, skill)
    function registerFreelancer(string calldata skill) external {
        require(bytes(skill).length > 0, "Skill cannot be empty");
        require(bytes(freelancerSkills[msg.sender]).length == 0, "Already registered");

        freelancerSkills[msg.sender] = skill;

        emit FreelancerRegistered(msg.sender, skill);
    }

    // -----------------------------------------------------------------------
    // TODO 2: postBounty
    // -----------------------------------------------------------------------
    // Requirements:
    // - The employer sends the reward as msg.value; revert if it is zero
    // - Increment bountyCount; the new bounty's id is the new bountyCount
    // - Store employer, description, skillRequired, amount, Status.Open
    // - Emit BountyPosted(bountyId, msg.sender, msg.value)
    // - Return the new bountyId
    //
    // Think: the ETH simply stays in this contract until approval. You do not
    // need to send it anywhere yet.
    function postBounty(string calldata description, string calldata skillRequired)
        external
        payable
        returns (uint256)
    {
        require(msg.value > 0, "Must send ETH");

        bountyCount += 1;
        uint256 bountyId = bountyCount;

        bounties[bountyId] = Bounty({
            employer: msg.sender,
            description: description,
            skillRequired: skillRequired,
            amount: msg.value,
            status: Status.Open
        });

        emit BountyPosted(bountyId, msg.sender, msg.value);
        return bountyId;
    }

    // -----------------------------------------------------------------------
    // TODO 3: applyForBounty
    // -----------------------------------------------------------------------
    // Requirements:
    // - Caller must be a registered freelancer
    // - The bounty must exist and still be Open
    // - The caller's skill must match the bounty's skillRequired
    // - Revert on a duplicate application
    // - Emit AppliedForBounty(bountyId, msg.sender)
    //
    // Hint: Solidity cannot compare strings with ==. Compare hashes instead:
    //   keccak256(bytes(a)) == keccak256(bytes(b))
    function applyForBounty(uint256 bountyId) external {
        require(bytes(freelancerSkills[msg.sender]).length > 0, "Not registered");
        require(bountyId > 0 && bountyId <= bountyCount, "Bounty does not exist");

        Bounty storage bounty = bounties[bountyId];
        require(bounty.status == Status.Open, "Bounty not open");
        require(
            keccak256(bytes(freelancerSkills[msg.sender])) == keccak256(bytes(bounty.skillRequired)),
            "Skill mismatch"
        );
        require(!applications[bountyId][msg.sender], "Already applied");

        applications[bountyId][msg.sender] = true;

        emit AppliedForBounty(bountyId, msg.sender);
    }

    // -----------------------------------------------------------------------
    // TODO 4: submitWork
    // -----------------------------------------------------------------------
    // Requirements:
    // - Caller must have applied for this bounty
    // - The bounty must still be Open
    // - Set the bounty's status to Submitted
    // - Emit WorkSubmitted(bountyId, msg.sender, submissionUrl)
    function submitWork(uint256 bountyId, string calldata submissionUrl) external {
        function submitWork(uint256 bountyId, string calldata submissionUrl) external {
        require(bountyId > 0 && bountyId <= bountyCount, "Bounty does not exist");
        require(applications[bountyId][msg.sender], "Has not applied");

        Bounty storage bounty = bounties[bountyId];
        require(bounty.status == Status.Open, "Bounty not open");

        bounty.status = Status.Submitted;

        emit WorkSubmitted(bountyId, msg.sender, submissionUrl);
    }

    // -----------------------------------------------------------------------
    // TODO 5: approveAndPay
    // -----------------------------------------------------------------------
    // Requirements:
    // - Only the employer who posted this bounty may call it
    // - The bounty must be in Submitted status (so it cannot be paid twice)
    // - Pay the full bounty amount to the freelancer
    // - Emit BountyPaid(bountyId, freelancer, amount)
    //
    // SECURITY - this is the marked part:
    // Use checks-effects-interactions. Set the status to Completed BEFORE
    // sending the ETH, so a malicious freelancer contract cannot call back in
    // and be paid twice. Send with:
    //     (bool ok, ) = freelancer.call{value: amount}("");
    //     require(ok, "Transfer failed");
    // rather than transfer() or send().
    function approveAndPay(uint256 bountyId, address freelancer) external {
        require(bountyId > 0 && bountyId <= bountyCount, "Bounty does not exist");

        Bounty storage bounty = bounties[bountyId];

        // CHECKS
        require(msg.sender == bounty.employer, "Not the employer");
        require(bounty.status == Status.Submitted, "Work not submitted");
        require(applications[bountyId][freelancer], "Has not applied");

        uint256 amount = bounty.amount;

        // EFFECTS — mark completed before sending so a reentrant call cannot drain
        bounty.status = Status.Completed;

        // INTERACTIONS
        (bool ok, ) = freelancer.call{value: amount}("");
        require(ok, "Transfer failed");

        emit BountyPaid(bountyId, freelancer, amount);
    }

    // -----------------------------------------------------------------------
    // TODO 6: View functions (the marker calls all four)
    // -----------------------------------------------------------------------

    /// @notice True if this address has registered as a freelancer
    function isRegistered(address freelancer) external view returns (bool) {
        return bytes(freelancerSkills[freelancer]).length > 0;
    }

    /// @notice The skill this freelancer registered with ("" if unregistered)
    function getSkill(address freelancer) external view returns (string memory) {
         return freelancerSkills[freelancer];
    }

    /// @notice True if this freelancer applied for this bounty
    function hasApplied(uint256 bountyId, address freelancer) external view returns (bool) {
        return applications[bountyId][freelancer];
    }

    /// @notice All of a bounty's details, in this exact order
    function getBounty(uint256 bountyId)
        external
        view
        returns (
            address employer,
            string memory description,
            string memory skillRequired,
            uint256 amount,
            Status status
        )
    {
        Bounty storage bounty = bounties[bountyId];
        return (
            bounty.employer,
            bounty.description,
            bounty.skillRequired,
            bounty.amount,
            bounty.status
        );
    }

    // BONUS (not auto-marked, describe it in PartB_Design.md instead):
    // What happens if the employer never approves work that was genuinely done?
    // Sketch a timeout or dispute mechanism.
}
