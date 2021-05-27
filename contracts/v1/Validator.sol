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
import "./interfaces/ICandidatePool.sol";

contract Validator is Params {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(CandidateType => uint8) public count;
    mapping(CandidateType => uint8) public backupCount;

    address[] activeValidators;
    address[] backupValidators;

    mapping(address => uint8) actives;

    mapping(address => ICandidatePool) public candidatePools;

    mapping(ICandidatePool => uint) public pendingReward;

    mapping(CandidateType => SortedLinkedList.List) public topCandidatePools;

    mapping(uint256 => mapping(Operation => bool)) operationsDone;

    event ChangeAdmin(address indexed admin);
    event UpdateParams(uint8 posCount, uint8 posBackup, uint8 poaCount, uint8 poaBackup);
    event AddCandidate(address indexed candidate, address contractAddress);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        ICandidatePool _pool = ICandidatePool(msg.sender);
        require(candidatePools[_pool.candidate()] == _pool, "Candidate pool not registered");
        _;
    }

    modifier onlyNotOperated(Operation operation) {
        require(!operationsDone[block.number][operation], "Already operated");
        _;
    }

    function initialize(address[] memory _candidates, address[] memory _managers, address _admin)
    external
    onlyNotInitialized {
        require(_candidates.length > 0 && _candidates.length == _managers.length, "Invalid params");
        require(_admin != address(0), "Invalid admin address");

        initialized = true;
        admin = _admin;

        count[CandidateType.Pos] = 0;
        count[CandidateType.Poa] = 21;
        backupCount[CandidateType.Pos] = 0;
        backupCount[CandidateType.Poa] = 0;

        for (uint8 i = 0; i < _candidates.length; i++) {
            address _candidate = _candidates[i];
            require(candidatePools[_candidate] == ICandidatePool(0), "Candidate already exists");
            CandidatePool _pool = new CandidatePool(_candidate, _managers[i], 100, CandidateType.Poa, State.Ready);
            candidatePools[_candidate] = ICandidatePool(address(_pool));

            // #if !Mainnet
            _pool.setAddress(address(this), address(0));
            // #endif

            _pool.initialize();
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
        require(_posCount + _poaCount == MaxValidators, "Invalid validator counts");
        require(_posBackup <= _posCount && _poaBackup <= _poaCount, "Invalid backup counts");

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
        require(candidatePools[_candidate] == ICandidatePool(0), "Candidate already exists");

        CandidatePool _pool = new CandidatePool(_candidate, _manager, _percent, _type, State.Idle);

        candidatePools[_candidate] = ICandidatePool(address(_pool));

        emit AddCandidate(_candidate, address(_pool));

        return address(_pool);
    }

    function updateCandidateState(address _candidate, bool pause)
    external
    onlyAdmin {
        require(candidatePools[_candidate] != ICandidatePool(0), "Corresponding candidate pool not found");
        candidatePools[_candidate].switchState(pause);
    }

    function getTopValidators()
    external
    view
    returns (address[] memory) {
        uint8 _count = 0;

        CandidateType[2] memory _types = [CandidateType.Pos, CandidateType.Poa];

        for (uint8 i = 0; i < _types.length; i++) {
            CandidateType _type = _types[i];
            SortedLinkedList.List storage _list = topCandidatePools[_type];
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
            SortedLinkedList.List storage _list = topCandidatePools[_type];

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
            uint8 _size = backupCount[types[i]];
            SortedLinkedList.List storage _topList = topCandidatePools[types[i]];
            ICandidatePool cur = _topList.head;
            while (_size >= 0 && cur != ICandidatePool(0)) {
                if (actives[cur.candidate()] == 0) {
                    backupValidators.push(cur.candidate());
                    _size--;
                }
                cur = _topList.next[cur];
            }
        }
    }

    function getActiveValidators()
    external
    view
    returns (address[] memory){
        return activeValidators;
    }

    function getBackupValidators()
    external
    view
    returns (address[] memory){
        return backupValidators;
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
        // 10% to backups 40% validators share by vote 50% validators share
        if (backupValidators.length > 0) {
            uint _firstPart = msg.value.mul(10).div(100).div(backupValidators.length);
            for (uint8 i = 0; i < backupValidators.length; i++) {
                ICandidatePool _pool = candidatePools[backupValidators[i]];
                pendingReward[_pool] = pendingReward[_pool].add(_firstPart);
            }
            _left = _left.sub(_firstPart.mul(backupValidators.length));
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote.add(candidatePools[activeValidators[i]].totalVote());
            }

            uint _secondPartTotal = _totalVote > 0 ? msg.value.mul(40).div(100) : 0;

            uint _thirdPart = _left.sub(_secondPartTotal).div(activeValidators.length);
            for (uint8 i = 0; i < activeValidators.length; i++) {
                ICandidatePool _pool = candidatePools[activeValidators[i]];
                if (_totalVote > 0) {
                    uint _secondPart = _pool.totalVote().mul(_secondPartTotal).div(_totalVote);
                    pendingReward[_pool] = pendingReward[_pool].add(_secondPart).add(_thirdPart);
                } else {
                    pendingReward[_pool] = pendingReward[_pool].add(_thirdPart);
                }
            }
        }
    }

    function withdrawReward()
    external {
        uint _amount = pendingReward[ICandidatePool(msg.sender)];
        if (_amount == 0) {
            return;
        }

        pendingReward[ICandidatePool(msg.sender)] = 0;
        CandidatePool(msg.sender).receiveReward{value : _amount}();
    }

    function improveRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidatePools[_candidate.candidateType()];
        _list.improveRanking(_candidate);
    }

    function lowerRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);
        require(_candidate.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topCandidatePools[_candidate.candidateType()];
        _list.lowerRanking(_candidate);
    }

    function removeRanking()
    external
    onlyRegistered {
        ICandidatePool _candidate = ICandidatePool(msg.sender);

        SortedLinkedList.List storage _list = topCandidatePools[_candidate.candidateType()];
        _list.removeRanking(_candidate);
    }

    function removeValidatorIncoming(address _candidate)
    external
    onlyPunishContract {
        pendingReward[candidatePools[_candidate]] = 0;
    }
}
