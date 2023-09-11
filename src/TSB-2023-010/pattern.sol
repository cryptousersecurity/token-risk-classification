function _transfer(address from, address recipient, uint256 amount) internal virtual override returns (bool) {
  require(_balances[_msgSender()] >= amount, );
  _balances[_msgSender()] -= amount;
  uint256 fee = amount.mul(feeRate).div(100);
  _balances[recipient] += (amount-fee);
  emit Transfer(_msgSender(), recipient, amount-fee);
  return true;
}
 
function setFee(uint256 _fee) external onlyOwner{
  fee = _fee;
}