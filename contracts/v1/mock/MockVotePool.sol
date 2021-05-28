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

contract MockVotePool is Params {
    using SafeMath for uint;

    IValidators pool;

    ValidatorType public validatorType;

    State public state;

    uint public percent;

    address public validator;

    address public manager;

    uint public totalVote;

    constructor(address _miner, address _manager, uint8 _percent, ValidatorType _type)
    public {
        pool = IValidators(msg.sender);
        validator = _miner;
        manager = _manager;
        percent = _percent;
        validatorType = _type;
        state = State.Ready;
    }

    function switchState(bool pause)
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

    function changeVoteAndRanking(IValidators _pool, uint _vote) external {
        totalVote = _vote;

        if (_vote > totalVote) {
            _pool.improveRanking();
        } else {
            _pool.lowerRanking();
        }
    }

    function changeState(State _state) external {
        state = _state;
    }
}
