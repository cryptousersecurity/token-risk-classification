function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, );
  _balances[_msgSender()] -= amount;
  require(amount <= maxAmount,);
  _balances[recipient] += (amount-fee);
  emit Transfer(_msgSender(), recipient, amount-fee);
  return true;
}
 
function setMaxAmount(uint256 _maxAmount) external onlyOwner {
  maxAmount = _maxAmount;
}