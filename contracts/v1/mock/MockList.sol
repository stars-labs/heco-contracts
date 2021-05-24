// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/ICandidate.sol";
import "../library/SortedList.sol";

contract MockList {
    using SortedLinkedList for SortedLinkedList.List;

    SortedLinkedList.List public list;

    function improveRanking(ICandidatePool _value) external {
        list.improveRanking(_value);
    }

    function lowerRanking(ICandidatePool _value) external {
        list.lowerRanking(_value);
    }

    function removeRanking(ICandidatePool _value) external {
        list.removeRanking(_value);
    }

    function prev(ICandidatePool _value) view external returns(ICandidatePool){
        return list.prev[_value];
    }

    function next(ICandidatePool _value) view external returns(ICandidatePool){
        return list.next[_value];
    }

    function clear() external {
        ICandidatePool _tail = list.tail;

        while(_tail != ICandidatePool(0)) {
            ICandidatePool _prev = list.prev[_tail];
            list.removeRanking(_tail);
            _tail = _prev;
        }
    }

}
