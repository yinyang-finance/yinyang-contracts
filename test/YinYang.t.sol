// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import "../src/YinYang.sol";
import "./SimpleERC20.sol";

contract YinYangTest is Test {
    YinYang public token;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address sender = address(42);
    address recipient = address(43);
    address temple = address(44);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));
    }

    function testYinYangTransfer(
        uint256 transferAmount,
        bool excludeSender,
        bool excludeRecipient
    ) public {
        uint256 initialSupply = 10 ** 27;
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);

        // Mint the initial supply
        quote = new SimpleERC20();
        token = new YinYang(
            address(this),
            "Yin",
            "YIN",
            transferFee,
            router,
            address(quote),
            thresholdAmount
        );
        token.excludeAccount(address(this));
        token.excludeAccount(sender);
        token.initialize(address(this), initialSupply);
        token.excludeAccount(temple);
        token.setTemple(temple);
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

        assertEq(
            token.balanceOf(temple),
            (transferAmount * transferFee) / 30000
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * (transferFee / 6)) / 10000
        );
        assertGe(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount - (transferAmount * transferFee) / 10000
        );

        if ((transferAmount * transferFee) / 10000 >= thresholdAmount) {
            // Liquidity has been added
            assertGe(
                IBaseV1Pair(
                    IBaseV1Factory(IBaseV1Router(router).factory()).getPair(
                        address(token),
                        address(quote)
                    )
                ).totalSupply(),
                0
            );
        }
    }
}
