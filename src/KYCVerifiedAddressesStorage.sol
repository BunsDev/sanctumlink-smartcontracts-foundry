// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract KYCVerifiedAddressesStorage {
    address[] public verifiedKYCAddresses;

    function addContractAddress(address _newAddress) public {
        verifiedKYCAddresses.push(_newAddress);
    }
}
