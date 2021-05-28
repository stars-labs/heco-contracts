// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";
import "./interfaces/IPunish.sol";

contract VotePool is Params {
    using SafeMath for uint;

    uint constant PERCENT_BASE = 1000;
    uint constant COEFFICIENT = 1e18;

    ValidatorType public validatorType;

    State public state;

    address public validator;

    address public manager;

    uint public margin;

    //base on 1000
    uint16 public percent;

    PercentChange public pendingPercentChange;

    //reward for this pool not for voters
    uint public poolReward;

    mapping(address => VoterInfo) public voters;

    //use to calc voter's reward
    uint public accRewardPerShare;

    uint public totalVote;

    uint public punishBlk;

    uint public exitBlk;

    struct VoterInfo {
        uint amount;
        uint rewardDebt;
        uint withdrawPendingAmount;
        uint withdrawAnnounceBlock;
    }

    struct PercentChange {
        uint16 newPercent;
        uint submitBlk;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only validator allowed");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager allowed");
        _;
    }

    modifier onlyValidPercent(uint16 _percent) {
        //zero represents null value, trade as invalid
        if (validatorType == ValidatorType.Poa) {
            require(_percent > 0 && _percent <= PERCENT_BASE, "Invalid percent");
        } else {
            require(_percent > 0 && _percent <= PERCENT_BASE.mul(3).div(10), "Invalid percent");
        }
        _;
    }

    event ChangeManager(address indexed manager);
    event SubmitPercentChange(uint16 indexed percent);
    event ConfirmPercentChange(uint16 indexed percent);
    event AddMargin(address indexed sender, uint amount);
    event ChangeState(State indexed state);
    event Exit(address indexed validator);
    event WithdrawMargin(address indexed sender, uint amount);
    event WithdrawPoolReward(address indexed sender, uint amount);
    event WithdrawVoteReward(address indexed sender, uint amount);
    event Deposit(address indexed sender, uint amount);
    event Withdraw(address indexed sender, uint amount);
    event Punish(address indexed validator, uint amount);


    constructor(address _validator, address _manager, uint8 _percent, ValidatorType _type, State _state)
    public
        // #if Mainnet
    onlyValidatorsContract
        // #endif
    onlyValidPercent(_percent) {
        validator = _validator;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = _state;
    }

    // only for chain hard fork to init poa validators
    function initialize()
    external
    onlyValidatorsContract
    onlyNotInitialized {
        initialized = true;
        validatorsContract.improveRanking();
    }


    function changeManager(address _manager)
    external
    onlyValidator {
        manager = _manager;
        emit ChangeManager(_manager);
    }

    //base on 1000
    function submitPercentChange(uint16 _percent)
    external
    onlyManager
    onlyValidPercent(_percent) {
        pendingPercentChange.newPercent = _percent;
        pendingPercentChange.submitBlk = block.number;

        emit SubmitPercentChange(_percent);
    }

    function confirmPercentChange()
    external
    onlyManager
    onlyValidPercent(pendingPercentChange.newPercent) {
        require(pendingPercentChange.submitBlk > 0 && block.number - pendingPercentChange.submitBlk > PercentChangeLockPeriod, "Interval not long enough");

        percent = pendingPercentChange.newPercent;
        pendingPercentChange.newPercent = 0;
        pendingPercentChange.submitBlk = 0;

        emit ConfirmPercentChange(percent);
    }

    function addMargin()
    external
    payable
    onlyManager {
        require(state == State.Idle || (state == State.Jail && block.number - punishBlk > JailPeriod), "Incorrect state");
        require(exitBlk == 0 || block.number - exitBlk > MarginLockPeriod, "Interval not long enough");
        require(msg.value > 0, "Value should not be zero");

        margin += msg.value;

        emit AddMargin(msg.sender, msg.value);

        uint minMargin;
        if (validatorType == ValidatorType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin >= minMargin) {
            state = State.Ready;
            punishContract.cleanPunishRecord(validator);
            emit ChangeState(state);
        }
    }

    function switchState(bool pause)
    external
    onlyValidatorsContract {
        if (pause) {
            require(state == State.Idle || state == State.Ready, "Incorrect state");

            state = State.Pause;
            emit ChangeState(state);
            validatorsContract.removeRanking();
            return;
        } else {
            require(state == State.Pause, "Incorrect state");

            state = State.Idle;
            emit ChangeState(state);
            return;
        }
    }

    function punish()
    external
    onlyPunishContract {
        punishBlk = block.number;

        state = State.Jail;
        emit ChangeState(state);
        validatorsContract.removeRanking();

        uint _punishAmount = margin >= PunishAmount ? PunishAmount : margin;
        if (_punishAmount > 0) {
            margin -= _punishAmount;
            address(0).transfer(_punishAmount);
            emit Punish(validator, _punishAmount);
        }

        return;
    }

    function exit()
    external
    onlyManager {
        require(state == State.Ready, "Incorrect state");
        exitBlk = block.number;

        state = State.Idle;
        emit ChangeState(state);

        validatorsContract.removeRanking();
        emit Exit(validator);
    }

    function withdrawMargin()
    external
    onlyManager {
        require(state == State.Idle, "Incorrect state");
        require(block.number - exitBlk > MarginLockPeriod, "Interval not long enough");
        require(margin > 0, "No more margin");

        uint _amount = margin;
        margin = 0;
        msg.sender.transfer(_amount);
        emit WithdrawMargin(msg.sender, _amount);
    }

    function receiveReward()
    external
    payable
    onlyValidatorsContract {
        uint _rewardForPool = msg.value.mul(percent).div(PERCENT_BASE);
        poolReward += _rewardForPool;
        if (totalVote > 0) {
            accRewardPerShare = msg.value.sub(_rewardForPool).mul(COEFFICIENT).div(totalVote).add(accRewardPerShare);
        }

        //TODO remove it or not ?
        require(poolReward + accRewardPerShare.mul(totalVote).div(COEFFICIENT) <= address(this).balance, "Insufficient balance");
    }

    function withdrawPoolReward()
    external
    payable
    onlyManager {
        validatorsContract.withdrawReward();
        require(poolReward > 0, "No more reward");

        uint _amount = poolReward;
        poolReward = 0;
        msg.sender.transfer(_amount);
        emit WithdrawPoolReward(msg.sender, _amount);
    }

    function getPendingReward(address _voter) external view returns (uint){
        return accRewardPerShare.mul(voters[_voter].amount).div(COEFFICIENT).sub(voters[_voter].rewardDebt);
    }

    function deposit()
    external
    payable {
        validatorsContract.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(COEFFICIENT).sub(voters[msg.sender].rewardDebt);

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(msg.value);
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(COEFFICIENT);
            totalVote = totalVote.add(msg.value);
            emit Deposit(msg.sender, msg.value);

            if (state == State.Ready) {
                validatorsContract.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(COEFFICIENT);
        }

        if (_pendingReward > 0) {
            msg.sender.transfer(_pendingReward);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }

    function announceWithdraw(uint _amount)
    external {
        require(_amount > 0, "Value should not be zero");
        require(_amount <= voters[msg.sender].amount, "Insufficient amount");

        voters[msg.sender].withdrawPendingAmount = _amount;
        voters[msg.sender].withdrawAnnounceBlock = block.number;
    }

    function withdraw()
    external {
        require(block.number - voters[msg.sender].withdrawAnnounceBlock > WithdrawLockPeriod, "Interval too small");
        require(voters[msg.sender].withdrawPendingAmount > 0, "Value should not be zero");
        require(voters[msg.sender].amount >= voters[msg.sender].withdrawPendingAmount, "Insufficient amount");

        validatorsContract.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(COEFFICIENT).sub(voters[msg.sender].rewardDebt);

        uint _amount = voters[msg.sender].withdrawPendingAmount;

        totalVote = totalVote.sub(_amount);

        voters[msg.sender].amount = voters[msg.sender].amount.sub(_amount);
        voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(COEFFICIENT);
        voters[msg.sender].withdrawPendingAmount = 0;
        voters[msg.sender].withdrawAnnounceBlock = 0;

        if (state == State.Ready) {
            validatorsContract.lowerRanking();
        }

        if (_amount > 0) {
            msg.sender.transfer(_amount.add(_pendingReward));
            emit Withdraw(msg.sender, _amount);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }
}
