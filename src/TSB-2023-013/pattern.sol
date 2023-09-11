function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, );
  _balances[_msgSender()] -= amount;
  uint256 fee = amount.mul(feeRate).div(100);
  if (whitelist[msg.sender] == ture)
  fee = 0;
  _balances[recipient] += (amount-fee);
  emit Transfer(_msgSender(), recipient, amount-fee);
  return true;
}