// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";

/// Same interface as Vault, but withdraw is reentrancy-vulnerable.
///
/// The bug: it reads the caller's balance into a local, sends tokens out
/// (external call), and only then writes the new balance using the STALE
/// local. If the token hands control back to the caller during the
/// transfer, the caller can re-enter withdraw while the recorded balance
/// is still the old value, pull tokens again, and on unwind each frame
/// writes `staleBalance - amount` (>= 0, so no underflow revert). The
/// attacker walks out with far more than they deposited and drains other
/// users' funds. This is the classic DAO-style reentrancy.
///
/// With a plain ERC-20 (no transfer hook) this contract behaves
/// identically to the safe one, which is exactly why a symbolic/ fuzz
/// check that assumes a plain token will not flag it.
contract BuggyVault {
    IERC20 public immutable token;
    mapping(address => uint256) public balanceOf;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount) external {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transferFrom failed"
        );
        balanceOf[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        uint256 bal = balanceOf[msg.sender]; // read (cached)
        require(bal >= amount, "insufficient");
        // BUG: interaction before effect, and the effect uses the stale
        // cached balance, so reentrant calls all see the old value.
        require(token.transfer(msg.sender, amount), "transfer failed");
        balanceOf[msg.sender] = bal - amount;
    }
}
