// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Eefr {

    event log(string _fun, address _sender, uint _val, bytes _data);

    fallback() external payable {
        emit log("fallback", msg.sender, msg.value, msg.data);
    }

    receive() external payable {
        emit log("receive", msg.sender, msg.value, " ");
    }

    function checkBal() public view returns(uint) {
        return address(this).balance;
    } 
}