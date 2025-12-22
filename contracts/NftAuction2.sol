// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./NftAuction.sol";

contract NftAuction2 is NftAuction {
    function hello() public pure returns (string memory) {
        return "hello world";
    }
}
