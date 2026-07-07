// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Trivial} from "../src/Trivial.sol";

contract TrivialTest is Test {
    Trivial t;

    function setUp() public {
        t = new Trivial();
    }

    /// Foundry fuzz version (TESTED).
    function testFuzz_add_commutative(uint256 a, uint256 b) public view {
        vm.assume(a <= type(uint256).max - b);
        assertEq(t.add(a, b), t.add(b, a));
    }

    /// Halmos symbolic version (PROVEN if it passes).
    function check_add_commutative(uint256 a, uint256 b) public view {
        vm.assume(a <= type(uint256).max - b);
        assertEq(t.add(a, b), t.add(b, a));
    }
}
