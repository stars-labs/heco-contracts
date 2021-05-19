// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "../library/SafeMath.sol";
import "./interfaces/ICandidate.sol";
import "./interfaces/IValidator.sol";
import "./interfaces/IPunish.sol";

contract Candidate is Params {
    using SafeMath for uint;

    CandidateType public cType;

    State public state;

    address public candidate;

    address public manager;

    uint public margin;

    //base on 1000
    uint16 public percent;

    uint public reward;

    mapping(address => VoterInfo) public voters;

    uint public accRewardPerShare;

    uint public totalVote;

    uint public lastPunishedBlk;

    uint public exitBlk;

    PercentChange public percentChange;

    struct VoterInfo {
        uint amount;
        uint rewardDebt;
        uint lastVoteBlk;
    }

    struct PercentChange {
        uint16 newPercent;
        uint lastCommitBlk;
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
        require(_percent > 0, "Invalid percent");
        require(_percent <= 1000, "Invalid percent");

        _;
    }

    event ChangeManager(address indexed manager);
    event UpdatingPercent(uint16 indexed percent);
    event ConfirmPercentChange(uint16 indexed percent);
    event AddMargin(address indexed sender, uint amount);
    event ChangeState(State state);
    event ExitVote();
    event WithdrawMargin(address indexed sender, uint amount);
    event WithdrawReward(address indexed sender, uint amount);
    event Deposit(address indexed sender, uint amount);
    event Withdraw(address indexed sender, uint amount);


    constructor(address _miner, address _manager, uint8 _percent, CandidateType _type)
    public
    // #if Mainnet
    onlyValidatorsContract
    // #endif
    onlyValidPercent(_percent) {

        candidate = _miner;
        manager = _manager;
        percent = _percent;
        cType = _type;
        state = State.Idle;
    }


    function changeManager(address _manager)
    external
    onlyCandidate {
        manager = _manager;
        emit ChangeManager(_manager);
    }

    //base on 1000
    function updatePercent(uint16 _percent)
    external
    onlyManager
    onlyValidPercent(_percent) {
        percentChange.newPercent = _percent;
        percentChange.lastCommitBlk = block.number;

        emit UpdatingPercent(_percent);
    }

    function confirmPercentChange()
    external
    onlyManager
    onlyValidPercent(percentChange.newPercent) {
        require(percentChange.lastCommitBlk > 0 && block.number - percentChange.lastCommitBlk >= LockPeriod, "Interval not long enough");

        percent = percentChange.newPercent;
        percentChange.newPercent = 0;
        percentChange.lastCommitBlk = 0;

        emit ConfirmPercentChange(percent);
    }

    function addMargin()
    external
    payable
    onlyManager {
        require(state == State.Idle || (state == State.Jail && block.number - lastPunishedBlk > JailPeriod), "Incorrect state");
        require(exitBlk == 0 || block.number - exitBlk >= LockPeriod, "Interval not long enough");
        margin += msg.value;

        emit AddMargin(msg.sender, msg.value);

        uint minMargin;
        if (cType == CandidateType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin >= minMargin) {
            state = State.Ready;
            punishcontract.cleanPunishRecord(candidate);
            emit ChangeState(state);
        }
    }

    function switchState(bool pause)
    external
    onlyValidatorsContract {
        if (pause && (state == State.Idle || state == State.Ready)) {
            state = State.Pause;
            emit ChangeState(state);
            validator.removeRanking();
            return;
        }

        if (!pause && state == State.Pause) {
            state = State.Idle;
            emit ChangeState(state);
            return;
        }
    }

    function punish()
    external
    onlyPunishContract {
        require(margin >= PunishAmount, "No enough margin left");
        lastPunishedBlk = block.number;
        state = State.Jail;
        validator.removeRanking();
        margin -= PunishAmount;
        address(0).transfer(PunishAmount);

        return;
    }

    function exit()
    external
    onlyManager {
        require(state == State.Ready, "Incorrect state");
        exitBlk = block.number;

        state = State.Idle;
        emit ChangeState(state);

        validator.removeRanking();
        emit ExitVote();
    }

    
    function withdrawMargin()
    external
    onlyManager {
        require(state == State.Idle, "Incorrect state");
        require(block.number - exitBlk >= LockPeriod, "Interval not long enough");
        require(margin > 0, "No more margin");

        uint _amount = margin;
        margin = 0;
        msg.sender.transfer(_amount);
        emit WithdrawMargin(msg.sender, _amount);
    }


    function withdrawReward()
    external
    payable
    onlyManager {
        validator.withdrawReward();
        require(reward > 0, "No more margin");

        uint _amount = reward;
        reward = 0;
        msg.sender.transfer(_amount);
        emit WithdrawReward(msg.sender, _amount);
    }

    function updateReward()
    external
    payable
    onlyValidatorsContract
    {
        uint rewardForCandidate = msg.value.mul(percent).div(1000);
        reward += rewardForCandidate;
        accRewardPerShare = accRewardPerShare.add(msg.value.sub(rewardForCandidate).mul(1e18).div(totalVote));

        require(reward + accRewardPerShare.mul(totalVote).div(1e18) <= address(this).balance, "Insufficient balance");
    }

    function deposit()
    external
    payable {
        validator.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(msg.value);
            voters[msg.sender].lastVoteBlk = block.number;
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
            totalVote = totalVote.add(msg.value);

            if (state == State.Ready) {
                validator.improveRanking();
            }
            emit Deposit(msg.sender, msg.value);
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
        }

        if (_pendingReward > 0) {
            msg.sender.transfer(_pendingReward);
            emit WithdrawReward(msg.sender, _pendingReward);
        }
    }

    function withdraw()
    external {
        require(block.number - voters[msg.sender].lastVoteBlk >= LockPeriod, "Interval too small");
        validator.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        totalVote = totalVote.sub(voters[msg.sender].amount);
        uint _amount = voters[msg.sender].amount + _pendingReward;

        voters[msg.sender].amount = 0;
        voters[msg.sender].rewardDebt = 0;

        if (state == State.Ready) {
            validator.lowerRanking();
        }

        if (_amount > 0) {
            msg.sender.transfer(_amount);
            emit Withdraw(msg.sender, _amount);
        }
    }
}
