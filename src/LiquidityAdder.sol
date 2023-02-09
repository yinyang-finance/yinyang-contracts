// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import "./TurnstileRegisterEntry.sol";

interface IBaseV1Pair {
    function totalSupply() external returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );
}

interface IBaseV1Router {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function factory() external returns (address);

    function note() external returns (address);

    function wcanto() external returns (address);

    function pairFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external;
}

interface IBaseV1Factory {
    function allPairsLength() external view returns (uint);

    function isPair(address pair) external view returns (bool);

    function pairCodeHash() external pure returns (bytes32);

    function getPair(
        address tokenA,
        address token,
        bool stable
    ) external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address);
}

contract LiquidityAdder is TurnstileRegisterEntry {
    IBaseV1Router public router;
    IBaseV1Pair public pair;
    ERC20 public token;
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
        token = ERC20(_token);
        quote = ERC20(_quote);
        token.approve(_router, ~uint(0));
        quote.approve(_router, ~uint(0));
    }

    function addLiquidity() public {
        uint256 adderTokenBalance = token.balanceOf(address(this));

        if (!inSwapAndLiquify && pair.totalSupply() > 0) {
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

            console.log(quote.balanceOf(address(this)), adderTokenBalance);
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
