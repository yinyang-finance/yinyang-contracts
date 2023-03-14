// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/LiquidityAdder.sol";
import "../src/Temple.sol";
import "../src/BasicDistributor.sol";
import "../src/YinYang.sol";

contract YinScript is Script {
    uint256 initialSupply = 10 ** 7 * 10 ** 18;
    uint256 minAmountToSell = 1000 * 10 ** 18;
    uint256 blockTime = 6;
    uint256 blockPerDay = 86400 / blockTime;
    uint256 rewardPerDay = 10 ** 23;
    uint256 rewardsPerBlock = rewardPerDay / blockPerDay;
    uint256 epochPeriod = 86400;
    uint16 depositFee = 500;
    uint256 startBlock = 3180000;
    address router = address(0x9B2920e72dF6E1A7053bEa7235c65079F5104398);
    address eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
    address atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
    address cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
    address cantoBonk = address(0x38D11B40D2173009aDB245b869e90525950aE345);
    IERC20 wcanto;
    Garden garden;
    Temple temple;

    function setUp() public {
        vm.deal(tx.origin, 100 ether);

        // TODO: Update for mainnet
        bool testnet = true;
        if (testnet) {
            blockTime = 6;
            blockPerDay = 86400 / blockTime;
            rewardPerDay = 10 ** 23;
            rewardsPerBlock = rewardPerDay / blockPerDay;
            epochPeriod = 3600;
            eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
            atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
            cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
            cantoBonk = address(0x38D11B40D2173009aDB245b869e90525950aE345);
        }
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        wcanto = IERC20(IBaseV1Router(router).weth());

        YinYang yin = new YinYang(
            tx.origin,
            "Test Yin",
            "tYIN",
            600,
            router,
            address(wcanto),
            minAmountToSell,
            3333,
            1666,
            3333
        );

        yin.excludeAccount(tx.origin);
        yin.initialize(address(tx.origin), initialSupply);

        yin.approve(router, type(uint256).max);
        wcanto.approve(router, type(uint256).max);
        IBaseV1Router(router).addLiquidity(
            address(yin),
            address(wcanto),
            false,
            10 ** 17,
            10 ** 17,
            0,
            0,
            tx.origin,
            block.timestamp + 100
        );

        vm.stopBroadcast();

        console.log('export const NULL_ADDRESS = "%s";', address(0));
        console.log('export const WCANTO_ADDRESS = "%s";', address(wcanto));
        // console.log('export const NOTE_ADDRESS = "%s";', address(note));
        console.log('export const YIN_ADDRESS = "%s";', address(yin));
        console.log(
            'export const YIN_ADDER_ADDRESS = "%s";',
            address(yin.liquidityAdder())
        );
        console.log(
            'export const PAIR_YIN_WCANTO_ADDRESS = "%s";',
            address(yin.pair())
        );
    }
}
