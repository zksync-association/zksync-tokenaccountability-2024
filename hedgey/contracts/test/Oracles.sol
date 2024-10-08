// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";



contract Oracles {

    address public nftCheck;
    address public tvlCheck;
    uint256 public tvlMilestone;
    address public auditor;

    mapping(address => mapping(address => uint256)) public protocolTvl;

    mapping(address => bool) public milestones;


    constructor (address _nftCheck, address _auditor) {
        nftCheck = _nftCheck;
        auditor = _auditor;
    }

    function initProtocolTvl(address protocol, address protocolOwner, uint256 tvl) external {
        require(msg.sender == auditor);
        protocolTvl[protocol][protocolOwner] = tvl;
    }
    /// function to determine if an address is the owner of an erc721
    function isOwnerOfERC721(address _owner) external view returns (bool) {
        return (IERC721(nftCheck).balanceOf(_owner) > 0);
    }

    /// function to determine if address has met certain TVL volumes - would assume address has been pre-associated with some like tvl oracle metric

    function hasMetTVL(address _owner, address protocol) external view returns (bool) {
        // needs to pull from owner if some other external check has met the tvl criteria
        uint256 tvl = getTVL(protocol, _owner);
        return tvl >= tvlMilestone;
    }

    function getTVL(address protocol, address protocolOwner) public view returns (uint256 tvl) {
        return protocolTvl[protocol][protocolOwner];
    }

    /// function to determine if address  has completed some arbitrary criteria that is managed by an external evaluator

    function updateProtocolMilestone(address protocol, bool met) external {
        require(msg.sender == auditor);
        milestones[protocol] = met;
    }

    function hasMetMilestone(address _owner) external view returns (bool) {
        return milestones[_owner];
    }

}