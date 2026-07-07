// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "./IERC20.sol";

/// Minimal safe vault for a single ERC-20.
///
/// Safety comes from ordering external token calls against internal
/// accounting so there is never a window where a user's recorded
/// balance overstates what they are owed:
///   deposit:  pull tokens in (external call) THEN credit.
///   withdraw: debit THEN send tokens out (external call).
/// So even a token that calls back into this contract during a transfer
/// cannot over-withdraw: by the time the external call runs, the
/// caller's balance is already reduced.
contract Vault {
    IERC20 public immutable token;
    mapping(address => uint256) public balanceOf;

    constructor(IERC20 _token) {
        token = _token;
    }

    function deposit(uint256 amount) external {
        // interaction first: tokens must actually arrive before we credit
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "transferFrom failed"
        );
        // effect after
        balanceOf[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        // check
        require(balanceOf[msg.sender] >= amount, "insufficient");
        // effect before interaction
        balanceOf[msg.sender] -= amount;
        // interaction last
        require(token.transfer(msg.sender, amount), "transfer failed");
    }
}
