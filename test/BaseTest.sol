// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/TurnstileRegisterEntry.sol";

contract BaseTest is Test {
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;
    address router = address(0x8e2e2f70B4bD86F82539187A634FB832398cc771); // Velocimeter

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("test_canto"));
    }
}
