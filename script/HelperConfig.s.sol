// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
  error HelperConfig__InvalidChainId();

  struct NetworkConfig{
    address entryPoint;
    address account;

  }

  uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
  uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
  uint256 constant LOCAL_CHAIN_ID = 31337;
  address constant BURNER_WALLET = 0xc46C866e8D6E2CCa79c6Ab8a67F4b5b29Ad91e92;
  address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
  address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

  NetworkConfig public localNetworkConfig;
  mapping(uint256 chainId => NetworkConfig) public networkConfigs;

  constructor() {
    networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
  }

  function getConfig() public returns (NetworkConfig memory) {
    return getConfigByChainId(block.chainid);
  }

  function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
    if (chainId == LOCAL_CHAIN_ID) {
      return getOrCreateAnvilEthConfig();
    } else if (networkConfigs[chainId].account != address(0)) {
      return networkConfigs[chainId];
    } else {
      revert HelperConfig__InvalidChainId();
    }
  }

  function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
    return NetworkConfig({
      entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
      // usdc: 0x53844F9577C2334e541Aec7Df7174ECe5dF1fCf0, // Update with your own mock token
      account: BURNER_WALLET
    });
  }

  function getZkSyncConfig() public pure returns (NetworkConfig memory) {
    return NetworkConfig({
      entryPoint: address(0), // supports native AA, so no entry point needed
      // usdc: 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4,
      account: BURNER_WALLET
    });
  }

  function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
    if (localNetworkConfig.account != address(0)) {
      return localNetworkConfig;
    }


    // deploy a mock entry point contract...
    console2.log("Deploying mocks...");
    vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
    EntryPoint entryPoint = new EntryPoint();
    vm.stopBroadcast();
    
    localNetworkConfig = NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

    return localNetworkConfig;
  }
}