// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

import "../interfaces/IERC20.sol";
import "../libraries/PayrollTypes.sol";
import "../interfaces/IPayroll.sol";

contract Payroll {
    address immutable factory;
    address owner;
    Receipient[] receipients;
    address token;
    Status status;
    uint256 last_payroll;
    uint256 start_date;
    Frequency frequency;
    // Track balances for all tokens
    mapping(address => mapping(address => uint256)) private userTokenBalances;
    // Track total balance of each token held by the contract
    mapping(address => uint256) public contractTokenBalances;

    event Deposit(
        address indexed from,
        address indexed tokenAddress,
        uint256 amount
    );

    event Withdrawal(
        address indexed to,
        address indexed tokenAddress,
        uint256 amount
    );

    event TokenAdded(address indexed tokenAddress);
    event TokenRemoved(address indexed tokenAddress);

    event Disburse(
        address indexed token,
        uint256 indexed receipients,
        uint256 indexed timestamp
    );

    constructor(
        Receipient[] memory _receipients,
        address _token,
        uint256 _start_date,
        Frequency _frequency
    ) {
        owner = tx.origin;
        factory = msg.sender;
        for (uint256 i = 0; i < _receipients.length; i++) {
            Receipient memory _receipient = _receipients[i];
            require(_receipient._address != address(0), "INVALID_ADDRESS");
            require(
                keccak256(abi.encodePacked(_receipient.username)) !=
                    keccak256(abi.encodePacked("")),
                "INVALID_USERNAME"
            );
            require(_receipient.amount > 0, "INVALID_AMOUNT");
            receipients.push(
                Receipient({
                    _address: _receipient._address,
                    amount: _receipient.amount,
                    username: _receipient.username,
                    valid: true
                })
            );
        }
        token = _token;
        start_date = _start_date;
        frequency = _frequency;
        status = Status.Active;
    }

    modifier OnlyOwner() {
        require(msg.sender == factory, "UNAUTHORIZED");
        require(tx.origin == owner, "UNAUTHORIZED");
        _;
    }

    function add_receipients(
        Receipient[] memory _new_receipients
    ) external OnlyOwner {
        for (uint256 i = 0; i < _new_receipients.length; i++) {
            Receipient memory _receipient = _new_receipients[i];
            require(_receipient._address != address(0), "INVALID_ADDRESS");
            require(
                keccak256(abi.encodePacked(_receipient.username)) !=
                    keccak256(abi.encodePacked("")),
                "INVALID_USERNAME"
            );
            require(_receipient.amount > 0, "INVALID_AMOUNT");
            receipients.push(
                Receipient({
                    _address: _receipient._address,
                    amount: _receipient.amount,
                    username: _receipient.username,
                    valid: true
                })
            );
        }
    }

    function remove_receipients(
        address[] calldata _receipients
    ) external OnlyOwner {
        for (uint256 i = 0; i < _receipients.length; i++) {
            require(_receipients[i] != address(0), "INVALID_ADDRESS");
            for (uint256 j = 0; j < receipients.length; j++) {
                if (receipients[j]._address == _receipients[i]) {
                    Receipient storage __rec = receipients[j];
                    __rec.valid = false;
                }
            }
        }
    }

    // Fixed deposit function in Payroll.sol
    function deposit(address _token, uint256 amount) external OnlyOwner {
        require(amount > 0, "INVALID_AMOUNT");
        IERC20 erc20 = IERC20(_token);

        // Transfer tokens from msg.sender (the factory) to contract instead of tx.origin
        bool success = erc20.transferFrom(msg.sender, address(this), amount);
        require(success, "TRANSFER_FAILED");

        // Update user's balance for this token - still using tx.origin for accounting
        userTokenBalances[tx.origin][_token] += amount;
        contractTokenBalances[_token] += amount;

        emit Deposit(tx.origin, _token, amount);
    }

    // Fixed withdraw function in Payroll.sol
    function withdraw(address _token, uint256 amount) external OnlyOwner {
        require(amount > 0, "INVALID_AMOUNT");

        // Check if the withdrawer has enough balance
        require(
            userTokenBalances[tx.origin][_token] >= amount,
            "INSUFFICIENT_BALANCE"
        );

        // Update balances first to prevent reentrancy
        userTokenBalances[tx.origin][_token] -= amount;
        contractTokenBalances[_token] -= amount;

        // Transfer tokens to tx.origin through msg.sender (the factory)
        IERC20 __token = IERC20(_token);
        bool success = __token.transfer(msg.sender, amount);
        require(success, "TRANSFER_FAILED");

        emit Withdrawal(tx.origin, _token, amount);
    }

    // New function to get user's balance for a specific token
    function getUserBalance(
        address user,
        address _token
    ) external view returns (uint256) {
        return userTokenBalances[user][_token];
    }

    // New function to get total balance for a specific token
    function getTotalTokenBalance(
        address _token
    ) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function update_frequency(Frequency _frequency) external OnlyOwner {
        frequency = _frequency;
    }

    function update_status(Status _status) external OnlyOwner {
        status = _status;
    }

    function update_token(address _token) external OnlyOwner {
        token = _token;
    }

    // Modified disburse function with balance check
    function disburse() external OnlyOwner {
        require(status == Status.Active, "INACTIVE_PAYROLL");
        require(isPayrollDue(), "PAYROLL_NOT_DUE");

        // Calculate total amount needed for disbursement
        uint256 totalRequired = 0;
        for (uint256 i = 0; i < receipients.length; i++) {
            if (receipients[i].valid) {
                totalRequired += receipients[i].amount;
            }
        }

        uint256 userBalance = userTokenBalances[owner][token];
        uint256 amount = getTotalAmountToDisburse();
        require(userBalance >= amount, "INSUFFICIENT_BALANCE");

        userTokenBalances[owner][token] -= amount;
        contractTokenBalances[token] -= amount;

        IERC20 erc20 = IERC20(token);
        uint chargeAmount;
        bool greaterThanFree = receipients.length > 3;
        for (uint256 i = 0; i < receipients.length; i++) {
            Receipient memory receipient = receipients[i];
            if (receipient.amount == 0) {
                continue;
            }
            if (receipient.valid) {
                bool success = erc20.transfer(
                    receipient._address,
                    receipient.amount
                );
                require(success, "TRANSFER_FAILED");
                if (greaterThanFree) {
                    bool isLargeEnough = receipient.amount >= 1000; // 0.1% fee means at least 1000 to have a meaningful fee

                    if (!isLargeEnough) {
                        chargeAmount += 10;
                        continue;
                        // revert("Amount is too small to calculate a clean fee");
                    }

                    uint256 fee = (receipient.amount * 1) / 1000; // 0.1% fee
                    chargeAmount += fee;
                }
            }
        }

        bool _success = erc20.transfer(address(1), chargeAmount);
        require(_success, "TRANSFER_FAILED");

        last_payroll = block.timestamp;

        emit Disburse(token, receipients.length, block.timestamp);
    }

    // Check if payroll is due
    function isPayrollDue() public view returns (bool) {
        uint256 nowTimestamp = block.timestamp;

        // If last payroll is not set, use the start date
        uint256 lastPayroll = last_payroll == 0 ? start_date : last_payroll;

        // Check the payroll frequency
        if (frequency == Frequency.Daily) {
            return nowTimestamp - lastPayroll >= 24 * 60 * 60; // 1 day in seconds
        } else if (frequency == Frequency.Weekly) {
            return nowTimestamp - lastPayroll >= 7 * 24 * 60 * 60; // 1 week in seconds
        } else if (frequency == Frequency.Monthly) {
            // Compare month and year for monthly payrolls
            uint256 lastMonth = getMonth(lastPayroll);
            uint256 currentMonth = getMonth(nowTimestamp);
            uint256 lastYear = getYear(lastPayroll);
            uint256 currentYear = getYear(nowTimestamp);

            return currentMonth != lastMonth || currentYear != lastYear;
        } else if (frequency == Frequency.Yearly) {
            // Compare year for yearly payrolls
            return getYear(nowTimestamp) != getYear(lastPayroll);
        }

        return false;
    }

    // Helper function to get the year from a timestamp
    function getYear(uint256 timestamp) public pure returns (uint256) {
        return (timestamp / 365 days) + 1970;
    }

    // Helper function to get the month from a timestamp
    function getMonth(uint256 timestamp) public pure returns (uint256) {
        return ((timestamp / 30 days) % 12) + 1; // Rough estimate for months
    }

    function getPayrollDetails()
        external
        view
        returns (
            address _token,
            Status _status,
            Frequency _frequency,
            uint256 _lastPayroll,
            uint256 _startDate
        )
    {
        return (token, status, frequency, last_payroll, start_date);
    }

    function getRecipients() external view returns (Receipient[] memory) {
        return receipients;
    }

    function getStatus() external view returns (Status) {
        return status;
    }

    // Getter function to get the last payroll date
    function getLastPayrollDate() external view returns (uint256) {
        return last_payroll;
    }

    // Getter function to get the frequency of the payroll
    function getFrequency() external view returns (Frequency) {
        return frequency;
    }

    function getTokenAddress() external view returns (address) {
        return token;
    }

    // Getter function to get the total amount to be disbursed
    function getTotalAmountToDisburse() public view returns (uint256) {
        uint256 totalAmount = 0;
        bool greaterThanFree = receipients.length > 3;
        for (uint256 i = 0; i < receipients.length; i++) {
            if (receipients[i].valid) {
                totalAmount += receipients[i].amount;
                if (greaterThanFree) {
                    bool isLargeEnough = receipients[i].amount >= 1000; // 0.1% fee means at least 1000 to have a meaningful fee

                    if (!isLargeEnough) {
                        totalAmount += 10;
                        continue;
                        // revert("Amount is too small to calculate a clean fee");
                    }

                    uint256 fee = (receipients[i].amount * 1) / 1000; // 0.1% fee
                    totalAmount += fee;
                }
            }
        }
        return totalAmount;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    receive() external payable {}
}
