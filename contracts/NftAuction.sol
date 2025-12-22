// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NftAuction is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    struct Auction {
        // 拍卖是否结束
        bool ended;
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
        // NFT地址
        address tokenAddress;
        // NFT ID
        uint256 tokenId;
    }

    Auction[] public auctions;
    address public owner;
    uint public autionId;

    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

    function initialize() public initializer {
        __ReentrancyGuard_init();
        owner = msg.sender;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // 什么也不做
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     *@notice 创建拍卖
     *@param _duration 拍卖时长
     *@param _startPrice 起始价格
     *@param _tokenAddress NFT地址
     *@param _tokenId NFT ID
     */
    function createAution(uint _duration, uint _startPrice, address _tokenAddress, uint _tokenId) external onlyOwner {
        Auction memory auction = Auction({
            ended: false,
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
     *@param _token ERC20地址
     *@param _amount 出价数量
     */
    function bid(uint _autionId, address _token, uint _amount) external payable nonReentrant {
        Auction storage auction = auctions[_autionId];
        require(!auction.ended && auction.endTime > block.timestamp, "Auction already ended");
        require(msg.value > auction.highestBid && msg.value > auction.startPrice, "There already is a higher bid");

        if (auction.highestBidder != address(0)) {
            (bool success, ) = payable(auction.highestBidder).call{value: auction.highestBid}("");
            require(success, "Transfer failed");
        }
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    function _getPrice(address _token) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[_token];
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }
}
