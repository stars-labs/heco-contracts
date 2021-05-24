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
    struct Blacklist {
        address a;
        Direction d;
    }

    bool public initialized;
    bool public devVerifyEnabled;
    address public admin;
    address public pendingAdmin;

    mapping(address => bool) private devs;

    Blacklist[] blacks;

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

    function getBlacklist() view external returns (Blacklist[] memory) {
        return blacks;
    }

    function addBlacklist(address a, Direction d) external onlyAdmin {
        // add with NO check
        Blacklist memory b = new Blacklist(a,d);
        blacks.push(b);

        emit BlackAddrAdded(a,d);
    }

    function removeBlacklist(address a, Direction d) external onlyAdmin {
        for (uint i = 0; i < blacks.length; i++) {
            if (blacks[i].a == a && (d == Direction.Both || blacks[i].d == d)) {
                Direction originD = blacks[i].d;
                if (i != blacks.length - 1) {
                    blacks[i] = blacks[blacks.length - 1];
                }
                blacks.pop();

                emit BlackAddrRemoved(a,originD);
            }
        }
    }
}