// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "../src/IERC20.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {NaiveVault} from "../src/NaiveVault.sol";
import {HardenedVault} from "../src/HardenedVault.sol";

/// Deploys the asset token and both vaults to whatever RPC you point at.
/// Run against a local anvil node:
///   forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 \
///     --broadcast --private-key <anvil_key_0>
contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        MockERC20 token = new MockERC20();
        NaiveVault naive = new NaiveVault(IERC20(address(token)));
        HardenedVault hardened = new HardenedVault(IERC20(address(token)), 3);
        vm.stopBroadcast();

        console2.log("MockERC20     :", address(token));
        console2.log("NaiveVault    :", address(naive));
        console2.log("HardenedVault :", address(hardened));
    }
}
