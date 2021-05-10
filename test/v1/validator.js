const Validator = artifacts.require('Validator');
const Candidate = artifacts.require('Candidate');

const {
    constants,
    expectRevert,
    expectEvent,
    time,
    ether,
    BN
} = require('@openzeppelin/test-helpers');
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

    it("test top candidates", async() => {
        
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


        // let balance1 = await web3.eth.getBalance(accounts[1])
        // let balance2 = await web3.eth.getBalance(accounts[2])

        // let candidate = await Candidate.at(await validator.candidates(accounts[0]))
        // await candidate.addVote({from: accounts[1]})
        // await candidate.addVote({from: accounts[2]})

        //TODO 精度问题
        // assert.equal(web3.utils.toWei(new BN(100), "ether").mul(new BN(8*2)).div(new BN(30)).add(new BN(balance2)).toString(), await web3.eth.getBalance(accounts[2]))
        // assert.equal(web3.utils.toWei(new BN(100), "ether").mul(new BN(8)).div(new BN(30)).add(new BN(balance1)).toString(), await web3.eth.getBalance(accounts[1]))
    })

});
