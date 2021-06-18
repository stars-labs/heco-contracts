// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./interfaces/IValidators.sol";
import "./interfaces/IPunish.sol";

contract Params {
    bool public initialized;

    // System contracts
    IValidators public constant validatorsContract = IValidators(0x000000000000000000000000000000000000F005);
    IPunish public constant punishContract = IPunish(0x000000000000000000000000000000000000F006);

    // System params
    uint16 public constant MaxValidators = 21;

    uint public constant PosMinMargin = 5000 ether;
    uint public constant PoaMinMargin = 1 ether;

    uint public constant PunishAmount = 100 ether;

    uint public constant JailPeriod = 86400;
    uint public constant MarginLockPeriod = 403200;
    uint public constant WithdrawLockPeriod = 86400;
    uint public constant PercentChangeLockPeriod = 86400;
    uint constant PERCENT_BASE = 10000;

    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }

    modifier onlyNotInitialized() {
        require(!initialized, "Already initialized");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Not init yet");
        _;
    }

    modifier onlyPunishContract() {
        require(msg.sender == address(punishContract), "Punish contract only");
        _;
    }

    modifier onlyBlockEpoch(uint256 epoch) {
        require(block.number % epoch == 0, "Block epoch only");
        _;
    }

    modifier onlyValidatorsContract() {
        require(msg.sender == address(validatorsContract), "Validators contract only");
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }
}
