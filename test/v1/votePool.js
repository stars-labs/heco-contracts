const Validators = artifacts.require('cache/solpp-generated-contracts/v1/mock/MockValidators.sol:MockValidators');
const Punish = artifacts.require('MockPunish');
const VotePool = artifacts.require('cache/solpp-generated-contracts/v1/VotePool.sol:VotePool');

const {web3, BN} = require('@openzeppelin/test-helpers/src/setup');
const {expectEvent, expectRevert, ether, balance} = require("@openzeppelin/test-helpers");

const Pos = 0
const Poa = 1

contract("VotePool test", accounts => {
    let validators;
    let punish;
    let validator;
    let manager;

    before('deploy', async () => {
        validators = await Validators.new()
        punish = await Punish.new()
    })

    it("add pool", async () => {
        let tx = await validators.addValidator(accounts[0], accounts[0], 20, Pos, {
            from: accounts[0],
            gas: 3000000
        })
        assert(tx.receipt.status)

        validator = accounts[0]
        manager = accounts[0]

        let pool = await VotePool.at(await validators.votePools(validator))
        await pool.setAddress(validators.address, punish.address)

        assert.equal(await pool.state(), 0)
    })

    // it('only pool', async() => {
    //     let inputs = [
    //         ['changeManager', [accounts[0]]],
    //     ]

    //     let pool = await VotePool.at(await validators.votePools(accounts[0]))

    //     for(let input of inputs) {
    //         try {
    //             await pool[input[0]](...input[1], {from: accounts[1]})
    //         }catch (e) {
    //             console.log(e)
    //             assert(e.message.search('Only pool') >= 0, input[0])
    //         }
    //     }
    // })


    it("change manager", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))

        let tx = await pool.changeManager(accounts[1], {from: validator})
        await expectEvent(tx, "ChangeManager", {manager: accounts[1]})
        manager = accounts[1]
    })

    it("add margin", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        let tx = await pool.addMargin({
            from: manager,
            value: ether("1")
        })

        await expectEvent(tx, 'AddMargin', {
            sender: manager,
            amount: ether('1')
        })

        assert.equal(await pool.state(), 0)

        tx = await pool.addMargin({
            from: manager,
            value: ether("4")
        })
        await expectEvent(tx, 'AddMargin', {
            sender: accounts[1],
            amount: ether('4')
        })
        await expectEvent(tx, 'ChangeState', {
            state: '1'
        })

        assert.equal(await pool.state(), 1)
    })

    it("change percent", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        let tx = await pool.submitPercentChange(80, {from: manager})

        await expectEvent(tx, 'SubmitPercentChange', {
            percent: '80'
        })

        tx = await pool.confirmPercentChange({from: manager})

        await expectEvent(tx, 'ConfirmPercentChange', {
            percent: '80'
        })

        assert.equal(await pool.percent(), 80)

        try {
            await pool.confirmPercentChange({from: manager})
        } catch (e) {
            assert(e, 'invalid confirm percent change')
            // assert(e.message.search('Invalid percent') >= 0, 'invalid confirm percent change')
        }
    })

    it("change percent", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))

        await expectRevert(pool.submitPercentChange(0, {from: accounts[0]}), 'Only manager allowed')

        await expectRevert(pool.submitPercentChange(3001, {from: manager}), 'Invalid percent')


        let tx = await pool.submitPercentChange(1, {from: manager});
        await expectEvent(tx, 'SubmitPercentChange', {percent: '1'})

        tx = await pool.confirmPercentChange({from: manager});
        await expectEvent(tx, 'ConfirmPercentChange', {percent: '1'})
    })


    it("deposit", async () => {
        let pool = await VotePool.at(await validators.votePools(accounts[0]))

        params = [
            [1, '100'],
            [2, '200'],
            [3, '0.00001']
        ]

        let tops = [await pool.validator()]
        for (let p of params) {
            let tx = await pool.deposit({from: accounts[p[0]], value: ether(p[1] )})

            await expectEvent(tx, "Deposit", {
                amount: ether(p[1])
            })
        }

        await validators.updateActiveValidatorSet(tops)
    })

    it("reward", async () => {
        await validators.distributeBlockReward({from: accounts[0], gas: 400000, value: ether("1")})
        assert.equal(ether("1").toString(), (await balance.current(validators.address)).toString())
        assert.equal(ether("1").toString(), (await validators.pendingReward(await validators.votePools(validator))).toString())
    })

    it('switch state', async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        assert.equal(await pool.state(), 1, 'in ready state')
        await pool.switchState(true)
        assert.equal(await pool.state(), 2, 'in pause state')
        await pool.switchState(false)
        assert.equal(await pool.state(), 0, 'in idle state')
    })

    it('punish', async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        let balanceBefore = await balance.current(pool.address);
        let marginBefore = await pool.margin();

        let punishAmount = await pool.PunishAmount()
        await pool.punish()

        assert.equal(balanceBefore - await balance.current(pool.address), punishAmount.toString(), 'contract balance check')
        assert.equal(marginBefore - await pool.margin(), punishAmount.toString(), 'contract margin check')
    })

    it("exit", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        try {
            await pool.exit({from: manager})
        } catch (e) {
            assert(e, 'Incorrect state')
            // assert(e.message.search('Incorrect state') >= 0, 'Incorrect state')
        }

        await pool.addMargin({
            from: manager,
            value: ether("5")
        })

        assert.equal(await pool.state(), 1, 'Ready state')
        await pool.exit({from: manager})
        assert.equal(await pool.state(), 0, 'Idle state')
    })

    it("withdraw margin", async () => {
        let pool = await VotePool.at(await validators.votePools(validator))
        let margin = await pool.margin()

        let balanceBefore = await balance.current(accounts[1])
        let tx = await pool.withdrawMargin({from: manager})

        let fee = web3.utils.toBN((await web3.eth.getTransaction(tx.tx)).gasPrice).mul(web3.utils.toBN(tx.receipt.gasUsed))

        assert.equal(web3.utils.toBN(await balance.current(accounts[1])).sub(web3.utils.toBN(balanceBefore)).add(web3.utils.toBN(fee)).toString(), margin.toString())
    })
})
