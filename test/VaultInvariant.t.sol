// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {Vault} from "../src/Vault.sol";
import {IERC20} from "../src/IERC20.sol";

/// Stateful handler: random deposits/withdraws across a fixed actor set.
/// Amounts are bounded so calls do not revert, and ghost totals track
/// the net flow for the conservation invariant.
contract Handler is Test {
    Vault public vault;
    MockERC20 public token;
    address[] public actors;
    uint256 public ghostDeposited;
    uint256 public ghostWithdrawn;

    constructor(Vault _vault, MockERC20 _token) {
        vault = _vault;
        token = _token;
        actors.push(address(0xA));
        actors.push(address(0xB));
        actors.push(address(0xC));
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function deposit(uint256 seed, uint256 amount) public {
        address actor = _actor(seed);
        amount = bound(amount, 0, 1e30);
        token.mint(actor, amount);
        vm.startPrank(actor);
        token.approve(address(vault), amount);
        vault.deposit(amount);
        vm.stopPrank();
        ghostDeposited += amount;
    }

    function withdraw(uint256 seed, uint256 amount) public {
        address actor = _actor(seed);
        uint256 bal = vault.balanceOf(actor);
        amount = bound(amount, 0, bal);
        vm.prank(actor);
        vault.withdraw(amount);
        ghostWithdrawn += amount;
    }

    function sumBalances() public view returns (uint256 s) {
        for (uint256 i; i < actors.length; i++) {
            s += vault.balanceOf(actors[i]);
        }
    }
}

contract VaultInvariantTest is StdInvariant, Test {
    MockERC20 token;
    Vault vault;
    Handler handler;

    function setUp() public {
        token = new MockERC20();
        vault = new Vault(IERC20(address(token)));
        handler = new Handler(vault, token);
        targetContract(address(handler));
    }

    /// P1 solvency: the vault always holds enough tokens to cover the sum
    /// of every user's recorded balance.
    function invariant_P1_solvency() public view {
        assertGe(token.balanceOf(address(vault)), handler.sumBalances());
    }

    /// P2 no theft (conservation): recorded balances net exactly to
    /// deposits minus withdrawals, so no value is created out of thin air.
    function invariant_P2_conservation() public view {
        assertEq(handler.sumBalances(), handler.ghostDeposited() - handler.ghostWithdrawn());
    }

    /// P3 no tampering (stateless fuzz): alice depositing never changes
    /// bob's recorded balance.
    function testFuzz_P3_noTampering(uint256 bobInit, uint256 aliceAmt) public {
        address alice = address(0xA11CE);
        address bob = address(0xB0B);
        bobInit = bound(bobInit, 0, 1e30);
        aliceAmt = bound(aliceAmt, 0, 1e30);

        token.mint(bob, bobInit);
        vm.startPrank(bob);
        token.approve(address(vault), bobInit);
        vault.deposit(bobInit);
        vm.stopPrank();
        uint256 bobBal = vault.balanceOf(bob);

        token.mint(alice, aliceAmt);
        vm.startPrank(alice);
        token.approve(address(vault), aliceAmt);
        vault.deposit(aliceAmt);
        vm.stopPrank();

        assertEq(vault.balanceOf(bob), bobBal);
    }
}
