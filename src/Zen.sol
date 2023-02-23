// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "./LiquidityAdder.sol";
import "./TurnstileRegisterEntry.sol";

contract Zen is ERC20, Owned, TurnstileRegisterEntry {
    address public zenWCantoPair;
    address public zenNotePair;

    constructor(
        address _owner
    ) ERC20("Zen", "ZEN", 18) Owned(_owner) TurnstileRegisterEntry() {}

    function setPairs(address router, address _note) external onlyOwner {
        address note = _note;
        address wcanto = IBaseV1Router(router).WETH();

        zenWCantoPair = IBaseV1Factory(IBaseV1Router(router).factory())
            .createPair(address(this), wcanto);
        zenNotePair = IBaseV1Factory(IBaseV1Router(router).factory())
            .createPair(address(this), note);
    }

    function mintTo(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
