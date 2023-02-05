const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { upgrades, ethers } = require("hardhat");

describe("Auction", function () {
  ///deploys contract, defines accounts and endTime(one week)
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, acct1] = await ethers.getSigners();
    const endTime = (await time.latest()) + 7 * 24 * 60 * 60;
    const Auction = await ethers.getContractFactory("Auction");
    const auction = await upgrades.deployProxy(Auction);
    await auction.deployed();

    return { auction, owner, acct1, endTime };
  }

  ///Checks if initializer sets the correct owner
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { auction, owner } = await loadFixture(deploy);

      expect(await auction.owner()).to.equal(owner.address);
    });
  });

  describe("InitAuction", function () {
    describe("Validations", function () {
      it("Should set the right endTime", async function () {
        const { auction, endTime } = await loadFixture(deploy);

        await auction.initAuction(
          [{ id: 0, desc: "ball", startingPrice: 1 }],
          endTime
        );

        expect(await auction.endTime()).to.equal(endTime);
      });
      it("Should fail if the endTime is not in the future", async function () {
        const { auction } = await loadFixture(deploy);
        const currentTime = await time.latest();
        await expect(
          auction.initAuction(
            [{ id: 0, desc: "ball", startingPrice: 1 }],
            currentTime - 1000
          )
        ).to.be.revertedWithCustomError(auction, "AuctionAlreadyEnded");
      });
      it("Should only let the owner call the function", async function () {
        const { auction, acct1, endTime } = await loadFixture(deploy);
        await expect(
          auction
            .connect(acct1)
            .initAuction([{ id: 0, desc: "ball", startingPrice: 1 }], endTime)
        ).to.be.revertedWithCustomError(auction, "Unauthorized");
      });
    });
    it("Should initialize the mapping with the starting price as highest bid and add items to the Items array", async function () {
      const { auction, endTime } = await loadFixture(deploy);
      const items = [
        { id: 1, desc: "ball", startingPrice: 1 },
        { id: 1, desc: "book", startingPrice: 3 },
      ];
      await auction.initAuction(items, endTime);
      const item = await auction.items(0);
      expect(item.id).to.equal(0); ///contract should error check and assign correct id to avoid duplicate ids
      expect(item.desc).to.equal("ball");
      expect(item.startingPrice).to.equal(1);
      const highestBid = await auction.itemIDTohighestBid(0);
      expect(highestBid).to.equal(1);
      const item2 = await auction.items(1);
      expect(item2.id).to.equal(1);
      expect(item2.desc).to.equal("book");
      expect(item2.startingPrice).to.equal(3);
      const highestBid2 = await auction.itemIDTohighestBid(1);
      expect(highestBid2).to.equal(3);
    });
  });

  describe("bid", function () {
    describe("Validations", function () {
      it("Should only let non-owners call the function", async function () {
        const { auction, endTime } = await loadFixture(deploy);
        const items = [
          { id: 0, desc: "ball", startingPrice: 1 },
          { id: 1, desc: "book", startingPrice: 3 },
        ];
        await auction.initAuction(items, endTime);
        await expect(auction.bid(0, 2)).to.be.revertedWithCustomError(
          auction,
          "Unauthorized"
        );
      });

      it("Should only let users bid while auction is ongoing", async function () {
        const { auction, acct1, endTime } = await loadFixture(deploy);
        const items = [
          { id: 0, desc: "ball", startingPrice: 1 },
          { id: 1, desc: "book", startingPrice: 3 },
        ];
        await auction.initAuction(items, endTime);
        await time.increase(7 * 24 * 60 * 60);
        await expect(
          auction.connect(acct1).bid(0, 2)
        ).to.be.revertedWithCustomError(auction, "AuctionAlreadyEnded");
      });

      it("Should ensure user bid is the highest", async function () {
        const { auction, acct1, endTime } = await loadFixture(deploy);
        const items = [
          { id: 0, desc: "ball", startingPrice: 2 },
          { id: 1, desc: "book", startingPrice: 3 },
        ];
        await auction.initAuction(items, endTime);
        await expect(
          auction.connect(acct1).bid(0, 1)
        ).to.be.revertedWithCustomError(auction, "BidTooLow");
      });
    });
    it("Should update both mappings if bid is successful", async function () {
      const { auction, acct1, endTime } = await loadFixture(deploy);
      const items = [
        { id: 0, desc: "ball", startingPrice: 1 },
        { id: 1, desc: "book", startingPrice: 3 },
      ];
      await auction.initAuction(items, endTime);
      await auction.connect(acct1).bid(0, 2);
      const bid = await auction.itemIDTohighestBid(0);
      const bidder = await auction.itemIDTohighestBidder(0);
      expect(bid).to.equal(2);
      expect(bidder).to.equal(acct1.address);
    });
  });
  describe("determineWinner", function () {
    it("Should revert if auction is not over yet", async function () {
      const { auction, endTime } = await loadFixture(deploy);
      const items = [
        { id: 0, desc: "ball", startingPrice: 1 },
        { id: 1, desc: "book", startingPrice: 3 },
      ];
      await auction.initAuction(items, endTime);
      await expect(auction.determineWinner()).to.be.revertedWithCustomError(
        auction,
        "AuctionNotEndedYet"
      );
    });
    it("Should return an array of auction winners", async function () {
      const { auction, acct1, endTime } = await loadFixture(deploy);

      const items = [
        { id: 0, desc: "ball", startingPrice: 1 },
        { id: 1, desc: "book", startingPrice: 3 },
      ];
      await auction.initAuction(items, endTime);
      await auction.connect(acct1).bid(0, 2);
      await time.increase(7 * 24 * 60 * 60);
      const winner = await auction.determineWinner();
      expect(winner[0].highestBidder).to.equal(acct1.address);
      expect(winner[0].id).to.equal(0);
      expect(winner[0].bidAmt).to.equal(2);
      expect(winner[1].highestBidder).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });
});
