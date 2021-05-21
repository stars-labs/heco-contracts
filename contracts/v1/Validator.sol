// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
import "./CandidatePool.sol";
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

    mapping(address => uint8) actives;

    // candidate address => contract address
    mapping(address => ICandidatePool) public candidates;

    mapping(address => uint) public pendingReward;

    mapping(CandidateType => SortedLinkedList.List) public topCandidates;

    mapping(uint256 => mapping(Operation => bool)) operationsDone;

    event ChangeAdmin(address indexed admin);
    event UpdateParams(uint8 posCount, uint8 posBackup, uint8 poaCount, uint8 poaBackup);
    event AddCandidate(address indexed candidate, address contractAddress);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        ICandidatePool _candidate = ICandidatePool(msg.sender);
        require(candidates[_candidate.candidate()] == _candidate, "Candidate not registered");
        _;
    }

    modifier onlyNotOperated(Operation operation) {
        require(!operationsDone[block.number][operation], "Already operated");
        _;
    }

    function initialize(address[] memory _candidates, address[] memory _manager, address _admin)
    external
    onlyNotInitialized {
        initialized = true;
        require(_candidates.length > 0 && _candidates.length == _manager.length, "Invalid params");
        require(_admin != address(0), "Invalid admin address");
        admin = _admin;

        count[CandidateType.Pos] = 0;
        count[CandidateType.Poa] = 21;
        backupCount[CandidateType.Pos] = 0;
        backupCount[CandidateType.Poa] = 0;

        for (uint8 i = 0; i < _candidates.length; i++) {
            address _candidate = _candidates[i];
            require(candidates[_candidate] == ICandidatePool(0), "Candidate already exists");
            CandidatePool _candidateContract = new CandidatePool(_candidate, _candidate, 100, CandidateType.Poa, State.Ready);
            candidates[_candidate] = ICandidatePool(address(_candidateContract));

            // #if !Mainnet
            _candidateContract.setAddress(address(this), address(0));
            // #endif

            _candidateContract.initialize();
        }
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
        require(candidates[_candidate] == ICandidatePool(0), "Candidate already exists");

        CandidatePool _candidateContract = new CandidatePool(_candidate, _manager, _percent, _type, State.Idle);

        candidates[_candidate] = ICandidatePool(address(_candidateContract));

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

        uint8 _index = 0;
        for (uint8 i = 0; i < _types.length; i++) {
            CandidateType _type = _types[i];
            SortedLinkedList.List storage _list = topCandidates[_type];


            uint8 _size = count[_type];
            ICandidatePool cur = _list.head;
            while (_size > 0 && cur != ICandidatePool(0)) {
                _topValidators[_index] = cur.candidate();
                _index++;
                _size--;
                cur = _list.next[cur];
            }
        }

        return _topValidators;
    }


    function updateActiveValidatorSet(address[] memory newSet, uint256 epoch)
    external
        // #if Mainnet
    onlyMiner
        // #endif
    onlyNotOperated(Operation.UpdateValidators)
    onlyBlockEpoch(epoch)
    onlyInitialized
    {
        operationsDone[block.number][Operation.UpdateValidators] = true;

        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 0;
        }

        activeValidators = newSet;
        for (uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 1;
        }


        delete backupValidators;

        CandidateType[2] memory types = [CandidateType.Pos, CandidateType.Poa];
        for (uint8 i = 0; i < types.length; i++) {
            uint8 size = backupCount[types[i]];
            SortedLinkedList.List storage topList = topCandidates[types[i]];
            ICandidatePool cur = topList.head;
            while (size >= 0 && cur != ICandidatePool(0)) {
                if (actives[cur.candidate()] == 0) {
                    backupValidators.push(cur.candidate());
                    size--;
                }
                cur = topList.next[cur];
            }
        }
    }

    function getActiveValidatorsCount()
    external
    view
    returns (uint){
        return activeValidators.length;
    }

    function getBackupValidatorsCount()
    external
    view
    returns (uint){
        return backupValidators.length;
    }

    function distributeBlockReward()
    external
    payable
        // #if Mainnet
    onlyMiner
        // #endif
    onlyNotOperated(Operation.Distribute)
    onlyInitialized
    {
        operationsDone[block.number][Operation.Distribute] = true;

        uint _left = msg.value;
        // 20% to backups 40% validators share by vote 40% validators share
        if (backupValidators.length > 0) {
            uint _firstPart = msg.value.mul(20).div(100).div(backupValidators.length);
            for (uint8 i = 0; i < backupValidators.length; i++) {
                ICandidatePool _c = candidates[backupValidators[i]];
                pendingReward[address(_c)] = pendingReward[address(_c)].add(_firstPart);
            }
            _left = _left.sub(_firstPart.mul(backupValidators.length));
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote.add(candidates[activeValidators[i]].totalVote());
            }

            uint _secondPartTotal = _totalVote > 0 ? msg.value.mul(40).div(100) : 0;

            uint _thirdPart = _left.sub(_secondPartTotal).div(activeValidators.length);
            for (uint8 i = 0; i < activeValidators.length; i++) {
                ICandidatePool _c = candidates[activeValidators[i]];
                if (_totalVote > 0) {
                    uint _secondPart = _c.totalVote().mul(_secondPartTotal).div(_totalVote);
                    pendingReward[address(_c)] = pendingReward[address(_c)].add(_secondPart).add(_thirdPart);
                } else {
                    pendingReward[address(_c)] = pendingReward[address(_c)].add(_thirdPart);
                }
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
        CandidatePool(msg.sender).updateReward{value : _amount}();
    }

    function improveRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.improveRanking(ICandidatePool(msg.sender));
    }

    function lowerRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.lowerRanking(_candidate);
    }

    function removeRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);

        SortedLinkedList.List storage _list = topCandidates[_candidate.cType()];
        _list.removeRanking(_candidate);
    }

    function removeValidatorIncoming(address _candidate)
    external
    onlyPunishContract {
        ICandidatePool _canContract = candidates[_candidate];
        pendingReward[address(_canContract)] = 0;
    }
}
