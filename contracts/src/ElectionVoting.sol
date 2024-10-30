// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "forge-std/console.sol";

contract ElectionVoting is AccessControl {
    struct Office {
        uint256 votingStart;
        uint256 votingEnd;
        bool isVotingOpen;
        bool isActive;
        string name;
        uint256[] candidateIds; // Array of candidate IDs for this office
    }

    struct Candidate {
        uint256 voteCount;
        uint256 officeId; // Reference to which office they're running for
        string name;
    }

    struct Voter {
        bool isEligible;
        mapping(uint256 => bool) hasVotedForOffice; // Track votes per office Id
    }

    address public admin;
    mapping(address => Voter) public voters;
    mapping(uint256 => Office) public offices; // officeId => Office
    mapping(uint256 => Candidate) public candidates; // candidateId => Candidate

    uint256 public nextOfficeId = 1;
    uint256 public nextCandidateId = 1;

    event OfficeAdded(uint256 indexed officeId, string name);
    event CandidateAdded(uint256 indexed candidateId, string name, uint256 indexed officeId);
    event Voted(address indexed voter, uint256 indexed officeId, uint256 indexed candidateId);
    event VotingStarted(uint256 indexed officeId, uint256 startTime, uint256 endTime);
    event VotingEnded(uint256 indexed officeId, uint256 endTime);

    /// @notice Custom errors
    error VotingNotOpen(uint256 officeId);
    error VotingPeriodAlreadyStarted(uint256 officeId);
    error VotingPeriodEnded(uint256 officeId);
    error InvalidOfficeName();
    error OfficeDoesNotExistOrInactive(uint256 officeId);
    error NoOfficesRegistered();
    error AlreadyVotedForOffice(uint256 officeId);
    error InvalidOfficeId(uint256 officeId);
    error CandidateNotRunningForOffice(uint256 candidateId, uint256 officeId);

    modifier votingIsOpen(uint256 _officeId) {
        Office memory office = offices[_officeId];
        require(office.isVotingOpen, VotingNotOpen(_officeId));
        require(
            block.timestamp >= office.votingStart && block.timestamp <= office.votingEnd, VotingPeriodEnded(_officeId)
        );
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addOffice(string memory _name) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 officeId) {
        require(bytes(_name).length > 0, InvalidOfficeName());

        offices[nextOfficeId] = Office({
            votingStart: 0,
            votingEnd: 0,
            isVotingOpen: false,
            isActive: true,
            name: _name,
            candidateIds: new uint256[](0)
        });

        officeId = nextOfficeId;
        emit OfficeAdded(nextOfficeId, _name);
        nextOfficeId++;
    }

    function addCandidate(string memory _name, uint256 _officeId) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256 candidateId) {
        Office memory office = offices[_officeId];
        require(!office.isVotingOpen, VotingPeriodAlreadyStarted(_officeId));
        require(offices[_officeId].isActive, OfficeDoesNotExistOrInactive(_officeId));

        candidates[nextCandidateId] = Candidate({name: _name, voteCount: 0, officeId: _officeId});

        offices[_officeId].candidateIds.push(nextCandidateId);

        candidateId = nextCandidateId;
        emit CandidateAdded(candidateId, _name, _officeId);
        nextCandidateId++;
    }

    function startVoting(uint256 _officeId, uint256 _durationInMinutes) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_officeId > 0, InvalidOfficeId(_officeId));

        Office memory office = offices[_officeId];
        require(!office.isVotingOpen, VotingPeriodAlreadyStarted(_officeId));
      

        office.votingStart = block.timestamp;
        office.votingEnd = block.timestamp + (_durationInMinutes * 1 minutes);
        office.isVotingOpen = true;

        offices[_officeId] = office;

        emit VotingStarted(_officeId, office.votingStart, office.votingEnd);
    }

    function vote(uint256 _officeId, uint256 _candidateId) external votingIsOpen(_officeId) {
        /**
         * Check zk proof to see if the voter is eligible. Could be a modifier ***
         */
        require(!voters[msg.sender].hasVotedForOffice[_officeId], AlreadyVotedForOffice(_officeId));
        require(offices[_officeId].isActive, InvalidOfficeId(_officeId));
        require(candidates[_candidateId].officeId == _officeId, CandidateNotRunningForOffice(_candidateId, _officeId));

        voters[msg.sender].hasVotedForOffice[_officeId] = true;
        candidates[_candidateId].voteCount++;

        emit Voted(msg.sender, _officeId, _candidateId);
    }

    function getOfficeCandidates(uint256 _officeId)
        external
        view
        returns (uint256[] memory candidateIds, string[] memory names, uint256[] memory voteCounts)
    {
        require(offices[_officeId].isActive, OfficeDoesNotExistOrInactive(_officeId));

        uint256[] memory cIds = offices[_officeId].candidateIds;
        names = new string[](cIds.length);
        voteCounts = new uint256[](cIds.length);

        for (uint256 i = 0; i < cIds.length; i++) {
            names[i] = candidates[cIds[i]].name;
            voteCounts[i] = candidates[cIds[i]].voteCount;
        }

        return (cIds, names, voteCounts);
    }

    function getOfficeDetails(uint256 _officeId)
        external
        view
        returns (
            uint256 votingStart,
            uint256 votingEnd,
            bool isVotingOpen,
            bool isActive,
            string memory name,
            uint256 candidateCount
        )
    {
        Office storage office = offices[_officeId];
        return (
            office.votingStart,
            office.votingEnd,
            office.isVotingOpen,
            office.isActive,
            office.name,
            office.candidateIds.length
        );
    }

    function hasVotedForOffice(address _voter, uint256 _officeId) external view returns (bool) {
        return voters[_voter].hasVotedForOffice[_officeId];
    }

    function getVotingTimeLeft(uint256 officeId) external view returns (uint256) {
        Office memory office = offices[officeId];
        if (!office.isVotingOpen || block.timestamp >= office.votingEnd) {
            return 0;
        }
        return office.votingEnd - block.timestamp;
    }
}
