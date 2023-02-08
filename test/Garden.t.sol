// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Garden.sol";

contract GardenTest is Test {
    Garden public garden;

    function setUp() public {
        garden = new Garden(address(this));
        garden.setNumber(0);
    }

    function testIncrement() public {
        garden.increment();
        assertEq(garden.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        garden.setNumber(x);
        assertEq(garden.number(), x);
    }
}
