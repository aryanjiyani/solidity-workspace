// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Escrow {
    address public admin; // Deployer
    address public superAdmin; // default from Factory
    address public arbitrator; // default from Factory
    address public affiliator; // default from Factorty
    uint256 public OneMinSec; // calcuted one day seconds
    enum Status {
        Initiated,
        Canceled,
        Delivered,
        Completed,
        ExtendedRequest,
        InspectionExtended,
        SettlementRequested,
        Settled,
        Arbitrator,
        Claimed
    }
    struct Order {
        address buyer;
        address token;
        uint256 amount;
        uint256 confirmOrderTime;
        Status status;
    }
    struct Token {
        uint256 trx_fees;
        uint256 aff_fees;
        bool status;
    }
    struct Settlement {
        uint256 percentage;
        bool settlementBy;
        uint256 RequestTime;
    }
    
    mapping(uint256 => Order) public orders;
    mapping(address => Token) public tokens;

    mapping(uint256 => Settlement) public settlementReq;
    event newOrder(uint256 orderId);
    uint256 public orderId;
    uint256 WithdrawalPeriod;
    uint256 EstDelivery;
    uint256 InspPeriod;
    uint256 InspExtperiod;
    uint256 ReqRepPeriod;

    constructor(
        address _admin,
        address _Affiliator,
        address _Arbitrator,
        uint256 _WithdrawalPeriod,
        uint256 _EstDelivery,
        uint256 _InspPeriod,
        uint256 _IEperiod
    ) {
        superAdmin = _admin;
        affiliator = _Affiliator;
        arbitrator = _Arbitrator;
        admin = msg.sender;
        WithdrawalPeriod = _WithdrawalPeriod;
        EstDelivery = _EstDelivery;
        InspPeriod = _InspPeriod;
        InspExtperiod = _IEperiod;
        OneMinSec = 60; // seconds
    }

    modifier onlySeller() {
        require(msg.sender == admin, "You are not seller");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == superAdmin, "You are not admin");
        _;
    }
    modifier ValidToken(address _token) {
        require (tokens[_token].status==true, "Invalid Token");
        _;
    }
    modifier ValidOrder(uint256 _orderId) {
        require(orders[_orderId].buyer == address(0),  "This order is taken");
        _;
    }
    modifier onlyBuyer(uint256 _orderId) {
        require(orders[_orderId].buyer == msg.sender, "You are not Buyer of this order");
        _;
    }

    function addSupportedToken(address _token) external onlySeller {
        tokens[_token] = Token({
            trx_fees: 1,
            aff_fees: 30,
            status: true
        });
    }
    function removeSupportedToken(address _token) external onlySeller {
        tokens[_token] = Token({
            trx_fees: 1,
            aff_fees: 30,
            status: false
        });
    }

    function createOrderbyToken(address _token,uint256 _orderId,uint256 _orderAmount) 
    external ValidOrder(_orderId) ValidToken(_token) {
        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                msg.sender,
                address(this),
                _orderAmount));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
        orders[_orderId] = Order({
            buyer: msg.sender,
            token: _token,
            amount: _orderAmount,
            confirmOrderTime: 0,
            status: Status.Initiated
        });
        emit newOrder(_orderId);
    }
    function createOrder(uint256 _orderId) external ValidOrder(_orderId) payable {
        require(orders[_orderId].buyer == address(0),"This orderId is already used");
        orders[_orderId] = Order({
            buyer: msg.sender,
            token: address(0),
            amount: msg.value,
            confirmOrderTime: 0,
            status: Status.Initiated
        });
        emit newOrder(_orderId);
    }

    function cancelOrderbyToken(uint256 _orderId) external {
        if(orders[_orderId].token == address(0)) {
            if (msg.sender == admin) {
                address payable user = payable(orders[_orderId].buyer);
                    user.transfer(orders[_orderId].amount);
                    orders[_orderId].status = Status.Canceled;
            } else if (
                orders[_orderId].buyer == msg.sender &&
                orders[_orderId].status == Status.Initiated
            ) {
                address payable user = payable(orders[_orderId].buyer);
                user.transfer(orders[_orderId].amount);
                orders[_orderId].status = Status.Canceled;
            } else {
                revert("forbiden");
            }
        } else if(tokens[orders[_orderId].token].status) {
            if (msg.sender == admin) {
                (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                        "transfer(address,uint256)",
                        orders[_orderId].buyer,
                        orders[_orderId].amount));
                require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
                orders[_orderId].status = Status.Canceled;
            } else if (
                orders[_orderId].buyer == msg.sender &&
                orders[_orderId].status == Status.Initiated) {
                (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                        "transfer(address,uint256)",
                        orders[_orderId].buyer,
                        orders[_orderId].amount));
                require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
                orders[_orderId].status = Status.Canceled;
            } else {
            revert("forbiden");
            }
        }else {
            revert("fprbidden");
        }
    }

    function settlementRequest(uint256 _orderId, uint256 _percentage) external {
        if (msg.sender == admin) {
            settlementReq[_orderId] = Settlement({
                percentage: _percentage,
                settlementBy: true,
                RequestTime: block.timestamp
            });
            orders[_orderId].status = Status.SettlementRequested;
        } else if (orders[_orderId].buyer == msg.sender) {
            settlementReq[_orderId] = Settlement({
                percentage: _percentage,
                settlementBy: false,
                RequestTime: block.timestamp
            });
            orders[_orderId].status = Status.SettlementRequested;
        } else {
            revert("forbidden");
        }
    }

    function approveByBuyer(uint256 _orderId) external onlyBuyer (_orderId) {
        require(settlementReq[_orderId].settlementBy == true);
        uint256 refund = (orders[_orderId].amount * settlementReq[_orderId].percentage) / 100;
        (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                refund));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
        (bool adSuccess, bytes memory adData) = orders[_orderId].token.call(abi.encodeWithSignature(
                "transfer(address,uint256)",
                admin,
                orders[_orderId].amount - refund));
        require(adSuccess && (adData.length == 0 || abi.decode(adData, (bool))),"ERROR: can't transfer");
        orders[_orderId].status = Status.Settled;
    }
    function approveBySeller(uint256 _orderId) external onlySeller {
        require(settlementReq[_orderId].settlementBy == false);
        uint256 refund = (orders[_orderId].amount * settlementReq[_orderId].percentage) / 100;
        (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                "transfer(address,uint256)",
                msg.sender,
                refund));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
        (bool adSuccess, bytes memory adData) = orders[_orderId].token.call(abi.encodeWithSignature(
                "transfer(address,uint256)",
                admin,
                orders[_orderId].amount - refund));
        require(adSuccess && (adData.length == 0 || abi.decode(adData, (bool))),"ERROR: can't transfer");
        orders[_orderId].status = Status.Settled;
    }

    function rejectByBuyer(uint256 _orderId) external onlyBuyer(_orderId) {
        require(settlementReq[_orderId].settlementBy == true);
        orders[_orderId].status = Status.Initiated;
    }
    function rejectBySeller(uint256 _orderId) external onlySeller {
        require(settlementReq[_orderId].settlementBy == false);
        orders[_orderId].status = Status.Initiated;
    }
    function requestExtension(uint256 _orderId) external onlyBuyer(_orderId) {
        orders[_orderId].status = Status.ExtendedRequest;
    }

    function approveExtension(uint256 _orderId) external onlySeller {
        require(orders[_orderId].status == Status.ExtendedRequest, "There is no request of extension");
        orders[_orderId].status = Status.InspectionExtended;
    }
    function extendInspection(uint256 _orderId) external onlySeller {
        require(block.timestamp >=
                orders[_orderId].confirmOrderTime +
                    (OneMinSec * EstDelivery) +
                    (OneMinSec * InspPeriod),
                "in inspection");
        orders[_orderId].status = Status.InspectionExtended;
    }

    function claimOrder(uint256 _orderId) external onlySeller {
        require(orders[_orderId].status == Status.Completed, "This order can not be caneled");
        if (tokens[orders[_orderId].token].status) {
            // uint256 charge = orders[_orderId].amount - (orders[_orderId].amount / (1+fees/100)); 
            // uint256 toAffiliater = charge - ((charge * affiliationFees) / 100);
            uint256 charge = orders[_orderId].amount - ((orders[_orderId].amount * tokens[orders[_orderId].token].trx_fees) / 100);
            uint256 toAffiliater = charge - ((charge * tokens[orders[_orderId].token].aff_fees) / 100);
            (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    admin,
                    orders[_orderId].amount - charge));
            require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
            (bool cool, bytes memory info) = orders[_orderId].token.call(abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    superAdmin,
                    charge));
            require(cool && (info.length == 0 || abi.decode(info, (bool))),"ERROR: can't transfer");
            (bool fool, bytes memory fnfo) = orders[_orderId].token.call(abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    affiliator,
                    toAffiliater));
            require(fool && (fnfo.length == 0 || abi.decode(fnfo, (bool))),"ERROR: can't transfer");
            orders[_orderId].status = Status.Claimed;
        } else if (orders[_orderId].token == address(0)) {
            uint256 charge = orders[_orderId].amount - ((orders[_orderId].amount * tokens[orders[_orderId].token].trx_fees) / 100);
            uint256 toAffiliater = charge - ((charge * tokens[orders[_orderId].token].aff_fees) / 100);

            address payable seller = payable(admin);
            address payable Admin = payable(superAdmin);
            address payable commision = payable(affiliator);

            seller.transfer(orders[_orderId].amount - charge);
            Admin.transfer(charge - toAffiliater);
            commision.transfer(toAffiliater);
            orders[_orderId].status = Status.Claimed;
        }
    }

    function finalClaim(uint256 _orderId) external onlyAdmin {
        require(orders[_orderId].status == Status.Completed);
        if (orders[_orderId].token == address(0)) {
            address payable Admin = payable(superAdmin);
            Admin.transfer(orders[_orderId].amount);
        } else {
            (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    superAdmin,
                    orders[_orderId].amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
        }
    }

    function toArbitrator(uint256 _orderId) public {
        require(msg.sender == admin && msg.sender == orders[_orderId].buyer);
        if (orders[_orderId].token == address(0)) {
            address payable Arbitrator = payable(superAdmin);
            Arbitrator.transfer(orders[_orderId].amount);
        } else {
            (bool success, bytes memory data) = orders[_orderId].token.call(abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    arbitrator,
                    orders[_orderId].amount));
            require(success && (data.length == 0 || abi.decode(data, (bool))),"ERROR: can't transfer");
        }
    }
}
