const Validator = artifacts.require('MockValidator');
const Punish = artifacts.require('MockPunish');
const Candidate = artifacts.require('CandidatePool');

const { web3, BN } = require('@openzeppelin/test-helpers/src/setup');
const truffleAssert = require('truffle-assertions')

const Pos = 0
const Poa = 1

contract("Candidate test", accounts => {
    let validator;
    let punish;

    before('deploy validator', async() => {
        validator = await Validator.new()
        punish = await Punish.new()
    } )

    it("add candidate", async ()=>{
        let tx = await validator.addCandidate(accounts[0], accounts[0], 20, Pos, {
            from: accounts[0],
            gas: 2000000
        })
        assert(tx.receipt.status)

        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        await candidate.setAddress(validator.address, punish.address)

        assert.equal(await candidate.state(), 0)
    })

    // it('only candidate', async() => {
    //     let inputs = [
    //         ['changeManager', [accounts[0]]],
    //     ]

    //     let candidate = await Candidate.at(await validator.candidates(accounts[0]))

    //     for(let input of inputs) {
    //         try {
    //             await candidate[input[0]](...input[1], {from: accounts[1]})
    //         }catch (e) {
    //             console.log(e)
    //             assert(e.message.search('Only candidate') >= 0, input[0])
    //         }
    //     }
    // })


    it("change manager", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))

        let tx = await candidate.changeManager(accounts[1], {from: accounts[0]})
        truffleAssert.eventEmitted(tx, "ChangeManager", {manager: accounts[1]})
    })

    it("add margin", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        let tx = await candidate.addMargin({
            from: accounts[1],
            value: web3.utils.toWei("1", "ether")
        })

        truffleAssert.eventEmitted(tx, 'AddMargin',  ev => ev.sender === accounts[1]
            && ev.amount == web3.utils.toWei("1", "ether").toString())

        assert.equal(await candidate.state(), 0)

        tx = await candidate.addMargin({
            from: accounts[1],
            value: web3.utils.toWei("4", "ether")
        })
        truffleAssert.eventEmitted(tx, 'AddMargin',  ev => ev.sender === accounts[1]
            && ev.amount == web3.utils.toWei("4", "ether").toString())

        truffleAssert.eventEmitted(tx, 'ChangeState',  ev => ev.state == 1)

        assert.equal(await candidate.state(), 1)
    })

    it("change percent", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        let tx = await candidate.updatePercent(80, {from: accounts[1]})
        truffleAssert.eventEmitted(tx, 'UpdatingPercent', ev => ev.percent.toString() == 80)

        tx = await candidate.confirmPercentChange({from: accounts[1]})
        truffleAssert.eventEmitted(tx, 'ConfirmPercentChange', ev => ev.percent.toString() == 80)
        assert.equal(await candidate.percent(), 80)

        try {
           await candidate.confirmPercentChange({from: accounts[1]})
        }catch(e) {
            assert(e.message.search('Invalid percent') >= 0, 'invalid confirm percent change')
        }


    })

    it("change percent", async () => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        try {
            await  candidate.updatePercent(0, {from: accounts[0]});
        }catch(e) {
            assert(e.message, 'from invalid account')
            // assert(e.message.search('Only manager allowed') >= 0, 'from invalid account')
        }

        try {
            await candidate.updatePercent(0, {from: accounts[1]});
        }catch(e) {
            assert(e.message, 'change percent to 0')
            // assert(e.message.search('Invalid percent') >= 0, 'change percent to 0')
        }

        try {
            await candidate.updatePercent(1001, {from: accounts[1]});
        }catch(e) {
            assert(e.message, 'change percent to 1001')
            // assert(e.message.search('Invalid percent') >= 0, 'change percent to 1001')
        }

        let tx = await candidate.updatePercent(1, {from: accounts[1]});
        assert.equal(tx.receipt.status, true, 'change percent to 1')

        await candidate.confirmPercentChange({from: accounts[1]});
        assert.equal(await candidate.percent(), 1, "change percent success")
    })


    it("deposit", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))

        params = [
            [1, 100],
            [2, 200],
            [3, 0.00001]
        ]

        let tops = [await candidate.candidate()]
        for(let p of params) {
            let tx = await candidate.deposit({from: accounts[p[0]], value: web3.utils.toWei(p[1] + "", "ether")})
            assert.equal(tx.receipt.status, true)
            truffleAssert.eventEmitted(tx, "Deposit", ev => ev.amount == web3.utils.toWei(p[1] + "", "ether").toString())
        }

        await validator.updateActiveValidatorSet(tops)
    })

    it("reward", async() => {
        await validator.distributeBlockReward({from: accounts[0], gas: 400000, value: web3.utils.toWei("1", "ether")})
        assert.equal(web3.utils.toWei("1", "ether"), await web3.eth.getBalance(validator.address))
        assert.equal(web3.utils.toWei("1", "ether"), await validator.pendingReward(await validator.candidates(accounts[0])))


    })

    it('switch state', async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        assert.equal(await candidate.state() , 1, 'in ready state')
        await candidate.switchState(true)
        assert.equal(await candidate.state() , 2, 'in pause state')
        await candidate.switchState(false)
        assert.equal(await candidate.state() , 0, 'in idle state')
    })

    it('punish', async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        let balanceBefore = await web3.eth.getBalance(candidate.address);
        let marginBefore = await candidate.margin();

        let punishAmount = await candidate.PunishAmount()
        await candidate.punish()

        assert.equal(balanceBefore - await web3.eth.getBalance(candidate.address), punishAmount.toString(), 'contract balance check')
        assert.equal(marginBefore - await candidate.margin(), punishAmount.toString(), 'contract margin check')
    })

    it("exit", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        try {
            await candidate.exit({from: accounts[1]})
        }catch(e) {
            assert(e, 'Incorrect state')
            // assert(e.message.search('Incorrect state') >= 0, 'Incorrect state')
        }

        await candidate.addMargin({
            from: accounts[1],
            value: web3.utils.toWei("5", "ether")})

        assert.equal(await candidate.state(), 1, 'Ready state')
        await candidate.exit({from: accounts[1]})
        assert.equal(await candidate.state(), 0, 'Idle state')
    })

    it("withdraw margin", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        let margin = await candidate.margin()

        let balanceBefore = await web3.eth.getBalance(accounts[1])
        let tx = await candidate.withdrawMargin({from: accounts[1]})
        let fee = web3.utils.toBN((await web3.eth.getTransaction(tx.tx)).gasPrice).mul(web3.utils.toBN(tx.receipt.gasUsed))

        assert.equal(web3.utils.toBN(await web3.eth.getBalance(accounts[1])).sub(web3.utils.toBN(balanceBefore)).add(web3.utils.toBN(fee)).toString(), margin.toString())
    })
})
