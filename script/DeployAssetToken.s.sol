// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployAssetToken
 * @dev Deployment script for AssetToken V1
 * @notice This script deploys the V1 implementation, creates an ERC1967Proxy, and initializes it
 */
contract DeployAssetToken is Script {
    function run() external returns (address proxyAddress, address implementationAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY"); // In wei (e.g., 1000000 * 10^18)

        vm.startBroadcast(deployerPrivateKey);

        // Deploy V1 implementation
        AssetToken implementation = new AssetToken();
        implementationAddress = address(implementation);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            AssetToken.initialize.selector,
            "Xault Asset Token",
            "XAT",
            maxSupply,
            admin
        );

        // Deploy ERC1967Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        proxyAddress = address(proxy);

        // Cast proxy to AssetToken interface for verification
        AssetToken assetToken = AssetToken(proxyAddress);

        // Verify deployment
        require(assetToken.maxSupply() == maxSupply, "Max supply mismatch");
        require(assetToken.hasRole(assetToken.DEFAULT_ADMIN_ROLE(), admin), "Admin role not set");

        vm.stopBroadcast();

        console.log("AssetToken Implementation deployed at:", implementationAddress);
        console.log("AssetToken Proxy deployed at:", proxyAddress);
        console.log("Max Supply:", maxSupply);
        console.log("Admin Address:", admin);
    }
}
