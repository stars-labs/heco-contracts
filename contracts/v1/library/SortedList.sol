// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/ICandidate.sol";

library SortedLinkedList {
    struct List {
        ICandidate head;
        ICandidate tail;
        uint8 length;
        mapping(ICandidate => ICandidate) prev;
        mapping(ICandidate => ICandidate) next;
    }

    function improveRanking(List storage curList, ICandidate c) internal {
        //insert new
        if (curList.length == 0) {
            curList.head = c;
            curList.tail = c;
            curList.length++;
            return;
        }

        //already first
        if (curList.head == c) {
            return;
        }

        ICandidate prev = curList.prev[c];
        // not in list
        if (prev == ICandidate(0)) {
            //insert new
            curList.length++;

            if (c.totalVote() <= curList.tail.totalVote()) {
                curList.prev[c] = curList.tail;
                curList.next[curList.tail] = c;
                curList.tail = c;

                return;
            }

            prev = curList.tail;
        } else {
            if (c.totalVote() <= prev.totalVote()) {
                return;
            }

            //remove from list
            curList.next[prev] = curList.next[c];
            if (c == curList.tail) {
                curList.tail = prev;
            } else {
                curList.prev[curList.next[c]] = curList.prev[c];
            }
        }

        while (prev != ICandidate(0) && c.totalVote() > prev.totalVote()) {
            prev = curList.prev[prev];
        }

        if (prev == ICandidate(0)) {
            curList.next[c] = curList.head;
            curList.prev[curList.head] = c;
            curList.prev[c] = ICandidate(0);
            curList.head = c;
            return;
        } else {
            curList.next[c] = curList.next[prev];
            curList.prev[curList.next[prev]] = c;
            curList.next[prev] = c;
            curList.prev[c] = prev;
        }
    }


    function lowerRanking(List storage curList, ICandidate c) internal {
        ICandidate next = curList.next[c];
        if (curList.tail == c || next == ICandidate(0) || next.totalVote() <= c.totalVote()) {
            return;
        }

        //remove it
        curList.prev[next] = curList.prev[c];
        if (curList.head == c) {
            curList.head = next;
        } else {
            curList.next[curList.prev[c]] = next;
        }

        while (next != ICandidate(0) && next.totalVote() > c.totalVote()) {
            next = curList.next[next];
        }

        if (next == ICandidate(0)) {
            curList.prev[c] = curList.tail;
            curList.next[c] = ICandidate(0);

            curList.next[curList.tail] = c;
            curList.tail = c;
        } else {
            curList.next[curList.prev[next]] = c;
            curList.prev[c] = curList.prev[next];
            curList.next[c] = next;
            curList.prev[next] = c;
        }
    }


    function removeRanking(List storage curList, ICandidate c) internal {
        if(curList.head != c && curList.prev[c] == ICandidate(0)) {
            //not in list
            return;
        }

        if (curList.tail == c) {
            curList.tail = curList.prev[c];
        }

        if(curList.head == c) {
            curList.head = curList.next[c];
        }

        ICandidate next = curList.next[c];
        if(next != ICandidate(0)) {
            curList.prev[next] = curList.prev[c];
        }
        ICandidate prev = curList.prev[c];
        if(prev != ICandidate(0)) {
            curList.next[prev] = curList.next[c];
        }

        curList.prev[c] = ICandidate(0);
        curList.next[c] = ICandidate(0);
        curList.length--;
    }
}