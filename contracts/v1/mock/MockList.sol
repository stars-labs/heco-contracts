// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IVotePool.sol";
import "../library/SortedList.sol";

contract MockList {
    using SortedLinkedList for SortedLinkedList.List;

    SortedLinkedList.List public list;

    function improveRanking(IVotePool _value) external {
        list.improveRanking(_value);
    }

    function lowerRanking(IVotePool _value) external {
        list.lowerRanking(_value);
    }

    function removeRanking(IVotePool _value) external {
        list.removeRanking(_value);
    }

    function prev(IVotePool _value) view external returns(IVotePool){
        return list.prev[_value];
    }

    function next(IVotePool _value) view external returns(IVotePool){
        return list.next[_value];
    }

    function clear() external {
        IVotePool _tail = list.tail;

        while(_tail != IVotePool(0)) {
            IVotePool _prev = list.prev[_tail];
            list.removeRanking(_tail);
            _tail = _prev;
        }
    }

}
