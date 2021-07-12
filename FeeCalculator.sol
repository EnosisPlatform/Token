// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswapV2Pair.sol";
import "./AggregatorV3Interface.sol";


contract FeeCalculator {
    using SafeMath for uint256;

    AggregatorV3Interface private _aggregator;
    //IUniswapV2Pair private _pair;
    // IERC20 private _token;
    uint256 private _decimals;
    uint256 public _bnbDecimals;

    constructor(address pairAddress, address AggregatorAddress) {
        _aggregator = AggregatorV3Interface(AggregatorAddress);
        pairAddress = address(0);
        // _pair = IUniswapV2Pair(pairAddress);
        // _token = IERC20(_pair.token1());
        _decimals = 8;
        _bnbDecimals = 8;
    }

   /**
    * Requirements:
    *   Pancakeswap pair address
    *
    * Returns $ENOS price in BNB
    *
    */
    function _getTokenPriceInBNB() internal view returns(uint)
    {
        (uint256 Res0, uint256 Res1,) = _pair.getReserves();

        uint256 res1 = Res1 * (10 ** _decimals);
        return(res1 / Res0); // Quantity of BNB for 1 Token
    }

   /**
    * @dev
    *
    * Requirements:
    *   `_aggregator` object to get BNB price in USD
    *
    * Returns $ENOS price in USD
    *
    */
    function _getTokenPrice() internal view returns(uint256)
    {
        (, int price, , ,) = _aggregator.latestRoundData();
        uint256 bnbPrice = uint256(price);
        return ((_getTokenPriceInBNB() * bnbPrice) / (10 ** 18));
    }

   /**
    * @dev
    *
    * Returns fees amount. Needs to use an oracle for bnb price and get Pancake LP value
    */
    function getFeeAmount() public view returns (uint256) {
        return ((10 ** (_decimals + _bnbDecimals - 1)) / _getTokenPrice());
    }

}
