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
    
    event FreshOrder (uint256 orderId, uint256 price, address buyer);
    
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
        tokenNumber++;
    }
    function delCurrency(address _token) external onlyMerchant {
        token[_token] = 0;
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
        
        emit FreshOrder(_orderId, _allowedValue, msg.sender);

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

        emit FreshOrder(_orderId, msg.value, msg.sender);
        
    }

    function claim(uint256 _orderId) external onlyMerchant {

        require(orders[_orderId].price != 0 , "This Order does not exist");
        Order storage thisOrder = orders[_orderId];

        require (thisOrder.status==false, "This order is already canceles or claimed");
        uint256 toMerchant = thisOrder.price - thisOrder.fees;

        if(token[thisOrder.currency] != 0) {
            bool toMerch = IERC20(thisOrder.currency).transfer(merchant,toMerchant);
            bool toAdmin = IERC20(thisOrder.currency).transfer(admin,thisOrder.fees);
            if(toMerch && toAdmin){
                thisOrder.status=true;
            }
            else {
                revert ("invalid order");
            }
        }
        else if(thisOrder.currency == address(0)) {
            address payable seller = payable(merchant);
            seller.transfer(toMerchant);
            address payable boss = payable(admin);
            boss.transfer(thisOrder.fees);

            thisOrder.status=true;
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
                bool toUser = IERC20(thisOrder.currency).transfer(thisOrder.buyer, thisOrder.price);
                if(toUser){
                    thisOrder.status=true;
                }
                else{
                    revert ("invalid order");
                }
            }
            else {
                bool toUser = IERC20(thisOrder.currency).transfer(thisOrder.buyer, toBuyer);
                bool toAdmin = IERC20(thisOrder.currency).transfer(admin,thisOrder.fees);
                if(toUser && toAdmin){
                    thisOrder.status=true;
                }
                else{
                    revert ("invalid order");
                }
            }
        }
        else if(thisOrder.currency == address(0)) {
            address payable user = payable(thisOrder.buyer);
            if(msg.sender == merchant) {
                user.transfer(thisOrder.price);
                thisOrder.status=true;
            }
            else {
                address payable boss = payable(admin);
                user.transfer(toBuyer);
                boss.transfer(thisOrder.fees);
                thisOrder.status=true;
            }
        }else {
            revert ("invalid order");
        }
    }
    function getBalance(address _adreess) public view returns (uint256) {
        return _adreess.balance;
    }
}
