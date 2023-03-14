// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

interface IYinYang is IERC20Metadata {
    function excludeAccount(address) external;

    function quote() external returns (address);

    function pair() external returns (address);
}
