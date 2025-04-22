const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers } = require('hardhat');
const { expect } = require('chai');
const { boolean } = require('hardhat/internal/core/params/argumentTypes');

const decimalAdjustment = BigInt(10 ** 18);

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

describe('Test ERC20 methods', function () {
    it('Should deploy, have right parameters', async function () {
      const [ owner, token ] = await loadFixture(_deploy);
  
      expect(await token.owner()).to.equal(owner);
      expect(await token.symbol()).to.equal("TEST");
      expect(await token.balanceOf(owner)).to.equal(250_000n * decimalAdjustment);
      expect(await token.circulatingSupply()).to.equal(250_000n * decimalAdjustment);
      expect(await token.cap()).to.equal(5_000_000n * decimalAdjustment);
      expect(await token.totalSupply()).to.equal(5_000_000n * decimalAdjustment);
      expect(await token.decimals()).to.equal(18);
    });
  
    it('Should properly transfer tokens', async function() {
      const [ owner, token, spender ] = await loadFixture(_deploy);

      await expect(token.connect(spender).transfer("0x1234567890123456789012345678901234567890", 100n * decimalAdjustment)).to.be.revertedWith("Locked");
      await expect(token.transfer("0x1234567890123456789012345678901234567365", 100n * decimalAdjustment)).to.emit(token, 'Transfer');
      await token.unlockTransfers();
      
      await expect(token.transfer("0x1234567890123456789012345678901234567890", 100n * decimalAdjustment)).to.emit(token, 'Transfer');
      expect(await token.balanceOf("0x1234567890123456789012345678901234567890")).to.equal(100n * decimalAdjustment);
      expect(await token.balanceOf(owner)).to.equal(249_800n * decimalAdjustment);
    });
  
    it('Should not allow transfer if amount exceeds balance', async function() {
      const [ owner, token ] = await loadFixture(_deploy);
      await token.unlockTransfers();
  
      await expect(token.transfer("0x1234567890123456789012345678901234567890", 250_000n * decimalAdjustment + 1n)).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });
  
    it('Should properly manage allowance and transferFrom', async function() {
      const [ owner, token ] = await loadFixture(_deploy);
      // We need to use spender address so that Hardhat can manage signature
      const [ o, spender ] = await ethers.getSigners();
      await token.unlockTransfers();
  
      await token.approve(spender, 1_000n * BigInt(10 ** 18));
      expect(await token.allowance(owner, spender)).to.equal(1_000n * decimalAdjustment);
      
      await expect(token.connect(spender).transferFrom(owner, spender, 550n * decimalAdjustment)).to.emit(token, 'Transfer');
      await expect(token.connect(spender).transferFrom(owner, ethers.ZeroAddress, 550n * decimalAdjustment)).to.be.revertedWithCustomError(token, 'ERC20InvalidReceiver');
      
      const balanceOwner = await token.balanceOf(owner);
      const balanceSpender = await token.balanceOf(spender);

      expect(balanceOwner).to.equal((250_000n - 550n) * decimalAdjustment);
      expect(balanceSpender).to.equal(550n * decimalAdjustment);
      expect(await token.allowance(owner, spender)).to.equal(450n * decimalAdjustment);
      expect(await token.circulatingSupply()).to.equal(balanceOwner + balanceSpender);
    });
  
    it('Should properly reject transferFrom if above allowance', async function() {
      const [ owner, token ] = await loadFixture(_deploy);
      // We need to use spender address so that Hardhat can manage signature
      const [ o, spender ] = await ethers.getSigners();
      await token.unlockTransfers();
  
      await token.approve(spender, 500n * decimalAdjustment);
      await expect(token.connect(spender).transferFrom(owner, spender, 501n * decimalAdjustment)).to.be.revertedWithCustomError(token, "ERC20InsufficientAllowance");
    });
  });