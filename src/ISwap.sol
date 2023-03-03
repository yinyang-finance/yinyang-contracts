// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";

interface IWCanto {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}

interface IBaseV1Pair {
    function totalSupply() external returns (uint256);

    function metadata()
        external
        view
        returns (
            uint dec0,
            uint dec1,
            uint r0,
            uint r1,
            bool st,
            address t0,
            address t1
        );

    function claimFees() external returns (uint, uint);

    function tokens() external returns (address, address);

    function transferFrom(
        address src,
        address dst,
        uint amount
    ) external returns (bool);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function burn(address to) external returns (uint amount0, uint amount1);

    function mint(address to) external returns (uint liquidity);

    function getReserves()
        external
        view
        returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);

    function getAmountOut(uint, address) external view returns (uint);

    function sync() external;
}

interface IBaseV1Router {
    function factory() external pure returns (address);

    function weth() external pure returns (address);

    function pairFor(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (address pair);

    function sortTokens(
        address tokenA,
        address tokenB
    ) external pure returns (address token0, address token1);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount, bool stable);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external;
}

interface IBaseV1Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

library Router {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        address input,
        address output,
        uint256 amount
    ) public {
        IBaseV1Pair pair = IBaseV1Pair(
            IBaseV1Router(router).pairFor(input, output, false)
        );
        ERC20(input).transferFrom(address(this), address(pair), amount);

        (address token0, ) = IBaseV1Router(router).sortTokens(input, output);
        uint amountInput;
        uint amountOutput;
        {
            // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1, ) = pair.getReserves();
            (uint reserveInput, ) = input == token0
                ? (reserve0, reserve1)
                : (reserve1, reserve0);
            amountInput = ERC20(input).balanceOf(address(pair)) - reserveInput;
            (amountOutput, ) = IBaseV1Router(router).getAmountOut(
                amountInput,
                input,
                output
            );
        }
        (uint amount0Out, uint amount1Out) = input == token0
            ? (uint(0), amountOutput)
            : (amountOutput, uint(0));
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));
    }
}
