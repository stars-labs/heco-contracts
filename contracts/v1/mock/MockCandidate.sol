// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "../Params.sol";
// #else
import "./MockParams.sol";
// #endif
import "../../library/SafeMath.sol";
import "../interfaces/ICandidatePool.sol";
import "../interfaces/IValidator.sol";

contract MockCandidatePool is Params {
    using SafeMath for uint;

    IValidator pool;

    CandidateType public candidateType;

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
        candidateType = _type;
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

    function changeVoteAndRanking(IValidator _pool, uint _vote) external {
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
