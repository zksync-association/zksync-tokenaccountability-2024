// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import './libraries/DistributorLibrary.sol';
import "./interfaces/ITokenAwards.sol";
import "./interfaces/IProgramManagerFactory.sol";
import './interfaces/IReceiveCallee.sol';

contract AwardManager is ReentrancyGuard, ERC721Holder {
    address public manager;
    ITokenAwards public tokenAwards;
    IERC20 public token;
    ITokenAwards public programAwards;

    uint256[] internal _awardIds;
    mapping(uint256 => uint256) internal _awardIndex;

    mapping(address => bool) internal _tokenOperators;

    uint256[] internal _programAward;

    constructor(address _manager, address _ta, address _token, address _programAwards) {
        manager = _manager;
        tokenAwards = ITokenAwards(_ta);
        token = IERC20(_token);
        programAwards = ITokenAwards(_programAwards);
    }

    modifier onlyManager() {
        require(msg.sender == manager, "!manager");
        _;
    }

    /***************************** INTERNAL FUNCTIONS***********************************************************/

    function addNewAwardId(uint256 id) internal {
        _awardIds.push(id);
        _awardIndex[id] = _awardIds.length - 1;
    }

    function removeAwardId(uint256 id) internal {
        uint256 index = _awardIndex[id];
        _awardIds[index] = _awardIds[_awardIds.length - 1];
        _awardIds.pop();
        delete _awardIndex[id];
    }

    function getAwardIds() public view returns (uint256[] memory) {
        return _awardIds;
    }

    /*******PUBLIC GETTER FUNCTINS****************************************************************************** */
    function getAwardsFunding(
        uint256 fundingTime
    ) public view returns (uint256 amountOwed, uint256 fundingRequired) {
        for (uint256 i; i < _awardIds.length; i++) {
            (, uint256 balance, , , ) = tokenAwards.getAwardFunding(
                _awardIds[i],
                fundingTime
            );
            amountOwed += balance;
        }
        uint256 currentBalance = token.balanceOf(address(this));
        fundingRequired = (amountOwed > currentBalance) ? amountOwed - currentBalance: 0;
    }

    function getFunding(
        uint256[] memory grantIds,
        uint256 fundingTime
    ) public view returns (uint256 amountOwed, uint256 fundingRequired) {
        for (uint256 i; i < grantIds.length; ++i) {
            (, uint256 balance, , , ) = tokenAwards.getAwardFunding(
                grantIds[i],
                fundingTime
            );
            amountOwed += balance;
        }
        uint256 currentBalance = token.balanceOf(address(this));
        fundingRequired = (amountOwed > currentBalance) ? amountOwed - currentBalance: 0;
    }

    /**********************CORE FUNCTIONS **************************************************************************** */

    function onERC721Received(address operator, address from, uint256 id, bytes memory data) public override returns (bytes4) {
        if (msg.sender == address(programAwards)) {
            require(_programAward.length == 0, 'already received award');
            _programAward.push(id);
        }
        return this.onERC721Received.selector;
    }


    function createAwards(
        ITokenAwards.Recipient[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory starts,
        uint256[] memory cliffs,
        uint256[] memory rates,
        uint256[] memory periods
    ) external onlyManager {
        for (uint256 i; i < amounts.length; i++) {
            uint256 id = tokenAwards.createAward(
                recipients[i],
                amounts[i],
                starts[i],
                cliffs[i],
                rates[i],
                periods[i]
            );
            addNewAwardId(id);
        }
    }

    function creatAwardsWithRequirements(
        ITokenAwards.Recipient[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory starts,
        uint256[] memory cliffs,
        uint256[] memory rates,
        uint256[] memory periods,
        ITokenAwards.ClaimRequirement[][] memory claimRequirements
    ) external onlyManager  {
        for (uint16 i; i < recipients.length; i++) {
            uint256 id = tokenAwards.createAwardWithClaimRequirements(
                recipients[i],
                amounts[i],
                starts[i],
                cliffs[i],
                rates[i],
                periods[i],
                claimRequirements[i]
            );
            addNewAwardId(id);
        }
    }

    function editAwards(
        uint256[] memory ids,
        uint256[] memory amounts,
        uint256[] memory starts,
        uint256[] memory cliffs,
        uint256[] memory rates,
        uint256[] memory periods
    ) external onlyManager {
        for (uint256 i; i < ids.length; i++) {
            tokenAwards.editAward(
                ids[i],
                amounts[i],
                starts[i],
                cliffs[i],
                rates[i],
                periods[i]
            );
        }
    }

    function updateRequirementsToGrant(uint256[] memory ids, ITokenAwards.ClaimRequirement[][] memory requirements) external {
        tokenAwards.updateRequirementsForAwards(ids, requirements);
    }


    function cancelAwards(uint256[] memory ids) external onlyManager {
        for (uint16 i; i < ids.length; i++) {
            tokenAwards.cancelAward(ids[i]);
            removeAwardId(ids[i]);
        }
    }

    /***************OPERATOR METHODS************************************************************************* */

    function updateOperator(address minter, bool canOperate) external onlyManager {
        _tokenOperators[minter] = canOperate;
    }


    function distributeAwards(uint256[] memory ids) external {
        require(
            _tokenOperators[msg.sender] ||
                msg.sender == manager ||
                _tokenOperators[address(0x0)],
            "!approved"
        );
        (uint256 amountOwed, uint256 fundingRequired) = getFunding(ids, block.timestamp);
        require(fundingRequired == 0, "insufficient funds");
        token.approve(address(tokenAwards), amountOwed);
        tokenAwards.redeemAwards(ids);
    }

    function distributeAllAwards() external {
        require(
            _tokenOperators[msg.sender] ||
                msg.sender == manager ||
                _tokenOperators[address(0x0)],
            "!approved"
        );
        (uint256 amountOwed, uint256 fundingRequired) = getAwardsFunding(block.timestamp);
        require(fundingRequired == 0, "insufficient funds");
        token.approve(address(tokenAwards), amountOwed);
        tokenAwards.redeemAwards(_awardIds);
    }

    function approveTokenSpend(uint256 amount) external {
        require(
            _tokenOperators[msg.sender] ||
                msg.sender == manager ||
                _tokenOperators[address(0x0)],
            "!approved"
        );
        token.approve(address(tokenAwards), amount);
    }

    function approveTokenSpendForCurrentOwed() external {
        require(
            _tokenOperators[msg.sender] ||
                msg.sender == manager ||
                _tokenOperators[address(0x0)],
            "!approved"
        );
        (uint256 amountOwed,) = getAwardsFunding(block.timestamp);
        token.approve(address(tokenAwards), amountOwed);
    }

    function claimAvailableAwards() external {
        require(
            _tokenOperators[msg.sender] ||
                msg.sender == manager ||
                _tokenOperators[address(0x0)],
            "!approved"
        );
        // claims tokens from the program manager distributor

        programAwards.redeemAwards(_programAward);
        token.approve(address(tokenAwards), token.balanceOf(address(this)));
    }

    function withdrawTokens(uint256 amount) external onlyManager {
        token.transfer(manager, amount);
    }

    /**************SPECIAL FUNCTIONs***************************************** */

    function setupForwardingAddresses(ITokenAwards.ForwardRecipient[] memory recipients) external onlyManager {
        programAwards.createForwardingRecipients(_programAward[0], recipients);
    }

    function removeForwardingAddresses(address[] memory recipients) external onlyManager {
        programAwards.removeForwardRecipients(_programAward[0], recipients);
    }

    function editForwardingAddresses(ITokenAwards.ForwardRecipient memory recipient, uint256 recipientIndex) external onlyManager {
        programAwards.editForwardRecipient(_programAward[0], recipient, recipientIndex);
    }
     

    function claimAwardsWithData(bytes memory data) external onlyManager {
        bytes[] memory _data = new bytes[](1);
        _data[0] = data;
        programAwards.redeemAwardsWithData(_programAward, _data);
    }


    function onReceived(uint256 id, uint256 amount, bytes calldata data) external returns (bytes memory) {
        (address externalContract, string memory externalContractMethod, bool approveAllowance, bytes memory sendData) = abi.decode(data, (address, string, bool, bytes)); 
        if (approveAllowance) token.approve(externalContract, amount);
        bytes memory _data = abi.encodeWithSignature(externalContractMethod, sendData);
        (bool success, bytes memory returnData) = externalContract.call(_data);
        // require(success);
        return returnData;
    }
}
