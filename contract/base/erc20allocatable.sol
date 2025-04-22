// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.20;

import { DurationUnits } from  "../enums.sol";
import { ERC20Vested } from "./utils/erc20vested.sol";
import { ERC20Burnable } from "./utils/erc20burnable.sol";

import { IERC20 } from "../interfaces/ierc20.sol";
import { IERC20Errors } from "../interfaces/ierc20errors.sol";

import { IGetCCIPAdmin } from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IGetCCIPAdmin.sol";
import { IBurnMint } from "../interfaces/iburnmint.sol";

contract ERC20Allocatable is ERC20Vested, IGetCCIPAdmin, IBurnMint {
    /// @dev Modifier that checks if the msg.sender is the ccipAdmin.
    // This function shall be called only when tokens are transferred from one chain to another.
    // Owner has no right to mint.
    modifier onlyMinter() {
        require(msg.sender == _ccipAdmin, "Denied");
        _;
    }

    /**************
     * Properties *
     **************/
    // The address of the CCIP Admin
    address internal _ccipAdmin;

    /**********
     * Events *
     **********/
    /// @notice Event emitted when CCIP Admin is transferred to a new address
    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    /// @notice The Allocated event is triggered when Owner allocates some token to a beneficiary
    event Allocated(address indexed beneficiary, uint256 amount);

    /***************
     * Constructor *
     ***************/
    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20Vested(owner_, name_, symbol_, decimals_)
    { }

    /// @notice Allocates a number of token to a beneficiary
    /// @param to The beneficiary
    /// @param amount The amount to allocate
    /// @param cliffDuration The duration of the cliff
    /// @param cliffDurationUnit The unit of the cliff duration
    /// @param upfrontRelease The amount released when cliff period ends
    /// @param vestingDuration The duration of the vesting
    /// @param vestingDurationUnit The unit of the vesting duration
    function allocateWithVesting(address to, uint256 amount, uint16 cliffDuration, DurationUnits cliffDurationUnit, uint8 upfrontRelease, uint16 vestingDuration, 
    DurationUnits vestingDurationUnit) external onlyOwner {
        uint vestingStart = _addDuration(block.timestamp, cliffDuration, cliffDurationUnit);
        allocateWithVesting(to,amount, vestingStart, upfrontRelease, vestingDuration, vestingDurationUnit);
    }

    /// @notice Allocates a number of token to a beneficiary
    /// @param to The beneficiary
    /// @param amount The amount to allocate
    /// @param cliffEnd The timsestamp of cliff end
    /// @param upfrontRelease The amount released when cliff period ends
    /// @param vestingDuration The duration of the vesting
    /// @param vestingDurationUnit The unit of the vesting duration
    function allocateWithVesting(address to, uint256 amount, uint cliffEnd, uint8 upfrontRelease, uint16 vestingDuration, DurationUnits vestingDurationUnit) 
    public onlyOwner {
        allocate(to, amount);

        if (upfrontRelease > 100) upfrontRelease = 100;
        _createVestingSchedule(to,upfrontRelease, cliffEnd, vestingDuration, vestingDurationUnit, amount);
    }

    /// @notice Allocates a number of token to a beneficiary
    /// @param to The beneficiary
    /// @param amount The amount
    function allocate(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "E103");
        if (to == address(this)) {
            if (amount + totalSupply() > _cap) revert IERC20Errors.ERC20AllocationFailed(amount, _cap);
            _update(address(0), to, amount);
        } else {
            if (amount > _availableTokens) revert IERC20Errors.ERC20AllocationFailed(amount, totalSupply());
            _update(address(this), to, amount);
        }
        
        emit Allocated(to, amount);
    }

    /// @notice Allocates a number of token to a beneficiary
    /// @param to The beneficiaries
    /// @param amount The amounts
    function massAllocation(address[] memory to, uint256[] memory amount) external onlyOwner {
        require(to.length == amount.length, "E104");

        for (uint i = 0; i < to.length; i++) {
            allocate(to[i], amount[i]);
        }
    }

    /// @notice Returns the token administrator's address
    function getCCIPAdmin() external view returns(address) {
        return _ccipAdmin;
    }

    /// @notice Transfers the CCIPAdmin role to a new address
    /// @dev only the owner can call this function, NOT the current ccipAdmin, and 1-step ownership transfer is used.
    /// @param newAdmin The address to transfer the CCIPAdmin role to. Setting to address(0) is a valid way to revoke
    /// the role
    function setCCIPAdmin(address newAdmin) public onlyOwner {
        emit CCIPAdminTransferred(_ccipAdmin, newAdmin);
        _ccipAdmin = newAdmin;
    }

    /*******************
     *  IBurnMintImpl  *
     *******************/
    /// @notice Mints 'value' amount of tokens when a cross-chain transfer is performed
    /// @dev This function can only be called by the ccipAdmin.
    /// @param account The account to receive the tokens
    /// @param value The amount of tokens to be minted
    function mint(address account, uint256 value) public onlyMinter {
        if (totalSupply() + value > _cap) revert ERC20ExceededCap(totalSupply(), _cap);
        _mint(account, value);
        _availableTokens = totalSupply() - circulatingSupply();

        emit Minted(account, _ccipAdmin, value);
    }

    /// @inheritdoc ERC20Burnable
    function burn(uint256 amount) public override(ERC20Burnable) {
        // Owner cannot burn non-allocated tokens
        if (msg.sender == _owner) {
            require(amount <= balanceOf(address(this)), "E1");
            super._update(address(this), address(0), amount);
        }
        else {
            super._burn(msg.sender, amount);
        }
        
        emit Burnt(amount);
    }

    /// @notice IBurnMint
    function burn(address account, uint256 amount) public override(IBurnMint) {
        if (account == msg.sender) burn(amount);
        else burnFrom(account, amount);
    }

    /// @inheritdoc ERC20Burnable
    function burnFrom(address account, uint256 amount) public override(ERC20Burnable, IBurnMint) {
        _spendAllowance(account, msg.sender, amount);

        super._burn(account, amount);
        emit Burnt(amount);
    }

    /********************/
}