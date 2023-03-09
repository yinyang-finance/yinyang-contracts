// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/TurnstileRegisterEntry.sol";

contract BaseTest is Test {
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;
    address router = address(0x9B2920e72dF6E1A7053bEa7235c65079F5104398); // Velocimeter

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("test_canto"));
    }
}
