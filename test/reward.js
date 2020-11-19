const Proposal = artifacts.require("Proposal");
const Validators = artifacts.require('Validators');
const Punish = artifacts.require("Punish");

const {
    constants,
    expectRevert,
    expectEvent,
    time,
    ether,
    BN
} = require('@openzeppelin/test-helpers');

contract("Validators test", function (accounts) {
    var valIns, proposalIns, punishIns, initValidators;
    var miner = accounts[0];
    // var totalStake = new BN("0");

    let stake = [ether('32'), ether('33'), ether('34')];
    let curTotalStake = ether('99');

    before(async function () {
        valIns = await Validators.new();
        proposalIns = await Proposal.new();
        punishIns = await Punish.new();

        initValidators = accounts.slice(0, 3);
        await proposalIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
        await valIns.setContracts(valIns.address, punishIns.address, proposalIns.address);
        await punishIns.setContracts(valIns.address, punishIns.address, proposalIns.address);

        await valIns.initialize(initValidators);
        await valIns.setMiner(miner);
        await proposalIns.initialize(initValidators);
        await punishIns.setMiner(miner);
        await punishIns.initialize();
    })

    describe("normal case(no validator jailed or unstaked)", async function () {

        it("total stake should be zero", async function () {
            let total = await valIns.totalStake();

            assert.equal(total.isZero(), true);

            let info = await valIns.getTotalStakeOfActiveValidators();
            assert.equal(info[0].isZero(), true);
            assert.equal(info[1].toNumber(), 3);
        })

        it("reward should be equally distributed to active validators if no stake", async function () {
            let stakeInfo = await valIns.getTotalStakeOfActiveValidators();

            let reward = ether('1');
            await valIns.distributeBlockReward({
                from: miner,
                value: reward
            });
            let remain = reward.sub(reward.div(stakeInfo[1]).mul(stakeInfo[1]));

            for (let i = 0; i < initValidators.length; i++) {
                let info = await valIns.getValidatorInfo(initValidators[i]);
                assert.equal(info[2].isZero(), true);

                let inPlan = reward.div(stakeInfo[1]);

                if (i == initValidators.length - 1) {
                    assert.equal(info[3].eq(inPlan.add(remain)), true);
                } else {
                    assert.equal(info[3].eq(inPlan), true);
                }
            }
        })

        it("reward should be distributed to active validators by stake percent(only one stake)", async function () {
            let stakedVal = initValidators[0];
            await valIns.stake(stakedVal, {
                from: stakedVal,
                value: ether('32')
            });

            let before = await getBefore(valIns, initValidators);
            let reward = ether('1');
            await valIns.distributeBlockReward({
                from: miner,
                value: reward
            });

            let added = new BN('0');

            // only the staked one can reward
            for (let i = 0; i < initValidators.length; i++) {
                let info = await valIns.getValidatorInfo(initValidators[i]);

                if (initValidators[i] == stakedVal) {
                    assert.equal(info[3].sub(before[i]).eq(reward), true);
                } else {
                    assert.equal(info[3].eq(before[i]), true);
                }
            }
        })

        it("reward should be distributed to active validators by stake percent(all stake)", async function () {
            // 0: 32
            // 1: 33
            // 2: 34
            await valIns.stake(initValidators[1], {
                from: initValidators[1],
                value: stake[1]
            });
            await valIns.stake(initValidators[2], {
                from: initValidators[2],
                value: stake[2]
            });

            let before = await getBefore(valIns, initValidators);
            let reward = ether('1');
            await valIns.distributeBlockReward({
                from: miner,
                value: reward
            });

            let added = ether('0');

            for (let i = 0; i < initValidators.length; i++) {
                let info = await valIns.getValidatorInfo(initValidators[i]);

                let inPlan = reward.mul(stake[i]).div(curTotalStake);
                added = added.add(inPlan);

                if (i == initValidators.length - 1) {
                    assert.equal(info[3].sub(before[i]).eq(inPlan.add(reward.sub(added))), true);
                } else {
                    assert.equal(info[3].sub(before[i]).eq(inPlan), true);
                }
            }
        })
    })

    describe("punish reward should be distributed to others by stake percent", async function () {
        it("remove validator's reward", async function () {
            let punishee = initValidators[0];
            let info = await valIns.getValidatorInfo(punishee);
            let toRemove = info[3];

            let punishThreshold = await punishIns.punishThreshold();
            let before = await getBefore(valIns, initValidators);

            for (let i = 0; i < punishThreshold.toNumber(); i++) {
                await punishIns.punish(punishee, {
                    from: miner
                });
            }

            // at this time, the profits of punishee will be removed to others.
            info = await valIns.getValidatorInfo(punishee);
            assert.equal(info[3].isZero(), true);

            let added = ether('0');

            // 33 + 34
            let total = stake[1].add(stake[2]);
            for (let i = 1; i < initValidators.length; i++) {
                info = await valIns.getValidatorInfo(initValidators[i]);

                let inPlan = toRemove.mul(stake[i]).div(total);
                added = added.add(inPlan);

                if (i == initValidators.length - 1) {
                    assert.equal(info[3].sub(before[i]).eq(inPlan.add(toRemove.sub(added))), true);
                } else {
                    assert.equal(info[3].sub(before[i]).eq(inPlan), true);
                }
            }
        })

        it("jailed validator can't get reward", async function () {
            let punishee = initValidators[0];
            let removeThreshold = await punishIns.removeThreshold();
            for (let i = 0; i < removeThreshold.toNumber(); i++) {
                await punishIns.punish(punishee, {
                    from: miner
                });
            }

            // at this time, the profit should only sent to not jailed validators.
            let before = await getBefore(valIns, initValidators);
            let reward = ether('1');
            let total = stake[1].add(stake[2]);
            await valIns.distributeBlockReward({
                from: miner,
                value: reward
            });

            let added = ether('0');

            for (let i = 1; i < initValidators.length; i++) {
                let info = await valIns.getValidatorInfo(initValidators[i]);

                let infoPlan = reward.mul(stake[i]).div(total);
                added = added.add(infoPlan);

                if (i == initValidators.length - 1) {
                    assert.equal(info[3].sub(before[i]).eq(infoPlan.add(reward.sub(added))), true);
                } else {
                    assert.equal(info[3].sub(before[i]).eq(infoPlan), true);
                }
            }
        })

        it("jailed validator can't get profits of punish", async function () {
            let punishThreshold = await punishIns.punishThreshold();
            let punishee = initValidators[1];
            let before = await getBefore(valIns, initValidators);

            for (let i = 0; i < punishThreshold.toNumber(); i++) {
                await punishIns.punish(punishee, {
                    from: miner
                });
            }

            let info = await valIns.getValidatorInfo(initValidators[0]);
            assert.equal(info[3].eq(before[0]), true);

            info = await valIns.getValidatorInfo(initValidators[1]);
            assert.equal(info[3].isZero(), true);

            info = await valIns.getValidatorInfo(initValidators[2]);
            assert.equal(info[3].sub(before[2]).eq(before[1]), true);
        })

        it("unstake validator can get block reward", async function () {
            let val = initValidators[2];

            await valIns.unstake(val, {
                from: val
            });

            let before = await getBefore(valIns, initValidators);

            // at this time only one top validator, but three active validator(jailed, normal, unstake)
            let reward = ether('1');
            await valIns.distributeBlockReward({
                from: miner,
                value: reward
            });

            let info = await valIns.getValidatorInfo(initValidators[0]);
            assert.equal(info[3].eq(before[0]), true);

            info = await valIns.getValidatorInfo(initValidators[1]);
            assert.equal(info[3].sub(before[1]).eq(reward), true);

            info = await valIns.getValidatorInfo(initValidators[2]);
            assert.equal(info[3].eq(before[2]), true);
        })
    })
})

async function getBefore(valIns, vals) {
    let before = [];
    for (let i = 0; i < vals.length; i++) {
        let info = await valIns.getValidatorInfo(vals[i]);
        before.push(info[3]);
    }

    return before
}