// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

interface IERC20 {
    /// @notice Emitted when `value` tokens are moved from one account to another
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when the allowance of a `spender` for an `owner` is set
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns the value of tokens in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens owned by account
    /// @param account The address of the account
    function balanceOf(address account) external view returns(uint256);

    /// @notice Transfers tokens
    /// @param to The recipient wallet
    /// @param value The amount to be transferred
    // Throws Transfer event
    function transfer(address to, uint256 value) external returns(bool);

    /// @notice Returns the remaining number of tokens that `spender` will be
    /// allowed to spend on behalf of `owner` through {transferFrom}. This is
    /// zero by default.
    /// @param owner The wallet which has given the allowance
    /// @param spender The spender
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets a `value` amount of tokens as the allowance of `spender` over the
    /// caller's tokens.
    /// @param spender The spender
    /// @param value The approved amount
    function approve(address spender, uint256 value) external returns (bool);

    /// @notice Moves a `value` amount of tokens from `from` to `to` using the
    /// allowance mechanism. `value` is then deducted from the caller's
    /// allowance.
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}