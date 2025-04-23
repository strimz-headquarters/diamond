// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

interface IDiamond {
    function list_user(address user, uint8 amount) external;

    function disburse() external;

    function stake(uint _amount, uint8 _poolId) external;
}
