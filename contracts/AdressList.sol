//SPDX-License-Identifier: MIT

pragma solidity >= 0.6.0 < 0.8.0;

// AddressList manages the developer addresses and black-list addresses
// NOTE: Never change the sequence of storage variables.
contract AddressList {

    enum Direction {
        From,
        To,
        Both
    }

    bool public initialized;
    bool public devVerifyEnabled;
    address public admin;
    address public pendingAdmin;

    mapping(address => bool) private devs;

    //NOTE: make sure this list is not too large!
    address[] blacksFrom;
    address[] blacksTo;

    event EnableStateChanged(bool indexed newState);

    event AdminChanging(address indexed newAdmin);
    event AdminChanged(address indexed newAdmin);

    event DeveloperAdded(address indexed addr);
    event DeveloperRemoved(address indexed addr);

    event BlackAddrAdded(address indexed addr, Direction d);
    event BlackAddrRemoved(address indexed addr, Direction d);

    modifier onlyNotInitialized() {
        require(!initialized, "Already initialized");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    function initialize(address _admin) external onlyNotInitialized {
        admin = _admin;
        initialized = true;
    }

    //Sets the developer verification flag
    function setEnable(bool _isEnabled) external onlyAdmin {
        require(devVerifyEnabled != _isEnabled, "Same value");
        devVerifyEnabled = _isEnabled;
        emit EnableStateChanged(_isEnabled);
    }

    function commitChangeAdmin(address newAdmin) external onlyAdmin {
        pendingAdmin = newAdmin;

        emit AdminChanging(newAdmin);
    }

    function confirmChangeAdmin() external {
        require(msg.sender == pendingAdmin, "New admin only");

        admin = pendingAdmin;
        pendingAdmin = address(0);

        emit AdminChanged(admin);
    }

    function addDeveloper(address addr) external onlyAdmin {
        devs[addr] = true;
        emit DeveloperAdded(addr);
    }

    function removeDeveloper(address addr) external onlyAdmin {
        devs[addr] = false;
        emit DeveloperRemoved(addr);
    }

    function isDeveloper(address addr) view external returns (bool) {
        return devs[addr];
    }

    function getBlacksFrom() view external returns (address[] memory) {
        return blacksFrom;
    }

    function getBlacksTo() view external returns (address[] memory) {
        return blacksTo;
    }

    function addBlacklist(address a, Direction d) external onlyAdmin {
        if (d == Direction.Both) {
            blacksFrom.push(a);
            blacksTo.push(a);
        } else if (d == Direction.From) {
            blacksFrom.push(a);
        } else {
            blacksTo.push(a);
        }

        emit BlackAddrAdded(a,d);
    }

    function removeBlacklistAtIndex(uint i, Direction d) external onlyAdmin {
        require(d != Direction.Both, "can not be Both on removeBlacklistAtIndex");
        if (d == Direction.From) {
            removeBlacksAtIndex(blacksFrom,i,d);
        } else {
            removeBlacksAtIndex(blacksTo,i,d);
        }
    }

    function removeBlacklist(address a, Direction d) external onlyAdmin {
        if (d == Direction.Both || d == Direction.From) {
            removeBlacks(blacksFrom, a, Direction.From);
            removeBlacks(blacksTo, a, Direction.To);
        } else if (d == Direction.From) {
            removeBlacks(blacksFrom, a, d);
        } else {
            removeBlacks(blacksTo, a, d);
        }
    }

    function removeBlacks(address[] storage blacks, address a, Direction d) private {
        for (uint i = 0; i < blacks.length; i++) {
            if (blacks[i] == a ) {
                if (i != blacks.length - 1) {
                    blacks[i] = blacks[blacks.length - 1];
                }
                blacks.pop();

                emit BlackAddrRemoved(a,d);
                break;
            }
        }
    }

    function removeBlacksAtIndex(address[] storage blacks, uint i, Direction d) private {
        require(i < blacks.length,"index out of bound");
        address a = blacks[i];
        if (i != blacks.length - 1) {
            blacks[i] = blacks[blacks.length - 1];
        }
        blacks.pop();

        emit BlackAddrRemoved(a,d);
    }
}