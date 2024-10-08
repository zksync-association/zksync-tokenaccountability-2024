// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/DistributorLibrary.sol";
import "./interfaces/IProgramManagerFactory.sol";
import './interfaces/IReceiveCallee.sol';

contract AwardDistributor is ERC721Enumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private _awardIds;
    IERC20 public token;

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

    mapping(uint256 => Award) internal _awards;

    mapping(uint256 => mapping(address => bool)) internal _approvedRedeemers;

    mapping(address => mapping(address => bool)) internal _redeemerOperators;

    mapping(uint256 => bool) internal _managerRedeem;

    mapping(uint256 => bool) internal _forwardingOn;

    mapping(uint256 => uint16) internal _forwardPercent;

    mapping(uint256 => ForwardRecipient[]) internal _forwardRecipients;

    mapping(uint256 => mapping(address => uint256)) internal _forwardIndex;

    mapping(uint256 => ClaimRequirement[]) internal _claimRequirements;


    // events
    event AwardCreated(
        uint256 id,
        address manager,
        address recipient,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 end,
        uint256 rate,
        uint256 period
    );
    event AwardCancelled(uint256 id, uint256 payout);
    event AwardRedeemed(uint256 id, uint256 payout);

    constructor(
        address _token
    ) ERC721("AwardDistributor", "AD") {
        token = IERC20(_token);
    }

    /*****TOKEN ID FUNCTIONS************************************************************************************ */

    function incrementAwardId() internal returns (uint256) {
        _awardIds++;
        return _awardIds;
    }

    function currentAwardId() public view returns (uint256) {
        return _awardIds;
    }

    /*****PUBLIC GETTER FUNCTIONS****************************************************************************/

    function getAward(uint256 id) public view returns (Award memory) {
        return _awards[id];
    }

    function getAwardFunding(
        uint256 id,
        uint256 fundingTime
    )
        public
        view
        returns (
            bool funded,
            uint256 balance,
            uint256 remainder,
            uint256 latestUnlock,
            uint256 excessFunding
        )
    {
        Award memory a = _awards[id];
        (balance, remainder, latestUnlock) = DistributorLibrary.balanceAtTime(
            fundingTime,
            a.start,
            a.cliff,
            a.amount,
            a.rate,
            a.period
        );
        uint256 funderBalance = token.balanceOf(a.manager);
        uint256 approvalBalance = token.allowance(a.manager, address(this));
        uint256 availableBalance = DistributorLibrary.min(
            funderBalance,
            approvalBalance
        );
        funded = availableBalance >= balance;
        excessFunding = funded ? availableBalance - balance : 0;
    }

    function getAwardDuration(
        uint256 id
    ) public view returns (uint256 duration, uint256 end) {
        Award memory a = _awards[id];
        end = DistributorLibrary.getEnd(
            a.start,
            a.amount,
            a.rate,
            a.period
        );
        duration = (end - a.start) / a.period;
    }

    function getClaimRequirements(
        uint256 id
    ) external view returns (ClaimRequirement[] memory) {
        return _claimRequirements[id];
    }

    function hasMetRequirements(uint256 id) public returns (bool) {
        uint256 reqLen = _claimRequirements[id].length;
        if (reqLen > 0) {
            address owner = ownerOf(id);
            for (uint256 i; i < reqLen; i++) {
                ClaimRequirement memory c = _claimRequirements[id][i];
                bytes memory data = abi.encodeWithSignature(c.functionSelector, owner);
                (bool success, bytes memory returnData) = c.target.call(data);
                if (success) {
                    bool hasMet = abi.decode(returnData, (bool));
                    if (!hasMet) {
                        return false;
                    }
                } else {
                    return false;
                }
            }
        }
        return true;
    }

    /*******************REDEEMER FUNCTIONS************************************************************************/

    /// @notice function to approve a new redeemer who can call the redeemVesting or unlock functions
    /// @param id is the token Id of the NFT
    /// @param redeemer is the address of the new redeemer (it can be the zero address)
    /// @dev only owner of the NFT can call this function
    /// @dev if the zero address is set to true, then it becomes publicly avilable for anyone to redeem
    function approveRedeemer(uint256 id, address redeemer) external {
        require(
            msg.sender == ownerOf(id) ||
                _redeemerOperators[ownerOf(id)][msg.sender]
        );
        _approvedRedeemers[id][redeemer] = true;
        // emit RedeemerApproved(grantId, redeemer);
    }

    /// @notice function to remove an approved redeemer
    /// @param id is the token Id of the NFT
    /// @param redeemer is the address of the redeemer to be removed
    /// @dev this function simply deletes the storage of the approved redeemer
    function removeRedeemer(uint256 id, address redeemer) external {
        require(
            msg.sender == ownerOf(id) ||
                _redeemerOperators[ownerOf(id)][msg.sender]
        );
        delete _approvedRedeemers[id][redeemer];
        // emit RedeemerRemoved(grantId, redeemer);
    }

    function approveRedeemerOperator(address operator, bool approved) external {
        _redeemerOperators[msg.sender][operator] = approved;
    }

    /// @notice function to set the admin redemption toggle on a specific lock NFT
    /// @param id is the token Id of the NFT
    /// @param enabled is the boolean toggle to allow the vesting admin to redeem on behalf of the owner
    function setManagerRedemption(uint256 id, bool enabled) external {
        require(
            msg.sender == ownerOf(id) ||
                _redeemerOperators[ownerOf(id)][msg.sender]
        );
        _managerRedeem[id] = enabled;
        // emit AdminRedemption(grantId, enabled);
    }

    /// @notice function to check if the admin can redeem on behalf of the owner
    /// @param id is the token Id of the NFT
    /// @param manager is the address of the admin
    function managerCanRedeem(
        uint256 id,
        address manager
    ) public view returns (bool) {
        return (_managerRedeem[id] && manager == _awards[id].manager);
    }

    /// @notice function to check if a specific address is an approved redeemer
    /// @param id is the token Id of the NFT
    /// @param redeemer is the address of the redeemer
    /// @dev will return true if the redeemer is the owner of the NFT, if the redeemer is approved or if the 0x0 address is approved, or if the redeemer is the admin address
    function isApprovedRedeemer(
        uint256 id,
        address redeemer
    ) public view returns (bool) {
        address owner = ownerOf(id);
        return (owner == redeemer ||
            _approvedRedeemers[id][redeemer] ||
            _approvedRedeemers[id][address(0x0)] ||
            _redeemerOperators[owner][redeemer] ||
            managerCanRedeem(id, redeemer));
    }

    /*******************FORWARDING FUNCTIONS***************************************************************************************/

    function createForwardingRecipients(
        uint256 id,
        ForwardRecipient[] memory recipients
    ) external {
        require(ownerOf(id) == msg.sender, "!owner");
        _forwardingOn[id] = true;
    for (uint256 i; i < recipients.length; i++) {
      _forwardPercent[id] += recipients[i].percent;
      _forwardIndex[id][recipients[i].beneficiary] = _forwardRecipients[id].length;
      _forwardRecipients[id].push(recipients[i]);
    }
    require(_forwardPercent[id] <= 10000, 'percent error');
    }

    function removeForwardRecipients(uint256 id, address[] memory recipients) external {
    require(ownerOf(id) == msg.sender, '!owner');
    for (uint8 i = 0; i < recipients.length; i++) {
      _removeForwardRecipient(id, recipients[i]);
    }
  }

  function _removeForwardRecipient(uint256 id, address recipient) internal {
    uint256 removalIndex = _forwardIndex[id][recipient];
    _forwardPercent[id] -= _forwardRecipients[id][removalIndex].percent;
    ForwardRecipient memory lastRecipient = _forwardRecipients[id][_forwardRecipients[id].length - 1];
    _forwardRecipients[id][removalIndex] = lastRecipient;
    _forwardIndex[id][lastRecipient.beneficiary] = removalIndex;
    _forwardRecipients[id].pop();
  }

  function editForwardRecipient(uint256 id, ForwardRecipient memory recipient, uint256 recipientIndex) external {
    require(ownerOf(id) == msg.sender, '!owner');
    uint16 existingPercent = _forwardRecipients[id][recipientIndex].percent;
    if (recipient.percent > existingPercent) {
      _forwardPercent[id] += recipient.percent - existingPercent;
    } else {
      _forwardPercent[id] -= existingPercent - recipient.percent;
    }
    _forwardRecipients[id][recipientIndex] = recipient;
  }

  function toggleForwarding(uint256 id, bool forwardToggle) external {
    require(ownerOf(id) == msg.sender, '!owner');
    _forwardingOn[id] = forwardToggle;
  }

  function getForwardRecipients(uint256 id) external view returns (ForwardRecipient[] memory) {
    return _forwardRecipients[id];
  }
    

    /***************************************************CORE FUNCTIONs *******************************************/

    function createAward(
        Recipient memory recipient,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 rate,
        uint256 period
    ) external nonReentrant returns (uint256 id) {
        uint256 end = DistributorLibrary.validatePlan(
            start,
            cliff,
            amount,
            rate,
            period
        );
        id = incrementAwardId();
        _awards[id] = Award(
            amount,
            start,
            cliff,
            rate,
            period,
            msg.sender
        );
        _safeMint(recipient.beneficiary, id);
        if (recipient.managerRedeem) {
            _managerRedeem[id] = true;
        }
        //emit event
        emit AwardCreated(id, msg.sender, recipient.beneficiary, amount, start, cliff, end, rate, period);
    }

    function createAwardWithClaimRequirements(
        Recipient memory recipient,
        uint256 amount,
        uint256 start,
        uint256 cliff,
        uint256 rate,
        uint256 period,
        ClaimRequirement[] memory claimRequirements
    ) external nonReentrant returns (uint256 id) {
        uint256 end = DistributorLibrary.validatePlan(
            start,
            cliff,
            amount,
            rate,
            period
        );
        id = incrementAwardId();
        _awards[id] = Award(
            amount,
            start,
            cliff,
            rate,
            period,
            msg.sender
        );
        _safeMint(recipient.beneficiary, id);
        if (recipient.managerRedeem) {
            _managerRedeem[id] = true;
        }
        _claimRequirements[id] = claimRequirements;
        //emit event
        emit AwardCreated(id, msg.sender, recipient.beneficiary, amount, start, cliff, end, rate, period);
    }

    function updateRequirementsForAwards(uint256[] memory ids, ClaimRequirement[][] memory requirements) external {
        for (uint256 i; i < ids.length; i++) {
            _updateRequirementForAward(ids[i], requirements[i]);
        }
    }

    function editAward(uint256 id, uint256 amount, uint256 start, uint256 cliff, uint256 rate, uint256 period) external nonReentrant {
        Award memory a = _awards[id];
        require(msg.sender == a.manager, "Only Manager");
        uint256 end = DistributorLibrary.validatePlan(
            start,
            cliff,
            amount,
            rate,
            period
        );
        _awards[id] = Award(
            amount,
            start,
            cliff,
            rate,
            period,
            a.manager
        );
        //emit event
        emit AwardCreated(id, a.manager, ownerOf(id), amount, start, cliff, end, rate, period);
    }

    function cancelAward(uint256 id) external nonReentrant {
        Award memory a = _awards[id];
        require(msg.sender == a.manager, "Only Manager");
        _burn(id);
        delete _awards[id];
        //emit event
        emit AwardCancelled(id, 0);
    }

    function cancelAwardWithPayout(uint256 id) external nonReentrant {
        Award memory a = _awards[id];
        require(msg.sender == a.manager, "Only Manager");
        (uint256 balanceClaimed, , ) = DistributorLibrary.balanceAtTime(
            block.timestamp,
            a.start,
            a.cliff,
            a.amount,
            a.rate,
            a.period
        );
        _distributeTokens(id, ownerOf(id), balanceClaimed, bytes(''));
        _burn(id);
        delete _awards[id];
        //emit event
        emit AwardCancelled(id, balanceClaimed);
    }


    function redeemAwards(
        uint256[] calldata ids
    )
        external
        nonReentrant
        returns (
            uint256[] memory balanceClaimed,
            uint256[] memory remainder,
            uint256[] memory latestUnlock
        )
    {
        balanceClaimed = new uint256[](ids.length);
        remainder = new uint256[](ids.length);
        latestUnlock = new uint256[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            (balanceClaimed[i], remainder[i], latestUnlock[i]) = _redeem(
                ids[i],
                bytes('')
            );
        }
    }

    function redeemAwardsWithData(
        uint256[] calldata ids,
        bytes[] calldata data
    )
        external
        nonReentrant
        returns (
            uint256[] memory balanceClaimed,
            uint256[] memory remainder,
            uint256[] memory latestUnlock
        )
    {
        balanceClaimed = new uint256[](ids.length);
        remainder = new uint256[](ids.length);
        latestUnlock = new uint256[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            (balanceClaimed[i], remainder[i], latestUnlock[i]) = _redeem(
                ids[i],
                data[i]
            );
        }
    }

    /******INTERNAL FUNCTIONS */

    function _redeem(
        uint256 id,
        bytes memory data
    )
        internal
        returns (
            uint256 balanceClaimed,
            uint256 remainder,
            uint256 latestUnlock
        )
    {
        require(isApprovedRedeemer(id, msg.sender), "Not Approved Redeemer");
        address owner = ownerOf(id);
        if (bytes(data).length > 0) {
            require(msg.sender == owner, "Only Owner");
        }
        Award memory a = _awards[id];
        (balanceClaimed, remainder, latestUnlock) = DistributorLibrary.balanceAtTime(
            block.timestamp,
            a.start,
            a.cliff,
            a.amount,
            a.rate,
            a.period
        );
        if (balanceClaimed > 0) {
            if (hasMetRequirements(id)) {
                _distributeTokens(id, owner, balanceClaimed, data);
            } else {
                return (0, a.amount, block.timestamp);
            }
        }
    }

    function _updateRequirementForAward(uint256 id, ClaimRequirement[] memory claimReqs) internal {
        require(msg.sender == _awards[id].manager, "Only Manager");
        _claimRequirements[id] = claimReqs;
    }

    function _distributeTokens(uint256 id, address owner, uint256 totalAward, bytes memory data) internal {
        ForwardRecipient[] memory fr = _forwardRecipients[id];
        address from = _awards[id].manager;
        if (_forwardingOn[id] && fr.length > 0) {
            uint256 amountPaid;
            for (uint256 i; i < fr.length; i++) {
                uint256 award = (totalAward * fr[i].percent) / 10000;
                token.safeTransferFrom(from, fr[i].beneficiary, award);
                amountPaid += award;
            }
            if (amountPaid < totalAward) {
                token.safeTransferFrom(from, owner, totalAward - amountPaid);
                if (bytes(data).length > 0) {
                    IReceiveCallee(owner).onReceived(id, totalAward - amountPaid, data);
                }
            }
        }
        else {
            token.safeTransferFrom(from, owner, totalAward);
            if (bytes(data).length > 0) {
                IReceiveCallee(owner).onReceived(id, totalAward, data);
            }
        }
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address from = _ownerOf(tokenId);
        if (from == address(0x0) || to == address(0x0)) {
            return super._update(to, tokenId, auth);
        } else {
            revert('not transferable');
        }
    }
}
