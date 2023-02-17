// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract Memsto
{
    string[] public action=["Hide","Or","Die"];

    function mem() public view
    {
        string[] memory a1=action;
        a1[0]="Do";
    }
    function sto() public
    {
        string[] storage a1=action;
        a1[0]="Do";
    }
}