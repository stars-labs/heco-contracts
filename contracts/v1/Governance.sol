//SPDX-License-Identifier: MIT

pragma solidity >= 0.6.0 < 0.8.0;

import "./Params.sol";

contract Governance is Params {

    struct Proposal {
        uint id;
        uint action;
        address from;
        address to;
        uint value;
        bytes data;
    }


    address public admin;
    address public pendingAdmin;

    Proposal[] proposals;

    Proposal[] passedProposals;


    event AdminChanging(address indexed newAdmin);
    event AdminChanged(address indexed newAdmin);

    event ProposalCommitted(uint indexed id);
    event ProposalFinished(uint indexed id);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Admin only");
        _;
    }

    function initialize(address _admin) external onlyNotInitialized {
        admin = _admin;
        initialized = true;
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

    function commitProposal(uint action, address from, address to, uint value, bytes calldata input) external onlyAdmin {
        uint id = proposals.length;
        Proposal memory p = Proposal(id, action, from, to, value, input);

        proposals.push(p);
        passedProposals.push(p);

        emit ProposalCommitted(id);
    }

    function getProposalsTotalCount() view external returns (uint) {
        return proposals.length;
    }

    function getProposalById(uint id) view external returns (
        uint _id,
        uint action,
        address from,
        address to,
        uint value,
        bytes memory data) {
        require(id < proposals.length, "Id does not exist");

        Proposal memory p = proposals[id];
        return (p.id, p.action, p.from, p.to, p.value, p.data);
    }

    function getPassedProposalCount() view external returns (uint32) {
        return uint32(passedProposals.length);
    }

    function getPassedProposalByIndex(uint32 index) view external returns (
        uint id,
        uint action,
        address from,
        address to,
        uint value,
        bytes memory data) {
        require(index < passedProposals.length, "Index out of range");

        Proposal memory p = passedProposals[index];
        return (p.id, p.action, p.from, p.to, p.value, p.data);
    }

    function finishProposalById(uint id) external onlyMiner {
        for (uint i = 0; i < passedProposals.length; i++) {
            if (passedProposals[i].id == id) {
                if (i != passedProposals.length - 1) {
                    passedProposals[i] = passedProposals[passedProposals.length - 1];
                }
                passedProposals.pop();

                emit ProposalFinished(id);
                break;
            }
        }
    }

}
