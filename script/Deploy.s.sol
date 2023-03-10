// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/LiquidityAdder.sol";
import "../src/Temple.sol";
import "../src/BasicDistributor.sol";

contract DeployScript is Script {
    uint256 initialSupply = 10 ** 7 * 10 ** 18;
    uint256 minAmountToSell = 1000 * 10 ** 18;
    uint256 blockTime = 6;
    uint256 blockPerDay = 86400 / blockTime;
    uint256 rewardPerDay = 10 ** 23;
    uint256 rewardsPerBlock = rewardPerDay / blockPerDay;
    uint256 epochPeriod = 2 * 86400;
    uint16 depositFee = 500;
    uint256 startBlock = 3180000;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
    address atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
    address cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
    address cantoShib = address(0xA025ced4aab666c1bbBFd5A224816705b438E50B);
    ERC20 wcanto;
    Garden garden;
    Temple temple;

    function setUp() public {
        vm.deal(tx.origin, 100 ether);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        wcanto = ERC20(IBaseV1Router(router).weth());

        YinYang yin = new YinYang(
            tx.origin,
            "Yin",
            "YIN",
            600,
            router,
            address(wcanto),
            minAmountToSell,
            3333,
            1666,
            3333
        );
        YinYang yang = new YinYang(
            tx.origin,
            "Yang",
            "YANG",
            600,
            router,
            address(wcanto),
            minAmountToSell,
            3333,
            1666,
            3333
        );
        Zen zen = new Zen(tx.origin);
        zen.setPairs(router);

        BasicDistributor yinDistributor = new BasicDistributor(
            tx.origin,
            rewardsPerBlock,
            startBlock,
            ERC20(address(yin))
        );
        BasicDistributor yangDistributor = new BasicDistributor(
            tx.origin,
            rewardsPerBlock,
            startBlock,
            ERC20(address(yang))
        );

        yin.excludeAccount(address(yinDistributor));
        yin.initialize(address(yinDistributor), initialSupply);
        yang.excludeAccount(address(yangDistributor));
        yang.initialize(address(yangDistributor), initialSupply);

        temple = new Temple(
            tx.origin,
            block.timestamp,
            epochPeriod,
            yin,
            yang,
            zen,
            router
        );
        yin.excludeAccount(address(temple));
        yin.setTemple(address(temple));
        yang.excludeAccount(address(temple));
        yang.setTemple(address(temple));
        zen.transferOwnership(address(temple));

        garden = new Garden(
            tx.origin,
            rewardsPerBlock,
            0,
            address(temple.zen()),
            address(temple)
        );
        temple.setGarden(garden);

        // Create pools
        garden.add(1, ERC20(yin.pair()), 0, true, 0);
        garden.add(1, ERC20(yang.pair()), 0, true, 0);
        garden.add(10, ERC20(zen.pair()), 0, true, 0);

        yinDistributor.add(40, ERC20(address(yang.pair())), 0, true, 0);
        yinDistributor.add(10, ERC20(address(yang)), 0, true, 0);
        yinDistributor.add(5, ERC20(address(cantoShib)), depositFee, true, 0);
        yinDistributor.add(3, ERC20(address(eth)), depositFee, true, 0);
        yinDistributor.add(1, ERC20(address(wcanto)), depositFee, true, 0);
        yangDistributor.add(40, ERC20(address(yin.pair())), 0, true, 0);
        yangDistributor.add(10, ERC20(address(yin)), 0, true, 0);
        yangDistributor.add(5, ERC20(address(cantoInu)), depositFee, true, 0);
        yangDistributor.add(3, ERC20(address(atom)), depositFee, true, 0);
        yangDistributor.add(1, ERC20(address(wcanto)), depositFee, true, 0);

        vm.stopBroadcast();

        console.log('export const NULL_ADDRESS = "%s";', address(0));
        console.log('export const WCANTO_ADDRESS = "%s";', address(wcanto));
        // console.log('export const NOTE_ADDRESS = "%s";', address(note));
        console.log('export const YIN_ADDRESS = "%s";', address(yin));
        console.log(
            'export const YIN_ADDER_ADDRESS = "%s";',
            address(yin.liquidityAdder())
        );
        console.log('export const YANG_ADDRESS = "%s";', address(yang));
        console.log(
            'export const YANG_ADDER_ADDRESS = "%s";',
            address(yang.liquidityAdder())
        );
        console.log('export const ZEN_ADDRESS = "%s";', address(zen));
        console.log(
            'export const PAIR_YIN_WCANTO_ADDRESS = "%s";',
            address(yin.pair())
        );
        console.log(
            'export const PAIR_YANG_WCANTO_ADDRESS = "%s";',
            address(yang.pair())
        );
        console.log(
            'export const PAIR_ZEN_WCANTO_ADDRESS = "%s";',
            address(zen.pair())
        );
        console.log(
            'export const YIN_DISTRIBUTOR_ADDRESS = "%s";',
            address(yinDistributor)
        );
        console.log(
            'export const YANG_DISTRIBUTOR_ADDRESS = "%s";',
            address(yangDistributor)
        );
        console.log('export const GARDEN_ADDRESS = "%s";', address(garden));
        console.log('export const TEMPLE_ADDRESS = "%s";', address(temple));
    }
}
