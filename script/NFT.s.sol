// SPDX-License-Identifier: MIT
pragma solidity = 0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {NFTWhiteList} from "../src/NFT.sol";

contract NFT is NFTWhiteList {
    constructor(bytes32 _root,address _signer,uint256 subscriptionId) 
        NFTWhiteList(_root, _signer, subscriptionId) 
    {}
}


contract NFTScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("DEV_PRIVATE_KEY");
        address account = vm.addr(privateKey);

        console.log("Account", account);

        vm.startBroadcast(privateKey);

        NFT nft = new NFT(0x5159467ff4fb8de8f3a8ec1c9ba54edad80d037ec7849a81f032bd0f7aab46a4, 0x7F72dDF0e619F9B1600D9B68979BD5a3F21C01E7, 5564272400328011146772289648250464027751378309997966949718957330259599796679);

        vm.stopBroadcast();
    }
}
