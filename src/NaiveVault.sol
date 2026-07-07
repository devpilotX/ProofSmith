// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";
import {ERC4626Base} from "./ERC4626Base.sol";

/// The NAIVE vault. Standard share math, no protection.
///
/// shares = assets * totalSupply / totalAssets   (and the inverse)
///
/// When the vault is empty it mints shares 1:1. That first-depositor 1:1
/// rule plus a donation-readable totalAssets() is the whole vulnerability.
/// An attacker mints 1 share for 1 wei, donates a pile of the asset to
/// move totalAssets, and the next depositor's shares round down toward 0.
contract NaiveVault is ERC4626Base {
    constructor(IERC20 _asset) ERC4626Base(_asset, "Naive Vault Share", "nvVAULT") {}

    function convertToShares(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply;
        // empty vault: 1:1. otherwise scale by the current price, round down.
        return supply == 0 ? assets : _mulDivDown(assets, supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : _mulDivDown(shares, totalAssets(), supply);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply;
        // assets needed to mint `shares`, round up.
        return supply == 0 ? shares : _mulDivUp(shares, totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply;
        // shares needed to pull out `assets`, round up.
        return supply == 0 ? assets : _mulDivUp(assets, supply, totalAssets());
    }
}
