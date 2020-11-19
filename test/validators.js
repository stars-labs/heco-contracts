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

const Created = new BN("1");
const Staked = new BN("2");
const Unstaked = new BN("3");
const Jailed = new BN("4");

contract("Validators test", function (accounts) {
    var valIns, proposalIns, punishIns, initValidators;
    var miner = accounts[0];
    var totalStake = new BN("0");

    before(async function () {
        valIns = await Validators.new();
        proposalIns = await Proposal.new();
        punishIns = await Punish.new();

        initValidators = getInitValidators(accounts);
        await proposalIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
        await valIns.setContracts(valIns.address, punishIns.address, proposalIns.address);
        await punishIns.setContracts(valIns.address, punishIns.address, proposalIns.address);

        await valIns.initialize(initValidators);
        await valIns.setMiner(miner);
        await proposalIns.initialize(initValidators);
        await punishIns.initialize();
    })

    it("can only init once", async function () {
        await expectRevert(valIns.initialize(initValidators), "Already initialized");
    })

    it("check const vals", async function () {
        let maxValidators = await valIns.MaxValidators();
        console.log("maxValidators", maxValidators.toString());
        let stakingLockPeriod = await valIns.StakingLockPeriod();
        console.log("stakingLockPeriod", stakingLockPeriod.toString());
        let WithdrawProfitPeriod = await valIns.WithdrawProfitPeriod();
        console.log("WithdrawProfitPeriod", WithdrawProfitPeriod.toString());
        let MinimalStakingCoin = await valIns.MinimalStakingCoin();
        console.log("MinimalStakingCoin", MinimalStakingCoin.toString());
    })

    describe("create or edit validator", async function () {
        let validator = accounts[30];

        it("can't create validator if fee addr == address(0)", async function () {
            await expectRevert(valIns.createOrEditValidator(constants.ZERO_ADDRESS, "", "", "", "", "", {
                from: validator
            }), "Invalid fee address");
        })

        it("can't create validator if describe info invalid", async function () {
            // invalid moniker
            let moniker = getInvalidMoniker();
            await expectRevert(valIns.createOrEditValidator(validator, moniker, "", "", "", "", {
                from: validator
            }), "Invalid moniker length");
        })

        it("can't create validator if not pass propose", async function () {
            await expectRevert(valIns.createOrEditValidator(validator, "", "", "", "", "", {
                from: validator
            }), "You must be authorized first");
        })

        it("create validator", async function () {
            await pass(proposalIns, initValidators, validator);
            let receipt = await valIns.createOrEditValidator(validator, "", "", "", "", "", {
                from: validator
            });
            expectEvent(receipt, "LogCreateValidator", {
                val: validator,
                fee: validator
            });

            // check validator status
            let status = await valIns.getValidatorInfo(validator);
            assert.equal(status[1].eq(Created), true);
        })

        it("edit validator info", async function () {
            let feeAddr = accounts[31];
            let receipt = await valIns.createOrEditValidator(feeAddr, "", "", "", "", "", {
                from: validator
            });
            expectEvent(receipt, "LogEditValidator", {
                val: validator,
                fee: feeAddr
            });
        })
    })

    // test for normal staking
    describe("stake", async function () {
        it("norma stake", async function () {
            let stakingCase = [{
                    accountIndex: 3,
                    staking: ether("100"),
                    isTopValidator: true
                },
                {
                    accountIndex: 4,
                    staking: ether("200"),
                    isTopValidator: true
                },
                {
                    accountIndex: 5,
                    staking: ether("300"),
                    isTopValidator: true
                },
                {
                    accountIndex: 6,
                    staking: ether("400"),
                    isTopValidator: true
                },
                {
                    accountIndex: 7,
                    staking: ether("500"),
                    isTopValidator: true
                },
                {
                    accountIndex: 8,
                    staking: ether("600"),
                    isTopValidator: true
                },
                {
                    accountIndex: 9,
                    staking: ether("700"),
                    isTopValidator: true
                },
                {
                    accountIndex: 10,
                    staking: ether("800"),
                    isTopValidator: true
                },
                {
                    accountIndex: 11,
                    staking: ether("900"),
                    isTopValidator: true
                },
                {
                    accountIndex: 12,
                    staking: ether("110"),
                    isTopValidator: true
                },
                {
                    accountIndex: 13,
                    staking: ether("200"),
                    isTopValidator: true
                },
                {
                    accountIndex: 14,
                    staking: ether("1000"),
                    isTopValidator: true
                },
                {
                    accountIndex: 15,
                    staking: ether("2000"),
                    isTopValidator: true
                },
                {
                    accountIndex: 16,
                    staking: ether("1000"),
                    isTopValidator: true
                },
                {
                    accountIndex: 17,
                    staking: ether("1000"),
                    isTopValidator: true
                },
                {
                    accountIndex: 18,
                    staking: ether("1020"),
                    isTopValidator: true
                },
                {
                    accountIndex: 19,
                    staking: ether("1300"),
                    isTopValidator: true
                },
                {
                    accountIndex: 20,
                    staking: ether("1400"),
                    isTopValidator: true
                },
                {
                    accountIndex: 21,
                    staking: ether("1020"),
                    isTopValidator: true
                },
                // 22
                {
                    accountIndex: 22,
                    staking: ether("120"),
                    isTopValidator: true
                },
                {
                    accountIndex: 23,
                    staking: ether("200"),
                    isTopValidator: true
                },
                {
                    accountIndex: 24,
                    staking: ether("110"),
                    isTopValidator: true
                },
                {
                    accountIndex: 25,
                    staking: ether("50"),
                    isTopValidator: false
                },
            ]
            let expectValidatorAccountIndex = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];

            for (let i = 0; i < stakingCase.length; i++) {
                let account = accounts[stakingCase[i].accountIndex];
                let feeAddr = accounts[20 + stakingCase[i].accountIndex];
                await pass(proposalIns, initValidators, account);
                let receipt = await valIns.createOrEditValidator(feeAddr, "", "", "", "", "", {
                    from: account
                });
                expectEvent(receipt, "LogCreateValidator", {
                    val: account,
                    fee: feeAddr
                });

                totalStake = totalStake.add(stakingCase[i].staking);
                receipt = await valIns.stake(account, {
                    from: account,
                    value: stakingCase[i].staking
                });
                expectEvent(receipt, "LogStake", {
                    staker: account,
                    val: account,
                    staking: stakingCase[i].staking
                });

                let isVal = await valIns.isTopValidator(account);
                assert.equal(isVal, stakingCase[i].isTopValidator);

                // check total stake
                let acutalStake = await valIns.totalStake();
                assert.equal(totalStake.eq(acutalStake), true);
            }

            // check final top validators
            for (let i = 0; i < expectValidatorAccountIndex; i++) {
                let account = accounts[expectValidatorAccountIndex[i]];

                let isVal = await valIns.isTopValidator(account);
                assert.equal(isVal, true);
            }
        })

        it("staker info and list in validator should be right updated", async function () {
            let validator = accounts[42];
            await pass(proposalIns, initValidators, validator);
            await valIns.createOrEditValidator(validator, "", "", "", "", "", {
                from: validator
            });

            let staker_1 = accounts[43];
            await valIns.stake(validator, {
                from: staker_1,
                value: ether('32')
            });

            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 1);
            assert.equal(info[6][0], staker_1);
            let stakingInfo = await valIns.getStakingInfo(staker_1, validator);
            assert.equal(stakingInfo[2].toNumber(), 0);


            let staker_2 = accounts[44];
            await valIns.stake(validator, {
                from: staker_2,
                value: ether('32')
            });
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 2);
            assert.equal(info[6][1], staker_2);
            stakingInfo = await valIns.getStakingInfo(staker_2, validator);
            assert.equal(stakingInfo[2].toNumber(), 1);

            let staker_3 = accounts[45];
            await valIns.stake(validator, {
                from: staker_3,
                value: ether('32')
            });
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 3);
            assert.equal(info[6][2], staker_3);
            stakingInfo = await valIns.getStakingInfo(staker_3, validator);
            assert.equal(stakingInfo[2].toNumber(), 2);

            // staker_3 add stake won't increase list
            staker_3 = accounts[45];
            await valIns.stake(validator, {
                from: staker_3,
                value: ether('32')
            });
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 3);
            assert.equal(info[6][2], staker_3);
            stakingInfo = await valIns.getStakingInfo(staker_3, validator);
            assert.equal(stakingInfo[2].toNumber(), 2);

            // staker 1 unstake
            await valIns.unstake(validator, {
                from: staker_1
            });
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 2);
            // staker_3 will be place in the index of unstaked user
            assert.equal(info[6][0], staker_3);
            stakingInfo = await valIns.getStakingInfo(staker_3, validator);
            assert.equal(stakingInfo[2].toNumber(), 0);
            stakingInfo = await valIns.getStakingInfo(staker_1, validator);
            assert.equal(stakingInfo[2].toNumber(), 0);

            // the last one unstake won't change index
            await valIns.unstake(validator, {
                from: staker_2
            })
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 1);
            // staker_2 will be removed
            assert.equal(info[6][0], staker_3);
            stakingInfo = await valIns.getStakingInfo(staker_3, validator);
            assert.equal(stakingInfo[2].toNumber(), 0);
            stakingInfo = await valIns.getStakingInfo(staker_2, validator);
            assert.equal(stakingInfo[2].toNumber(), 0);

            // staker_1 restake will add to list
            let lock = await valIns.StakingLockPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }
            await valIns.withdrawStaking(validator, {
                from: staker_1
            });
            await valIns.stake(validator, {
                from: staker_1,
                value: ether('33')
            });
            info = await valIns.getValidatorInfo(validator);
            assert.equal(info[6].length, 2);
            // staker_2 will be removed
            assert.equal(info[6][1], staker_1);
            stakingInfo = await valIns.getStakingInfo(staker_1, validator);
            assert.equal(stakingInfo[2].toNumber(), 1);
        })

        it("can't stake situation", async function () {
            // validator not exist
            let validator = accounts[31];
            await expectRevert(valIns.stake(validator, {
                from: validator,
                value: ether("100")
            }), "Can't stake to a validator in abnormal status");
            await expectRevert(valIns.stake(constants.ZERO_ADDRESS, {
                from: validator,
                value: ether("100")
            }), "Can't stake to a validator in abnormal status");

            await pass(proposalIns, initValidators, validator);
            await expectRevert(valIns.stake(validator, {
                from: validator,
                value: ether("100")
            }), "Can't stake to a validator in abnormal status");

            await valIns.createOrEditValidator(validator, "", "", "", "", "", {
                from: validator
            });
            // stake amount not enough
            let stake = ether("1");
            await expectRevert(valIns.stake(validator, {
                from: validator,
                value: stake
            }), "Staking coins not enough");
        })

        it("normal stake", async function () {
            let validator = accounts[31];
            let minimal = await valIns.MinimalStakingCoin();

            let receipt = await valIns.stake(validator, {
                from: validator,
                value: minimal
            });
            expectEvent(receipt, "LogStake", {
                staker: validator,
                val: validator,
                staking: minimal
            });

            let stakingInfo = await valIns.getStakingInfo(validator, validator);
            assert.equal(stakingInfo[0].eq(minimal), true);
            assert.equal(stakingInfo[1].isZero(), true);

            // check validator info
            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[1].eq(Staked), true);
            assert.equal(info[2].eq(minimal), true);
        })

        it("anyone can stake to a validator(less than minimal)", async function () {
            let validator = accounts[31];
            let staker = accounts[30];
            let stake = ether('1');

            let receipt = await valIns.stake(validator, {
                from: staker,
                value: stake
            });
            expectEvent(receipt, "LogStake", {
                staker: staker,
                val: validator,
                staking: stake
            });

            let stakingInfo = await valIns.getStakingInfo(staker, validator);
            assert.equal(stakingInfo[0].eq(stake), true);
            assert.equal(stakingInfo[1].isZero(), true);

            // check validator info
            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[1].eq(Staked), true);
            // 32 + 1
            assert.equal(info[2].eq(ether('33')), true);
        })

        it("normal add stake", async function () {
            let validator = accounts[31];
            let staker = accounts[30];
            let addStake = ether('1');

            let receipt = await valIns.stake(validator, {
                from: staker,
                value: addStake
            });
            expectEvent(receipt, "LogStake", {
                staker: staker,
                val: validator,
                staking: addStake
            });

            let stakingInfo = await valIns.getStakingInfo(staker, validator);
            assert.equal(stakingInfo[0].eq(ether('2')), true);
            assert.equal(stakingInfo[1].isZero(), true);

            // check validator info
            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[1].eq(Staked), true);
            // 32 + 2
            assert.equal(info[2].eq(ether('34')), true);
        })
    })

    // test for normal unstake
    describe("unstake/withdraw", async function () {

        it("can't unstake if no stake exist", async function () {
            let validator = accounts[31];
            let staker = accounts[1];

            await expectRevert(valIns.unstake(validator, {
                from: staker
            }), "You don't have any stake");
        })

        it("can't withdraw if not unstake before", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            await expectRevert(
                valIns.withdrawStaking(validator, {
                    from: staker
                }),
                "You have to unstake first"
            )
        })

        it("normal unstake", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            let totalStakeBefore = await valIns.totalStake();

            let receipt = await valIns.unstake(validator, {
                from: staker
            });
            // 1 + 1
            expectEvent(receipt, "LogUnstake", {
                staker: staker,
                val: validator,
                amount: ether('2')
            })

            let totalStakeAfter = await valIns.totalStake();
            assert.equal(totalStakeBefore.sub(totalStakeAfter).eq(ether('2')), true);

            // check validator info
            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[2].eq(ether('32')), true);

            // check staking info
            info = await valIns.getStakingInfo(staker, validator);
            assert.equal(info[0].isZero(), false);
            assert.equal(info[1].isZero(), false);
        })

        it("can't stake when you are unstaking", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            await expectRevert(valIns.stake(validator, {
                from: staker
            }), "Can't stake when you are unstaking");
        })

        it("can't unstake if you are already unstaked", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            await expectRevert(valIns.unstake(validator, {
                from: staker
            }), "You are already in unstaking status");
        })

        it("can't withdraw if stake locked", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            await expectRevert(valIns.withdrawStaking(validator, {
                from: staker
            }), "Your staking haven't unlocked yet");
        })

        it("can withdraw stake if unlocked", async function () {
            let validator = accounts[31];
            let staker = accounts[30];

            let lock = await valIns.StakingLockPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }

            let receipt = await valIns.withdrawStaking(validator, {
                from: staker
            });
            expectEvent(receipt, "LogWithdrawStaking", {
                staker: staker,
                val: validator,
                amount: ether('2')
            });
        })

        it("unstake change validator status to unstaked and unpass ", async function () {
            let validator = accounts[21];
            let staker = validator;
            let is = await valIns.isTopValidator(validator);
            assert.equal(is, true);
            let isPass = await proposalIns.pass(validator);
            assert.equal(isPass, true);

            let receipt = await valIns.unstake(validator, {
                from: staker
            });
            expectEvent(receipt, "LogUnstake", {
                staker: staker,
                val: validator,
                amount: ether('1020')
            });

            // not top validator any more
            is = await valIns.isTopValidator(validator);
            assert.equal(is, false);
            let topValidators = await valIns.getTopValidators();
            assert.equal(topValidators.length, 20);

            // check validator status
            let info = await valIns.getValidatorInfo(validator);
            assert.equal(info[1].eq(Unstaked), true);
            assert.equal(info[2].isZero(), true);

            // check proposal status of validator
            isPass = await proposalIns.pass(validator);
            assert.equal(isPass, false);
        })

        it("can't stake to a unstaked validator", async function () {
            let staker = accounts[31];
            let validator = accounts[21];

            await expectRevert(valIns.stake(validator, {
                from: staker,
                value: ether('100')
            }), "Can't stake to a validator in abnormal status");
        })
    })

    describe("repropose to be a validator if unstaked", async function () {
        let unstakedAccount = accounts[21];
        let staker = accounts[20];

        it("unstaked val can repropose", async function () {
            let info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Unstaked), true);

            await pass(proposalIns, initValidators, unstakedAccount);
            info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Created), true);
        })

        it("can't stake if stake < min stake", async function () {
            let stake = ether("1");

            await expectRevert(valIns.stake(unstakedAccount, {
                from: staker,
                value: stake
            }), "Staking coins not enough");
        })

        it("can stake if pass proposal and stake amount >= minimal", async function () {
            let stake = ether("1000");

            // check status
            let info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Created), true);

            let receipt = await valIns.stake(unstakedAccount, {
                from: staker,
                value: stake
            });
            expectEvent(receipt, "LogStake", {
                staker: staker,
                val: unstakedAccount,
                staking: stake
            });

            info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Staked), true);

            let isTop = await valIns.isTopValidator(unstakedAccount);
            assert.equal(isTop, true);
        })

        it("you can unstake", async function () {
            let receipt = await valIns.unstake(unstakedAccount, {
                from: staker
            });
            expectEvent(receipt, "LogUnstake", {
                staker,
                staker,
                val: unstakedAccount
            })
        })
    })

    describe("distribute block reward", async function () {
        let fee = ether("0.3");
        let expectPerFee = ether("0.1");
        it("miner can distribute to validator contract, the profits should be right updated", async function () {
            let receipt = await valIns.distributeBlockReward({
                from: miner,
                value: fee
            });

            expectEvent(receipt, "LogDistributeBlockReward", {
                coinbase: miner,
                blockReward: fee,
            })

            for (let i = 0; i < initValidators.length; i++) {
                let info = await valIns.getValidatorInfo(miner);

                assert.equal(info[3].toString(10), expectPerFee.toString(10));
            }
        })

        it("validator can withdraw profits", async function () {
            let receipt = await valIns.withdrawProfits(miner, {
                from: miner
            });

            expectEvent(receipt, "LogWithdrawProfits", {
                val: miner,
                fee: miner,
                hb: expectPerFee,
            });

            fee = ether('0.5');
            feeAddr = accounts[10];
            expectFee = fee.div(new BN('3'));
            await valIns.createOrEditValidator(feeAddr, "", "", "", "", "", {
                from: miner
            });
            await valIns.distributeBlockReward({
                from: miner,
                value: fee
            });

            // advance block
            let lock = await valIns.WithdrawProfitPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }

            receipt = await valIns.withdrawProfits(miner, {
                from: feeAddr
            });
            expectEvent(receipt, "LogWithdrawProfits", {
                val: miner,
                fee: feeAddr,
                hb: expectFee,
            });
        })

        it("Can't call withdrawProfits if you don't have any profits", async function () {
            feeAddr = accounts[10];

            // advance block
            let lock = await valIns.WithdrawProfitPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }

            await expectRevert(valIns.withdrawProfits(miner, {
                from: feeAddr
            }), "You don't have any profits");
        })
    })

    describe("update set", async function () {
        it("update active validator set", async function () {
            let epoch = 30;
            let newSet = getNewValidators(accounts);
            while (true) {
                let currentNumber = await web3.eth.getBlockNumber();

                if (currentNumber % epoch == (epoch - 1)) {
                    let receipt = await valIns.updateActiveValidatorSet(newSet, epoch, {
                        from: miner
                    });
                    expectEvent(receipt, "LogUpdateValidator");
                    break;
                }

                await time.advanceBlock();
            }

            // validate validator set
            for (let i = 0; i < initValidators.length; i++) {
                let is = await valIns.isActiveValidator(initValidators[i]);
                assert.equal(is, false);
            }
            for (let i = 0; i < newSet.length; i++) {
                let is = await valIns.isActiveValidator(newSet[i]);
                assert.equal(is, true);
            }
        })
    })
});

