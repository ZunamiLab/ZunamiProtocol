//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20 as OzIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20 as OzSafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import '../interfaces/IStrategy.sol';
import '../interfaces/ICurveAavePool.sol';
import '../interfaces/IYearnAlusd.sol';

import "hardhat/console.sol";


contract StrategyYearnAlusd is IStrategy {
    address constant internal usdcAddr = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    bytes32 constant internal usdcTicker = 'usdc';
    address constant internal curveTokenAddr = 0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900;
    bytes32 constant internal curveTicker = 'a3CRV';
    address constant internal yearnTokenAddr = 0x02d341CcB60fAaf662bC0554d13778015d1b285C;
    bytes32 constant internal yearnTicker = 'saCRV';

    address constant internal aavePoolAddr = 0xDeBF20617708857ebe4F679508E7b7863a8A8EeE;
    address constant internal yearnVaultAddr = 0x03403154afc09Ce8e44C3B185C82C6aD5f86b9ab;


    using OzSafeERC20 for OzIERC20;

    struct Token {
        bytes32 ticker;
        OzIERC20 token;
    }

    mapping(bytes32 => Token) public Coins;
    mapping(address => mapping(bytes32 => uint)) public depositerBalances;

    ICurveAavePool aavePool;
    IYearnAlusd yearnVault;

    constructor() {
        Coins[usdcTicker] = Token(usdcTicker, OzIERC20(usdcAddr));
        Coins[curveTicker] = Token(curveTicker, OzIERC20(curveTokenAddr));
        Coins[yearnTicker] = Token(yearnTicker, OzIERC20(yearnTokenAddr));

        aavePool = ICurveAavePool(aavePoolAddr);
        yearnVault = IYearnAlusd(yearnVaultAddr);
    }

    function deposit(address _depositer, uint _amount, bytes32 _ticker) external override {
        require(Coins[usdcTicker].token.balanceOf(_depositer) >= _amount,
                'Insufficent balance of the depositer');

        Coins[usdcTicker].token.transferFrom(_depositer, address(this), _amount);
        Coins[usdcTicker].token.safeApprove(aavePoolAddr, _amount);

        uint curveTokenAmount = _depositToCurve({
            _depositer: _depositer, _amount: _amount, _ticker: _ticker
            });
        _depositToYearn({_depositer: _depositer, _amount: curveTokenAmount});
    }

    function _depositToCurve(address _depositer, uint _amount, bytes32 _ticker)
        internal returns(uint curveTokensAmount) {

        uint[3] memory coinAmounts;
        coinAmounts[0] = 0;
        coinAmounts[1] = _amount;
        coinAmounts[2] = 0;

        uint curveTokenAmount = aavePool.add_liquidity(coinAmounts, 0, true);
        depositerBalances[_depositer][_ticker] += _amount;
        depositerBalances[_depositer][curveTicker] += curveTokenAmount;

        return curveTokenAmount;
    }

    function _depositToYearn(address _depositer, uint _amount) internal {
        Coins[curveTicker].token.safeApprove(yearnVaultAddr, _amount);

        uint yearnTokenAmountBefore = yearnVault.balanceOf(address(this));
        yearnVault.deposit(_amount);
        uint yearnTokenAmount = yearnVault.balanceOf(address(this)) - yearnTokenAmountBefore;

        depositerBalances[_depositer][yearnTicker] += yearnTokenAmount;
    }

    function withdrawAll(address _depositer, int128 _coin, uint _minAmount,
        bytes32 _ticker) external override {
        require(depositerBalances[ _depositer][_ticker] > 0,
                "Insufficient funds for withdrawAll");

        uint curveTokenAmount = _withdrawFromYearn({
             _depositer: _depositer, _amount: depositerBalances[ _depositer][yearnTicker]});

        uint amount = aavePool.remove_liquidity_one_coin(curveTokenAmount, _coin, _minAmount, true);
        depositerBalances[_depositer][curveTicker] = 0;

        Coins[usdcTicker].token.transfer(_depositer, amount);
        depositerBalances[_depositer][_ticker] = 0;

    }

    function withdraw(address _depositer, uint _amount, bytes32 _ticker) external override {
        require(depositerBalances[_depositer][_ticker] >= _amount,
                "Insufficient funds for withdraw");

        uint[3] memory coinAmounts;
        coinAmounts[0] = 0;
        coinAmounts[1] = _amount;
        coinAmounts[2] = 0;

        uint curveRequiredAmount = aavePool.calc_token_amount(coinAmounts, false);
        uint curveTokenAmount = _withdrawFromYearn({
            _depositer: _depositer, _amount: curveRequiredAmount
            });

        _withdrawFromCurve({
            _depositer: _depositer, _amount: coinAmounts, curveTokenAmount: curveTokenAmount
            });

        Coins[usdcTicker].token.transfer(_depositer, _amount);
        depositerBalances[_depositer][_ticker] -= _amount;
    }

    function _withdrawFromCurve(address _depositer, uint[3] memory _amount, uint curveTokenAmount)
        internal {

        aavePool.remove_liquidity_imbalance(_amount, curveTokenAmount, true);
        depositerBalances[_depositer][curveTicker] -= curveTokenAmount;
    }

    function _withdrawFromYearn(address _depositer, uint _amount)
        internal returns(uint curveTokenAmount) {
        require(depositerBalances[_depositer][yearnTicker] >= _amount,
                "Insufficient funds for Yearn");

        uint curveTokensBefore = Coins[curveTicker].token.balanceOf(address(this));
        yearnVault.withdraw(_amount);
        uint curveTokensAfter = Coins[curveTicker].token.balanceOf(address(this));

        depositerBalances[_depositer][yearnTicker] -= _amount;

        return curveTokensAfter - curveTokensBefore;
    }

}