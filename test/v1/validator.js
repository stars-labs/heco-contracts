const Validator = artifacts.require('Validator');
const Candidate = artifacts.require('MockCandidate');

const { assert } = require('hardhat');
const truffleAssert = require('truffle-assertions')

const Pos = 0
const Poa = 1

contract("Validator test", accounts => {
    let validator;

    before('deploy validator', async() => {
        validator = await Validator.new()
    } )

    before('init validator', async() => {
        await validator.initialize(accounts.slice(10, 15), accounts[1], {gas: 12450000})
        assert.equal(await validator.admin(), accounts[1])

        let vals = await validator.getTopValidators()
        assert.equal(vals.length, 5, 'validator length')
    })

    it('only admin', async() => {
        let inputs = [
            ['changeAdmin', [accounts[0]]],
            ['updateParams', [11,10,10,11]],
            ['addCandidate', [accounts[0], accounts[0], 20, Pos]],
            ['updateCandidateState', [accounts[0], true]]
        ]

        for(let input of inputs) {
            try {
                await validator[input[0]](...input[1], {from: accounts[0]})
            }catch (e) {
                assert(e.message.search('Only admin') >= 0, input[0])
            }
        }
    })

    it('change admin', async() => {
        let tx = await validator.changeAdmin(accounts[0], {from: accounts[1]})
        truffleAssert.eventEmitted(tx, 'ChangeAdmin', {admin: accounts[0]})
        assert.equal(await validator.admin(), accounts[0])
    })

    it('change params', async() => {
        //params incorrect
        try {
            await validator.updateParams(1, 1, 1, 1, {from: accounts[0]})
        }catch (e) {
            assert(e.message.search('Invalid params') >= 0, 'invalid params')
        }

        let tx = await validator.updateParams(20,10, 1, 11, {from: accounts[0]})
      
        truffleAssert.eventEmitted(tx, 'UpdateParams', ev => ev.posCount.toNumber() === 20 
        && ev.posBackup.toNumber() === 10
        && ev.poaCount.toNumber() === 1
        && ev.poaBackup.toNumber() === 11)

        assert.equal((await validator.count(Pos)).toNumber(), 20, 'pos count')
        assert.equal((await validator.count(Poa)).toNumber(), 1, 'poa count')
        assert.equal((await validator.backupCount(Pos)).toNumber(), 10, 'pos backup count')
        assert.equal((await validator.backupCount(Poa)).toNumber(), 11, 'poa backup count')
    })

    it("get top validators" , async () => {
        let vals = await validator.getTopValidators()
        assert.equal(vals.length, 1, 'validator length')
    })

    it("add candidate", async ()=>{
        let tx = await validator.addCandidate(accounts[0], accounts[0], 10, Pos, {
            from: accounts[0],
            yy: 2000000
        })

        truffleAssert.eventEmitted(tx, 'AddCandidate', {candidate: accounts[0], contractAddress: await validator.candidates(accounts[0])})

        assert(tx.receipt.status)
    })

    it('only registered', async () => {
        let c = await Candidate.new(accounts[0], accounts[0], 0, 1)        
        await c.changeVote(50)
        try {
            await c.changeVoteAndRanking(await validator.address, 100)
        }catch(e) {
            assert(e.message.search('Candidate not registered') >= 0)
        }

        try {
            await c.changeVoteAndRanking(await validator.address, 0)
        }catch(e) {
            assert(e.message.search('Candidate not registered') >= 0)
        }
    })
});
