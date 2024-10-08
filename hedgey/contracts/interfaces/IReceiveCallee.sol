// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReceiveCallee {
  function onReceived(uint256 id, uint256 amount, bytes calldata data) external;
}
