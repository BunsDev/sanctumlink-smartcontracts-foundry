// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// 1. Use chainlink functions to get product information. the function takes in product id and
// quantity to get the price and stock. Next the total price in usd is calculated and finally,
// the totalprice in ISH and AVAX is emitted depending on the enum selected
// 2.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
// import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";

import {FunctionsSource} from "./FunctionsSource.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {UintToString} from "./UintToString.sol";
import {CreateAndAuthenticateSanctumLinkIdentityV2} from "./CreateAndAuthenticateSanctumLinkIdentityV2.sol";

contract ECommerce is Ownable, VRFConsumerBaseV2, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;
    using PriceConverter for uint256;
    using UintToString for uint256;

    enum PayWith {
        Native,
        ISH
    }

    // Custom error type
    error ECommerce__AddressNotAuthenticated();
    error ECommerce__NotEnoughProducts();
    // error KYCVerifiedStage0__UnexpectedRequestID(bytes32 requestId);

    struct Product {
        uint256 productId;
        uint256 productQuantity;
        PayWith payWith;
        uint256 totalPriceUSD;
        uint256 toTransfer;
        uint256 paymentId;
    }
    
    // VRF
    struct RequestStatus {
        uint256[] randomWords;
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
    }

    IERC20 public slcToken;
    CreateAndAuthenticateSanctumLinkIdentityV2 public createAndAuthenticateSanctumLinkIdentity;
    FunctionsSource internal immutable i_functionsSource;

    uint256 private conversionFactor = 2;
    uint256 private constant PRECISION = 1e10;

    // Chainlink VRF
    // Hardcoded for Fuji
    VRFCoordinatorV2Interface COORDINATOR;
    address vrfCoordinator = 0x2eD832Ba664535e5886b75D64C46EB9a228C2610;
    bytes32 keyHash = 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61;
    uint32 callbackGasLimit = 2500000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;
    uint256[] public requestIds;
    uint256[] public lastRandomWords;
    uint64 public s_vrfSubId;

    // Chainlink Functions
    // Hardcoded for Fuji
    // Supported networks https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0;
    bytes32 donID =
        0x66756e2d6176616c616e6368652d66756a692d31000000000000000000000000;
    //Callback gas limit
    uint32 gasLimit = 300000;
    uint64 public s_functionSubId;

    // VRF
    mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus (Chainlink VRF)
    mapping(uint256 => bool) public s_paymentIdGenerated;

    // Chainlink Functions
    mapping(bytes32 => bytes) public s_responses;
    mapping(bytes32 => bytes) public s_errors;
    mapping(bytes32 => Product) public s_products;
    mapping(uint256 => Product) public s_productOrders;

    event ProductToBePurchasedInSLC(bytes32 sanctumLinkIdentity, bytes32 indexed requestId, uint256 indexed productId, uint256 indexed productQuantity, uint256 totalPriceUSD, uint256 totalPriceSLC);
    event ProductToBePurchasedInNative(bytes32 sanctumLinkIdentity, bytes32 indexed requestId, uint256 indexed productId, uint256 indexed productQuantity, uint256 totalPriceUSD, uint256 totalPriceNative);
    event ProductPurchased(bytes32 sanctumLinkIdentity, address user, uint256 indexed productId, uint256 indexed productQuantity, uint256 indexed totalPriceUSD, uint256 paymentId);
    
    // VRF events
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event PaymentIdGenerated(uint256 paymentIdGenerated);

    constructor(IERC20 _slcToken, address _createAndAuthenticateSanctumLinkIdentity, uint64 _vrfSubId, uint64 _functionSubId) VRFConsumerBaseV2(vrfCoordinator) FunctionsClient(router) Ownable(msg.sender) {
        slcToken = _slcToken;
        createAndAuthenticateSanctumLinkIdentity = CreateAndAuthenticateSanctumLinkIdentityV2(
            _createAndAuthenticateSanctumLinkIdentity
        );
        i_functionsSource = new FunctionsSource();
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_vrfSubId = _vrfSubId;
        s_functionSubId = _functionSubId;
    }

    function sendRequest(
        uint256 _productId, uint256 _productQuantity, PayWith _payWith
    ) external returns (bytes32 requestId) {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert ECommerce__AddressNotAuthenticated();
        }
        string[] memory args = new string[](1);
        args[0] = _productId.uintToString();

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            i_functionsSource.getProductInformation()
        ); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        requestId = _sendRequest(
            req.encodeCBOR(),
            s_functionSubId,
            gasLimit,
            donID
        );
        Product memory product;
        product = s_products[requestId];
        product.productQuantity = _productQuantity;
        product.payWith = _payWith;
        s_products[requestId] = product;
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        // Store the response and any errors
        s_responses[requestId] = response;
        s_errors[requestId] = err;
        Product memory product = s_products[requestId];
        (
            uint256 id,
            uint256 price,
            uint256 stock,
            string memory description
        ) = abi.decode(response, (uint256, uint256, uint256, string));

        if (product.productQuantity > stock) {
            revert ECommerce__NotEnoughProducts();
        }
        
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);
        uint256 productId = id;
        product.productId = productId;
        uint256 productQuantity = product.productQuantity;
        uint256 totalPriceUSD = price * productQuantity * 1e8;
        product.totalPriceUSD = totalPriceUSD;

        if (product.payWith == PayWith.ISH) {
            uint256 totalPriceSLC = totalPriceUSD * conversionFactor * PRECISION;
            product.toTransfer = totalPriceSLC;
            emit ProductToBePurchasedInSLC(sanctumLinkIdentity, requestId, productId, productQuantity, totalPriceUSD, totalPriceSLC);
        }

        if (product.payWith == PayWith.Native) {
            uint256 totalPriceNative = totalPriceUSD.getConversionRate();
            product.toTransfer = totalPriceNative;
            emit ProductToBePurchasedInNative(sanctumLinkIdentity, requestId, productId, productQuantity, totalPriceUSD, totalPriceNative);
        }
    }

    function purchaseProductWithToken(bytes32 _requestId) public {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert ECommerce__AddressNotAuthenticated();
        }
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);
        uint256 requestId = generatePaymentId(_requestId);
        Product memory product = s_productOrders[requestId];
        // Transfer ISH tokens to the owner
        slcToken.transferFrom(msg.sender, owner(), product.toTransfer);
        emit ProductPurchased(sanctumLinkIdentity, msg.sender, product.productId, product.productQuantity, product.totalPriceUSD, product.paymentId);
        delete s_products[_requestId];
    }

    function purchaseProductWithNativeToken(bytes32 _requestId) public payable {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert ECommerce__AddressNotAuthenticated();
        }
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);
        uint256 requestId = generatePaymentId(_requestId);
        Product memory product = s_productOrders[requestId];
        require(msg.value == product.toTransfer, "Incorrect payment amount");
        payable(owner()).transfer(msg.value);
        emit ProductPurchased(sanctumLinkIdentity, msg.sender, product.productId, product.productQuantity, product.totalPriceUSD, product.paymentId);
        delete s_products[_requestId];
    }

    function generatePaymentId(bytes32 _requestId) internal returns (uint256 requestId) {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_vrfSubId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            fulfilled: false,
            exists: true
        });

        requestIds.push(requestId);
        emit RequestSent(requestId, numWords);
        Product memory product = s_products[_requestId];
        s_productOrders[requestId] = product;
        return requestId;      
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        lastRandomWords = _randomWords;

        uint256 paymentId = (lastRandomWords[0] % 100000);
        while (s_paymentIdGenerated[paymentId]) {
            paymentId = (uint256(keccak256(abi.encode(lastRandomWords[0], paymentId))) % 100000);
        }
        s_paymentIdGenerated[paymentId] = true;
        Product memory product = s_productOrders[_requestId];
        product.paymentId = paymentId;
        
        emit RequestFulfilled(_requestId, _randomWords);
        emit PaymentIdGenerated(paymentId);
        
    }

    function setUSDToISHConversionFactor(uint256 _conversionFactor) public onlyOwner {
        conversionFactor = _conversionFactor;
    }

    function setVRFSubscriptionId (uint64 _subId) public onlyOwner {
        s_vrfSubId = _subId;
    }

    function setFunctionSubscriptionId (uint64 _subId) public onlyOwner {
        s_vrfSubId = _subId;
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

}