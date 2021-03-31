require('chai').use(require('chai-as-promised')).should();

const { EVM_REVERT, ETHER_ADDRESS } = require('./helpers.js');

const ZunamiStablecoin = artifacts.require('./ZunamiStablecoin');

contract('ZunamiStablecoin', (accounts) => {
    let zunami;
    beforeEach(async () => {
        zunami = await ZunamiStablecoin.new(accounts[0]);
    })

    describe('description', () => {
        it('name', async () => {
            const name = await zunami.name();
            assert(name === 'Zunami Stablecoin');
        })

        it('symbol',async () => {
            const symbol = await zunami.symbol();
            assert(symbol === 'ZUSD');
        })
    })


    describe('totalSupply', () => {

        describe('mint and burn', () => {
            it('mint and burn',async () => {
                const amountTokenAfterMint = await zunami.totalSupply();
                assert(amountTokenAfterMint.toString() === '0');

                await zunami.mint(accounts[0], 2, {from: accounts[0]});
                const accOneBalance = await zunami.balanceOf(accounts[0]);
                assert(accOneBalance.toString() === '2');

                const amountTokenBeforeMint = await zunami.totalSupply();
                assert(amountTokenBeforeMint.toString() === '2');

                await zunami.burn(accounts[0], 1, {from: accounts[0]});
                const amountTokenBeforeBurn = await zunami.totalSupply();
                assert(amountTokenBeforeBurn.toString() === '1');
            })

            it('minus burn totalSupply',async () => {
                await zunami.mint(accounts[0], 5, {from: accounts[0]});
                await zunami.burn(accounts[0], 6, {from: accounts[0]}).should.be.rejectedWith(EVM_REVERT);
            })
        })

        it('failde number argument mint 1',async () => {
            await zunami.mint(accounts[0], -2, {from: accounts[0]}).should.be.rejectedWith();
        })

        it('failde number argument mint 2',async () => {
            await zunami.mint(accounts[0], 'fdsafa', {from: accounts[0]}).should.be.rejectedWith();
        })

        it('failde address from',async () => {
            await zunami.mint(accounts[0], 2, {from: accounts[2]}).should.be.rejectedWith(EVM_REVERT);
        })

        it('failde address',async () => {
            await zunami.mint('dsaDASDA', 2, {from: accounts[0]}).should.be.rejectedWith();
        })

    })

    describe('events Mint and Burn', () => {

        const amountMint = 2;
        const amountBurn = 2;

        it('event mint',async () => {
            const mint = await zunami.mint(accounts[0], amountMint, {from: accounts[0]});
            const log = mint.logs[0]
            log.event.should.eq('Transfer');
            log.id.should.a('string');

            const event = log.args;
            event.from.should.eq(ETHER_ADDRESS, 'ether address');
            event.to.should.eq(accounts[0], 'teacher\'s address');
            event.value.toString().should.eq(amountMint.toString(), 'amount tokens')
        })

        it('event burn',async () => {
            await zunami.mint(accounts[0], amountMint, {from: accounts[0]});

            const burn = await zunami.burn(accounts[0], amountBurn, {from: accounts[0]});

            const log = burn.logs[0]
            log.event.should.eq('Transfer');
            log.id.should.a('string');

            const event = log.args;
            event.from.should.eq(accounts[0], 'teacher\'s address');
            event.to.should.eq(ETHER_ADDRESS, 'ether address');
            event.value.toString().should.eq(amountBurn.toString(), 'amount tokens')
        })
    })


    describe('sending tokens', () => {
        let result
        let amount
    
        describe('success', () => {
          beforeEach(async () => {
            amount = 100
            await zunami.mint(accounts[0], amount, {from: accounts[0]});
            result = await zunami.transfer(accounts[1], amount, { from: accounts[0] })
          })
    
          it('transfers token balances', async () => {
            let balanceOf
            balanceOf = await zunami.balanceOf(accounts[0]);
            balanceOf.toString().should.equal('0');
            
            balanceOf = await zunami.balanceOf(accounts[1]);
            balanceOf.toString().should.equal('100');
          })
    
          it('emits a Transfer event', () => {
            const log = result.logs[0];
            log.event.should.eq('Transfer');
            const event = log.args;
            event.from.toString().should.equal(accounts[0], 'from is correct');
            event.to.toString().should.equal(accounts[1], 'to is correct');
            event.value.toString().should.equal(amount.toString(), 'value is correct');
          })
        
    
        describe('failure', () => {
          it('rejects insufficient balances', async () => {
            let invalidAmount = 10;
            await zunami.transfer(accounts[1], invalidAmount, { from: accounts[0] }).should.be.rejectedWith(EVM_REVERT);
          })
    
          it('rejects invalid recipients', () => {
            zunami.transfer(0x0, amount, { from: accounts[0] }).should.be.rejected;
          })
        })
    })
  })



})
