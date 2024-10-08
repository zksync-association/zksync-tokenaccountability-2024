// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenDistributor {

    function approveProgram(address programManager, uint256 amount) external;

    function distributeTokens(uint256 amount) external returns (uint256 remainingApproval);

    function getApprovedAmount(address programManager) external view returns (uint256);

    function getAvailableTokenBalance() external view returns (uint256);
}