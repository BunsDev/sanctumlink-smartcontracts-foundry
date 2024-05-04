// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title CreateSanctumLinkIdentity
 * @author Isaiah Idonije
 *
 * Creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked to the connected wallet
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

contract CreateSanctumLinkIdentity {
    address public owner;
    address public connnectedWallet;
    bytes32 public sanctumLinkIdentity = bytes32(0);
    bytes32[] public sanctumLinkIdentities;

    // Mapping to link connected wallet to SanctumLink Identity
    mapping(bytes32 => address) public connectedWalletToSanctumLinkIdentity;

    // Mapping to link SanctumLink Identity to connected wallet
    mapping(address => bytes32) public sanctumLinkIdentityToConnectedWallet;

    // Event to emit when sanctumLinkIdentity is created
    event sanctumLinkIdentityCreated(bytes32 indexed sanctumLinkIdentity);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     *
     * @param _wallet This wallet is connected to the SanctumLink Identity
     * @param _email This is the verified email of user creating a SanctumLink Identity
     * @notice This function creates an Identity on SanctumLink protocol and created SanctumLink Identity is linked
     * to the connected wallet
     * @notice After the function createSanctumLinkIdentity() is executed and the above notice is effected, the user is logged
     * in and redirected to page to fill in kyc information - Stage 0. The url of this page can look something like
     * http://localhost:8000/{username}/provide_stage_0_information
     * @notice In other words, after createSanctumLinkIdentity() is successfully executed, the Dapp reads the emitted
     * event from the blockchain, in this case the SanctumLink Identity, then queries the SanctumLink Centralized Service to
     * login in the user with that SanctumLink Identity.
     */
    function createSanctumLinkIdentity(
        address _wallet,
        string memory _email
    ) external {
        sanctumLinkIdentity = createIdentity(_email);
        sanctumLinkIdentities.push(sanctumLinkIdentity);
        emit sanctumLinkIdentityCreated(sanctumLinkIdentity);
        connnectedWallet = _wallet;
        require(
            connectedWalletToSanctumLinkIdentity[sanctumLinkIdentity] ==
                address(0),
            "Identity already connected to wallet!"
        );
        connectedWalletToSanctumLinkIdentity[
            sanctumLinkIdentity
        ] = connnectedWallet;
        sanctumLinkIdentityToConnectedWallet[
            connnectedWallet
        ] = sanctumLinkIdentity;
    }

    // Helper function to create an Identity
    function createIdentity(
        string memory _email
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_email));
    }

    // Getter function to retrieve the connected wallet associated with the SanctumLink Identity
    function getConnectedWallet(
        bytes32 _sanctumLinkIdentity
    ) public view returns (address) {
        return connectedWalletToSanctumLinkIdentity[_sanctumLinkIdentity];
    }

    // Getter function to retrieve the SanctumLink Identity associated with the connected wallet
    function getSanctumLinkIdentity(
        address _connectedWallet
    ) public view returns (bytes32) {
        return sanctumLinkIdentityToConnectedWallet[_connectedWallet];
    }

    // Getter function to retrieve all SanctumLink Identities
    function getAllSanctumLinkIdentities()
        public
        view
        onlyOwner
        returns (bytes32[] memory)
    {
        return sanctumLinkIdentities;
    }
}
