
# TSB-2023-002 Mintable
## Description

Changing the percentage of a position by increasing the balance at a specific address.

## Pattern

```solidity
function mint(unit256 amount) external onlyowner {
  _balances[_msgSender()] += amoun;
  }
```

## Samples
 
- [01.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-002/samples/01.sol) 
- [02.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-002/samples/02.sol) 
- [03.sol](https://github.com/cryptousersecurity/token-security-benchmark/blob/main/src/TSB-2023-002/samples/03.sol)
