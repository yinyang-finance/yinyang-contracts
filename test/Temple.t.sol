// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "../src/Temple.sol";
import "../src/LiquidityAdder.sol";

contract TempleTest is BaseTest {
    Temple public temple;
    Garden public garden;
    ERC20 public quote;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    uint256 rewardsPerBlock = 10 ** 18;
    uint256 epochPeriod = 2;
    ERC20 wcanto;

    function setUp() public override {
        super.setUp();

        wcanto = ERC20(IBaseV1Router(router).weth());

        vm.deal(address(this), 100 ether);
        IWCanto(address(wcanto)).deposit{value: 50 ether}();

        YinYang yin = new YinYang(
            address(this),
            "Yin",
            "YIN",
            500,
            router,
            address(wcanto),
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

        yin.excludeAccount(address(this));
        yin.initialize(address(this), 10 ** 27);
        yang.excludeAccount(address(this));
        yang.initialize(address(this), 10 ** 27);

        vm.deal(address(this), 10 ** 24);
        IWCanto(address(wcanto)).deposit{value: 10 ** 19}();
        wcanto.approve(address(router), type(uint256).max);
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
            address(wcanto),
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
        yin.excludeAccount(address(temple));
        yin.setTemple(address(temple));
        yang.excludeAccount(address(temple));
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

        garden.add(1, wcanto, 0, true, block.number);
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

        address voteToken = address(wcanto);

        temple.voteForNextTarget(voteToken, voteAmount);

        assertEq(temple.voices(0, voteToken), voteAmount);
        assertEq(temple.shares(), voteAmount);
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

        address voteToken = address(wcanto);

        temple.voteForNextTarget(voteToken, voteAmount);
        vm.prank(otherUser);
        temple.voteForNextTarget(voteToken, rewardsPerBlock - voteAmount);

        vm.warp(block.timestamp + epochPeriod + 1);
        temple.harvest();

        uint256 balanceBefore = wcanto.balanceOf(address(this));
        uint256 balanceContractBefore = wcanto.balanceOf(address(temple));
        temple.claimAllVoterShares();

        assertEq(
            wcanto.balanceOf(address(this)),
            balanceBefore +
                (balanceContractBefore * voteAmount) /
                rewardsPerBlock
        );
        assertEq(temple.votersToken(address(this)), voteToken);
        assertEq(temple.voices(0, voteToken), rewardsPerBlock);
        assertEq(temple.shares(), 0);
        assertEq(temple.zen().balanceOf(address(this)), 0);
    }

    function testTempleUpdateAccount(uint256 voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount < rewardsPerBlock);

        // Deposit into the garden
        vm.deal(address(this), rewardsPerBlock);
        IWCanto(address(wcanto)).deposit{value: voteAmount}();
        garden.deposit(0, voteAmount);

        address otherUser = address(123);
        vm.startPrank(otherUser);
        vm.deal(otherUser, rewardsPerBlock);
        IWCanto(address(wcanto)).deposit{value: rewardsPerBlock - voteAmount}();
        wcanto.approve(address(garden), type(uint256).max);
        garden.deposit(0, rewardsPerBlock - voteAmount);
        vm.stopPrank();

        vm.roll(block.number + 1);

        garden.withdraw(0, 0);

        vm.prank(otherUser);
        garden.withdraw(0, 0);

        address voteToken = address(wcanto);

        temple.voteForNextTarget(voteToken, voteAmount);
        vm.prank(otherUser);
        temple.voteForNextTarget(voteToken, rewardsPerBlock - voteAmount);

        vm.warp(block.timestamp + epochPeriod + 1);
        temple.harvest();

        vm.startPrank(otherUser);
        temple.updateUserAccount(1);
        uint256 balanceBefore = wcanto.balanceOf(otherUser);
        uint256 balanceContractBefore = wcanto.balanceOf(address(temple));
        temple.claimAllVoterShares();
        vm.stopPrank();

        assertEq(
            wcanto.balanceOf(otherUser),
            balanceBefore +
                (balanceContractBefore * (rewardsPerBlock - voteAmount)) /
                rewardsPerBlock
        );
        assertEq(temple.votersToken(otherUser), voteToken);
        assertEq(temple.voices(0, voteToken), rewardsPerBlock);
        assertEq(temple.zen().balanceOf(otherUser), 0);
    }

    function testTempleSharesTransferBetweenRounds(uint256 voteAmount) public {
        vm.assume(voteAmount > 0);
        vm.assume(voteAmount < rewardsPerBlock);

        // Deposit into the garden
        vm.deal(address(this), rewardsPerBlock);
        IWCanto(address(wcanto)).deposit{value: voteAmount}();
        garden.deposit(0, voteAmount);

        vm.roll(block.number + 1);
        address voteToken = address(wcanto);
        garden.withdraw(0, 0);
        temple.voteForNextTarget(voteToken, voteAmount);

        vm.warp(block.timestamp + epochPeriod + 1);
        temple.harvest();

        vm.roll(block.number + 1);
        garden.withdraw(0, 0);
        temple.voteForNextTarget(voteToken, voteAmount);

        assertEq(temple.participations(1, address(this)), 2 * voteAmount);
        assertEq(temple.voices(1, voteToken), 2 * voteAmount);
        assertEq(temple.shares(), 2 * voteAmount);
    }

    function testTempleHarvestMultipleUsers(uint8 users) public {
        vm.assume(users > 0);
        vm.assume(rewardsPerBlock % users == 0);

        uint256 voteAmount = 1;

        // Deposit
        address addr;
        for (uint8 i = 0; i < users; i++) {
            addr = address(uint160(i + 1));
            vm.startPrank(addr);
            vm.deal(addr, 10 ether);
            IWCanto(address(wcanto)).deposit{value: 1 ether}();
            wcanto.approve(address(garden), type(uint256).max);
            garden.deposit(0, 1 ether);
            vm.stopPrank();
        }

        vm.roll(block.number + 1);

        // Collect rewards
        for (uint8 i = 0; i < users; i++) {
            addr = address(uint160(i + 1));
            vm.startPrank(addr);
            garden.withdraw(0, 0);
            vm.stopPrank();
        }

        address voteToken = address(wcanto);

        // Vote
        for (uint8 i = 0; i < users; i++) {
            addr = address(uint160(i + 1));
            vm.startPrank(addr);
            temple.voteForNextTarget(voteToken, voteAmount);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + epochPeriod + 1);
        assertEq(temple.shares(), users);
        temple.harvest();

        uint256 balanceBefore = wcanto.balanceOf(addr);
        uint256 balanceContractBefore = wcanto.balanceOf(address(temple));
        vm.prank(addr);
        temple.claimAllVoterShares();

        assertEq(
            wcanto.balanceOf(addr),
            balanceBefore + (balanceContractBefore * voteAmount) / users
        );
        assertEq(temple.votersToken(addr), voteToken);
        assertEq(temple.voices(0, voteToken), voteAmount * users);
        assertEq(temple.shares(), 0);
        assertEq(temple.zen().balanceOf(addr), rewardsPerBlock / users - 1);
    }
}
