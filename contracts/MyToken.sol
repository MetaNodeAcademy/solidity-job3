// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyToken is ERC721 {
    uint private count = 0;

    constructor() ERC721("MyToken", "MTK") {
        mint_token();
    }

    function mint_token() public {
        _mint(msg.sender, count);
        count++;
    }
}
