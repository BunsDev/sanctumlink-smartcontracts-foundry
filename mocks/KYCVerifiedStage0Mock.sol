// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SLCToken} from "../src/SLCToken.sol";
import {CreateAndAuthenticateSanctumLinkIdentityV2} from "../src/CreateAndAuthenticateSanctumLinkIdentityV2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title KYCVerifiedStage0
 * @notice This will be the first stage of storing KYC verified properties onchain
 * @notice The verified attributes are hardcoded for this contract.
 */

contract KYCVerifiedStage0 is Ownable {
    // Custom error types
    error KYCVerifiedStage0Mock__AddressNotAuthenticated();

    struct VerifiedProperties {
        bytes32 primaryEmail;
        bytes32 nameOfUser;
        bytes32 primaryPhone;
        bytes32 dateOfBirth;
        bytes32 countryOfBirth;
        bytes32 nationalIdNumber;
        bytes32 currentCountryOfResidence;
        bytes32 currentStateOfResidence;
        bytes32 primaryPhysicalAddress;
    }

    CreateAndAuthenticateSanctumLinkIdentityV2
        public createAndAuthenticateSanctumLinkIdentity;
    SLCToken internal immutable i_slcToken;

    uint256 public rewardAmount = 50;
    uint256 private constant PRECISION = 1e16;

    // Mappings to store request-related data
    mapping(bytes32 => VerifiedProperties)
        public s_sanctumLinkIdentityToKYCStage0VerifiedProperties;
    mapping(bytes32 => bool) public rewardClaimed;

    event VerifiedPropertiesUpdated(
        bytes32 indexed sanctumLinkIdentity,
        VerifiedProperties oldVerifiedProperties,
        VerifiedProperties newVerifiedProperties
    );

    event RewardClaimed(
        bytes32 indexed sanctumLinkIdentity,
        uint256 valueInWei,
        string valueString
    );

    constructor(
        SLCToken _slcToken,
        address _createAndAuthenticateSanctumLinkIdentity
    ) Ownable(msg.sender) {
        i_slcToken = _slcToken;
        createAndAuthenticateSanctumLinkIdentity = CreateAndAuthenticateSanctumLinkIdentityV2(
            _createAndAuthenticateSanctumLinkIdentity
        );
    }

    function setRewardAmount(uint256 _rewardAmount) external onlyOwner {
        rewardAmount = _rewardAmount;
    }

    function updateVerifiedPropertiesMock(
        string memory _nameOfUser,
        string memory _primaryPhone,
        uint256 _dateOfBirth,
        string memory _countryOfBirth,
        string memory _nationalIdNumber,
        string memory _currentCountryOfResidence,
        string memory _currentStateOfResidence,
        string memory _primaryPhysicalAddress
    ) external {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert KYCVerifiedStage0Mock__AddressNotAuthenticated();
        }
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);

        VerifiedProperties memory oldVerifiedProperties = s_sanctumLinkIdentityToKYCStage0VerifiedProperties[sanctumLinkIdentity];
        bool isCompletelyPopulated = true;

        VerifiedProperties memory newVerifiedProperties = oldVerifiedProperties;
        // Update each property only if a new value is provided
        newVerifiedProperties.primaryEmail = sanctumLinkIdentity;
        
        if (bytes(_nameOfUser).length > 0) {
            newVerifiedProperties.nameOfUser = hashAttributes(_nameOfUser);
        }
        if (bytes(_primaryPhone).length > 0) {
            newVerifiedProperties.primaryPhone = hashAttributes(_primaryPhone);
        }
        if (_dateOfBirth > 0) {
            string memory dateOfBirth = uintToString(_dateOfBirth);
            newVerifiedProperties.dateOfBirth = hashAttributes(dateOfBirth);
        }
        if (bytes(_countryOfBirth).length > 0) {
            newVerifiedProperties.countryOfBirth = hashAttributes(_countryOfBirth);
        }
        if (bytes(_nationalIdNumber).length > 0) {
            newVerifiedProperties.nationalIdNumber = hashAttributes(_nationalIdNumber);
        }
        if (bytes(_currentCountryOfResidence).length > 0) {
            newVerifiedProperties.currentCountryOfResidence = hashAttributes(_currentCountryOfResidence);
        }
        if (bytes(_currentStateOfResidence).length > 0) {
            newVerifiedProperties.currentStateOfResidence = hashAttributes(_currentStateOfResidence);
        }
        if (bytes(_primaryPhysicalAddress).length > 0) {
            newVerifiedProperties.primaryPhysicalAddress = hashAttributes(_primaryPhysicalAddress);
        }

        s_sanctumLinkIdentityToKYCStage0VerifiedProperties[sanctumLinkIdentity] = newVerifiedProperties;
        if (
            newVerifiedProperties.primaryEmail == bytes32(0) ||
            newVerifiedProperties.nameOfUser == bytes32(0) ||
            newVerifiedProperties.primaryPhone == bytes32(0) ||
            newVerifiedProperties.dateOfBirth == bytes32(0) ||
            newVerifiedProperties.countryOfBirth == bytes32(0) ||
            newVerifiedProperties.nationalIdNumber == bytes32(0) ||
            newVerifiedProperties.currentCountryOfResidence == bytes32(0) ||
            newVerifiedProperties.currentStateOfResidence == bytes32(0) ||
            newVerifiedProperties.primaryPhysicalAddress == bytes32(0)
        ) {
            isCompletelyPopulated = false;
        }

        if (
            isCompletelyPopulated &&
            !rewardClaimed[sanctumLinkIdentity]
        ) {
            uint256 adjustedRewardAmount = rewardAmount * PRECISION;
            i_slcToken.mint(msg.sender, adjustedRewardAmount);
            string memory valueString = weiToEthString(adjustedRewardAmount);
            emit RewardClaimed(
                sanctumLinkIdentity, adjustedRewardAmount, valueString
            );
            rewardClaimed[sanctumLinkIdentity] = true;
        }

        emit VerifiedPropertiesUpdated(
            sanctumLinkIdentity,
            oldVerifiedProperties,
            newVerifiedProperties
        );
    }

    // Helper function to hash attributes
    function hashAttributes(
        string memory _attributes
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_attributes));
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