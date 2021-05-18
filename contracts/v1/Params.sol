// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

contract Params {
    bool public initialized;

    // System contracts
    address
        public constant ValidatorContractAddr = $(ValidatorContractAddr);
    address
        public constant PunishContractAddr = $(PunishContractAddr);

    // System params
    uint16 public constant MaxValidators = 21;

    uint public constant PosMinMargin = $(PosMinMargin) ether;
    uint public constant PoaMinMargin = $(PoaMinMargin) ether;
    uint public constant JailPeriod = $(JailPeriod);
    uint64 public constant LockPeriod = $(LockPeriod);

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
        require(msg.sender == PunishContractAddr, "Punish contract only");
        _;
    }

    modifier onlyBlockEpoch(uint256 epoch) {
        require(block.number % epoch == 0, "Block epoch only");
        _;
    }

    // modifier onlyValidatorsContract() {
    //     require(
    //         msg.sender == ValidatorContractAddr,
    //         "Validators contract only"
    //     );
    //     _;
    // }
}
