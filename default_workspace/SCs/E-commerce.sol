// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract Ecommerce {
    
    address public merchant;
    address public admin;
    uint256 public paidBy; // 1 for buyer & 2 for merchant
    mapping(address => uint256) public token;
    uint256 public tokenNumber=1;
    struct Order {
        address buyer;
        uint256 price;
        uint256 fees;
        address currency;
        bool status;
    }
    mapping(uint256 => Order) public orders;
    uint256 public orderId;
    
    event Ordered (uint256 orderId, uint256 price, address buyer);
    event Token (address token, uint256 tokenNumber);
    event Claimed (uint256 orderId, uint256 price, bool status);
    event Canceled (uint256 orderId, uint256 price, bool status);
    
    // Remove the struct and try to depend on one variable for mitigate th usage of gas
    
    constructor(address _admin, uint256 _paidBy) {
        admin = _admin;
        paidBy = _paidBy;
        merchant = msg.sender;
    }
    modifier onlyMerchant() {
        require(msg.sender == merchant, "You are not merchant");
        _;
    }
    
    function addCurrency(address _token) external onlyMerchant{
        token[_token] = tokenNumber;
        emit Token (_token, tokenNumber);
        tokenNumber++;
    }
    function delCurrency(address _token) external onlyMerchant {
        token[_token] = 0;
        emit Token (_token, token[_token]);
    }

// For Other TOKENs
    function createOrderbyToken(address _token, uint256 _orderId) external {
        require(token[_token] != 0, "This token is not supported");
        require(orders[_orderId].price == 0, "This orderId is already taken");

        uint256 _allowedValue = IERC20(_token).allowance(msg.sender, address(this));
        require(_allowedValue >= 0, "You have not Allowed yet");

        Order storage newOrder = orders[_orderId];
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _allowedValue));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");

        newOrder.buyer = msg.sender;
        newOrder.price = _allowedValue;
        newOrder.fees = _allowedValue/100;
        newOrder.currency = _token;
        newOrder.status = false;
        emit Ordered(_orderId, _allowedValue, msg.sender);
    }
// For ETH only
    function createOrder(uint256 _orderId) external payable {
        require(orders[_orderId].price == 0, "This orderId is already taken");
        Order storage newOrder = orders[_orderId];
        newOrder.buyer = msg.sender;
        newOrder.price = msg.value;
        newOrder.fees = msg.value/100;
        newOrder.currency = address(0);
        newOrder.status = false;

        emit Ordered(_orderId, msg.value, msg.sender);
        
    }

    function claim(uint256 _orderId) external onlyMerchant {

        require(orders[_orderId].price != 0 , "This Order does not exist");
        Order storage thisOrder = orders[_orderId];

        require (thisOrder.status==false, "This order is already canceles or claimed");
        uint256 toMerchant = thisOrder.price - thisOrder.fees;

        if(token[thisOrder.currency] != 0) {
            (bool success, bytes memory data) = thisOrder.currency.call(abi.encodeWithSignature("transfer(address,uint256)", merchant, toMerchant));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");
            (bool cool, bytes memory info) = thisOrder.currency.call(abi.encodeWithSignature("transfer(address,uint256)", admin, thisOrder.fees));
            require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR : can't transfer");
            thisOrder.status=true;
            emit Claimed (_orderId, thisOrder.price, thisOrder.status);
        }else if(thisOrder.currency == address(0)) {
            address payable seller = payable(merchant);
            seller.transfer(toMerchant);
            address payable boss = payable(admin);
            boss.transfer(thisOrder.fees);
            thisOrder.status=true;
            emit Claimed (_orderId, thisOrder.price, thisOrder.status);
        }else {
            revert("Invalid order");
        }
    }
    
    function cancelOrder(uint256 _orderId) external {

        require(orders[_orderId].price != 0 , "This Order does not exist");
        Order storage thisOrder = orders[_orderId];

        require(msg.sender==merchant || msg.sender==thisOrder.buyer, "You are not able to cacel order");
        require(thisOrder.status==false,"This order is already completed or claimed");
        
        uint256 toBuyer = thisOrder.price - thisOrder.fees;
        if(token[thisOrder.currency] != 0) {
            if(msg.sender == merchant) {
                (bool success, bytes memory data) = thisOrder.currency.call(abi.encodeWithSignature("transfer(address,uint256)", thisOrder.buyer, thisOrder.price));
                require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");
                thisOrder.status=true;
                emit Canceled (_orderId, thisOrder.price, thisOrder.status);
            }
            else {
                (bool success, bytes memory data) = thisOrder.currency.call(abi.encodeWithSignature("transfer(address,uint256)", thisOrder.buyer, toBuyer));
                require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");
                (bool cool, bytes memory info) = thisOrder.currency.call(abi.encodeWithSignature("transfer(address,uint256)", admin, thisOrder.fees));
                require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR : can't transfer");
                thisOrder.status=true;
                emit Canceled (_orderId, thisOrder.price, thisOrder.status);
            }
        }else if(thisOrder.currency == address(0)) {
            address payable user = payable(thisOrder.buyer);
            if(msg.sender == merchant) {
                user.transfer(thisOrder.price);
                thisOrder.status=true;
                emit Canceled (_orderId, thisOrder.price, thisOrder.status);
            }
            else {
                address payable boss = payable(admin);
                user.transfer(toBuyer);
                boss.transfer(thisOrder.fees);
                thisOrder.status=true;
                emit Canceled (_orderId, thisOrder.price, thisOrder.status);
            }
        }else {
            revert ("invalid order");
        }
    }
    function getBalance(address _adreess) public view returns (uint256) {
        return _adreess.balance;
    }
}
