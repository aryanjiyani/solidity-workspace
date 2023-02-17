// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract Enum 
{
    enum user{yes,no,wait}

    user public u1= user.yes;
    uint public reward=1000;

    function owner() public
    {
        if(u1 == user.yes)
        {
            reward=0;
        }
    }
    function changeOwner() public
    {
        u1=user.wait;
    }
}