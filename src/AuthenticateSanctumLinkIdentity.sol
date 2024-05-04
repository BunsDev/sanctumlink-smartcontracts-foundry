// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CreateSanctumLinkIdentity} from "./CreateSanctumLinkIdentity.sol";

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
    address public wallet;
    bytes32 public sanctumLinkIdentity = bytes32(0);

    // Event to emit when wallet address selected is authenticated
    event walletAuthenticated(bytes32 indexed sanctumLinkIdentity);

    CreateSanctumLinkIdentity public createSanctumLinkIdentity;

    /**
     *
     * @param _createSanctumLinkIdentity Address of the an already deployed instance of the 'CreateSanctumLinkIdentity' contract
     * @notice This constructor initializes an instance of 'CreateSanctumLinkIdentity' within the 'AuthenticateSanctumLinkIdentity' contract.
     * It takes an address '_createSanctumLinkIdentity' as an argument
     */
    constructor(address _createSanctumLinkIdentity) {
        createSanctumLinkIdentity = CreateSanctumLinkIdentity(
            _createSanctumLinkIdentity
        );
    }

    /**
     *
     * @param _wallet address of wallet to be authenticated
     * @notice Accesses the 'getSanctumLinkIdentity' function of 'CreateSanctumLinkIdentity'. If the 'getSanctumLinkIdentity' function
     * returns a non-zero value, the wallet is authenticated. User is then logged into the Dapp attempting to authenticate user.
     */
    function authenticate(address _wallet) public {
        require(
            createSanctumLinkIdentity.getSanctumLinkIdentity(_wallet) !=
                bytes32(0),
            "Wallet not found"
        );
        sanctumLinkIdentity = createSanctumLinkIdentity.getSanctumLinkIdentity(
            _wallet
        );
        wallet = _wallet;
        emit walletAuthenticated(sanctumLinkIdentity);
    }
}
