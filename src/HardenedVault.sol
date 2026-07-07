// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";
import {ERC4626Base} from "./ERC4626Base.sol";

/// The HARDENED vault. Same vault, same donation-readable totalAssets().
/// The only change is the conversion math: it adds a virtual offset.
///
/// shares = assets * (totalSupply + 10^offset) / (totalAssets + 1)
/// assets = shares * (totalAssets + 1) / (totalSupply + 10^offset)
///
/// This is the OpenZeppelin mitigation. There is no empty-vault special
/// case, because the +10^offset and +1 keep the denominator >= 1 and put
/// virtual shares and a virtual asset between the first real depositor and
/// the price. Those virtual shares belong to nobody, so any donation an
/// attacker makes is partly captured by the void. That is what flips the
/// attack from profitable to a guaranteed loss for the attacker.
///
/// offset is fixed at construction. Bigger offset = stronger protection
/// (the attacker must burn 10^offset times the value they hope to steal).
contract HardenedVault is ERC4626Base {
    uint8 public immutable offset;
    uint256 public immutable virtualShares; // 10^offset
    uint256 public constant VIRTUAL_ASSETS = 1;

    constructor(IERC20 _asset, uint8 _offset) ERC4626Base(_asset, "Hardened Vault Share", "hvVAULT") {
        offset = _offset;
        virtualShares = 10 ** uint256(_offset);
    }

    function convertToShares(uint256 assets) public view override returns (uint256) {
        return _mulDivDown(assets, totalSupply + virtualShares, totalAssets() + VIRTUAL_ASSETS);
    }

    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return _mulDivDown(shares, totalAssets() + VIRTUAL_ASSETS, totalSupply + virtualShares);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        return _mulDivUp(shares, totalAssets() + VIRTUAL_ASSETS, totalSupply + virtualShares);
    }

    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return _mulDivUp(assets, totalSupply + virtualShares, totalAssets() + VIRTUAL_ASSETS);
    }
}
