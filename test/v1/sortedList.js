const SortedList = artifacts.require('MockList');
const VotePool = artifacts.require('cache/solpp-generated-contracts/v1/mock/MockVotePool.sol:VotePool');

const {assert} = require('hardhat');

contract("SortedList test", accounts => {
    let mock;

    before('deploy list', async () => {
        mock = await SortedList.new()
    })

    it('check init state', async () => {
        await assertEmpty()
    })

    async function assertEmpty() {
        let list = await mock.list()
        assert.equal(await list.head, '0x0000000000000000000000000000000000000000', "check init head")
        assert.equal(await list.tail, '0x0000000000000000000000000000000000000000', "check init head")
        assert.equal(await list.length.toNumber(), 0, "check init length")
    }

    it('add new value', async () => {
        let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
        await mock.improveRanking(await c.address, {from: accounts[0]})

        let list = await mock.list()
        assert.equal(await list.length.toNumber(), 1, "check length")
        assert.equal(await list.head, c.address, "check head")
        assert.equal(await list.tail, c.address, "check head")
    })

    it('improve ranking', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 30; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        let list = await mock.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        let v = 1
        for (let addr of values) {
            await (await VotePool.at(addr)).changeVote(v++)
            await mock.improveRanking(addr, {from: accounts[0]})
        }

        list = await mock.list()
        assert.equal(list.head, values[list.length - 1], 'check head')
        assert.equal(list.tail, values[0], 'check tail')

        for (let i = 0; i < 30; i++) {
            if (i < 29) {
                assert.equal(await mock.prev(values[i]), values[i + 1], 'check prev')
            }

            if (i > 0) {
                assert.equal(await mock.next(values[i]), values[i - 1], 'check next')
            }
        }
    })

    it('improve ranking from middle', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 10; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await VotePool.at(values[5])).changeVote(1)
        await mock.improveRanking(values[5], {from: accounts[0]})

        list = await mock.list()
        assert.equal(list.head, values[5], 'check head')
    })

    it('improve ranking from tail', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 10; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await VotePool.at(values[values.length - 1])).changeVote(1)
        await mock.improveRanking(values[values.length - 1], {from: accounts[0]})

        list = await mock.list()
        assert.equal(list.head, values[values.length - 1], 'check head')
        assert.equal(list.tail, values[values.length - 2], 'check tail')
    })

    it('lower ranking from head', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 10; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            await c.changeVote(100)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await VotePool.at(values[0])).changeVote(1)
        await mock.lowerRanking(values[0], {from: accounts[0]})

        list = await mock.list()
        assert.equal(list.head, values[1], 'check head')
        assert.equal(list.tail, values[0], 'check tail')
    })

    it('lower ranking from middle', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 10; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            await c.changeVote(100)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await VotePool.at(values[values.length / 2])).changeVote(1)
        await mock.lowerRanking(values[values.length / 2], {from: accounts[0]})

        list = await mock.list()
        assert.equal(list.tail, values[values.length / 2], 'check tail')
    })


    it('lower ranking', async () => {
        await mock.clear()
        await assertEmpty()

        let values = []
        for (let i = 0; i < 30; i++) {
            let c = await VotePool.new(accounts[0], accounts[0], 0, 1, 1)
            await c.changeVote(1000)
            values.push(await c.address)
            await mock.improveRanking(await c.address, {from: accounts[0]})
        }

        let list = await mock.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        let v = 900
        for (let addr of values) {
            await (await VotePool.at(addr)).changeVote(v--)
            await mock.lowerRanking(addr, {from: accounts[0]})
        }

        list = await mock.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        for (let i = 0; i < 30; i++) {
            if (i < 29) {
                assert.equal(await mock.next(values[i]), values[i + 1], 'check next')
            }

            if (i > 0) {
                assert.equal(await mock.prev(values[i]), values[i - 1], 'check next')
            }
        }
    })

});
