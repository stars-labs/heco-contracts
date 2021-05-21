pragma solidity >=0.6.0 <0.8.0;

interface ICandidatePool {
    function state() external view returns (State);

    function cType() external view returns (CandidateType);

    function totalVote() external view returns (uint);

    function candidate() external view returns (address);

    function switchState(bool pause) external;

    function punish() external;

    function addMargin() payable external;

    function deposit() payable external;

}

    enum CandidateType {
        Pos,
        Poa
    }

    enum State {
        Idle,
        Ready,
        Pause,
        Jail
    }

