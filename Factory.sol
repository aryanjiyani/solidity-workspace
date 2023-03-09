// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;
import "./Ecommerce.sol";
contract Factory {
    Ecommerce public Ecommerce1;
    function createSeller(address _Affiliator, uint256 _fees, uint256 _feesPaidBy) public returns(Ecommerce) {
        Ecommerce1 = new Ecommerce(_Affiliator, _fees, _feesPaidBy);
        return Ecommerce1;
    }
}
