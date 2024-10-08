// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import 'hardhat/console.sol';

library DistributorLibrary {
    function min(uint256 a, uint256 b) internal pure returns (uint256 _min) {
        _min = (a <= b) ? a : b;
    }

    function triMin(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256 _min) {
        _min = (a <= b && a <= c) ? a : (b <= a && b <= c) ? b : c;
    }

    function getEnd(
        uint256 start,
        uint256 amount,
        uint256 rate,
        uint256 period
    ) internal pure returns (uint256 end) {
        end = (amount % rate == 0)
            ? (amount / rate) * period + start
            : ((amount / rate) * period) + period + start;
    }

    function balanceAtTime(
        uint256 currentTime,
        uint256 start,
        uint256 cliff,
        uint256 amount,
        uint256 rate,
        uint256 period
    )
        internal
        pure
        returns (
            uint256 claimableBalance,
            uint256 remainder,
            uint256 latestUnlock
        )
    {
        if (start > currentTime || cliff > currentTime) {
            claimableBalance = 0;
            remainder = amount;
            latestUnlock = start;
        } else {
            // means that ALL Three are in the past, start is in the past, cliff is in the past, and unlockDate is in the past
            uint256 periodsElapsed = (currentTime - start) / period;
            uint256 calculatedBalance = periodsElapsed * rate;
            claimableBalance = min(amount, calculatedBalance);
            latestUnlock = start + (period * periodsElapsed);
        }
    }

    function validatePlan(
        uint256 start,
        uint256 cliff,
        uint256 amount,
        uint256 rate,
        uint256 period
    ) internal pure returns (uint256 end) {
        end = getEnd(start, amount, rate, period);
        require(end >= cliff);
        require(amount > 0);
        require(amount >= rate);
        require(period > 0, "0_period");
        require(rate > 0, "0_rate");
    }
}
