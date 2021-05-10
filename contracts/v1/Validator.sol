// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../library/SafeMath.sol";
import "./Candidate.sol";
import "./Params.sol";

contract Validator is Params {
    using SafeMath for uint;

    address public admin;

    mapping(Candidate.CandidateType => uint8) public count;
    mapping(Candidate.CandidateType => uint8) public backupCount;

    address[] activeValidators;
    address[] backupValidators;

    mapping(address => Candidate) public candidates;

    mapping(address => uint) public pendingReward;

    mapping(Candidate.CandidateType => LinkedList) public topCandidates;


    struct LinkedList {
        address head;
        address tail;
        uint8 length;
        mapping(address => address) prev;
        mapping(address => address) next;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        Candidate c = Candidate(msg.sender);
        require(candidates[c.candidate()] == c, "Candidate not registered");
        _;
    }

    function initialize(address _admin) external {
        admin = _admin;

        count[Candidate.CandidateType.Pos] = 11;
        count[Candidate.CandidateType.Poa] = 10;
        backupCount[Candidate.CandidateType.Pos] = 11;
        backupCount[Candidate.CandidateType.Poa] = 3;
    }


    function addValidator(address _miner, address _manager, uint8 _percent, Candidate.CandidateType _type) external onlyAdmin returns (address) {
        require(address(candidates[_miner]) == address(0), "Miner already exists");

        Candidate v = new Candidate(this, _miner, _manager, _percent, _type);
        candidates[_miner] = v;

        //TODO event
        return address(v);
    }


    function getTopValidators() public view returns (address[] memory) {
        uint8 _count = 0;

        Candidate.CandidateType[2] memory types = [Candidate.CandidateType.Pos, Candidate.CandidateType.Poa];

        for(uint8 i=0; i < types.length; i++) {
            Candidate.CandidateType _type = types[i];
            LinkedList storage list = topCandidates[_type];
            if(list.length < count[_type]) {
                _count += list.length;
            }else {
                _count += count[_type];
            }
        }

        address[] memory topValidators = new address[](_count);


        for(uint8 i=0; i < types.length; i++) {
            Candidate.CandidateType _type = types[i];
            LinkedList storage list = topCandidates[_type];


            uint8 size = count[_type];
            address cur = list.head;
            uint8 index = 0;
            while (size > 0 && cur != address(0)) {

                topValidators[index] = Candidate(cur).candidate();
                index++;
                size--;
                cur = list.next[cur];
            }
        }

        return topValidators;
    }

    mapping(address => uint8) actives;
    function updateActiveValidatorSet(address[] memory newSet, uint256 epoch)
        //TODO modifier
    public
    {
        for(uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 0;
        }

        activeValidators = newSet;
        for(uint8 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 1;
        }

        Candidate.CandidateType[2] memory types = [Candidate.CandidateType.Pos, Candidate.CandidateType.Poa];
        for(uint8 i=0; i < types.length; i++) {
            uint8 size = backupCount[types[i]];
            LinkedList storage topList = topCandidates[types[i]];
            address cur = topList.head;
            while (size >= 0 && cur != address(0) && actives[Candidate(cur).candidate()] == 0) {
                backupValidators.push(Candidate(cur).candidate());
                size--;
                cur = topList.next[cur];
            }
        }
    }

    function distributeBlockReward()
    external
    payable
    {
        //TODO
        uint total = 0;
        for (uint8 i = 0; i < activeValidators.length; i++) {
            total += candidates[activeValidators[i]].totalVote();
        }

        if (total > 0) {
            for (uint8 i = 0; i < activeValidators.length; i++) {
                Candidate c = candidates[activeValidators[i]];
                pendingReward[address(c)] += c.totalVote().mul(msg.value).div(total);
            }
        }
    }

    function withdrawReward() external {
        uint amount = pendingReward[msg.sender];
        if (amount == 0) {
            return;
        }

        pendingReward[msg.sender] = 0;
        Candidate(msg.sender).updateReward{value : amount}();
    }


    function updateParams(uint8 _posCount, uint8 _posBackup, uint8 _poaCount, uint8 _poaBackup) external onlyAdmin {

    }

    function updateCandidateState(address _miner, bool pause) external onlyAdmin {
        require(address(candidates[_miner]) != address(0), "Corresponding candidate not found");
        candidates[_miner].switchState(pause);
    }

    function improveRanking() external onlyRegistered {
        Candidate c = Candidate(msg.sender);
        require(c.state() == Candidate.State.Ready, "Incorrect state");

        //TODO check status check length
        LinkedList storage curList = topCandidates[c.cType()];

        //insert new
        if (curList.length == 0) {
            curList.head = address(c);
            curList.tail = address(c);
            curList.length++;
            return;
        }

        if (curList.head == address(c)) {
            return;
        }

        address prev = curList.prev[address(c)];
        if (prev == address(0)) {
            //insert new
            curList.length++;

            if (c.totalVote() < Candidate(curList.tail).totalVote()) {
                curList.prev[address(c)] = curList.tail;
                curList.next[curList.tail] = address(c);
                curList.tail = address(c);

                return;
            }

            prev = curList.tail;
        } else {
            //already exist
            if (c.totalVote() <= Candidate(prev).totalVote()) {
                return;
            }

            //remove from list
            curList.next[prev] = curList.next[address(c)];
            if (address(c) == curList.tail) {
                curList.tail = prev;
            } else {
                curList.prev[curList.next[address(c)]] = curList.prev[address(c)];
            }
        }

        while (prev != address(0) && c.totalVote() > Candidate(prev).totalVote()) {
            prev = curList.prev[prev];
        }

        if (prev == address(0)) {
            curList.next[address(c)] = curList.head;
            curList.prev[curList.head] = address(c);
            curList.prev[address(c)] = address(0);
            curList.head = address(c);
            return;
        } else {
            curList.next[address(c)] = curList.next[prev];
            curList.prev[curList.next[prev]] = address(c);
            curList.next[prev] = address(c);
            curList.prev[address(c)] = prev;
        }

    }

    function lowerRanking() external onlyRegistered {
        Candidate c = Candidate(msg.sender);
        require(c.state() == Candidate.State.Ready, "Incorrect state");

        LinkedList storage curList = topCandidates[c.cType()];

        address next = curList.next[address(c)];
        if (curList.tail == address(c) || next == address(0) || Candidate(next).totalVote() <= c.totalVote()) {
            return;
        }

        //remove it
        curList.prev[next] = curList.prev[address(c)];
        if (curList.head == address(c)) {
            curList.head = next;
        } else {
            curList.next[curList.prev[address(c)]] = next;
        }

        while (next != address(0) && Candidate(next).totalVote() > c.totalVote()) {
            next = curList.next[next];
        }

        if (next == address(0)) {
            curList.prev[address(c)] = curList.tail;
            curList.next[address(c)] = address(0);

            curList.next[curList.tail] = address(c);
            curList.tail = address(c);
        } else {
            curList.next[curList.prev[next]] = address(c);
            curList.prev[address(c)] = curList.prev[next];
            curList.next[address(c)] = next;
            curList.prev[next] = address(c);
        }
    }


    function removeRanking() external onlyRegistered {
        Candidate c = Candidate(msg.sender);

        LinkedList storage curList = topCandidates[c.cType()];

        if(curList.head != address(c) && curList.prev[address(c)] == address(0)) {
            //not in list
            return;
        }

        if (curList.tail == address(c)) {
            curList.tail = curList.prev[address(c)];
        }

        if(curList.head == address(c)) {
            curList.head = curList.next[address(c)];
        }

        address next = curList.next[address(c)];
        if(next != address(0)) {
            curList.prev[next] = curList.prev[address(c)];
        }
        address prev = curList.prev[address(c)];
        if(prev != address(0)) {
            curList.next[prev] = curList.next[address(c)];
        }

        curList.prev[address(c)] = address(0);
        curList.next[address(c)] = address(0);
        curList.length--;
    }
}
