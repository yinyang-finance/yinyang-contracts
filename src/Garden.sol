// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "solmate/auth/Owned.sol";

/// @author Dodecahedr0x
/// @title The Garden of YinYang
/// @notice This contract manages collected fees
contract Garden is Owned {
    uint256 public number;

    constructor(address _owner) Owned(_owner) {}

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
