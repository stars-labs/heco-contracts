pragma solidity >=0.6.0 <0.8.0;

import "./ICandidate.sol";

interface IValidator {
    function improveRanking() external ;
    function lowerRanking() external ;
    function removeRanking() external;
    function withdrawReward() external ;
    function candidates(address candidate) external view returns (ICandidate);
}
