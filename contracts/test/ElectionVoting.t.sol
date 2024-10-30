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
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.OfficeAdded(1, "President");

        // Add an office and check the returned office ID
        uint256 officeId = electionVoting.addOffice("President");
        assertEq(officeId, 1);

        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(officeId);

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
        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(officeId);
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
        vm.expectRevert(abi.encodeWithSignature("VotingPeriodAlreadyStarted(uint256)", officeId));
        electionVotingHarness.removeOffice(officeId);
    }

    function test_AddCandidate() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Expect the CandidateAdded event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateAdded(1, "Alice", officeIdPresident);

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);
        assertEq(candidateId, 1);

        // Access the Candidate struct using the getter function
        (uint256 voteCount, uint256 officeId, string memory name) = electionVoting.candidates(candidateId);

        // Check the members of the Candidate struct
        assertEq(name, "Alice");
        assertEq(voteCount, 0);
        assertEq(officeId, officeIdPresident);
    }

    function test_RevertAddCandidate_VotingPeriodAlreadyStarted() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVotingHarness.addOffice("President");

        // Start voting for the office
        electionVotingHarness.workaround_startVoting(officeIdPresident, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
        vm.expectRevert(abi.encodeWithSignature("VotingPeriodAlreadyStarted(uint256)", officeIdPresident));
        electionVotingHarness.addCandidate("Alice", 1);
    }

    function test_RevertAddCandidate_OfficeDoesNotExist() public {
        // Expect the OfficeDoesNotExistOrInactive custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.OfficeDoesNotExist.selector, 1));
        electionVoting.addCandidate("Alice", 1);
    }

    function test_RemoveCandidate_OneOfOne() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Expect the CandidateRemoved event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateRemoved(candidateId);

        // Remove the candidate
        electionVoting.removeCandidate(candidateId);

        // Check that the candidate no longer exists
        (uint256 voteCount, uint256 officeId, string memory name) = electionVoting.candidates(candidateId);
        assertEq(name, "");
        assertEq(voteCount, 0);
        assertEq(officeId, 0);
    }

    function test_RemoveCandidate_OneOfTwo() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeIdPresident);

        // Add a second candidate
        uint256 candidateId2 = electionVoting.addCandidate("Bob", officeIdPresident);

        // Expect the CandidateRemoved event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.CandidateRemoved(candidateId2);

        // Remove the candidate
        electionVoting.removeCandidate(candidateId2);

        // Check that the candidate no longer exists
        (uint256 voteCount, uint256 officeId, string memory name) = electionVoting.candidates(candidateId2);
        assertEq(name, "");
        assertEq(voteCount, 0);
        assertEq(officeId, 0);
    }

    function test_RevertRemoveCandidate_VotingPeriodAlreadyStarted() public {
        // Add an office so candidate can run for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.VotingPeriodAlreadyStarted.selector, officeIdPresident));
        electionVoting.removeCandidate(candidateId);
    }

    function test_StartVoting() public {
        // Add an office so we can start voting for it
        uint256 officeId = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeId);

        // Expect the VotingStarted event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.VotingStarted(officeId, block.timestamp, block.timestamp + (60 * 1 minutes));

        // Start voting for the office
        electionVoting.startVoting(officeId, 60);

        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(officeId);

        // Check the members of the Office struct
        assertEq(votingStart, block.timestamp);
        assertEq(votingEnd, block.timestamp + (60 * 1 minutes));
        assertTrue(isVotingOpen);
        assertEq(name, "President");
        assertEq(candidateCount, 1);
    }

    function test_RevertStartVoting_InvalidOfficeId() public {
        // Expect the InvalidOfficeId custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.InvalidOfficeId.selector, 0));
        electionVoting.startVoting(0, 60);
    }

    function test_RevertStartVoting_VotingPeriodAlreadyStarted() public {
        // Add an office so we can start voting for it
        uint256 officeId = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeId);

        // Start voting for the office
        electionVoting.startVoting(officeId, 60);

        // Expect the VotingPeriodAlreadyStarted custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.VotingPeriodAlreadyStarted.selector, 1));

        // Try to start voting for the office again
        electionVoting.startVoting(officeId, 60);
    }

    function test_RevertStartVoting_NoCandidatesForOffice() public {
        // Add an office so we can start voting for it
        uint256 officeId = electionVoting.addOffice("President");

        // Expect the NoCandidatesForOffice custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.NoCandidatesForOffice.selector, officeId));
        electionVoting.startVoting(officeId, 60);
    }

    function test_EndVoting() public {
        // Add an office so we can start voting for it
        uint256 officeId = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeId);

        // Start voting for the office
        electionVoting.startVoting(officeId, 60);

        (uint256 votingStartBefore, uint256 votingEndBefore,, string memory nameBefore, uint256 candidateCountBefore) =
            electionVoting.getOfficeDetails(officeId);

        // Advance the block time by more than 60 minutes
        vm.warp(block.timestamp + (61 * 1 minutes));

        console.log("block.timestamp in test: %d", block.timestamp);

        // Expect the VotingEnded event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.VotingEnded(officeId, block.timestamp);

        // End voting for the office
        electionVoting.endVoting(officeId);

        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(officeId);

        // Check the members of the Office struct
        assertEq(votingStart, votingStartBefore);
        assertEq(votingEnd, votingEndBefore);
        assertFalse(isVotingOpen);
        assertEq(name, nameBefore);
        assertEq(candidateCount, candidateCountBefore);
    }

    function test_RevertEndVoting_VotingPeriodNotStarted() public {
        // Add an office so we can start voting for it
        uint256 officeId = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeId);

        // Expect the VotingPeriodNotStarted custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.VotingPeriodNotStarted.selector, officeId));
        electionVoting.endVoting(officeId);
    }

    function test_vote() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Set the msg.sender to a specific address
        address voter = address(0x123);
        vm.prank(voter);

        // Expect the VoteCast event
        vm.expectEmit(true, true, true, true);
        emit ElectionVoting.Voted(voter, officeIdPresident, candidateId);

        // Vote for the candidate
        electionVoting.vote(officeIdPresident, candidateId);

        // Check that the candidate's vote count has increased
        (uint256 voteCount, uint256 officeId, string memory name) = electionVoting.candidates(candidateId);
        assertEq(voteCount, 1);
        assertEq(officeId, officeIdPresident);
        assertEq(name, "Alice");
    }

    function test_RevertVote_VotingPeriodNotStarted() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Expect the VotingPeriodNotStarted custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.VotingPeriodNotStarted.selector, officeIdPresident));
        electionVoting.vote(officeIdPresident, candidateId);
    }

    function test_RevertVote_AlreadyVotedForOffice() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Set the msg.sender to a specific address
        address voter = address(0x123);
        vm.prank(voter);

        // Vote once
        electionVoting.vote(officeIdPresident, candidateId);

        // Expect the AlreadyVotedForOffice custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.AlreadyVotedForOffice.selector, voter, officeIdPresident));

        // Set the msg.sender to a specific address
        voter = address(0x123);
        vm.prank(voter);

        // Vote again
        electionVoting.vote(officeIdPresident, candidateId);
    }

    function test_RevertVote_VotingPeriodNotStarted_NoOffice() public {
        // Expect the VotingPeriodNotStarted custom error
        vm.expectRevert(abi.encodeWithSelector(ElectionVoting.VotingPeriodNotStarted.selector, 1));
        electionVoting.vote(1, 1);
    }

    function test_RevertVote_CandidateNotRunningForOffice() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");
        uint256 officeIdVicePresident = electionVoting.addOffice("VicePresident");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        electionVoting.addCandidate("Bob", officeIdVicePresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);
        electionVoting.startVoting(officeIdVicePresident, 60);

        // Expect the CandidateNotRunningForOffice custom error
        vm.expectRevert(
            abi.encodeWithSelector(
                ElectionVoting.CandidateNotRunningForOffice.selector, candidateId, officeIdVicePresident
            )
        );
        electionVoting.vote(officeIdVicePresident, candidateId);
    }

    function test_getOfficeCandidates_OfficeHasCandidates() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        uint256 candidateId2 = electionVoting.addCandidate("Bob", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);
        electionVoting.vote(officeIdPresident, candidateId2);

        // Get the candidates for the office
        (uint256[] memory candidateIds, string[] memory names, uint256[] memory voteCounts) =
            electionVoting.getOfficeCandidates(officeIdPresident);

        // Check that the candidate is in the list
        assertEq(candidateIds.length, 2);
        assertEq(candidateIds[0], candidateId);
        assertEq(candidateIds[1], candidateId2);
        assertEq(names.length, 2);
        assertEq(names[0], "Alice");
        assertEq(names[1], "Bob");
        assertEq(voteCounts.length, 2);
        assertEq(voteCounts[0], 0);
        assertEq(voteCounts[1], 1);
    }

    function test_getOfficeCandidates_OfficeDoesNotExist() public view {
        // Get the candidates for a non-existent office
        (uint256[] memory candidateIds, string[] memory names, uint256[] memory voteCounts) =
            electionVoting.getOfficeCandidates(1);

        // Check that the candidate is in the list
        assertEq(candidateIds.length, 0);
        assertEq(names.length, 0);
        assertEq(voteCounts.length, 0);
    }

    function test_getOfficeDetails_OfficeExists() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Get the office details
        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(officeIdPresident);

        // Check the members of the Office struct
        assertEq(votingStart, block.timestamp);
        assertEq(votingEnd, block.timestamp + (60 * 1 minutes));
        assertTrue(isVotingOpen);
        assertEq(name, "President");
        assertEq(candidateCount, 1);
    }

    function test_getOfficeDetails_OfficeDoesNotExist() public view {
        // Get the office details
        (uint256 votingStart, uint256 votingEnd, bool isVotingOpen, string memory name, uint256 candidateCount) =
            electionVoting.getOfficeDetails(1);

        // Check the members of the Office struct
        assertEq(votingStart, 0);
        assertEq(votingEnd, 0);
        assertFalse(isVotingOpen);
        assertEq(name, "");
        assertEq(candidateCount, 0);
    }

    function test_hasVotedForOffice_True() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Set the msg.sender to a specific address
        address voter = address(0x123);
        vm.prank(voter);

        // Vote for the candidate
        electionVoting.vote(officeIdPresident, candidateId);

        // Check if the voter has voted for the office
        bool hasVoted = electionVoting.hasVotedForOffice(voter, officeIdPresident);
        assertTrue(hasVoted);
    }

    function test_hasVotedForOffice_False() public {
        // Add an office so we can start voting for it
        uint256 officeIdPresident = electionVoting.addOffice("President");

        // Add a candidate
        uint256 candidateId = electionVoting.addCandidate("Alice", officeIdPresident);

        // Start voting for the office
        electionVoting.startVoting(officeIdPresident, 60);

        // Set voter address
        address voter = address(0x123);

        // Set the msg.sender to a specific address
        address voter2 = address(0x456);
        vm.prank(voter2);

        // Vote for the candidate
        electionVoting.vote(officeIdPresident, candidateId);

        // Check if the voter has voted for the office
        bool hasVoted = electionVoting.hasVotedForOffice(voter, officeIdPresident);
        assertFalse(hasVoted);
    }
}

contract ElectionVotingHarness is ElectionVoting {
    // Helper function for testing purposes to get around circular dependency in addCandidate and startVoting
    function workaround_startVoting(uint256 _officeId, uint256 _durationInMinutes)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Office storage office = offices[_officeId];
        office.votingStart = block.timestamp;
        office.votingEnd = block.timestamp + (_durationInMinutes * 1 minutes);
        office.isVotingOpen = true;

        emit VotingStarted(_officeId, office.votingStart, office.votingEnd);
    }
}
