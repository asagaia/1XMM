const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers } = require('hardhat');
const { expect } = require('chai');

const decimalAdjustment = BigInt(10 ** 18);
const ratePrecision = 10_000n;

async function deploy() {
  const [owner, spender] = await ethers.getSigners();
  const contractFactory = await ethers.getContractFactory("OneXMM");

  const token = await contractFactory.deploy("TEST", "Test token");

  // Initial supply is 5 mios
  await token.allocate(token, 5_000_000n * BigInt(10 ** 18));
  // Allocation to owner is 250k
  await token.allocate(owner, 250_000n * BigInt(10 ** 18));

  return [owner, token, spender];
}

describe('Test base token functions', function () {
    it('Cannot transfer if locked', async function () {
      const [owner, token, spender] = await loadFixture(deploy);
      
      const amount1 = 100n * BigInt(10 ** 18);
      await expect(token.allocate(spender, amount1)).to.emit(token, 'Allocated');
      await expect(token.connect(spender).transfer(owner.address, amount1)).to.be.revertedWith("Locked");

      await token.unlockTransfers();
      await expect(token.connect(spender).transfer(owner.address, amount1)).to.emit(token, 'Transfer');
    });

    it('Allocation is done properly and is reflected in AllocatedAmount', async function () {
      const [owner, token, spender] = await loadFixture(deploy);

      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 100n * BigInt(10 ** 18);
      await expect(token.allocate("0x1234567890123456789012345678901234567890", amount1)).to.emit(token, 'Allocated');

      const amount2 = 50n * BigInt(10 ** 18);
      await token.allocate("0x1234567890123456789012345678901233458793", amount2);

      expect(await token.balanceOf("0x1234567890123456789012345678901234567890")).to.equal(amount1);
      expect(await token.balanceOf("0x1234567890123456789012345678901233458793")).to.equal(amount2);
      expect(await token.totalSupply()).to.equal(5_000_000n * BigInt(10 ** 18));
      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1 + amount2);
      expect(await token.availableTokens()).to.equal(5_000_000n * BigInt(10 ** 18) - (ownerAmount + amount1 + amount2));
    });

    it('Can allocate to different users', async function() {
      const [owner, token, spender] = await loadFixture(deploy);

      const amount1 = 200n * BigInt(10 ** 18);
      await expect(token.connect(spender).allocate(spender, amount1)).to.be.rejectedWith("E0");

      await token.allocate("0x1234567890123456789012345678901111111111", amount1);
      await token.allocate("0x1234567890123456789012345678902222222222", 2n * amount1);
      await token.allocate("0x1234567890123456789012345678903333333333", 3n * amount1);

      expect(await token.balanceOf("0x1234567890123456789012345678901111111111")).to.equal(amount1);
      expect(await token.balanceOf("0x1234567890123456789012345678902222222222")).to.equal(2n * amount1);
      expect(await token.balanceOf("0x1234567890123456789012345678903333333333")).to.equal(3n * amount1);

      expect(await token.availableTokens()).to.equal(await token.totalSupply() - (6n * amount1 + 250_000n * BigInt(10 ** 18)));
    });

    it('Cannot allocate more than available', async function() {
      const [owner, token, spender] = await loadFixture(deploy);

      const cap = await token.totalSupply();
      const ownerBalance = await token.balanceOf(owner.address);

      await expect(token.allocate("0x1234567890123456789012345678901234567890", cap)).to.be.revertedWithCustomError(token, "ERC20AllocationFailed");
      await expect(token.allocate("0x1234567890123456789012345678901234567890", cap -  ownerBalance + 1n)).to.be.revertedWithCustomError(token, "ERC20AllocationFailed");

      await token.allocate("0x1234567890123456789012345678901234567890", cap -  ownerBalance);
      const newBalance = await token.balanceOf("0x1234567890123456789012345678901234567890");
      
      expect(await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());
      expect(newBalance + ownerBalance).to.equal(await token.circulatingSupply());
      expect(await token.circulatingSupply() + await token.balanceOf(token)).to.equal(await token.totalSupply());
      await expect(token.allocate("0x1234567890123456789012345678901234567890", 1n)).to.be.revertedWithCustomError(token, "ERC20AllocationFailed");
    });

    it('Approve and Allowance work as expected', async function() {
      const [owner, token, spender] = await loadFixture(deploy);
      await token.unlockTransfers();
  
      const newBalance = 2_500n * BigInt(10 ** 18);
      await token.allocate(spender.address, newBalance);
  
      await token.connect(spender).approve(owner, newBalance / 2n);
      const allowance = await token.allowance(spender, owner);
  
      expect(allowance).to.equal(newBalance / 2n);
      await token.connect(owner).transferFrom(spender, "0x1234567890123456789012345678901234567890", newBalance / 4n);
      const balance90 = await token.balanceOf("0x1234567890123456789012345678901234567890");
  
      expect(balance90).to.equal(newBalance / 4n);
      await expect(token.transferFrom(spender, "0x1234567890123456789012345678901234567890", newBalance)).to.be.revertedWithCustomError(token, "ERC20InsufficientAllowance");
      await expect(token.transferFrom(spender, "0x1234567890123456789012345678901234567890", newBalance / 2n)).to.be.revertedWithCustomError(token, "ERC20InsufficientAllowance");
  
      await token.connect(spender).approve(owner, newBalance);
      await expect(token.transferFrom(spender, "0x1234567890123456789012345678901234567890", 3n * newBalance / 4n + 1n)).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });

    it('Can change ownership', async function() {
      const [owner, token, spender] = await loadFixture(deploy);
      
      await expect(token.connect(spender).changeOwnership(spender)).to.be.revertedWith("E0");
      expect(await token.changeOwnership(spender)).to.emit("OwnerChanged");

      expect(await token.owner()).to.equal(spender.address);
    });

    it ('Can mass allocate', async function() {
      const [owner, token, spender] = await loadFixture(deploy);

      const allocateTo = ["0x1234567890123456789012345678901234567890", "0x1234567890123456789012345678901234567891"];
      const wrongAllocateTo = ["0x1234567890123456789012345678901234567890", "0x1234567890123456789012345678901234567891", "0x1234567890123456789012345678901234567892"];
      const allocateAmt = [1_000n * BigInt(10 ** 18), 1_500n * BigInt(10 ** 18)];
      const wrongAllocateAmt = [1_000n * BigInt(10 ** 18), 1_500n * BigInt(10 ** 18), 2_000n * BigInt(10 ** 18)];

      // OnlyOwner can mass allocate
      await expect(token.connect(spender).massAllocation(allocateTo, allocateAmt)).to.be.revertedWith("E0");

      // Cannot allocate if parameters do not have same size
      await expect(token.massAllocation(wrongAllocateTo, allocateAmt)).to.be.revertedWith("E104");
      await expect(token.massAllocation(allocateTo, wrongAllocateAmt)).to.be.revertedWith("E104");

      await token.massAllocation(allocateTo, allocateAmt);

      expect(await token.balanceOf("0x1234567890123456789012345678901234567890")).to.equal(1_000n * BigInt(10 ** 18));
      expect(await token.balanceOf("0x1234567890123456789012345678901234567891")).to.equal(1_500n * BigInt(10 ** 18));

      expect(await token.circulatingSupply()).to.equal(252_500n * BigInt(10 ** 18));
    });

    it ('Cannot allocate/transfer to, or approve address 0', async function() {
      const [owner, token, spender] = await loadFixture(deploy);

      await expect(token.connect(spender).transfer("0x0000000000000000000000000000000000000000", 1_000n * BigInt(10 ** 18))).to.be.revertedWith("Locked");

      await token.unlockTransfers();
      
      await expect(token.allocate("0x0000000000000000000000000000000000000000", 1_000n * BigInt(10 ** 18))).to.be.revertedWith("E103");
      await expect(token.transfer("0x0000000000000000000000000000000000000000", 1_000n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InvalidReceiver");
      await expect(token.transferFrom("0x0000000000000000000000000000000000000000", spender, 1_000n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InvalidSender");
      await expect(token.connect(spender).transfer("0x0000000000000000000000000000000000000000", 1_000n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InvalidReceiver");
      await expect(token.connect(spender).transferFrom("0x0000000000000000000000000000000000000000", spender, 1_000n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InvalidSender");
      await expect(token.approve("0x0000000000000000000000000000000000000000", 1_000n * BigInt(10 ** 18))).to.be.revertedWithCustomError(token, "ERC20InvalidSpender");
    });
  });