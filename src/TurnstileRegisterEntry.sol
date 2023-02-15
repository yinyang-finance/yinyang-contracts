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
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;

    constructor() {
        Turnstile(TURNSTILE).register(tx.origin);
    }
}
