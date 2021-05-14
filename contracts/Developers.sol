//SPDX-License-Identifier: MIT

pragma solidity >= 0.6.0 < 0.8.0;

// Developers manages the developer addresses
contract Developers {
    bool public initialized;
    bool public enabled;
    address public admin;
    address public pendingAdmin;

    mapping(address => bool) private devs;

    event EnableStateChanged(bool indexed newState);

    event AdminChanging(address indexed newAdmin);
    event AdminChanged(address indexed newAdmin);

    event DeveloperAdded(address indexed addr);
    event DeveloperRemoved(address indexed addr);

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

    function changeEnable(bool _isEnabled) external onlyAdmin {
        require(enabled != _isEnabled, "Same value");
        enabled = _isEnabled;
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
}