// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
  using MessageHashUtils for bytes32;

  HelperConfig helperConfig;
  MinimalAccount minimalAccount;
  ERC20Mock usdc;
  uint256 AMOUNT = 1e18;
  SendPackedUserOp sendPackedUserOp;

  address randomUser = makeAddr('randomUser');

  function setUp() public {
    DeployMinimal deployMinimal = new DeployMinimal();
    (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
    usdc = new ERC20Mock();
    sendPackedUserOp = new SendPackedUserOp();
  }

  // USDC Mint
  // msg.sender -> MinimalAccount
  // approve some amount 
  // USDC contract
  // come from the entrypoint

  function testOwnerCanExecuteCommands() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

    // Act
    vm.prank(minimalAccount.owner());
    minimalAccount.execute(destination, value, functionData);

    // Assert
    assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
  }

  function testNonOwnerCannotExecuteCommands() public {
     // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

    // Act
    vm.prank(randomUser);
    vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
    minimalAccount.execute(destination, value, functionData);
  }

  function testRecoverSignedOp() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, functionData); // this executeCallData is saying EntryPoint contract call our contract (execute) and then our contract will call USDC
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
    bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

    // Act
    address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

    // Assert
    assertEq(actualSigner, minimalAccount.owner());
  }


  // 1. Sign user ops
  // 2. Call validate userops
  // 3. Assert the return is correct
  function testValidationOfUserOps() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, functionData); // this executeCallData is saying EntryPoint contract call our contract (execute) and then our contract will call USDC
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
    bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
    uint256 missingAccountFunds = 1e18;

    // Act;
    vm.prank(helperConfig.getConfig().entryPoint);
    uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

    assertEq(validationData, 0); // 0 = SUCCESS, 1 = FAILURE
  }

  function testEntryPointCanExecuteCommands() public {
    // Arrange
    assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    address destination = address(usdc);
    uint256 value = 0;
    bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
    bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, destination, value, functionData); // this executeCallData is saying EntryPoint contract call our contract (execute) and then our contract will call USDC
    PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(executeCallData, helperConfig.getConfig(), address(minimalAccount));
    bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

    vm.deal(address(minimalAccount), 1e18);

    PackedUserOperation[] memory ops = new PackedUserOperation[](1);
    ops[0] = packedUserOp;

    // Act
    vm.prank(randomUser);
    IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

    // Assert
    assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
  }
}