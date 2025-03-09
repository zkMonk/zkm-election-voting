// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ElectionVoting} from "../src/ElectionVoting.sol";
import {Verifier} from "../src/Verifier.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy Verifier
        //TODO  Replace this contract with a verifier.sol that is generated for this  voting application. The exising one is a default
        Verifier verifier = new Verifier();

        // Deploy ElectionVoting
        ElectionVoting electionVoting = new ElectionVoting();

        vm.stopBroadcast();

        // Log the addresses
        console2.log("Verifier deployed to:", address(verifier));
        console2.log("ElectionVoting deployed to:", address(electionVoting));
    }
}
