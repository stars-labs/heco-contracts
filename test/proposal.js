const MockValidators = artifacts.require("MockValidators");
const Proposal = artifacts.require("Proposal");

const {
    constants,
    expectRevert,
    expectEvent,
    time
} = require('@openzeppelin/test-helpers');

// Test content:
// 1. initialize can only call once
//
// 1. anyone can create a proposal
// 2. one can't create a proposal to propose a already passed user
// 3. detail info can't too long
//
// 1. only validator can vote for a proposal
// 2. validator can only vote once for a proposal
// 3. validator can't vote for a expired proposal
// 4. len(validators)/2+1 vote agree, the proposal will pass
// 5. len(validators)/2+1 vote reject, the proposal will reject

contract("Proposal test", function (accounts) {
    // set validators
    let vals = [];
    for (let i = 0; i < 5; i++) {
        vals.push(accounts[i]);
    }
    var proposalIns;
    var mockVal;

    before(async function () {
        proposalIns = await Proposal.new();
        mockVal = await MockValidators.new(vals, proposalIns.address);
        for (let i = 0; i < vals.length; i++) {
            let exist = await mockVal.isActiveValidator(vals[i]);
            assert.equal(exist, true, "initialize validator failed");
        }

        await proposalIns.setContracts(mockVal.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
        await proposalIns.initialize([]);
    });

    it("Init can only call once", async function () {
        await expectRevert(proposalIns.initialize([]), "Already initialized");
    })

    describe("Create proposal", async function () {
        let candidate = accounts[6];
        it('anyone can create proposal', async function () {
            for (let i = 0; i < accounts.length && i < 10; i++) {
                let receipt = await proposalIns.createProposal(candidate, "", {
                    from: accounts[i]
                });

                expectEvent(receipt, 'LogCreateProposal', {
                    proposer: accounts[i],
                    dst: candidate,
                });
            }
        })

        it("details info can't too long", async function () {
            await expectRevert(proposalIns.createProposal(candidate, getInvalidDetails()), "Details too long");
        })
    })

    describe("Vote for proposal(pass)", async function () {
        let candidate = accounts[6];
        let proposer = accounts[7];
        let id;

        it("normal vote for a proposal(3 true/2 false)", async function () {
            let receipt = await proposalIns.createProposal(candidate, "test", {
                from: proposer
            });
            id = receipt.logs[0].args.id;

            for (let i = 0; i < 3; i++) {
                let receipt = await proposalIns.voteProposal(id, true, {
                    from: accounts[i]
                });
                expectEvent(receipt, 'LogVote', {
                    id: id,
                    voter: accounts[i],
                    auth: true
                });

                if (i == 2) {
                    expectEvent(receipt, 'LogPassProposal', {
                        id: id,
                        dst: candidate
                    });
                }
            }

            receipt = await proposalIns.voteProposal(id, false, {
                from: accounts[3]
            });
            expectEvent(receipt, 'LogVote', {
                id: id,
                voter: accounts[3],
                auth: false
            });
        })

        it("only validator can vote for a proposal", async function () {
            await expectRevert(proposalIns.voteProposal(id, false, {
                from: accounts[6]
            }), "Validator only");
        })

        it("validator can only vote for a proposal once", async function () {
            await expectRevert(proposalIns.voteProposal(id, false, {
                from: accounts[1]
            }), "You can't vote for a proposal twice");
        })

        it("validator can't vote for proposal if it is expired", async function () {
            let step = await proposalIns.proposalLastingPeriod();
            await time.increase(step);
            await expectRevert(proposalIns.voteProposal(id, false, {
                from: accounts[4]
            }), "Proposal expired");
        })

        it("Validate candidate's info", async function () {
            // check proposal info
            let proposalInfo = await proposalIns.proposals(id);
            assert.equal(proposalInfo.proposer, proposer);
            assert.equal(proposalInfo.dst, candidate);
            assert.equal(proposalInfo.agree.toNumber(), 3);
            assert.equal(proposalInfo.reject.toNumber(), 1);
            assert.equal(proposalInfo.resultExist, true);
            // ensure candidate is passed
            let pass = await proposalIns.pass(candidate);
            assert.equal(pass, true);
        })

        it("can't create a proposal for one who is pass proposal", async function () {
            await expectRevert(proposalIns.createProposal(candidate, ""), "Dst already passed, You can start staking");
        })
    })

    describe("Vote for proposal(reject)", async function () {
        let candidate = accounts[8];
        let proposer = accounts[9];
        let id;

        it("normal vote(2 agree, 3 reject)", async function () {
            let receipt = await proposalIns.createProposal(candidate, "test", {
                from: proposer
            });
            id = receipt.logs[0].args.id;

            for (let i = 0; i < 2; i++) {
                let receipt = await proposalIns.voteProposal(id, true, {
                    from: accounts[i]
                });
                expectEvent(receipt, 'LogVote', {
                    id: id,
                    voter: accounts[i],
                    auth: true
                });

                if (i == 2) {
                    expectEvent(receipt, 'LogPassProposal', {
                        id: id,
                        dst: candidate
                    });
                }
            }

            for (let i = 2; i < 5; i++) {
                let receipt = await proposalIns.voteProposal(id, false, {
                    from: accounts[i]
                });
                expectEvent(receipt, 'LogVote', {
                    id: id,
                    voter: accounts[i],
                    auth: false
                });

                if (i == 4) {
                    expectEvent(receipt, 'LogRejectProposal', {
                        id: id,
                        dst: candidate
                    });
                }
            }
        })
    })

    describe("Set val unpass", async function () {
        let candidate = accounts[6];

        it("only validator can set val unpass", async function () {
            await expectRevert(
                proposalIns.setUnpassed(candidate),
                "Validators contract only"
            )
        })
        it("validator contract can set val unpass", async function () {
            let before = await proposalIns.pass(candidate);
            assert.equal(before, true);

            await mockVal.setUnpassed(candidate);

            let after = await proposalIns.pass(candidate);
            assert.equal(after, false);
        })
    })
});

function getInvalidDetails() {
    var res = ""
    for (let i = 0; i < 3005; i++) {
        res += i;
    }

    return res;
}