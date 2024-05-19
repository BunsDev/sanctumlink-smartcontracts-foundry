// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CreateSanctumLinkIdentityV2
 * @author Isaiah Idonije
 *
 * Creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked to the connected wallet(s)
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
 * SanctumLink Centralized Service is accessed. For now as a temporary measure, the security implemented is to ensure email addresses are
 * not editable in the backend functionality.
 */

contract CreateSanctumLinkIdentityV2 is Ownable {
    address public s_connectedWallet;
    address[] public s_connnectedWallets;
    bytes32 public s_sanctumLinkIdentity;
    bytes32[] public s_sanctumLinkIdentities;

    // Mapping to link connected wallets to SanctumLink Identity
    mapping(bytes32 => address[])
        public s_connectedWalletsToSanctumLinkIdentity;

    // Mapping to link SanctumLink Identity to connected wallet
    mapping(address => bytes32) public s_sanctumLinkIdentityToConnectedWallet;

    mapping(bytes32 => mapping(address => bool)) private s_isWalletConnected;

    // Event to emit when sanctumLinkIdentity is created
    event sanctumLinkIdentityCreated(
        bytes32 indexed sanctumLinkIdentity,
        address indexed connectedWallet
    );

    constructor() Ownable(msg.sender) {}

    modifier onlyAuthenticatedWalletAddress(
        address _address,
        bytes32 _sanctumLinkIdentity
    ) {
        require(
            s_connectedWallet != address(0) &&
                s_sanctumLinkIdentity != bytes32(0),
            "No wallet address authenticated yet"
        );
        require(
            _address == s_connectedWallet &&
                _sanctumLinkIdentity == s_sanctumLinkIdentity,
            "Address not authorized"
        );
        _;
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
    function createSanctumLinkIdentity(string memory _email) private {
        s_sanctumLinkIdentity = createIdentity(_email);
        s_sanctumLinkIdentities.push(s_sanctumLinkIdentity);
        s_connectedWallet = msg.sender;
        emit sanctumLinkIdentityCreated(s_sanctumLinkIdentity, msg.sender);

        require(
            s_connectedWalletsToSanctumLinkIdentity[s_sanctumLinkIdentity]
                .length == 0,
            "Identity already connected to wallet!"
        );

        s_connnectedWallets.push(msg.sender);
        s_isWalletConnected[s_sanctumLinkIdentity][msg.sender] = true;
        s_connectedWalletsToSanctumLinkIdentity[
            s_sanctumLinkIdentity
        ] = s_connnectedWallets;
        s_sanctumLinkIdentityToConnectedWallet[
            msg.sender
        ] = s_sanctumLinkIdentity;
    }

    function addWallet(
        address _address
    ) public onlyAuthenticatedWalletAddress(_address) {
        require(
            !isConnected(s_sanctumLinkIdentity, msg.sender),
            "Wallet already connected!"
        );
        s_connnectedWallets.push(msg.sender);
        s_isWalletConnected[s_sanctumLinkIdentity][msg.sender] = true;
        s_connectedWalletsToSanctumLinkIdentity[
            s_sanctumLinkIdentity
        ] = s_connnectedWallets;
        s_sanctumLinkIdentityToConnectedWallet[
            msg.sender
        ] = s_sanctumLinkIdentity;
    }

    // Helper function to create an Identity
    function createIdentity(
        string memory _email
    ) private pure returns (bytes32) {
        return sha256(abi.encodePacked(_email));
    }

    // Getter function to retrieve the sanctumLinkIdentity
    function getSanctumLinkIdentity() public view returns (bytes32) {
        return s_sanctumLinkIdentity;
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
