//SPDX-License-Identifier: MIT

pragma solidity >= 0.6.0 < 0.8.0;

// AddressList manages the developer addresses and black-list addresses
// NOTE: Never change the sequence of storage variables.
contract AddressList {
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

    uint256 public blackLastUpdatedNumber; // last block number when the black list is updated
    uint256 public rulesLastUpdatedNumber;  // last block number when the rules are updated
    // event check rules
    EventCheckRule[] rules;
    mapping(bytes32 => mapping(uint128 => uint256)) rulesMap;   // eventSig => checkIdx => indexInArray+1
    //=*=*= End of state variables =*=*=

    event EnableStateChanged(bool indexed newState);

    event AdminChanging(address indexed newAdmin);
    event AdminChanged(address indexed newAdmin);

    event DeveloperAdded(address indexed addr);
    event DeveloperRemoved(address indexed addr);

    event BlackAddrAdded(address indexed addr, Direction d);
    event BlackAddrRemoved(address indexed addr, Direction d);

    event RuleAdded(bytes32 indexed eventSig, uint128 checkIdx, CheckType t);
    event RuleUpdated(bytes32 indexed eventSig, uint128 checkIdx, CheckType t);
    event RuleRemoved(bytes32 indexed eventSig, uint128 checkIdx, CheckType t);

    enum Direction {
        From,
        To,
        Both
    }
    // address check type of event check rules
    enum CheckType {
        CheckNone,
        CheckFrom,
        CheckTo,
        CheckBothInAny
    }
    //
    struct EventCheckRule {
        bytes32 eventSig;
        uint128 checkIdx;
        CheckType checkType;
    }

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
        devVerifyEnabled = true;
        emit EnableStateChanged(true);
    }

    function disableDevVerify() external onlyAdmin {
        require(devVerifyEnabled, "already disabled");
        devVerifyEnabled = false;
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

    function isBlackAddress(address a) view external returns (bool, Direction) {
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
        return (false, Direction.From);
        // the Direction means nothing here.
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

        blackLastUpdatedNumber = block.number;
        emit BlackAddrAdded(a, d);
    }

    function addBlack(address[] storage blacks, mapping(address => uint256) storage idx, address a) private {
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
        blackLastUpdatedNumber = block.number;
    }

    function removeBlacks(address[] storage blacks, mapping(address => uint256) storage idx, address a, Direction d) private {
        uint i = idx[a] - 1;
        idx[a] = 0;
        if (i != blacks.length - 1) {
            blacks[i] = blacks[blacks.length - 1];
            // update index
            idx[blacks[i]] = i + 1;
        }
        blacks.pop();

        emit BlackAddrRemoved(a, d);
    }

    // rules manage

    function initializeV2() external {
        require(rulesLastUpdatedNumber == 0, "Only initialize before any use");
        require(blackLastUpdatedNumber == 0, "Only initialize before any use");
        // erc20/erc721 transfer: Transfer(address,address,uint256);
        bytes32 sig = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
        uint128 checkIdx = 1;
        EventCheckRule memory rule = EventCheckRule(sig, checkIdx, CheckType.CheckFrom);
        rules.push(rule);
        rulesMap[sig][checkIdx] = rules.length;

        // erc777 sent: Sent(address,address,address,uint256,bytes,bytes)
        sig = 0x06b541ddaa720db2b10a4d0cdac39b8d360425fc073085fac19bc82614677987;
        checkIdx = 2;
        rule = EventCheckRule(sig, checkIdx, CheckType.CheckFrom);
        rules.push(rule);
        rulesMap[sig][checkIdx] = rules.length;

        // erc1155 transfer single and batch
        // TransferSingle(address,address,address,uint256,uint256)
        sig = 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62;
        rule = EventCheckRule(sig, checkIdx, CheckType.CheckFrom);
        rules.push(rule);
        rulesMap[sig][checkIdx] = rules.length;
        // TransferBatch(address,address,address,uint256[],uint256[])
        sig = 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb;
        rule = EventCheckRule(sig, checkIdx, CheckType.CheckFrom);
        rules.push(rule);
        rulesMap[sig][checkIdx] = rules.length;

        blackLastUpdatedNumber = block.number;
        rulesLastUpdatedNumber = block.number;
    }

    function addOrUpdateRule(bytes32 sig, uint128 checkIdx, CheckType tp) external onlyAdmin returns (bool) {
        require(sig != bytes32(0), "eventSignature must not empty");
        require(checkIdx > 0, "check index must greater than 0");
        require(tp > CheckType.CheckNone && tp <= CheckType.CheckBothInAny, "invalid check type");

        uint old = rulesMap[sig][checkIdx];
        if (old > 0) {
            EventCheckRule storage rule = rules[old - 1];
            rule.checkType = tp;
            emit RuleUpdated(sig, checkIdx, tp);
        } else {
            EventCheckRule memory rule = EventCheckRule(sig, checkIdx, tp);
            rules.push(rule);
            rulesMap[sig][checkIdx] = rules.length;
            emit RuleAdded(sig, checkIdx, tp);
        }

        rulesLastUpdatedNumber = block.number;
        return true;
    }

    function removeRule(bytes32 sig, uint128 checkIdx) external onlyAdmin returns (bool) {
        require(sig != bytes32(0), "eventSignature must not empty");
        require(checkIdx > 0, "check index must greater then 0");
        require(rulesMap[sig][checkIdx] > 0, "rule not exist");

        uint i = rulesMap[sig][checkIdx];
        rulesMap[sig][checkIdx] = 0;
        //delete from rulesMap
        EventCheckRule memory old = rules[i - 1];

        if (i != rules.length) {
            // not the last element, do a replace
            EventCheckRule memory rule = rules[rules.length - 1];
            rules[i - 1] = rule;
            rulesMap[rule.eventSig][rule.checkIdx] = i;
        }
        rules.pop();
        emit RuleRemoved(old.eventSig, old.checkIdx, old.checkType);

        rulesLastUpdatedNumber = block.number;
        return true;
    }

    function rulesLen() external view returns (uint32) {
        return uint32(rules.length);
    }

    function getRuleByIndex(uint32 i) external view returns (bytes32, uint128, CheckType) {
        require(i < rules.length, "index out of range");
        EventCheckRule memory r = rules[i];
        return (r.eventSig, r.checkIdx, r.checkType);
    }

    function getRuleByKey(bytes32 sig, uint128 checkIdx) external view returns (bytes32, uint128, CheckType) {
        uint i = rulesMap[sig][checkIdx];
        if (i > 0 && i <= rules.length) {
            EventCheckRule memory r = rules[i - 1];
            return (r.eventSig, r.checkIdx, r.checkType);
        }
        return (bytes32(0), uint128(0), CheckType.CheckNone);
    }
}