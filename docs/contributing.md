# Contribution Guidelines

This document describes the contribution guidelines for the Token Security Benchmark project. We welcome any contributions including adding new risk types, adding new risk samples, and updating the documentation, etc.

## Risk Type Format

All risk types are defined under [src](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/src) folder with the name of the risk type ID. For example, `TSB-2023-001`. The folder should contain the following folders and files:

`metadata.json`: This file contains the metadata of the risk type. The metadata should be in the following format:
```json
{
  "id": "Risk Type ID",
  "name": "Risk Type Name",
  "description": "Risk Type Description",
  "samples": [
    {
      "name": "01.sol"
    },
    {
      "name": "02.sol",
      "start": 1,
      "end": 10
    },
    {
      "name": "03.sol"
    }
  ]
}
```
The fields in the metadata are:

- `id`: The risk type ID.
- `name`: The name of the risk type.
- `description`: The description of the risk type.
- `samples`: The list of sample contracts. Each sample contract should have a `name` field. If you want to specify the start line and end line of the risk code snippet in the contract, you can add `start` and `end` fields to the sample contract. The line numbers should be 1-indexed.

`samples` folder: This folder contains the sample contracts that demonstrate the risk type. The sample contracts should be named as `NN.sol`, e.g., `01.sol`, `02.sol`, `03.sol`, etc.

`pattern.sol`(optional): This file should contain the risk pattern, which is the code snippet that demonstrates the risk type. The code snippet should be in solidity.

## Contribute New Risk Samples

### Add New Risk Samples to samples Folder

If you want to add new risk samples to an existing risk type, you can add the new risk samples to the `samples` folder of the risk type folder under [src](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/src). The sample contracts should be named as `NN.sol`, e.g., `01.sol`, `02.sol`, `03.sol`, etc.

### Update metadata.json

Update the `samples` field in the `metadata.json` file of the risk type folder under [src](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/src).

## Contribute New Risk Types

### Request a Risk Type ID

Risk Type ID is defined in format `TSB-YYYY-NNN` where `YYYY` is the year and `NNN` is the number of the risk type in that year. For example, `TSB-2023-001` is the first risk type in 2023.
Before adding a new risk type, please check if the risk type ID is already taken. If not, please request a new risk type ID by creating an issue in this repository. You can check the taken risk type IDs in under [src](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/src) folder.

### Create a new Risk Type Folder

Create a folder under [src](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/src) folder with the name of the risk type ID. Add folders and files based on the [Risk Type Format](#risk-type-format) section.

## Update Documentation
Everytime you add a new risk type or add new risk samples to an existing risk type, please update the documentation by executing the following command:
```bash
make generate-docs
```
This command will generate the documentation in [docs](https://github.com/cryptousersecurity/token-security-benchmark/tree/main/docs) folder.
You can also preview the change by serving the documentation locally:
```bash
mkdocs serve
```
The documentation will be served at `http://localhost:8000/`.
