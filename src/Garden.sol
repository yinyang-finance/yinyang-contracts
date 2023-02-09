// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Distributor.sol";
import "./Zen.sol";
import "./Temple.sol";

contract Garden is Distributor {
    Zen public zen;
    Temple public temple;

    constructor(
        address _owner,
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        address _zen,
        address _temple
    ) Distributor(_owner, _rewardsPerBlock, _startBlock) {
        temple = Temple(_temple);
        zen = Zen(_zen);
    }

    function _payRewards(address recipient, uint256 amount) internal override {
        temple.mintZen(recipient, amount);
    }
}
