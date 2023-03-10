    // SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Ecommerce {
    address public seller; // Deployer
    address public admin; // superAdmin (default)
    address public affiliator; // previous seller
    uint256 public fees; // in percentage
    uint256 public affiliationFees; // in percentage
    uint256 public feesPaidBy; // 1-buyer & 2-seller
    enum Status {
        NotExist, Initiated, 
        CancelbySeller, CancelbyBuyer,
        ConfirmBySeller, ConfirmedByBuyer, 
        inDelivery, Delivered,
        SettlementRequestedByBuyer, SettlementRequestedBySeller,
        SettlementRejectByBuyer, SettlementRejectBySeller, 
        InspectionRequested, inInspection, InspectionExtended,
        Settled, Locked, Completed,     
        ClaimedBySeller, ClaimedByAdmin
    }
    struct Order {
        address buyer;
        uint256 price;
    }
    mapping(address => mapping(bytes32 => Order)) public orders;
    mapping(bytes32 => Status) public status;
    bytes32 public orderId;
    mapping(address => bool) public supportedTokens;
    event newOrder(bytes32 orderId);
    
    constructor(address _admin, address _Affiliator, uint256 _fees,uint256 _affiliationFees, uint256 _feesPaidBy) {
        admin = _admin;
        affiliator = _Affiliator;
        fees = _fees;
        affiliationFees = _affiliationFees;
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
    modifier onlyBuyer() {
        require(msg.sender != seller, "You are seller");
        _;
    }
    function addSupportedToken(address _token) external onlySeller {
        supportedTokens[_token] = true;
    }
    function removeSupportedToken(address _token) external onlySeller {
        supportedTokens[_token] = false;
    }
    
    function createOrderbyToken(address _token,bytes32 _orderId, uint256 _orderAmount) external {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",
        msg.sender, address(this), _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");

        require(orders[_token][_orderId].buyer == address(0), "This orderId is already used");

        orders[_token][_orderId] = Order({
            buyer: msg.sender,
            price: _orderAmount
        });
        status[_orderId] = Status.Initiated;
        emit newOrder(_orderId);
    }
    function createOrder(bytes32 _orderId) external payable {
        require(orders[address(0)][_orderId].buyer == address(0), "This orderId is already used");

        orders[address(0)][_orderId] = Order({
            buyer: msg.sender,
            price: msg.value
        });
        status[_orderId] = Status.Initiated;
        emit newOrder(_orderId);
    }
    
    
    function cancelOrderbyToken(address _token, bytes32 _orderId) external {
        if(msg.sender == seller) {
            require(status[_orderId] == Status.Initiated, "This order can not be caneled");

            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            orders[_token][_orderId].buyer, orders[_token][_orderId].price));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");
            status[_orderId] = Status.CancelbySeller;
        }else {
            require(orders[_token][_orderId].buyer == msg.sender && status[_orderId] == Status.Initiated, "This orderId is already used");
            
            uint256 charge = orders[_token][_orderId].price - (orders[_token][_orderId].price * fees / 100);
            uint256 toBuyer = orders[_token][_orderId].price - charge;
            uint256 toAffiliater = charge - (charge * affiliationFees / 100);

            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            msg.sender, toBuyer));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");

            (bool cool, bytes memory info) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            admin, charge - toAffiliater));
            require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR: can't transfer");

            (bool fool, bytes memory fnfo) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            affiliator, toAffiliater));
            require(fool && (fnfo.length == 0 || abi.decode(fnfo, (bool))), "ERROR: can't transfer");

            status[_orderId] = Status.CancelbyBuyer;
        }
    }
    function cancelOrder(bytes32 _orderId) external {
        if(msg.sender == seller) {
            require(status[_orderId] == Status.Initiated, "This order can not be caneled");
            address payable user = payable(orders[address(0)][_orderId].buyer);
            user.transfer(orders[address(0)][_orderId].price);

            status[_orderId] = Status.CancelbySeller;
        }else {
            require(orders[address(0)][_orderId].buyer == msg.sender && status[_orderId] == Status.Initiated, "This orderId is already used");
            uint256 charge = orders[address(0)][_orderId].price - (orders[address(0)][_orderId].price * fees / 100);
            uint256 toBuyer = orders[address(0)][_orderId].price - charge;
            uint256 toAffiliater = charge - (charge * affiliationFees / 100);

            address payable user = payable(orders[address(0)][_orderId].buyer);
            address payable boss = payable(admin);
            address payable commision = payable(affiliator);

            user.transfer(toBuyer);
            boss.transfer(charge - toAffiliater);
            commision.transfer(toAffiliater);

            status[_orderId] = Status.CancelbyBuyer;
        }
    }

    function ConfirmOrder(address _token, bytes32 _orderId) external onlySeller  {
        status[_orderId] = Status.inDelivery;
    }
    
    function settlementByByer(address _token, bytes32 _orderId) external onlyBuyer {
        require(status[_orderId] == Status.Initiated);
        
        status[_orderId] = Status.SettlementRequestedByBuyer;
    }

    function settlementBySeller(address _token, bytes32 _orderId) external  onlySeller {
        require(status[_orderId] == Status.Initiated);
        
        status[_orderId] = Status.SettlementRequestedBySeller;
    }

    function inspectionStart(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.Delivered);
        
        status[_orderId] = Status.inInspection;
    }

    function extendInspection(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.inInspection);
        
        status[_orderId] = Status.InspectionExtended;
    }

    function requestExtension(address _token, bytes32 _orderId) external onlyBuyer {
        require(status[_orderId] == Status.inInspection);
        
        status[_orderId] = Status.InspectionRequested;
    }

    function approveExtension(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.inInspection);
        
        status[_orderId] = Status.InspectionExtended;
    }

    function approveByBuyer(address _token, bytes32 _orderId) external onlyBuyer {
        require(status[_orderId] == Status.SettlementRequestedBySeller);
        
        status[_orderId] = Status.Settled;
    }

    function rejectByBuyer(address _token, bytes32 _orderId) external onlyBuyer {
        require(status[_orderId] == Status.SettlementRequestedBySeller);
        
        status[_orderId] = Status.SettlementRejectByBuyer;
    }

    function approveBySeller(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.SettlementRequestedByBuyer);
        
        status[_orderId] = Status.Settled;
    }

    function rejectBySeller(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.SettlementRequestedByBuyer);
        
        status[_orderId] = Status.SettlementRejectBySeller;
    }
    

    function claimOrder(address _token, bytes32 _orderId) external onlySeller {
        require(status[_orderId] == Status.Initiated, "This order can not be caneled");
        if(supportedTokens[_token]) {

            uint256 charge = orders[_token][_orderId].price - (orders[_token][_orderId].price * fees / 100);
            uint256 toAffiliater = charge - (charge * affiliationFees / 100);

            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            seller, orders[_token][_orderId].price - charge));
            require(success && (data.length == 0 || abi.decode(data, (bool))), "ERROR: can't transfer");

            (bool cool, bytes memory info) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            admin, charge));
            require(cool && (info.length == 0 || abi.decode(info, (bool))), "ERROR: can't transfer");

            (bool fool, bytes memory fnfo) = _token.call(abi.encodeWithSignature("transfer(address,uint256)",
            affiliator, toAffiliater));
            require(fool && (fnfo.length == 0 || abi.decode(fnfo, (bool))), "ERROR: can't transfer");

            status[_orderId] = Status.ClaimedBySeller;
        }else if(_token == address(0)) {

            uint256 charge = orders[address(0)][_orderId].price - (orders[address(0)][_orderId].price * fees / 100);
            uint256 toAffiliater = charge - (charge * affiliationFees / 100);

            address payable merchant = payable(seller);
            address payable boss = payable(admin);
            address payable commision = payable(affiliator);

            merchant.transfer(orders[address(0)][_orderId].price - charge);
            boss.transfer(charge - toAffiliater);
            commision.transfer(toAffiliater);
            status[_orderId] = Status.ClaimedBySeller;
        }
    }
}
