// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IWCanto {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}

interface IBaseV1Pair {
    function totalSupply() external returns (uint256);

    function token0() external returns (address);

    function token1() external returns (address);

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
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
}
