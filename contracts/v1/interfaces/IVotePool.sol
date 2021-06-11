pragma solidity >=0.6.0 <0.8.0;

interface IVotePool {
    function state() external view returns (State);

    function validatorType() external view returns (ValidatorType);

    function totalVote() external view returns (uint);

    function validator() external view returns (address);

    function switchState(bool pause) external;

    function punish() external;

    function removeValidatorIncoming() external;
}

    enum ValidatorType {
        Pos,
        Poa
    }

    enum State {
        Idle,
        Ready,
        Pause,
        Jail
    }

