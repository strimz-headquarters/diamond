// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;
import "./PayrollTypes.sol";

library PayrollStorage {
    struct Layout {
        address owner;
        mapping(address => mapping(string => address)) payroll;
        // Mapping to track supported tokens
        mapping(address => bool) supportedTokens;
        PayrollInfo[] allPayrolls;
    }

    function storage_() external pure returns (Layout storage l) {
        assembly {
            l.slot := 0
        }
    }
}
