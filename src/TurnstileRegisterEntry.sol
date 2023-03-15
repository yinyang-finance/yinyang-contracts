// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC721/IERC721.sol";

interface Turnstile is IERC721 {
    function register(address) external returns (uint256);

    function balances(uint256) external returns (uint256);

    function withdraw(uint256, address, uint256) external returns (uint256);

    function getTokenId(address) external returns (uint256);
}

contract TurnstileRegisterEntry {
    address constant TURNSTILE = 0xEcf044C5B4b867CFda001101c617eCd347095B44;

    constructor() {
        Turnstile(TURNSTILE).register(tx.origin);
    }
}
