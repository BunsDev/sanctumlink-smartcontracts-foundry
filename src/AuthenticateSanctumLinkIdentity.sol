// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {CreateSanctumLinkIdentityV2} from "./CreateSanctumLinkIdentityV2.sol";

/**
 * @title AuthenticateSanctumLinkIdentity
 * @author Isaiah Idonije
 *
 * Authenticates wallet address connected to an existing Identity on the SanctumLink protocol
 *
 * @notice This contract is meant to be used in conjunction with the CreateSanctumLinkIdentity contract.
 *
 *
 */

contract AuthenticateSanctumLinkIdentity {
    address public s_wallet;
    bytes32 public s_sanctumLinkIdentity = bytes32(0);

    // Event to emit when wallet address selected is authenticated
    event walletAuthenticated(
        bytes32 indexed sanctumLinkIdentity,
        address indexed wallet
    );

    CreateSanctumLinkIdentityV2 public createSanctumLinkIdentity;

    /**
     *
     * @param _createSanctumLinkIdentity Address of the an already deployed instance of the 'CreateSanctumLinkIdentityV2' contract
     * @notice This constructor initializes an instance of 'CreateSanctumLinkIdentity' within the 'AuthenticateSanctumLinkIdentity' contract.
     * It takes an address '_createSanctumLinkIdentity' as an argument
     */
    constructor(address _createSanctumLinkIdentity) {
        createSanctumLinkIdentity = CreateSanctumLinkIdentityV2(
            _createSanctumLinkIdentity
        );
    }

    // Modifier to check if the input address and SanctumLink Identity matches the authenticated address and corresponding SanctumLink Identity
    modifier onlyAuthenticatedWalletAddress(
        address _address,
        bytes32 _sanctumLinkIdentity
    ) {
        require(
            s_wallet != address(0) && s_sanctumLinkIdentity != bytes32(0),
            "No wallet address authenticated yet"
        );
        require(
            _address == s_wallet &&
                _sanctumLinkIdentity == s_sanctumLinkIdentity,
            "Address not authorized"
        );
        _;
    }

    /**
     * @notice Accesses the 'getSanctumLinkIdentity' function of 'CreateSanctumLinkIdentity'. If the 'getSanctumLinkIdentity' function
     * returns a non-zero value, the wallet is authenticated. User is then logged into the Dapp attempting to authenticate user.
     */
    function authenticate() public {
        require(
            createSanctumLinkIdentity.getSanctumLinkIdentity(msg.sender) !=
                bytes32(0),
            "Wallet not found"
        );
        s_sanctumLinkIdentity = createSanctumLinkIdentity
            .getSanctumLinkIdentity(msg.sender);
        s_wallet = msg.sender;
        emit walletAuthenticated(s_sanctumLinkIdentity, s_wallet);
    }

    function addWallet(
        address _address
    ) public onlyAuthenticatedWalletAddress(_address) {
        require(
            !createSanctumLinkIdentity.isConnected(
                s_sanctumLinkIdentity,
                msg.sender
            ),
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
}
