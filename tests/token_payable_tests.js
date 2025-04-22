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

describe('Test payable functions', function() {
    function abs(x) {
      return x < 0 ? -x : x;
    }

    it('Deposit is working properly', async function() {
      const [ owner, token, spender1 ] = await loadFixture(_deploy);

      var eth = ethers.parseEther("0.5");
      const prevETHBalance = await ethers.provider.getBalance(spender1.address);

      await expect(token.connect(spender1).depositEther({ value: eth })).to.be.revertedWith('E2');
      await token.setEthDepositExchangeRate(30_000_000);

      // Spender has not been approved
      await expect(token.connect(spender1).depositEther({ value: eth })).to.be.revertedWith('Not Approved');
      await expect(token.changeDepositorStatus(spender1, true)).to.emit(token, "DepositorStatusChanged").withArgs(spender1, true);

      // Now we can transfer
      await token.connect(spender1).depositEther({ value: eth })
      expect(await token.getAvailableQuantityOfETH()).to.equal(500_000_000_000_000_000n);
      expect(await token.balanceOf(spender1)).to.equal(1_500_000_000_000_000_000_000n);

      const newETHBalance = await ethers.provider.getBalance(spender1.address);
      const estimatedETHBalance = prevETHBalance - eth;
      expect(abs((newETHBalance - estimatedETHBalance) * 1000n / estimatedETHBalance)).to.be.lessThanOrEqual(10);

      // Spender approval is removed
      await expect(token.changeDepositorStatus(spender1, false)).to.emit(token, "DepositorStatusChanged").withArgs(spender1, false);
      await expect(token.connect(spender1).depositEther({ value: eth })).to.be.revertedWith('Not Approved');
    });

    it ('Sell-back is working properly', async function() {
      const [ owner, token, spender1 ] = await loadFixture(_deploy);

      var eth = ethers.parseEther("0.5");
      await token.setEthDepositExchangeRate(30_000_000);
      const prevETHBalance = await ethers.provider.getBalance(spender1.address);

      await token.changeDepositorStatus(spender1, true);
      await token.connect(spender1).depositEther({ value: eth });
      
      await expect(token.sellBack(1_500_000_000_000_000_000_001n)).to.be.revertedWith("E3");
      await token.connect(owner).updateEthExchangeRate(30_000_000);
      await expect(token.connect(spender1).sellBack(1_500_000_000_000_000_000_001n)).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");

      await token.connect(spender1).sellBack(750_000_000_000_000_000_000n);
      expect(await token.balanceOf(spender1)).to.equal(750_000_000_000_000_000_000n);
      expect(await token.getAvailableQuantityOfETH()).to.equal(250_000_000_000_000_000n);

      const newETHBalance = await ethers.provider.getBalance(spender1.address);
      eth = ethers.parseEther("0.25");

      const estimatedETHBalance = prevETHBalance - eth;
      expect(abs((newETHBalance - estimatedETHBalance) * 1000n / estimatedETHBalance)).to.be.lessThanOrEqual(10);
    });

    it ('Deposit is limited to available tokens', async function() {
      const [ owner, token, spender1 ] = await loadFixture(_deploy);

      var eth = ethers.parseEther("2500");
      await token.setEthDepositExchangeRate(30_000_000);
      const prevETHBalance = await ethers.provider.getBalance(spender1.address);

      await token.changeDepositorStatus(spender1, true);
      await token.connect(spender1).depositEther({ value: eth });

      var spenderBalance = await token.balanceOf(spender1);
      expect(spenderBalance).to.equal(await token.totalSupply() - await token.balanceOf(owner.address));

      const newETHBalance = await ethers.provider.getBalance(spender1.address);
      const estimatedETHBalance = prevETHBalance - spenderBalance / 3000n;
      
      expect(abs((estimatedETHBalance - newETHBalance) * 1000n / newETHBalance)).to.be.lessThanOrEqual(10);
    });

    it ('Cannot sell back more than available', async function() {
      const [ owner, token, spender1 ] = await loadFixture(_deploy);

      var eth = ethers.parseEther("0.5");
      await token.setEthDepositExchangeRate(30_000_000);
      await token.updateEthExchangeRate(30_000_000);
      const prevETHBalance = await ethers.provider.getBalance(spender1.address);

      await token.changeDepositorStatus(spender1, true);
      await token.connect(spender1).depositEther({ value: eth });
      await token.allocate(spender1.address, 1_500_000_000_000_000_000_000n);

      await token.connect(spender1).sellBack(1_750_000_000_000_000_000_000n);

      expect(await token.balanceOf(spender1)).to.equal(1_500_000_000_000_000_000_000n);
      expect(await token.getAvailableQuantityOfETH()).to.equal(0n);

      const newETHBalance = await ethers.provider.getBalance(spender1.address);
      expect(abs((newETHBalance - prevETHBalance) * 1000n / prevETHBalance)).to.be.lessThanOrEqual(10);
    });
  });