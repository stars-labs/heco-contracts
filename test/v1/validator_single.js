const Validator = artifacts.require('Validator');
const Candidate = artifacts.require('Candidate');

const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const BigNumber = require('bignumber.js')

const Pos = 0
const Poa = 1

contract("Single validator test", accounts => {
    let validator;

    before('deploy validator', async() => {
        validator = await Validator.new()
    } )

    before('add admin', async() => {
        await validator.initialize(accounts[0])
        assert.equal(await validator.admin(), accounts[0])
    })
    
    it("add candidate", async ()=>{
        await validator.addValidator(accounts[0], accounts[0], 20, Pos, {
            from: accounts[0],
            gas: 2000000
        })

        let candidate = await Candidate.at(await validator.candidates(accounts[0]))

        assert.equal(await candidate.state(), 0)

    })

    it("add margin", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        await candidate.addMargin({
            from: accounts[0],
            value: web3.utils.toWei("10", "ether")
        })

        assert.equal(await candidate.state(), 1)
    })

    it("add vote", async() => {
        let candidate = await Candidate.at(await validator.candidates(accounts[0]))

        params = [
            [1, 1000],
            [2, 2000],
            [3, 0.00001]
        ]

        for(let p of params) {
            let tx = await candidate.addVote({from: accounts[p[0]], value: web3.utils.toWei(p[1] + "", "ether")})
            assert.equal(tx.receipt.status, true)
        }

        let tops = await validator.getTopValidators()
        assert.equal(tops.length, 1)
        await validator.updateActiveValidatorSet(tops, 0)
    })

    it("reward with one candidate", async() => {
        await validator.distributeBlockReward({from: accounts[0], gas: 400000, value: web3.utils.toWei("1", "ether")})
        assert.equal(web3.utils.toWei("1", "ether"), await web3.eth.getBalance(validator.address))
        assert.equal(web3.utils.toWei("1", "ether"), await validator.pendingReward(await validator.candidates(accounts[0])))

        params = [
            [1, 1000],
            [2, 2000],
            [3, 0.00001]
        ]

        let total = 0
        params.forEach(p => {
           total += p[1] 
        });

        let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        for(let p of params) {
            let account = accounts[p[0]]
            let balance = await  web3.eth.getBalance(account)
            await candidate.addVote({from: account})
            
            assert.equal(
                new BN(await web3.eth.getBalance(account)).sub(new BN(balance)).div(new BN(10000)).mul(new BN(10000)).toString(),
                web3.utils.toWei(BigNumber(p[1]).times(100 - await candidate.percent()).div(100).div(BigNumber(total)).toFixed(14, BigNumber.BigNumber.ROUND_DOWN), 'ether'), 
                `account:${p[0]}, address:${account}`
            )
        }
    })
});
