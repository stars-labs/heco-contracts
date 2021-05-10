const Validator = artifacts.require('Validator');
const Candidate = artifacts.require('Candidate');

const { web3 } = require('@openzeppelin/test-helpers/src/setup');
const BigNumber = require('bignumber.js')

const Pos = 0
const Poa = 1

contract("Multi validators test", accounts => {
    let validator;

    before('deploy validator', async() => {
        validator = await Validator.new()
    } )

    before('add admin', async() => {
        await validator.initialize(accounts[0])
        assert.equal(await validator.admin(), accounts[0])
    })
    
    it("add candidates", async ()=>{
        let max = parseInt(await validator.count(Pos))
        for(let i =0; i < accounts.length; i++) {
            max--
            if(max < 0) {
                break
            }

            await validator.addValidator(accounts[i], accounts[i], 20, 0, {
                from: accounts[0],
                gas: 2000000
            })
            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            assert.equal(await candidate.state(), 0)
        }
    })

    it("add margin", async() => {
        let max = parseInt(await validator.count(Pos))
        for(let i = 0; i < accounts.length; i++) {
            max--
            if(max < 0) {
                break
            }

            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            await candidate.addMargin({
                from: accounts[i],
                value: web3.utils.toWei("10", "ether")
            })

            assert.equal(await candidate.state(), 1)
        }        
   })

    it("add vote", async() => {
        let max = parseInt(await validator.count(Pos))
        for(let i =0; i < accounts.length; i++) {
            max--
            if(max < 0) {
                break
            }

            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            let tx = await candidate.addVote({from: accounts[i], value: web3.utils.toWei(`${1+ 1 * i}`, "ether")})
            console.log(`tx gas used:${tx.receipt.gasUsed}`)
            assert.isOk(tx.receipt.status, "add vote failed")
        }


    })

    it("top candidates", async() => {
        
        let tops = await validator.getTopValidators()
        assert.equal(await validator.count(Pos), tops.length)

        for(let i =0; i < tops.length; i++) {
            assert.equal(tops[i], accounts[tops.length - i - 1], `index ${i} not equal`)
        }

        await validator.updateActiveValidatorSet(tops, 0)
    })

    it("reward with multi candidates", async() => {
        await validator.distributeBlockReward({from: accounts[0], gas: 400000, value: web3.utils.toWei("100", "ether")})
        assert.equal(web3.utils.toWei("100", "ether"), await web3.eth.getBalance(validator.address))

        let max = parseInt(await validator.count(Pos))
        let total = (1 + max) * max / 2;

        for(let i =0; i < accounts.length; i++) {
            max--
            if(max < 0) {
                break
            }

            assert.equal(web3.utils.toWei(`${new BigNumber(i+1).times(100).div(total).toFixed(18, BigNumber.BigNumber.ROUND_DOWN)}`, "ether"), 
            (await validator.pendingReward(await validator.candidates(accounts[i]))).toString(),
            `address:${accounts[i]}`)
        }

        max = parseInt(await validator.count(Pos))
        for(let i =0; i < accounts.length; i++) {
            max--
            if(max < 0) {
                break
            }

            // let topCandidates =  await validator.topCandidates(Pos)
            // console.log(`head:${await (await Candidate.at(topCandidates.head)).candidate()}, tail:${await (await Candidate.at(topCandidates.tail)).candidate()}`)
            // console.log(await validator.getTopValidators())
            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            let tx = await candidate.removeVote({from: accounts[i]})
            console.log(`tx gas used:${tx.receipt.gasUsed}`)
            assert.isOk(tx.receipt.status, "remove vote failed")
        }
    })

    it("vote to change ranking", async () => {

        //accounts vote for self
        let i = await validator.count(Pos) - 1
        while(i >=0 ) {
            let account = accounts[i]

            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            let tx = await candidate.addVote({from: accounts[i], value: web3.utils.toWei(`${accounts.length - i}`, "ether")})
            console.log(`tx gas used:${tx.receipt.gasUsed}`)
            assert.isOk(tx.receipt.status, "add vote failed")

            // let topCandidates =  await validator.topCandidates(Pos)
            // console.log(`head:${await (await Candidate.at(topCandidates.head)).candidate()}, tail:${await (await Candidate.at(topCandidates.tail)).candidate()}`)
            // console.log(await validator.getTopValidators())

            let tops = await validator.getTopValidators()
            assert.equal(tops[0], account, `account:${account}`)

            i --
        }

        //remove from top0
        i = 0
        while(i <= await validator.count(Pos) - 1) {
            let account = accounts[i]

            let candidate = await Candidate.at(await validator.candidates(accounts[i]))
            let tx = await candidate.removeVote({from: accounts[i]})
            console.log(`tx gas used:${tx.receipt.gasUsed}`)
            assert.isOk(tx.receipt.status, "remove vote failed")

            let tops = await validator.getTopValidators()
            if(i < await validator.count(Pos) - 1) {
                assert.equal(tops[0], accounts[i+1], `index:${i} account:${account}`)
            }else {
                assert.equal(tops[0], account, `index:${i} account:${account}`)
            }

            i ++
        }


    })


});
