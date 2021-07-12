// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IBep20.sol";
import "./IFeeCalculator.sol";


contract Enosis is Context, IBEP20, Ownable {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  IFeeCalculator private _feeContract;
  
  uint256 private _feeTimestamp;
  uint256 private _maxFee;
  uint256 private _feeAmount;
  bool private _feeEnabled;

  address private _stakingContract;
  uint256 private _totalSupply;
  uint8 private _decimals;
  string private _symbol;
  string private _name;

  constructor(address stakingContract) {
    _name = "Enosis";
    _symbol = "ENOS";
    _decimals = 8;
    _totalSupply = 2 * 10 ** 16;
    _balances[_msgSender()] = _totalSupply;
    _maxFee = 1;
    _feeEnabled = false;
    _stakingContract = stakingContract;

    emit Transfer(address(0), _msgSender(), _totalSupply);
  }

  event NewFeeCalculator(address indexed _newFeeCalculator);
  event FeeAmountUpdated(uint256 indexed _newFeeAmount, address indexed _feeCalculator);

  /**
   * @dev Returns the bep token owner.
   */
  function getOwner() public virtual override view returns (address) {
    return owner();
  }

  /**
   * @dev Returns the token decimals.
   */
  function decimals() public virtual override view returns (uint8) {
    return _decimals;
  }

  /**
   * @dev Returns the token symbol.
   */
  function symbol() public virtual override view returns (string memory) {
    return _symbol;
  }

  /**
  * @dev Returns the token name.
  */
  function name() public virtual override view returns (string memory) {
    return _name;
  }

  /**
   * @dev See {BEP20-totalSupply}.
   */
  function totalSupply() public virtual override view returns (uint256) {
    return _totalSupply;
  }

  /**
   * @dev See {BEP20-balanceOf}.
   */
  function balanceOf(address account) public virtual override view returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev See {BEP20-transfer}.
   *
   * Requirements:
   *
   * - `recipient` cannot be the zero address.
   * - the caller must have a balance of at least `amount`.
   */
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev See {BEP20-allowance}.
   */
  function allowance(address owner, address spender) public virtual override view returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
   * @dev See {BEP20-approve}.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev See {BEP20-transferFrom}.
   *
   * Emits an {Approval} event indicating the updated allowance. This is not
   * required by the EIP. See the note at the beginning of {BEP20};
   *
   * Requirements:
   * - `sender` and `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   * - the caller must have allowance for `sender`'s tokens of at least
   * `amount`.
   */
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  /**
   * @dev Atomically increases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   */
  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  /**
   * @dev Atomically decreases the allowance granted to `spender` by the caller.
   *
   * This is an alternative to {approve} that can be used as a mitigation for
   * problems described in {BEP20-approve}.
   *
   * Emits an {Approval} event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `spender` must have allowance for the caller of at least
   * `subtractedValue`.
   */
  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  /**
   * @dev Recalculates fee amount per transaction through the feeCalculator contract.
   *
   *
   * Emits an {FeeAmountUpdated} event indicating fee's amount have been updated.
   *
   * Requirements:
   *
   * - `_feeContract` using IFeeCalculator interface for FeeCalculator contract.
   */
  function refreshFeeAmount() public {
    _feeAmount =_feeContract.getFeeAmount();
    _feeTimestamp = block.timestamp;
    emit FeeAmountUpdated(_feeAmount, address(_feeContract));
  }

  /**
   * @dev Set the new FeeCalculator contract and refresh the fee's amount
   *
   *
   * Emits an {NewFeeCalculator} event indicating FeeCalculator contract has been modified.
   *
   * Requirements:
   *
   * - `newFeeCalculatorAddress` cannot be the zero address.
   */
  function setNewFeeCalculator(address newFeeCalculatorAddress) public onlyOwner {
    require(newFeeCalculatorAddress != address(0), "New FeeCalculator contract cannot be at the zero address");
    _feeEnabled = true;
    _feeContract = IFeeCalculator(newFeeCalculatorAddress);

    emit NewFeeCalculator(newFeeCalculatorAddress);
    refreshFeeAmount();
  }

  /**
   * @dev Takes fee from transaction amount.
   * Remove `_feeAmount` from transaction amount. 
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `amount`
   */
  function _takeFee(address sender, uint256 amount) internal returns (uint256) {
    if (block.timestamp >= _feeTimestamp.add(86400))
      refreshFeeAmount();
    uint256 currentFee = (amount.mul(2)).div(100);
    if (currentFee > _feeAmount)
      currentFee = _feeAmount;

    amount = amount.sub(currentFee);
    uint256 burnAmount = (currentFee.mul(4)).div(10);

    _burn(sender, burnAmount);
    _balances[_stakingContract] = _balances[_stakingContract].add(currentFee.sub(burnAmount));
    _balances[sender] = _balances[sender].sub(currentFee.sub(burnAmount));
    return (amount);
  }

  /**
   * @dev Moves tokens `amount` from `sender` to `recipient`.
   *
   * This is internal function is equivalent to {transfer}, and can be used to
   * e.g. implement automatic token fees, slashing mechanisms, etc.
   *
   * Emits a {Transfer} event.
   *
   * Requirements:
   *
   * - `sender` cannot be the zero address.
   * - `recipient` cannot be the zero address.
   * - `sender` must have a balance of at least `amount`.
   */
  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");

    if (_feeEnabled == true)
      amount = _takeFee(sender, amount);

    _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  /**
   * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
   *
   * This is internal function is equivalent to `approve`, and can be used to
   * e.g. set automatic allowances for certain subsystems, etc.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `owner` cannot be the zero address.
   * - `spender` cannot be the zero address.
   */
  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
   * from the caller's allowance.
   *
   * See {_burn} and {_approve}.
   */
  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
  }
}
