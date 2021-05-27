const Validator = artifacts.require('Validator');
const Candidate = artifacts.require('MockCandidatePool');
const Punish = artifacts.require('MockPunish');

const {assert} = require('hardhat');
const truffleAssert = require('truffle-assertions');
const {web3, BN} = require('@openzeppelin/test-helpers/src/setup');

const Pos = 0
const Poa = 1

contract("Validator test", accounts => {
    let validator;
    let punish;

    before('deploy validator', async () => {
        validator = await Validator.new()
        punish = await Punish.new()
    })

    before('init validator', async () => {
        await validator.initialize(accounts.slice(10, 15), accounts.slice(10, 15), accounts[1], {gas: 12450000})
        assert.equal(await validator.admin(), accounts[1])

        let vals = await validator.getTopValidators()
        assert.equal(vals.length, 5, 'validator length')
    })

    it('only admin', async () => {
        let inputs = [
            ['changeAdmin', [accounts[0]]],
            ['updateParams', [11, 10, 10, 11]],
            ['addCandidate', [accounts[0], accounts[0], 20, Pos]],
            ['updateCandidateState', [accounts[0], true]]
        ]

        for (let input of inputs) {
            try {
                await validator[input[0]](...input[1], {from: accounts[0]})
            } catch (e) {
                assert(e.message.search('Only admin') >= 0, input[0])
            }
        }
    })

    it('change admin', async () => {
        let tx = await validator.changeAdmin(accounts[0], {from: accounts[1]})
        truffleAssert.eventEmitted(tx, 'ChangeAdmin', {admin: accounts[0]})
        assert.equal(await validator.admin(), accounts[0])
    })

    it('change params', async () => {
        //params incorrect
        try {
            await validator.updateParams(1, 1, 1, 1, {from: accounts[0]})
        } catch (e) {
            assert(e.message.search('Invalid validator counts') >= 0, 'invalid validator count')
        }

        let tx = await validator.updateParams(20, 20, 1, 1, {from: accounts[0]})

        truffleAssert.eventEmitted(tx, 'UpdateParams', ev => ev.posCount.toNumber() === 20
            && ev.posBackup.toNumber() === 20
            && ev.poaCount.toNumber() === 1
            && ev.poaBackup.toNumber() === 1)

        assert.equal((await validator.count(Pos)).toNumber(), 20, 'pos count')
        assert.equal((await validator.count(Poa)).toNumber(), 1, 'poa count')
        assert.equal((await validator.backupCount(Pos)).toNumber(), 20, 'pos backup count')
        assert.equal((await validator.backupCount(Poa)).toNumber(), 1, 'poa backup count')
    })

    it("get top validators", async () => {
        let vals = await validator.getTopValidators()
        assert.equal(vals.length, 1, 'validator length')
    })

    it("add candidate", async () => {
        let tx = await validator.addCandidate(accounts[0], accounts[0], 10, Pos, {
            from: accounts[0],
            gas: 2000000
        })

        truffleAssert.eventEmitted(tx, 'AddCandidate', {
            candidate: accounts[0],
            contractAddress: await validator.candidatePools(accounts[0])
        })

        assert(tx.receipt.status)
    })

    it('only registered', async () => {
        let c = await Candidate.new(accounts[0], accounts[0], 0, 1)
        await c.changeVote(50)
        try {
            await c.changeVoteAndRanking(await validator.address, 100)
        } catch (e) {
            assert(e.message.search('Candidate pool not registered') >= 0, "change vote to 100")
        }

        try {
            await c.changeVoteAndRanking(await validator.address, 0)
        } catch (e) {
            assert(e.message.search('Candidate pool not registered') >= 0, "change vote to 0")
        }
    })

    it('updateActiveValidatorSet', async () => {
        let vals = await validator.getTopValidators()
        await validator.updateActiveValidatorSet(vals, 200)
        assert.equal((await validator.getActiveValidators()).length, 1, 'active validators length')
        assert.equal((await validator.getBackupValidators()).length, 4, 'backup validators length')
    })

    it('distributeBlockReward', async () => {
        await validator.addCandidate(accounts[1], accounts[1], 10, Pos, {
            from: accounts[0],
            gas: 2000000
        })

        let candidate0 = await Candidate.at(await validator.candidatePools(accounts[0]))
        let candidate1 = await Candidate.at(await validator.candidatePools(accounts[1]))

        for (let can of [candidate0, candidate1]) {
            await can.setAddress(validator.address, punish.address)

            let from = await can.candidate()
            await can.addMargin({from, value: web3.utils.toWei("10", 'ether')})
            await can.deposit({from, value: web3.utils.toWei("10", 'ether')})
        }

        let vals = await validator.getTopValidators()
        await validator.updateActiveValidatorSet(vals, 200)
        assert.equal((await validator.getActiveValidators()).length, 3, 'active validators length')
        assert.equal((await validator.getBackupValidators()).length, 4, 'backup validators length')

        await validator.distributeBlockReward({from: accounts[0], value: web3.utils.toWei("100", "ether")})

        //backup vals
        for (let i = 11; i < 15; i++) {
            let candidate = await validator.candidatePools(accounts[i])
            //100 * 0.1 / 4
            assert.equal((await validator.pendingReward(candidate)).toString(), web3.utils.toWei(new BN(100), "ether").mul(new BN(1)).div(new BN(40)).toString())
        }

        //no staking   100 * 0.5 / 3
        assert.equal((await validator.pendingReward(await validator.candidatePools(accounts[10]))).toString(), web3.utils.toWei(new BN(100), "ether").mul(new BN(5)).div(new BN(30)).toString())

        //staking  100 * 0.5 / 3 + 100 * 0.4 / 2
        assert.equal((await validator.pendingReward(await validator.candidatePools(accounts[0]))).toString(),
            web3.utils.toWei(new BN(100), "ether").mul(new BN(5)).div(new BN(30)).add(
                web3.utils.toWei(new BN(100), "ether").mul(new BN(4)).div(new BN(20))
            ).toString())
    })


    // use to check gas used when 21 val + 21 backup
    // it('distributeBlockReward2', async () => {
    //     for (let i = 0; i < accounts.length; i++) {
    //         if ((await validator.candidates(accounts[i])) !== '0x0000000000000000000000000000000000000000') {
    //             continue
    //         }
    //         await validator.addCandidate(accounts[i], accounts[i], 10, Pos, {
    //             from: accounts[0],
    //             gas: 2000000
    //         })
    //
    //
    //         let can = await Candidate.at(await validator.candidates(accounts[i]))
    //         await can.setAddress(validator.address, punish.address)
    //
    //         let from = await can.candidate()
    //         await can.addMargin({from, value: web3.utils.toWei("10", 'ether')})
    //         await can.deposit({from, value: web3.utils.toWei("10", 'ether')})
    //     }
    //
    //     let vals = await validator.getTopValidators()
    //     await validator.updateActiveValidatorSet(vals, 200)
    //
    //     assert.equal(await validator.getActiveValidatorsCount(), 21, 'active validators length')
    //
    //     let tx = await validator.distributeBlockReward({from: accounts[0], value: web3.utils.toWei("100", "ether")})
    //     console.log(tx)
    // })

});
