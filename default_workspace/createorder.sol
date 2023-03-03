// Version 1

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    
    address public merchant;
    mapping(address => uint256) public token;
    uint256 public tokenNumber=1;
    struct Order {
        address buyer;
        uint256 price;
        uint256 charge;
        address currency;
        uint256 status;
    }
    mapping(string => Order) public orders;
    string public orderId;
    uint256 public numOrders;
    
    event newOrder (string orderId, uint256 price);
    
    function addCurrency(address _token) external onlyMerchant{
        token[_token] = tokenNumber;
        emit Token (_token, tokenNumber);
        tokenNumber++;
    }
    function createOrderbyToken(address _token, uint256 _orderAmount, string memory _orderId) external {
        require(token[_token] != 0 && orders[_orderId].price == 0, "This token or orderID is not supported");        
        Order storage thisOrder = orders[_orderId];

        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");

        thisOrder.buyer = msg.sender;
        thisOrder.price = _orderAmount;
        thisOrder.charge = _orderAmount*0.05;
        thisOrder.currency = _token;
        thisOrder.status = 1;
        numOrders++;

        emit newOrder (_orderId, _orderAmount);
    }
}


// Version 2
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    
    address public merchant;
    address public admin;
    uint256 public fees=5;
    mapping(address => uint256) public token;
    uint256 public tokenNumber=1;
    struct Order {
        uint256 price;
        uint256 charge;
        uint256 status;
    }
    mapping(uint256 => Order) public orders;
    mapping(address => mapping(address => mapping(string => uint256))) public index;
    string public orderId;
    uint256 public numOrders=1;
    
    event newOrder (string orderId, uint256 price);
    constructor (address _admin) {
        admin = _admin;
        merchant = msg.sender;
    }
    modifier onlyMerchant() {
        require(msg.sender == merchant, "You are not merchant");
        _;
    }
    function addCurrency(address _token) external onlyMerchant{
        token[_token] = tokenNumber;
        tokenNumber++;
    }
    function createOrderbyToken(address _token, string memory _orderId, uint256 _orderAmount) external {
        require(token[_token] != 0, "This token or orderID is not supported");     
        index[msg.sender][_token][_orderId] = numOrders;
        Order storage thisOrder = orders[numOrders];

        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");

        thisOrder.price = _orderAmount;
        thisOrder.charge = _orderAmount*fees/100;
        emit newOrder (_orderId, _orderAmount);
        numOrders++; 
    }
}

// Version 3 (best)

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    
    address public merchant;
    address public admin;
    uint256 public fees=5;
    uint256 public tokenNumber=1;
    string public orderId;
    uint256 public numOrders=1;
    
    mapping(address => uint256) public token;
    mapping(uint256 => mapping(uint256 => uint256)) public orders;
    mapping(address => mapping(address => mapping(string => uint256))) public index;
    
    event newOrder (string orderId, uint256 price);
    constructor (address _admin) {
        admin = _admin;
        merchant = msg.sender;
    }
    modifier onlyMerchant() {
        require(msg.sender == merchant, "You are not merchant");
        _;
    }
    function addCurrency(address _token) external onlyMerchant{
        token[_token] = tokenNumber;
        tokenNumber++;
    }
    function createOrderbyToken(address _token, string memory _orderId, uint256 _orderAmount) external {
        require(token[_token] != 0, "This token or orderID is not supported");     
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");
        
        index[msg.sender][_token][_orderId] = numOrders;
        orders[_orderAmount][_orderAmount*fees/100] = numOrders;
        emit newOrder (_orderId, numOrders);
        numOrders++;
    }
}
