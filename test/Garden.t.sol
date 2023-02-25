// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Temple.sol";
import "../src/LiquidityAdder.sol";

contract GardenTest is Test {
    Temple public temple;
    Garden public garden;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    uint256 rewardsPerBlock = 10 ** 18;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    ERC20 wcanto;
    ERC20 note = ERC20(address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503));

    function setUp() public {
        wcanto = ERC20(IBaseV1Router(router).WETH());

        vm.deal(address(this), 100 ether);
        IWCanto(address(wcanto)).deposit{value: 50 ether}();

        YinYang yin = new YinYang(
            address(this),
            "Yin",
            "YIN",
            500,
            router,
            address(note),
            10 ** 19
        );
        YinYang yang = new YinYang(
            address(this),
            "Yang",
            "YANG",
            500,
            router,
            address(wcanto),
            10 ** 19
        );
        Zen zen = new Zen(address(this));
        zen.setPairs(router);

        temple = new Temple(
            address(this),
            block.timestamp,
            1,
            yin,
            yang,
            zen,
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
        garden.add(1, wcanto, true, block.number);

        assertEq(garden.poolLength(), 1);
        (
            ERC20 _lpToken,
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
        garden.add(1, wcanto, true, block.number);
        wcanto.approve(address(garden), 1 ether);
        garden.deposit(0, 1 ether);

        assertEq(garden.balanceOf(0, address(this)), 1 ether);
    }

    function testGardenWithdraw() public {
        garden.add(1, wcanto, true, block.number);
        wcanto.approve(address(garden), 1 ether);
        garden.deposit(0, 1 ether);
        vm.roll(block.number + 1);
        garden.withdraw(0, 0);

        assertEq(garden.zen().balanceOf(address(this)), rewardsPerBlock);
    }
}
