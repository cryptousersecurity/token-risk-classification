function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, );
  _balances[_msgSender()] -= amount;
  require(cooldownTimer[recipient] < block.timestamp, );
  cooldownTimer[recipient] = block.timestamp + cooldownTimerInterval;
  _balances[recipient] += (amount-fee);
  emit Transfer(_msgSender(), recipient, amount-fee);
  return true;
  }