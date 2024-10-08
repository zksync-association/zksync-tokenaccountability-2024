// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract KYCNFT is ERC721 {

    uint256 public _tokenIds;

    constructor (string memory name, string memory symbol) ERC721(name, symbol) {}


    function incrementTokenId() internal returns (uint256) {
        _tokenIds++;
        return _tokenIds;
    }


    function mint(address to) public returns (uint256 tokenId) {
        tokenId = incrementTokenId();
        _mint(to, tokenId);
    }
}