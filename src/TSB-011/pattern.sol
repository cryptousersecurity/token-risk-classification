function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount,);
  require(tradeEnabled,);
  _balances[_msgSender()] -= amount;
  _balances[recipient] += amount;
  emit Transfer(_msgSender(), recipient, amount);
  return true;
}
 
function setTradeEnabled(bool _enabled) external onlyOwner {
  tradeEnabled = _enabled;
}