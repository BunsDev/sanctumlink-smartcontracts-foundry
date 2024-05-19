// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsSource} from "./FunctionsSource.sol";
import {SLCToken} from "./SLCToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KYCVerifiedStage0
 * @author Isaiah Idonije
 *
 *
 * @notice This will be the first stage of storing KYC verified properties onchain
 * @notice The verified attributes are hardcoded for this contract.
 * @notice The chainlink functions limit will be increased from 256 bytes
 */

contract KYCVerifiedStage0 is FunctionsClient, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);
    error InvalidRouter(address router);
    error LatestVerifiedKYCRequestNotYetFulfilled();

    struct VerifiedProperties {
        bytes32 primaryEmail;
        bytes32 name;
        bytes32 primaryPhone;
        bytes32 dateOfBirth;
        bytes32 birthCertificateDocument;
        bytes32 countryOfBirth;
        bytes32 nationalId;
        bytes32 currentCountryOfResidence;
        bytes32 currentStateOfResidence;
        bytes32 primaryPhysicalAddress;
        bytes32 utilityBillForPrimaryResidence;
    }

    FunctionsSource internal immutable i_functionsSource;

    SLCToken internal immutable i_slcToken;
    uint256 public rewardAmount = 50;
    uint256 private constant PRECISION = 1e16;

    // Hardcoded for Fuji
    // Supported networks https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    //Callback gas limit
    uint32 gasLimit = 300000;

    uint64 subscriptionId;

    // State variables to store the last request ID, response, and error
    bytes32 internal s_lastRequestId;
    bytes internal s_lastResponse;
    bytes internal s_lastError;

    mapping(bytes32 => VerifiedProperties)
        public s_sanctumLinkIdentityToKYCStage0VerifiedProperties;

    mapping(bytes32 => bool) public rewardClaimed;

    // Event to log responses
    event Response(
        bytes32 indexed requestId,
        bytes32 indexed sanctumLinkIdentity,
        VerifiedProperties verifiedProperties,
        bytes response,
        bytes err
    );

    event VerifiedPropertiesUpdated(
        bytes32 indexed sanctumLinkIdentity,
        VerifiedProperties oldVerifiedProperties,
        VerifiedProperties newVerifiedProperties
    );

    event RewardClaimed(bytes32 indexed sanctumLinkIdentity, uint256 amount);

    constructor(
        uint64 functionSubscriptionId,
        SLCToken _slcToken
    ) FunctionsClient(router) Ownable(msg.sender) {
        subscriptionId = functionSubscriptionId;
        i_functionsSource = new FunctionsSource();
        i_slcToken = _slcToken;
    }

    function setRewardAmount(uint256 _rewardAmount) external onlyOwner {
        rewardAmount = _rewardAmount;
    }

    function sendRequest(
        string memory _sanctumLinkIdentity
    ) external returns (bytes32 requestId) {
        if (s_lastRequestId != bytes32(0))
            revert LatestVerifiedKYCRequestNotYetFulfilled();

        string[] memory args = new string[](1);
        args[0] = _sanctumLinkIdentity;

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            i_functionsSource.getKYCVerifiedStage0()
        ); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        requestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        s_lastRequestId = requestId;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        (
            string memory sanctumLinkIdentity,
            string memory primaryEmail,
            string memory name,
            string memory primaryPhone,
            string memory dateOfBirth,
            string memory birthCertificateDocument,
            string memory countryOfBirth,
            string memory nationalId,
            string memory currentCountryOfResidence,
            string memory currentStateOfResidence,
            string memory primaryPhysicalAddress,
            string memory utilityBillForPrimaryResidence
        ) = abi.decode(
                response,
                (
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string,
                    string
                )
            );

        VerifiedProperties memory s_verifiedProperties;
        s_verifiedProperties = s_sanctumLinkIdentityToKYCStage0VerifiedProperties[
            stringToBytes32(sanctumLinkIdentity)
        ];

        VerifiedProperties memory oldVerifiedProperties = s_verifiedProperties;
        bool isCompletelyPopulated = true;

        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;

        s_verifiedProperties.primaryEmail = stringToBytes32(primaryEmail);
        s_verifiedProperties.name = stringToBytes32(name);
        s_verifiedProperties.primaryPhone = stringToBytes32(primaryPhone);
        s_verifiedProperties.dateOfBirth = stringToBytes32(dateOfBirth);
        s_verifiedProperties.birthCertificateDocument = stringToBytes32(
            birthCertificateDocument
        );
        s_verifiedProperties.countryOfBirth = stringToBytes32(countryOfBirth);
        s_verifiedProperties.nationalId = stringToBytes32(nationalId);
        s_verifiedProperties.currentCountryOfResidence = stringToBytes32(
            currentCountryOfResidence
        );
        s_verifiedProperties.currentStateOfResidence = stringToBytes32(
            currentStateOfResidence
        );
        s_verifiedProperties.primaryPhysicalAddress = stringToBytes32(
            primaryPhysicalAddress
        );
        s_verifiedProperties.utilityBillForPrimaryResidence = stringToBytes32(
            utilityBillForPrimaryResidence
        );

        // s_verifiedProperties = VerifiedProperties({
        //     primaryEmail: stringToBytes32(primaryEmail),
        //     name: stringToBytes32(name),
        //     primaryPhone: stringToBytes32(primaryPhone),
        //     dateOfBirth: stringToBytes32(dateOfBirth),
        //     birthCertificateDocument: stringToBytes32(birthCertificateDocument),
        //     countryOfBirth: stringToBytes32(countryOfBirth),
        //     nationalId: stringToBytes32(nationalId),
        //     currentCountryOfResidence: stringToBytes32(
        //         currentCountryOfResidence
        //     ),
        //     currentStateOfResidence: stringToBytes32(currentStateOfResidence),
        //     primaryPhysicalAddress: stringToBytes32(primaryPhysicalAddress),
        //     utilityBillForPrimaryResidence: stringToBytes32(
        //         utilityBillForPrimaryResidence
        //     )
        // });

        VerifiedProperties memory newVerifiedProperties = s_verifiedProperties;

        if (
            s_verifiedProperties.primaryEmail == bytes32(0) ||
            s_verifiedProperties.name == bytes32(0) ||
            s_verifiedProperties.primaryPhone == bytes32(0) ||
            s_verifiedProperties.dateOfBirth == bytes32(0) ||
            s_verifiedProperties.birthCertificateDocument == bytes32(0) ||
            s_verifiedProperties.countryOfBirth == bytes32(0) ||
            s_verifiedProperties.nationalId == bytes32(0) ||
            s_verifiedProperties.currentCountryOfResidence == bytes32(0) ||
            s_verifiedProperties.currentStateOfResidence == bytes32(0) ||
            s_verifiedProperties.primaryPhysicalAddress == bytes32(0) ||
            s_verifiedProperties.utilityBillForPrimaryResidence == bytes32(0)
        ) {
            isCompletelyPopulated = false;
        }

        if (
            isCompletelyPopulated &&
            !rewardClaimed[stringToBytes32(sanctumLinkIdentity)]
        ) {
            uint256 adjustedRewardAmount = rewardAmount * PRECISION;
            i_slcToken.mint(msg.sender, adjustedRewardAmount);
            emit RewardClaimed(
                stringToBytes32(sanctumLinkIdentity),
                rewardAmount
            );
            rewardClaimed[stringToBytes32(sanctumLinkIdentity)] = true;
        }
        s_sanctumLinkIdentityToKYCStage0VerifiedProperties[
            stringToBytes32(sanctumLinkIdentity)
        ] = s_verifiedProperties;
        s_lastError = err;

        // Emit an event to log the response
        emit Response(
            requestId,
            stringToBytes32(sanctumLinkIdentity),
            s_verifiedProperties,
            s_lastResponse,
            s_lastError
        );

        // Emit an event to log the updated properties
        emit VerifiedPropertiesUpdated(
            stringToBytes32(sanctumLinkIdentity),
            oldVerifiedProperties,
            newVerifiedProperties
        );

        s_lastRequestId = bytes32(0);
    }

    // Helper function to convert string to bytes32
    function stringToBytes32(
        string memory _str
    ) internal pure returns (bytes32) {
        require(bytes(_str).length == 64, "Invalid string length");
        bytes memory bStr = bytes(_str);
        uint256 res = 0;
        for (uint256 i = 0; i < bStr.length; i++) {
            uint256 value = uint256(uint8(bStr[i]));
            if (value >= 48 && value <= 57) {
                res = res * 16 + (value - 48);
            } else if (value >= 65 && value <= 70) {
                res = res * 16 + (value - 55);
            } else if (value >= 97 && value <= 102) {
                res = res * 16 + (value - 87);
            }
        }
        return bytes32(res);
    }
}
