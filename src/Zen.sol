// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "./ISwap.sol";
import "./TurnstileRegisterEntry.sol";

contract Zen is ERC20, Owned, TurnstileRegisterEntry {
    address public pair;

    constructor(
        address _owner
    ) ERC20("Zen", "ZEN", 18) Owned(_owner) TurnstileRegisterEntry() {}

    function setPairs(address router) external onlyOwner {
        address wcanto = IBaseV1Router(router).weth();

        pair = IBaseV1Factory(IBaseV1Router(router).factory()).createPair(
            address(this),
            wcanto,
            false
        );
    }

    function mintTo(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
