// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    
    address public merchant;
    address public admin;
    uint256 public fees; // percentage
    uint256 public feesPaidBy; // 1 for buyer & 2 for merchant
    uint256 public tokenNumber=1;
    uint256 public orders=1;
    string public orderId;
    
    mapping(address => mapping(address => mapping(string => uint256))) public index;
    mapping(uint256 => mapping(uint256 => uint256)) public amount;
    mapping(address => uint256) public token;
    
    event newOrder (string orderId, uint256 price);
    event Token (address token, uint256 tokenNumber);

    constructor(address _admin, uint256 _fees, uint256 _feesPaidBy) {
        admin = _admin;
        fees = _fees;
        feesPaidBy = _feesPaidBy;
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
    function createOrderbyToken(address _token, string memory _orderId, uint256 _orderAmount) external {
        require(token[_token] != 0, "This token or orderID is not supported");     
        
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR : can't transfer");
        
        index[msg.sender][_token][_orderId] = orders;
        amount[_orderAmount][_orderAmount*fees/100] = orders;
        emit newOrder (_orderId, orders);
        orders++;
    }
    function createOrder(string memory _orderId) external payable {
        index[msg.sender][address(0)][_orderId] = orders;
        amount[msg.value][msg.value*fees/100] = orders;
        emit newOrder (_orderId, orders);        
        orders++;
    }
    function cancelOrder(uint256 _index) external {
    }
    function claimOrder(uint256 _index) external onlyMerchant {
    }
    function getBalance(address _adreess) public view returns (uint256) {
        return _adreess.balance;
    }
}
