// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

/**
 * @title KYCVerifiedDynamicData
 * @author Isaiah Idonije
 *
 *
 *
 * @notice SMART CONTRACT NOT FULLY DEVELOPED!!! WORK IN PROGRESS
 */

contract KYCVerifiedStage0 {
    using FunctionsRequest for FunctionsRequest.Request;

    // State variables to store the last request ID, response, and error
    bytes32 public lastRequestId;
    bytes public lastResponse;
    bytes public lastError;

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        bytes response;
        bytes err;
    }
    mapping(bytes32 => RequestStatus)
        public requests; /* requestId --> requestStatus */
    bytes32[] public requestIds;

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string kycVerifiedStageI,
        bytes response,
        bytes err
    );

    // Hardcoded for Fuji
    // Supported networks https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    //Callback gas limit
    uint32 gasLimit = 300000;

    uint64 subscriptionId;

    constructor(uint64 functionSubscriptionId) {
        subscriptionId = functionSubscriptionId;
    }
}
