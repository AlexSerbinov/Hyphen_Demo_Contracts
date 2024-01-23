const hre = require("hardhat");
const linkTokenAbi = require("../abi/LinkTokenABI.json");
const ethers = hre.ethers;

const LINK_TOKEN_ADDRESS = "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"; // Fuji Avalanche testnet LINK token address
const LINK_AMOUNT = ethers.utils.parseEther("0.001"); // LINK amount to transfer
const linkToken = await ethers.getContractAt(linkTokenAbi, LINK_TOKEN_ADDRESS);

async function main() {
  await printGlinkBalance();
  const blockchainEndpointsDemoV3 = await deployContract();

  await transferLinkToContract(blockchainEndpointsDemoV3.address);
  await verifyContract(blockchainEndpointsDemoV3.address);
}

async function printGlinkBalance() {
  const balance = await ethers.provider.getBalance("0x29B187De608B491310b1ee2743E5cfcF91C50f61");
  console.log(`Glink balance is: ${ethers.utils.formatEther(balance)} AVAX`);
}

async function deployContract() {
  const BlockchainEndpointsDemoV3 = await ethers.getContractFactory("BlockchainEndpointsDemoV3");
  const blockchainEndpointsDemoV3 = await BlockchainEndpointsDemoV3.deploy();
  await blockchainEndpointsDemoV3.deployed();
  console.log("blockchainEndpointsDemoV3 deployed to:", blockchainEndpointsDemoV3.address);
  return blockchainEndpointsDemoV3;
}

async function transferLinkToContract(contractAddress) {
  await linkToken.transfer(contractAddress, LINK_AMOUNT);
  await confirmLinkReceived(contractAddress);
}

async function confirmLinkReceived(contractAddress) {
  let retries = 15;
  while (retries > 0) {
    const balance = await linkToken.balanceOf(blockchainEndpointsDemoV3.address);
    if (balance.gte(linkAmount)) break;
    retries -= 1;
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Delay for 1 second and then recheck
  }
  throw new Error("Failed to confirm LINK transfer to the contract.");
}

async function verifyContract(contractAddress) {
  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [],
    });
  } catch (error) {
    console.error("Error during verification:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
