// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFeeCalculator {

   /**
    * @dev
    *
    * Returns ENOS transaction fees amount.
    */
    function getFeeAmount() external view returns (uint256);

}
