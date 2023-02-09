// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "solmate/tokens/ERC20.sol";
import "./Distributor.sol";

contract Garden is Distributor {
    ERC20 public rewardToken;

    constructor(
        address _owner,
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        ERC20 _rewardToken
    ) Distributor(_owner, _rewardsPerBlock, _startBlock) {
        rewardToken = _rewardToken;
    }

    function _payRewards(address recipient, uint256 amount) internal override {
        uint256 paidAmount = amount > rewardToken.balanceOf(address(this))
            ? rewardToken.balanceOf(address(this))
            : amount;
        rewardToken.transfer(recipient, paidAmount);
    }
}
