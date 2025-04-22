// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { IERC20 } from "../interfaces/ierc20.sol";
import { IExchangeable } from "../interfaces/iexchangeable.sol";

abstract contract ERC20Exchangeable is IExchangeable {
    /*************
     * Modifiers *
     *************/
     modifier _onlyOwner {
        require(msg.sender == _owner, "E0");
        _;
    }

    modifier ethDepositIsAllowed {
        require(EthDepositIsAllowed, "E2");
        _;
    }

    modifier ethExchangeIsAllowed {
        require(EthExchangeIsAllowed && EthExchangeRate != 0, "E3");
        _;
    }

    modifier exchangeIsAllowedForToken(address token) {
        require(_tokenIsApproved[token] && _exchangeIsAllowed[token] && _exchangeRates[token] != 0, "E4");
        _;
    }

    modifier tokenIsApproved(address token) {
        require(_tokenIsApproved[token], "E5");
        _;
    }

     /**************
     * Properties *
     **************/
     // Private Properties
     address private _owner;

    // Public properties linked to IExchangeable
    /// @dev The exchange rate represents a real number with 4 digits precision
    bool public EthExchangeIsAllowed;
    bool public EthDepositIsAllowed;
    uint64 public EthExchangeRate;
    uint16 internal _precision = 10_000;

    /// @dev Parameters to manage other token exchanges
    mapping(address tokenAddress => bool) internal _tokenIsApproved;
    mapping(address tokenAddress => uint64) internal _exchangeRates;
    mapping(address tokenAddress => bool) internal _exchangeIsAllowed;

    // Other public Properties
    address[] public ApprovedTokens;
    mapping(address tokenAddress => uint8) internal _approvedTokenDecimals;

    /***************
     * Constructor *
     ***************/
    constructor(address owner_) {
        _owner = owner_;
        EthDepositIsAllowed = false;
        EthExchangeIsAllowed = false;
    }

    /// @notice Sets the change authorization status for ETH to false
    function removeEthExchangeAuthorization() external _onlyOwner {
        EthExchangeIsAllowed = false;
    }

    /// @notice Sets the change authorization status for a token to false
    function removeExchangeAuthorizationForToken(address tokenToBeReceived) external _onlyOwner tokenIsApproved(tokenToBeReceived) {
        _exchangeIsAllowed[tokenToBeReceived] = false;
    }

    /// @notice Sets whether the deposit of ETH against token is allowed or not
    /// @dev The exchange rate is expressed in pips
    function setEthDepositExchangeRate(uint64 exchangeRate) external _onlyOwner {
        EthExchangeRate = exchangeRate;
        EthDepositIsAllowed = true;
    }

    /// @notice Sets the ETH deposit authorization to false
    function removeEthDepositAuthorization() external _onlyOwner {
        EthDepositIsAllowed = false;
    }

    /// @notice Updates the exchange rate between ETH and the Token
    /// @dev The exchange rate is expressed in pips
    function updateEthExchangeRate(uint64 exchangeRate) external _onlyOwner {
        EthExchangeRate = exchangeRate;
        EthExchangeIsAllowed = true;
    }

    /// @notice Updates the exchange rate between a token and our Token
    /// @param  tokenToBeReceived The token to be received in exchange of our Token
    /// @param  exchangeRate The exchange rate, with 4 digits precision (in pips)
    function updateTokenExchangeRate(address tokenToBeReceived, uint64 exchangeRate) external _onlyOwner tokenIsApproved(tokenToBeReceived) {
        _exchangeRates[tokenToBeReceived] = exchangeRate;
        _exchangeIsAllowed[tokenToBeReceived] = true;
    }

    /// @notice Returns the quantity of ETH available for change against Token
    function getAvailableQuantityOfETH() external view returns(uint256) {
        return address(this).balance;
    }

    /// @notice Returns the latest exchange rate associated to the token to be received
    /// @return isAllowed true if the exchange is authorized
    /// @return rate the exchange rate
    function getExchangeInfoForToken(address tokenToBeReceived) external view tokenIsApproved(tokenToBeReceived) returns(bool isAllowed, uint64 rate) {
        isAllowed = _exchangeIsAllowed[tokenToBeReceived];
        rate = _exchangeRates[tokenToBeReceived];
    }

    /// @notice Returns the available quantity of a token to be exchanged
    function getAvailableQuantityOfToken(address tokenToBeReceived) public tokenIsApproved(tokenToBeReceived) returns(uint256 availableQuantity) {
        availableQuantity = 0;

        (bool success , bytes memory res) = tokenToBeReceived.call(abi.encodeWithSelector(IERC20.balanceOf.selector, address(this)));
        if (success) availableQuantity = abi.decode(res, (uint256));
    }

    /// @notice Adds a token which can be traded against our Token
    function addApprovedToken(address token, uint8 decimals) external _onlyOwner {
        require(decimals <= 18, "E105");
        if (_tokenIsApproved[token]) return;

        _tokenIsApproved[token] = true;
        _exchangeIsAllowed[token] = false;

        ApprovedTokens.push(token);
        _approvedTokenDecimals[token] = decimals;
    }

    /// @notice Gets approved tokens
    function getApprovedTokens() external view returns(address[] memory) {
        return ApprovedTokens;
    }
}