pragma solidity >=0.6.0 <0.8.0;

interface ICandidate {
    function totalVote() external view returns(uint);
    function candidate() external view returns(address);
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

