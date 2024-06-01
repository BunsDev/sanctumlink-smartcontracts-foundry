// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConverter {
    // For Avalanche Fuji network
    function getLatestPrice() internal view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(0x0A77230d17318075983913bC2145DB16C7366156);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getConversionRate(uint256 ethAmount) public view returns(uint256) {
        uint256 ethPrice = getLatestPrice();
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;
        return ethAmountInUsd;
    }

    function getUsdConversionRate(uint256 usdAmount) public view returns(uint256) {
        uint256 ethPrice = getLatestPrice();
        uint256 ethAmount = (usdAmount * 1e18) / ethPrice;
        return ethAmount;
    }
}