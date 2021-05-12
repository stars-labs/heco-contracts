// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "../library/SafeMath.sol";
import "./Validator.sol";
import "./interfaces/ICandidate.sol";

contract Candidate is Params {
    using SafeMath for uint;

    Validator pool;

    address public candidate;

    address public manager;

    //base on 100
    uint8 public percent;

    uint public accRewardPerShare;

    uint public totalVote;

    uint public margin;

    uint public reward;

    uint public lastPunishedBlk;

    CandidateType public cType;

    State public state;

    mapping(address => VoterInfo) public voters;

    struct VoterInfo {
        uint amount;
        uint rewardDebt;
        uint lastVoteBlk;
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
        require(
            msg.sender == address(pool),
            "Validators contract only"
        );
        _;
    }

    constructor(Validator _pool, address _miner, address _manager, uint8 _percent, CandidateType _type) public {
        require(_percent <= 100, "Invalid percent");

        pool = _pool;
        candidate = _miner;
        manager = _manager;
        percent = _percent;
        cType = _type;
        state = State.Idle;
    }

    function changeManager(address _manager) external onlyCandidate {
        manager = _manager;
    }

    struct PercentChange{
        uint8 newPercent;
        uint lastCommitBlk;
    }

    PercentChange percentChange;

    //base on 100
    function updatePercent(uint8 _percent) external onlyManager {
        require(_percent > 0, "Invalid percent");
        require(_percent <= 100, "Invalid percent");
        percentChange.newPercent = _percent;
        percentChange.lastCommitBlk = block.number;
    }

    function confirmPercentChange() external onlyManager {
        require(block.number - percentChange.lastCommitBlk >= 86400, "Interval not long enough");
        require(percentChange.newPercent > 0, "No commited percent info");

        percent = percentChange.newPercent;
        percentChange.newPercent = 0;
    }

    function addMargin() external payable onlyManager {
        require(state == State.Idle || (state == State.Jail && block.number - lastPunishedBlk > JailPeriod), "Incorrect state");
        require(exitBlk == 0 || block.number - exitBlk >= 86400, "Interval not long enough");
        margin += msg.value;

        uint minMargin;
        if (cType == CandidateType.Poa) {
            minMargin = PoaMinMargin;
        } else {
            minMargin = PosMinMargin;
        }

        if (margin > minMargin) {
            state = State.Ready;
        }
    }
    
    function switchState(bool pause) external onlyValidatorsContract {
        if(pause && (state == State.Idle || state == State.Ready)) {
            state = State.Pause;
            pool.removeRanking();
            return;
        }

        if(!pause && state == State.Pause) {
            state = State.Idle;
            return;
        }
    }

    function punish() external onlyPunishContract {
        lastPunishedBlk = block.number;
        state = State.Jail;
        address(0).transfer(margin);

        return;
    }

    uint exitBlk;
    function exit() external onlyManager {
        require(state == State.Ready, "Incorrect state");
        exitBlk = block.number;

        state = State.Idle;

        pool.removeRanking();
    }

    function withdrawMargin() external onlyManager {
        require(state == State.Idle, "Incorrect state");
        require(block.number - exitBlk >= 86400, "Interval not long enough");

        if (margin > 0) {
            uint amount = margin;
            margin = 0;
            msg.sender.transfer(amount);
        }
    }

    function withdrawReward() external payable onlyManager {
        pool.withdrawReward();

        if (reward > 0) {
            uint amount = reward;
            reward = 0;
            msg.sender.transfer(amount);
        }
    }

    function updateReward() external payable {
        uint forCandidate = msg.value.mul(percent).div(100);
        reward += forCandidate;
        accRewardPerShare = accRewardPerShare.add(msg.value.sub(forCandidate).mul(1e18).div(totalVote));

        //TODO for test
        require(reward + accRewardPerShare.mul(totalVote).div(1e18) <= address(this).balance, "Insufficent balance");
    }


    function addVote() external payable {
        //take care of fallback
        pool.withdrawReward();

        uint pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        if(msg.amount > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount.add(msg.value);
            voters[msg.sender].lastVoteBlk = block.number;
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
            totalVote = totalVote.add(msg.value);

            if(state == State.Ready) {
              pool.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount.mul(accRewardPerShare).div(1e18);
        }

        if (pendingReward > 0) {
            msg.sender.transfer(pendingReward);
        }
    }

    function removeVote() external {
        // require(block.number - voters[msg.sender].lastVoteBlk >= 86400, "Interval too small");
        pool.withdrawReward();

        uint pendingReward = accRewardPerShare.mul(voters[msg.sender].amount).div(1e18).sub(voters[msg.sender].rewardDebt);

        totalVote = totalVote.sub(voters[msg.sender].amount);
        uint amount = voters[msg.sender].amount + pendingReward;

        voters[msg.sender].amount = 0;
        voters[msg.sender].lastVoteBlk = block.number;
        voters[msg.sender].rewardDebt = 0;

        if(state == State.Ready) {
            pool.lowerRanking();
        }

        if (amount > 0) {
            msg.sender.transfer(amount);
        }
    }
}
