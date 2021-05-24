// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "../Params.sol";
// #else
import "./MockParams.sol";
// #endif
import "../../library/SafeMath.sol";
import "../library/SortedList.sol";
import "../interfaces/ICandidate.sol";
import "../CandidatePool.sol";

contract MockValidator is Params {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(CandidateType => uint8) public count;
    mapping(CandidateType => uint8) public backupCount;

    address[] public activeValidators;
    address[] public backupValidators;

    // candidate address => contract address
    mapping(address => ICandidatePool) public candidates;

    mapping(address => uint) public pendingReward;

    function initialize(address _admin)
    external {
        admin = _admin;

        count[CandidateType.Pos] = 11;
        count[CandidateType.Poa] = 10;
        backupCount[CandidateType.Pos] = 11;
        backupCount[CandidateType.Poa] = 3;
    }

    function addCandidate(address _candidate, address _manager, uint8 _percent, CandidateType _type)
    external
    returns (address) {
        require(candidates[_candidate] == ICandidatePool(0), "Candidate already exists");

        CandidatePool _candidateContract = new CandidatePool(_candidate, _manager, _percent, _type, State.Idle);
        candidates[_candidate] = ICandidatePool(address(_candidateContract));

        return address(_candidateContract);
    }

    function distributeBlockReward()
    external
    payable
    {
        uint _total = 0;
        for (uint8 i = 0; i < activeValidators.length; i++) {
            _total += candidates[activeValidators[i]].totalVote();
        }

        if (_total > 0) {
            for (uint8 i = 0; i < activeValidators.length; i++) {
                ICandidatePool c = candidates[activeValidators[i]];
                pendingReward[address(c)] += c.totalVote().mul(msg.value).div(_total);
            }
        }
    }

    function withdrawReward()
    external {
        uint _amount = pendingReward[msg.sender];
        if (_amount == 0) {
            return;
        }

        pendingReward[msg.sender] = 0;
        CandidatePool(msg.sender).updateReward{value : _amount}();
    }

    function updateActiveValidatorSet(address[] memory newSet) external {
        activeValidators = newSet;
    }

    function improveRanking()
    external {
    }

    function lowerRanking()
    external {
    }

    function removeRanking()
    external {

    }
}
