// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import {PriceConverter} from "../../libraries/PriceConverter.sol";
import {UintToString} from "../../libraries/UintToString.sol";
import {CreateAndAuthenticateSanctumLinkIdentityV2} from "../../src/CreateAndAuthenticateSanctumLinkIdentityV2.sol";

contract ECommerceMock is Ownable, VRFConsumerBaseV2, ReentrancyGuard {
    using PriceConverter for uint256;
    using UintToString for uint256;
    using SafeMath for uint256;

    // Custom error type
    error ECommerceMock__ProductDoesNotExist();
    error ECommerceMock__AddressNotAuthenticated();
    error ECommerceMock__NotEnoughStock();
    error ECommerceMock__SLCTokenTransferFailed();
    error ECommerceMock__NativeTokenTransferFailed();
    error ECommerceMock__IncorrectPaymentAmount();

    struct Product {
        uint256 id;
        string productDescription;
        uint256 priceUSD; // Price in USD (with 8 decimals)
        uint256 stock;
    }

    // VRF
    struct RequestStatus {
        uint256[] randomWords;
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
    }

    struct ProductOrder {
        address buyer;
        uint256 productId;
        uint256 quantity;
        uint256 totalPriceUSD;
        string shippingAddress;
        bool productDelivered;
    }

    IERC20 public slcToken;
    CreateAndAuthenticateSanctumLinkIdentityV2 public createAndAuthenticateSanctumLinkIdentity;

    uint256 private conversionFactor = 2;
    uint256 private constant PRECISION = 1e10;
    uint256 public nextProductId = 1;

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

    mapping(uint256 => Product) public s_products;

    mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus (Chainlink VRF)
    mapping(uint256 => bool) public s_paymentIdGenerated; 
    mapping(uint256 => uint256) public s_paymentIdToRequestId; // requestId --> paymentId (Chainlink VRF)
    mapping(uint256 => ProductOrder) public s_productOrders;
    mapping(uint256 => bytes32) public s_sanctumLinkIdentityToPaymentId;
    mapping(uint256 => bool) public s_productOrderDelivered;

    event ProductAdded(uint256 productId, string productDescription, uint256 priceUSD, uint256 stock);
    event ProductUpdated(uint256 productId, string productDescription, uint256 priceUSD, uint256 stock);
    event ProductRemoved(uint256 productId);
    event ProductPurchasedInSLC(
        bytes32 sanctumLinkIdentity,
        address indexed buyer,
        uint256 indexed productId,
        uint256 quantity,
        uint256 totalPriceUSD,
        uint256 indexed totalPriceInSLC
    );
    event ProductPurchasedInNative(
        bytes32 sanctumLinkIdentity,
        address indexed buyer,
        uint256 indexed productId,
        uint256 quantity,
        uint256 totalPriceUSD,
        uint256 indexed totalPriceInNative
    );
    event ProductOrderPurchasedDetails(
        uint256 indexed paymentId,
        bytes32 sanctumLinkIdentity,
        address buyer,
        uint256 productId,
        uint256 quantity,
        uint256 totalPriceUSD,
        string shippingAddress,
        bool productDelivered
    );
    event ProductOrderDeliveryConfirmed(uint256 paymentId);

    // VRF events
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event PaymentIdGenerated(uint256 paymentIdGenerated);

    constructor(IERC20 _slcToken, address _createAndAuthenticateSanctumLinkIdentity, uint64 _vrfSubId) VRFConsumerBaseV2(vrfCoordinator) Ownable(msg.sender) {
        slcToken = _slcToken;
        createAndAuthenticateSanctumLinkIdentity = CreateAndAuthenticateSanctumLinkIdentityV2(
            _createAndAuthenticateSanctumLinkIdentity
        );
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_vrfSubId = _vrfSubId;
    }

    function addProduct(string memory _productDescription, uint256 _priceUSD, uint256 _stock) public onlyOwner {
        s_products[nextProductId] = Product(nextProductId, _productDescription, _priceUSD, _stock);
        emit ProductAdded(nextProductId, _productDescription, _priceUSD, _stock);
        nextProductId++;
    }

    function updateProduct(uint256 _productId, string memory _productDescription, uint256 _priceUSD, uint256 _stock) public onlyOwner {
        if (_productId >= nextProductId) {
            revert ECommerceMock__ProductDoesNotExist();
        }
        s_products[_productId] = Product(_productId, _productDescription, _priceUSD, _stock);
        emit ProductUpdated(_productId, _productDescription, _priceUSD, _stock);
    }

    function removeProduct(uint256 _productId) public onlyOwner {
        if (_productId >= nextProductId) {
            revert ECommerceMock__ProductDoesNotExist();
        }
        delete s_products[_productId];
        emit ProductRemoved(_productId);
    }

    function purchaseProductWithSLCToken(uint256 _productId, uint256 _quantity, string memory _shippingAddress) public nonReentrant {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert ECommerceMock__AddressNotAuthenticated();
        }
        Product memory product = s_products[_productId];
        if (product.id != _productId) {
            revert ECommerceMock__ProductDoesNotExist();
        }
        if (product.stock < _quantity) {
            revert ECommerceMock__NotEnoughStock();
        }
        // require(product.id == _productId, "Product does not exist");
        // require(product.stock >= _quantity, "Not enough stock");
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);
        uint256 totalPriceUSD = product.priceUSD.mul(_quantity);
        uint256 totalPriceSLC = totalPriceUSD * conversionFactor * PRECISION;

        // Transfer ISH tokens to the owner
        bool success = slcToken.transferFrom(msg.sender, owner(), totalPriceSLC);

        if (!success) {
            revert ECommerceMock__SLCTokenTransferFailed();
        }

        s_products[_productId].stock = s_products[_productId].stock.sub(_quantity);
        emit ProductPurchasedInSLC(sanctumLinkIdentity, msg.sender, _productId, _quantity, totalPriceUSD, totalPriceSLC);
        generatePaymentId(_productId, _quantity, totalPriceUSD, _shippingAddress);
    }

    function purchaseProductWithNativeToken(uint256 _productId, uint256 _quantity, string memory _shippingAddress) public payable {
        if (!createAndAuthenticateSanctumLinkIdentity.isAuthenticated(msg.sender)) {
            revert ECommerceMock__AddressNotAuthenticated();
        }
        Product memory product = s_products[_productId];
        if (product.id != _productId) {
            revert ECommerceMock__ProductDoesNotExist();
        }
        if (product.stock < _quantity) {
            revert ECommerceMock__NotEnoughStock();
        }

        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(msg.sender);
        uint256 totalPriceUSD = product.priceUSD.mul(_quantity);
        uint256 totalPriceNative = totalPriceUSD.getConversionRate();

        if (msg.value != totalPriceNative) {
            revert ECommerceMock__IncorrectPaymentAmount();
        }

        // payable(owner()).transfer(msg.value);
        (bool success, ) = owner().call{value: msg.value}("");
        if (!success) {
            revert ECommerceMock__NativeTokenTransferFailed();
        }

        s_products[_productId].stock = s_products[_productId].stock.sub(_quantity);

        emit ProductPurchasedInNative(sanctumLinkIdentity, msg.sender, _productId, _quantity, totalPriceUSD, totalPriceNative);
        generatePaymentId(_productId, _quantity, totalPriceUSD, _shippingAddress);
    }

    function generatePaymentId(uint256 _productId, uint256 _quantity, uint256 _totalPriceUSD, string memory _shippingAddress) internal returns (uint256 requestId) {
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

        ProductOrder memory productOrder;
        productOrder.buyer = msg.sender;
        productOrder.productId = _productId;
        productOrder.quantity = _quantity;
        productOrder.totalPriceUSD = _totalPriceUSD;
        productOrder.shippingAddress = _shippingAddress;

        s_productOrders[requestId] = productOrder;

        requestIds.push(requestId);
        emit RequestSent(requestId, numWords);
        return requestId;      
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].randomWords = _randomWords;
        lastRandomWords = _randomWords;

        uint256 paymentId = (lastRandomWords[0] % 100000);
        while (s_paymentIdGenerated[paymentId]) {
            paymentId = (uint256(keccak256(abi.encode(lastRandomWords[0], paymentId))) % 100000);
        }
        s_paymentIdGenerated[paymentId] = true;
        s_requests[_requestId].fulfilled = true; 
        emit RequestFulfilled(_requestId, _randomWords);
        s_productOrders[paymentId] = s_productOrders[_requestId];
        s_paymentIdToRequestId[_requestId] = paymentId;
        delete s_productOrders[_requestId];
        emit PaymentIdGenerated(paymentId);

        address buyer = s_productOrders[paymentId].buyer;
        bytes32 sanctumLinkIdentity = createAndAuthenticateSanctumLinkIdentity.s_sanctumLinkIdentityToConnectedWallet(buyer);
        s_sanctumLinkIdentityToPaymentId[paymentId] = sanctumLinkIdentity;
        emit ProductOrderPurchasedDetails(
            paymentId,
            sanctumLinkIdentity,
            buyer,
            s_productOrders[paymentId].productId,
            s_productOrders[paymentId].quantity,
            s_productOrders[paymentId].totalPriceUSD,
            s_productOrders[paymentId].shippingAddress,
            s_productOrders[paymentId].productDelivered
        );
        
    }

    function setUSDToISHConversionFactor(uint256 _conversionFactor) public onlyOwner {
        conversionFactor = _conversionFactor;
    }

    function setVRFSubscriptionId (uint64 _subId) public onlyOwner {
        s_vrfSubId = _subId;
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

}