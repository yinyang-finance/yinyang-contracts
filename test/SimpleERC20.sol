// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";

contract SimpleERC20 is ERC20 {
    constructor() ERC20("Test", "TEST", 18) {
        _mint(msg.sender, 10 ** 27);
    }
}
