const Validator = artifacts.require('MockValidator');
const Candidate = artifacts.require('Candidate');

const { web3, BN } = require('@openzeppelin/test-helpers/src/setup');
const truffleAssert = require('truffle-assertions')

const Pos = 0
const Poa = 1

contract("Candidate test", accounts => {
    let validator;

    before('deploy validator', async() => {
        validator = await Validator.new()
    } )

    it("add candidate", async ()=>{
        let tx = await validator.addCandidate(accounts[0], accounts[0], 20, Pos, {
            from: accounts[0],
            gas: 2000000
        })
        assert(tx.receipt.status)

        let candidate = await Candidate.at(await validator.candidates(accounts[0]))

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
            assert(e.message.search('Only manager allowed') >= 0, 'from invalid account')
        }

        try {
            await candidate.updatePercent(0, {from: accounts[1]});
        }catch(e) {
            assert(e.message.search('Invalid percent') >= 0, 'change percent to 0')
        }

        try {
            await candidate.updatePercent(1001, {from: accounts[1]});
        }catch(e) {
            assert(e.message.search('Invalid percent') >= 0, 'change percent to 1001')
        }

        let tx = await candidate.updatePercent(1, {from: accounts[1]});
        assert.equal(tx.receipt.status, true, 'change percent to 1')

        await candidate.confirmPercentChange({from: accounts[1]});
        assert.equal(await candidate.percent(), 1, "change percent success")
    }) 


    it("exit", async() => {

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

//     it("reward with one candidate", async() => {
//         params = [
//             [1, 1000],
//             [2, 2000],
//             [3, 0.00001]
//         ]

//         let total = 0
//         params.forEach(p => {
//            total += p[1] 
//         });

//         let candidate = await Candidate.at(await validator.candidates(accounts[0]))
//         for(let p of params) {
//             let account = accounts[p[0]]
//             let balance = await  web3.eth.getBalance(account)
//             await candidate.addVote({from: account})
            
//             assert.equal(
//                 new BN(await web3.eth.getBalance(account)).sub(new BN(balance)).div(new BN(10000)).mul(new BN(10000)).toString(),
//                 web3.utils.toWei(BigNumber(p[1]).times(100 - await candidate.percent()).div(100).div(BigNumber(total)).toFixed(14, BigNumber.BigNumber.ROUND_DOWN), 'ether'), 
//                 `account:${p[0]}, address:${account}`
//             )
//         }
//     })

});
