// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/LiquidityAdder.sol";
import "./SimpleERC20.sol";

contract LiquidityAdderTest is Test {
    LiquidityAdder public adder;
    ERC20 public quote;
    ERC20 public token;
    uint16 transferFee = 700;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("canto_mainnet"));
    }

    function testLiquidityAdderAddLiquidity(uint256 amount) public {
        vm.assume(amount > 10 ** 5);
        vm.assume(amount < 10 ** 25);

        quote = new SimpleERC20();
        token = new SimpleERC20();
        quote.approve(router, ~uint(0));
        token.approve(router, ~uint(0));
        IBaseV1Router(router).addLiquidity(
            address(token),
            address(quote),
            false,
            10 ** 18,
            10 ** 18,
            0,
            0,
            address(this),
            block.timestamp + 360
        );
        adder = new LiquidityAdder(
            router,
            IBaseV1Router(router).pairFor(
                address(quote),
                address(token),
                false
            ),
            address(token),
            address(quote)
        );

        token.transfer(address(adder), amount);
        (uint256 r0before, uint256 r1before, ) = IBaseV1Pair(
            IBaseV1Router(router).pairFor(address(quote), address(token), false)
        ).getReserves();

        adder.addLiquidity();

        (uint256 r0after, uint256 r1after, ) = IBaseV1Pair(
            IBaseV1Router(router).pairFor(address(quote), address(token), false)
        ).getReserves();

        if (uint160(address(quote)) > uint160(address(token))) {
            assertGe(r0after, r0before);
            assertLe(r1after, r1before);
        } else {
            assertLe(r0after, r0before);
            assertGe(r1after, r1before);
        }
    }
}
