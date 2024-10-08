// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IProgramManagerFactory {

    function awardRecipients() external view returns (address);
    function tokenDistributor() external view returns (address);
    function daoController() external view returns (address);
    function token() external view returns (address);
    function fundingTimeAllowance() external view returns (uint256);

    function isManager(address) external view returns (bool);

}