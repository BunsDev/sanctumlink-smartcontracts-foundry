const { ethers } = await import('npm:ethers@6.10.0');

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const sanctumLinkIdentity = args[0];

const url = `https://sanctum-link-worker.danny-b41.workers.dev/api/v1/identity/${sanctumLinkIdentity}`; // api url goes here

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

const KYCVerified = res.data

for (const key in kycVerifiedStage0) {
    if (kycVerifiedStage0.hasOwnProperty(key)) {
        dataTypeArray.push(`string`);
        dataValueArray.push(kycVerifiedStage0[key]);
    }
}

const encoded = abiCoder.encode(dataTypeArray, dataValueArray)

return ethers.getBytes(encoded)

