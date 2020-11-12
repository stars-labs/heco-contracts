pragma solidity >=0.6.0 <0.8.0;

import "../Proposal.sol";

contract MockValidators {
    address[] vals;

    Proposal proposal;

    constructor(address[] memory vals_, address proposal_) public {
        for (uint256 i = 0; i < vals_.length; i++) {
            vals.push(vals_[i]);
        }

        proposal = Proposal(proposal_);
    }

    function getActiveValidators() public view returns (address[] memory) {
        address[] memory activeSet = new address[](vals.length);

        for (uint256 i = 0; i < vals.length; i++) {
            activeSet[i] = vals[i];
        }
        return activeSet;
    }

    function isActiveValidator(address who) public view returns (bool) {
        for (uint256 i = 0; i < vals.length; i++) {
            if (vals[i] == who) {
                return true;
            }
        }

        return false;
    }

    function setUnpassed(address who) public {
        proposal.setUnpassed(who);
    }

    function tryReactive(address who) public returns (bool) {
        return true;
    }
}
