// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/Temple.sol";
import "../src/LiquidityAdder.sol";

contract TempleTest is Test {
    Temple public temple;
    Garden public garden;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    uint256 rewardsPerBlock = 10 ** 18;
    uint256 epochPeriod = 2;
    address router = address(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    ERC20 wcanto;
    ERC20 note;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

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
        Zen zen = new Zen(address(this));
        zen.setPairs(router);

        // Note USDC pair
        address noteUsdcPair = address(
            0x9571997a66D63958e1B3De9647C22bD6b9e7228c
        );
        vm.prank(noteUsdcPair);
        note.transfer(address(this), 10 ** 21);

        yin.excludeAccount(address(this));
        yin.initialize(address(this), 10 ** 27);
        yang.excludeAccount(address(this));
        yang.initialize(address(this), 10 ** 27);

        vm.deal(address(this), 10 ** 24);
        IWCanto(address(wcanto)).deposit{value: 10 ** 19}();
        wcanto.approve(address(router), type(uint256).max);
        note.approve(address(router), type(uint256).max);
        yin.approve(address(router), type(uint256).max);
        yang.approve(address(router), type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(yang),
            address(wcanto),
            false,
            10 ** 23,
            10 ** 18,
            0,
            0,
            address(this),
            block.timestamp + 360
        );
        IBaseV1Router(router).addLiquidity(
            address(yin),
            address(note),
            false,
            10 ** 23,
            10 ** 18,
            0,
            0,
            address(this),
            block.timestamp + 360
        );

        temple = new Temple(
            address(this),
            block.timestamp,
            epochPeriod,
            yin,
            yang,
            zen,
            router
        );
        yin.setTemple(address(temple));
        yang.setTemple(address(temple));
        zen.transferOwnership(address(temple));

        garden = new Garden(
            address(this),
            rewardsPerBlock,
            0,
            address(temple.zen()),
            address(temple)
        );
        temple.setGarden(garden);

        garden.add(1, wcanto, true, block.number);
        wcanto.approve(address(garden), type(uint256).max);

        yin.transfer(address(temple), 10 ** 16);
        yang.transfer(address(temple), 10 ** 16);
    }

    function testTempleVote(uint256 voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount < rewardsPerBlock);

        vm.deal(address(this), 100 ether);
        IWCanto(address(wcanto)).deposit{value: 50 ether}();

        garden.deposit(0, 1 ether);
        vm.roll(block.number + 1);
        garden.withdraw(0, 0);

        address voteToken = address(note);

        temple.voteForNextTarget(voteToken, voteAmount);

        assertEq(temple.voices(voteToken), voteAmount);
        assertEq(temple.shares(voteToken), voteAmount);
        assertEq(temple.votersToken(address(this)), voteToken);
        assertEq(
            temple.zen().balanceOf(address(this)),
            rewardsPerBlock - voteAmount
        );
    }

    function testTempleHarvest(uint256 voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount < rewardsPerBlock);

        vm.deal(address(this), rewardsPerBlock);
        IWCanto(address(wcanto)).deposit{value: voteAmount}();
        garden.deposit(0, voteAmount);

        address otherUser = address(123);
        vm.deal(otherUser, rewardsPerBlock);
        vm.startPrank(otherUser);
        IWCanto(address(wcanto)).deposit{value: rewardsPerBlock - voteAmount}();
        wcanto.approve(address(garden), type(uint256).max);
        garden.deposit(0, rewardsPerBlock - voteAmount);
        vm.stopPrank();

        vm.roll(block.number + 1);

        garden.withdraw(0, 0);

        vm.prank(otherUser);
        garden.withdraw(0, 0);

        console.log(
            garden.zen().balanceOf(address(this)),
            garden.zen().balanceOf(otherUser)
        );

        address voteToken = address(note);

        temple.voteForNextTarget(voteToken, voteAmount);
        vm.prank(otherUser);
        temple.voteForNextTarget(voteToken, rewardsPerBlock - voteAmount);

        vm.warp(block.timestamp + epochPeriod + 1);
        console.log(
            temple.epochStart(),
            temple.epochDuration(),
            block.timestamp
        );
        temple.harvest();

        uint256 balanceBefore = note.balanceOf(address(this));
        uint256 balanceContractBefore = note.balanceOf(address(temple));
        temple.claimAllVoterShares();

        assertEq(
            note.balanceOf(address(this)),
            balanceBefore +
                (balanceContractBefore * voteAmount) /
                rewardsPerBlock
        );
        assertEq(temple.votersToken(address(this)), voteToken);
        assertEq(temple.voices(voteToken), rewardsPerBlock);
        assertEq(temple.shares(voteToken), rewardsPerBlock);
        assertEq(temple.zen().balanceOf(address(this)), 0);
    }
}
