// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import '../interfaces/ITokenAwards.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "hardhat/console.sol";

interface IClaims {
    struct Campaign {
    address manager;
    address token;
    uint256 amount;
    uint256 start;
    uint256 end;
    TokenLockup tokenLockup;
    bytes32 root;
    bool delegating;
  }

  enum TokenLockup {
    Unlocked,
    Locked,
    Vesting
  }

    function createUnlockedCampaign(bytes16 id, Campaign memory campaign, uint256 totalClaimers) external;
}

contract ClaimIntermediary is ERC721Holder {

    IClaims public claims;
    address public manager;
    address public token;
    address public distributor;
    uint256[] public awardId;

    constructor(address _claims, address _token, address _distributor) {
        claims = IClaims(_claims);
        token = _token;
        distributor = _distributor;
        manager = msg.sender;
    }

    function onReceived(uint256 tokenId, uint256 amount, bytes memory data) external {
        require(tokenId == awardId[0], "ClaimIntermediary: Invalid Award Id");
        (bytes16 id, bytes32 root, uint256 totalClaimers) = abi.decode(data, (bytes16, bytes32, uint256));
        console.log('just received callback with amount of ', amount);
        IClaims.Campaign memory campaign = IClaims.Campaign({
            manager: manager,
            token: token,
            amount: amount,
            start: block.timestamp,
            end: block.timestamp + 30 days,
            tokenLockup: IClaims.TokenLockup.Unlocked,
            root: root,
            delegating: false
        });
        IERC20(token).approve(address(claims), amount);
        claims.createUnlockedCampaign(id, campaign, totalClaimers);
    }

    function onERC721Received(address, address, uint256 tokenId, bytes memory data) public override returns (bytes4) {
        require(msg.sender == distributor, "ClaimIntermediary: Invalid token");
        require(awardId.length == 0, 'ClaimIntermediary: Award Id already set');
        awardId.push(tokenId);
        return this.onERC721Received.selector;
    }

    function redeemAwardsWithData(bytes16 id, bytes32 root, uint256 totalClaimers) external {
        require(msg.sender == manager, '!manager');
        console.log('redeeming with data');
        bytes memory _data = abi.encode(id, root, totalClaimers);
        bytes[] memory data = new bytes[](1);
        data[0] = _data;
        ITokenAwards(distributor).redeemAwardsWithData(awardId, data);
    }
}