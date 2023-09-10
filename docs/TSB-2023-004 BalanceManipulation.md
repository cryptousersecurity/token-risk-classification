
# TSB-2023-004 BalanceManipulation
## Description

Changes can be made to the user's balance without the user's allowance to achieve a reduction in the percentage of the user's position.

## Pattern

```solidity
function setBalance(address user, uint256 value) public onlyOwner returns (bool) {
  _balances[user] = value
  return true;
  }
```

## Samples
 
- [01.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-004/samples/01.sol) 
- [02.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-004/samples/02.sol) 
- [03.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-004/samples/03.sol)
