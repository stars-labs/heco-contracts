const Validators = artifacts.require('Validators');
const HSCTToken = artifacts.require("HSCTToken");

const { ether, constants, BN } = require('@openzeppelin/test-helpers');
const expectRevert = require('@openzeppelin/test-helpers/src/expectRevert');

let premintAmount = ether("25000000");
let limit = ether("100000000");

contract("hsct token", function (accounts) {
    let valIns;
    let hsctIns;
    let premint = accounts[1];
    let admin = accounts[0];
    let miner = accounts[0];

    before(async function () {
        hsctIns = await HSCTToken.new();
        valIns = await Validators.new();

        await hsctIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, hsctIns.address);
        await valIns.setContracts(valIns.address, constants.ZERO_ADDRESS, constants.ZERO_ADDRESS, hsctIns.address);

        await hsctIns.initialize(premint);
        await valIns.initialize([miner], admin);
        await valIns.setMiner(miner);
    })

    it("premint address will get 25000000 hsct token when init", async function () {
        let actual = await hsctIns.balanceOf(premint);

        assert.equal(actual.eq(premintAmount), true);
    })

    it("the limit is 100000000", async function () {
        let limit_ = await hsctIns.limit();

        assert.equal(limit.eq(limit_), true);
    })

    it("normal when reach limit", async function () {
        let amount = ether('75000000');

        await valIns.depositBlockReward({ from: miner, value: amount });

        // check balance
        let supply = await hsctIns.totalSupply();
        assert.equal(supply.eq(limit), true);
        let actual = await hsctIns.balanceOf(valIns.address);
        assert.equal(amount.eq(actual), true);
    })

    it("won't mint if over limit", async function () {
        let amount = new BN("1");

        let before = await hsctIns.balanceOf(valIns.address);
        await valIns.depositBlockReward({ from: miner, value: amount });
        let after = await hsctIns.balanceOf(valIns.address);
        assert.equal(before.eq(after), true);
    })

    it("can't send hb to hsct token", async function () {
        await expectRevert.unspecified(web3.eth.sendTransaction({ from: accounts[0], to: hsctIns.address, value: ether('1') }));
    })
})