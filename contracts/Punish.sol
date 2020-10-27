pragma solidity >=0.6.0 <0.8.0;

import "./Params.sol";
import "./Validators.sol";

contract Punish is Params {
    uint256 public previousHeight;
    uint256 public punishThreshold;
    uint256 public removeThreshold;
    uint256 public decreaseRate;

    struct PunishRecord {
        uint256 missedBlocksCounter;
        uint256 index;
        bool exist;
    }

    mapping(address => PunishRecord) punishRecords;
    mapping(uint256 => bool) punished;
    address[] public punishValidators;
    Validators validators;

    event LogDecreaseMissedBlocksCounter();
    event LogPunishValidator(address indexed val, uint256 time);

    modifier notPunish() {
        require(!punished[block.number], "Already punished");
        _;
    }

    modifier onlyZeroGasPrice() {
        require(tx.gasprice == 0, "Gasprice zero only");
        _;
    }

    function initialize() external onlyNotInitialized {
        validators = Validators(ValidatorContractAddr);
        punishThreshold = 10;
        removeThreshold = 30;
        decreaseRate = 4;

        initialized = true;
    }

    function punish(address val)
        external
        onlyMiner
        onlyInitialized
        notPunish
        onlyZeroGasPrice
    {
        punished[block.number] = true;
        if (!punishRecords[val].exist) {
            punishRecords[val].index = punishValidators.length;
            punishValidators.push(val);
            punishRecords[val].exist = true;
        }
        punishRecords[val].missedBlocksCounter++;

        if (punishRecords[val].missedBlocksCounter % removeThreshold == 0) {
            validators.removeValidator(val);
            // reset validator's missed blocks counter
            punishRecords[val].missedBlocksCounter = 0;
        } else if (
            punishRecords[val].missedBlocksCounter % punishThreshold == 0
        ) {
            validators.punishValidator(val);
        }

        emit LogPunishValidator(val, block.timestamp);
    }

    function decreaseMissedBlocksCounter(uint256 epoch)
        external
        onlyMiner
        onlyInitialized
        onlyBlockEpoch(epoch)
    {
        if (punishValidators.length == 0) {
            return;
        }

        for (uint256 i = 0; i < punishValidators.length; i++) {
            if (
                punishRecords[punishValidators[i]].missedBlocksCounter >
                removeThreshold / decreaseRate
            ) {
                punishRecords[punishValidators[i]].missedBlocksCounter =
                    punishRecords[punishValidators[i]].missedBlocksCounter -
                    removeThreshold /
                    decreaseRate;
            }
        }

        emit LogDecreaseMissedBlocksCounter();
    }

    // clean validator's punish record if one restake in
    function cleanPunishRecord(address val)
        public
        onlyInitialized
        onlyValidatorsContract
        returns (bool)
    {
        if (punishRecords[val].missedBlocksCounter != 0) {
            punishRecords[val].missedBlocksCounter = 0;
        }

        // remove it out of array if exist
        if (punishRecords[val].exist && punishValidators.length > 0) {
            if (punishRecords[val].index != punishValidators.length - 1) {
                address uval = punishValidators[punishValidators.length - 1];
                punishValidators[punishRecords[val].index] = uval;

                punishRecords[uval].index = punishRecords[val].index;
            }
            punishValidators.pop();
            punishRecords[val].index = 0;
            punishRecords[val].exist = false;
        }

        return true;
    }

    function getPunishValidatorsLen() public view returns (uint256) {
        return punishValidators.length;
    }

    function getPunishRecord(address val) public view returns (uint256) {
        return punishRecords[val].missedBlocksCounter;
    }
}
