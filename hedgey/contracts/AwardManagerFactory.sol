// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import './AwardManager.sol';

contract AwardManagerFactory {

    address public tokenAwards;
    address public programAwards;
    address public token;
    mapping(address => address) public awardManagers;

    constructor(address _tokenAwards, address _programAwards, address _token) {
        tokenAwards = _tokenAwards;
        programAwards = _programAwards;
        token = _token;
    }

    function createNewAwardManager(address manager) external returns (address awardManager) {
        awardManager = address(new AwardManager(manager, tokenAwards, token, programAwards));
        awardManagers[manager] = awardManager;
    }
}