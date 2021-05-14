pragma solidity >=0.6.0 <0.8.0;

interface ICandidate {
    function totalVote() external view returns(uint);
    function candidate() external view returns(address);
    function switchState(bool pause) external;
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

