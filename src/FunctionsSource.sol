// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @author Isaiah Idonije
 * @notice This contract will contain the js source codes that chainlink functions will run
 */

contract FunctionsSource {
    string public getKYCVerifiedStage0 =
        "const { ethers } = await import('npm:ethers@6.10.0');"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();"
        "const sanctumLinkIdentity = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "    url: ``"
        "});"
        "if (apiResponse.error) {"
        "    console.log(apiResponse.error);"
        "    throw Error('Request failed');"
        "}"
        "const dataTypeArray = [`string`];"
        "const dataValueArray = [sanctumLinkIdentity];"
        "const KYCVerifiedStage0 = apiResponse.data[sanctumLinkIdentity];"
        "KYCVerifiedStage0.forEach(item => {"
        "    const key = Object.keys(item)[0];"
        "    const value = item[key];"
        "    dataTypeArray.push(`string`);"
        "    if (item.verifiedOnChain) {"
        "        dataValueArray.push(value);"
        "    } else {"
        "        dataValueArray.push('');"
        "    }"
        "})"
        "const encoded = abiCoder.encode(dataTypeArray, dataValueArray);"
        "return ethers.getBytes(encoded);";
}
