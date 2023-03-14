// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/LiquidityAdder.sol";
import "../src/Temple.sol";
import "../src/BasicDistributor.sol";

contract ClaimTurnstile is Script {
    address WCANTO_ADDRESS =
        address(0x826551890Dc65655a0Aceca109aB11AbDbD7a07B);
    address YIN_ADDRESS = address(0x54CF7077B13c087eE74C9f686fdeb3De9A85C7c6);
    address YIN_ADDER_ADDRESS =
        address(0x63a30706fafAa41EF68d80E428d8B4d7C4C76Fc1);
    address YANG_ADDRESS = address(0x5D058F57a1B816E8Bf5228786c56F5589935208C);
    address YANG_ADDER_ADDRESS =
        address(0x480Bc014E09cdf1927d3f70c37029E6EC434A4A1);
    address ZEN_ADDRESS = address(0x21634aE7d8A1fde458BD268cCfA30BA4DA835F40);
    address PAIR_YIN_WCANTO_ADDRESS =
        address(0xEa3ae0d152c8f9b5D4567B87Eabc790921516080);
    address PAIR_YANG_WCANTO_ADDRESS =
        address(0x2f56DeA01B3080e717d051574075691E68DA710b);
    address PAIR_ZEN_WCANTO_ADDRESS =
        address(0x405ed2acd3d06AF7A6E3fCb1f4D6Bc90963dC8D1);
    address YIN_DISTRIBUTOR_ADDRESS =
        address(0xecC0d61a43b4a1469688627FC4998F60210f984c);
    address YANG_DISTRIBUTOR_ADDRESS =
        address(0x7e4B41888C61056723324eDe3fD083fAA81c01F1);
    address GARDEN_ADDRESS =
        address(0xf0FA2b95F209cE80c39B88621D5B99b17E1cd8aF);
    address TEMPLE_ADDRESS =
        address(0x67565F75d098F2FBC3f7BfAc40940BdfF0Ce7182);
    address router = address(0xe6e35e2AFfE85642eeE4a534d4370A689554133c);
    address eth = address(0x5FD55A1B9FC24967C4dB09C513C3BA0DFa7FF687);
    address atom = address(0xecEEEfCEE421D8062EF8d6b4D814efe4dc898265);
    address cantoInu = address(0x7264610A66EcA758A8ce95CF11Ff5741E1fd0455);
    address cantoShib = address(0xA025ced4aab666c1bbBFd5A224816705b438E50B);
    IERC20 wcanto;
    Garden garden;
    Temple temple;

    function setUp() public {
        vm.deal(tx.origin, 100 ether);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        Turnstile turnstile = Turnstile(
            address(0xEcf044C5B4b867CFda001101c617eCd347095B44)
        );
        console.log(
            "Yin claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(YIN_ADDRESS)) / 1e18
        );
        console.log(
            "Yang claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(YANG_ADDRESS)) / 1e18
        );
        console.log(
            "Zen claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(ZEN_ADDRESS)) / 1e18
        );
        console.log(
            "Yin ditributor claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(YIN_DISTRIBUTOR_ADDRESS)) /
                1e18
        );
        console.log(
            "Yang Distributor claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(YANG_DISTRIBUTOR_ADDRESS)) /
                1e18
        );
        console.log(
            "Garden claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(GARDEN_ADDRESS)) / 1e18
        );
        console.log(
            "Temple claimable CSR: ",
            turnstile.balances(turnstile.getTokenId(TEMPLE_ADDRESS)) / 1e18
        );

        vm.startBroadcast(deployerPrivateKey);
        vm.stopBroadcast();
    }
}
