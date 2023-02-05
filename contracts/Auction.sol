// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/** @title Auction */
contract Auction is Initializable {
    uint256 public endTime; ///auction end time
    address public owner;

    ///Mapping to see what the highest bid for each item is
    mapping(uint256 => uint256) public itemIDTohighestBid;
    ///Mapping to see who the highest bidder for each item is
    mapping(uint256 => address) public itemIDTohighestBidder;

    /// Struct for a listed item allowing for an id, a description and the startingPrice
    struct Item {
        uint256 id;
        string desc;
        uint256 startingPrice;
    }
    /// Struct for winner of each auction item
    struct Winner {
        uint256 id;
        address highestBidder;
        uint256 bidAmt;
    }
    Item[] public items; //Array of items owner wishes to list

    ///Custom Errors
    error Unauthorized();
    error AuctionNotEndedYet();
    error BidTooLow(uint256 currentBid, uint256 yourBid);
    error AuctionAlreadyEnded();

    ///Initializer for upgradeability
    function initialize() public initializer {
        owner = msg.sender;
    }

    /**
    @dev function that allows the owner to initialize the auctions with items
    @param _items - array of Items which are to be put up for auction
    @param _endTime - time auction will end
    */
    function initAuction(Item[] memory _items, uint256 _endTime) public {
        if (_endTime < block.timestamp) {
            ///checks that endTime is in the future
            revert AuctionAlreadyEnded();
        }
        if (msg.sender != owner) {
            revert Unauthorized(); /// allows only the owner to initialize the auction
        }
        endTime = _endTime;
        uint256 len = _items.length;
        ///pushes all the items the owner is listing to the Items array
        for (uint256 i = 0; i < len; ) {
            ///ensures all item ids are distinct
            _items[i].id = i;
            items.push(_items[i]);
            itemIDTohighestBid[_items[i].id] = _items[i].startingPrice;
            unchecked {
                ++i;
            }
        }
    }

    /**
    @dev function that allows anyone but the owner to bid on the items. If successful, the bid 
    updates the mappings. 
    @param _itemID - id of item on which the user wants to bid
    @param _bid - amount user wishes to bid
    */
    function bid(uint256 _itemID, uint256 _bid) public {
        ///checks if auction is still ongoing
        if (block.timestamp > endTime) {
            revert AuctionAlreadyEnded();
        }
        /// Allows anyone but owner to place a bid
        if (msg.sender == owner) {
            revert Unauthorized();
        }
        ///check if the current bid is higher than old highest bid for the item
        ///if it isn't, bid is reverted, otherwise it is accepted and mappings are updated
        uint256 _currentBid = itemIDTohighestBid[_itemID];
        if (_bid <= _currentBid) {
            revert BidTooLow({currentBid: _currentBid, yourBid: _bid});
        }
        itemIDTohighestBid[_itemID] = _bid;
        itemIDTohighestBidder[_itemID] = msg.sender;
    }

    /**
    @dev function that is called when the auction has ended. Rotates through all items
    to declare the winner for each item
    @return Returns an array of Winners
    */
    function determineWinner() public view returns (Winner[] memory) {
        ///ensures auction has ended
        if (block.timestamp < endTime) {
            revert AuctionNotEndedYet();
        }
        uint256 len = items.length;
        Winner[] memory winner = new Winner[](len);
        ///for each item, checks who the highest bidder and highest bid is and puts it into an array of winners
        for (uint256 i = 0; i < len; ) {
            uint256 _id = items[i].id;
            address _highestBidder = itemIDTohighestBidder[_id];
            winner[i] = Winner(_id, _highestBidder, itemIDTohighestBid[_id]);
            unchecked {
                ++i;
            }
        }
        return winner;
    }
}
