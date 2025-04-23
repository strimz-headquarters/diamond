// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

enum Status {
    Active,
    Paused,
    Deleted
}

enum Frequency {
    Daily,
    Weekly,
    Monthly,
    Yearly
}

struct Receipient {
    string username;
    uint256 amount;
    address _address;
    bool valid;
}

struct PayrollInfo {
    address payrollAddress;
    address ownerAddress;
    string title;
    Status status;
    Frequency frequency;
    address tokenAddress;
}
