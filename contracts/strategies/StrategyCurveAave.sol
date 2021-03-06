//SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {IERC20 as OzIERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20 as OzSafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AddressAndTickers as Constants} from '../helpers/AddressAndTickers.sol';

import '../interfaces/IStrategy.sol';
import '../interfaces/ICurveAavePool.sol';

import "hardhat/console.sol";

contract StrategyCurveAave is IStrategy {
 
    using OzSafeERC20 for OzIERC20;

    struct Token {
        bytes32 ticker;
        OzIERC20 token;
    }

    mapping(bytes32 => Token) public Coins;
    mapping(address => mapping(bytes32 => uint)) public depositerBalances;

    ICurveAavePool aavePool;

    constructor() {
        Coins[Constants.USDC_TICKER] = Token(Constants.USDC_TICKER, OzIERC20(Constants.USDC_ADDRESS));
        Coins[Constants.CURVE_TICKER] = Token(Constants.CURVE_TICKER, OzIERC20(Constants.CURVE_TOKEN_ADDRESS));

        aavePool = ICurveAavePool(Constants.CURVE_AAVE_ADDRESS);
    }

    function deposit(address _depositer, uint _amount, bytes32 _ticker) external override {
        require(Coins[Constants.USDC_TICKER].token.balanceOf(_depositer) >= _amount,
                'Insufficent balance of the depositer');

        Coins[Constants.USDC_TICKER].token.safeApprove(Constants.CURVE_AAVE_ADDRESS, _amount);

        uint[3] memory coinAmounts;
        coinAmounts[0] = 0;
        coinAmounts[1] = _amount;
        coinAmounts[2] = 0;

        uint curveTokenAmount = aavePool.add_liquidity(coinAmounts, 0, true);
        depositerBalances[_depositer][_ticker] += _amount;
        depositerBalances[_depositer][Constants.CURVE_TICKER] += curveTokenAmount;
    }

     function withdraw(address _depositer, uint _amount,
         bytes32 _ticker) external override {
         require(depositerBalances[_depositer][_ticker] >= _amount,
                "Insufficient funds for withdraw");

        uint[3] memory coinAmounts;
        coinAmounts[0] = 0;
        coinAmounts[1] = _amount;
        coinAmounts[2] = 0;

        uint curveRequiredAmount = aavePool.calc_token_amount(coinAmounts, false);

        uint curveTokenAmount = aavePool.
            remove_liquidity_imbalance(coinAmounts, curveRequiredAmount, true);

        depositerBalances[_depositer][Constants.CURVE_TICKER] -= curveTokenAmount;

        Coins[Constants.USDC_TICKER].token.transfer(_depositer, _amount);
        depositerBalances[_depositer][_ticker] -= _amount;
     }


    function withdrawAll(address _depositer, int128 _coin, uint _minAmount,
        bytes32 _ticker) external override {
        require(depositerBalances[ _depositer][_ticker] > 0,
            "Insufficient funds for withdrawAll");

        uint amount = aavePool.remove_liquidity_one_coin(
            depositerBalances[_depositer][Constants.CURVE_TICKER]
            , _coin, _minAmount, true);

        depositerBalances[_depositer][Constants.CURVE_TICKER] = 0;
        Coins[Constants.USDC_TICKER].token.transfer(_depositer, amount);
        depositerBalances[_depositer][_ticker] = 0;
    }

}
