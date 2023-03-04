// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "./ISwap.sol";

contract Router {
    IBaseV1Router public immutable router;

    constructor(address _router) {
        router = IBaseV1Router(_router);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address input,
        address output,
        uint256 amount
    ) public {
        IBaseV1Pair pair = IBaseV1Pair(router.pairFor(input, output, false));
        ERC20(input).transfer(address(pair), amount);

        (address token0, ) = router.sortTokens(input, output);
        uint amountInput;
        uint amountOutput;
        {
            // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1, ) = pair.getReserves();
            (uint reserveInput, ) = input == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);
            amountInput = ERC20(input).balanceOf(address(pair)) - reserveInput;
            (amountOutput, ) = router.getAmountOut(amountInput, input, output);
        }
        (uint amount0Out, uint amount1Out) = input == token0
            ? (uint(0), amountOutput)
            : (amountOutput, uint(0));
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
}
