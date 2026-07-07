// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";

/// Shared ERC-4626-style logic. Everything that is identical between the
/// naive vault and the hardened vault lives here: the ERC-20 share
/// accounting, deposit/mint/withdraw/redeem, and access control.
///
/// The ONLY thing a subclass changes is the four conversion functions.
/// That is the whole experiment. If the naive vault gets robbed and the
/// hardened one does not, the difference is exactly that math and nothing
/// else.
///
/// totalAssets() reads the live token balance of the vault. That is the
/// naive, donation-readable definition on purpose: a direct token
/// transfer into the vault moves totalAssets without minting shares. The
/// hardened vault keeps this same totalAssets and defends with a virtual
/// offset in the conversion instead, which is the OpenZeppelin approach.
abstract contract ERC4626Base {
    IERC20 public immutable asset;

    // --- ERC-20 accounting for the SHARES the vault issues ---
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(IERC20 _asset, string memory _name, string memory _symbol) {
        asset = _asset;
        name = _name;
        symbol = _symbol;
    }

    // --- asset side ---

    /// Live token balance. Donations (direct transfers in) show up here
    /// with no shares minted. That is the lever the inflation attack pulls.
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // --- conversions: the only thing subclasses change ---
    // convertToShares / convertToAssets round DOWN (used by deposit/redeem).
    function convertToShares(uint256 assets) public view virtual returns (uint256);
    function convertToAssets(uint256 shares) public view virtual returns (uint256);
    // previewMint / previewWithdraw round UP (the vault-favoring direction).
    function previewMint(uint256 shares) public view virtual returns (uint256);
    function previewWithdraw(uint256 assets) public view virtual returns (uint256);

    // deposit and redeem use the round-down conversions.
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    // --- ERC-4626 actions ---

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = previewDeposit(assets); // round DOWN: user may get fewer shares
        require(asset.transferFrom(msg.sender, address(this), assets), "ASSET_TRANSFER_FROM_FAILED");
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = previewMint(shares); // round UP: user pays a touch more
        require(asset.transferFrom(msg.sender, address(this), assets), "ASSET_TRANSFER_FROM_FAILED");
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        shares = previewWithdraw(assets); // round UP: user burns a touch more
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);
        _burn(owner, shares);
        require(asset.transfer(receiver, assets), "ASSET_TRANSFER_FAILED");
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        if (msg.sender != owner) _spendAllowance(owner, msg.sender, shares);
        assets = previewRedeem(shares); // round DOWN: user gets a touch less
        _burn(owner, shares);
        require(asset.transfer(receiver, assets), "ASSET_TRANSFER_FAILED");
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // --- ERC-20 on the shares (owner/approved only) ---

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount; // checked: reverts if caller lacks shares
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // --- internals ---

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 allowed = allowance[owner][spender];
        if (allowed != type(uint256).max) {
            allowance[owner][spender] = allowed - amount; // checked: reverts if not enough allowance
        }
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount; // checked: reverts if owner lacks shares
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    // --- rounding helpers ---
    // Inputs are bounded in the proofs so a*b cannot overflow 2^256.

    function _mulDivDown(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return (a * b) / c;
    }

    function _mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        // ceil(a*b/c). For a*b == 0 this is 0 since c >= 1.
        return (a * b + (c - 1)) / c;
    }
}
