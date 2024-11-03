// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    /*
    * @param minDelay is how long you have to wait before executing a proposal
    * @param proposers list of addresses that can propose a new proposal
    * @param executors list of addresses that can execute a proposal
    * @param admin admin
    */
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
