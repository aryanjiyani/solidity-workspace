// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    address public seller;
    address public admin;
    uint256 public fees;
    uint256 public feesPaidBy;
    enum Status {
        NotExist, 
        Initiated, 
        CancelbySeller, 
        CancelbyBuyer,
        Claimed
    }
    struct Order {
        address buyer;
        uint256 price;
        uint256 charge;
    }
    mapping(address => mapping(bytes32 => Order)) public orders;
    mapping(bytes32 => Status) public order_status;
    bytes32 public orderId;
    mapping(address => bool) public supportedTokens;
    event newOrder(bytes32 orderId);

    constructor(address _Affiliator, uint256 _fees, uint256 _feesPaidBy) {
        admin = _Affiliator;
        fees = _fees;
        feesPaidBy = _feesPaidBy;
        seller = msg.sender;
    }
    modifier onlySeller() {
        require(msg.sender == seller, "You are not seller");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "You are not admin");
        _;
    }
    function addSupportedToken(address _token) external onlyAdmin {
        supportedTokens[_token] = true;
    }
    function removeSupportedToken(address _token) external onlyAdmin {
        supportedTokens[_token] = false;
    }

    function createOrderbyToken(address _token,bytes32 _orderId, uint256 _orderAmount) external {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",
        msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");

        require(orders[_token][_orderId].buyer == address(0), "This orderId is already used");

        orders[_token][_orderId] = Order({
            buyer: msg.sender,
            price: _orderAmount,
            charge: _orderAmount * fees / 100
        });
        order_status[_orderId] = Status.Initiated;
        emit newOrder(_orderId);
    }
    function createOrder(bytes32 _orderId) external payable {
        require(orders[address(0)][_orderId].buyer == address(0), "This orderId is already used");

        orders[address(0)][_orderId] = Order({
            buyer: msg.sender,
            price: msg.value,
            charge: msg.value * fees / 100
        });
        order_status[_orderId] = Status.Initiated;
        emit newOrder(_orderId);
    }

    function cancelOrderbyToken(address _token, bytes32 _orderId) external {
        if(msg.sender == seller) {
            require(order_status[_orderId] == Status.Initiated, "This order can not be caneled");

            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            msg.sender, orders[_token][_orderId].price));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");
           order_status[_orderId] = Status.CancelbySeller;
        }else {
            require(orders[_token][_orderId].buyer == msg.sender && order_status[_orderId] == Status.Initiated, "This orderId is already used");

            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",
            address(this), msg.sender, orders[_token][_orderId].price - orders[_token][_orderId].charge));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");
            (bool cool, bytes memory info) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            admin, orders[_token][_orderId].charge));
            require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR: can't transfer");

            order_status[_orderId] = Status.CancelbyBuyer;
        }
    }
    function cancelOrder(bytes32 _orderId) external {
        if(msg.sender == seller) {
            require(order_status[_orderId] == Status.Initiated, "This order can not be caneled");
            address payable user = payable(orders[address(0)][_orderId].buyer);
            user.transfer(orders[address(0)][_orderId].price);

            order_status[_orderId] = Status.CancelbySeller;
        }else {
            require(orders[address(0)][_orderId].buyer == msg.sender && order_status[_orderId] == Status.Initiated, "This orderId is already used");
            address payable user = payable(orders[address(0)][_orderId].buyer);
            user.transfer(orders[address(0)][_orderId].price - orders[address(0)][_orderId].charge);

            order_status[_orderId] = Status.CancelbyBuyer;
        }
    }
    function claimOrder(address _token, bytes32 _orderId) external onlySeller {
        require(order_status[_orderId] == Status.Initiated, "This order can not be caneled");
        if(supportedTokens[_token]) {
            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            seller, orders[_token][_orderId].price - orders[_token][_orderId].charge));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");
            (bool cool, bytes memory info) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            admin, orders[_token][_orderId].charge));
            require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR: can't transfer");

            order_status[_orderId] = Status.Claimed;
        }else if(_token == address(0)) {
            address payable merchant = payable(seller);
            address payable superAdmin = payable(admin);
            merchant.transfer(orders[address(0)][_orderId].price-orders[address(0)][_orderId].charge);
            superAdmin.transfer(orders[address(0)][_orderId].charge);

            order_status[_orderId] = Status.Claimed;
        }
    }
    function finalClaim() external onlyAdmin {
        address payable superAdmin = payable(admin);
        superAdmin.transfer(address(this).balance);
    }
}
