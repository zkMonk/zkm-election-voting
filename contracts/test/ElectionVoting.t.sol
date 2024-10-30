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
    ElectionVotingHarness private electionVotingHarness;

    function setUp() public {
        // Deploy ElectionVoting contract
        electionVoting = new ElectionVoting();
        electionVotingHarness = new ElectionVotingHarness();
    }

    function test_DeployerHasAdminRole() public view {
        bytes32 defaultAdminRole = electionVoting.DEFAULT_ADMIN_ROLE();
        bool hasRole = electionVoting.hasRole(
            defaultAdminRole,
            address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496)
        );
        assertTrue(hasRole);
    }

    function test_RandomAddressDoesNotHaveRole() public view {
        bytes32 defaultAdminRole = electionVoting.DEFAULT_ADMIN_ROLE();
        bool hasRole = electionVoting.hasRole(
            defaultAdminRole,
            address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266)
        );
        assertFalse(hasRole);
    }

    function test_AddOffice() public {
        // Check for event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.OfficeAdded(1, "President");

        // Add an office and check the returned office ID
        uint256 officeId = electionVoting.addOffice("President");
        assertEq(officeId, 1);

        // Access the Office struct members directly from the mapping
        (
            uint256 votingStart,
            uint256 votingEnd,
            bool isVotingOpen,
            string memory name,
            uint256 candidateCount
        ) = electionVoting.getOfficeDetails(officeId);

        // Check the members of the Office struct
        assertEq(votingStart, 0);
        assertEq(votingEnd, 0);
        assertFalse(isVotingOpen);
        assertEq(name, "President");
        assertEq(candidateCount, 0);
    }

    function test_RevertAddOfficeWithEmptyName() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidOfficeName()"));
        electionVoting.addOffice("");
    }

    function test_RemoveOffice() public {
        // Add an office so we can remove it
        uint256 officeId = electionVoting.addOffice("President");

        // Check for event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.OfficeRemoved(1);

        // Remove the office
        electionVoting.removeOffice(officeId);

        // Check that the office no longer exists
        (
            uint256 votingStart,
            uint256 votingEnd,
            bool isVotingOpen,
            string memory name,
            uint256 candidateCount
        ) = electionVoting.getOfficeDetails(officeId);
        assertEq(votingStart, 0);
        assertEq(votingEnd, 0);
        assertFalse(isVotingOpen);
        assertEq(name, "");
        assertEq(candidateCount, 0);
    }

    function test_RevertRemovOffice_VotingPeriodAlreadyStarted() public {
        // Add an office so we can remove it
        uint256 officeId = electionVotingHarness.addOffice("President");

        // Start voting for the office
        electionVotingHarness.workaround_startVoting(officeId, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
        vm.expectRevert(
            abi.encodeWithSignature(
                "VotingPeriodAlreadyStarted(uint256)",
                officeId
            )
        );
        electionVotingHarness.removeOffice(officeId);
    }

    function test_AddCandidate() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Expect the CandidateAdded event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateAdded(1, "Alice", officeIdPresident);

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate(
            "Alice",
            officeIdPresident
        );
        assertEq(candidateId, 1);

        // Access the Candidate struct using the getter function
        (
            uint256 voteCount,
            uint256 officeId,
            string memory name
        ) = electionVoting.candidates(candidateId);
        

        // Check the members of the Candidate struct
        assertEq(name, "Alice");
        assertEq(voteCount, 0);
        assertEq(officeId, officeIdPresident);
        
    }

    function test_RevertAddCandidate_VotingPeriodAlreadyStarted() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVotingHarness.addOffice(
            "President"
        );

        // Start voting for the office
        electionVotingHarness.workaround_startVoting(officeIdPresident, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
        vm.expectRevert(
            abi.encodeWithSignature(
                "VotingPeriodAlreadyStarted(uint256)",
                officeIdPresident
            )
        );
        electionVotingHarness.addCandidate("Alice", 1);
    }

    function test_RevertAddCandidate_OfficeDoesNotExist() public {
        // Expect the OfficeDoesNotExistOrInactive custom error
        vm.expectRevert(
            abi.encodeWithSelector(
                ElectionVoting.OfficeDoesNotExist.selector,
                1
            )
        );
        electionVoting.addCandidate("Alice", 1);
    }

    function test_RemoveCandidate_OneOfOne() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate(
            "Alice",
            officeIdPresident
        );

        // Expect the CandidateRemoved event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateRemoved(candidateId);

        // Remove the candidate
        electionVoting.removeCandidate(candidateId);

        // Check that the candidate no longer exists
        (
            uint256 voteCount,
            uint256 officeId,
            string memory name
        ) = electionVoting.candidates(candidateId);
        assertEq(name, "");
        assertEq(voteCount, 0);
        assertEq(officeId, 0);
    }

     function test_RemoveCandidate_OneOfTwo() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate(
            "Alice",
            officeIdPresident
        );

         // Add a second candidate
        uint256 candidateId2 = electionVoting.addCandidate(
            "Bob",
            officeIdPresident
        );


        // Expect the CandidateRemoved event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateRemoved(candidateId2);

        // Remove the candidate
        electionVoting.removeCandidate(candidateId2);

        // Check that the candidate no longer exists
        (
            uint256 voteCount,
            uint256 officeId,
            string memory name
        ) = electionVoting.candidates(candidateId2);
        assertEq(name, "");
        assertEq(voteCount, 0);
        assertEq(officeId, 0);
    }

    function test_RevertRemoveCandidate_VotingPeriodAlreadyStarted() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice(
            "President"
        );

        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
          vm.expectRevert(
            abi.encodeWithSelector(
                ElectionVoting.VotingPeriodAlreadyStarted.selector,
                officeIdPresident
            )
        );
        electionVoting.removeCandidate(candidateId);
    }
}

contract ElectionVotingHarness is ElectionVoting {
    // Helper function for testing purposes to get around circular dependency in addCandidate and startVoting
    function workaround_startVoting(
        uint256 _officeId,
        uint256 _durationInMinutes
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Office storage office = offices[_officeId];
        office.votingStart = block.timestamp;
        office.votingEnd = block.timestamp + (_durationInMinutes * 1 minutes);
        office.isVotingOpen = true;

        emit VotingStarted(_officeId, office.votingStart, office.votingEnd);
    }
}
