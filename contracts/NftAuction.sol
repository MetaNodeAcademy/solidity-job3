// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NftAuction is Initializable, ReentrancyGuardUpgradeable {
    struct Auction {
        // 拍卖是否结束
        bool ended;
        // 起始价格
        uint256 startPrice;
        // 最高出价者
        address highestBidder;
        // 最高出价
        uint256 highestBidUsdt;
        // 最高出价数量
        uint256 highestBidAmount;
        // 拍卖开始时间
        uint256 startTime;
        // 拍卖结束时间
        uint256 endTime;
        // NFT地址
        address nftAddress;
        // NFT ID
        uint256 nftId;
        // token地址
        address tokenAddress;
    }

    Auction[] public auctions;
    address public owner;
    uint public autionId;

    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

    function initialize() public initializer {
        __ReentrancyGuard_init();
        owner = msg.sender;

        // USDC/USD
        tokenPriceFeeds[address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)] = AggregatorV3Interface(
            0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
        );
        // ETH/USD
        tokenPriceFeeds[address(0)] = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     *@notice 设置代币价格预言机
     *@param _token 代币地址
     *@param _priceFeed 价格预言机地址
     */
    function setTokenPriceFeed(address _token, address _priceFeed) external onlyOwner {
        tokenPriceFeeds[_token] = AggregatorV3Interface(_priceFeed);
    }

    /**
     *@notice 创建拍卖
     *@param _duration 拍卖时长
     *@param _startPrice 起始价格
     *@param _nftAddress NFT地址
     *@param _nftId NFT ID
     */
    function createAution(uint _duration, uint _startPrice, address _nftAddress, uint _nftId) external onlyOwner {
        IERC721 erc721 = IERC721(_nftAddress);
        require(erc721.getApproved(_nftId) == address(this), "Not the owner of the NFT");
        Auction memory auction = Auction({
            ended: false,
            startPrice: _startPrice,
            highestBidder: address(0),
            highestBidUsdt: 0,
            highestBidAmount: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            nftAddress: _nftAddress,
            nftId: _nftId,
            tokenAddress: address(0)
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

        if (auction.tokenAddress == address(0)) {
            auction.tokenAddress = _token;
        } else {
            require(_token == auction.tokenAddress, "Token mismatch");
        }

        uint highestBidAmount = 0;
        uint priceUsdt = 0;
        uint ethPrice = getPrice(address(0));
        if (_token != address(0)) {
            priceUsdt = getPrice(_token) * _amount;
            highestBidAmount = _amount;
        } else {
            priceUsdt = ethPrice * msg.value;
            highestBidAmount = msg.value;
        }
        uint startPriceUsdt = auction.startPrice * ethPrice;
        require(priceUsdt > startPriceUsdt, "The starting price is not met");
        require(priceUsdt > auction.highestBidUsdt, "There already is a higher bid");

        if (auction.highestBidder != address(0)) {
            if (_token != address(0)) {
                IERC20 erc20 = IERC20(_token);
                erc20.transfer(auction.highestBidder, auction.highestBidAmount);
            } else {
                (bool success, ) = payable(auction.highestBidder).call{value: auction.highestBidAmount}("");
                require(success, "Transfer failed");
            }
        }

        if (_token != address(0)) {
            IERC20 erc20 = IERC20(_token);
            erc20.transferFrom(msg.sender, address(this), highestBidAmount);
        }
        auction.highestBidder = msg.sender;
        auction.highestBidUsdt = priceUsdt;
        auction.highestBidAmount = highestBidAmount;
    }

    /**
     *@notice 结束拍卖
     *@param _autionId 拍卖ID
     */
    function endAuction(uint _autionId) external onlyOwner {
        Auction storage auction = auctions[_autionId];
        require(!auction.ended && auction.endTime < block.timestamp, "Auction already ended");
        auction.ended = true;
        if (auction.highestBidder != address(0)) {
            IERC721 erc721 = IERC721(auction.nftAddress);
            address seller = erc721.ownerOf(auction.nftId);

            // 转移NFT
            erc721.safeTransferFrom(seller, auction.highestBidder, auction.nftId);

            // 资金转给卖家
            if (auction.tokenAddress != address(0)) {
                IERC20 erc20 = IERC20(auction.tokenAddress);
                erc20.transfer(seller, auction.highestBidAmount);
            } else {
                (bool success, ) = payable(seller).call{value: auction.highestBidAmount}("");
                require(success, "Transfer failed");
            }
        }
    }

    /**
     *@notice 获取价格
     *@param _token ERC20地址
     *@return 价格
     */
    function getPrice(address _token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[_token];
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer);
    }
}