contract("Punish", function (accounts) {
    var valIns, proposalIns, punishIns, initValidators;
    var miner = accounts[0];

    before(async function () {
        valIns = await Validators.new();
        proposalIns = await Proposal.new();
        punishIns = await Punish.new();

        initValidators = getInitValidators(accounts);
        await proposalIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS);
        await valIns.setContracts(valIns.address, punishIns.address, proposalIns.address);
        await punishIns.setContracts(valIns.address, punishIns.address, proposalIns.address);

        await valIns.initialize(initValidators);
        await valIns.setMiner(miner);
        await proposalIns.initialize(initValidators);
        await punishIns.initialize();
        await punishIns.setMiner(miner);
    })

    it("can only init once", async function () {
        await expectRevert(punishIns.initialize(), "Already initialized");
    })

    it("prepare", async function () {
        for (let i = 0; i < initValidators.length; i++) {
            let val = initValidators[i];
            await valIns.stake(val, {
                from: initValidators[i],
                value: ether("100")
            });
        }
    })

    describe("punish val", async function () {

        it("miner can punish validator", async function () {
            let removeThreshold = await punishIns.removeThreshold();
            let punishThreshold = await punishIns.punishThreshold();
            let fee = ether("0.4");

            for (let i = 0; i < removeThreshold.toNumber(); i++) {
                // distribute
                await valIns.distributeBlockReward({
                    from: miner,
                    value: fee
                });

                // punish
                let receipt = await punishIns.punish(miner, {
                    from: miner
                });
                expectEvent(receipt, "LogPunishValidator", {
                    val: miner
                });
                let recordInfo = await punishIns.getPunishRecord(miner);
                assert.equal(recordInfo.toNumber(), (i + 1) % removeThreshold.toNumber());

                let info = await valIns.getValidatorInfo(miner);

                if ((i + 1) % removeThreshold.toNumber() == 0) {
                    let is = await valIns.isTopValidator(miner);
                    assert.equal(is, false);

                    assert.equal(recordInfo.toNumber(), 0);
                    assert.equal(info[1].eq(Jailed), true);
                } else if ((i + 1) % punishThreshold.toNumber() == 0) {
                    assert.equal(info[3].toNumber(), 0);
                }
            }

            // check other validator profits.
            let info = await valIns.getValidatorInfo(initValidators[1]);

            let feeBN = new BN(fee.toString());
            let multi = new BN(removeThreshold.toString());
            let expectFee = feeBN.mul(multi).div(new BN("2"));

            // not equal for precision
            console.log("expect", expectFee.toString(), "acutal", info[3].toString());

            // get punish info
            info = await valIns.getValidatorInfo(miner);
            assert.equal(info[3].isZero(), true);
            // not equal for precision reason
            console.log("expect", feeBN.mul(multi).div(new BN('3')).toString(), "acutal", info[4].toString());
        })

        it("validator missed record will decrease if necessary", async function () {
            let removeThreshold = await punishIns.removeThreshold();
            let decreaseRate = await punishIns.decreaseRate();
            let step = 2;
            for (let i = 0; i < removeThreshold.div(decreaseRate).toNumber() + step; i++) {
                if (i < removeThreshold.div(decreaseRate).toNumber()) {
                    await punishIns.punish(initValidators[0], {
                        from: miner
                    });
                }
                await punishIns.punish(initValidators[1], {
                    from: miner
                });
            }

            let l = await punishIns.getPunishValidatorsLen();
            assert.equal(l.toNumber(), 2);

            let expect = await punishIns.getPunishRecord(initValidators[0]);
            // Punish record will be set to 0 if <= removeThreshold/decreaseRate 
            if (expect.lte(removeThreshold.div(decreaseRate))) {
                expect = new BN('0');
            }

            // step to epoch
            let epoch = 30;
            while (true) {
                let currentNumber = await web3.eth.getBlockNumber();
                if (currentNumber % epoch == (epoch - 1)) {
                    let receipt = await punishIns.decreaseMissedBlocksCounter(epoch, {
                        from: miner
                    });
                    expectEvent(receipt, "LogDecreaseMissedBlocksCounter");
                    break;
                }

                await time.advanceBlock();
            }

            let acutal_0 = await punishIns.getPunishRecord(initValidators[0]);
            assert.equal(expect.toNumber(), acutal_0.toNumber());
            let acutal_1 = await punishIns.getPunishRecord(initValidators[1]);
            assert.equal(acutal_1.toNumber(), step);
        })

        it("Can't stake to a jailed validator", async function () {
            let jailed = initValidators[0];

            await punishIns.punish(jailed, {
                from: miner
            });
            let record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), false);

            let info = await valIns.getValidatorInfo(jailed);
            assert.equal(info[2].isZero(), false);

            // not repass proposal
            await expectRevert(
                valIns.stake(jailed, {
                    from: jailed,
                    value: ether("32")
                }),
                "Can't stake to a validator in abnormal status"
            )
        })

        it("jailed record will be cleaned if validator repass proposal", async function () {
            let jailed = initValidators[0];
            let record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), false);

            await pass(proposalIns, initValidators, jailed);

            // check record
            record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), true);

            // not in punish list
            let len = await punishIns.getPunishValidatorsLen();

            for (let i = 0; i < len.toNumber(); i++) {
                let punishee = await punishIns.punishValidators(i);
                assert.equal(punishee == jailed, false);
            }
        })

        it("can stake to a jailed validator if he repass proposal(staked exist)", async function () {
            let staker = accounts[5];
            let jailed = initValidators[0];
            let stake = ether('1');

            await valIns.stake(jailed, {
                from: staker,
                value: stake
            });

            // get jailed validator info
            let info = await valIns.getValidatorInfo(jailed);
            // original 100 + stake 1
            assert.equal(info[2].eq(ether('101')), true);
        })
    })
})

async function pass(proposalIns, validators, who) {
    let receipt = await proposalIns.createProposal(who, "test", {
        from: who
    });
    let id = receipt.logs[0].args.id;
    for (let i = 0; i < validators.length / 2 + 1; i++) {
        await proposalIns.voteProposal(id, true, {
            from: validators[i]
        });
    }
}

function getInitValidators(accounts) {
    return accounts.slice(0, 3);
}

function getNewValidators(accounts) {
    return accounts.slice(3, 6);
}

function getInvalidMoniker() {
    let r = ""
    for (let i = 0; i < 71; i++) {
        r += i;
    }

    return r;
}