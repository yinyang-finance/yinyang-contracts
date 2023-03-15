// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../src/LiquidityAdder.sol";
import "./SimpleERC20.sol";

contract LiquidityAdderTest is BaseTest {
    LiquidityAdder public adder;
    ERC20 public quote;
    ERC20 public token;
    uint16 transferFee = 700;

    function setUp() public override {
        super.setUp();
    }

    function testLiquidityAdderAddLiquidity(uint256 amount) public {
        vm.assume(amount > 10 ** 5);
        vm.assume(amount < 10 ** 27);

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

        adder.addLiquidity(address(this));

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
