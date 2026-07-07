// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";

interface ITokenReceiver {
    function tokensReceived(address from, uint256 amount) external;
}

/// ERC-20 with an ERC-777-style receive hook on `transfer`. After moving
/// balances it notifies a contract recipient. This is a real, legitimate
/// token feature, and it is the lever that turns a checks-effects bug in
/// a consumer into a drain. The hook is only on `transfer` (used by the
/// vault's withdraw), not on `transferFrom` (used by deposit), so the
/// deposit path stays simple.
contract ReentrantToken is IERC20 {
    string public name = "Reentrant";
    string public symbol = "RENT";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        _notify(to, msg.sender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function _notify(address to, address from, uint256 amount) internal {
        if (to.code.length > 0) {
            // best-effort hook: ignore a missing implementation, but let
            // a genuine revert inside the hook bubble up.
            try ITokenReceiver(to).tokensReceived(from, amount) {} catch {}
        }
    }
}
