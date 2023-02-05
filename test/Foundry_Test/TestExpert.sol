pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/Expert.sol";
import "./Mocks/MockERC20.sol";

contract TestExpert is Test {
    address public deployer = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);
    Expert public expert;
    MockERC20 t;

    function setUp() public {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);
        t = new MockERC20("DAI", "DAI"); ///deploy ERC20
        expert = new Expert(); ///deploy contract
        vm.deal(user1, 5 ether);
        vm.deal(user2, 5 ether);
    }

    function testAuction() public {
        t.approve(address(expert), 1000e18);
        expert.initAuction(address(t), 1000e18, 6e14, block.timestamp + (60));
        ///check that initAuction initializes variables correctl
        assertEq(1000e18, t.balanceOf(address(expert)));
        assertEq(6e14, expert.minPrice());
        vm.stopPrank();
        ///test bid function and that struct is added to Bids array with correct values
        vm.prank(user1);
        expert.bid{value: 0.0012 ether}(1e18);
        (
            address bidder,
            uint256 tokenAmt,
            uint256 amtPerToken,
            uint256 eth
        ) = expert.bids(0);
        assertEq(bidder, address(user1));
        assertEq(tokenAmt, 1e18);
        assertEq(amtPerToken, 12e14);
        assertEq(eth, 12e14);
    }

    function testAll() public {
        t.approve(address(expert), 1000e18);
        expert.initAuction(address(t), 1000e18, 6e14, block.timestamp + (60));
        vm.stopPrank();
        ///some bids
        vm.prank(user1);
        expert.bid{value: 0.0012 ether}(1e18);
        vm.prank(user2);
        expert.bid{value: 2 ether}(2e18);

        ///test if findMax works correctly
        (uint256 max, uint256 index) = expert.findMax();
        assertEq(max, 2e18);
        assertEq(index, 1);

        ///More bids
        vm.prank(user1);
        expert.bid{value: 0.12 ether}(200e18);
        vm.prank(user2);
        expert.bid{value: 2 ether}(1000e18);
        skip(61);

        ///Once auction has ended, test determineWinner function
        uint256 balance = t.balanceOf(deployer);
        vm.prank(deployer);
        expert.determineWinner();
        assertEq(t.balanceOf(user1), 201e18);
        assertEq(t.balanceOf(user2), 2e18);
        assertEq(t.balanceOf(deployer), balance + 1000e18 - 2e18 - 201e18);
        assertEq(user2.balance, 1 ether);
        vm.prank(user2);
        expert.withdraw();
        assertEq(user2.balance, 3 ether);
        vm.prank(deployer);
        expert.withdraw();
        assertEq(deployer.balance, 2.1212 ether);
    }
}
