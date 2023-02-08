// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import "../src/YinYang.sol";
import "./SimpleERC20.sol";

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
}

contract YinYangTest is Test {
    YinYang public token;
    ERC20 public quote;
    uint16 transferFee = 700;
    IUniswapV2Factory factory =
        IUniswapV2Factory(address(0xE387067f12561e579C5f7d4294f51867E0c1cFba));
    address router = address(0xa252eEE9BDe830Ca4793F054B506587027825a8e);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("canto_mainnet"), 2863000);
    }

    function testTransfer(
        address sender,
        address recipient,
        uint256 transferAmount,
        bool excludeSender,
        bool excludeRecipient
    ) public {
        uint256 initialSupply = 10 ** 27;
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);
        vm.assume(sender != address(0));
        vm.assume(recipient != address(0));
        vm.assume(sender != recipient);

        quote = new SimpleERC20();
        token = new YinYang(
            address(this),
            "Yin",
            "YIN",
            700,
            router,
            address(quote),
            10 ** 19
        );
        token.excludeAccount(address(this));
        token.excludeAccount(sender);
        IBaseV1Factory(IBaseV1Router(router).factory()).createPair(
            address(token),
            address(quote),
            false
        );
        token.initialize(address(this), initialSupply);
        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);
        if (!excludeSender) {
            token.includeAccount(sender);
        }
        if (excludeRecipient) {
            token.excludeAccount(recipient);
        }

        vm.prank(sender);
        uint256 supplyBefore = token.totalSupply();
        token.transfer(recipient, transferAmount);

        assertGe(supplyBefore, token.totalSupply());
        assertGe(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount - (transferAmount * transferFee) / 10000
        );

        if (transferAmount >= 10 ** 21) {
            // Liquidity has been added
            assertGe(
                IBaseV1Pair(
                    IBaseV1Router(router).pairFor(
                        address(token),
                        address(quote),
                        false
                    )
                ).totalSupply(),
                0
            );
        }
    }
}
