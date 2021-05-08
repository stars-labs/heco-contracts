// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../library/SafeMath.sol";
import "./Candidate.sol";

contract Validator {
    using SafeMath for uint;

    address public admin;

    uint8 public  posCount;
    uint8 public posBackup;
    uint8 public poaCount;
    uint8  public poaBackup;

    address[] activeValidators;
    address[] backupValidators;

    mapping(address => Candidate) public candidates;

    mapping(address => uint) public pendingReward;

    mapping(Candidate.CandidateType => LinkedList) topCandidates;
    // LinkedList topPoaCandidates;
    // LinkedList topPosCandidates;


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
    }


    function addValidator(address _miner, address _manager, uint8 _percent, Candidate.CandidateType _type) external onlyAdmin returns (address) {
        require(address(candidates[_miner]) == address(0), "Miner already exists");

        Candidate v = new Candidate(this, _miner, _manager, _percent, _type);
        candidates[_miner] = v;

        //TODO event
        return address(v);
    }


    function getTopValidators() public view returns (address[] memory) {

        address[] memory topValidators = new address[](21);
        uint8 index = 0;

        // //find out top 21
        // uint8 size = posCount;
        // address cur = topPosCandidates.head;
        // while (size >= 0 && cur != address(0)) {

        //     topValidators[index] = Candidate(cur).miner();
        //     index++;
        //     size--;
        //     cur = topPosCandidates.next[cur];
        // }

        // size = poaCount;
        // cur = topPoaCandidates.head;
        // while (size >= 0 && cur != address(0)) {
        //     topValidators[index] = Candidate(cur).miner();
        //     index++;

        //     size--;
        //     cur = topPoaCandidates.next[cur];
        // }

        return topValidators;
    }

    function updateActiveValidatorSet(address[] memory newSet, uint256 epoch)
        //TODO modifier
    public
    {
        activeValidators = newSet;

        //TODO
        // //find out backupValidators
        // mapping(address => uint8) storage actives;
        // for (uint8 i = 0; i < newSet.length; i++) {
        //     actives[newSet[i]] = 1;
        // }

        // uint8 size = posBackup;
        // Candidate cur = topPosCandidates.header;
        // while (size >= 0 && cur.candidate != address(0) && actives[cur.candidate.miner()] == 0) {
        //     backupValidators.push(cur.candidate.miner());
        //     size--;
        //     cur = topPosCandidates.next[cur];
        // }

        // size = poaBackup;
        // cur = topPoaCandidates.header;
        // while (size >= 0 && cur.candidate != address(0) && actives[cur.candidate.miner()] == 0) {
        //     backupValidators.push(cur.candidate.miner());
        //     size--;
        //     cur = cur.next;
        // }
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

    function updateCandidateState(address _miner, Candidate.State state) external onlyAdmin {
        //TODO only idle pause
    }

    function addNew(LinkedList storage l, Candidate c) internal {
        if (l.length == 0) {
            l.head = address(c);
            l.tail = address(c);
            l.length++;
            return;
        }

        if (c.totalVote() < Candidate(l.tail).totalVote()) {
            l.prev[address(c)] = l.tail;
            l.next[l.tail] = address(c);
            l.tail = address(c);
            l.length++;
            return;
        }

        address prev = l.tail;

        while (prev != address(0)) {
            if (prev == l.head) {
                l.next[address(c)] = l.head;
                l.prev[l.head] = address(c);
                l.head = address(c);
                l.length++;
                return;
            }
        }
    }


    function improveRanking() external onlyRegistered {
        Candidate c = Candidate(msg.sender);

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
            if (c.totalVote() < Candidate(prev).totalVote()) {
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

        LinkedList storage curList = topCandidates[c.cType()];

        if (curList.tail == address(c)) {
            return;
        }

        address next = curList.next[address(c)];
        if (Candidate(next).totalVote() < c.totalVote()) {
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

    }

}
