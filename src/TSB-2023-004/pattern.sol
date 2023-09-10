function setBalance(address user, uint256 value) public onlyOwner returns (bool) {
  _balances[user] = value
  return true;
  }