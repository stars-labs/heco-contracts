// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../library/SafeMath.sol";
import "./Candidate.sol";
import "./Params.sol";
import "./library/SortedList.sol";
import "./interfaces/ICandidate.sol";

contract Validator is Params {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(CandidateType => uint8) public count;
    mapping(CandidateType => uint8) public backupCount;

    address[] public activeValidators;
    address[] public backupValidators;

    // candidate address => contract address
    mapping(address => ICandidate) public candidates;

    mapping(address => uint) public pendingReward;

    mapping(CandidateType => SortedLinkedList.List) public topCandidates;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        ICandidate _candidate = ICandidate(msg.sender);
        require(candidates[_candidate.candidate()] == _candidate, "Candidate not registered");
        _;
    }

    //TODO add requirement
    function initialize(address _admin)
    external {
        admin = _admin;

        count[CandidateType.Pos] = 11;
        count[CandidateType.Poa] = 10;
        backupCount[CandidateType.Pos] = 11;
        backupCount[CandidateType.Poa] = 3;
    }

    function addValidator(address _candidate, address _manager, uint8 _percent, CandidateType _type)
    external
    onlyAdmin
    returns (address) {
        require(candidates[_candidate] == ICandidate(0), "Candidate already exists");

        Candidate _candidateContract = new Candidate(_candidate, _manager, _percent, _type);
        candidates[_candidate] = ICandidate(address(_candidateContract));

        //TODO event
        return address(_candidateContract);
    }

    function getTopValidators()
    external
    view
    returns (address[] memory) {
        uint8 _count = 0;

        CandidateType[2] memory _types = [CandidateType.Pos, CandidateType.Poa];

        for (uint8 i = 0; i < _types.length; i++) {
            CandidateType _type = _types[i];
            SortedLinkedList.List storage _list = topCandidates[_type];
            if (_list.length < count[_type]) {
                _count += _list.length;
            } else {
                _count += count[_type];
            }
        }

        address[] memory _topValidators = new address[](_count);

        for (uint8 i = 0; i < _types.length; i++) {
            CandidateType _type = _types[i];
            SortedLinkedList.List storage _list = topCandidates[_type];


            uint8 _size = count[_type];
            ICandidate cur = _list.head;
            uint8 _index = 0;
            while (_size > 0 && cur != ICandidate(0)) {
                _topValidators[_index] = cur.candidate();
                _index++;
                _size--;
                cur = _list.next[cur];
            }
        }

        return _topValidators;
    }

    mapping(address => uint8) actives;

    function updateActiveValidatorSet(address[] memory newSet, uint256 epoch)
        //TODO modifier
    public
    {
        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 0;
        }

        activeValidators = newSet;
        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 1;
        }

        CandidateType[2] memory types = [CandidateType.Pos, CandidateType.Poa];
        for (uint8 i = 0; i < types.length; i++) {
            uint8 size = backupCount[types[i]];
            SortedLinkedList.List storage topList = topCandidates[types[i]];
            ICandidate cur = topList.head;
            while (size >= 0 && cur != ICandidate(0) && actives[cur.candidate()] == 0) {
                backupValidators.push(cur.candidate());
                size--;
                cur = topList.next[cur];
            }
        }
    }

    function distributeBlockReward()
    external
    payable
    {
        //TODO
        uint total = 0;
        for (uint8 i = 0; i < activeValidators.length; i++) {
            total += candidates[activeValidators[i]].totalVote();
        }

        if (total > 0) {
            for (uint8 i = 0; i < activeValidators.length; i++) {
                ICandidate c = candidates[activeValidators[i]];
                pendingReward[address(c)] += c.totalVote().mul(msg.value).div(total);
            }
        }
    }

    function withdrawReward()
    external {
        uint amount = pendingReward[msg.sender];
        if (amount == 0) {
            return;
        }

        pendingReward[msg.sender] = 0;
        Candidate(msg.sender).updateReward{value : amount}();
    }

    //TODO change admin

    function updateParams(uint8 _posCount, uint8 _posBackup, uint8 _poaCount, uint8 _poaBackup)
    external
    onlyAdmin {

    }

    function updateCandidateState(address _miner, bool pause)
    external
    onlyAdmin {
        require(address(candidates[_miner]) != address(0), "Corresponding candidate not found");
        candidates[_miner].switchState(pause);
    }

    function improveRanking()
    external
    onlyRegistered {
        Candidate c = Candidate(msg.sender);
        require(c.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage curList = topCandidates[c.cType()];
        curList.improveRanking(ICandidate(msg.sender));
    }

    function lowerRanking()
    external
    onlyRegistered {
        Candidate c = Candidate(msg.sender);
        require(c.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage curList = topCandidates[c.cType()];
        curList.lowerRanking(ICandidate(msg.sender));
    }


    function removeRanking()
    external
    onlyRegistered {
        Candidate c = Candidate(msg.sender);

        SortedLinkedList.List storage curList = topCandidates[c.cType()];
        curList.removeRanking(ICandidate(msg.sender));
    }
}
