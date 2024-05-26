const { ethers } = await import('npm:ethers@6.10.0');

const abiCoder = ethers.AbiCoder.defaultAbiCoder();

const productId = args[0];

const url = `https://sanctum-link-worker.danny-b41.workers.dev/api/v1/product/${productId}`; // api url goes here

const req = Functions.makeHttpRequest({
    url,
})

const res = await req;

if (res.error) {
    console.log(res.error);
    throw Error("Request failed");
}

const productPrice = Number(res.data.price);
const productQuantity = Number(res.data.stock);
const productDescription = res.data.description;
const encoded = abiCoder.encode([`uint256`, `uint256`, `uint256`, `string`], [parseInt(productId), productPrice, productQuantity, productDescription]);
return ethers.getBytes(encoded);