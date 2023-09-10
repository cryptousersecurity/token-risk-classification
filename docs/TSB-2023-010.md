
# TSB-2023-010 SlippageModification
## Description

The transaction tax rate is subject to modification.

## Pattern

```solidity
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
```

## Samples
 
- [01.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-010/samples/01.sol) 
- [02.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-010/samples/02.sol) 
- [03.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-010/samples/03.sol)
