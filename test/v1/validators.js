const Validators = artifacts.require('cache/solpp-generated-contracts/v1/Validators.sol:Validators');
const VotePool = artifacts.require('cache/solpp-generated-contracts/v1/mock/MockVotePool.sol:VotePool');
const Punish = artifacts.require('MockPunish');

const {assert} = require('hardhat');
const {expectEvent, expectRevert, ether, balance} = require("@openzeppelin/test-helpers");

const Pos = 0
const Poa = 1

contract("Validators test", accounts => {
    let validators;
    let punish;
    let admin;

    before('deploy validator', async () => {
        validators = await Validators.new()
        punish = await Punish.new()
    })

    before('init validator', async () => {
        await validators.initialize(accounts.slice(10, 15), accounts.slice(10, 15), accounts[1], {gas: 12450000})
        assert.equal(await validators.admin(), accounts[1])
        admin = accounts[1]

        let vals = await validators.getTopValidators()
        assert.equal(vals.length, 5, 'validator length')
    })

    it('only admin', async () => {
        let inputs = [
            ['changeAdmin', [accounts[0]]],
            ['updateParams', [11, 10, 10, 11]],
            ['addValidator', [accounts[0], accounts[0], 20, Pos]],
            ['updateValidatorState', [accounts[0], true]],
            ['updateRates', [11, 10]],
            ['updateFoundation', [accounts[0]]],
        ]

        for (let input of inputs) {
            await expectRevert(validators[input[0]](...input[1], {from: accounts[0]}), 'Only admin')
        }
    })

    it('change admin', async () => {
        let tx = await validators.changeAdmin(accounts[0], {from: admin})
        await expectEvent(tx, 'ChangeAdmin', {admin: accounts[0]})
        assert.equal(await validators.admin(), accounts[0])
        admin = accounts[0]
    })

    it('change params', async () => {
        //params incorrect
        await expectRevert(validators.updateParams(1, 1, 1, 1, {from: admin}), 'Invalid counts')

        let tx = await validators.updateParams(20, 20, 1, 1, {from: admin})

        await expectEvent(tx, 'UpdateParams', {
            posCount: '20',
            posBackup: '20',
            poaCount: '1',
            poaBackup: '1',
        })

        assert.equal((await validators.count(Pos)).toNumber(), 20, 'pos count')
        assert.equal((await validators.count(Poa)).toNumber(), 1, 'poa count')
        assert.equal((await validators.backupCount(Pos)).toNumber(), 20, 'pos backup count')
        assert.equal((await validators.backupCount(Poa)).toNumber(), 1, 'poa backup count')
    })

    it('update rates', async () => {
        await expectRevert(validators.updateRates(10000, 1, {from: admin}), 'Invalid rates')

        let tx = await validators.updateRates(20, 30, {from: admin})
        await expectEvent(tx, 'UpdateRates', {
            burnRate: '20',
            foundationRate: '30'
        })

        assert.equal((await validators.burnRate()).toNumber(), 20, 'burn rate')
        assert.equal((await validators.foundationRate()).toNumber(), 30, 'foundation rate')
    })

    it('update foundation address', async () => {
        let tx = await validators.updateFoundation(accounts[0])

        await expectEvent(tx, "UpdateFoundationAddress", {foundation: accounts[0]})
        assert.equal(await validators.foundation(), accounts[0], 'foundation address')
    })

    it("get top validators", async () => {
        let vals = await validators.getTopValidators()
        assert.equal(vals.length, 1, 'validator length')
    })

    it("add validator", async () => {
        let tx = await validators.addValidator(accounts[0], accounts[0], 10, Pos, {
            from: admin,
            gas: 4000000
        })

        await expectEvent(tx, 'AddValidator', {
            validator: accounts[0],
            votePool: await validators.votePools(accounts[0])
        })
    })

    it('only registered', async () => {
        let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)

        await c.changeVote(50)
        await expectRevert(c.changeVoteAndRanking(await validators.address, 100), 'Vote pool not registered')
    })

    it('updateActiveValidatorSet', async () => {
        let vals = await validators.getTopValidators()
        await validators.updateActiveValidatorSet(vals, 200)
        assert.equal((await validators.getActiveValidators()).length, 1, 'active validators length')
        assert.equal((await validators.getBackupValidators()).length, 1, 'backup validators length')
    })

    it('distribute reward for burn and foundation', async () => {
        await validators.updateRates(100, 100, {
            from: admin,
        })

        await validators.updateFoundation(accounts[10], {from: admin})

        let burnReceiver = '0x000000000000000000000000000000000000FaaA'

        let beforeReward = await validators.foundationReward()
        let beforeBurn = await balance.current(burnReceiver)
        await validators.distributeBlockReward({
            from: admin,
            gas: 4000000,
            value: ether('10', 'ether').toString()
        })
        let afterReward = await validators.foundationReward()
        let afterBurn = await balance.current(burnReceiver)
        assert.equal(afterReward.sub(beforeReward).toString(), ether('0.1').toString(), 'foundation value')
        assert.equal(afterBurn.sub(beforeBurn).toString(), ether('0.1').toString(), 'burn value')
    });

    it('withdraw foundation reward', async () => {
        await validators.updateFoundation(accounts[15], {from: admin})
        await expectRevert(validators.withdrawFoundationReward({from: admin}), 'Only foundation')

        //clean up
        await validators.withdrawFoundationReward({from: accounts[15]})

        let before = await balance.current(accounts[15])

        await validators.updateRates(0, 10000, {
            from: admin,
        })
        await validators.distributeBlockReward({
            from: admin,
            gas: 4000000,
            value: ether('1')
        })

        let tx = await validators.withdrawFoundationReward({from: accounts[15], gasPrice: 0})
        await expectEvent(tx, 'WithdrawFoundationReward', {
            receiver: accounts[15],
            amount: ether('1'),
        })
        let after = await balance.current(accounts[15])

        assert.equal(after.sub(before).toString(), ether('1').toString(), 'withdraw foundation reward')
    })

    it('distribute reward for validators', async () => {
        let reward = ether('1')

        let pos = [
            {addr: accounts[0], type: Pos, vote: 500, reward: '158385093167701862'}, // validator
            {addr: accounts[1], type: Pos, vote: 400, reward: '140993788819875775'}, // validator
            {addr: accounts[2], type: Pos, vote: 300, reward: '123602484472049688'}, // validator
            {addr: accounts[3], type: Pos, vote: 200, reward: '106211180124223601'}, //validator
        ]

        let poa = [
            {addr: accounts[4], type: Poa, vote: 400, reward: '140993788819875775'}, //validator
            {addr: accounts[5], type: Poa, vote: 300, reward: '123602484472049688'}, //validator
            {addr: accounts[6], type: Poa, vote: 200, reward: '106211180124223601'}, //validator
            {addr: accounts[7], type: Poa, vote: 200, reward: '57142857142857142'}, // backup
            {addr: accounts[8], type: Poa, vote: 150, reward: '42857142857142857'}, // backup
            {addr: accounts[9], type: Poa, vote: 100, reward: '0'}, // none
        ]

        validators = await Validators.new()
        await validators.initialize([accounts[10]], [accounts[10]], admin, {gas: 12450000})
        await validators.updateParams(18, 0, 3, 2, {from: admin})
        //all reward to validator
        await validators.updateRates(0, 0, {from: admin})


        for (const it of pos.concat(poa)) {
            await validators.addValidator(it.addr, it.addr, 0, it.type, {
                from: admin,
                gas: 4000000
            })

            let pool = new VotePool(await validators.votePools(it.addr))

            await pool.changeState(1)
            await pool.changeVoteAndRanking(validators.address, it.vote)

        }

        let vals = await validators.getTopValidators()

        await validators.updateActiveValidatorSet(vals, 200)

        await validators.distributeBlockReward({
            from: admin,
            gas: 4000000,
            value: reward
        })
        for (const it of pos.concat(poa)) {
            let pool = await validators.votePools(it.addr)
            assert.equal(it.reward, (await validators.pendingReward(pool)).toString())
        }
    })
});
