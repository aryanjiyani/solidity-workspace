// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

// mapping(0 => 0xdAC17F958D2ee523a2206206994597C13D831ec7) public USDT;
// mapping(1 => 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) public WBTC;
// mapping(2 => 0x4f3AfEC4E5a3F2A6a1A411DEF7D7dFe50eE057bF) public DGX;
// mapping(3 => 0xFA1a856Cfa3409CFa145Fa4e20Eb270dF3EB21ab) public IOST;
// mapping(4 => 0x514910771AF9Ca656af840dff83E8264EcF986CA) public LINK;
// mapping(5 => 0xB8c77482e45F1F44dE1745F52C74426C631bDD52) public BNB;

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

    mapping(uint256 => address) public token;
    uint256 public tokenNumber;

    struct Order {
        address buyer;
        uint256 price;
        uint256 fees;
        // uint256 merchantId;
        uint256 currency;
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
        token[tokenNumber] = _token;
        tokenNumber++;
    }
    function doApprove(uint256 _amount, uint256 _tokenNumber) external returns(bool) {
        require(_tokenNumber < tokenNumber, "This token is not supported");
        
        uint256 _val = IERC20(token[_tokenNumber]).balanceOf(msg.sender);
        require(_val >= _amount, "You have not enough balance");
        
        bool _success = IERC20(token[_tokenNumber]).approve(address(this), _amount);
        return _success;
    }
    function getBalance(address _adreess) public view returns (uint256) {
        return _adreess.balance;
    }

// For Other TOKENs
    function createOrderbyToken(uint256 _tokenNumber) external {
        require(_tokenNumber < tokenNumber, "This token is not supported");

        uint256 _allowedValue = IERC20(token[_tokenNumber]).allowance(msg.sender, address(this));
        require(_allowedValue >= 0, "You have not Allowed yet");

        bool _success = IERC20(token[_tokenNumber]).transferFrom(msg.sender, address(this), _allowedValue);
        require(_success==true, "Transaction is not done yet");

        Order storage newOrder = orders[orderId];
        newOrder.buyer = msg.sender;
        newOrder.price = _allowedValue;
        newOrder.fees = _allowedValue/100;
        newOrder.currency = _tokenNumber;
        newOrder.status = false;
        
        emit FreshOrder(orderId, _allowedValue, msg.sender);
        orderId++;
    }
// For ETH only
    function createOrder() external payable {
        
        Order storage newOrder = orders[orderId];
        newOrder.buyer = msg.sender;
        newOrder.price = msg.value;
        newOrder.fees = msg.value/100;
        newOrder.currency = tokenNumber;
        newOrder.status = false;

        emit FreshOrder(orderId, msg.value, msg.sender);
        orderId++;
    }


    function claim(uint256 _orderId) external onlyMerchant {
        require(_orderId < orderId, "This Order does not exist");
        Order storage thisOrder = orders[_orderId];

        require (thisOrder.status==false && thisOrder.price > 0, "This order is already canceles or claimed");
        uint256 toMerchant = thisOrder.price - thisOrder.fees;

        if(thisOrder.currency < tokenNumber) {
            bool toMerch = IERC20(token[tokenNumber]).transfer(merchant,toMerchant);
            bool toAdmin = IERC20(token[tokenNumber]).transfer(admin,thisOrder.fees);
            if(toMerch && toAdmin){
                thisOrder.status=true;
            }
            else {
                thisOrder.status=false;
            }
        }
        else if(thisOrder.currency==tokenNumber) {
            address payable seller = payable(merchant);
            seller.transfer(toMerchant);
            address payable boss = payable(admin);
            boss.transfer(thisOrder.fees);

            thisOrder.status=true;
        }
    }
    
    function cancelOrder(uint256 _orderId) external {
        require(_orderId < orderId, "This Order does not exist");
        Order storage thisOrder = orders[_orderId];

        require(thisOrder.status==false,"This order is already completed or claimed");
        require(msg.sender==merchant || msg.sender==thisOrder.buyer, "You are not able to cacel order");
        
        uint256 toBuyer = thisOrder.price - thisOrder.fees;
        if(thisOrder.currency < tokenNumber) {
            if(msg.sender == merchant) {
                bool toUser = IERC20(token[tokenNumber]).transfer(thisOrder.buyer, thisOrder.price);
                if(toUser){
                    thisOrder.status=true;
                }
                else{
                    thisOrder.status=false;
                }
            }
            else {
                bool toUser = IERC20(token[tokenNumber]).transfer(thisOrder.buyer, toBuyer);
                bool toAdmin = IERC20(token[tokenNumber]).transfer(admin,thisOrder.fees);
                if(toUser && toAdmin){
                    thisOrder.status=true;
                }
                else{
                    thisOrder.status=false;
                }
            }
        }
        else if(thisOrder.currency==tokenNumber) {
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
        }
    }
}
