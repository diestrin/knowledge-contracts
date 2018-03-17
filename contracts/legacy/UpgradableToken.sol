pragma solidity ^0.4.18;

import { Ownable } from '../utils/Ownable.sol';
import { SafeMath } from '../utils/SafeMath.sol';
import { ERC20TokenLegacy } from './ERC20Token.sol';


/**
 * A token upgrade mechanism where users can upgrade tokens
 * to the next smart contract revision.
 *
 * First envisioned by Golem and Lunyr projects.
 */
contract UpgradeableTokenLegacy is ERC20TokenLegacy, Ownable {
  using SafeMath for uint256;

  /** The next contract where the tokens will be migrated. */
  UpgradeableTokenLegacy public nextContract;

  /** The contract from which we upgrade */
  UpgradeableTokenLegacy public prevContract;

  /**
   * Somebody has upgraded some of their tokens.
   */
  event Upgrade(address indexed _from, address indexed _to, uint256 _value);
  event UpgradeFrom(address indexed _from, address indexed _to, uint256 _value);

  /**
   * Next contract available.
   */
  event NextContractSet(address contractAddress);

  /**
   * Previous contract available.
   */
  event PrevContractSet(address contractAddress);

  modifier canUpgrade() {
    require(address(nextContract) != 0x0);
    _;
  }

  modifier notUpgrading() {
    require(address(nextContract) == 0x0);
    _;
  }

  modifier destroyIfEmpty() {
    _;
    if (totalSupply == 0) {
      selfdestruct(owners[0]);
    }
  }

  modifier fromPrevContract() {
    require(msg.sender == address(prevContract));
    _;
  }

  /**
   * Upgrade the tokens from holder
   */
  function upgrade() canUpgrade destroyIfEmpty public returns (bool) {
    uint256 value = balances[msg.sender];

    assert(value > 0);

    // Take tokens out from circulation
    balances[msg.sender] = 0;
    totalSupply = totalSupply.sub(value);
    Transfer(msg.sender, address(0), value);

    // Upgrade contract reissues the tokens
    nextContract.upgradeFrom(msg.sender, value);
    Upgrade(msg.sender, address(nextContract), value);

    return true;
  }

  function upgradeFrom(address holder, uint256 value) fromPrevContract public returns (bool) {
    balances[holder] = value;
    Transfer(address(0), holder, value);
    UpgradeFrom(address(prevContract), holder, value);

    return true;
  }

  /**
   * Set an upgrade contract that handles the migration
   */
  function setNextContract(address contractAddress) onlyOwner notUpgrading public returns (bool) {
    require(contractAddress != 0x0);
    nextContract = UpgradeableTokenLegacy(contractAddress);

    // Make sure that token supplies match
    require(nextContract.totalSupply() == totalSupply);

    NextContractSet(nextContract);

    return true;
  }

  function setPrevContract(address contractAddress) onlyOwner public returns (bool) {
    require(contractAddress != 0x0);
    prevContract = UpgradeableTokenLegacy(contractAddress);

    PrevContractSet(prevContract);

    return true;
  }
}
