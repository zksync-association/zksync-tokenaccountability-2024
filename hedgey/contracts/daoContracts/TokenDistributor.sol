// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '../interfaces/ITokenDistributor.sol';

interface IERC20 {
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract TokenDistributor is ITokenDistributor {
    IERC20 public token;
    address public governor;
    uint256 public mintCap;

    mapping(address => uint256) public approvedAmounts;

    event ProgramApproved(address indexed programManager, uint256 amount);
    event CapSet(uint256 mintCap);
    event TokensDistributed(address indexed programManager, uint256 amount, uint256 remainingApproval, uint256 mintCap);

    constructor(address _governor, address _token, uint256 _mintCap) {
        governor = _governor;
        token = IERC20(_token);
        mintCap = _mintCap;
    }

    function setCap(uint256 _mintCap) external {
        require(msg.sender == governor, 'Only governor can set cap');
        mintCap = _mintCap;
        emit CapSet(mintCap);
    }

    function approveProgram(address programManager, uint256 amount) external {
        require(msg.sender == governor, 'Only governor can approve');
        approvedAmounts[programManager] += amount;
        emit ProgramApproved(programManager, amount);
    }

    function distributeTokens(uint256 amount) external returns (uint256 remainingApproval) {
        require(approvedAmounts[msg.sender] >= amount, 'Not approved');
        require(mintCap >= amount, 'Exceeds mint cap');
        approvedAmounts[msg.sender] -= amount;
        token.mint(msg.sender, amount);
        mintCap -= amount;
        remainingApproval = approvedAmounts[msg.sender];
        emit TokensDistributed(msg.sender, amount, remainingApproval, mintCap);
    }

    function getApprovedAmount(address programManager) public view returns (uint256) {
        return approvedAmounts[programManager];
    }

    function getAvailableTokenBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }
}