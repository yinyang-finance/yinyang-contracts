// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/LiquidityAdder.sol";
import "../src/Temple.sol";
import "../src/BasicDistributor.sol";

contract AddLiquidityScript is Script {
    uint256 initialSupply = 10 ** 7 * 10 ** 18;
    uint256 minAmountToSell = 1000 * 10 ** 18;
    uint256 blockTime = 6;
    uint256 blockPerDay = 86400 / blockTime;
    uint256 rewardPerDay = 10 ** 23;
    uint256 rewardsPerBlock = rewardPerDay / blockPerDay;
    uint256 epochPeriod = 86400;
    uint16 depositFee = 500;
    uint256 startBlock = 3180000;
    address router = address(0x8e2e2f70B4bD86F82539187A634FB832398cc771);
    address eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
    address atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
    address cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
    address cantoBonk = address(0x38D11B40D2173009aDB245b869e90525950aE345);
    IERC20 wcanto;
    Garden garden;
    Temple temple;

    function setUp() public {
        vm.deal(tx.origin, 100 ether);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        wcanto = IERC20(IBaseV1Router(router).weth());

        IYinYang yin = IYinYang(0xefc1aB2475ACb7E60499Efb171D173be19928a05);
        IYinYang yang = IYinYang(0x870526b7973b56163a6997bB7C886F5E4EA53638);
        IZen zen = IZen(0xD49a0e9A4CD5979aE36840f542D2d7f02C4817Be);

        yang.approve(router, type(uint256).max);
        wcanto.approve(router, type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(yang),
            address(wcanto),
            false,
            10 ** 17,
            10 ** 16,
            0,
            0,
            tx.origin,
            block.timestamp + 100
        );
        yin.approve(router, type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(yin),
            address(wcanto),
            false,
            10 ** 17,
            10 ** 16,
            0,
            0,
            tx.origin,
            block.timestamp + 100
        );
        zen.approve(router, type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(zen),
            address(wcanto),
            false,
            10 ** 17,
            10 ** 16,
            0,
            0,
            tx.origin,
            block.timestamp + 100
        );

        vm.stopBroadcast();
    }
}
