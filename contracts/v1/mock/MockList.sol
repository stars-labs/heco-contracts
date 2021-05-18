// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/ICandidate.sol";
import "../library/SortedList.sol";

contract MockList {
    using SortedLinkedList for SortedLinkedList.List;

    SortedLinkedList.List public list;

    function improveRanking(ICandidate _value) external {
        list.improveRanking(_value);
    }

    function lowerRanking(ICandidate _value) external {
        list.lowerRanking(_value);
    }

    function removeRanking(ICandidate _value) external {
        list.removeRanking(_value);
    }

    function prev(ICandidate _value) view external returns(ICandidate){
        return list.prev[_value];
    }

    function next(ICandidate _value) view external returns(ICandidate){
        return list.next[_value];
    }

    function clear() external {
        ICandidate _tail = list.tail;

        while(_tail != ICandidate(0)) {
            ICandidate _prev = list.prev[_tail];
            list.removeRanking(_tail);
            _tail = _prev;
        }
    }

}
