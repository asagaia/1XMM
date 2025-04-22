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

describe('Test cap and burn token functions', function () {
    it('Can manage cap properly', async function () {
      const [owner, token] = await loadFixture(_deploy);
      await token.unlockTransfers();
      
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const cap = 5_000_000n * BigInt(10 ** 18);
      const amount1 = 100n * BigInt(10 ** 18);

      await expect(token.allocate("0x1234567890123456789012345678901234567890", amount1)).to.emit(token, 'Allocated');
      expect (await token.availableTokens()).to.equal(cap - (ownerAmount + amount1));

      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1);
      expect (await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());
      expect(await token.totalSupply()).to.equal(cap);

      await token.transfer("0x1234567890123456789012345678901234567893", amount1);

      expect(await token.balanceOf("0x1234567890123456789012345678901234567890")).to.equal(amount1);
      expect(await token.balanceOf("0x1234567890123456789012345678901234567893")).to.equal(amount1);
      expect(await token.balanceOf(owner)).to.equal(ownerAmount - amount1);

      // supply and cap have not changed
      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1);
      expect(await token.totalSupply()).to.equal(cap);
      expect (await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());

      await expect(token.allocate("0x1234567890123456789012345678901234567893", await token.availableTokens() + 1n)).to.revertedWithCustomError(token, "ERC20AllocationFailed");
    });

    it('Can burn user\'s tokens properly', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 10_000n * BigInt(10 ** 18);
      const burnAmount = 1_000n * BigInt(10 ** 18);

      await token.allocate(spender, amount1);
      
      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1);
      expect(await token.connect(spender).burn(burnAmount)).to.emit(token, "Burnt");

      expect(await token.balanceOf(spender)).to.equal(amount1 - burnAmount);
      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1 - burnAmount);
      expect(await token.totalSupply()).to.equal(5_000_000n * BigInt(10 ** 18) - burnAmount);
      expect (await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());

      await expect(token.connect(spender).burn(amount1)).to.be.revertedWithCustomError(token, "ERC20InsufficientBalance");
    });

    it('Can burn non-allocated tokens properly', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      
      const initialSupply = await token.totalSupply();
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 10_000n * BigInt(10 ** 18);
      const burnAmount = 10_000n * BigInt(10 ** 18);

      await token.allocate(spender, amount1);
      expect(await token.burn(burnAmount)).to.emit(token, "Burnt");

      expect(await token.totalSupply()).to.equal(initialSupply - burnAmount);
      expect(await token.circulatingSupply()).to.equal(ownerAmount + amount1);
      expect(await token.availableTokens()).to.equal(initialSupply - (burnAmount + ownerAmount + amount1));

      await expect(token.burn(await token.availableTokens() + 1n)).to.be.revertedWith("E1");
    });

  it('Can burn and allocate', async function() {
    const [owner, token, spender] = await loadFixture(_deploy);

    const burntAmt = 250_000n * BigInt(10 ** 18);
    const initCap = await token.cap();

    await expect(token.burn(burntAmt)).to.emit(token, 'Burnt');
    const newSupply = await token.totalSupply(); // new supply is 4.75mios

    expect (newSupply).to.equal(initCap - burntAmt);
    expect (await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());

    const circSupply = await token.circulatingSupply();
    expect (circSupply).to.equal(await token.balanceOf(owner));
    expect (circSupply).to.equal(250_000n * BigInt(10 ** 18));

    await expect(token.allocate(spender, newSupply - circSupply + 1n)).to.be.revertedWithCustomError(token, 'ERC20AllocationFailed');
    await expect(token.allocate(spender, initCap - circSupply)).to.be.revertedWithCustomError(token, 'ERC20AllocationFailed');
    await expect(token.allocate(spender, newSupply - circSupply)).to.emit(token, 'Allocated');

    expect (await token.circulatingSupply()).to.equal(await token.balanceOf(spender) + await token.balanceOf(owner));
    expect (await token.availableTokens()).to.equal(await token.totalSupply() - await token.circulatingSupply());

    expect(await token.totalSupply()).to.equal(initCap - burntAmt);
  });

  it('Cannot burn more than available tokens', async function() {
    const [owner, token] = await loadFixture(_deploy);
          
    const initSupply = await token.totalSupply();
    const ownerAmount = 250_000n * BigInt(10 ** 18);
    
    await expect(token.burn(initSupply)).to.be.revertedWith("E1");
    const burntAmt = 250_000n * BigInt(10 ** 18);
    await expect(token.burn(burntAmt)).to.emit(token, 'Burnt');
    
    const newSupply = await token.totalSupply();
    expect(newSupply).to.equal(initSupply - burntAmt);
    
    await token.allocate("0x1234567890123456789012345678901234567890", burntAmt);
    expect(await token.circulatingSupply()).to.equal(ownerAmount + burntAmt);
    expect(await token.availableTokens()).to.equal(newSupply - (ownerAmount + burntAmt));
    await expect(token.burn(newSupply - burntAmt)).to.be.revertedWith("E1");
  });

  it ('Can burn from another account', async function() {
    const [owner, token, spender] = await loadFixture(_deploy);

    const amt1 = 2_000n * BigInt(10 ** 18);
    await token.allocate(spender, amt1);
    const initCap = await token.cap();

    await expect(token.burnFrom(spender, amt1 / 2n)).to.be.revertedWithCustomError(token, "ERC20InsufficientAllowance");
    expect(await token.cap()).to.equal(initCap);
    await token.connect(spender).approve(owner, amt1);

    expect(await token.burnFrom(spender, amt1 / 2n)).to.emit("Burnt");
    expect(await token.balanceOf(spender)).to.equal(amt1 / 2n);
  })

  it ('Can burn from ourselves', async function() {
    const [owner, token, spender] = await loadFixture(_deploy);

    const amt1 = 2_000n * BigInt(10 ** 18);
    await token.allocate(spender, amt1);

    await expect(token.connect(spender).getFunction("burn(address,uint256)")(spender, amt1)).to.emit(token, "Burnt");
    expect(await token.balanceOf(spender)).to.equal(0n);
  });
});