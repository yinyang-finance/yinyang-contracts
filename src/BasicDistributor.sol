// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "./Distributor.sol";

contract BasicDistributor is Distributor {
    IERC20 public rewardToken;

    constructor(
        address _owner,
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        IERC20 _rewardToken
    ) Distributor(_owner, _rewardsPerBlock, _startBlock) {
        rewardToken = _rewardToken;
    }

    function _payRewards(address recipient, uint256 amount) internal override {
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(recipient, amount > balance ? balance : amount);
    }
}
