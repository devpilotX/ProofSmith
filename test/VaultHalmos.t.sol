// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "../src/IERC20.sol";

/// Halmos symbolic proofs of P1/P2/P3 for the SAFE vault.
/// Run: python -m halmos --contract VaultHalmosTest
///
/// All amounts are symbolic and bounded below 2^128 so sums cannot
/// overflow 2^256 (overflow paths revert and are not the property under
/// test). Two fixed, distinct users `alice` and `bob` model "different
/// users"; that is enough to express tampering and solvency since only
/// these addresses ever hold a vault balance in the test.
contract VaultHalmosTest is Test {
    MockERC20 token;
    Vault vault;

    address constant alice = address(0xA11CE);
    address constant bob = address(0xB0B);

    function setUp() public {
        token = new MockERC20();
        vault = new Vault(IERC20(address(token)));
    }

    function _deposit(address user, uint256 amt) internal {
        token.mint(user, amt);
        vm.startPrank(user);
        token.approve(address(vault), amt);
        vault.deposit(amt);
        vm.stopPrank();
    }

    // P2 no theft: if a withdraw succeeds, the user took out no more than
    // they deposited, and cannot end with more tokens than they started.
    function check_P2_noTheft(uint256 depositAmt, uint256 withdrawAmt) public {
        vm.assume(depositAmt < 2 ** 128);
        token.mint(alice, depositAmt);
        uint256 tokStart = token.balanceOf(alice);
        vm.startPrank(alice);
        token.approve(address(vault), depositAmt);
        vault.deposit(depositAmt);
        vault.withdraw(withdrawAmt); // reverts unless withdrawAmt <= depositAmt
        vm.stopPrank();
        assert(withdrawAmt <= depositAmt);
        assert(token.balanceOf(alice) <= tokStart);
        assert(vault.balanceOf(alice) == depositAmt - withdrawAmt);
    }

    // P1 solvency preserved by a deposit from a reachable state.
    function check_P1_solvency_deposit(uint256 a0, uint256 b0, uint256 amt, bool who) public {
        vm.assume(a0 < 2 ** 128);
        vm.assume(b0 < 2 ** 128);
        vm.assume(amt < 2 ** 128);
        _deposit(alice, a0);
        _deposit(bob, b0);
        _deposit(who ? alice : bob, amt);
        assert(token.balanceOf(address(vault)) >= vault.balanceOf(alice) + vault.balanceOf(bob));
    }

    // P1 solvency preserved by a withdraw from a reachable state.
    function check_P1_solvency_withdraw(uint256 a0, uint256 b0, uint256 amt, bool who) public {
        vm.assume(a0 < 2 ** 128);
        vm.assume(b0 < 2 ** 128);
        _deposit(alice, a0);
        _deposit(bob, b0);
        vm.prank(who ? alice : bob);
        vault.withdraw(amt); // reverts if amt exceeds the actor's balance
        assert(token.balanceOf(address(vault)) >= vault.balanceOf(alice) + vault.balanceOf(bob));
    }

    // P3 no tampering: alice's deposit cannot change bob's balances.
    function check_P3_noTampering_deposit(uint256 bobInit, uint256 aliceAmt) public {
        vm.assume(bobInit < 2 ** 128);
        vm.assume(aliceAmt < 2 ** 128);
        _deposit(bob, bobInit);
        uint256 bobVault = vault.balanceOf(bob);
        uint256 bobTok = token.balanceOf(bob);
        _deposit(alice, aliceAmt);
        assert(vault.balanceOf(bob) == bobVault);
        assert(token.balanceOf(bob) == bobTok);
    }

    // P3 no tampering: alice's withdraw cannot change bob's balances.
    function check_P3_noTampering_withdraw(uint256 bobInit, uint256 aliceAmt, uint256 aliceW) public {
        vm.assume(bobInit < 2 ** 128);
        vm.assume(aliceAmt < 2 ** 128);
        _deposit(bob, bobInit);
        _deposit(alice, aliceAmt);
        uint256 bobVault = vault.balanceOf(bob);
        uint256 bobTok = token.balanceOf(bob);
        vm.prank(alice);
        vault.withdraw(aliceW); // reverts if aliceW exceeds alice's balance
        assert(vault.balanceOf(bob) == bobVault);
        assert(token.balanceOf(bob) == bobTok);
    }
}
