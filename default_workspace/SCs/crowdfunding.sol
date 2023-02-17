// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

contract Crowdfunding {
    mapping(address=>uint) public contributors;
    address public manager;
    uint public minContribution;
    uint public target;
    uint public deadline;
    uint public raisedAmount;
    uint public totcontributors;

    struct Request {
        string description;
        address payable recipient;
        uint value;
        bool completed;
        uint totVoters;
        mapping(address=>bool) voters;
    }
    mapping(uint=>Request) public request;
    uint public numRequestes;
    
    constructor(uint _target, uint _deadline) {
        target=_target;
        deadline=block.timestamp+_deadline;
        minContribution=100 wei;
        manager=msg.sender;
    }
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    modifier checkTime() {
        require(block.timestamp<deadline, "You have missed the time");
        _;}
    modifier checkVal() {
        require(msg.value >= minContribution, "Minimum contribution is not met");
        _;}
    modifier timeToRefund() {
        require(block.timestamp>deadline && raisedAmount<target, "You are not able take refund");
        _;}
    modifier timeToPay() {
        require(block.timestamp>deadline && raisedAmount>=target, "Funds are still coming..");
        _;}
    modifier onlyManager() {
        require(msg.sender==manager, "Only manager can call this function");
        _;}
    modifier checkCont() {
        require(contributors[msg.sender]>0, "You are not contributor..");
        _;}

    function sendEth() public payable checkTime checkVal {
        if(contributors[msg.sender]==0) {
            totcontributors++;
        }
        contributors[msg.sender]+=msg.value;
        raisedAmount+=msg.value;
    }
    function refund() public timeToRefund {
        require(contributors[msg.sender]>0);
        address payable user=payable(msg.sender);
        user.transfer(contributors[msg.sender]);
        contributors[msg.sender]=0;
    }
    function createRequests(string memory _description, address payable _recipients, uint _value) public onlyManager {
        Request storage newRequest = request[numRequestes];
        numRequestes++;
        newRequest.description=_description;
        newRequest.recipient=_recipients;
        newRequest.value=_value;
        newRequest.completed=false;
        newRequest.totVoters=0;
    }
    function voteRequest(uint _requestNo) public checkCont {
        Request storage thisRequest=request[_requestNo];
        require(thisRequest.voters[msg.sender]==false,"You have already voted..");
        thisRequest.voters[msg.sender]=true;
        thisRequest.totVoters++;
    }

    function makePay(uint _requestNo) public onlyManager timeToPay {
        Request storage thisRequest=request[_requestNo];

        require(thisRequest.completed==false, "The request has been completed");
        require(thisRequest.totVoters > totcontributors/2, "Majority does not support");
        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed=true;
    }
}
