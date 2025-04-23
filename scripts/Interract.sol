// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;
import "../contracts/interfaces/IDiamond.sol";

contract Interract {
    IDiamond diamond;

    function run() external {
        diamond = IDiamond(0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0);
    }
}
