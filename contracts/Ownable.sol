// SPDX-License-Identifier: MIT

// Functions define by this contract
// a) Able to assert that a person is the owner of the smart contract
// b) Able to non-owners from calling a function

pragma solidity ^0.8.21;

// This contract provides basic contract ownership functions
abstract contract Ownable {

    //Address of the contract owner
    address payable private _owner;

    constructor() {
        _owner = payable(msg.sender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Only the Contract Owner can call.");
        _;
    }
}