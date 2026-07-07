// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {IERC20} from "../src/IERC20.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {ERC4626Base} from "../src/ERC4626Base.sol";
import {NaiveVault} from "../src/NaiveVault.sol";
import {HardenedVault} from "../src/HardenedVault.sol";

address constant ALICE = address(0xA11CE);
address constant BOB = address(0xB0B);
address constant CAROL = address(0xCA201);

/// Drives random vault ops for invariant runs. Includes donate() so the
/// fuzzer is allowed to do the exact thing the inflation attack relies on:
/// move the asset balance without minting shares.
contract VaultHandler is Test {
    MockERC20 public token;
    ERC4626Base public vault;
    address[3] public actors = [ALICE, BOB, CAROL];

    constructor(MockERC20 _token, ERC4626Base _vault) {
        token = _token;
        vault = _vault;
    }

    function _who(uint256 seed) internal view returns (address) {
        return actors[seed % 3];
    }

    function deposit(uint256 seed, uint256 amt) public {
        address a = _who(seed);
        amt = bound(amt, 0, 1e30);
        token.mint(a, amt);
        vm.startPrank(a);
        token.approve(address(vault), amt);
        vault.deposit(amt, a);
        vm.stopPrank();
    }

    function redeem(uint256 seed, uint256 shares) public {
        address a = _who(seed);
        uint256 bal = vault.balanceOf(a);
        if (bal == 0) return;
        shares = bound(shares, 0, bal);
        vm.prank(a);
        vault.redeem(shares, a, a);
    }

    function donate(uint256 amt) public {
        amt = bound(amt, 0, 1e30);
        token.mint(address(this), amt);
        token.transfer(address(vault), amt);
    }
}

/// Property suite shared by both vaults. A subclass just says which vault
/// to deploy. Everything else is identical, so any difference in results
/// comes from the vault math, not the test.
abstract contract VaultPropertiesBase is StdInvariant, Test {
    MockERC20 internal token;
    ERC4626Base internal vault;
    VaultHandler internal handler;

    function deployVault(MockERC20 t) internal virtual returns (ERC4626Base);

    function setUp() public {
        token = new MockERC20();
        vault = deployVault(token);
        handler = new VaultHandler(token, vault);
        targetContract(address(handler));
    }

    // ---------- invariants (I1, I4) ----------

    /// I1 Solvency: the vault holds at least the redeem value of every
    /// share outstanding. If everyone redeemed at the current price, the
    /// vault could pay.
    function invariant_I1_solvency() public view {
        assertGe(vault.totalAssets(), vault.convertToAssets(vault.totalSupply()));
    }

    /// I4 (conservation half): shares only live where the vault minted
    /// them. Total supply equals the sum of the three actors' balances, so
    /// no shares appear from nowhere and none get stolen into other
    /// accounts. The handler never holds shares.
    function invariant_I4_shareConservation() public view {
        uint256 sum = vault.balanceOf(ALICE) + vault.balanceOf(BOB) + vault.balanceOf(CAROL);
        assertEq(vault.totalSupply(), sum);
    }

    // ---------- helpers ----------

    function _deposit(address who, uint256 amt) internal returns (uint256 shares) {
        token.mint(who, amt);
        vm.startPrank(who);
        token.approve(address(vault), amt);
        shares = vault.deposit(amt, who);
        vm.stopPrank();
    }

    function _seed(uint256 amt) internal {
        amt = bound(amt, 1, 1e30); // make the vault nonempty and priced
        _deposit(ALICE, amt);
    }

    // ---------- stateless fuzz property tests (I2, I3, I4) ----------

    /// I2 No round-trip profit: deposit then immediately redeem the shares
    /// you got. You never come out ahead. Rounding favors the vault.
    function testFuzz_I2_noRoundTripProfit(uint256 seed, uint256 dep) public {
        _seed(seed);
        dep = bound(dep, 0, 1e30);
        uint256 shares = _deposit(BOB, dep);
        vm.prank(BOB);
        uint256 out = vault.redeem(shares, BOB, BOB);
        assertLe(out, dep, "round trip returned more than deposited");
    }

    /// I3 Rounding direction: converting assets to shares and back never
    /// gains value, and the up-rounding previews sit on the vault's side of
    /// the down-rounding converts.
    function testFuzz_I3_roundingFavorsVault(uint256 seed, uint256 amt) public {
        _seed(seed);
        amt = bound(amt, 0, 1e30);
        uint256 s = vault.convertToShares(amt);
        assertLe(vault.convertToAssets(s), amt, "convert round trip created value");
        assertGe(vault.previewMint(s), vault.convertToAssets(s), "mint must round up");
        assertGe(vault.previewWithdraw(amt), vault.convertToShares(amt), "withdraw must round up");
    }

    /// I4 No share theft: a third party with no allowance cannot move or
    /// burn someone else's shares.
    function testFuzz_I4_noShareTheft(uint256 dep, uint256 stealAmt, address thief) public {
        vm.assume(thief != ALICE && thief != address(0) && thief != address(vault));
        dep = bound(dep, 1, 1e30);
        uint256 aliceShares = _deposit(ALICE, dep);

        vm.prank(thief);
        try vault.transferFrom(ALICE, thief, stealAmt) {} catch {}
        assertEq(vault.balanceOf(ALICE), aliceShares, "shares moved without allowance");

        vm.prank(thief);
        try vault.redeem(stealAmt, thief, ALICE) {} catch {}
        assertEq(vault.balanceOf(ALICE), aliceShares, "shares burned without allowance");
    }
}

contract NaiveVaultPropertiesTest is VaultPropertiesBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new NaiveVault(IERC20(address(t)));
    }
}

contract HardenedVaultPropertiesTest is VaultPropertiesBase {
    function deployVault(MockERC20 t) internal override returns (ERC4626Base) {
        return new HardenedVault(IERC20(address(t)), 3);
    }
}
