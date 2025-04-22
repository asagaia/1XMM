const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers } = require('hardhat');
const { expect } = require('chai');

const decimalAdjustment = BigInt(10 ** 18);
const ratePrecision = 10_000n;

async function _deploy() {
  const [owner, spender] = await ethers.getSigners();
  const contractFactory = await ethers.getContractFactory("OneXMM");

  const token = await contractFactory.deploy("TEST", "Test token");

  // Initial supply is 5 mios
  await token.allocate(token, 5_000_000n * BigInt(10 ** 18));
  // Allocation to owner is 250k
  await token.allocate(owner, 250_000n * BigInt(10 ** 18));

  return [owner, token, spender];
}

async function _deployERC20() {
  const [owner] = await ethers.getSigners();
  const contractFactory = await ethers.getContractFactory("ERC677Allocatable");
  return await contractFactory.deploy(owner[0].address, 100_000, "COIN1", "COIN1", 18);
}

async function _deployERC20_6() {
  const [owner] = await ethers.getSigners();
  const contractFactory = await ethers.getContractFactory("ERC677Allocatable");
  return await contractFactory.deploy(owner[0].address, 50_000, "COIN2", "COIN2", 6);
}

describe('Test 1XMM specific token functions', function () {
    it ('Only owner can unlock token', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      await expect(token.connect(spender).unlockTransfers()).to.be.rejectedWith("E0");
    });

    it('Owner can transfer back', async function() {
      const [owner, token, spender] = await loadFixture(_deploy);
      
      await expect(token.connect(spender).ownerTransfersBack(250_001n * BigInt(10 ** 18))).to.be.rejectedWith("E0");
      await expect(token.ownerTransfersBack(250_001n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
      expect(await token.ownerTransfersBack(150_000n * BigInt(10 ** 18))).to.emit("Transfer");

      expect(await token.balanceOf(owner)).to.equal(100_000n * BigInt(10 ** 18));
      expect(await token.circulatingSupply()).to.equal(100_000n * BigInt(10 ** 18));
      expect(await token.totalSupply()).to.equal(5_000_000n * BigInt(10 ** 18));
      expect(await token.cap()).to.equal(5_000_000n * BigInt(10 ** 18));
    });

    it('Can mass allocate', async function() {
      const [owner, token, spender] = await loadFixture(_deploy);
      const addresses = ["0x1234567890123456789012345678901234500002", "0x1234567890123456789012345678901234500003", "0x1234567890123456789012345678901234500004"];
      const amt = 100_000n * BigInt(10 ** 18);
      const amts = [amt, 2n * amt, amt];

      await expect(token.connect(spender).massAllocation(addresses, amts)).to.be.rejectedWith("E0");
      await expect(token.massAllocation(addresses, amts)).to.emit(token, "Allocated");

      expect(await token.balanceOf("0x1234567890123456789012345678901234500002")).to.equal(amt);
      expect(await token.balanceOf("0x1234567890123456789012345678901234500003")).to.equal(2n * amt);
      expect(await token.balanceOf("0x1234567890123456789012345678901234500004")).to.equal(amt);

      expect(await token.circulatingSupply()).to.equal(250_000n * BigInt(10 ** 18) + 4n * amt);
    });

    it('Can grant authorization for transfer', async function() {
      const [owner, token, spender] = await loadFixture(_deploy);

      await token.allocate(spender, 250_000n * BigInt(10 ** 18));
      await expect(token.connect(spender).transfer("0x1234567890123456789012345678901234500002", 150_000n * BigInt(10 ** 18))).to.be.revertedWith("Locked");
      
      await expect(token.connect(spender).changeTransferAuthorization(spender, true, "test")).to.be.revertedWith("E0");
      expect(await token.changeTransferAuthorization(spender, true, "test")).to.emit("TransferAuthorized");

      expect(await token.connect(spender).transfer("0x1234567890123456789012345678901234500002", 150_000n * BigInt(10 ** 18))).to.emit("Transfer");
    });
});