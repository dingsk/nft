// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const Grnft = await hre.ethers.getContractFactory("GoldRush");
  const grnft = await Grnft.deploy("0xfD85b99A39A9f155B73b35d2b9AB224c3bEd8ee8","GoldRush","GR");

  await grnft.deployed();

  console.log(
    `GoldRush is deployed to ${grnft.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
