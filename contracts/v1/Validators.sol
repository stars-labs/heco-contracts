// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
import "./VotePool.sol";
import "./library/SortedList.sol";
import "./interfaces/IVotePool.sol";

contract Validators is Params {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(ValidatorType => uint8) public count;
    mapping(ValidatorType => uint8) public backupCount;

    address[] activeValidators;
    address[] backupValidators;

    mapping(address => uint8) actives;

    address[] public validators;
    mapping(address => IVotePool) public votePools;

    mapping(IVotePool => uint) public pendingReward;

    mapping(ValidatorType => SortedLinkedList.List) public topVotePools;

    mapping(uint256 => mapping(Operation => bool)) operationsDone;

    event ChangeAdmin(address indexed admin);
    event UpdateParams(uint8 posCount, uint8 posBackup, uint8 poaCount, uint8 poaBackup);
    event AddValidator(address indexed validator, address votePool);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        IVotePool _pool = IVotePool(msg.sender);
        require(votePools[_pool.validator()] == _pool, "Vote pool not registered");
        _;
    }

    modifier onlyNotOperated(Operation operation) {
        require(!operationsDone[block.number][operation], "Already operated");
        _;
    }

    function initialize(address[] memory _validators, address[] memory _managers, address _admin)
    external
    onlyNotInitialized {
        require(_validators.length > 0 && _validators.length == _managers.length, "Invalid params");
        require(_admin != address(0), "Invalid admin address");

        initialized = true;
        admin = _admin;

        count[ValidatorType.Pos] = 0;
        count[ValidatorType.Poa] = 21;
        backupCount[ValidatorType.Pos] = 0;
        backupCount[ValidatorType.Poa] = 0;

        for (uint8 i = 0; i < _validators.length; i++) {
            address _validator = _validators[i];
            require(votePools[_validator] == IVotePool(0), "Validators already exists");
            VotePool _pool = new VotePool(_validator, _managers[i], 100, ValidatorType.Poa, State.Ready);
            votePools[_validator] = IVotePool(address(_pool));

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

        count[ValidatorType.Pos] = _posCount;
        count[ValidatorType.Poa] = _poaCount;

        backupCount[ValidatorType.Pos] = _posBackup;
        backupCount[ValidatorType.Poa] = _poaBackup;

        emit UpdateParams(_posCount, _posBackup, _poaCount, _poaBackup);
    }

    function addValidator(address _validator, address _manager, uint8 _percent, ValidatorType _type)
    external
    onlyAdmin
    returns (address) {
        require(votePools[_validator] == IVotePool(0), "Validators already exists");

        VotePool _pool = new VotePool(_validator, _manager, _percent, _type, State.Idle);

        validators.push(_validator);
        votePools[_validator] = IVotePool(address(_pool));

        emit AddValidator(_validator, address(_pool));

        return address(_pool);
    }

    function updateValidatorState(address _validator, bool pause)
    external
    onlyAdmin {
        require(votePools[_validator] != IVotePool(0), "Corresponding vote pool not found");
        votePools[_validator].switchState(pause);
    }

    function getTopValidators()
    external
    view
    returns (address[] memory) {
        uint8 _count = 0;

        ValidatorType[2] memory _types = [ValidatorType.Pos, ValidatorType.Poa];

        for (uint8 i = 0; i < _types.length; i++) {
            ValidatorType _type = _types[i];
            SortedLinkedList.List storage _list = topVotePools[_type];
            if (_list.length < count[_type]) {
                _count += _list.length;
            } else {
                _count += count[_type];
            }
        }

        address[] memory _topValidators = new address[](_count);

        uint8 _index = 0;
        for (uint8 i = 0; i < _types.length; i++) {
            ValidatorType _type = _types[i];
            SortedLinkedList.List storage _list = topVotePools[_type];

            uint8 _size = count[_type];
            IVotePool cur = _list.head;
            while (_size > 0 && cur != IVotePool(0)) {
                _topValidators[_index] = cur.validator();
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

        ValidatorType[2] memory types = [ValidatorType.Pos, ValidatorType.Poa];
        for (uint8 i = 0; i < types.length; i++) {
            uint8 _size = backupCount[types[i]];
            SortedLinkedList.List storage _topList = topVotePools[types[i]];
            IVotePool cur = _topList.head;
            while (_size >= 0 && cur != IVotePool(0)) {
                if (actives[cur.validator()] == 0) {
                    backupValidators.push(cur.validator());
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
                IVotePool _pool = votePools[backupValidators[i]];
                pendingReward[_pool] = pendingReward[_pool].add(_firstPart);
            }
            _left = _left.sub(_firstPart.mul(backupValidators.length));
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote.add(votePools[activeValidators[i]].totalVote());
            }

            uint _secondPartTotal = _totalVote > 0 ? msg.value.mul(40).div(100) : 0;

            uint _thirdPart = _left.sub(_secondPartTotal).div(activeValidators.length);
            for (uint8 i = 0; i < activeValidators.length; i++) {
                IVotePool _pool = votePools[activeValidators[i]];
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
        uint _amount = pendingReward[IVotePool(msg.sender)];
        if (_amount == 0) {
            return;
        }

        pendingReward[IVotePool(msg.sender)] = 0;
        VotePool(msg.sender).receiveReward{value : _amount}();
    }

    function improveRanking()
    external
    onlyRegistered {
        IVotePool _validator = IVotePool(msg.sender);
        require(_validator.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_validator.validatorType()];
        _list.improveRanking(_validator);
    }

    function lowerRanking()
    external
    onlyRegistered {
        IVotePool _validator = IVotePool(msg.sender);
        require(_validator.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_validator.validatorType()];
        _list.lowerRanking(_validator);
    }

    function removeRanking()
    external
    onlyRegistered {
        IVotePool _validator = IVotePool(msg.sender);

        SortedLinkedList.List storage _list = topVotePools[_validator.validatorType()];
        _list.removeRanking(_validator);
    }

    function removeValidatorIncoming(address _validator)
    external
    onlyPunishContract {
        pendingReward[votePools[_validator]] = 0;
    }
}
