// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface Turnstile {
    function register(address) external returns (uint256);
}

contract TurnstileRegisterEntry {
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;
    uint256 immutable turnstileTokenId;

    constructor() {
        turnstileTokenId = Turnstile(TURNSTILE).register(tx.origin);
    }
}
