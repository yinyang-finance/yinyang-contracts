// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "./ReflectToken.sol";
import "./TurnstileRegisterEntry.sol";
import "./ISwap.sol";

contract LiquidityAdder is TurnstileRegisterEntry {
    IBaseV1Router public router;
    IBaseV1Pair public pair;
    ReflectToken public token;
    ERC20 public quote;
    uint256 public minimumTokenToSell;
    bool private initialized = false;
    bool private inSwapAndLiquify = false;

    event AddedLiquidity(uint256 toSwap, uint256 firstHalf, uint256 otherHalf);

    constructor(
        address _router,
        address _pair,
        address _token,
        address _quote
    ) TurnstileRegisterEntry() {
        router = IBaseV1Router(_router);
        pair = IBaseV1Pair(_pair);
        token = ReflectToken(_token);
        quote = ERC20(_quote);
        token.approve(_router, ~uint(0));
        quote.approve(_router, ~uint(0));
    }

    function addLiquidity() public {
        uint256 adderTokenBalance = token.balanceOf(address(this));

        if (
            !inSwapAndLiquify && pair.totalSupply() > 0 && adderTokenBalance > 0
        ) {
            inSwapAndLiquify = true;

            // Sell half for some base coins
            // A bit more to account for slippage
            uint256 tokenAmountToBeSwapped = (adderTokenBalance * 535) / 1000;
            uint256 otherHalf = adderTokenBalance - tokenAmountToBeSwapped;
            IBaseV1Router.route[] memory routes = new IBaseV1Router.route[](1);
            routes[0].from = address(token);
            routes[0].to = address(quote);
            routes[0].stable = false;

            router.swapExactTokensForTokens(
                tokenAmountToBeSwapped,
                0,
                routes,
                address(this),
                block.timestamp + 360
            );

            uint256 newBalance = quote.balanceOf(address(this));

            router.addLiquidity(
                address(token),
                address(quote),
                false,
                otherHalf,
                newBalance,
                0,
                0,
                address(this),
                block.timestamp + 360
            );

            emit AddedLiquidity(tokenAmountToBeSwapped, newBalance, otherHalf);

            inSwapAndLiquify = false;
        }
    }
}
