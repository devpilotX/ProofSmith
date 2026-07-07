// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {ERC4626Base} from "../src/ERC4626Base.sol";
import {NaiveVault} from "../src/NaiveVault.sol";
import {HardenedVault} from "../src/HardenedVault.sol";

/// Halmos symbolic checks for I1-I4 and the inflation property INF.
/// Run:
///   python -m halmos --contract NaiveVaultHalmosTest
///   python -m halmos --contract HardenedVaultHalmosTest
///
/// Bounds: every symbolic amount is assumed below a stated power of two so
/// that a*b cannot overflow 2^256 (overflowing inputs revert and are out
/// of scope). PROVEN means Halmos found no counterexample inside those
/// bounds. It is not a claim about the full uint256 range.
abstract contract VaultHalmosBase is Test {
    MockERC20 internal token;
    ERC4626Base internal vault;

    address internal constant alice = address(0xA11CE);
    address internal constant bob = address(0xB0B);
    address internal constant attacker = address(0xBAD);
    address internal constant victim = address(0x71C);

    function deployVault(MockERC20 t) internal virtual returns (ERC4626Base);

    function setUp() public {
        token = new MockERC20();
        vault = deployVault(token);
    }

    function _deposit(address who, uint256 amt) internal returns (uint256) {
        token.mint(who, amt);
        vm.startPrank(who);
        token.approve(address(vault), amt);
        uint256 s = vault.deposit(amt, who);
        vm.stopPrank();
        return s;
    }

    // I1 Solvency: after a deposit into an empty vault, the vault holds at
    // least the redeem value of every share.
    function check_I1_solvency(uint256 dep) public {
        vm.assume(dep < 2 ** 64);
        _deposit(alice, dep);
        assert(vault.totalAssets() >= vault.convertToAssets(vault.totalSupply()));
    }

    // I2 No round-trip profit: from a priced vault, deposit then redeem
    // returns no more than was put in.
    function check_I2_noRoundTripProfit(uint256 dep) public {
        vm.assume(dep < 2 ** 64);
        _deposit(alice, 1_000_000); // concrete seed so the vault is priced
        uint256 s = _deposit(bob, dep);
        vm.prank(bob);
        uint256 out = vault.redeem(s, bob, bob);
        assert(out <= dep);
    }

    // I3 Rounding direction: converting assets to shares and back never
    // creates value for the user.
    function check_I3_roundingFavorsVault(uint256 amt) public {
        vm.assume(amt < 2 ** 64);
        _deposit(alice, 1_000_000);
        uint256 s = vault.convertToShares(amt);
        assert(vault.convertToAssets(s) <= amt);
    }

    // I4 No share theft: bob has no allowance from alice, so he cannot move
    // or burn her shares. A reverting attempt rolls back, so either way
    // alice's balance is untouched.
    function check_I4_noShareTheft(uint256 dep, uint256 stealAmt) public {
        vm.assume(dep < 2 ** 64);
        _deposit(alice, dep);
        uint256 aliceShares = vault.balanceOf(alice);

        vm.prank(bob);
        (bool ok1,) =
            address(vault).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", alice, bob, stealAmt));
        ok1;
        assert(vault.balanceOf(alice) == aliceShares);

        vm.prank(bob);
        (bool ok2,) =
            address(vault).call(abi.encodeWithSignature("redeem(uint256,address,address)", stealAmt, bob, alice));
        ok2;
        assert(vault.balanceOf(alice) == aliceShares);
    }

    // INF the inflation property. Attacker is first depositor, donates to
    // inflate, victim deposits, attacker redeems. The attacker must not end
    // up with more than they put in (deposit + donation).
    //
    // Halmos result: on the naive vault this FAILS fast with a profit
    // counterexample. On the hardened vault Halmos could not decide it: the
    // 4-step nonlinear mulDiv sequence times out, even when the bound is
    // dropped to 2^16 and the solver gets 300s. So hardened INF is TESTED
    // by fuzzing, not PROVEN. See docs/REPORT.md.
    function check_INF_attackerCannotProfit(uint256 atkDeposit, uint256 donation, uint256 victimDeposit) public {
        vm.assume(atkDeposit > 0);
        vm.assume(atkDeposit < 2 ** 40);
        vm.assume(donation < 2 ** 40);
        vm.assume(victimDeposit < 2 ** 40);

        uint256 atkShares = _deposit(attacker, atkDeposit);

        token.mint(attacker, donation);
        vm.prank(attacker);
        token.transfer(address(vault), donation);

        _deposit(victim, victimDeposit);

        vm.prank(attacker);
        uint256 got = vault.redeem(atkShares, attacker, attacker);

        assert(got <= atkDeposit + donation);
    }
}

contract NaiveVaultHalmosTest is VaultHalmosBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new NaiveVault(IERC20(address(t)));
    }
}

contract HardenedVaultHalmosTest is VaultHalmosBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new HardenedVault(IERC20(address(t)), 3); // virtual shares = 10^3
    }
}
