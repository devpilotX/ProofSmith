// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Trivial contract. Its only job is to prove forge + solc compile.
contract Trivial {
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }
}
