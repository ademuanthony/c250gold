/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

contract MockC250PriceOracle {

    function getQuote(
        address tokenIn,
        address tokenOut,
        address pool,
        uint128 amountIn,
        uint32 secondsAgo
    ) external view returns (uint256 amountOut) {
        amountOut = amountIn;
    }
}
