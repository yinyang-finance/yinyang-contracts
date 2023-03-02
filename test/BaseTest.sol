// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/TurnstileRegisterEntry.sol";

contract BaseTest is Test {
    // address router = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Ethereum
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("test_canto"));
        // vm.mockCall(
        //     TURNSTILE,
        //     abi.encodeWithSelector(Turnstile.register.selector, address(1)),
        //     0
        // );
    }
}
