// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;

contract Array
{
    // Fixed size array
    uint[4] public arr=[10,20,30,40];

    function setter(uint index, uint value) public 
    {
        arr[index]=value;
    }

    // Dynamic array
    uint[] public arr2;

    function pushElement(uint item) public 
    {
        arr2.push(item);
    }
    function length() public view returns(uint)
    {
        return arr2.length;
    }
    function popElement() public
    {
        // It'll remove last element of array
        arr2.pop();
    }

    // Bytes Array (Fixed size)
    bytes3 public b3; 
    bytes2 public b2;

    function set() public
    {
        b2='ab';
        b3='abc';
        // b3[0]='d'; can't do because bytes array is immutable
    }

    // Bytes Array (Dynamic)
    bytes public b1='abc';

    function push() public 
    {
        b1.push('d');
    } 
    function get(uint i) public view returns(bytes1) // How many bytes you want to return...?
    {
        return b1[i];
    }

}