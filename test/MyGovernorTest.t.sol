// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    GovToken token;
    TimeLock timelock;
    Box box;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    address[] public proposers;
    address[] public executors;

    uint256[] public values;
    bytes[] public callData;
    address[] public targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after proposal is created to execute
    uint256 public constant VOTING_DELAY = 1; // 1 block till voting starts
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    function setUp() public {
        token = new GovToken();
        token.mint(USER, INITIAL_SUPPLY); // mint some tokens to USER

        vm.startPrank(USER); // pretend to be USER cause only USER can delegate
        token.delegate(USER); // delegate all votes to USER

        timelock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(token, timelock);

        bytes32 proposalRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposalRole, address(governor)); // only governor can propose
        timelock.grantRole(executorRole, address(0)); // only governor can execute
        timelock.revokeRole(adminRole, USER); // User will no longer be admin, meaning will no longer be able to change timelock settings
        vm.stopPrank(); // stop pretending to be USER

        box = new Box();
        box.transferOwnership(address(timelock)); // transfer ownership to timelock and not governor (very important)
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 888 in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        callData.push(encodedFunctionCall);
        values.push(0);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, callData, description);

        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1); // warp to next block
        vm.roll(block.number + VOTING_DELAY + 1); // roll to next block
        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "cuz Hossam Elanany is cool";
        uint8 voteWay = 1; // 0 = Against, 1 = For, 2 = Abstain for this example
        vm.prank(USER); // pretend to be USER
        governor.castVoteWithReason(proposalId, voteWay, reason); // we are the only voter so it will pass

        vm.warp(block.timestamp + VOTING_PERIOD + 1); // warp to next block
        vm.roll(block.number + VOTING_PERIOD + 1); // roll to next block

        console.log("Proposal state: ", uint256(governor.state(proposalId)));

        // 3. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, callData, descriptionHash);
        vm.roll(block.number + MIN_DELAY + 1); // roll to next block
        vm.warp(block.timestamp + MIN_DELAY + 1); // warp to next block

        // 4. Execute
        governor.execute(targets, values, callData, descriptionHash);

        // 5. Check if the box has been updated
        uint256 storedValue = box.getNumber();
        assertEq(storedValue, valueToStore);
        console.log("Stored value: ", storedValue);
    }
}
