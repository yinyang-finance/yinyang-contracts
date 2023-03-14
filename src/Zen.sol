// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import "solmate/auth/Owned.sol";
import "./ISwap.sol";
import "./TurnstileRegisterEntry.sol";

contract Zen is ERC20, ERC20Permit, ERC20Votes, Owned, TurnstileRegisterEntry {
    address public pair;

    constructor(
        address _owner
    )
        ERC20("Zen", "ZEN")
        ERC20Permit("Zen")
        Owned(_owner)
        TurnstileRegisterEntry()
    {}

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

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
