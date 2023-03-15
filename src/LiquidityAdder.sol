// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";
import "./TurnstileRegisterEntry.sol";
import "./ISwap.sol";
import "./Router.sol";

contract LiquidityAdder is TurnstileRegisterEntry, Router {
    IBaseV1Pair public pair;
    IERC20 public token;
    IERC20 public quote;
    uint256 public minimumTokenToSell;
    bool private initialized = false;
    bool private inSwapAndLiquify = false;

    event AddedLiquidity(uint256 toSwap, uint256 firstHalf, uint256 otherHalf);

    constructor(
        address _router,
        address _pair,
        address _token,
        address _quote
    ) TurnstileRegisterEntry() Router(_router) {
        pair = IBaseV1Pair(_pair);
        token = IERC20(_token);
        quote = IERC20(_quote);
        token.approve(_router, ~uint(0));
        quote.approve(_router, ~uint(0));
    }

    function addLiquidity(address to) public {
        uint256 adderTokenBalance = token.balanceOf(address(this));

        if (
            !inSwapAndLiquify && pair.totalSupply() > 0 && adderTokenBalance > 0
        ) {
            inSwapAndLiquify = true;

            // Sell half for some base coins
            // A bit more to account for slippage
            uint256 tokenAmountToBeSwapped = (adderTokenBalance * 535) / 1000;
            uint256 otherHalf = adderTokenBalance - tokenAmountToBeSwapped;
            address[] memory routes = new address[](2);
            routes[0] = address(token);
            routes[1] = address(quote);

            swapExactTokensForTokensSupportingFeeOnTransferTokens(
                address(token),
                address(quote),
                tokenAmountToBeSwapped
            );

            uint256 newBalance = quote.balanceOf(address(this));

            pair.sync();
            router.addLiquidity(
                address(token),
                address(quote),
                false,
                otherHalf,
                newBalance,
                0,
                0,
                to,
                block.timestamp + 360
            );

            emit AddedLiquidity(tokenAmountToBeSwapped, newBalance, otherHalf);

            inSwapAndLiquify = false;
        }
    }
}
