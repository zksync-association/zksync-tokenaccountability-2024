// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import './libraries/DistributorLibrary.sol';
import "./interfaces/ITokenAwards.sol";
import "./interfaces/IProgramManagerFactory.sol";
import "./interfaces/ITokenDistributor.sol";

contract ProgramManager is ReentrancyGuard {
    address public manager;
    ITokenAwards public tokenAwards;
    IERC20 public token;
    IProgramManagerFactory public factory;
    ITokenDistributor public tokenDistributor;

    uint256 public lastFundingTime;

    uint256[] internal _awardIds;
    mapping(uint256 => uint256) internal _awardIndex;

    bool public isInitialized;

    event AwardCreated(uint256 indexed id);
    event RequirementsAdded(uint256 indexed id);
    event AwardCancelled(uint256 indexed id);
    event AwardEdited(uint256 indexed id);
    event AwardDistributed(uint256 id);
    event OperatorUpdated(address operator, bool canOperate);
    event ProgramCancelled();

    constructor(address _manager, address _ta, address _token) {
        manager = _manager;
        tokenAwards = ITokenAwards(_ta);
        token = IERC20(_token);
        factory = IProgramManagerFactory(msg.sender);
        tokenDistributor = ITokenDistributor(factory.tokenDistributor());
    }

    modifier onlyManager() {
        require(msg.sender == manager, "!manager");
        _;
    }

    modifier managerOrDAO() {
        require(msg.sender == manager || msg.sender == factory.daoController(), "!auth");
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
    function getAwardsFundingAtTime(
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

    function getAllowableMint() public view returns (uint256) {
         uint256 fundingApproved = tokenDistributor.getApprovedAmount(address(this));
         uint256 amountOwed;
        for (uint256 i; i < _awardIds.length; i++) {
            (, uint256 balance, , , ) = tokenAwards.getAwardFunding(
                _awardIds[i],
                block.timestamp + factory.fundingTimeAllowance()
            );
            amountOwed += balance;
        }
        uint256 currentBalance = token.balanceOf(address(this));
        return DistributorLibrary.min(fundingApproved, amountOwed - currentBalance);
    }

    /**********************CORE FUNCTIONS **************************************************************************** */
    function createAwards(
        ITokenAwards.Recipient[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory starts,
        uint256[] memory cliffs,
        uint256[] memory rates,
        uint256[] memory periods
    ) external onlyManager {
        require(!isInitialized, "Already Initialized");
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
            emit AwardCreated(id);
        }
    }

    function createAwardsWithRequirements(
        ITokenAwards.Recipient[] memory recipients,
        uint256[] memory amounts,
        uint256[] memory starts,
        uint256[] memory cliffs,
        uint256[] memory rates,
        uint256[] memory periods,
        ITokenAwards.ClaimRequirement[][] memory claimRequirements
    ) external onlyManager  {
        require(!isInitialized, "Already Initialized");
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
            emit AwardCreated(id);
            emit RequirementsAdded(id);
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
        require(!isInitialized, "Already Initialized");
        for (uint256 i; i < ids.length; i++) {
            tokenAwards.editAward(
                ids[i],
                amounts[i],
                starts[i],
                cliffs[i],
                rates[i],
                periods[i]
            );
            emit AwardEdited(ids[i]);
        }
    }

    function updateRequirementsToGrant(uint256[] memory ids, ITokenAwards.ClaimRequirement[][] memory requirements) external onlyManager {
        tokenAwards.updateRequirementsForAwards(ids, requirements);
    }


    function cancelAwards(uint256[] memory ids) external managerOrDAO {
        for (uint16 i; i < ids.length; i++) {
            tokenAwards.cancelAward(ids[i]);
            removeAwardId(ids[i]);
            emit AwardCancelled(ids[i]);
        }
    }


    function distributeAwards(uint256[] memory ids) external onlyManager {
        tokenAwards.redeemAwards(ids);
    }

    function distributeAllAwards() external onlyManager {
        tokenAwards.redeemAwards(_awardIds);
    }

    /**************SPECIAL ADMIN FUNCTIONs***************************************** */

    function initialize() external onlyManager {
        require(!isInitialized, "Already Initialized");
        isInitialized = true;
    }

    function mintFromTokenMinter() external onlyManager {
        require(isInitialized, 'not initialized');
        uint256 mintAmount = getAllowableMint();
        tokenDistributor.distributeTokens(mintAmount);
        token.approve(address(tokenAwards), mintAmount);
    }
    

    function approveTokenSpend(uint256 amount) external onlyManager {
        token.approve(address(tokenAwards), amount);
    }

    /***** ADMIN OR DAO FUNCTIONS */

    function cancelProgam() external managerOrDAO {
        for (uint16 i; i < _awardIds.length; i++) {
            tokenAwards.cancelAward(_awardIds[i]);
        }
        sendTokensToDAO();
        delete manager;
    }

    function sendTokensToDAO() public managerOrDAO {
        token.transfer(factory.daoController(), token.balanceOf(address(this)));
    }
}
