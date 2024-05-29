// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

import {FunctionsSource} from "./FunctionsSource.sol";
import {SLCToken} from "./SLCToken.sol";
import {CreateAndAuthenticateSanctumLinkIdentityV2} from "./CreateAndAuthenticateSanctumLinkIdentityV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KYCVerifiedStage0
 * @notice This will be the first stage of storing KYC verified properties onchain
 * @notice The verified attributes are hardcoded for this contract.
 */
contract KYCVerifiedStage0 is FunctionsClient, Ownable {
    using FunctionsRequest for FunctionsRequest.Request;

    // Custom error types
    error KYCVerifiedStage0__AddressNotAuthenticated();

    struct VerifiedProperties {
        bytes32 primaryEmail;
        bytes32 nameOfUser;
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

    CreateAndAuthenticateSanctumLinkIdentityV2 public createAndAuthenticateSanctumLinkIdentity;
    FunctionsSource internal immutable i_functionsSource;
    SLCToken internal immutable i_slcToken;

    uint256 public rewardAmount = 50;
    uint256 private constant PRECISION = 1e16;

    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;

    uint32 gasLimit = 300000;
    uint64 subscriptionId;

    // Mappings to store request-related data
    mapping(bytes32 => VerifiedProperties)
        public s_sanctumLinkIdentityToKYCStage0VerifiedProperties;
    mapping(bytes32 => bool) public rewardClaimed;
    mapping(bytes32 => bytes) public s_responses;
    mapping(bytes32 => bytes) public s_errors;

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

    event RewardClaimed(bytes32 indexed sanctumLinkIdentity, uint256 valueInWei, string valueString);

    constructor(
        uint64 functionSubscriptionId,
        SLCToken _slcToken,
        address _createAndAuthenticateSanctumLinkIdentity
    ) FunctionsClient(router) Ownable(msg.sender) {
        subscriptionId = functionSubscriptionId;
        i_functionsSource = new FunctionsSource();
        i_slcToken = _slcToken;
        createAndAuthenticateSanctumLinkIdentity = CreateAndAuthenticateSanctumLinkIdentityV2(
            _createAndAuthenticateSanctumLinkIdentity
        );

    }

    function setRewardAmount(uint256 _rewardAmount) external onlyOwner {
        rewardAmount = _rewardAmount;
    }

    function sendRequest(
        string memory _sanctumLinkIdentity
    ) external returns (bytes32 requestId) {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert KYCVerifiedStage0__AddressNotAuthenticated();
        }
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
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // Store the response and any errors
        s_responses[requestId] = response;
        s_errors[requestId] = err;

        (
            string memory sanctumLinkIdentity,
            string memory primaryEmail,
            string memory nameOfUser,
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

        VerifiedProperties memory verifiedProperties;
        verifiedProperties = s_sanctumLinkIdentityToKYCStage0VerifiedProperties[
            stringToBytes32(sanctumLinkIdentity)
        ];

        VerifiedProperties memory oldVerifiedProperties = verifiedProperties;
        bool isCompletelyPopulated = true;

        if (stringToBytes32(primaryEmail) != bytes32(0))
            verifiedProperties.primaryEmail = stringToBytes32(primaryEmail);
        if (stringToBytes32(nameOfUser) != bytes32(0))
            verifiedProperties.nameOfUser = stringToBytes32(nameOfUser);
        if (stringToBytes32(primaryPhone) != bytes32(0))
            verifiedProperties.primaryPhone = stringToBytes32(primaryPhone);
        if (stringToBytes32(dateOfBirth) != bytes32(0))
            verifiedProperties.dateOfBirth = stringToBytes32(dateOfBirth);
        if (stringToBytes32(birthCertificateDocument) != bytes32(0))
            verifiedProperties.birthCertificateDocument = stringToBytes32(
                birthCertificateDocument
            );
        if (stringToBytes32(countryOfBirth) != bytes32(0))
            verifiedProperties.countryOfBirth = stringToBytes32(
                countryOfBirth
            );
        if (stringToBytes32(nationalId) != bytes32(0))
            verifiedProperties.nationalId = stringToBytes32(nationalId);
        if (stringToBytes32(currentCountryOfResidence) != bytes32(0))
            verifiedProperties.currentCountryOfResidence = stringToBytes32(
                currentCountryOfResidence
            );
        if (stringToBytes32(currentStateOfResidence) != bytes32(0))
            verifiedProperties.currentStateOfResidence = stringToBytes32(
                currentStateOfResidence
            );
        if (stringToBytes32(primaryPhysicalAddress) != bytes32(0))
            verifiedProperties.primaryPhysicalAddress = stringToBytes32(
                primaryPhysicalAddress
            );
        if (stringToBytes32(utilityBillForPrimaryResidence) != bytes32(0))
            verifiedProperties
                .utilityBillForPrimaryResidence = stringToBytes32(
                utilityBillForPrimaryResidence
            );

        VerifiedProperties memory newVerifiedProperties = verifiedProperties;

        if (
            verifiedProperties.primaryEmail == bytes32(0) ||
            verifiedProperties.nameOfUser == bytes32(0) ||
            verifiedProperties.primaryPhone == bytes32(0) ||
            verifiedProperties.dateOfBirth == bytes32(0) ||
            verifiedProperties.birthCertificateDocument == bytes32(0) ||
            verifiedProperties.countryOfBirth == bytes32(0) ||
            verifiedProperties.nationalId == bytes32(0) ||
            verifiedProperties.currentCountryOfResidence == bytes32(0) ||
            verifiedProperties.currentStateOfResidence == bytes32(0) ||
            verifiedProperties.primaryPhysicalAddress == bytes32(0) ||
            verifiedProperties.utilityBillForPrimaryResidence == bytes32(0)
        ) {
            isCompletelyPopulated = false;
        }

        if (
            isCompletelyPopulated &&
            !rewardClaimed[stringToBytes32(sanctumLinkIdentity)]
        ) {
            uint256 adjustedRewardAmount = rewardAmount * PRECISION;
            i_slcToken.mint(msg.sender, adjustedRewardAmount);
            string memory valueString = weiToEthString(adjustedRewardAmount);
            emit RewardClaimed(
                stringToBytes32(sanctumLinkIdentity),
                adjustedRewardAmount, valueString
            );
            rewardClaimed[stringToBytes32(sanctumLinkIdentity)] = true;
        }
        s_sanctumLinkIdentityToKYCStage0VerifiedProperties[
            stringToBytes32(sanctumLinkIdentity)
        ] = verifiedProperties;

        // Emit events to log the response and updated properties
        emit Response(
            requestId,
            stringToBytes32(sanctumLinkIdentity),
            verifiedProperties,
            response,
            err
        );
        emit VerifiedPropertiesUpdated(
            stringToBytes32(sanctumLinkIdentity),
            oldVerifiedProperties,
            newVerifiedProperties
        );
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

    function weiToEthString(uint256 valueInWei) internal pure returns (string memory) {
        uint256 ethUnits = valueInWei / 1 ether;
        uint256 decimalUnits = (valueInWei % 1 ether) / 10**14; // Get 4 decimal places
        
        // Convert uint256 to strings
        string memory ethUnitsStr = uintToString(ethUnits);
        string memory decimalUnitsStr = uintToString(decimalUnits);
        
        // Ensure 4 decimal places (e.g., 0.0500)
        while (bytes(decimalUnitsStr).length < 4) {
            decimalUnitsStr = string(abi.encodePacked("0", decimalUnitsStr));
        }

        return string(abi.encodePacked(ethUnitsStr, ".", decimalUnitsStr, " SLC"));
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
