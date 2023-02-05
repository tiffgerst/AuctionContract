const { ethers, upgrades } = require("hardhat");

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const ONE_WEEK_IN_SECS = 7 * 24 * 60 * 60;
  const endTime = currentTimestampInSeconds + ONE_WEEK_IN_SECS;
  const Auction = await ethers.getContractFactory("Auction");
  console.log("Deploying contract...");
  const auction = await upgrades.deployProxy(Auction);
  // const auction = await AuctionFactory.deploy(endTime);
  await auction.deployed();
  console.log(`Deployed contract to: ${auction.address}`);
  const ExpertFactory = await ethers.getContractFactory("Expert");
  console.log("Deploying contract...");
  const expert = await ExpertFactory.deploy();
  await expert.deployed();
  console.log(`Deployed contract to: ${expert.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
