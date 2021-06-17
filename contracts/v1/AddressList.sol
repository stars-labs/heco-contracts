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
    mapping(address => uint256) blacksFromMap;      // address => index+1
    mapping(address => uint256) blacksToMap;        // address => index+1

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

    function enableDevVerify() external onlyAdmin {
        require(devVerifyEnabled == false, "already enabled");
        devVerifyEnabled=true;
        emit EnableStateChanged(true);
    }

    function disableDevVerify() external onlyAdmin {
        require(devVerifyEnabled, "already disabled");
        devVerifyEnabled=false;
        emit EnableStateChanged(false);
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
        require(!devs[addr], "already added");
        devs[addr] = true;
        emit DeveloperAdded(addr);
    }

    function removeDeveloper(address addr) external onlyAdmin {
        require(devs[addr], "not a developer");
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

    function isBlackAddress(address a) view external returns(bool, Direction) {
        bool f = blacksFromMap[a] > 0;
        bool t = blacksToMap[a] > 0;
        if (f && t) {
            return (true, Direction.Both);
        }
        if (f) {
            return (true, Direction.From);
        }
        if (t) {
            return (true, Direction.To);
        }
        return (false, Direction.From); // the Direction means nothing here.
    }

    function addBlacklist(address a, Direction d) external onlyAdmin {
        require(a != admin, "cannot add admin to blacklist");
        if (d == Direction.Both) {
            require(blacksFromMap[a] == 0, "already in from list");
            require(blacksToMap[a] == 0, "already in to list");
            addBlack(blacksFrom, blacksFromMap, a);
            addBlack(blacksTo, blacksToMap, a);
        } else if (d == Direction.From) {
            require(blacksFromMap[a] == 0, "already in from list");
            addBlack(blacksFrom, blacksFromMap, a);
        } else {
            require(blacksToMap[a] == 0, "already in to list");
            addBlack(blacksTo, blacksToMap, a);
        }

        emit BlackAddrAdded(a, d);
    }

    function addBlack(address[] storage blacks, mapping(address=>uint256) storage idx, address a) private {
        blacks.push(a);
        idx[a] = blacks.length;
    }

    function removeBlacklist(address a, Direction d) external onlyAdmin {
        if (d == Direction.Both) {
            require(blacksFromMap[a] > 0, "not in from list");
            require(blacksToMap[a] > 0, "not in to list");
            removeBlacks(blacksFrom, blacksFromMap, a, Direction.From);
            removeBlacks(blacksTo, blacksToMap, a, Direction.To);
        } else if (d == Direction.From) {
            require(blacksFromMap[a] > 0, "not in from list");
            removeBlacks(blacksFrom, blacksFromMap, a, Direction.From);
        } else {
            require(blacksToMap[a] > 0, "not in to list");
            removeBlacks(blacksTo, blacksToMap, a, Direction.To);
        }
    }

    function removeBlacks(address[] storage blacks, mapping(address=>uint256) storage idx, address a, Direction d) private {
        uint i = idx[a] - 1;
        idx[a] = 0;
        if (i != blacks.length - 1) {
            blacks[i] = blacks[blacks.length - 1];
            // update index
            idx[blacks[i]] = i+1;
        }
        blacks.pop();

        emit BlackAddrRemoved(a,d);
    }
}