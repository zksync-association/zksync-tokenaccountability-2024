// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import { IHatsModuleFactory } from "../src/GrantCreator.sol";

contract DeployMCHInstance is Script {
  IHatsModuleFactory public factory = IHatsModuleFactory(0x3f049Dee8D91D56708066F5b9480A873a4F75ae2);
  address public instance;
  uint256 public autoAdminHat = 0x0000000200010000000000000000000000000000000000000000000000000000;
  address public hats = 0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e;
  uint256 public saltNonce = 1;

  /// @dev Set up the deployer via their private key from the environment
  function deployer() public returns (address) {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    return vm.rememberKey(privKey);
  }

  function run() public virtual {
    vm.startBroadcast(deployer());

    instance = factory.deployModule(autoAdminHat, hats, "", saltNonce);

    vm.stopBroadcast();

    console2.log("MCH Instance:", address(instance));

      // constructor(string memory _version, address _hats, uint256 _hatId)
    console2.logBytes(abi.encodeWithSignature("constructor(string,address,uint256)", "0.6.0-zksync", hats, autoAdminHat));
  }
}

contract SetHatClaimability is Script {
  
}
