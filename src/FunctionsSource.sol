// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @author Isaiah Idonije
 * @notice This contract will contain the js source codes that chainlink functions will run
 */

contract FunctionsSource {
    string public getKYCVerifiedStage0 = "const { ethers } = await import('npm:ethers@6.10.0');"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();" "const sanctumLinkIdentity = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "    url: `https://sanctum-link-worker.danny-b41.workers.dev/api/v1/identity/${sanctumLinkIdentity}`"
        "});" "const dataTypeArray = [`string`];"
        "const dataValueArray = [sanctumLinkIdentity];"
        "const kycVerifiedStage0 = apiResponse.data;"
        "for (const key in kycVerifiedStage0) {"
        "    if (kycVerifiedStage0.hasOwnProperty(key)) {"
        "        dataTypeArray.push(`string`);"
        "        dataValueArray.push(kycVerifiedStage0[key]);"
        "    }"
        "}"
        "const encoded = abiCoder.encode(dataTypeArray, dataValueArray);"
        "return ethers.getBytes(encoded);";

    string public getProductInformation = "const { ethers } = await import('npm:ethers@6.10.0');"
        "const abiCoder = ethers.AbiCoder.defaultAbiCoder();" "const productId = args[0];"
        "const apiResponse = await Functions.makeHttpRequest({"
        "    url: `https://sanctum-link-worker.danny-b41.workers.dev/api/v1/product/${productId}`"
        "});" "const productPrice = Number(apiResponse.data.price);"
        "const productQuantity = Number(apiResponse.data.stock);"
        "const productDescription = apiResponse.data.description;"
        "const encoded = abiCoder.encode([`uint256`, `uint256`, `uint256`, `string`], [parseInt(productId), productPrice, productQuantity, productDescription]);"
        "return ethers.getBytes(encoded);";
}
