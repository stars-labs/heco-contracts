// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
// #if Mainnet
import "./VotePool.sol";
// #else
import "./mock/MockVotePool.sol";
// #endif
import "./library/SortedList.sol";
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";
import "./library/SafeSend.sol";

contract Validators is Params, SafeSend, IValidators {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(ValidatorType => uint8) public count;
    mapping(ValidatorType => uint8) public backupCount;

    address[] activeValidators;
    address[] backupValidators;
    mapping(address => uint8) actives;

    address[] public allValidators;
    mapping(address => IVotePool) public override votePools;

    uint256 rewardLeft;
    mapping(IVotePool => uint) public override pendingReward;

    mapping(ValidatorType => SortedLinkedList.List) topVotePools;

    mapping(uint256 => mapping(Operation => bool)) operationsDone;

    address payable constant burnReceiver = 0x000000000000000000000000000000000000FaaA;
    address payable public foundation;
    uint public foundationReward;
    uint public burnRate;
    uint public foundationRate;

    event ChangeAdmin(address indexed admin);
    event UpdateParams(uint8 posCount, uint8 posBackup, uint8 poaCount, uint8 poaBackup);
    event AddValidator(address indexed validator, address votePool);
    event UpdateRates(uint burnRate, uint foundationRate);
    event UpdateFoundationAddress(address foundation);
    event WithdrawFoundationReward(address receiver, uint amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyFoundation() {
        require(msg.sender == foundation, "Only foundation");
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
            VotePool _pool = new VotePool(_validator, _managers[i], PERCENT_BASE, ValidatorType.Poa, State.Ready);
            allValidators.push(_validator);
            votePools[_validator] = _pool;

            // #if !Mainnet
            _pool.setAddress(address(this), address(0));
            // #endif

            _pool.initialize();
        }
    }

    function changeAdmin(address _newAdmin)
    external
    onlyValidAddress(_newAdmin)
    onlyAdmin {
        admin = _newAdmin;
        emit ChangeAdmin(admin);
    }

    function updateParams(uint8 _posCount, uint8 _posBackup, uint8 _poaCount, uint8 _poaBackup)
    external
    onlyAdmin {
        require(_posCount + _poaCount == MaxValidators, "Invalid counts");
        require(_posBackup <= _posCount && _poaBackup <= _poaCount, "Invalid backup counts");

        count[ValidatorType.Pos] = _posCount;
        count[ValidatorType.Poa] = _poaCount;

        backupCount[ValidatorType.Pos] = _posBackup;
        backupCount[ValidatorType.Poa] = _poaBackup;

        emit UpdateParams(_posCount, _posBackup, _poaCount, _poaBackup);
    }

    function updateRates(uint _burnRate, uint _foundationRate)
    external
    onlyAdmin {
        require(_burnRate.add(_foundationRate) <= PERCENT_BASE, "Invalid rates");

        burnRate = _burnRate;
        foundationRate = _foundationRate;

        emit UpdateRates(_burnRate, _foundationRate);
    }

    function updateFoundation(address payable _foundation)
    external
    onlyAdmin {
        foundation = _foundation;
        emit UpdateFoundationAddress(_foundation);
    }

    function withdrawFoundationReward()
    external
    onlyFoundation {
        uint _val = foundationReward;
        foundationReward = 0;
        sendValue(msg.sender, _val);
        emit WithdrawFoundationReward(msg.sender, _val);
    }

    function addValidator(address _validator, address _manager, uint _percent, ValidatorType _type)
    external
    onlyAdmin
    returns (address) {
        require(votePools[_validator] == IVotePool(0), "Validators already exists");

        VotePool _pool = new VotePool(_validator, _manager, _percent, _type, State.Idle);

        allValidators.push(_validator);
        votePools[_validator] = _pool;

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

        ValidatorType[2] memory _types = [ValidatorType.Pos, ValidatorType.Poa];
        for (uint8 i = 0; i < _types.length; i++) {
            uint8 _size = backupCount[_types[i]];
            SortedLinkedList.List storage _topList = topVotePools[_types[i]];
            IVotePool _cur = _topList.head;
            while (_size > 0 && _cur != IVotePool(0)) {
                if (actives[_cur.validator()] == 0) {
                    backupValidators.push(_cur.validator());
                    _size--;
                }
                _cur = _topList.next[_cur];
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

    function getAllValidatorsLength()
    external
    view
    returns (uint){
        return allValidators.length;
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

        uint burnVal = msg.value.mul(burnRate).div(PERCENT_BASE);
        sendValue(burnReceiver, burnVal);

        uint foundationVal = msg.value.mul(foundationRate).div(PERCENT_BASE);
        foundationReward = foundationReward.add(foundationVal);

        uint _left = msg.value.add(rewardLeft).sub(burnVal).sub(foundationVal);

        // 10% to backups; 40% to validators according to votes; 50% is divided equally among validators
        uint _firstPart = _left.mul(10).div(100);
        uint _secondPartTotal = _left.mul(40).div(100);
        uint _thirdPart = _left.mul(50).div(100);

        if (backupValidators.length > 0) {
            uint _totalBackupVote = 0;
            for (uint8 i = 0; i < backupValidators.length; i++) {
                _totalBackupVote = _totalBackupVote.add(votePools[backupValidators[i]].totalVote());
            }

            if (_totalBackupVote > 0) {
                for (uint8 i = 0; i < backupValidators.length; i++) {
                    IVotePool _pool = votePools[backupValidators[i]];
                    uint256 _reward = _firstPart.mul(_pool.totalVote()).div(_totalBackupVote);
                    pendingReward[_pool] = pendingReward[_pool].add(_reward);
                    _left = _left.sub(_reward);
                }
            }
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote.add(votePools[activeValidators[i]].totalVote());
            }

            for (uint8 i = 0; i < activeValidators.length; i++) {
                IVotePool _pool = votePools[activeValidators[i]];
                uint _reward = _thirdPart.div(activeValidators.length);
                if (_totalVote > 0) {
                    uint _secondPart = _pool.totalVote().mul(_secondPartTotal).div(_totalVote);
                    _reward = _reward.add(_secondPart);
                }

                pendingReward[_pool] = pendingReward[_pool].add(_reward);
                _left = _left.sub(_reward);
            }
        }

        rewardLeft = _left;
    }

    function withdrawReward()
    override
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
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.improveRanking(_pool);
    }

    function lowerRanking()
    external
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.lowerRanking(_pool);
    }

    function removeRanking()
    external
    override
    onlyRegistered {
        IVotePool _pool = IVotePool(msg.sender);

        SortedLinkedList.List storage _list = topVotePools[_pool.validatorType()];
        _list.removeRanking(_pool);
    }

}
