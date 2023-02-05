# TruFin Project

The item auction is given by Auction.sol, and was tested in hardhat (Auction.js)
The ERC20 auction is in Expert.sol and as I was running close to the time limit, it was only tested in Foundry and not hardhat. It also only contains functionality testing and not as in-depth testing as testing for the simple auction contract. For example, revert statements were not tested as most were tested in Auction.js. The file can be found in the Foundry_Test folder.
The findMax function runs in O(n) time but will take O(n^2) time to run through all the bids. Instead, one could implement a more efficient algorithm like merge sort (O(nlogn)) which would sort the array once so that one can then iterate through it in order. One could also do the sorting and comparing off-chain. However, this would have taken me over the alotted time.
As for upgradeability, the basic auction uses Openzeppelin Upgrades.
For testing the basic auction - all functionalities have been tested i.e. validations, updating data values, etc. This includes unit tests as well as integration tests as testing some functionality requires that other functions are working properly. For example, testing the bid function requires that the initAuction function works.

One idea could be to use GRDs as shown in this repo: https://github.com/FrankieIsLost/gradual-dutch-auction
Alternatively, one could change the expert auction contract to allow users to both buy and sell assets. The contract could calculate the bid-ask spread by keeping track of the lowest sell price and highest bid price and execute trades that fall above a minimum spread. In this case, the contract would function as a liquidity pool and the auction would need to be initialized with both eth and ERC20 token supply.
