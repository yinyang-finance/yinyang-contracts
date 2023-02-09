// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "./LiquidityAdder.sol";
import "forge-std/console.sol";

interface Turnstile {
    function register(address) external returns (uint256);
}

contract TurnstileRegisterEntry {
    Turnstile public turnstile =
        Turnstile(address(0xEcf044C5B4b867CFda001101c617eCd347095B44));
    address public dev = address(0x7F63Cc4Bc0a0Ef44214e183D7EdfBA62ff8De930);

    constructor() {
        console.log(turnstile.register(dev));
    }
}
