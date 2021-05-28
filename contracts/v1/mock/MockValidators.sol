// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "../Params.sol";
// #else
import "./MockParams.sol";
// #endif
import "../../library/SafeMath.sol";
import "../library/SortedList.sol";
import "../interfaces/IVotePool.sol";
import "../VotePool.sol";

contract MockValidators is Params {
    using SafeMath for uint;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    mapping(ValidatorType => uint8) public count;
    mapping(ValidatorType => uint8) public backupCount;

    address[] public activeValidators;
    address[] public backupValidators;

    // validator address => contract address
    mapping(address => IVotePool) public votePools;

    mapping(address => uint) public pendingReward;

    function initialize(address _admin)
    external {
        admin = _admin;

        count[ValidatorType.Pos] = 11;
        count[ValidatorType.Poa] = 10;
        backupCount[ValidatorType.Pos] = 11;
        backupCount[ValidatorType.Poa] = 3;
    }

    function addValidator(address _validator, address _manager, uint8 _percent, ValidatorType _type)
    external
    returns (address) {
        require(votePools[_validator] == IVotePool(0), "Validators already exists");

        VotePool _validatorsContract = new VotePool(_validator, _manager, _percent, _type, State.Idle);
        votePools[_validator] = IVotePool(address(_validatorsContract));

        return address(_validatorsContract);
    }

    function distributeBlockReward()
    external
    payable
    {
        uint _total = 0;
        for (uint8 i = 0; i < activeValidators.length; i++) {
            _total += votePools[activeValidators[i]].totalVote();
        }

        if (_total > 0) {
            for (uint8 i = 0; i < activeValidators.length; i++) {
                IVotePool c = votePools[activeValidators[i]];
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
        VotePool(msg.sender).receiveReward{value : _amount}();
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
