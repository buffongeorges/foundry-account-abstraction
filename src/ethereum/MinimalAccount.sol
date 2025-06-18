// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
  // entry point => this contract
      /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
  error MinimalAccount__NotFromEntryPoint();
  error MinimalAccount__NotFromEntryPointOrOwner();
  error MinimalAccount__CallFailed(bytes);

  

      /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  IEntryPoint private immutable i_entryPoint;

      /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

  modifier requireFromEntryPoint() {
    if (msg.sender != address(i_entryPoint)) {
      revert MinimalAccount__NotFromEntryPoint();
    }
    _;
  }

  modifier requireFromEntryPointOrOwner() {
    if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
      revert MinimalAccount__NotFromEntryPointOrOwner();
    }
    _;
  }

      /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  constructor(address entryPoint) Ownable(msg.sender) {
    i_entryPoint = IEntryPoint(entryPoint);
  }

  receive() external payable {} // this contract should be able to accept funds in order to pay for transactions
  // when alt mempools sends a transactions it will pull the funds from here that we payed from _payPrefund(). 
  // So our smart contracts needs to be able to accept funds first of all

  /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function execute(address dest, uint256 value, bytes calldata functionData) external requireFromEntryPointOrOwner {
    (bool success, bytes memory result) = dest.call{value: value}(functionData);

    if (!success) {
      revert MinimalAccount__CallFailed(result);
    }
  }

  // A signature is valid if it's the MinimalAccount owner
  function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external requireFromEntryPoint returns (uint256 validationData) {
    validationData = _validateSignature(userOp, userOpHash);
    // Additionnally we can :
    // _validateNonce() // we can keep track of the nonce, which will be passed in userOp
    _payPrefund(missingAccountFunds); // pay back money to the entry point/whoever send the tx
  }

      /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  // userOpHash=EIP-191 version of the signed hash
  function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash) internal view returns (uint256 validationData) {
    bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
    address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature); // ECDSA.recover will return who did this signing
    if (signer != owner()) {
      return SIG_VALIDATION_FAILED;
    }
    // in here we can add the logic we want on the signature (check if multi sig is OK, check if Google auth ...)
    return SIG_VALIDATION_SUCCESS;
  }

  function _payPrefund(uint256 missingAccountFunds) internal {
    if (missingAccountFunds != 0) {
      (bool success, ) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}('');
      (success);
    }
  }

      /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
  function getEntryPoint() external view returns (address) {
    return address(i_entryPoint);
  }
}