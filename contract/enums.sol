// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

enum LongShort { Long, Short }
enum FixingTypes { Previous, Next }
enum Terms { OneDay, OneWeek, TwoWeeks, ThreeWeeks, OneMonth, TwoMonths, ThreeMonths }
enum UpdateIntervals { OneMin, TwoMin, ThreeMin, FiveMin, TenMin, FifteenMin, TwentyMin, ThirtyMin, OneH, TwoH, ThreeH, FourH }
enum CompensatedSides {None, Long, Short, All}
enum OptionTypes { Call, Put }
enum DurationUnits { Days, Weeks, Months }