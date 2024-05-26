// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreateAndAuthenticateSanctumLinkIdentityV2
 * @author Isaiah Idonije
 *
 * @dev Creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked to the connected wallet(s).
 * Also, Authenticates wallet address connected to an existing Identity on the SanctumLink protocol.
 *
 * @notice In this contract, multiple connected wallets can linked to the SanctumLink Identity.
 * In future versions, SanctumLinkIdentity will be stored securely on a hardware wallet.
 *
 * @notice This contract can be deployed on any EVM network
 * @notice The contract is predicated on the notion that the SanctumLink centralized service will not allow the same
 * email address to be used for signup more than once. Also, for this contract implementation, one email address cannot
 * be associated to more than one SanctumLink Identity
 * @notice Final notice: In the future, a smart contract shall be deployed to check that all email addresses stored on
 * SanctumLink centralized service have not been altered periodically. If any email addresses have been altered, the
 * SanctumLink Centralized Service is assessed. For now as a temporary measure, the security implemented is to ensure email addresses are
 * not editable in the backend functionality.
 */

contract CreateAndAuthenticateSanctumLinkIdentityV2 is Ownable {
    // Custom errors
    error CreateAndAuthenticateSanctumLinkIdentityV2__WalletNotFound();
    error CreateAndAuthenticateSanctumLinkIdentityV2__IdentityAlreadyConnectedToWallet();
    error CreateAndAuthenticateSanctumLinkIdentityV2__WalletAlreadyHasIdentity();
    error CreateAndAuthenticateSanctumLinkIdentityV2__AddressNotAuthenticated();
    error CreateAndAuthenticateSanctumLinkIdentityV2__WalletAlreadyConnected();
    error CreateAndAuthenticateSanctumLinkIdentityV2__WalletNotAuthorizedForAddition();
    error CreateAndAuthenticateSanctumLinkIdentityV2__InvalidWalletAddress();

    bytes32[] public s_sanctumLinkIdentities;
    uint256 public authenticationTimeout; // Timeout period in seconds

    // Mapping to link connected wallets to SanctumLink Identity
    mapping(bytes32 => address[])
        public s_connectedWalletsToSanctumLinkIdentity;

    // Mapping to link SanctumLink Identity to connected wallet
    mapping(address => bytes32) public s_sanctumLinkIdentityToConnectedWallet;

    // Mapping to store if a wallet is connected to a specific identity
    mapping(bytes32 => mapping(address => bool)) private s_isWalletConnected;

    // Mapping to store authenticated wallets and their identities
    mapping(address => bytes32) private s_authenticatedWallet;

    // Mapping to store the time when a wallet was authenticated
    mapping(address => uint256) private s_authenticationTimestamp;

    // Mapping to store authorized wallet additions
    mapping(address => bytes32) private s_authorizedAdditions;

    // Mapping to store authorizing wallet to authorized wallet
    mapping(address => address) s_authorizingWalletToAuthorizedWallet;

    // Event to emit when sanctumLinkIdentity is created
    event SanctumLinkIdentityCreated(bytes32 indexed sanctumLinkIdentity);

    // Event to emit when a wallet address is authenticated
    event WalletAuthenticated(
        bytes32 indexed sanctumLinkIdentity,
        address indexed wallet
    );

    // Event to emit when a wallet address is authorized for addition
    event WalletAdditionAuthorized(
        bytes32 indexed sanctumLinkIdentity,
        address indexed authorizedBy,
        address indexed walletToAdd
    );

    // Event to emit when the timeout period is updated
    event TimeoutPeriodUpdated(uint256 newTimeoutPeriod);

    // @param _initialTimeout Initial timeout period in seconds
    constructor(uint256 _initialTimeout) Ownable(msg.sender) {
        authenticationTimeout = _initialTimeout;
    }

    /**
     *
     * @param _email This is the verified email of user creating a SanctumLink Identity
     * @notice This function creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked
     * to the connected wallet
     * @notice After the function createSanctumLinkIdentity() is executed and the above notice is effected, the user is logged
     * in and redirected to page to the Dapp dashboard
     * @notice In other words, after createSanctumLinkIdentity() is successfully executed, the Dapp reads the emitted
     * event from the blockchain, in this case the SanctumLink Identity, triggering an offchain event of logging in the user.
     */
    function createSanctumLinkIdentity(string memory _email) public {
        address connectedWallet = msg.sender;

        // Check if the wallet is already connected to an existing SanctumLink Identity
        if (
            s_sanctumLinkIdentityToConnectedWallet[connectedWallet] !=
            bytes32(0)
        ) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__WalletAlreadyHasIdentity();
        }

        bytes32 sanctumLinkIdentity = createIdentity(_email);
        s_sanctumLinkIdentities.push(sanctumLinkIdentity);
        emit SanctumLinkIdentityCreated(sanctumLinkIdentity);

        if (
            s_connectedWalletsToSanctumLinkIdentity[sanctumLinkIdentity]
                .length != 0
        ) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__IdentityAlreadyConnectedToWallet();
        }

        s_connectedWalletsToSanctumLinkIdentity[sanctumLinkIdentity].push(
            connectedWallet
        );
        s_isWalletConnected[sanctumLinkIdentity][msg.sender] = true;
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
            revert CreateAndAuthenticateSanctumLinkIdentityV2__WalletNotFound();
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

    /**
     * @notice Authorizes a new wallet to be added to the authenticated user's SanctumLink Identity
     * @param _newWallet The address of the new wallet to authorize
     */
    function authorizeAddWallet(address _newWallet) public {
        if (!isAuthenticated(msg.sender)) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__AddressNotAuthenticated();
        }

        bytes32 sanctumLinkIdentity = s_authenticatedWallet[msg.sender];

        if (_newWallet == address(0)) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__InvalidWalletAddress();
        }

        s_authorizedAdditions[_newWallet] = sanctumLinkIdentity;

        s_authorizingWalletToAuthorizedWallet[_newWallet] = msg.sender;

        emit WalletAdditionAuthorized(
            sanctumLinkIdentity,
            msg.sender,
            _newWallet
        );
    }

    /**
     * @notice Adds the current wallet to the authenticated user's SanctumLink Identity
     */
    function addWallet() public {
        // Checking if authorizing wallet is authenticated is just a security consideration
        // The next 4 lines of code can be commented out if you don't feel the security measure is needed
        address authorizingWallet = getAuthorizingWallet(msg.sender);
        if (!isAuthenticated(authorizingWallet)) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__WalletNotAuthorizedForAddition();
        }

        bytes32 sanctumLinkIdentity = s_authorizedAdditions[msg.sender];
        if (sanctumLinkIdentity == bytes32(0)) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__WalletNotAuthorizedForAddition();
        }
        if (s_isWalletConnected[sanctumLinkIdentity][msg.sender]) {
            revert CreateAndAuthenticateSanctumLinkIdentityV2__WalletAlreadyConnected();
        }

        s_connectedWalletsToSanctumLinkIdentity[sanctumLinkIdentity].push(
            msg.sender
        );
        s_sanctumLinkIdentityToConnectedWallet[
            msg.sender
        ] = sanctumLinkIdentity;
        s_isWalletConnected[sanctumLinkIdentity][msg.sender] = true;

        // Clear the authorization to prevent reuse
        delete s_authorizedAdditions[msg.sender];
    }

    // Helper function to create an Identity
    function createIdentity(
        string memory _email
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_email));
    }

    /**
     * @notice Helper function to get the wallet that authorized the addition
     * @param _newWallet The address of the new wallet to check
     * @return The address of the wallet that authorized the addition
     */
    function getAuthorizingWallet(
        address _newWallet
    ) internal view returns (address) {
        return s_authorizingWalletToAuthorizedWallet[_newWallet];
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

    // Function to check if an address is in the connectedWallets array
    function isConnected(
        bytes32 _sanctumLinkIdentity,
        address _address
    ) public view returns (bool) {
        return s_isWalletConnected[_sanctumLinkIdentity][_address];
    }

    // Getter function to retrieve the connected wallet associated with the SanctumLink Identity
    function getConnectedWallets(
        bytes32 _sanctumLinkIdentity
    ) public view returns (address[] memory) {
        return s_connectedWalletsToSanctumLinkIdentity[_sanctumLinkIdentity];
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
