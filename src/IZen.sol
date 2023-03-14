// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "openzeppelin/token/ERC20/IERC20.sol";

interface IZen is IERC20 {
    function mintTo(address, uint256) external;

    function burnFrom(address, uint256) external;

    function pair() external returns (address);
}
