// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

interface IOwned {
    /// @notice Emitted when ownership of the contracted is transferred to a new owner
    event OwnerChanged(uint indexed timestamp, address prevOwner, address newOwner);

    /// @notice Returns the current owner of the contract
    function owner() external view returns (address owner);

    /// @notice Changes the ownership of the contract
    /// @param newOwner The address of the new owner
    function changeOwnership(address newOwner) external;
}