const Proposal = artifacts.require("Proposal");
const Validators = artifacts.require('Validators');
const HSCTToken = artifacts.require("HSCTToken");
const Punish = artifacts.require("Punish");

const { constants, expectRevert, expectEvent, time, ether, BN } = require('@openzeppelin/test-helpers');

const Staked = new BN("1");
const Unstaking = new BN("2");
const Unstaked = new BN("3");
const Jailed = new BN("4");

contract("Validators test", function (accounts) {
    var valIns, proposalIns, punishIns, initValidators;
    var miner = accounts[0];
    var admin = accounts[0];
    var premint = accounts[0];

    before(async function () {
        valIns = await Validators.new();
        proposalIns = await Proposal.new();
        hsctTokenIns = await HSCTToken.new();
        punishIns = await Punish.new();

        initValidators = getInitValidators(accounts);
        await proposalIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS,);
        await hsctTokenIns.setContracts(valIns.address, constants.ZERO_ADDRESS, proposalIns.address, hsctTokenIns.address);
        await valIns.setContracts(valIns.address, punishIns.address, proposalIns.address, hsctTokenIns.address);
        await punishIns.setContracts(valIns.address, punishIns.address, proposalIns.address, hsctTokenIns.address);

        await valIns.initialize(initValidators, admin);
        await valIns.setMiner(miner);
        await proposalIns.initialize(initValidators);
        await hsctTokenIns.initialize(premint);
        await punishIns.initialize();
    })

    before("can only init once", async function () {
        await expectRevert(valIns.initialize(initValidators, admin), "Already initialized");
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

    // test for normal staking
    describe("Staking", async function () {
        it("norma stake", async function () {
            let stakingCase = [
                { accountIndex: 3, staking: web3.utils.toWei("100"), isTopValidator: true },
                { accountIndex: 4, staking: web3.utils.toWei("200"), isTopValidator: true },
                { accountIndex: 5, staking: web3.utils.toWei("300"), isTopValidator: true },
                { accountIndex: 6, staking: web3.utils.toWei("400"), isTopValidator: true },
                { accountIndex: 7, staking: web3.utils.toWei("500"), isTopValidator: true },
                { accountIndex: 8, staking: web3.utils.toWei("600"), isTopValidator: true },
                { accountIndex: 9, staking: web3.utils.toWei("700"), isTopValidator: true },
                { accountIndex: 10, staking: web3.utils.toWei("800"), isTopValidator: true },
                { accountIndex: 11, staking: web3.utils.toWei("900"), isTopValidator: true },
                { accountIndex: 12, staking: web3.utils.toWei("110"), isTopValidator: true },
                { accountIndex: 13, staking: web3.utils.toWei("200"), isTopValidator: true },
                { accountIndex: 14, staking: web3.utils.toWei("1000"), isTopValidator: true },
                { accountIndex: 15, staking: web3.utils.toWei("2000"), isTopValidator: true },
                { accountIndex: 16, staking: web3.utils.toWei("1000"), isTopValidator: true },
                { accountIndex: 17, staking: web3.utils.toWei("1000"), isTopValidator: true },
                { accountIndex: 18, staking: web3.utils.toWei("1020"), isTopValidator: true },
                { accountIndex: 19, staking: web3.utils.toWei("1300"), isTopValidator: true },
                { accountIndex: 20, staking: web3.utils.toWei("1400"), isTopValidator: true },
                { accountIndex: 21, staking: web3.utils.toWei("1020"), isTopValidator: true },
                // 22
                { accountIndex: 22, staking: web3.utils.toWei("120"), isTopValidator: true },
                { accountIndex: 23, staking: web3.utils.toWei("200"), isTopValidator: true },
                { accountIndex: 24, staking: web3.utils.toWei("110"), isTopValidator: true },
                { accountIndex: 25, staking: web3.utils.toWei("50"), isTopValidator: false },
            ]
            let expectValidatorAccountIndex = [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];

            for (let i = 0; i < stakingCase.length; i++) {
                let account = accounts[stakingCase[i].accountIndex];
                await pass(proposalIns, initValidators, account);
                let receipt = await valIns.stake(account, "", "", "", "", "", { from: account, value: stakingCase[i].staking });
                expectEvent(receipt, "LogCreateValidator", { val: account, fee: account, staking: stakingCase[i].staking });

                let isVal = await valIns.isTopValidator(account);
                assert.equal(isVal, stakingCase[i].isTopValidator);
            }

            // check final top validators
            for (let i = 0; i < expectValidatorAccountIndex; i++) {
                let account = accounts[expectValidatorAccountIndex[i]];

                let isVal = await valIns.isTopValidator(account);
                assert.equal(isVal, true);
            }
        })

        it("can't stake situation", async function () {
            // not pass proposal
            let account = accounts[30];
            await expectRevert(valIns.stake(account, "", "", "", "", "", { from: account, value: web3.utils.toWei("100") }), "You must be authorized first");

            // stake amount not enough
            let stake = web3.utils.toWei("1");
            await pass(proposalIns, initValidators, account);
            await expectRevert(valIns.stake(account, "", "", "", "", "", { from: account, value: stake }), "Staking coins not enough");

            // invalid fee addr
            stake = await valIns.MinimalStakingCoin();
            await expectRevert(valIns.stake(constants.ZERO_ADDRESS, "", "", "", "", "", { from: account, value: stake }), "Invalid fee address");

            // invalid describe
            let invalidMoniker = getInvalidMoniker();
            await expectRevert(valIns.stake(account, invalidMoniker, "", "", "", "", { from: account, value: stake }), "Invalid moniker length");
        })

        it("normal add stake", async function () {
            let account = accounts[1];
            let addStake = web3.utils.toWei("200");

            let receipt = await valIns.stake(account, "", "", "", "", "", { from: account, value: addStake });

            expectEvent(receipt, "LogAddStake", { val: account, addAmount: addStake });
            // this account will be top validator
            let is = await valIns.isTopValidator(account);
            assert.equal(is, true);
        })

        it("withdraw stake will transfer stake back to original validator", async function () {
            let val = accounts[41];
            let fee = accounts[42];
            let stake = ether('100');
            await pass(proposalIns, initValidators, val);
            await valIns.stake(fee, "", "", "", "", "", { from: val, value: stake });

            await valIns.unstake({ from: val });

            let lock = await valIns.StakingLockPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }

            let receipt = await valIns.withdrawStaking({ from: val });
            expectEvent(receipt, "LogWithdrawStaking", { val: val, amount: stake });
        })
    })

    describe("Edit validator", async function () {
        // edit validator info
        it("Edit validator info", async function () {
            // validator not exist
            let account = accounts[31];
            await expectRevert(valIns.editValidator(account, "", "", "", "", "", { from: account }), "Validator not exist");

            // fee addr invalid
            account = accounts[1];
            await expectRevert(valIns.editValidator(constants.ZERO_ADDRESS, "", "", "", "", "", { from: account }), "Invalid fee address");

            // invalid moniker
            let moniker = getInvalidMoniker();
            await expectRevert(valIns.editValidator(account, moniker, "", "", "", "", { from: account }), "Invalid moniker length");
        })
    })

    // test for normal unstake
    describe("unstake", async function () {
        it("normal unstake", async function () {
            let account = accounts[1];
            let is = await valIns.isTopValidator(account);
            assert.equal(is, true);

            let receipt = await valIns.unstake({ from: account });
            expectEvent(receipt, "LogUnstake", { val: account });
            // not top validator any more
            is = await valIns.isTopValidator(account);
            assert.equal(is, false);
            let topValidators = await valIns.getTopValidators();
            assert.equal(topValidators.length, 20);
            // check validator status
            let info = await valIns.getValidatorInfo(account);
            assert.equal(info[1].eq(Unstaking), true);
        })

        it("can't unstake situation", async function () {
            // validator not exist
            let account = accounts[31];
            await expectRevert(valIns.unstake({ from: account }), "Invalid status, can't unstake");

            // validator is unstaking
            account = accounts[1];
            await expectRevert(valIns.unstake({ from: account }), "Invalid status, can't unstake");
        })

        it("can't withdraw staking back if locked", async function () {
            let account = accounts[1];
            await expectRevert(valIns.withdrawStaking({ from: account }), "Your staking haven't lock yet");
        })

        it("can withdraw staking back if unlocked", async function () {
            let account = accounts[1];
            let blocks = await valIns.StakingLockPeriod();

            for (let i = 0; i < blocks.toNumber(); i++) {
                await time.advanceBlock();
            }

            let info = await valIns.getValidatorInfo(account);
            let receipt = await valIns.withdrawStaking({ from: account });
            expectEvent(receipt, "LogWithdrawStaking", { val: account, amount: info[2] });
            info = await valIns.getValidatorInfo(account);
            assert.equal(info[1].eq(Unstaked), true);
        })
    })

    describe("repropose to be a validator if removed", async function () {
        let unstakedAccount = accounts[1];

        it("can't stake if removed without withdraw stake or repass proposal", async function () {
            let stake = web3.utils.toWei("100");

            await expectRevert(valIns.stake(unstakedAccount, "", "", "", "", "", { from: unstakedAccount, value: stake }), "You must be authorized first");
        })

        it("unstaked val can repropose", async function () {
            await pass(proposalIns, initValidators, unstakedAccount);
        })

        it("can't stake if stake < min stake", async function () {
            let stake = web3.utils.toWei("1");

            await expectRevert(valIns.stake(unstakedAccount, "", "", "", "", "", { from: unstakedAccount, value: stake }), "Staking coins not enough");
        })

        it("can stake if pass proposal and stake amount >= minimal", async function () {
            let stake = web3.utils.toWei("1000");

            // check status
            let info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Unstaked), true);

            let receipt = await valIns.stake(unstakedAccount, "", "", "", "", "", { from: unstakedAccount, value: stake });
            expectEvent(receipt, "LogRestake", { val: unstakedAccount, restake: stake });

            info = await valIns.getValidatorInfo(unstakedAccount);
            assert.equal(info[1].eq(Staked), true);

            await valIns.isTopValidator(unstakedAccount);
        })

        it("you can unstake", async function () {
            let receipt = await valIns.unstake({ from: unstakedAccount });
            expectEvent(receipt, "LogUnstake", { val: unstakedAccount })
        })
    })

    describe("deposit block reward and profits", async function () {
        let fee = web3.utils.toWei("0.3");
        it("miner can deposit to validator contract", async function () {
            let receipt = await valIns.depositBlockReward({ from: miner, value: fee });

            expectEvent(receipt, "LogDepositBlockReward", { val: miner, hb: fee, hsct: fee })

            let info = await valIns.getValidatorInfo(miner);

            assert.equal(info[4].toString(10), fee.toString(10));
            assert.equal(info[5].toString(10), fee.toString(10));
        })

        it("validator can withdraw profits", async function () {
            let receipt = await valIns.withdrawProfits(miner, { from: miner });

            expectEvent(receipt, "LogWithdrawProfits", { val: miner, fee: miner, hb: fee, hsct: fee });

            fee = ether('0.5');
            feeAddr = accounts[10];
            await valIns.editValidator(feeAddr, "", "", "", "", "", { from: miner });
            await valIns.depositBlockReward({ from: miner, value: fee });

            // advance block
            let lock = await valIns.WithdrawProfitPeriod();
            for (let i = 0; i < lock.toNumber(); i++) {
                await time.advanceBlock();
            }

            receipt = await valIns.withdrawProfits(miner, { from: feeAddr });
            expectEvent(receipt, "LogWithdrawProfits", { val: miner, fee: feeAddr, hb: fee, hsct: fee });
        })
    })

    describe("update set", async function () {
        it("update active validator set", async function () {
            let epoch = 30;
            let newSet = getNewValidators(accounts);
            while (true) {
                let currentNumber = await web3.eth.getBlockNumber();

                if (currentNumber % epoch == (epoch - 1)) {
                    let receipt = await valIns.updateActiveValidatorSet(newSet, epoch, { from: miner });
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
    var premint = accounts[0];
    var admin = accounts[0];

    before(async function () {
        valIns = await Validators.new();
        proposalIns = await Proposal.new();
        hsctTokenIns = await HSCTToken.new();
        punishIns = await Punish.new();

        initValidators = getInitValidators(accounts);
        await proposalIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS,);
        await hsctTokenIns.setContracts(valIns.address, constants.ZERO_ADDRESS, proposalIns.address, hsctTokenIns.address);
        await valIns.setContracts(valIns.address, punishIns.address, proposalIns.address, hsctTokenIns.address);
        await punishIns.setContracts(valIns.address, punishIns.address, proposalIns.address, hsctTokenIns.address);

        await valIns.initialize(initValidators, admin);
        await valIns.setMiner(miner);
        await proposalIns.initialize(initValidators);
        await hsctTokenIns.initialize(premint);
        await punishIns.initialize();
        await punishIns.setMiner(miner);
    })

    it("can only init once", async function () {
        await expectRevert(punishIns.initialize(), "Already initialized");
    })

    it("prepare", async function () {
        for (let i = 0; i < initValidators.length; i++) {
            let val = initValidators[i];
            await valIns.stake(val, "", "", "", "", "", { from: initValidators[i], value: web3.utils.toWei("100") });
        }
    })

    describe("punish val", async function () {
        it("miner can punish validator", async function () {
            let removeThreshold = await punishIns.removeThreshold();
            let punishThreshold = await punishIns.punishThreshold();
            let fee = web3.utils.toWei("0.4");

            for (let i = 0; i < removeThreshold.toNumber(); i++) {
                // deposit
                await valIns.depositBlockReward({ from: miner, value: fee });

                // punish
                let receipt = await punishIns.punish(miner, { from: miner });
                expectEvent(receipt, "LogPunishValidator", { val: miner });
                let recordInfo = await punishIns.getPunishRecord(miner);
                assert.equal(recordInfo.toNumber(), (i + 1) % removeThreshold.toNumber());

                let info = await valIns.getValidatorInfo(miner);

                if ((i + 1) % removeThreshold.toNumber() == 0) {
                    let is = await valIns.isTopValidator(miner);
                    assert.equal(is, false);

                    assert.equal(recordInfo.toNumber(), 0);
                    assert.equal(info[1].eq(Jailed), true);
                } else if ((i + 1) % punishThreshold.toNumber() == 0) {
                    assert.equal(info[4].toNumber(), 0);
                    assert.equal(info[5].toNumber(), 0);
                }
            }

            // check other validator profits.
            let info = await valIns.getValidatorInfo(initValidators[1]);

            let feeBN = new BN(fee.toString());
            let RewardBN = new BN(fee.toString());
            let multi = new BN(removeThreshold.toString());
            let expectFee = feeBN.mul(multi).div(new BN("2"));
            let expectReward = RewardBN.mul(multi).div(new BN("2"));
            assert.equal(info[4].toString(), expectFee.toString());
            assert.equal(info[5].toString(), expectReward.toString());

            // get punish info
            info = await valIns.getValidatorInfo(miner);
            assert.equal(info[4].isZero(), true);
            assert.equal(info[5].isZero(), true);
            assert.equal(info[6].toString(), feeBN.mul(multi).toString());
            assert.equal(info[7].toString(), RewardBN.mul(multi).toString());
        })

        it("validator missed record will decrease if necessary", async function () {
            let removeThreshold = await punishIns.removeThreshold();
            let decreaseRate = await punishIns.decreaseRate();
            let step = 2;
            for (let i = 0; i < removeThreshold.div(decreaseRate).toNumber() + step; i++) {
                if (i < removeThreshold.div(decreaseRate).toNumber()) {
                    await punishIns.punish(initValidators[0], { from: miner });
                }
                await punishIns.punish(initValidators[1], { from: miner });
            }

            let l = await punishIns.getPunishValidatorsLen();
            assert.equal(l.toNumber(), 2);

            let expect = await punishIns.getPunishRecord(initValidators[0]);

            // step to epoch
            let epoch = 30;
            while (true) {
                let currentNumber = await web3.eth.getBlockNumber();
                if (currentNumber % epoch == (epoch - 1)) {
                    let receipt = await punishIns.decreaseMissedBlocksCounter(epoch, { from: miner });
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

        it("jailed validator can't stake if not withdraw staking or not repass proposal", async function () {
            let jailed = initValidators[0];
            let record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), false);

            let info = await valIns.getValidatorInfo(jailed);
            assert.equal(info[3].isZero(), false);

            // not repass proposal
            await expectRevert(
                valIns.stake(jailed, "", "", "", "", "", { from: jailed, value: ether("32") }),
                "You must be authorized first"
            )

            await pass(proposalIns, initValidators, jailed);
            await expectRevert(
                valIns.stake(jailed, "", "", "", "", "", { from: jailed, value: ether("32") }),
                "You can only add stake when staked"
            )

            // step block number to pass staking lock
            let blocks = await valIns.StakingLockPeriod();
            for (let i = 0; i < blocks.toNumber(); i++) {
                await time.advanceBlock();
            }
            await valIns.withdrawStaking({ from: jailed });

            // stake amount not enough
            await expectRevert(
                valIns.stake(jailed, "", "", "", "", "", { from: jailed, value: ether("31") }),
                "Staking coins not enough"
            )
        })

        it("jailed validator stake will clean record", async function () {
            let jailed = initValidators[0];
            let record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), false);

            // now you can stake
            let info = await valIns.getValidatorInfo(jailed);
            let beforeStake = info[2];
            assert.equal(beforeStake.isZero(), true);
            let receipt = await valIns.stake(jailed, "", "", "", "", "", { from: jailed, value: ether('100') });
            expectEvent(receipt, "LogRestake", { val: jailed, restake: ether('100') });

            // stake should right updated
            info = await valIns.getValidatorInfo(jailed);
            assert.equal(ether('100').eq(info[2]), true);

            // record is cleared
            record = await punishIns.getPunishRecord(jailed);
            assert.equal(record.isZero(), true);
            // not in punish list
            let len = await punishIns.getPunishValidatorsLen();

            for (let i = 0; i < len.toNumber(); i++) {
                let punishee = await punishIns.punishValidators(i);
                assert.equal(punishee == jailed, false);
            }
        })
    })
})

async function pass(proposalIns, validators, who) {
    let receipt = await proposalIns.createProposal(who, "test", { from: who });
    let id = receipt.logs[0].args.id;
    for (let i = 0; i < validators.length / 2 + 1; i++) {
        await proposalIns.voteProposal(id, true, { from: validators[i] });
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