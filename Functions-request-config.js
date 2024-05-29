const fs = require("fs")

require("@chainlink/env-enc").config()

const Location = {
    Inline: 0,
    Remote: 1,
}

const CodeLanguage = {
    JavaScript: 0,
}

const ReturnType = {
    uint: "uint256",
    uint256: "uint256",
    int: "int256",
    int256: "int256",
    string: "string",
    bytes: "Buffer",
    Buffer: "Buffer",
}

// Configure the request by setting the fields below
const requestConfig = {
    // String containing the source code to be executed
    source: fs.readFileSync("./getProductInformationSource.js").toString(),
    //source: fs.readFileSync("./API-request-example.js").toString(),
    // Location of source code (only Inline is currently supported)
    codeLocation: Location.Inline,
    // Optional. Secrets can be accessed within the source code with `secrets.varName` (ie: secrets.apiKey). The secrets object can only contain string values.
    secrets: {},
    // Optional if secrets are expected in the sourceLocation of secrets (only Remote or DONHosted is supported)
    //   secretsLocation: Location.DONHosted,
    // Args (string only array) can be accessed within the source code with `args[index]` (ie: args[0]).
    args: ["1"],
    // Code language (only JavaScript is currently supported)
    codeLanguage: CodeLanguage.JavaScript,
    // Expected type of the returned value
    expectedReturnType: ReturnType.bytes,
    // expectedReturnType: ReturnType.string,
    // Redundant URLs which point to encrypted off-chain secrets
    secretsURLs: [],
}

module.exports = requestConfig