// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Temple.sol";
import "../src/LiquidityAdder.sol";

interface IWCanto {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;
}

contract TempleTest is Test {
    Temple public temple;
    Garden public garden;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    address router = address(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    ERC20 wcanto;
    ERC20 note;

    function setUp() public {
        note = ERC20(IBaseV1Router(router).note());
        wcanto = ERC20(IBaseV1Router(router).wcanto());

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

        temple = new Temple(
            address(this),
            block.timestamp,
            1,
            yin,
            yang,
            router
        );

        garden = new Garden(
            address(this),
            10 ** 18,
            0,
            address(temple.zen()),
            address(temple)
        );
    }

    // function testVote() public {
    //     temple;
    // }
}
