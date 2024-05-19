const { ethers } = await import('npm:ethers@6.10.0');

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const sanctumLinkIdentity = args[0];

const url = ``; // api url goes here

const req = Functions.makeHttpRequest({
    url,
})

const res = await req;

if (res.error) {
    console.log(res.error);
    throw Error("Request failed");
}

const dataTypeArray = [`string`]
const dataValueArray = [sanctumLinkIdentity]

const KYCVerified = res.data[sanctumLinkIdentity]

KYCVerified.forEach(item => {
    const key = Object.keys(item)[0]
    const value = item[key]

    dataTypeArray.push(`string`)

    if (item.verifiedOnChain) {
        dataValueArray.push(value)
    } else {
        dataValueArray.push('')
    }
})

const encoded = abiCoder.encode(dataTypeArray, dataValueArray)

return ethers.getBytes(encoded)

