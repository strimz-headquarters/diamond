// SPDX-License-Identifier: SEE LICENSE IN LICENSE
import "../libraries/PayrollTypes.sol";

pragma solidity ^0.8.8;

interface IPayroll {
    function getPayrollDetails()
        external
        view
        returns (
            address _token,
            Status _status,
            Frequency _frequency,
            uint256 _lastPayroll,
            uint256 _startDate
        );

    function getRecipients() external view returns (Receipient[] memory);

    function add_receipients(Receipient[] memory _new_receipients) external;

    function remove_receipients(address[] calldata _receipients) external;

    function getStatus() external view returns (Status);

    function getLastPayrollDate() external view returns (uint256);

    function getFrequency() external view returns (Frequency);

    function getTokenAddress() external view returns (address);

    function disburse() external;

    function getTotalAmountToDisburse() external view returns (uint256);

    function getOwner() external view returns (address);

    function update_status(Status _status) external;

    function update_frequency(Frequency _frequency) external;

    function update_token(address _token) external;

    function deposit(address _token, uint256 amount) external;

    function withdraw(address _token, uint256 amount) external;

    function getUserBalance(
        address user,
        address _token
    ) external view returns (uint256);
}
