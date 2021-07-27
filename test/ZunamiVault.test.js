/* eslint-disable max-len */
const {expect} = require('chai');
const {waffle} = require('hardhat');
const provider = waffle.provider;
const abi = require('human-standard-token-abi');

// get the signers
let owner; let addr1; let zunamiVaultContract; let testUSDTContract;

const setup = async () => {
    // deploy the test USDT first
    const TestUSDT = await ethers.getContractFactory('TestUSDT');
    testUSDTContract = await (await TestUSDT.deploy()).deployed();


    // then deploy the vault
    const ZunamiVault = await ethers.getContractFactory('ZunamiVault');
    const zunamiVault = await ZunamiVault.deploy(testUSDTContract.address);
    await zunamiVault.deployed();
    [owner, addr1, ...addrs] = await ethers.getSigners();
    return zunamiVault;
};


describe('Deploying the vault + USDT contracts', () => {
    before(async () => {
        zunamiVaultContract = await setup();
    });

    describe('Test vault contract deployment', () => {
        it('Should set the deployed vault to the correct owner', async () => {
            expect(await zunamiVaultContract.owner()).to.equal(owner.address);
            expect(await testUSDTContract.owner()).to.equal(owner.address);
        });
    });

    describe('Test vault deposit and withdrawal', () => {
        it('User should be able to deposit to the vault and get LP Tokens', async () => {
            const usdtDepositAmount = 10000;
            console.log('Initial Deposit Amount ', usdtDepositAmount);
            const usdtDepositAmountInWei = ethers.utils.parseEther(usdtDepositAmount.toString());
            const res = await(await zunamiVaultContract.deposit(usdtDepositAmountInWei)).wait();

            expect(res.status).to.be.equal(1);

            if (res.status === 1) {
                const lpTokensContract = new ethers.Contract(zunamiVaultContract.address, abi, provider);
                const lpTokensBal = Number(ethers.utils.formatUnits(await lpTokensContract.balanceOf(owner.address), `ether`));
                console.log('LP Tokens Balance ', lpTokensBal);
                expect(lpTokensBal).to.be.gte(usdtDepositAmount);
            }
        });

        // eslint-disable-next-line max-len
        it('User should be able to withdraw from the vault, burn the LP Tokens & get their initial deposit back', async () => {
            const initialLPTokens = 10000;
            const initialUSDTBal = Number(ethers.utils.formatUnits(await testUSDTContract.balanceOf(owner.address), `ether`));
            console.log('Initial LP Token Amount ', initialLPTokens);
            const initialLPTokensInWei = ethers.utils.parseEther(initialLPTokens.toString());
            const res = await(await zunamiVaultContract.withdraw(initialLPTokensInWei)).wait();

            expect(res.status).to.be.equal(1);

            if (res.status === 1) {
                const currentUSDTBal = Number(ethers.utils.formatUnits(await testUSDTContract.balanceOf(owner.address), `ether`));
                expect(currentUSDTBal).to.be.gte(initialUSDTBal);
            }
        });
    });
});