// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";
import "./LiquidityAdder.sol";

contract Zen is ERC20, Owned {
    address public zenWCantoPair;
    address public zenNotePair;

    constructor(
        address router,
        address _owner
    ) ERC20("Zen", "ZEN", 18) Owned(_owner) {
        address note = IBaseV1Router(router).note();
        address wcanto = IBaseV1Router(router).wcanto();

        zenWCantoPair = IBaseV1Factory(IBaseV1Router(router).factory())
            .createPair(address(this), wcanto, false);
        zenNotePair = IBaseV1Factory(IBaseV1Router(router).factory())
            .createPair(address(this), note, false);
    }

    function mintTo(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}
