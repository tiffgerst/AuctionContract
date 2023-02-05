// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** @title Expert */
contract Expert {
    uint256 constant PRECISION = 1e18;
    uint256 public endTime; ///auction end time
    address public owner;
    IERC20 public token;
    Bid[] public bids; ///array of all bidders
    mapping(address => uint256) ethToUser;

    ///min amt of eth needed to be bid per token
    uint256 public minPrice;

    ///Custom Errors
    error Unauthorized();
    error AuctionNotEndedYet();
    error BidTooLow(uint256 minimumPrice, uint256 yourBid);
    error AuctionAlreadyEnded();
    error ItemDoesNotExist();

    /**Bid struct to represent each bid -
     * contains the bidder address
     * how many ERC20 tokens they are bidding for
     * the amount of eth/ERC20 they are bidding
     * the total amount of eth sent
     **/
    struct Bid {
        address bidder;
        uint256 tokenAmt;
        uint256 amtPerToken;
        uint256 ethSent;
    }
    ///Auction enum to ensure declare winner function is only called once when auction is active
    enum Auction {
        ACTIVE,
        INACTIVE
    }

    ///initialize status to inactive
    Auction status = Auction.INACTIVE;

    ///constructor
    constructor() {
        owner = msg.sender;
    }

    /**
    @dev function that allows the owner to initialize the auctions with items
    @param _token - address of token
    @param _amount - amount of token they want to put up for auction
    @param _minPrice - min amount of eth per token seller is willing to accept
    @param _endTime - end time of auction
    */
    function initAuction(
        address _token,
        uint256 _amount,
        uint256 _minPrice,
        uint256 _endTime
    ) public {
        if (_endTime < block.timestamp) {
            revert AuctionAlreadyEnded();
        }
        if (msg.sender != owner) {
            revert Unauthorized(); /// allows only the owner to initialize the auction
        }
        endTime = _endTime;
        minPrice = _minPrice;
        token = IERC20(_token);
        token.transferFrom(msg.sender, address(this), _amount);
        status = Auction.ACTIVE; ///activate auction
        ethToUser[owner] = 0;
    }

    /**
    @dev function that allows anyone but the owner to bid on the tokens . If successful, the bid 
    updates the mappings and array. 
    @param _amount - amount of ERC20 tokens user wishes to acquire
    */
    function bid(uint256 _amount) public payable {
        require(status == Auction.ACTIVE, "Auction is not yet active");

        if (endTime < block.timestamp) {
            revert AuctionAlreadyEnded();
        }
        if (msg.sender == owner) {
            revert Unauthorized(); /// Allows anyone but owner to place a bid
        }
        ///ensures the total amount bid for is less than or equal to the total amount available
        require(
            _amount <= (token.balanceOf(address(this))),
            "Amount must be less than total tokens available"
        );
        ///checks that bidder bid at least the minimum amount
        if (((minPrice * _amount) / PRECISION) > msg.value) {
            revert BidTooLow({
                minimumPrice: (minPrice * _amount) / PRECISION,
                yourBid: msg.value
            });
        }
        /// add the bid to the bids array
        bids.push(
            Bid(
                msg.sender,
                _amount,
                ((msg.value * PRECISION) / _amount),
                msg.value
            )
        );
        ///add the amount sent to mapping
        ethToUser[msg.sender] += msg.value;
    }

    /**
    @dev function that is called when the auction has ended. 
    Checks max bid each round to see who next highest bidder is. Immediately transfers
    them the funds. 
    Next highest bidder is determined by who is paying the most eth per ERC20, not by 
    who is bidding on the most ERC20 or who is bidding the most overall. 
    */
    function determineWinner() public {
        if (endTime > block.timestamp) {
            revert AuctionNotEndedYet();
        }
        ///this function should only be called once. At the end of the function status is set to Inactive
        require(status == Auction.ACTIVE, "winner already declared");
        uint256 len = bids.length;
        uint256 j = 0;
        (uint256 next, uint256 index) = findMax();
        while (j < len && token.balanceOf(address(this)) > 0) {
            ///If next bidder has bid on more tokens than are left in the pool, their bid is skipped
            ///either way, the amtPerToken and tokenAmt are set to 0 to ensure bid cannot be realized/cannot be fulfilled twice
            if (next > token.balanceOf(address(this))) {
                unchecked {
                    ++j;
                }
                bids[index].amtPerToken = 0;
                bids[index].tokenAmt = 0;
                (next, index) = findMax();
                continue;
            }
            address _bidder = bids[index].bidder;
            bids[index].amtPerToken = 0;
            bids[index].tokenAmt = 0;
            ethToUser[_bidder] -= bids[index].ethSent;
            ethToUser[owner] += bids[index].ethSent;
            token.transfer(_bidder, next);
            unchecked {
                ++j;
            }
            (next, index) = findMax();
        }
        status = Auction.INACTIVE;
        ///gives owner back his unbid tokens
        token.transfer(owner, token.balanceOf(address(this)));
    }

    /**
    @dev function that finds the largest amtPerToken bid i.e. where the seller will maximize profits.
    @return max - Returns the amount of tokens that the max bidder bid for 
    @return index - the index of the array with the highest bid
    */
    function findMax() public view returns (uint256, uint256) {
        uint256 len = bids.length;
        uint256 max = 0;
        uint256 index = 0;
        for (uint256 i = 0; i < len; ) {
            if (max < bids[i].amtPerToken) {
                max = bids[i].amtPerToken;
                index = i;
            }
            unchecked {
                ++i;
            }
        }
        return (bids[index].tokenAmt, index);
    }

    /**
    @dev function that bidders can call when auction has ended. 
    Returns amount from unsuccessful bids to them. Owner can use the function to withdraw
    his eth. 
    */
    function withdraw() public {
        require(status == Auction.INACTIVE, "Auction has not ended yet");
        uint256 amount = ethToUser[msg.sender];
        address payable receiver = payable(msg.sender);
        ethToUser[msg.sender] = 0;
        receiver.transfer(amount);
    }
}
