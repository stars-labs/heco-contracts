const {ether, expectEvent, expectRevert, BN} = require("@openzeppelin/test-helpers");

const AddressList = artifacts.require("AddressList");

describe("AddressList contract", function () {
    let accounts;
    let admin;
    let aList;
    let erc20transRule = {
        sig: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        idx: new BN(1),
        ct: '1'
    };
    // {0x06b541ddaa720db2b10a4d0cdac39b8d360425fc073085fac19bc82614677987,2,1}
    let erc777SentRule = {
        sig: "0x06b541ddaa720db2b10a4d0cdac39b8d360425fc073085fac19bc82614677987",
        idx: new BN(2),
        ct: '1'
    };
    // [{0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62,2,1},{0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb,2,1}]
    let erc1155transSingleRule = {
        sig: "0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62",
        idx: new BN(2),
        ct: '1'
    };
    let erc1155transBatchRule = {
        sig: "0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb",
        idx: new BN(2),
        ct: '1'
    };

    before(async function () {
        accounts = await web3.eth.getAccounts();
        admin = accounts[0];

        aList = await AddressList.new();
        await aList.initialize(admin);
    });

    it('should only init once', async function () {
        await expectRevert(aList.initialize(accounts[1]), "Already initialized");
    });

    describe("manage rules", async function () {

        it('should only initialize rules before any use',async function () {
            let receipt = await aList.initializeV2();
            assert.equal(receipt.receipt.status, true);

            await expectRevert( aList.initializeV2(),"Only initialize before any use");

            //remove all rules for later test
            await aList.removeRule(erc1155transBatchRule.sig, erc1155transBatchRule.idx, {from: admin});
            await aList.removeRule(erc1155transSingleRule.sig, erc1155transSingleRule.idx, {from: admin});
            await aList.removeRule(erc777SentRule.sig, erc777SentRule.idx, {from: admin});
            await aList.removeRule(erc20transRule.sig, erc20transRule.idx, {from: admin});

            let len = await aList.rulesLen();
            assert.equal(0, len);
        });

        it('should only the admin can manage the rules', async function () {
            await expectRevert(aList.addOrUpdateRule(erc20transRule.sig, erc20transRule.idx, 2, {from: accounts[1]}), "Admin only");
            let receipt = await aList.addOrUpdateRule(erc20transRule.sig, erc20transRule.idx, 2, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc20transRule.sig,
                checkIdx: erc20transRule.idx,
                t: '2'
            });
            await expectRevert(aList.removeRule(erc20transRule.sig, erc20transRule.idx, {from: accounts[1]}), "Admin only");
            receipt = await aList.removeRule(erc20transRule.sig, erc20transRule.idx, {from: admin});
            expectEvent(receipt, "RuleRemoved", {
                eventSig: erc20transRule.sig,
                checkIdx: erc20transRule.idx,
                t: '2'
            });
        });

        it('should add rules correctly', async function () {

            await expectRevert(aList.addOrUpdateRule("0x0000000000000000000000000000000000000000000000000000000000000000", 0, 1), "eventSignature must not empty");
            await expectRevert(aList.addOrUpdateRule(erc20transRule.sig, 0, 1), "check index must greater than 0");
            await expectRevert(aList.addOrUpdateRule(erc20transRule.sig, 1, 0), "invalid check type");


            let receipt = await aList.addOrUpdateRule(erc20transRule.sig, erc20transRule.idx, 2, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc20transRule.sig,
                checkIdx: erc20transRule.idx,
                t: '2'
            });
            let lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.addOrUpdateRule(erc20transRule.sig, erc20transRule.idx, erc20transRule.ct, {from: admin});
            expectEvent(receipt, "RuleUpdated", {
                eventSig: erc20transRule.sig,
                checkIdx: erc20transRule.idx,
                t: erc20transRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.addOrUpdateRule(erc777SentRule.sig, erc777SentRule.idx, erc777SentRule.ct, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc777SentRule.sig,
                checkIdx: erc777SentRule.idx,
                t: erc777SentRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.addOrUpdateRule(erc1155transSingleRule.sig, erc1155transSingleRule.idx, erc1155transSingleRule.ct, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc1155transSingleRule.sig,
                checkIdx: erc1155transSingleRule.idx,
                t: erc1155transSingleRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.addOrUpdateRule(erc1155transBatchRule.sig, erc1155transBatchRule.idx, erc1155transBatchRule.ct, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc1155transBatchRule.sig,
                checkIdx: erc1155transBatchRule.idx,
                t: erc1155transBatchRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            let len = await aList.rulesLen();
            assert.equal(4, len);

        });

        it('should remove rules correctly', async function () {
            let receipt = await aList.removeRule(erc777SentRule.sig, erc777SentRule.idx, {from: admin});
            expectEvent(receipt, "RuleRemoved", {
                eventSig: erc777SentRule.sig,
                checkIdx: erc777SentRule.idx,
                t: erc777SentRule.ct
            });
            let lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.addOrUpdateRule(erc777SentRule.sig, erc777SentRule.idx, erc777SentRule.ct, {from: admin});
            expectEvent(receipt, "RuleAdded", {
                eventSig: erc777SentRule.sig,
                checkIdx: erc777SentRule.idx,
                t: erc777SentRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            receipt = await aList.removeRule(erc777SentRule.sig, erc777SentRule.idx, {from: admin});
            expectEvent(receipt, "RuleRemoved", {
                eventSig: erc777SentRule.sig,
                checkIdx: erc777SentRule.idx,
                t: erc777SentRule.ct
            });
            lastUpdated = await aList.rulesLastUpdatedNumber();
            assert.equal(lastUpdated, receipt.receipt.blockNumber);

            let len = await aList.rulesLen();
            assert.equal(3, len);

        });

        it('should be queryable', async function () {
            let len = await aList.rulesLen();
            for (let i = 0; i < len; i++) {
                let rule = await aList.getRuleByIndex(i);
                console.log(rule);
            }

            let rule = await aList.getRuleByKey(erc20transRule.sig, erc20transRule.idx);
            assert.equal(rule[0], erc20transRule.sig);
            assert.equal(rule[1].eq(erc20transRule.idx), true);
            assert.equal(rule[2], erc20transRule.ct);
        });
    })

});