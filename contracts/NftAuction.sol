// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract NftAuction is Initializable {
    struct Auction {
        // 拍卖是否结束
        bool ended;
        // 是否正在出价
        bool biding;
        // 起始价格
        uint256 startPrice;
        // 最高出价者
        address highestBidder;
        // 最高出价
        uint256 highestBid;
        // 拍卖开始时间
        uint256 startTime;
        // 拍卖结束时间
        uint256 endTime;
        // 拍卖token地址
        address tokenAddress;
        // 拍卖token ID
        uint256 tokenId;
    }

    Auction[] public auctions;
    address public owner;
    uint public autionId;

    function initialize() public initializer {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     *@notice 创建拍卖
     *@param _duration 拍卖时长
     *@param _startPrice 起始价格
     *@param _tokenAddress 拍卖token地址
     *@param _tokenId 拍卖token ID
     */
    function createAution(
        uint _duration,
        uint _startPrice,
        address _tokenAddress,
        uint _tokenId
    ) external onlyOwner {
        Auction memory auction = Auction({
            ended: false,
            biding: false,
            startPrice: _startPrice,
            highestBidder: address(0),
            highestBid: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            tokenAddress: _tokenAddress,
            tokenId: _tokenId
        });
        auctions.push(auction);
        autionId++;
    }

    /**
     *@notice 竞拍
     *@param _autionId 拍卖ID
     */
    function bid(uint _autionId) external payable {
        Auction storage auction = auctions[_autionId];
        require(!auction.ended && auction.endTime > block.timestamp, "Auction already ended");
        require(
            msg.value > auction.highestBid && msg.value > auction.startPrice,
            "There already is a higher bid"
        );

        require(!auction.biding, "Already biding");
        auction.biding = true;
        if (auction.highestBidder != address(0)) {
            (bool success, ) = payable(auction.highestBidder).call{value: auction.highestBid}("");
            require(success, "Transfer failed");
        }
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        auction.biding = false;
    }
}
