// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    constructor() Ownable(address(msg.sender)) {}

    uint256 private s_number;

    event NumberChanged(uint256 number);

    function store(uint256 number) public onlyOwner {
        s_number = number;
        emit NumberChanged(number);
    }

    function getNumber() external view returns (uint256) {
        return s_number;
    }
}
