// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
import "./interfaces/ICandidatePool.sol";
import "./interfaces/IValidator.sol";
import "./interfaces/IPunish.sol";

contract CandidatePool is Params {
    using SafeMath for uint;

    uint constant PERCENT_BASE = 1000;
    uint constant COEFFICIENT = 1e18;

    CandidateType public candidateType;

    State public state;

    address public candidate;

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
        uint lastVoteBlk;
    }

    struct PercentChange {
        uint16 newPercent;
        uint submitBlk;
    }

    modifier onlyCandidate() {
        require(msg.sender == candidate, "Only candidate allowed");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == manager, "Only manager allowed");
        _;
    }

    modifier onlyValidPercent(uint16 _percent) {
        //zero represents null value, trade as invalid
        require(_percent > 0 && _percent <= PERCENT_BASE, "Invalid percent");
        _;
    }

    event ChangeManager(address indexed manager);
    event SubmitPercentChange(uint16 indexed percent);
    event ConfirmPercentChange(uint16 indexed percent);
    event AddMargin(address indexed sender, uint amount);
    event ChangeState(State indexed state);
    event Exit(address indexed candidate);
    event WithdrawMargin(address indexed sender, uint amount);
    event WithdrawPoolReward(address indexed sender, uint amount);
    event WithdrawVoteReward(address indexed sender, uint amount);
    event Deposit(address indexed sender, uint amount);
    event Withdraw(address indexed sender, uint amount);
    event Punish(address indexed candidate, uint amount);


    constructor(address _miner, address _manager, uint8 _percent, CandidateType _type, State _state)
    public
        // #if Mainnet
    onlyValidatorsContract
        // #endif
    onlyValidPercent(_percent) {
        candidate = _miner;
        manager = _manager;
        percent = _percent;
        candidateType = _type;
        state = _state;
    }

    // only for chain hard fork to init poa validators
    function initialize()
    external
    onlyValidatorsContract
    onlyNotInitialized {
        initialized = true;
        validatorContract.improveRanking();
    }


    function changeManager(address _manager)
    external
    onlyCandidate {
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
        require(pendingPercentChange.submitBlk > 0 && block.number - pendingPercentChange.submitBlk > LockPeriod, "Interval not long enough");

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
        require(exitBlk == 0 || block.number - exitBlk > LockPeriod, "Interval not long enough");
        require(msg.value > 0, "Value should not be zero");

        margin += msg.value;

        emit AddMargin(msg.sender, msg.value);

        uint minMargin;
        if (candidateType == CandidateType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin >= minMargin) {
            state = State.Ready;
            punishContract.cleanPunishRecord(candidate);
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
            validatorContract.removeRanking();
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
        //        require(margin >= PunishAmount, "No enough margin left");
        punishBlk = block.number;

        state = State.Jail;
        emit ChangeState(state);
        validatorContract.removeRanking();

        uint _punishAmount = margin >= PunishAmount ? PunishAmount : margin;
        if (_punishAmount > 0) {
            margin -= _punishAmount;
            address(0).transfer(_punishAmount);
            emit Punish(candidate, _punishAmount);
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

        validatorContract.removeRanking();
        emit Exit(candidate);
    }

    function withdrawMargin()
    external
    onlyManager {
        require(state == State.Idle, "Incorrect state");
        require(block.number - exitBlk > LockPeriod, "Interval not long enough");
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
        validatorContract.withdrawReward();
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
        validatorContract.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(COEFFICIENT).sub(voters[msg.sender].rewardDebt);

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(msg.value);
            voters[msg.sender].lastVoteBlk = block.number;
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(COEFFICIENT);
            totalVote = totalVote.add(msg.value);
            emit Deposit(msg.sender, msg.value);

            if (state == State.Ready) {
                validatorContract.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(COEFFICIENT);
        }

        if (_pendingReward > 0) {
            msg.sender.transfer(_pendingReward);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }

    function withdraw()
    external {
        require(block.number - voters[msg.sender].lastVoteBlk > LockPeriod, "Interval too small");
        validatorContract.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(COEFFICIENT).sub(voters[msg.sender].rewardDebt);

        totalVote = totalVote.sub(voters[msg.sender].amount);
        uint _amount = voters[msg.sender].amount;

        voters[msg.sender].amount = 0;
        voters[msg.sender].rewardDebt = 0;

        if (state == State.Ready) {
            validatorContract.lowerRanking();
        }

        if (_amount > 0) {
            msg.sender.transfer(_amount.add(_pendingReward));
            emit Withdraw(msg.sender, _amount);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }
}
