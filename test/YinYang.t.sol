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
        quote = ERC20(IBaseV1Router(router).weth());
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

        assertGe(
            token.balanceOf(temple),
            (transferAmount * 2 * transferFee) / 50000 - 1
        );
        assertGe(
            token.totalSupply(),
            supplyBefore - (transferAmount * (transferFee / 5)) / 10000 - 1
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
        console.log(
            IBaseV1Pair(
                IBaseV1Router(router).pairFor(
                    address(token),
                    address(wcanto),
                    false
                )
            ).totalSupply()
        );
        console.log(
            IBaseV1Pair(
                IBaseV1Router(router).pairFor(
                    address(token),
                    address(wcanto),
                    false
                )
            ).token0(),
            IBaseV1Pair(
                IBaseV1Router(router).pairFor(
                    address(token),
                    address(wcanto),
                    false
                )
            ).token1()
        );
        console.log(
            IBaseV1Pair(token.pair()).token0(),
            IBaseV1Pair(token.pair()).token1()
        );
        console.log(
            token.pair(),
            IBaseV1Router(router).pairFor(
                address(token),
                address(wcanto),
                false
            )
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
                templeBalance + (senderBalance * 2 * transferFee) / 50000 - 1
            );
            assertGe(
                token.totalSupply(),
                supplyBefore - (senderBalance * transferFee) / 10000 - 1
            );
            assertLe(
                token.balanceOf(_sender),
                (senderBalance * transferFee) / 10000
            );
            assertGe(
                token.balanceOf(_recipient),
                senderBalance - (senderBalance * transferFee) / 10000
            );

            if ((senderBalance * transferFee) / 50000 >= thresholdAmount) {
                // Liquidity has been added
                assertGt(
                    IBaseV1Pair(token.pair()).totalSupply(),
                    liquidityBefore
                );
            }
        }
    }
}
