// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "solmate/auth/Owned.sol";
import "./LiquidityAdder.sol";
import "./TurnstileRegisterEntry.sol";

abstract contract Distributor is Owned, TurnstileRegisterEntry {
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint16 depositFee;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardsPerShare;
    }

    uint256 public rewardsPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when reward mining starts.
    uint256 public startBlock;

    uint256 immutable PRECISION_FACTOR = 1e18;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event RewardPaid(address indexed user, uint256 amount);

    constructor(
        address _owner,
        uint256 _rewardsPerBlock,
        uint256 _startBlock
    ) Owned(_owner) TurnstileRegisterEntry() {
        if (_startBlock <= block.number) {
            _startBlock = block.number;
        } else {
            startBlock = _startBlock;
        }
        rewardsPerBlock = _rewardsPerBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // View function to see user balance on frontend.
    function balanceOf(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.amount;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            _updatePool(poolInfo[pid]);
        }
    }

    function checkPoolDuplicate(IERC20 _lpToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(
                poolInfo[pid].lpToken != _lpToken,
                "Distributor: existing pool?"
            );
        }
    }

    function setRewardsPerBlock(uint256 newRewards) external onlyOwner {
        massUpdatePools();
        rewardsPerBlock = newRewards;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFee,
        bool _withUpdate,
        uint256 _lastRewardBlock
    ) public onlyOwner {
        require(_depositFee < 10000, "bad fee");
        checkPoolDuplicate(_lpToken);

        if (_withUpdate) {
            massUpdatePools();
        }
        if (block.number < startBlock) {
            // chef is sleeping
            if (_lastRewardBlock == 0) {
                _lastRewardBlock = startBlock;
            } else {
                if (_lastRewardBlock < startBlock) {
                    _lastRewardBlock = startBlock;
                }
            }
        } else {
            // chef is cooking
            if (_lastRewardBlock == 0 || _lastRewardBlock < block.number) {
                _lastRewardBlock = block.number;
            }
        }
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                depositFee: _depositFee,
                allocPoint: _allocPoint,
                lastRewardBlock: _lastRewardBlock,
                accRewardsPerShare: 0
            })
        );

        totalAllocPoint = totalAllocPoint + _allocPoint;
    }

    // Update the given pool's YANG allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        massUpdatePools();
        PoolInfo storage pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(PoolInfo storage pool) internal {
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 rewards = (multiplier * rewardsPerBlock * pool.allocPoint) /
            totalAllocPoint;
        pool.accRewardsPerShare =
            pool.accRewardsPerShare +
            (rewards * PRECISION_FACTOR) /
            lpSupply;
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _updatePool(pool);
        if (user.amount > 0) {
            uint256 pending = ((user.amount * (pool.accRewardsPerShare)) /
                PRECISION_FACTOR) - user.rewardDebt;
            if (pending > 0) {
                _payRewards(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 amount = _amount;
            uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
            if (pool.depositFee > 0) {
                uint256 fee = (_amount * pool.depositFee) / 10000;
                pool.lpToken.transferFrom(msg.sender, owner, fee);
                pool.lpToken.transferFrom(
                    msg.sender,
                    address(this),
                    _amount - fee
                );
                amount = _amount - fee;
            } else {
                pool.lpToken.transferFrom(msg.sender, address(this), _amount);
            }

            user.amount =
                user.amount +
                pool.lpToken.balanceOf(address(this)) -
                balanceBefore;
        }
        user.rewardDebt =
            (user.amount * pool.accRewardsPerShare) /
            PRECISION_FACTOR;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        require(pool.depositFee != 10000, "full fee");
        _updatePool(pool);
        uint256 pending = ((user.amount * pool.accRewardsPerShare) /
            PRECISION_FACTOR) - (user.rewardDebt);
        if (pending > 0) {
            _payRewards(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt =
            (user.amount * pool.accRewardsPerShare) /
            PRECISION_FACTOR;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // View function to see pending rewards on frontend.
    function pendingRewards(
        uint256 _pid,
        address _user
    ) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 rewards = (multiplier * rewardsPerBlock * pool.allocPoint) /
                totalAllocPoint;
            accRewardsPerShare = (accRewardsPerShare +
                (rewards * (PRECISION_FACTOR)) /
                (lpSupply));
        }
        return
            ((user.amount * accRewardsPerShare) / PRECISION_FACTOR) -
            user.rewardDebt;
    }

    function _payRewards(address recipient, uint256 amount) internal virtual {}
}
