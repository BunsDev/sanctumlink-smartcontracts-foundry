//////// DEMO CODE TO HELP INTEGRATE PURCHASE PRODUCTS FUNCTIONS IN ECOMMERCE MOCK CONTRACT ////////

const slcTokenAddress = "0xSLCTokenAddress";
const ecommerceAddress = "0xEcommerceContractAddress";
const priceConverterAddress = "0xPriceConverterAddress"; 

const slcTokenAbi = [/* SLCToken ABI */];
const ecommerceAbi = [/* Ecommerce ABI */];
const priceConverterAbi = [/* PriceConverter ABI */];

const slcToken = new web3.eth.Contract(slcTokenAbi, slcTokenAddress);
const ecommerce = new web3.eth.Contract(ecommerceAbi, ecommerceAddress);
const priceConverter = new web3.eth.Contract(priceConverterAbi, priceConverterAddress);

// Purchase Product with SLC Token
async function approveAndBuyProductWithToken(userAddress, productId, quantity) {
    const product = await ecommerce.methods.s_products(productId).call();
    const totalPriceUSD = product.priceUSD * quantity;
    const conversionFactor = 2 //  Assuming 0.5 SLC = 1 USD
    const totalPriceSLC = totalPriceUSD * conversionFactor * (10 ** 10);

    // Step 1: Approve the contract to spend the required amount
    await ishToken.methods.approve(ecommerceAddress, totalPriceSLC).send({ from: userAddress });

    // Step 2: Purchase the product
    await ecommerce.methods.purchaseProductWithSLCToken(productId, quantity).send({ from: userAddress });
}

// Purchase Product with Native Token
async function buyProductWithNativeToken(userAddress, productId, quantity) {
    const product = await ecommerce.methods.products(productId).call();
    const totalPriceUSD = product.priceUSD * quantity;
    const totalPriceNativeToken = await priceConverter.methods.getConversionRate(totalPriceUSD).call();

    await ecommerce.methods.purchaseProductWithNativeToken(productId, quantity).send({ from: userAddress, value: totalPriceNativeToken });
}
   