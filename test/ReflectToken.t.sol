// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

import "../src/ReflectToken.sol";

contract Reflect is ReflectToken {
    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 totalTransferFee
    ) ReflectToken(_owner, _name, _symbol, _decimals, totalTransferFee) {}
}

contract ReflectTokenTest is Test {
    Reflect public token;
    uint16 transferFee = 500;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("canto_mainnet"));
        // console.log(address(this), vm.rpcUrl("canto_mainnet"));
    }

    function testReflectTransferFromExcluded(
        address sender,
        address recipient,
        uint256 transferAmount,
        bool excludeSender,
        bool excludeRecipient
    ) public {
        uint256 initialSupply = 10 ** 27;
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount < initialSupply);
        vm.assume(sender != address(0));
        vm.assume(recipient != address(0));
        vm.assume(sender != recipient);

        token = new Reflect(address(this), "Test", "TEST", 18, transferFee);
        token.excludeAccount(address(this));
        token.excludeAccount(sender);
        token.mintInitialSupply(address(this), initialSupply);
        token.transfer(sender, transferAmount);

        assertEq(
            token.balanceOf(address(this)),
            initialSupply - transferAmount
        );
        assertEq(token.balanceOf(sender), transferAmount);

        if (!excludeSender) {
            token.includeAccount(sender);
        }
        if (excludeRecipient) {
            token.excludeAccount(recipient);
        }

        vm.prank(sender);
        token.transfer(recipient, transferAmount);

        assertGe(token.balanceOf(sender), 0);
        assertGe(
            token.balanceOf(recipient),
            transferAmount - (transferAmount * transferFee) / 10000
        );
    }

    function testReflectInclusion(address account) public {
        vm.assume(account != address(0));

        token = new Reflect(address(this), "Test", "TEST", 18, transferFee);

        assertEq(token.isExcluded(account), false);

        token.excludeAccount(account);

        assertEq(token.isExcluded(account), true);

        token.includeAccount(account);

        assertEq(token.isExcluded(account), false);
    }
}
