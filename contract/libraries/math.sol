// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

library Math {
  /*
  * Minimum value signed 32.32-bit fixed point number may have.
  */
  int64 internal constant MIN_32x32 = -0x8000000000000000;
  /*
  * Maximum value signed 32.32-bit fixed point number may have. 
  */
  int64 internal constant MAX_32x32 = 0x7FFFFFFFFFFFFFFF;
  /*
  * Maximum value unsigned 32.32-bit. 
  */
  uint64 internal constant MAX_U32x32 = 0xFFFFFFFFFFFFFFFF;
   /*
  * Maximum value unsigned 128.32-bit. 
  */
  uint160 internal constant MAX_U128x32 = 1461501637330902918203684832716283019655932542975;
  /*
  * One
  */
  uint64 internal constant One_32 = 0x100000000;

  function max(int8 x, int8 l) internal pure returns(uint8) {
    return x > l ? uint8(x) : uint8(l);
  }

  /**
  * @notice Calculates x + y for unsigned integer
  */
  function add(uint64 x, uint64 y) internal pure returns(uint64)
  {
    unchecked {
      uint64 res = x + y;
      require (res >= x && res >= y);
      return res;
    }
  }

  function addSigned(int64 x, int64 y) internal pure returns(int64)
  {
    unchecked {
      int96 res = int96(x) + y;
      require (res >= MIN_32x32 && res <= MAX_32x32, "Overflow");
      return int64(res);
    }
  }

  /**
  * @notice Calculates x - y.
  */
  function sub(uint64 x, uint64 y) internal pure returns (uint64) {
    unchecked {
      require (x > y);
      return x - y;
    }
  }

  function sub(uint x, uint y) internal pure returns (uint) {
    unchecked {
      require (x > y);
      return x - y;
    }
  }

  function subSigned(int64 x, int64 y) internal pure returns (int64) {
    unchecked {
      int128 res = int128(x) - int128(y);
      require (res >= MIN_32x32 && res <= MAX_32x32, "Overflow");
      return int64(res);
    }
  }

  /// @notice Returns the absolute value of the difference
  function absSub(uint64 x, uint64 y) internal pure returns (uint64) {
    unchecked {
      if (x > y) {
        return x - y;
      } else {
        return y - x;
      }
    }
  }

  function absSub(uint x, uint y) internal pure returns (uint) {
    unchecked {
      if (x > y) {
        return x - y;
      } else {
        return y - x;
      }
    }
  }

  /**
  * @notice Calculates x * y rounding down.
  */
  function mult(uint64 x, uint64 y) internal pure returns (uint64) {
    unchecked {
      uint128 res = (uint128(x) * y) >> 32;

      require (res >= 0 && res <= MAX_U32x32, "Overflow");
      return uint64(res);
    }
  }

  function multPerf(uint64 x, uint128 y) internal pure returns (uint160) {
    unchecked {
      uint160 res = uint160((uint256(x) * uint256(y)) >> 32);

      require (res >= 0 && res <= MAX_U128x32, "Overflow");
      return res;
    }
  }

  function multSigned(int64 x, int64 y) internal pure returns (int64) {
    unchecked {
      int128 res = (int128(x) * y) >> 32;

      require (res >= MIN_32x32 && res <= MAX_32x32, "Overflow");
      return int64(res);
    }
  }

  /**
  * @notice Calculates x / y rounding towards zero.
  */
  function div(uint64 x, uint64 y) internal pure returns (uint64) {
    unchecked {
      require (y != 0);

      uint96 res = (uint96(x) << 32) / y;

      require (res <= MAX_U32x32);
      return uint64(res);
    }
  }

  function div128(uint128 x, uint128 y) internal pure returns (uint64) {
    unchecked {
      require (y != 0);

      uint160 res = (uint160(x) << 32) / y;

      require (res <= MAX_U32x32);
      return uint64(res);
    }
  }

  function divSigned(int64 x, int64 y) internal pure returns (int64) {
    unchecked {
      require (y != 0);

      int96 res = (int96(x) << 32) / y;

      require (res >= MIN_32x32 && res <= MAX_32x32, "Overflow");
      return int64(res);
    }
  }

  function adjustAmountDecimals(uint128 amt, int8 decimalAdj) internal pure returns(uint128) {
    if (decimalAdj == 0) return amt;

    unchecked {
      if (decimalAdj < 0) {
        uint8 f = uint8(-decimalAdj);
        return amt / uint128(10 ** f);
      }
      else {
        return amt * uint128(10 ** uint8(decimalAdj));
      }
    }
  }
}