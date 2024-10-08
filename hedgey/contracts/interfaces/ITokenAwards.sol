// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenAwards {
  struct Award {
    uint256 amount;
    uint256 start;
    uint256 cliff;
    uint256 rate;
    uint256 period;
    address manager;
  }

  struct Recipient {
    address beneficiary;
    bool managerRedeem;
  }

  struct ForwardRecipient {
    address beneficiary;
    uint16 percent;
  }

  struct ClaimRequirement {
    address target;
    string functionSelector;
  }

  function getAward(uint256 id) external view returns (Award memory);

  function getAwardFunding(
    uint256 id,
    uint256 fundingTime
  )
    external
    view
    returns (bool funded, uint256 balance, uint256 remainder, uint256 latestUnlock, uint256 excessFunding);

  function getAwardDuration(uint256 id) external view returns (uint256 duration, uint256 end);

  function createAward(
    Recipient memory recipient,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 period
  ) external returns (uint256 id);

  function createAwardWithClaimRequirements(
    Recipient memory recipient,
    uint256 amount,
    uint256 start,
    uint256 cliff,
    uint256 rate,
    uint256 period,
    ClaimRequirement[] memory claimRequirements
  ) external returns (uint256 id);

  function editAward(uint256 id, uint256 amount, uint256 start, uint256 cliff, uint256 rate, uint256 period) external;

  function updateRequirementsForAwards(uint256[] memory ids, ClaimRequirement[][] memory requirements) external;

  function redeemAwards(
    uint256[] calldata ids
  ) external returns (uint256[] memory balanceClaimed, uint256[] memory remainder, uint256[] memory latestUnlock);

  function redeemAwardsWithData(
    uint256[] calldata ids,
    bytes[] calldata data
  ) external returns (uint256[] memory balanceClaimed, uint256[] memory remainder, uint256[] memory latestUnlock);

  function cancelAward(uint256 id) external;

  function cancelAwardWithPayment(uint256 id, uint256 paymentDate) external;

  function createForwardingRecipients(uint256 id, ForwardRecipient[] memory recipients) external;

  function removeForwardRecipients(uint256 id, address[] memory recipients) external;

  function editForwardRecipient(uint256 id, ForwardRecipient memory recipient, uint256 recipientIndex) external;

  function toggleForwarding(uint256 id, bool forwardToggle) external;
}
