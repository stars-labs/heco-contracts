pragma solidity >=0.6.0 <0.8.0;

// #if Mainnet
import "./Params.sol";
// #else
import "./mock/MockParams.sol";
// #endif
import "./interfaces/IVotePool.sol";
import "./interfaces/IValidators.sol";
import "./interfaces/IPunish.sol";

contract Punish is Params, IPunish {
    uint256 public punishThreshold;
    uint256 public removeThreshold;
    uint256 public decreaseRate;

    struct PunishRecord {
        uint256 missedBlocksCounter;
        uint256 index;
        bool exist;
    }

    mapping(address => PunishRecord) punishRecords;
    address[] public punishValidators;

    mapping(uint256 => bool) punished;
    mapping(uint256 => bool) decreased;

    event LogDecreaseMissedBlocksCounter();
    event LogPunishValidator(address indexed val, uint256 time);

    modifier onlyNotPunished() {
        require(!punished[block.number], "Already punished");
        _;
    }

    modifier onlyNotDecreased() {
        require(!decreased[block.number], "Already decreased");
        _;
    }

    function initialize() external onlyNotInitialized {
        punishThreshold = 24;
        removeThreshold = 48;
        decreaseRate = 24;

        initialized = true;
    }

    function punish(address _val)
    external
    onlyMiner
    onlyInitialized
    onlyNotPunished
    {
        punished[block.number] = true;
        if (!punishRecords[_val].exist) {
            punishRecords[_val].index = punishValidators.length;
            punishValidators.push(_val);
            punishRecords[_val].exist = true;
        }
        punishRecords[_val].missedBlocksCounter++;

        if (punishRecords[_val].missedBlocksCounter % removeThreshold == 0) {
            IVotePool _pool = validatorsContract.votePools(_val);
            _pool.punish();
            // reset validator's missed blocks counter
            punishRecords[_val].missedBlocksCounter = 0;
        } else if (punishRecords[_val].missedBlocksCounter % punishThreshold == 0) {
            IVotePool _pool = validatorsContract.votePools(_val);
            _pool.removeValidatorIncoming();
        }

        emit LogPunishValidator(_val, block.timestamp);
    }

    function decreaseMissedBlocksCounter(uint256 _epoch)
    external
    onlyMiner
    onlyNotDecreased
    onlyInitialized
    onlyBlockEpoch(_epoch)
    {
        decreased[block.number] = true;
        if (punishValidators.length == 0) {
            return;
        }

        for (uint256 i = 0; i < punishValidators.length; i++) {
            if (
                punishRecords[punishValidators[i]].missedBlocksCounter > removeThreshold / decreaseRate) {
                punishRecords[punishValidators[i]].missedBlocksCounter =
                punishRecords[punishValidators[i]].missedBlocksCounter -
                removeThreshold /
                decreaseRate;
            } else {
                punishRecords[punishValidators[i]].missedBlocksCounter = 0;
            }
        }

        emit LogDecreaseMissedBlocksCounter();
    }

    // clean validator's punish record if one vote in
    function cleanPunishRecord(address _val)
    external
    override
    onlyInitialized
    {
        require(address(validatorsContract.votePools(_val)) == msg.sender, "Validator not registered");
        if (punishRecords[_val].missedBlocksCounter != 0) {
            punishRecords[_val].missedBlocksCounter = 0;
        }

        // remove it out of array if exist
        if (punishRecords[_val].exist && punishValidators.length > 0) {
            if (punishRecords[_val].index != punishValidators.length - 1) {
                address _tail = punishValidators[punishValidators.length - 1];
                punishValidators[punishRecords[_val].index] = _tail;

                punishRecords[_tail].index = punishRecords[_val].index;
            }
            punishValidators.pop();
            punishRecords[_val].index = 0;
            punishRecords[_val].exist = false;
        }
    }

    function getPunishValidatorsLen() public view returns (uint256) {
        return punishValidators.length;
    }

    function getPunishRecord(address val) public view returns (uint256) {
        return punishRecords[val].missedBlocksCounter;
    }
}
