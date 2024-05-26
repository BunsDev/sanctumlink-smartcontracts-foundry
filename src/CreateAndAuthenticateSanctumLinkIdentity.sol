// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreateSanctumLinkIdentity
 * @author Isaiah Idonije
 *
 * @dev Creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked to the connected wallet.
 * Also, Authenticates wallet address connected to an existing Identity on the SanctumLink protocol.
 *
 * @notice In this contract, only one connected wallet is linked to the SanctumLink Identity
 * In future versions, we will allow multiple wallets to be connected to a SanctumLink Identity
 * @notice This contract can be deployed on any EVM network
 * @notice The contract is predicated on the notion that the SanctumLink centralized service will not allow the same
 * email address to be used for signup more than once. Also, for this contract implementation, one email address cannot
 * be associated to more than one SanctumLink Identity
 * @notice Final notice: In the future, a smart contract shall be deployed to check that all email addresses stored on
 * SanctumLink centralized service have not been altered periodically. If any email addresses have been altered, the
 * SanctumLink Centralized Service is accessed. For now as a temporary measure, the security implemented is to ensure email addresses are
 * not editable in the backend functionality.
 *
 */

contract CreateSanctumLinkIdentity is Ownable {
    // Custom errors
    error CreateAndAuthenticateSanctumLinkIdentity__WalletNotFound();
    error CreateAndAuthenticateSanctumLinkIdentity__IdentityAlreadyExists();
    error CreateAndAuthenticateSanctumLinkIdentity__WalletAlreadyHasIdentity();

    bytes32[] public s_sanctumLinkIdentities;
    uint256 public authenticationTimeout; // Timeout period in seconds

    // Mapping to link connected wallet to SanctumLink Identity
    mapping(bytes32 => address) public s_connectedWalletToSanctumLinkIdentity;

    // Mapping to link SanctumLink Identity to connected wallet
    mapping(address => bytes32) public s_sanctumLinkIdentityToConnectedWallet;

    // Mapping to store authenticated wallets and their identities
    mapping(address => bytes32) private s_authenticatedWallet;

    // Mapping to store the time when a wallet was authenticated
    mapping(address => uint256) private s_authenticationTimestamp;

    // Event to emit when sanctumLinkIdentity is created
    event SanctumLinkIdentityCreated(bytes32 indexed sanctumLinkIdentity);

    // Event to emit when a wallet address is authenticated
    event WalletAuthenticated(
        bytes32 indexed sanctumLinkIdentity,
        address indexed wallet
    );

    // Event to emit when the timeout period is updated
    event TimeoutPeriodUpdated(uint256 newTimeoutPeriod);

    // _initialTimeout Initial timeout period in seconds
    constructor(uint256 _initialTimeout) Ownable(msg.sender) {
        authenticationTimeout = _initialTimeout;
    }

    /**
     *
     * @param _email This is the verified email of user creating a SanctumLink Identity
     * @notice This function creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked
     * to the connected wallet
     * @notice After the function createSanctumLinkIdentity() is executed and the above notice is effected, the user is logged
     * in and redirected to the Dapp dashboard
     * @notice In other words, after createSanctumLinkIdentity() is successfully executed, the Dapp reads the emitted
     * event from the blockchain, in this case the SanctumLink Identity, triggering an offchain event of logging in the user.
     */
    function createSanctumLinkIdentity(string memory _email) public {
        // Check if the wallet is already connected to an existing SanctumLink Identity
        if (s_sanctumLinkIdentityToConnectedWallet[msg.sender] != bytes32(0)) {
            revert CreateAndAuthenticateSanctumLinkIdentity__WalletAlreadyHasIdentity();
        }

        bytes32 sanctumLinkIdentity = createIdentity(_email);
        s_sanctumLinkIdentities.push(sanctumLinkIdentity);
        emit SanctumLinkIdentityCreated(sanctumLinkIdentity);

        if (
            s_connectedWalletToSanctumLinkIdentity[sanctumLinkIdentity] !=
            address(0)
        ) {
            revert CreateAndAuthenticateSanctumLinkIdentity__IdentityAlreadyExists();
        }
        s_connectedWalletToSanctumLinkIdentity[sanctumLinkIdentity] = msg
            .sender;
        s_sanctumLinkIdentityToConnectedWallet[
            msg.sender
        ] = sanctumLinkIdentity;
    }

    /**
     * @notice Accesses the 'getSanctumLinkIdentity' function to check if the wallet to be authenticated is
     * linked to an existing SanctumLink Identity.
     */
    function authenticate() public {
        bytes32 sanctumLinkIdentity = getSanctumLinkIdentity(msg.sender);
        if (sanctumLinkIdentity == bytes32(0)) {
            revert CreateAndAuthenticateSanctumLinkIdentity__WalletNotFound();
        }

        s_authenticatedWallet[msg.sender] = sanctumLinkIdentity;
        s_authenticationTimestamp[msg.sender] = block.timestamp;

        emit WalletAuthenticated(sanctumLinkIdentity, msg.sender);
    }

    /**
     * @notice Checks if the wallet authentication is still valid
     * @param _wallet The address of the wallet to check
     * @return True if the wallet is authenticated and within the timeout period, false otherwise
     */
    function isAuthenticated(address _wallet) public view returns (bool) {
        bytes32 sanctumLinkIdentity = s_authenticatedWallet[_wallet];
        if (sanctumLinkIdentity == bytes32(0)) {
            return false;
        }

        uint256 timestamp = s_authenticationTimestamp[_wallet];
        if (block.timestamp > timestamp + authenticationTimeout) {
            return false;
        }

        return true;
    }

    // Helper function to create an Identity
    function createIdentity(
        string memory _email
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_email));
    }

    /**
     * @notice Updates the authentication timeout period
     * @param _newTimeout The new timeout period in seconds
     */
    function updateTimeoutPeriod(uint256 _newTimeout) public onlyOwner {
        authenticationTimeout = _newTimeout;
        emit TimeoutPeriodUpdated(_newTimeout);
    }

    // Getter function to retrieve the authentication timeout
    function getAuthenticationTimeout() public view returns (uint256) {
        return authenticationTimeout;
    }

    // Getter function to retrieve the connected wallet associated with the SanctumLink Identity
    function getConnectedWallet(
        bytes32 _sanctumLinkIdentity
    ) public view returns (address) {
        return s_connectedWalletToSanctumLinkIdentity[_sanctumLinkIdentity];
    }

    // Getter function to retrieve the SanctumLink Identity associated with the connected wallet
    function getSanctumLinkIdentity(
        address _connectedWallet
    ) public view returns (bytes32) {
        return s_sanctumLinkIdentityToConnectedWallet[_connectedWallet];
    }

    // Getter function to retrieve all SanctumLink Identities
    function getAllSanctumLinkIdentities()
        public
        view
        onlyOwner
        returns (bytes32[] memory)
    {
        return s_sanctumLinkIdentities;
    }
}
