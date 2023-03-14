// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./BaseTest.sol";
import "./SimpleERC20.sol";
import "../src/BasicDistributor.sol";
import "../src/LiquidityAdder.sol";

contract BasicDistributorTest is BaseTest {
    BasicDistributor public basicDistributor;
    SimpleERC20 public token;
    uint16 transferFee = 700;
    uint256 thresholdAmount = 10 ** 19;
    uint256 rewardsPerBlock = 10 ** 18;
    // uint256 startBlock = 0;
    IERC20 wcanto;
    IERC20 note = IERC20(address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503));

    function setUp() public override {
        super.setUp();
        token = new SimpleERC20();
        wcanto = IERC20(IBaseV1Router(router).weth());
    }

    function testBasicDistributorAddPool(uint16 depositFee) public {
        vm.assume(depositFee < 10000);

        basicDistributor = new BasicDistributor(
            address(this),
            rewardsPerBlock,
            0,
            IERC20(address(token))
        );

        uint256 allocPoint = 1;
        basicDistributor.add(1, wcanto, depositFee, true, 0);

        assertEq(basicDistributor.poolLength(), 1);
        (
            IERC20 _lpToken,
            uint16 _depositFee,
            uint256 _allocPoint,
            uint256 _lastRewardBlock,
            uint256 _accRewardsPerShare
        ) = basicDistributor.poolInfo(0);

        assertEq(address(_lpToken), address(wcanto));
        assertEq(_depositFee, depositFee);
        assertEq(_allocPoint, allocPoint);
        assertEq(_lastRewardBlock, block.number);
        assertEq(_accRewardsPerShare, 0);
    }

    function testBasicDistributorDepositWithFee(
        uint16 depositFee,
        uint256 amount
    ) public {
        vm.assume(depositFee < 10000);
        vm.assume(amount < 2 ** 230);

        basicDistributor = new BasicDistributor(
            address(this),
            rewardsPerBlock,
            0,
            IERC20(address(token))
        );

        basicDistributor.add(1, wcanto, depositFee, true, 0);
        address user = address(123);
        vm.startPrank(user);
        vm.deal(user, amount);
        IWCanto(address(wcanto)).deposit{value: amount}();
        wcanto.approve(address(basicDistributor), amount);
        basicDistributor.deposit(0, amount);

        (uint256 userAmount, uint256 debt) = basicDistributor.userInfo(0, user);
        assertEq(userAmount, amount - (amount * depositFee) / 10000);
        assertEq(
            wcanto.balanceOf(address(basicDistributor)),
            amount - (amount * depositFee) / 10000
        );
        assertEq(
            wcanto.balanceOf(address(this)),
            (amount * depositFee) / 10000
        );
        assertEq(debt, 0);
    }

    function testBasicDistributorDeposit(uint256 amount) public {
        // Deposit a fuzzed amount
        vm.assume(amount < 2 ** 250);
        basicDistributor = new BasicDistributor(
            address(this),
            rewardsPerBlock,
            0,
            IERC20(address(token))
        );

        basicDistributor.add(1, wcanto, 0, true, 0);
        vm.deal(address(this), amount);
        IWCanto(address(wcanto)).deposit{value: amount}();
        wcanto.approve(address(basicDistributor), amount);
        basicDistributor.deposit(0, amount);

        assertEq(basicDistributor.balanceOf(0, address(this)), amount);
    }

    function testBasicDistributorWithdrawBeforeStart(
        uint256 rewards,
        uint256 startBlock
    ) public {
        // Deposit a fix amount, receive a fuzzed amount
        vm.assume(rewards < 10 ** 27);
        vm.assume(startBlock > 2);
        vm.roll(0);

        basicDistributor = new BasicDistributor(
            address(this),
            rewards,
            startBlock,
            IERC20(address(token))
        );
        token.transfer(
            address(basicDistributor),
            token.balanceOf(address(this))
        );

        basicDistributor.add(1, wcanto, 0, true, 0);
        IWCanto(address(wcanto)).deposit{value: 1 ether}();
        wcanto.approve(address(basicDistributor), 1 ether);
        basicDistributor.deposit(0, 1 ether);
        vm.roll(block.number + 1);
        basicDistributor.withdraw(0, 0);

        assertEq(token.balanceOf(address(this)), 0);
    }

    function testBasicDistributorWithdraw(
        uint256 rewards,
        uint256 blocks
    ) public {
        // Deposit a fixed amount, received fuzzed rewards
        vm.assume(blocks > 1);
        vm.assume(blocks < 1000);
        vm.assume(rewards < 10 ** 27 / blocks);

        basicDistributor = new BasicDistributor(
            address(this),
            rewards,
            0,
            IERC20(address(token))
        );
        token.transfer(
            address(basicDistributor),
            token.balanceOf(address(this))
        );

        basicDistributor.add(1, wcanto, 0, true, 0);

        address a = address(123);
        vm.startPrank(a);
        vm.deal(a, 10 ether);
        IWCanto(address(wcanto)).deposit{value: 2 ether}();
        wcanto.approve(address(basicDistributor), type(uint256).max);
        basicDistributor.deposit(0, 1 ether);
        vm.roll(block.number + blocks);
        basicDistributor.massUpdatePools();
        basicDistributor.withdraw(0, 0);
        vm.stopPrank();

        assertEq(token.balanceOf(a), rewards * blocks);
    }

    function testBasicDistributorWithdrawMultipleUsers(
        uint256 rewards,
        uint256 blocks,
        uint8 users
    ) public {
        // Deposit a fixed amount, received fuzzed rewards
        vm.assume(blocks > 1);
        vm.assume(blocks < 1000);
        vm.assume(rewards < 10 ** 27 / blocks);
        vm.assume(users > 0);

        basicDistributor = new BasicDistributor(
            address(this),
            rewards,
            0,
            IERC20(address(token))
        );
        token.transfer(
            address(basicDistributor),
            token.balanceOf(address(this))
        );
        basicDistributor.add(1, wcanto, 0, true, 0);

        uint8 i = 0;
        address a;
        while (i < users) {
            a = address(uint160(i + 1));
            vm.startPrank(a);

            vm.deal(a, 10 ether);
            IWCanto(address(wcanto)).deposit{value: 2 ether}();
            wcanto.approve(address(basicDistributor), type(uint256).max);

            basicDistributor.deposit(0, 1 ether);

            vm.stopPrank();
            i += 1;
        }

        vm.roll(block.number + blocks);
        vm.prank(a);
        basicDistributor.withdraw(0, 0);

        assertEq(token.balanceOf(a), (rewards * blocks) / users);
    }

    function testBasicDistributorWithdrawAllocPoints(
        uint256 rewards,
        uint256 allocPoints
    ) public {
        // Deposit a fixed amount, received fuzzed rewards
        vm.assume(allocPoints > 1);
        vm.assume(allocPoints < 2 ** 16);
        vm.assume(rewards < 10 ** 27);
        vm.roll(block.number);

        basicDistributor = new BasicDistributor(
            address(this),
            rewards,
            block.number,
            IERC20(address(token))
        );
        token.transfer(address(basicDistributor), rewards);

        basicDistributor.add(1, wcanto, 0, true, 0);
        basicDistributor.add(allocPoints - 1, note, 0, true, 0);

        address a = address(0x1);
        vm.startPrank(a);

        vm.deal(a, 10 ether);
        IWCanto(address(wcanto)).deposit{value: 2 ether}();
        wcanto.approve(address(basicDistributor), type(uint256).max);

        basicDistributor.deposit(0, 1 ether);

        vm.roll(block.number + 1);

        basicDistributor.withdraw(0, 0);

        vm.stopPrank();

        assertEq(token.balanceOf(a), rewards / allocPoints);
        assertGe(
            token.balanceOf(address(basicDistributor)),
            ((allocPoints - 1) * rewards) / allocPoints
        );
    }

    function testBasicDistributorWithdrawAllRewards(
        uint256 blocks,
        uint8 users,
        uint256 rewards
    ) public {
        // Deposit a fixed amount, received fuzzed rewards
        vm.assume(blocks > 0);
        vm.assume(blocks < 10 ** 7);
        vm.assume(users > 0);
        vm.assume(rewards % users == 0);
        vm.assume(rewards % blocks == 0);
        vm.assume(rewards > blocks);
        vm.assume(rewards < 10 ** 27);
        vm.roll(block.number);

        basicDistributor = new BasicDistributor(
            address(this),
            rewards / blocks,
            block.number,
            IERC20(address(token))
        );
        token.transfer(address(basicDistributor), rewards);
        basicDistributor.add(1, wcanto, 0, true, 0);

        uint8 i = 0;
        address a;
        while (i < users) {
            a = address(uint160(i + 1));
            vm.startPrank(a);

            vm.deal(a, 10 ether);
            IWCanto(address(wcanto)).deposit{value: 2 ether}();
            wcanto.approve(address(basicDistributor), type(uint256).max);

            basicDistributor.deposit(0, 1 ether);

            vm.stopPrank();
            i += 1;
        }

        // basicDistributor.massUpdatePools();

        vm.roll(block.number + blocks);
        a = address(1);
        vm.prank(a);
        basicDistributor.withdraw(0, 0);

        assertEq(token.balanceOf(a), rewards / users);
        assertEq(
            token.balanceOf(address(basicDistributor)),
            ((users - 1) * rewards) / users
        );
    }
}
