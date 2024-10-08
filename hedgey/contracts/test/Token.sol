// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import '@openzeppelin/contracts/utils/cryptography/EIP712.sol';

contract Token is ERC20Votes {

  uint8 internal _decimals = 18;
  address public minter;

  constructor(string memory name, string memory symbol) ERC20(name, symbol) EIP712(name, '1') {
    minter = msg.sender;
  }

  function mint(address to, uint256 amount) public {
    require(msg.sender == minter,'not minter');
    _mint(to, amount);
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

}