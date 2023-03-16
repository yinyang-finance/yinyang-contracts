// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../src/YinYang.sol";
import "./SimpleERC20.sol";
import "./BaseTest.sol";

contract YinYangTest is BaseTest {
    YinYang public token;
    ERC20 public quote;
    uint16 transferFee = 500;
    uint256 thresholdAmount = 10 ** 19;
    // address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address sender = address(42);
    address recipient = address(43);
    address temple = address(44);
    uint256 initialSupply = 10 ** 27;
    uint16 burnBP = 2000;
    uint16 liquidityBP = 2000;
    uint16 templeBP = 4000;

    function setUp() public override {
        super.setUp();

        // Mint the initial supply
        quote = ERC20(IBaseV1Router(router).weth());
        token = new YinYang(
            address(this),
            "Yin",
            "YIN",
            transferFee,
            router,
            address(quote),
            thresholdAmount,
            burnBP,
            liquidityBP,
            templeBP
        );
        token.initialize(address(this), initialSupply);
        token.excludeAccount(sender);
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
            (transferAmount * transferFee * templeBP) / 1e8
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * transferFee * burnBP) / 1e8
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

        assertGe(
            token.balanceOf(temple),
            (transferAmount * transferFee * templeBP) / 1e8 - 1
        );
        assertGe(
            token.totalSupply(),
            supplyBefore - (transferAmount * transferFee * burnBP) / 1e8 - 1
        );
        assertGe(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount -
                (transferAmount *
                    transferFee *
                    (10000 - burnBP + liquidityBP + templeBP)) /
                1e8
        );

        if (
            (transferAmount * transferFee * liquidityBP) / 1e8 >=
            thresholdAmount
        ) {
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
            (transferAmount * transferFee * templeBP) / 1e8
        );
        assertLe(
            token.totalSupply(),
            supplyBefore - (transferAmount * transferFee * burnBP) / 1e8
        );
        assertGe(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount - (transferAmount * transferFee) / 10000
        );

        if (
            (transferAmount * transferFee * liquidityBP) / 1e8 >=
            thresholdAmount
        ) {
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

        if (
            (transferAmount * transferFee * liquidityBP) / 1e8 >=
            thresholdAmount
        ) {
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

    function testYinYangPingPong(
        uint256 transferAmount,
        uint8 exchanges
    ) public {
        vm.assume(transferAmount >= transferFee);
        vm.assume(transferAmount > thresholdAmount);
        vm.assume(transferAmount < initialSupply / 2);

        ERC20 wcanto = ERC20(IBaseV1Router(router).weth());
        vm.deal(address(this), 10 ** 24);
        IWCanto(address(wcanto)).deposit{value: 10 ** 19}();
        wcanto.approve(address(router), type(uint256).max);
        token.approve(address(router), type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(token),
            address(wcanto),
            false,
            initialSupply / 2,
            10 ** 18,
            0,
            0,
            address(this),
            block.timestamp + 360
        );

        token.includeAccount(sender);
        token.transfer(sender, transferAmount);

        for (uint8 i = 0; i < exchanges; i++) {
            address _sender = (i % 2) == 0 ? sender : recipient;
            address _recipient = (i % 2) == 1 ? sender : recipient;
            uint256 templeBalance = token.balanceOf(temple);
            uint256 senderBalance = token.balanceOf(_sender);
            uint256 supplyBefore = token.totalSupply();
            uint256 liquidityBefore = IBaseV1Pair(token.pair()).totalSupply();

            vm.prank(_sender);
            token.transfer(_recipient, senderBalance);

            assertGe(
                token.balanceOf(temple),
                templeBalance +
                    (senderBalance * transferFee * templeBP) /
                    1e8 -
                    1
            );
            console.log(senderBalance);
            console.log(supplyBefore);
            console.log(
                transferFee,
                burnBP,
                senderBalance,
                (senderBalance * uint256(transferFee) * uint256(burnBP)) / 1e8
            );
            assertLe(
                token.balanceOf(_sender),
                (senderBalance *
                    transferFee *
                    (10000 - burnBP - liquidityBP - templeBP)) / 1e8
            );
            assertLe(
                token.totalSupply(),
                supplyBefore -
                    ((senderBalance * uint256(transferFee) * uint256(burnBP)) /
                        1e8) +
                    1
            );
            assertGe(
                token.balanceOf(_recipient),
                senderBalance - (senderBalance * transferFee) / 10000
            );

            if (
                (senderBalance * transferFee * liquidityBP) / 1e8 >=
                thresholdAmount
            ) {
                // Liquidity has been added
                assertGt(
                    IBaseV1Pair(token.pair()).totalSupply(),
                    liquidityBefore
                );
            }
        }
    }
}
