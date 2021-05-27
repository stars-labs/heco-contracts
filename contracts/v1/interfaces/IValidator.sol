pragma solidity >=0.6.0 <0.8.0;

import "./ICandidatePool.sol";

interface IValidator {
    function improveRanking() external ;
    function lowerRanking() external ;
    function removeRanking() external;
    function withdrawReward() external ;
    function candidatePools(address candidate) external view returns (ICandidatePool);
    function removeValidatorIncoming(address candidate) external;
}

enum Operation {Distribute, UpdateValidators}
