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
    IBaseV1Factory factory =
        IBaseV1Factory(address(0xE387067f12561e579C5f7d4294f51867E0c1cFba));
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);

    function setUp() public {
        // vm.createSelectFork(vm.rpcUrl("canto_mainnet"));
    }

    function testAddLiquidity(uint256 amount) public {
        vm.assume(amount > 10 ** 5);
        vm.assume(amount < 10 ** 25);

        quote = new SimpleERC20();
        token = new SimpleERC20();
        quote.approve(router, ~uint(0));
        token.approve(router, ~uint(0));
        IBaseV1Router(router).addLiquidity(
            address(token),
            address(quote),
            10 ** 18,
            10 ** 18,
            0,
            0,
            address(this),
            block.timestamp + 360
        );
        adder = new LiquidityAdder(
            router,
            IBaseV1Factory(IBaseV1Router(router).factory()).getPair(
                address(quote),
                address(token)
            ),
            address(token),
            address(quote)
        );

        token.transfer(address(adder), amount);
        (uint112 r0before, uint112 r1before, ) = IBaseV1Pair(
            IBaseV1Factory(IBaseV1Router(router).factory()).getPair(
                address(quote),
                address(token)
            )
        ).getReserves();

        adder.addLiquidity();

        (uint112 r0after, uint112 r1after, ) = IBaseV1Pair(
            IBaseV1Factory(IBaseV1Router(router).factory()).getPair(
                address(quote),
                address(token)
            )
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
