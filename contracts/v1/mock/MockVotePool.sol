// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "../Params.sol";
// #else
import "./MockParams.sol";
// #endif
import "../../library/SafeMath.sol";
import "../interfaces/IVotePool.sol";
import "../interfaces/IValidators.sol";

contract VotePool is Params, IVotePool {
    using SafeMath for uint;

    IValidators pool;

    ValidatorType public override validatorType;

    State public override state;

    uint public percent;

    address public override validator;

    address public manager;

    uint public override totalVote;

    constructor(address _miner, address _manager, uint _percent, ValidatorType _type, State _state)
    public {
        pool = IValidators(msg.sender);
        validator = _miner;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = _state;
    }

    function initialize()
    external {
        initialized = true;
        validatorsContract.improveRanking();
    }

    function switchState(bool pause)
    override
    external {
    }

    function addMargin()
    external
    payable
    {
    }

    function deposit()
    external
    payable {
    }

    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

    function changeVoteAndRanking(IValidators validators, uint _vote) external {

        if (_vote > totalVote) {
            totalVote = _vote;
            validators.improveRanking();
        } else {
            totalVote = _vote;
            validators.lowerRanking();
        }
    }

    function changeState(State _state) external {
        state = _state;
    }


    function punish()
    external
    override {

    }

    function removeValidatorIncoming()
    external
    override {

    }

    function receiveReward()
    external
    payable {
    }

}
