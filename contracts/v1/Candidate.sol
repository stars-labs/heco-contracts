// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "../library/SafeMath.sol";
import "./Validator.sol";
import "./interfaces/ICandidate.sol";
import "./interfaces/IValidator.sol";

contract Candidate is Params {
    using SafeMath for uint;

    IValidator pool;

    CandidateType public cType;

    State public state;

    address public candidate;

    address public manager;

    uint public margin;

    //base on 100
    uint8 public percent;

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
        uint8 newPercent;
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

    modifier onlyValidatorsContract() {
        require(msg.sender == address(pool), "Only Validators contract allowed");
        _;
    }

    modifier onlyValidPercent(uint8 _percent) {
        require(_percent > 0, "Invalid percent");
        require(_percent <= 100, "Invalid percent");

        _;
    }

    constructor(address _miner, address _manager, uint8 _percent, CandidateType _type)
    public
//TODO    onlyValidatorsContract
    onlyValidPercent(_percent) {
        pool = IValidator(msg.sender);
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
    }

    //base on 100
    function updatePercent(uint8 _percent)
    external
    onlyManager
    onlyValidPercent(_percent) {
        percentChange.newPercent = _percent;
        percentChange.lastCommitBlk = block.number;
    }

    function confirmPercentChange()
    external
    onlyManager
    onlyValidPercent(percentChange.newPercent) {
        require(block.number - percentChange.lastCommitBlk >= 86400, "Interval not long enough");

        percent = percentChange.newPercent;
        percentChange.newPercent = 0;
    }

    function addMargin()
    external
    payable
    onlyManager {
        require(state == State.Idle || (state == State.Jail && block.number - lastPunishedBlk > JailPeriod), "Incorrect state");
        require(exitBlk == 0 || block.number - exitBlk >= 86400, "Interval not long enough");
        margin += msg.value;

        uint minMargin;
        if (cType == CandidateType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin >= minMargin) {
            state = State.Ready;
        }
    }

    function switchState(bool pause)
    external
    onlyValidatorsContract {
        if (pause && (state == State.Idle || state == State.Ready)) {
            state = State.Pause;
            pool.removeRanking();
            return;
        }

        if (!pause && state == State.Pause) {
            state = State.Idle;
            return;
        }
    }

    function punish()
    external
    onlyPunishContract {
        //TODO
        lastPunishedBlk = block.number;
        state = State.Jail;
        address(0).transfer(margin);

        return;
    }


    function exit()
    external
    onlyManager {
        require(state == State.Ready, "Incorrect state");
        exitBlk = block.number;

        state = State.Idle;

        pool.removeRanking();
    }

    function withdrawMargin()
    external
    onlyManager {
        require(state == State.Idle, "Incorrect state");
        require(block.number - exitBlk >= 86400, "Interval not long enough");
        require(margin > 0, "No more margin");

        uint amount = margin;
        margin = 0;
        msg.sender.transfer(amount);
    }

    function withdrawReward()
    external
    payable
    onlyManager {
        pool.withdrawReward();
        require(reward > 0, "No more margin");

        uint _amount = reward;
        reward = 0;
        msg.sender.transfer(_amount);
    }

    function updateReward()
    external
    payable
    onlyValidatorsContract
    {
        uint rewardForCandidate = msg.value.mul(percent).div(100);
        reward += rewardForCandidate;
        accRewardPerShare = accRewardPerShare.add(msg.value.sub(rewardForCandidate).mul(1e18).div(totalVote));

        //TODO for test
        require(reward + accRewardPerShare.mul(totalVote).div(1e18) <= address(this).balance, "Insufficient balance");
    }


    function addVote()
    external
    payable {
        pool.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(msg.value);
            voters[msg.sender].lastVoteBlk = block.number;
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
            totalVote = totalVote.add(msg.value);

            if (state == State.Ready) {
                pool.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
        }

        if (_pendingReward > 0) {
            msg.sender.transfer(_pendingReward);
        }
    }

    function removeVote()
    external {
// TODO       require(block.number - voters[msg.sender].lastVoteBlk >= 86400, "Interval too small");
        pool.withdrawReward();

        uint _pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        totalVote = totalVote.sub(voters[msg.sender].amount);
        uint _amount = voters[msg.sender].amount + _pendingReward;

        voters[msg.sender].amount = 0;
        voters[msg.sender].rewardDebt = 0;

        if (state == State.Ready) {
            pool.lowerRanking();
        }

        if (_amount > 0) {
            msg.sender.transfer(_amount);
        }
    }
}
