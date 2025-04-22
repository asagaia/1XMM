// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { IERC20 } from  "../../interfaces/ierc20.sol";
import { IERC20Errors } from  "../../interfaces/ierc20errors.sol";

import { DurationUnits } from  "../../enums.sol";
import { VestingSchedule } from  "../../structures/vestingschedule.sol";

import { ERC20Burnable } from  "./erc20burnable.sol";

abstract contract ERC20Vested is ERC20Burnable {
    /**********
     * Events *
     **********/
    /// @notice Emitted when a vesting schedule is created
    event VestingScheduleCreated(address indexed beneficiary, uint start, uint end, uint8 upfrontRelease, uint256 amount);
    /// @notice Emitted when a vesting schedule is created
    event TokensAddedToVestingSchedule(address indexed beneficiary, uint256 amount);
    /// @notice Emitted when tokens are released
    event TokensReleased(address indexed beneficiary, uint256 amount);
    /// @notice Emitted when an authorization for transfer has been granted
    event TransferAuthorized(address indexed account, bool status, string reason);

    /*************
     * Modifiers *
     *************/
    /// @notice Modifier that checks if the contract is unlocked
    modifier unlocked(address sender) {
        require(_unlocked || sender == _owner || _authorizedAddresses[sender], "Locked");
        _;
    }

    /**************
     * Properties *
     **************/
    /// @notice The vesting schedules for each beneficiary
    mapping(address beneficiary => VestingSchedule) private _vestingSchedules;
    mapping(address beneficiary => bool) private _hasVestingSchedule;

    // The list of addresses which are authorized to transfer
    // even if token is locked.
    mapping(address => bool) internal _authorizedAddresses;

    // Private properties
    bool private _unlocked = false;

    /***************
     * Constructor *
     ***************/
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20Burnable(owner_, name_, symbol_, decimals_)
    {}

    /// @notice Transfers tokens from the msg sender to another address
    /// overrides the transfer function of ERC20
    function transfer(address to, uint256 value) public override unlocked(msg.sender) returns(bool) {
        if (msg.sender == address(0)) revert IERC20Errors.ERC20InvalidSender(address(0));
        if (to == address(0)) revert IERC20Errors.ERC20InvalidReceiver(address(0));
        uint256 releasableAmount = _releaseTokens(msg.sender, value);
        require(releasableAmount >= value, "E102");

        return super.transfer(to, value);
    }

    /// @notice Transfers tokens from one address to another
    /// overrides the transferFrom function of ERC20
    function transferFrom(address from, address to, uint256 value) public override unlocked(msg.sender) returns(bool) {
        if (from == address(0)) revert IERC20Errors.ERC20InvalidSender(address(0));
        if (to == address(0)) revert IERC20Errors.ERC20InvalidReceiver(address(0));
        uint256 releasableAmount = _releaseTokens(from, value);
        require(releasableAmount >= value, "E102");

        return super.transferFrom(from, to, value);
    }

    /// @notice Gets the remaining amount of tokens which are vested
    function getRemainingVestedAmount() public view returns(uint256 remainingVestedAmt) {
        remainingVestedAmt = 0;

        if (_hasVestingSchedule[msg.sender]) {
            VestingSchedule storage schedule = _vestingSchedules[msg.sender];
            remainingVestedAmt = schedule.totalAmount - schedule.released;
        }
    }

    /// @notice Gets the amount of vested tokens which can be withdrawn by the msg.sender
    function getReleasableAmount() external view returns(uint256 releasableAmt) {
        (releasableAmt, ) = _getReleasableAmount(msg.sender);
    }

    /// @notice Sets the authorization status for `account` to transfer tokens before the unlock
    /// @param account The beneficiary account
    /// @param status The authorization status: true or false
    /// @param reason The reason for providing or removing the authorization
    /// @dev This functionality has been implemented mainly to allow bridges when the contract is locked
    function changeTransferAuthorization(address account, bool status, string memory reason) external onlyOwner {
        _authorizedAddresses[account] = status;
        emit TransferAuthorized(account, status, reason);
    }

    /// @notice Unlocks the contract and allows transfers to be made
    /// @dev This function can only be called to set the unlocked property to true
    // Once the contract is unlocked, it cannot be locked again
    function unlockTransfers() external onlyOwner {
        _unlocked = true;
    }

    /// @dev Gets the amount of vested tokens which can be withdrawn by the beneficiary
    function _getReleasableAmount(address beneficiary) internal view returns(uint256 releasableAmt, bool vestingEnded) {
        releasableAmt = 0;
        vestingEnded = false;

        if (_hasVestingSchedule[beneficiary]) {
            VestingSchedule storage schedule = _vestingSchedules[beneficiary];
            
            // if end of cliff period has not been reached, 0 can be released
            if (block.timestamp < schedule.start) return (releasableAmt, vestingEnded);
            if (block.timestamp >= schedule.end) {
                vestingEnded = true;
                releasableAmt = schedule.totalAmount - schedule.released;
                return (releasableAmt, vestingEnded);
            }
            
            uint256 upfrontRelease = uint256((schedule.totalAmount * schedule.upfrontRelease) / 100);
            releasableAmt = upfrontRelease + uint256(((schedule.totalAmount - upfrontRelease) * (block.timestamp - schedule.start)) / schedule.totalDuration);
            
            // Sanity check - we make sure to always release at max the total amount of tokens
            if (releasableAmt > schedule.totalAmount) releasableAmt = schedule.totalAmount;
            releasableAmt -= schedule.released;
        }
    }

    /// @dev Gets the amount of tokens which are not vested
    function _getNonVestedAmount(address beneficiary) internal view returns(uint256 nonVestedAmt) {
        nonVestedAmt = 0;

        if (_hasVestingSchedule[beneficiary]) {
            VestingSchedule storage schedule = _vestingSchedules[beneficiary];

            uint256 currentBalance = IERC20(address(this)).balanceOf(beneficiary);
            if (currentBalance > schedule.totalAmount) nonVestedAmt = currentBalance - (schedule.totalAmount - schedule.released);
        }
    }

    /// @dev Computes the amount of tokens which can be released and updates the schedule (if ever)
    function _releaseTokens(address beneficiary, uint256 amount) internal returns(uint256) {
        if (_hasVestingSchedule[beneficiary]) {
            (uint256 releasableAmount, bool canDelete) = _getReleasableAmount(beneficiary);
            uint256 extraAmount = 0;

            if (releasableAmount < amount) extraAmount = _getNonVestedAmount(beneficiary);
            else releasableAmount = amount;

            if (canDelete) {
                _hasVestingSchedule[beneficiary] = false;
                delete _vestingSchedules[beneficiary];
            } else {
                _vestingSchedules[beneficiary].released += releasableAmount;
                emit TokensReleased(beneficiary, releasableAmount);
            }
            
            return releasableAmount + extraAmount;
        }

        return amount;
    }

     /**
     * @dev Creates a vesting schedule
     * @param beneficiary The address of the beneficiary
     * @param upfrontRelease The amount released when cliff period ends
     * @param start The start UNIX timestamp of the vesting period - this can correspond to a cliff period
     * @param duration The duration of the vesting period in DurationUnits
     * @param durationUnit The units of the duration(0 = days, 1 = weeks, 2 = months)
     * @param amount The total amount of tokens to be vested
     */
    function _createVestingSchedule(address beneficiary, uint8 upfrontRelease, uint start, uint16 duration, DurationUnits durationUnit, uint256 amount) internal {
        // perform input checks
        require(beneficiary != address(0) && amount > 0 && start >= block.timestamp && duration > 0, "E101");

        // if beneficiary already has a vesting schedule, we just add the amount to the existing schedule
        if (_hasVestingSchedule[beneficiary]) {
            VestingSchedule storage schedule = _vestingSchedules[beneficiary];
            schedule.totalAmount += amount;
            emit TokensAddedToVestingSchedule(beneficiary, amount);
            return;
        }
        
        uint end = _addDuration(start, duration, durationUnit);
        
        // create the vesting schedule and add it to the list of schedules for the beneficiary
        _vestingSchedules[beneficiary] = VestingSchedule(beneficiary, upfrontRelease, start, end, end - start, amount, 0);
        _hasVestingSchedule[beneficiary] = true;

        emit VestingScheduleCreated(beneficiary, start, end, upfrontRelease, amount);
    }

    /*******************
     * Private Methods *
     *******************/
    /// @dev Adds a duration to a timestamp
    function _addDuration(uint start, uint16 duration, DurationUnits durationUnit) internal pure returns(uint) {
        if (durationUnit == DurationUnits.Days) return start + duration * 86_400;
        if (durationUnit == DurationUnits.Weeks) return start + duration * 604_800;
        return start + duration * 2_592_000;
    }
}