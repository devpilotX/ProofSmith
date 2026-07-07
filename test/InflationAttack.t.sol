// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {ERC4626Base} from "../src/ERC4626Base.sol";
import {NaiveVault} from "../src/NaiveVault.sol";
import {HardenedVault} from "../src/HardenedVault.sol";

/// The inflation / donation / first-depositor attack.
///
/// Same scenario run against both vaults. The attacker is the first
/// depositor with 1 wei, donates a pile straight into the vault to move
/// the share price, then the victim deposits and the attacker redeems.
/// On the naive vault the victim is robbed. On the hardened vault the
/// attacker cannot profit.
abstract contract InflationAttackBase is Test {
    MockERC20 internal token;
    ERC4626Base internal vault;

    address internal constant ATTACKER = address(0xBAD);
    address internal constant VICTIM = address(0x71C);

    function deployVault(MockERC20 t) internal virtual returns (ERC4626Base);

    function setUp() public {
        token = new MockERC20();
        vault = deployVault(token);
    }

    /// Run the full attack and report the numbers.
    /// returns attacker shares, victim shares, what the attacker pulled
    /// out, and what the victim could pull out after.
    function _runAttack(uint256 atkDeposit, uint256 donation, uint256 victimDeposit)
        internal
        returns (uint256 atkShares, uint256 victimShares, uint256 attackerGot, uint256 victimGot)
    {
        // 1. attacker is first depositor with a dust amount
        token.mint(ATTACKER, atkDeposit);
        vm.startPrank(ATTACKER);
        token.approve(address(vault), atkDeposit);
        atkShares = vault.deposit(atkDeposit, ATTACKER);
        // 2. attacker donates straight into the vault, no shares minted
        token.mint(ATTACKER, donation);
        token.transfer(address(vault), donation);
        vm.stopPrank();

        // 3. victim deposits for real
        token.mint(VICTIM, victimDeposit);
        vm.startPrank(VICTIM);
        token.approve(address(vault), victimDeposit);
        victimShares = vault.deposit(victimDeposit, VICTIM);
        vm.stopPrank();

        // 4. attacker redeems everything their shares are worth
        vm.prank(ATTACKER);
        attackerGot = vault.redeem(atkShares, ATTACKER, ATTACKER);

        // 5. victim tries to get out whatever is left for them
        if (victimShares != 0) {
            vm.prank(VICTIM);
            victimGot = vault.redeem(victimShares, VICTIM, VICTIM);
        }
    }
}

contract NaiveInflationAttackTest is InflationAttackBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new NaiveVault(IERC20(address(t)));
    }

    /// The headline: on the naive vault the attacker steals the victim's
    /// whole deposit. 1 wei in, a 10,000-token donation, victim deposits
    /// 10,000 and gets zero shares, attacker walks with the lot.
    function test_inflationAttackStealsDeposit() public {
        uint256 atkDeposit = 1; // 1 wei
        uint256 donation = 10_000 ether; // 10,000 tokens donated to inflate
        uint256 victimDeposit = 10_000 ether; // the victim's 10,000 tokens

        (uint256 atkShares, uint256 victimShares, uint256 attackerGot, uint256 victimGot) =
            _runAttack(atkDeposit, donation, victimDeposit);

        emit log_named_uint("attacker shares from 1 wei  ", atkShares);
        emit log_named_uint("victim shares for 10000e18  ", victimShares);
        emit log_named_uint("attacker spent (dep+donate) ", atkDeposit + donation);
        emit log_named_uint("attacker got back           ", attackerGot);
        emit log_named_uint("victim got back             ", victimGot);

        uint256 attackerSpent = atkDeposit + donation;

        // the victim's deposit rounded down to zero shares
        assertEq(victimShares, 0, "victim should be rounded to zero shares");
        assertEq(victimGot, 0, "victim recovers nothing");

        // the attacker profited, and the profit is exactly the victim's deposit
        assertGt(attackerGot, attackerSpent, "attacker should profit");
        assertEq(attackerGot - attackerSpent, victimDeposit, "attacker profit == stolen victim deposit");
    }
}

contract HardenedInflationAttackTest is InflationAttackBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new HardenedVault(IERC20(address(t)), 3); // virtual shares = 10^3
    }

    /// Same attack, hardened vault. The victim still gets shares and the
    /// attacker comes out behind. The donation is partly eaten by the
    /// virtual shares, so the attack is a loss for the attacker.
    function test_hardenedResistsInflation() public {
        uint256 atkDeposit = 1;
        uint256 donation = 10_000 ether;
        uint256 victimDeposit = 10_000 ether;

        (uint256 atkShares, uint256 victimShares, uint256 attackerGot, uint256 victimGot) =
            _runAttack(atkDeposit, donation, victimDeposit);

        emit log_named_uint("attacker shares from 1 wei  ", atkShares);
        emit log_named_uint("victim shares for 10000e18  ", victimShares);
        emit log_named_uint("attacker spent (dep+donate) ", atkDeposit + donation);
        emit log_named_uint("attacker got back           ", attackerGot);
        emit log_named_uint("victim got back             ", victimGot);

        uint256 attackerSpent = atkDeposit + donation;

        // victim is not zeroed out
        assertGt(victimShares, 0, "victim should still receive shares");
        // attacker cannot profit
        assertLe(attackerGot, attackerSpent, "attacker must not profit on hardened vault");
        // victim recovers almost all of their deposit
        assertGe(victimGot, victimDeposit * 99 / 100, "victim should recover most of the deposit");
    }

    /// Fuzz the attack across many parameter choices. The attacker never
    /// profits on the hardened vault. This is TESTED, not a proof. Halmos
    /// could not prove it (the nonlinear math times out), so this 20,000-run
    /// fuzz plus the worked example is the evidence we have.
    /// forge-config: default.fuzz.runs = 20000
    function testFuzz_hardenedAttackerNeverProfits(uint256 atkDeposit, uint256 donation, uint256 victimDeposit)
        public
    {
        atkDeposit = bound(atkDeposit, 1, 1e27);
        donation = bound(donation, 0, 1e27);
        victimDeposit = bound(victimDeposit, 0, 1e27);

        (,, uint256 attackerGot,) = _runAttack(atkDeposit, donation, victimDeposit);
        assertLe(attackerGot, atkDeposit + donation, "attacker profited on hardened vault");
    }
}
