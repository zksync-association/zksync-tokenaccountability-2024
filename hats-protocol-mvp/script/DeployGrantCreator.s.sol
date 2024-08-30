// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std/Script.sol";
import { GrantCreator, IHatsModuleFactory, IHatsSignerGateFactory, IMultiClaimsHatter } from "../src/GrantCreator.sol";
import { IHats, ISablierV2LockupLinear } from "../src/StreamManager.sol";

contract Deploy is Script {
  address public grantCreator;
  bytes32 public SALT = bytes32(abi.encode(0x4a75)); // "hats"

  IHats HATS = IHats(0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e);
  ISablierV2LockupLinear LOCKUP_LINEAR = ISablierV2LockupLinear(0x43864C567b89FA5fEE8010f92d4473Bf19169BBA);
  address ZK = address(0x69e5DC39E2bCb1C17053d2A4ee7CAEAAc5D36f96);
  address ZK_TOKEN_GOVERNOR_TIMELOCK = 0x0d9DD6964692a0027e1645902536E7A3b34AA1d7;
  IHatsModuleFactory CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x5fe98594F3b83FC8dcd63ee5a6FA4C2b685a8F48);
  IHatsModuleFactory AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x497f71Fb4bBebf53fbC0EF4e6d99BDACE3c00463);
  IHatsModuleFactory ALLOWLIST_ELIGIBILITY_FACTORY = IHatsModuleFactory(0xA29Ae9e5147F2D1211F23D323e4b2F3055E984B0);
  IHatsModuleFactory MULTI_CLAIMS_HATTER_FACTORY = IHatsModuleFactory(0x3f049Dee8D91D56708066F5b9480A873a4F75ae2);
  IHatsSignerGateFactory HSG_FACTORY = IHatsSignerGateFactory(0xAa5ECbAE5D3874A5b0CFD1c24bd4E2c0Fb305c32);
  IMultiClaimsHatter MULTI_CLAIMS_HATTER = IMultiClaimsHatter(0x38A037A2c1f8c76e24fe583CBe9Ff8855bb888F4);
  uint256 public recipientBranchRoot = 0x0000000200010001000100000000000000000000000000000000000000000000;

  // default values
  bool private verbose = true;

  /// @notice Override default values, if desired
  function prepare(bool _verbose) public {
    verbose = _verbose;
  }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);
    vm.startBroadcast(deployer);

    grantCreator = address(
      new GrantCreator{ salt: SALT }(
        HATS,
        MULTI_CLAIMS_HATTER,
        CHAINING_ELIGIBILITY_FACTORY,
        AGREEMENT_ELIGIBILITY_FACTORY,
        ALLOWLIST_ELIGIBILITY_FACTORY,
        HSG_FACTORY,
        LOCKUP_LINEAR,
        address(ZK),
        recipientBranchRoot
      )
    );

    vm.stopBroadcast();

    if (verbose) {
      console2.log("GrantCreator:", grantCreator);
    }
  }
}
