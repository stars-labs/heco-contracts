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

    event ChangeAdmin(address indexed admin);
    event UpdateParams(uint8 posCount, uint8 posBackup, uint8 poaCount, uint8 poaBackup);
    event AddCandidate(address indexed candidate, address contractAddress);

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

    function changeAdmin(address _newAdmin)
    external
    onlyAdmin {
        admin = _newAdmin;
        emit ChangeAdmin(admin);
    }

    function updateParams(uint8 _posCount, uint8 _posBackup, uint8 _poaCount, uint8 _poaBackup)
    external
    onlyAdmin {
        require(_posCount + _poaCount == MaxValidators, "Invalid params");

        count[CandidateType.Pos] = _posCount;
        count[CandidateType.Poa] = _poaCount;

        backupCount[CandidateType.Pos] = _posBackup;
        backupCount[CandidateType.Poa] = _poaBackup;

        emit UpdateParams(_posCount, _posBackup, _poaCount, _poaBackup);
    }

    function addCandidate(address _candidate, address _manager, uint8 _percent, CandidateType _type)
    external
    onlyAdmin
    returns (address) {
        require(candidates[_candidate] == ICandidate(0), "Candidate already exists");

        Candidate _candidateContract = new Candidate(_candidate, _manager, _percent, _type);
        candidates[_candidate] = ICandidate(address(_candidateContract));

        emit AddCandidate(_candidate, address(_candidateContract));

        return address(_candidateContract);
    }

    function updateCandidateState(address _candidate, bool pause)
    external
    onlyAdmin {
        require(address(candidates[_candidate]) != address(0), "Corresponding candidate not found");
        candidates[_candidate].switchState(pause);
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
    external
    {
        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 0;
        }

        activeValidators = newSet;
        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 1;
        }


        for(uint8 i = 0; i < backupValidators.length; i ++) {
            delete backupValidators[backupValidators.length - 1];
        }

        CandidateType[2] memory types = [CandidateType.Pos, CandidateType.Poa];
        for (uint8 i = 0; i < types.length; i++) {
            uint8 size = backupCount[types[i]];
            SortedLinkedList.List storage topList = topCandidates[types[i]];
            ICandidate cur = topList.head;
            while (size >= 0 && cur != ICandidate(0)) {
                if(actives[cur.candidate()] == 0) {
                    backupValidators.push(cur.candidate());
                    size--;
                }
                cur = topList.next[cur];
            }
        }
    }

    function distributeBlockReward()
    external
    payable
    {
        //TODO
        uint _total = 0;
        for (uint8 i = 0; i < activeValidators.length; i++) {
            _total += candidates[activeValidators[i]].totalVote();
        }

        if (_total > 0) {
            for (uint8 i = 0; i < activeValidators.length; i++) {
                ICandidate c = candidates[activeValidators[i]];
                pendingReward[address(c)] += c.totalVote().mul(msg.value).div(_total);
            }
        }
    }

    function withdrawReward()
    external {
        uint _amount = pendingReward[msg.sender];
        if (_amount == 0) {
            return;
        }

        pendingReward[msg.sender] = 0;
        Candidate(msg.sender).updateReward{value : _amount}();
    }

    function improveRanking()
    external
    onlyRegistered {
        ICandidate _candidate = ICandidate(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.improveRanking(ICandidate(msg.sender));
    }

    function lowerRanking()
    external
    onlyRegistered {
        ICandidate _candidate = ICandidate(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.lowerRanking(_candidate);
    }

    function removeRanking()
    external
    onlyRegistered {
        ICandidate _candidate = ICandidate(msg.sender);

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.removeRanking(_candidate);
    }
}
