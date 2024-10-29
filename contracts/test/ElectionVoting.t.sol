// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ElectionVoting} from "../src/ElectionVoting.sol";
import {stdJson} from "forge-std/StdJson.sol";
//import {Verifier} from "../src/verifier.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

contract ElectionVotingTest is Test {
    ElectionVoting private electionVoting;

    function setUp() public {
        // Deploy ElectionVoting contract
        electionVoting = new ElectionVoting();
    }

    function test_DeployerHasAdminRole() public view {
        bytes32 defaultAdminRole = electionVoting.DEFAULT_ADMIN_ROLE();
        bool hasRole = electionVoting.hasRole(defaultAdminRole, address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496));
        assertTrue(hasRole);
    }

    function test_RandomAddressDoesNotHaveRole() public view {
        bytes32 defaultAdminRole = electionVoting.DEFAULT_ADMIN_ROLE();
        bool hasRole = electionVoting.hasRole(defaultAdminRole, address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266));
        assertFalse(hasRole);
    }

    function test_AddOffice() public {
        // Check for event
        vm.expectEmit(true, false, false, true);
        emit ElectionVoting.OfficeAdded(1, "President");

        // Add an office and check the returned office ID
        uint256 officeId = electionVoting.addOffice("President");
        assertEq(officeId, 1);

        // Access the Office struct members directly from the mapping
        (
            uint256 votingStart,
            uint256 votingEnd,
            bool isVotingOpen,
            bool isActive,
            string memory name,
            uint256 candidateCount
        ) = electionVoting.getOfficeDetails(officeId);

        // Check the members of the Office struct
        assertEq(votingStart, 0);
        assertEq(votingEnd, 0);
        assertFalse(isVotingOpen);
        assertTrue(isActive);
        assertEq(name, "President");
        assertEq(candidateCount, 0);
    }

    function test_RevertAddOfficeWithEmptyName() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidOfficeName()"));
        electionVoting.addOffice("");
    }
}
