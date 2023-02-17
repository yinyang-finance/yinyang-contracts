// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./ReflectToken.sol";
import "./LiquidityAdder.sol";

contract YinYang is ReflectToken {
    address public router;
    address public pair;
    address public quote;
    LiquidityAdder public liquidityAdder;
    uint256 public minimumTokenToSell;

    constructor(
        address _owner,
        string memory name,
        string memory symbol,
        uint16 feeBP,
        address _router,
        address _quote,
        uint256 _minimumTokenToSell
    ) ReflectToken(_owner, name, symbol, 18, feeBP) {
        router = _router;
        quote = _quote;
        minimumTokenToSell = _minimumTokenToSell;

        _excludeAccount(router);
        _excludeAccount(pair);
        _excludeAccount(address(liquidityAdder));
    }

    function initialize(
        address recipient,
        uint256 initialSupply
    ) external onlyOwner {
        require(!initialized, "Initialized");

        pair = IBaseV1Factory(IBaseV1Router(router).factory()).createPair(
            address(this),
            quote,
            false
        );
        liquidityAdder = new LiquidityAdder(router, pair, address(this), quote);
        mintInitialSupply(recipient, initialSupply);

        initialized = true;
    }

    function _onTransfer(
        address sender,
        uint256 reflectionFee
    ) internal override returns (uint256) {
        uint256 burn = reflectionFee / 3;
        uint256 liquidity = reflectionFee / 3;

        // Burn a share
        _tTotal = _tTotal - burn;
        _rTotal = _rTotal - burn * _getRate();
        emit Transfer(sender, address(0), burn);

        // Send a share to the liquidity adder
        uint256 newLiquidity = _tOwned[address(liquidityAdder)] + liquidity;
        _tOwned[address(liquidityAdder)] = newLiquidity;
        emit Transfer(sender, address(liquidityAdder), liquidity);

        // Add liquidity if threshold reached
        if (newLiquidity > minimumTokenToSell) {
            liquidityAdder.addLiquidity();
        }

        // Reflect the rest
        return reflectionFee - burn - liquidity;
    }
}
