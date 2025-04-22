// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import "./math.sol";
import "../structures/position.sol";
import "../enums.sol";

library Utils {
    uint internal constant ONE_DAY_TIMESPAN_INTERVAL = 86_400;
    uint internal constant ONE_WEEK_TIMESPAN_INTERVAL = 604_800;
    uint internal constant TWO_WEEKS_TIMESPAN_INTERVAL = 1_209_600;
    uint internal constant THREE_WEEKS_TIMESPAN_INTERVAL = 1_814_400;
    uint internal constant ONE_MONTH_TIMESPAN_INTERVAL = 2_592_000;
    uint internal constant TWO_MONTHS_TIMESPAN_INTERVAL = 5_184_000;
    uint internal constant THREE_MONTHS_TIMESPAN_INTERVAL = 7_776_000;
    uint internal constant ONE_YEAR_TIMESPAN_INTERVAL = 31_536_000;

    uint64 internal constant ONE_DAY_YF = 11_767_034;
    uint64 private constant ONE_WEEK_YF = 82_369_236;
    uint64 private constant TWO_WEEKS_YF = 164_738_472;
    uint64 private constant THREE_WEEKS_YF = 247_107_707;
    uint64 private constant ONE_MONTH_YF = 353_011_011; // 30 days
    uint64 private constant TWO_MONTHS_YF = 706_022_021; // 60 days
    uint64 private constant THREE_MONTHS_YF = 1_059_033_032; // 90 days

    uint internal constant ONE_MINUTE_UPDATE_INTERVAL = 60;
    uint internal constant TWO_MINUTES_UPDATE_INTERVAL = 120;
    uint internal constant THREE_MINUTES_UPDATE_INTERVAL = 180;
    uint internal constant FIVE_MINUTES_UPDATE_INTERVAL = 300;
    uint internal constant TEN_MINUTES_UPDATE_INTERVAL = 600;
    //uint internal constant FIFTEEN_MINUTES_UPDATE_INTERVAL = 900;
    //uint internal constant TWENTY_MINUTES_UPDATE_INTERVAL = 1_200;
    //uint internal constant THIRTY_MINUTES_UPDATE_INTERVAL = 1_800;
    //uint internal constant ONE_HOUR_UPDATE_INTERVAL = 3_600;
    //uint internal constant TWO_HOURS_UPDATE_INTERVAL = 7_200;
    //uint internal constant THREE_HOURS_UPDATE_INTERVAL = 10_800;
    //uint internal constant FOUR_HOURS_UPDATE_INTERVAL = 14_400;

    /// @notice Computes option expiry as a year fraction
    function getTermInformation(uint8 term) internal pure returns(uint expiryInterval, uint64 expiryYF) {
        if (term == 0) return (ONE_DAY_TIMESPAN_INTERVAL, ONE_DAY_YF);
        if (term == 1) return (ONE_WEEK_TIMESPAN_INTERVAL, ONE_WEEK_YF);
        if (term == 2) return (TWO_WEEKS_TIMESPAN_INTERVAL, TWO_WEEKS_YF);
        if (term == 3) return (THREE_WEEKS_TIMESPAN_INTERVAL, THREE_WEEKS_YF);
        if (term == 4) return (ONE_MONTH_TIMESPAN_INTERVAL, ONE_MONTH_YF);
        if (term == 5) return (TWO_MONTHS_TIMESPAN_INTERVAL, TWO_MONTHS_YF);

        return (THREE_MONTHS_TIMESPAN_INTERVAL, THREE_MONTHS_YF);
    }

    /// @notice Checks if an address is in an array of addresses, and returns the index
    function itemExistsInArray(address item, address[] memory intoArray) internal pure returns(bool, uint) {
        for (uint i = 0; i < intoArray.length; i++) {
            if (item == intoArray[i]) return (true, i);
        }

        return (false, 0);
    }

    /// @notice Checks if a uint is in an array of uint, and returns the index
    function itemExistsInArray(uint item, uint[] storage intoArray) internal view returns(bool, uint) {
        for (uint i = 0; i < intoArray.length; i++) {
            if (item == intoArray[i]) return (true, i);
        }

        return (false, 0);
    }
    
    /// @notice Gets the position pro-rated holding time. If position has been hold for a longer period of time
    //          than initially expected, the pro-rated time is equal to 1
    function getProRata(uint tradeTimestamp, Position storage position, uint positionTimeSpanInterval) internal view returns(uint64) {
        uint holdingPeriod = tradeTimestamp - position.startDate;

        if (holdingPeriod > positionTimeSpanInterval) return Math.One_32;
        return uint64((holdingPeriod << 32) / positionTimeSpanInterval);
    }

    /// @notice Returns the accrual period as a year fraction
    function getAccrualYF(uint currentFixingUpdateInterva, uint expiryInterval) internal pure returns(uint64) {
        return Math.div(uint64(currentFixingUpdateInterva) << 32, uint64(expiryInterval) << 32);
    }

    function removePositionFromArray(uint32 indexOfItemToRemove, Position[] storage positions) internal {
        require(indexOfItemToRemove < positions.length, "Bad Index");
        Position storage lastPosition = positions[positions.length - 1];
        lastPosition.positionIndex = indexOfItemToRemove;
        positions[uint(indexOfItemToRemove)] = lastPosition;
        positions.pop();
    }

    function getAccrualDetails(uint64[] storage premiaReceiver, uint64[7] storage currentAccrualYFs, uint128[7] storage payerPositions, uint128[7] storage receiverPositions,
     uint128 totalPositionPayer, uint128 totalPositionReceiver, uint128 pot) internal view returns(uint128[] memory amtPayerByTerm, uint128[] memory amtReceiverByTerm) {
        amtPayerByTerm = new uint128[](7);
        amtReceiverByTerm = new uint128[](7);
        
        if (totalPositionPayer == 0 || totalPositionReceiver == 0) return (amtPayerByTerm, amtReceiverByTerm);

        uint8 i;
        uint128 totalPaid = 0;
        uint160 sumReceiver = 0;
        uint160[] memory tmpReceiver = new uint160[](7);

        for (i = 0; i < 7; i++) {
            uint64 accrualFactor = Math.mult(premiaReceiver[i], currentAccrualYFs[i]);
            amtPayerByTerm[i] = uint128(Math.multPerf(accrualFactor, payerPositions[i]) >> 32);
            tmpReceiver[i] = Math.multPerf(accrualFactor, receiverPositions[i]);

            totalPaid += amtPayerByTerm[i];
            sumReceiver += tmpReceiver[i];
        }

        totalPaid += pot;

        for (i = 0; i < 7; i++) {
            amtReceiverByTerm[i] = uint128(Math.multPerf(uint64(tmpReceiver[i] / sumReceiver), totalPaid) >> 32);
        }
    }

    /// @notice Adds a new strike to the list of strikes which have been dealt
    function addStrikeToList(uint40[] storage existingStrikes, uint40 newStrike) internal {
        for (uint32 i = 0; i < existingStrikes.length; i++) {
            if (existingStrikes[i] == newStrike) return;
        }

        existingStrikes.push(newStrike);
    }
}