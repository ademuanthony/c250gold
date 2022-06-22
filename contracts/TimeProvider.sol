/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

contract TimeProvider {
    uint256 now;

    function currentTime() external view returns (uint256 amountOut) {
        if (now > 0) return now;
        return block.timestamp;
    }

    function setTime(uint256 _now) external {
        now = _now;
    }

    function increaseTime(uint256 val) external {
        if (now > 0) {
            now = now + val;
        } else {
            now = block.timestamp + val;
        }
    }

    function decreaseTime(uint256 val) external {
        if (now > 0) {
            now = now - val;
        } else {
            now = block.timestamp - val;
        }
    }

    function reset() external {
        now = 0;
    }
}
