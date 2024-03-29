// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../src/Temple.sol";
import "../src/YinYang.sol";
import "../src/Zen.sol";
import "../src/LiquidityAdder.sol";

contract GardenTest is BaseTest {
    Temple public temple;
    Garden public garden;
    IERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    uint256 rewardsPerBlock = 10 ** 18;
    IERC20 wcanto;
    IERC20 note = IERC20(address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503));

    function setUp() public override {
        super.setUp();

        wcanto = IERC20(IBaseV1Router(router).weth());

        vm.deal(address(this), 100 ether);
        IWCanto(address(wcanto)).deposit{value: 50 ether}();

        YinYang yin = new YinYang(
            address(this),
            "Yin",
            "YIN",
            500,
            router,
            address(note),
            10 ** 19,
            150,
            150,
            200
        );
        YinYang yang = new YinYang(
            address(this),
            "Yang",
            "YANG",
            500,
            router,
            address(wcanto),
            10 ** 19,
            150,
            150,
            200
        );
        Zen zen = new Zen(address(this));
        zen.setPairs(router);

        temple = new Temple(
            address(this),
            block.timestamp,
            1,
            IYinYang(address(yin)),
            IYinYang(address(yang)),
            IZen(address(zen)),
            router
        );
        zen.transferOwnership(address(temple));

        garden = new Garden(
            address(this),
            rewardsPerBlock,
            0,
            address(temple.zen()),
            address(temple)
        );
        temple.setGarden(garden);
    }

    function testGardenAddPool() public {
        uint256 allocPoint = 1;
        garden.add(1, wcanto, 0, true, block.number);

        assertEq(garden.poolLength(), 1);
        (
            IERC20 _lpToken,
            ,
            uint256 _allocPoint,
            uint256 _lastRewardBlock,
            uint256 _accRewardsPerShare
        ) = garden.poolInfo(0);

        assertEq(address(_lpToken), address(wcanto));
        assertEq(_allocPoint, allocPoint);
        assertEq(_lastRewardBlock, block.number);
        assertEq(_accRewardsPerShare, 0);
    }

    function testGardenDeposit() public {
        garden.add(1, wcanto, 0, true, block.number);
        wcanto.approve(address(garden), 1 ether);
        garden.deposit(0, 1 ether);

        assertEq(garden.balanceOf(0, address(this)), 1 ether);
    }

    function testGardenWithdraw() public {
        garden.add(1, wcanto, 0, true, block.number);
        wcanto.approve(address(garden), 1 ether);
        garden.deposit(0, 1 ether);
        vm.roll(block.number + 1);
        garden.withdraw(0, 0);

        assertEq(garden.zen().balanceOf(address(this)), rewardsPerBlock);
    }
}
