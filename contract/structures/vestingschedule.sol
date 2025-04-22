// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { DurationUnits } from  "../enums.sol";

struct VestingSchedule {
    // beneficiary of tokens after they are released
    address beneficiary;
    // The upfront release when the vesting starts
    uint8 upfrontRelease;
    // start time of the vesting period
    uint start;
    // end of the vesting period in DurationUnits
    uint end;
    // the number of seconds between start and end
    uint totalDuration;
    // total amount of tokens to be released at the end of the vesting;
    uint256 totalAmount;
    // amount of tokens released
    uint256 released;
}