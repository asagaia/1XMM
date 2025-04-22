// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/ERC20Capped.sol)

pragma solidity >= 0.8.20;

import { ERC20CappedAndOwned } from "./erc20cappedandowned.sol";

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
abstract contract ERC20Burnable is ERC20CappedAndOwned {
    /**********
     * Events *
     **********/
    /// @notice The Burnt event is triggered when tokens are burnt
    event Burnt(uint256 amount);

    /**************
     * Properties *
     **************/
    // Private Properties
    uint256 internal _availableTokens;

    /**
     * @notice Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20CappedAndOwned(owner_, name_, symbol_, decimals_) {}

    /**
     * @notice Gets the amount of tokens which remains to be allocated
     */
    function availableTokens() external view returns(uint256) {
        return _availableTokens;
    }

    /**
     * @notice Destroys a `amount` of tokens.
     * @param amount The amount of tokens to be burnt
     *
     * @dev The burn function allows the owner to burn tokens
     * which are available but not allocated.
     */
    function burn(uint256 amount) public virtual;

    /**
     * @notice Destroys a `amount` of tokens.
     * @param account The account to burn from
     * @param amount The amount of tokens to be burnt
     *
     */
    function burnFrom(address account, uint256 amount) public virtual;

    /**
     * @dev See {ERC20-_update}.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20CappedAndOwned) {
        super._update(from, to, value);
        _availableTokens = totalSupply() - circulatingSupply();
    }
}