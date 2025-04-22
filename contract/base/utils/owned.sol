// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { IOwned } from  "../../interfaces/iowned.sol";

abstract contract Owned is IOwned {
     /*****************
     * The modifiers *
     *****************/
    modifier onlyOwner {
        require(msg.sender == _owner, "E0");
        _;
    }

    /**************
     * Properties *
     **************/
    // Private Properties
    address internal _owner;

    /**
     * @dev Sets the values for {owner}.
     */
    constructor(address owner_) {
        _owner = owner_;
    }

    /// @dev Returns the current owner of the contract
    function owner() external view returns (address) {
        return _owner;
    }

    /// @dev Changes the ownership of the contract
    /// @param newOwner The new owner
    function changeOwnership(address newOwner) external onlyOwner {
        _owner = newOwner;
        emit OwnerChanged(block.timestamp, msg.sender, newOwner);
    }
}