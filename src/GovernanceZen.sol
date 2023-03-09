// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin/token/ERC20/extensions/ERC20Wrapper.sol";
import "./TurnstileRegisterEntry.sol";

contract GovernanceZen is
    ERC20,
    ERC20Permit,
    ERC20Votes,
    ERC20Wrapper,
    TurnstileRegisterEntry
{
    constructor(
        IERC20 wrappedToken
    )
        ERC20("Governance Zen", "gZEN")
        ERC20Permit("Governance Zen")
        ERC20Wrapper(wrappedToken)
    {}

    function decimals()
        public
        view
        override(ERC20, ERC20Wrapper)
        returns (uint8)
    {
        return super.decimals();
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
