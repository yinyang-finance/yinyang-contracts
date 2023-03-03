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
    ERC20 wcanto;
    ERC20 note = ERC20(address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503));

    function setUp() public override {
        super.setUp();
        token = new SimpleERC20();
        wcanto = ERC20(IBaseV1Router(router).weth());
    }

    function testBasicDistributorAddPool() public {
        basicDistributor = new BasicDistributor(
            address(this),
            rewardsPerBlock,
            0,
            token
        );

        uint256 allocPoint = 1;
        basicDistributor.add(1, wcanto, true, 0);

        assertEq(basicDistributor.poolLength(), 1);
        (
            ERC20 _lpToken,
            uint256 _allocPoint,
            uint256 _lastRewardBlock,
            uint256 _accRewardsPerShare
        ) = basicDistributor.poolInfo(0);

        assertEq(address(_lpToken), address(wcanto));
        assertEq(_allocPoint, allocPoint);
        assertEq(_lastRewardBlock, block.number);
        assertEq(_accRewardsPerShare, 0);
    }

    function testBasicDistributorDeposit(uint256 amount) public {
        // Deposit a fuzzed amount
        vm.assume(amount < 2 ** 250);
        basicDistributor = new BasicDistributor(
            address(this),
            rewardsPerBlock,
            0,
            token
        );

        basicDistributor.add(1, wcanto, true, 0);
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
            token
        );
        token.transfer(
            address(basicDistributor),
            token.balanceOf(address(this))
        );

        basicDistributor.add(1, wcanto, true, 0);
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
            token
        );
        token.transfer(
            address(basicDistributor),
            token.balanceOf(address(this))
        );

        basicDistributor.add(1, wcanto, true, 0);

        address a = address(123);
        vm.startPrank(a);
        vm.deal(a, 10 ether);
        IWCanto(address(wcanto)).deposit{value: 2 ether}();
        wcanto.approve(address(basicDistributor), type(uint256).max);
        basicDistributor.deposit(0, 1 ether);
        vm.roll(block.number + blocks);
        basicDistributor.massUpdatePools();
        {
            (
                ERC20 pi0,
                uint256 pi1,
                uint256 pi2,
                uint256 pi3
            ) = basicDistributor.poolInfo(0);
            console.log(address(pi0), pi1, pi2, pi3);
        }
        {
            (uint256 pi2, uint256 pi3) = basicDistributor.userInfo(0, a);
            console.log(pi2, pi3);
        }
        basicDistributor.withdraw(0, 0);
        {
            (
                ERC20 pi0,
                uint256 pi1,
                uint256 pi2,
                uint256 pi3
            ) = basicDistributor.poolInfo(0);
            console.log(address(pi0), pi1, pi2, pi3);
        }
        vm.stopPrank();

        assertEq(token.balanceOf(a), rewards * blocks);
    }
}
