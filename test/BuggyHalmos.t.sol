// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrantToken} from "../src/ReentrantToken.sol";
import {BuggyVault} from "../src/BuggyVault.sol";
import {Attacker} from "./Reentrancy.t.sol";
import {IERC20} from "../src/IERC20.sol";

/// Symbolic search for a reentrancy counterexample on the BUGGY vault,
/// using the callback token and an attacker that re-enters once. Halmos
/// explores symbolic victim and attacker amounts. The no-theft / solvency
/// property is expected to FAIL with a concrete counterexample.
/// Run: python -m halmos --contract BuggyHalmosTest
contract BuggyHalmosTest is Test {
    ReentrantToken token;
    BuggyVault buggy;
    Attacker attacker;
    address victim;

    function setUp() public {
        victim = address(0xBEEF);
        token = new ReentrantToken();
        buggy = new BuggyVault(IERC20(address(token)));
        attacker = new Attacker(token);
    }

    // P1/P2 on the buggy vault under reentrancy. EXPECTED TO FAIL.
    function check_P1_solvency_buggy(uint256 victimDep, uint256 atkUnit) public {
        vm.assume(victimDep < 2 ** 96);
        vm.assume(atkUnit < 2 ** 96);
        vm.assume(0 < atkUnit);
        vm.assume(atkUnit <= victimDep);

        token.mint(victim, victimDep);
        vm.startPrank(victim);
        token.approve(address(buggy), victimDep);
        buggy.deposit(victimDep);
        vm.stopPrank();

        token.mint(address(attacker), atkUnit);
        attacker.attack(address(buggy), atkUnit, 1); // one re-entry

        // solvency: vault tokens must cover all recorded balances
        assert(
            token.balanceOf(address(buggy))
                >= buggy.balanceOf(victim) + buggy.balanceOf(address(attacker))
        );
    }
}
