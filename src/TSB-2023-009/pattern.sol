function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, );
  require(_balances(from).sub(amount)>=1*10**18,);
  _balances[_msgSender()] -= amount;
  _balances[recipient] += amount;
  emit Transfer(_msgSender(), recipient, amount);
  return true;
  }