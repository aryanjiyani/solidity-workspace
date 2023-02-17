// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract demo {
    // State Variable
    uint age;
    uint public count;

    // Local Variable
    function store() pure public returns(uint){
        uint year=2002;
        return year; 
    }

    constructor(uint new_count) 
    {
        count = new_count;
    }

    mapping(uint=>string) public roll_no;

    function setter(uint no, string memory name) public {
        roll_no[no]=name;
    }
}