// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IVotePool.sol";

library SortedLinkedList {
    struct List {
        IVotePool head;
        IVotePool tail;
        uint8 length;
        mapping(IVotePool => IVotePool) prev;
        mapping(IVotePool => IVotePool) next;
    }

    function improveRanking(List storage _list, IVotePool _value)
    internal {
        //insert new
        if (_list.length == 0) {
            _list.head = _value;
            _list.tail = _value;
            _list.length++;
            return;
        }

        //already first
        if (_list.head == _value) {
            return;
        }

        IVotePool _prev = _list.prev[_value];
        // not in list
        if (_prev == IVotePool(0)) {
            //insert new
            _list.length++;

            if (_value.totalVote() <= _list.tail.totalVote()) {
                _list.prev[_value] = _list.tail;
                _list.next[_list.tail] = _value;
                _list.tail = _value;

                return;
            }

            _prev = _list.tail;
        } else {
            if (_value.totalVote() <= _prev.totalVote()) {
                return;
            }

            //remove from list
            _list.next[_prev] = _list.next[_value];
            if (_value == _list.tail) {
                _list.tail = _prev;
            } else {
                _list.prev[_list.next[_value]] = _list.prev[_value];
            }
        }

        while (_prev != IVotePool(0) && _value.totalVote() > _prev.totalVote()) {
            _prev = _list.prev[_prev];
        }

        if (_prev == IVotePool(0)) {
            _list.next[_value] = _list.head;
            _list.prev[_list.head] = _value;
            _list.prev[_value] = IVotePool(0);
            _list.head = _value;
        } else {
            _list.next[_value] = _list.next[_prev];
            _list.prev[_list.next[_prev]] = _value;
            _list.next[_prev] = _value;
            _list.prev[_value] = _prev;
        }
    }


    function lowerRanking(List storage _list, IVotePool _value)
    internal {
        IVotePool _next = _list.next[_value];
        if (_list.tail == _value || _next == IVotePool(0) || _next.totalVote() <= _value.totalVote()) {
            return;
        }

        //remove it
        _list.prev[_next] = _list.prev[_value];
        if (_list.head == _value) {
            _list.head = _next;
        } else {
            _list.next[_list.prev[_value]] = _next;
        }

        while (_next != IVotePool(0) && _next.totalVote() > _value.totalVote()) {
            _next = _list.next[_next];
        }

        if (_next == IVotePool(0)) {
            _list.prev[_value] = _list.tail;
            _list.next[_value] = IVotePool(0);

            _list.next[_list.tail] = _value;
            _list.tail = _value;
        } else {
            _list.next[_list.prev[_next]] = _value;
            _list.prev[_value] = _list.prev[_next];
            _list.next[_value] = _next;
            _list.prev[_next] = _value;
        }
    }


    function removeRanking(List storage _list, IVotePool _value)
    internal {
        if (_list.head != _value && _list.prev[_value] == IVotePool(0)) {
            //not in list
            return;
        }

        if (_list.tail == _value) {
            _list.tail = _list.prev[_value];
        }

        if (_list.head == _value) {
            _list.head = _list.next[_value];
        }

        IVotePool _next = _list.next[_value];
        if (_next != IVotePool(0)) {
            _list.prev[_next] = _list.prev[_value];
        }
        IVotePool _prev = _list.prev[_value];
        if (_prev != IVotePool(0)) {
            _list.next[_prev] = _list.next[_value];
        }

        _list.prev[_value] = IVotePool(0);
        _list.next[_value] = IVotePool(0);
        _list.length--;
    }
}
