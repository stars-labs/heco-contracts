// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../Params.sol";
import "../../library/SafeMath.sol";
import "../interfaces/ICandidate.sol";
import "../interfaces/IValidator.sol";

contract MockCandidate is Params {
    using SafeMath for uint;

    IValidator pool;

    CandidateType public cType;

    State public state;

    uint public percent;

    address public candidate;

    address public manager;

    uint public totalVote;

    constructor(address _miner, address _manager, uint8 _percent, CandidateType _type)
    public {
        pool = IValidator(msg.sender);
        candidate = _miner;
        manager = _manager;
        percent = _percent;
        cType = _type;
        state = State.Ready;
    }

    function switchState(bool pause)
    external {
    }

    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

    function changeVoteAndRanking(IValidator _pool, uint _vote) external {
        totalVote = _vote;

        if(_vote > totalVote) {
            _pool.improveRanking();
        } else {
            _pool.lowerRanking();
        }
    }

    function changeState(State _state) external {
        state = _state;
    }
}
