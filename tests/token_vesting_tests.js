const { time, loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { ethers, network } = require('hardhat');
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

describe('Test vesting functions', function () {
    it('Can allocate without vesting', async function () {
        const [owner, token, spender] = await loadFixture(_deploy);
      
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 100n * BigInt(10 ** 18);

      expect(await token.allocate(spender, amount1)).to.emit(token, 'Allocated');
      var spenderConnect = await token.connect(spender);
      expect(await spenderConnect.getReleasableAmount()).to.equal(0n);
    });

    it('Can allocate with vesting', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      await token.unlockTransfers();
      
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 10_000n * BigInt(10 ** 18);
      // await expect(token.connect(spender).getFunction("burn(address,uint256)")(spender, amt1)).to.emit(token, "Burnt");
      await expect(token.connect(spender)
        .getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 3, 0, 0, 1, 2))
        .to.be.rejectedWith("E0");
      await expect(token
        .getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 3, 0, 0, 1, 2))
        .to.emit(token, 'Allocated').to.emit(token, "VestingScheduleCreated");

      var spenderConnect = await token.connect(spender);
      await expect(spenderConnect.transfer(owner, 100n * BigInt(10 ** 18))).to.be.revertedWith("E102");

      await time.increase(2*3*24*3600);
      expect(await spenderConnect.getReleasableAmount()).to.be.above(1_000n * BigInt(10 ** 18));
      await expect(spenderConnect.transfer(owner, 1_000n * BigInt(10 ** 18))).to.emit(token, "Transfer");
      await expect(spenderConnect.transfer(owner, 1n * BigInt(10 ** 18))).to.be.revertedWith("E102");

      expect(await token.balanceOf(spender)).to.equal(9_000n * BigInt(10 ** 18));
      await expect(token
        .getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 3, 0, 0, 1, 2))
        .to.emit(token, 'Allocated').to.emit(token, "TokensAddedToVestingSchedule");
    });

    it('Can transfer all after vesting', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      await token.unlockTransfers();
      
      const ownerAmount = 250_000n * BigInt(10 ** 18);
      const amount1 = 10_000n * BigInt(10 ** 18);
      
      var spenderConnect = await token.connect(spender);
      await expect(token.getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 3, 0, 0, 1, 2)).to.emit(token, 'Allocated').to.emit(token, "VestingScheduleCreated");

      await time.increase(33*24*3600);
      expect(await spenderConnect.getReleasableAmount()).to.be.equal(amount1);
      await expect(spenderConnect.transfer(owner, amount1)).to.emit(token, "Transfer");
      expect(await token.balanceOf(spender)).to.equal(0n);
    });

    it('Can manage upftont at cliff', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      
      const amount1 = 10_000n * BigInt(10 ** 18);
      
      var spenderConnect = await token.connect(spender);
      await expect(token.getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 3, 0, 20, 1, 2)).to.emit(token, 'Allocated').to.emit(token, "VestingScheduleCreated");

      await time.increase(3*24*3600 - 10);
      expect(await spenderConnect.getReleasableAmount()).to.be.equal(0n);
      await time.increase(11);
      expect(await spenderConnect.getReleasableAmount()).to.be.above(2_000n * BigInt(10 ** 18));
      await time.increase(30*24*3600 + 1);
      expect(await spenderConnect.getReleasableAmount()).to.be.equal(amount1);
    });

    it('Can get allocate with no cliff', async function () {
      const [owner, token, spender] = await loadFixture(_deploy);
      await token.unlockTransfers();

      const amount1 = 10_000n * BigInt(10 ** 18);
      
      var spenderConnect = await token.connect(spender);
      await expect(token.getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 0, 0, 20, 1, 2)).to.emit(token, "VestingScheduleCreated");

      const releasable = await spenderConnect.getReleasableAmount();
      expect(releasable).to.equal(2_000n * BigInt(10 ** 18));

      const initAmt = await spenderConnect.getRemainingVestedAmount();
      expect(initAmt).to.equal(10_000n * BigInt(10 ** 18));

      await spenderConnect.transfer("0x1234567890123456789012345678901234500005", 1_000n * BigInt(10 ** 18));
      expect(await spenderConnect.getRemainingVestedAmount()).to.equal(9_000n * BigInt(10 ** 18));

      expect(await token.getRemainingVestedAmount()).to.equal(0n);
    });

    it('Can get the right non-vested amt after release', async function() {
      const [owner, token, spender] = await loadFixture(_deploy);
      await token.unlockTransfers();
      const amount1 = 10_000n * BigInt(10 ** 18);

      // we transfer first to spender
      await token.getFunction("allocateWithVesting(address,uint256,uint16,uint8,uint8,uint16,uint8)")(spender, amount1, 0, 0, 20, 1, 2);
      // spender will transfer the cliff amt to dummy address
      expect(await token.connect(spender).transfer("0x1234567890123456789012345678901234500005", 2_000n * BigInt(10 ** 18))).to.emit("Transfer");

      await token.allocate(spender, 1_000n * BigInt(10 ** 18));
      await time.increase(10*24*3600);

      const nonVested = await token.balanceOf(spender) - await token.connect(spender).getRemainingVestedAmount();
      expect (nonVested).to.equal(1_000n * BigInt(10 ** 18));

      expect (await token.balanceOf(spender)).to.equal(9_000n * BigInt(10 ** 18));
      expect (await token.transfer("0x1234567890123456789012345678901234500005", 3_666n * BigInt(10 ** 18))).to.emit("Transfer");
    })
  });