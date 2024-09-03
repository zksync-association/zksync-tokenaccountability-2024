// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './ProgramManager.sol';

contract ProgramManagerFactory {
  address public awardDistributor;
  address public tokenDistributor;
  address public daoController;
  address public token;
  uint256 public fundingTimeAllowance;
  address internal deployer;

  bool public initialized;

  /// mapping of grant manager address to true => used by GrantRecipients to check to only allow grants manager contracts to interact with it
  mapping(address => bool) public isManager;

  // maps the owner of a grant manager to a list of addresses that the manager is onwer of
  mapping(address => address[]) public programManagers;

  event ProgramManagerCreated(address indexed manager, address indexed owner);
  event FundingTimeSet(uint256 fundingTimeAllowance);

  constructor(address _deployer) {
    deployer = _deployer;
  }

  function init(
    address _awardDistributor,
    address _tokenDistributor,
    address _daoController,
    address _token,
    uint256 _fundingTimeAllowance
  ) external {
    require(msg.sender == deployer, 'Only Deployer');
    require(!initialized, 'Already initalized');
    initialized = true;
    awardDistributor = _awardDistributor;
    tokenDistributor = _tokenDistributor;
    daoController = _daoController;
    token = _token;
    fundingTimeAllowance = _fundingTimeAllowance;
  }

  modifier onlyController() {
    require(msg.sender == daoController, 'Only Controller');
    _;
  }

  function updateFundingTimeAllowance(uint256 _fundingTimeAllowance) external onlyController {
    fundingTimeAllowance = _fundingTimeAllowance;
    emit FundingTimeSet(_fundingTimeAllowance);
  }

  function createProgramManager(address _manager) external returns (address programManager) {
    require(initialized, 'Not initalized');
    programManager = address(new ProgramManager(_manager, awardDistributor, token));
    isManager[programManager] = true;
    programManagers[_manager].push(programManager);
    emit ProgramManagerCreated(programManager, _manager);
  }

  function getProgramManagers(address owner) public view returns (address[] memory) {
    return programManagers[owner];
  }
}
