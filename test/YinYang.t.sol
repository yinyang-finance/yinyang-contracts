// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import "../src/YinYang.sol";
import "./SimpleERC20.sol";
import "./BaseTest.sol";

contract YinYangTest is BaseTest {
    YinYang public token;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    // address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address sender = address(42);
    address recipient = address(43);
    address temple = address(44);
    uint256 initialSupply = 10 ** 27;

    function setUp() public override {
        super.setUp();

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
    }

    function testYinYangTransferFromExcludedToIncluded(
        uint256 transferAmount
    ) public {
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);

        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);

        uint256 supplyBefore = token.totalSupply();
        vm.prank(sender);
        token.transfer(recipient, transferAmount);

        assertLe(
            token.balanceOf(temple),
            (transferAmount * 2 * transferFee) / 50000
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * (transferFee / 5)) / 10000
        );
        assertEq(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount - (transferAmount * transferFee) / 10000
        );

        if ((transferAmount * transferFee) / 10000 >= thresholdAmount) {
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

    function testYinYangTransferFromIncludedToIncluded(
        uint256 transferAmount
    ) public {
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);

        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);

        token.includeAccount(sender);

        uint256 supplyBefore = token.totalSupply();
        vm.prank(sender);
        token.transfer(recipient, transferAmount);

        assertLe(
            token.balanceOf(temple),
            (transferAmount * 2 * transferFee) / 50000
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * (transferFee / 5)) / 10000
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

    function testYinYangTransferFromIncludedToExcluded(
        uint256 transferAmount
    ) public {
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);

        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);

        token.includeAccount(sender);
        token.excludeAccount(recipient);

        uint256 supplyBefore = token.totalSupply();
        vm.prank(sender);
        token.transfer(recipient, transferAmount);

        assertLe(
            token.balanceOf(temple),
            (transferAmount * 2 * transferFee) / 50000
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * (transferFee / 5)) / 10000
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

    function testYinYangTransferFromExcludedToExcluded(
        uint256 transferAmount
    ) public {
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount < initialSupply / 2);

        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);
        token.excludeAccount(recipient);

        uint256 supplyBefore = token.totalSupply();
        vm.prank(sender);
        token.transfer(recipient, transferAmount);

        assertEq(token.balanceOf(temple), 0);
        assertLe(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(sender), 0);
        assertEq(token.balanceOf(recipient), transferAmount);

        if ((transferAmount * transferFee) / 10000 >= thresholdAmount) {
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
