// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/LiquidityAdder.sol";
import "../src/Temple.sol";
import "../src/BasicDistributor.sol";

contract DeployScript is Script {
    uint256 initialSupply = 10 ** 6 * 10 ** 18;
    uint256 minAmountToSell = 10 * 10 ** 18;
    uint256 blockTime = 6;
    uint256 blockPerDay = 86400 / blockTime;
    uint256 rewardPerDay = 10 ** 22;
    uint256 rewardsPerBlock = rewardPerDay / blockPerDay;
    uint256 epochPeriod = 600;
    uint256 startBlock;
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
    address atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
    address cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
    address cantoShib = address(0xA025ced4aab666c1bbBFd5A224816705b438E50B);
    ERC20 wcanto;
    ERC20 note = ERC20(address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503));
    Garden garden;
    Temple temple;

    function setUp() public {
        vm.deal(tx.origin, 100 ether);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // TODO: Set a date
        startBlock = block.number;

        vm.startBroadcast(deployerPrivateKey);

        wcanto = ERC20(IBaseV1Router(router).WETH());

        YinYang yin = new YinYang(
            tx.origin,
            "Yin",
            "YIN",
            500,
            router,
            address(note),
            minAmountToSell
        );
        YinYang yang = new YinYang(
            tx.origin,
            "Yang",
            "YANG",
            500,
            router,
            address(wcanto),
            minAmountToSell
        );
        Zen zen = new Zen(tx.origin);
        zen.setPairs(router, address(note));

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
            address(note),
            router
        );
        yin.setTemple(address(temple));
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
        garden.add(1, ERC20(yin.pair()), true, startBlock);
        garden.add(1, ERC20(yang.pair()), true, startBlock);
        garden.add(10, ERC20(zen.zenNotePair()), true, startBlock);
        garden.add(10, ERC20(zen.zenWCantoPair()), true, startBlock);

        yinDistributor.add(10, ERC20(address(yang)), true, startBlock);
        yinDistributor.add(5, ERC20(address(cantoShib)), true, startBlock);
        yinDistributor.add(3, ERC20(address(eth)), true, startBlock);
        yinDistributor.add(1, ERC20(address(note)), true, startBlock);
        yangDistributor.add(10, ERC20(address(yin)), true, startBlock);
        yangDistributor.add(5, ERC20(address(cantoInu)), true, startBlock);
        yangDistributor.add(3, ERC20(address(atom)), true, startBlock);
        yangDistributor.add(1, ERC20(address(wcanto)), true, startBlock);

        vm.stopBroadcast();

        console.log('export const NULL_ADDRESS = "%s";', address(0));
        console.log('export const WCANTO_ADDRESS = "%s";', address(wcanto));
        console.log('export const NOTE_ADDRESS = "%s";', address(note));
        console.log('export const YIN_ADDRESS = "%s";', address(yin));
        console.log('export const YANG_ADDRESS = "%s";', address(yang));
        console.log('export const ZEN_ADDRESS = "%s";', address(zen));
        console.log(
            'export const PAIR_YIN_NOTE_ADDRESS = "%s";',
            address(yin.pair())
        );
        console.log(
            'export const PAIR_YANG_WCANTO_ADDRESS = "%s";',
            address(yang.pair())
        );
        console.log(
            'export const PAIR_ZEN_NOTE_ADDRESS = "%s";',
            address(zen.zenNotePair())
        );
        console.log(
            'export const PAIR_ZEN_WCANTO_ADDRESS = "%s";',
            address(zen.zenWCantoPair())
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
