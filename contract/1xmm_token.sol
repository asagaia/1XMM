// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { IERC20Errors } from "./interfaces/ierc20errors.sol";
import { IERC20 } from "./interfaces/ierc20.sol";

import { ERC20Allocatable } from "./base/erc20allocatable.sol";
import { ERC20Exchangeable } from "./base/erc20exchangeable.sol";

contract OneXMM is ERC20Allocatable, ERC20Exchangeable {
    modifier isApproved(address account) {
        require(_approvedDepositors[account], "Not Approved");
        _;
    }

    /**********
     * Events *
     **********/
    event DepositorStatusChanged(address indexed account, bool status);
    event Deposited(address indexed from, uint256 amountETH, uint256 amountToken);
    event ChangedBack(address indexed beneficiary, uint256 amountTokens);
    event ChangedBackFor(address indexed beneficiary, address tokenReceived, uint256 amount);
    event Withdrawn(address indexed from, uint256 amount);   

    /**************
     * Properties *
     **************/
    mapping(address account => bool) private _approvedDepositors;

    /**
     * @dev Constructor
     * @param symbol_ The symbol of the token
     * @param name_ The name of the token
     */
    constructor(string memory symbol_, string memory name_)
        ERC20Allocatable(msg.sender, name_, symbol_, 18)
        ERC20Exchangeable(msg.sender) payable { }

    receive() external payable {
        emit Deposited(msg.sender, msg.value, 0);
    }

    /// @notice Adds an approved depositor who will be able to deposit ETH against Token
    function changeDepositorStatus(address account, bool status) external onlyOwner {
        _approvedDepositors[account] = status;
        emit DepositorStatusChanged(account, status);
    }

    /// @notice Enables a user to deposit ETH and receive Tokens in exchange
    /// @dev The conversion rate applies at a fixed rate, updated by Owner
    function depositEther() external payable ethDepositIsAllowed isApproved(msg.sender) returns(uint256 amountToken) {
        uint256 amountETH = msg.value;
        if (amountETH == 0) return 0;

        amountToken = uint256((amountETH * uint256(EthExchangeRate)) / uint256(_precision));
        
        if (amountToken > _availableTokens) {
            // We compute the number of ETH corresponding to the amount of tokens available
            amountETH = (_availableTokens * uint256(_precision)) / uint256(EthExchangeRate);
            amountToken = _availableTokens;

            address payable receiver = payable(msg.sender);
            // We transfer back extra ETH to the msg.sender
            receiver.call{value:msg.value - amountETH}("");
        }

        _update(address(this), msg.sender, amountToken);

        emit Deposited(msg.sender, amountETH, amountToken);
        emit Allocated(msg.sender, amountToken);
    }

    /// @notice Enables owner to send back some tokens to the Token contract
    function ownerTransfersBack(uint256 amount) external onlyOwner {
        if (amount > balanceOf(_owner)) revert IERC20Errors.ERC20InsufficientBalance(_owner, balanceOf(_owner), amount);
        _update(_owner, address(this), amount);
    }

    /// @notice Enables a user to sell back an amount of Tokens against ETH
    /// if there is enough ETH available, and if the change is authorized.
    /// @dev Sold-back tokens are automatically burnt.
    /// @param amountToken The amount of tokens to be exchanged
    function sellBack(uint128 amountToken) external ethExchangeIsAllowed {
        if (balanceOf(msg.sender) < uint256(amountToken)) revert IERC20Errors.ERC20InsufficientBalance(msg.sender, balanceOf(msg.sender), amountToken);
        
        uint256 amt256 = uint256(amountToken);
        uint256 amountETH = (amt256 * uint256(_precision)) / uint256(EthExchangeRate);
        uint256 availableQuantityOfETH = address(this).balance;

        if (amountETH > availableQuantityOfETH) {
            amountETH = availableQuantityOfETH;
            amountToken = uint128((amountETH * uint256(EthExchangeRate)) / uint256(_precision));
        }
        
        payable(msg.sender).call{value:amountETH}("");
        
        // Now we burn the tokens
        burn(amountToken);

        emit ChangedBack(msg.sender, amountETH);
        emit Withdrawn(msg.sender, amountToken);
    }

    /// @notice Enables a user to sell back an amount of Tokens against a preferred token
    /// if there is enough token available, and if the change is authorized.
    /// @dev Sold-back tokens are automatically burnt.
    /// @param amountToken The amount of tokens to be exchanged
    /// @param tokenToBeReceived The address of the token to be exchanged for
    function sellBackAgainst(uint128 amountToken, address tokenToBeReceived) external exchangeIsAllowedForToken(tokenToBeReceived) {
        if (balanceOf(msg.sender) < uint256(amountToken)) revert IERC20Errors.ERC20InsufficientBalance(msg.sender, balanceOf(msg.sender), amountToken);

        uint8 decimalAdjust = 18 - _approvedTokenDecimals[tokenToBeReceived];
        uint256 amt256 = uint256(amountToken);

        uint256 amountExpectedToken = (amt256 * uint256(_precision)) / uint256(_exchangeRates[tokenToBeReceived]);
        if (decimalAdjust != 0) amountExpectedToken /= (10 ** decimalAdjust);
        uint256 availableQuantity = getAvailableQuantityOfToken(tokenToBeReceived);

        // We make sure that the available quantity of expected token is bigger than the requested amount of expected token
        if (amountExpectedToken > availableQuantity) {
            amountExpectedToken = availableQuantity;
            // We adjust down the quantity of token to be delivered
            amountToken = uint128((amountExpectedToken * uint256(_exchangeRates[tokenToBeReceived])) / uint256(_precision));
        }
        
        // We transfer the expected to token to msg.sender
        // Then, we adjust msg.sender's balance
        IERC20(tokenToBeReceived).transfer(msg.sender, amountExpectedToken);
        
        // Now we burn the tokens
        burn(amountToken);

        emit ChangedBackFor(msg.sender, tokenToBeReceived, amountExpectedToken);
        emit Withdrawn(msg.sender, amountToken);
    }

    /// @notice Enables the Owner to buy back tokens from a user, in exchange of ETH and at a specified rate
    /// @param from The beneficiary
    /// @param amountToken The amount of tokens
    /// @param rate The conversion rate
    function buyBack(address payable from, uint128 amountToken, uint64 rate) external onlyOwner {
        if (from == address(0)) revert IERC20Errors.ERC20InvalidReceiver(from);
        if (balanceOf(from) < uint256(amountToken)) revert IERC20Errors.ERC20InsufficientBalance(msg.sender, balanceOf(msg.sender), amountToken);

        uint256 availableQuantityOfETH = address(this).balance;
        require (availableQuantityOfETH != 0, "E106");

        uint256 amountETH = (uint256(amountToken) * uint256(_precision)) / uint256(rate); 

        // We make sure that the available quantity of ETH is bigger than the expected ETH amount
        // If not, we adjust down the quantity of token to be withdrawn
        if (amountETH > availableQuantityOfETH) {
            amountETH = availableQuantityOfETH;
            amountToken = uint128((amountETH * uint256(rate)) / uint256(_precision));
        }

        // We check the allowance first
        // If allowance is not enough, it triggers an error
        _spendAllowance(from, _owner, amountToken);

        from.call{value:amountETH}("");
        _update(from, address(this), amountToken); // In this case, we don't burn the tokens; tokens can be reallocated.

        emit ChangedBack(from, amountETH);
        emit Withdrawn(from, amountToken);
    }
}