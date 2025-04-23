// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.8;

import "../interfaces/IERC20.sol";
import "../libraries/PayrollTypes.sol";
import "../interfaces/IPayroll.sol";
import "./Payroll.sol";
import "../libraries/PayrollAppStorage.sol";

contract PayrollFactory {
    PayrollStorage.Layout p;

    event NewPayroll(
        address indexed owner,
        string indexed title,
        uint256 indexed timestamp
    );

    constructor() {
        p.owner = msg.sender;
    }

    modifier ValidPayroll(string calldata _title) {
        require(p.payroll[msg.sender][_title] != address(0), "INVALID_PAYROLL");
        _;
    }

    // Function to add supported tokens
    function addSupportedToken(address _token) external {
        require(msg.sender == p.owner, "UNAUTHORIZED");
        require(_token != address(0), "INVALID_TOKEN_ADDRESS");
        require(!p.supportedTokens[_token], "TOKEN_ALREADY_SUPPORTED");

        p.supportedTokens[_token] = true;
    }

    // Function to remove supported tokens
    function removeSupportedToken(address _token) external {
        require(msg.sender == p.owner, "UNAUTHORIZED");
        require(p.supportedTokens[_token], "TOKEN_NOT_SUPPORTED");

        p.supportedTokens[_token] = false;
    }

    function new_payroll(
        string calldata _title,
        Receipient[] memory _receipients,
        address _token,
        uint256 _start_date,
        Frequency _frequency
    ) external {
        require(
            p.payroll[msg.sender][_title] == address(0),
            "PAYROLL_ALREADY_EXIST"
        );
        address _new_payroll = address(
            new Payroll(_receipients, _token, _start_date, _frequency)
        );

        p.payroll[msg.sender][_title] = _new_payroll;
        p.allPayrolls.push(
            PayrollInfo({
                payrollAddress: _new_payroll,
                ownerAddress: msg.sender,
                title: _title,
                status: Status.Active,
                frequency: _frequency,
                tokenAddress: _token
            })
        );
        emit NewPayroll(msg.sender, _title, block.timestamp);
    }

    function add_receipients(
        Receipient[] memory _new_receipients,
        string calldata _title
    ) external ValidPayroll(_title) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        _payroll.add_receipients(_new_receipients);
    }

    function remove_receipients(
        address[] memory _receipients,
        string calldata _title
    ) external ValidPayroll(_title) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        _payroll.remove_receipients(_receipients);
    }

    // Fixed deposit function in PayrollFactory.sol
    function deposit(
        address _token,
        uint256 amount,
        string calldata _title
    ) external ValidPayroll(_title) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);

        // First transfer tokens from caller to factory
        IERC20 token = IERC20(_token);
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "TRANSFER_TO_FACTORY_FAILED"
        );

        // Then approve payroll to spend tokens
        require(token.approve(address(_payroll), amount), "APPROVAL_FAILED");

        // Call payroll deposit (now payroll will pull from factory)
        _payroll.deposit(_token, amount);
    }

    // Fixed withdraw function in PayrollFactory.sol
    function withdraw(
        address _token,
        uint256 amount,
        string calldata _title
    ) external ValidPayroll(_title) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);

        // Withdraw tokens from Payroll to Factory
        _payroll.withdraw(_token, amount);

        // Transfer tokens from Factory to original user
        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, amount), "FACTORY_TRANSFER_FAILED");
    }

    function getUserBalance(
        address _user,
        address _token,
        string calldata _title
    ) external view ValidPayroll(_title) returns (uint256) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        return _payroll.getUserBalance(_user, _token);
    }

    function delete_payroll(
        string calldata _title
    ) external ValidPayroll(_title) {
        address payrollAddr = p.payroll[msg.sender][_title];

        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].payrollAddress == payrollAddr) {
                p.allPayrolls[i].status = Status.Deleted;
                break;
            }
        }
        p.payroll[msg.sender][_title] = address(0);
    }

    function disburse(string calldata _title) external ValidPayroll(_title) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        _payroll.disburse();
    }

    // Function to get all payrolls
    function getAllPayrolls()
        external
        view
        returns (PayrollInfo[] memory activePayrolls)
    {
        return p.allPayrolls;
    }

    function getPayrollDetails(
        string calldata _title
    )
        external
        view
        ValidPayroll(_title)
        returns (
            address _token,
            Status _status,
            Frequency _frequency,
            uint256 _lastPayroll,
            uint256 _startDate
        )
    {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        return _payroll.getPayrollDetails();
    }

    function getPayrollAddress(
        address cowner,
        string calldata title
    ) external view returns (address) {
        return p.payroll[cowner][title];
    }

    function getFullPayrollInfo(
        string calldata _title
    )
        external
        view
        ValidPayroll(_title)
        returns (
            PayrollInfo memory info,
            Receipient[] memory recipients,
            uint256 totalAmount,
            uint256 lastPayrollDate
        )
    {
        // Get the payroll contract address from mapping
        address payrollAddr = p.payroll[msg.sender][_title];

        // Create interface instance
        IPayroll _payroll = IPayroll(payrollAddr);

        // Get PayrollInfo from allPayrolls array
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].payrollAddress == payrollAddr) {
                info = p.allPayrolls[i];
                break;
            }
        }

        // Get remaining details from Payroll contract
        recipients = _payroll.getRecipients();
        totalAmount = _payroll.getTotalAmountToDisburse();
        lastPayrollDate = _payroll.getLastPayrollDate();

        return (info, recipients, totalAmount, lastPayrollDate);
    }

    function getPayrollOwner(
        string calldata _title
    ) external view ValidPayroll(_title) returns (address) {
        IPayroll _payroll = IPayroll(p.payroll[msg.sender][_title]);
        return _payroll.getOwner();
    }

    // Function to get all active payrolls
    function getActivePayrolls()
        external
        view
        returns (PayrollInfo[] memory activePayrolls)
    {
        // First count active payrolls
        uint256 activeCount = 0;
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].status == Status.Active) {
                activeCount++;
            }
        }

        // Create array of correct size
        PayrollInfo[] memory active = new PayrollInfo[](activeCount);
        uint256 currentIndex = 0;

        // Fill array with active payrolls
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].status == Status.Active) {
                active[currentIndex] = p.allPayrolls[i];
                currentIndex++;
            }
        }

        return active;
    }

    // Get payrolls for specific owner
    function getPayrollsByOwner(
        address _owner
    ) external view returns (PayrollInfo[] memory ownerPayrolls) {
        // Count owner's payrolls
        uint256 ownerCount = 0;
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].ownerAddress == _owner) {
                ownerCount++;
            }
        }

        // Create array of correct size
        PayrollInfo[] memory owned = new PayrollInfo[](ownerCount);
        uint256 currentIndex = 0;

        // Fill array with owner's payrolls
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].ownerAddress == _owner) {
                owned[currentIndex] = p.allPayrolls[i];
                currentIndex++;
            }
        }

        return owned;
    }

    // Get total number of payrolls
    function getTotalPayrolls()
        external
        view
        returns (uint256 total, uint256 active)
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].status == Status.Active) {
                activeCount++;
            }
        }
        return (p.allPayrolls.length, activeCount);
    }

    function update_frequency(
        Frequency _frequency,
        string calldata _title
    ) external ValidPayroll(_title) {
        // Get the payroll contract address
        address payrollAddr = p.payroll[msg.sender][_title];

        // Update frequency in the Payroll contract
        IPayroll _payroll = IPayroll(payrollAddr);
        _payroll.update_frequency(_frequency);

        // Update frequency in the PayrollInfo struct in p.allPayrolls array
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].payrollAddress == payrollAddr) {
                p.allPayrolls[i].frequency = _frequency;
                break;
            }
        }
    }

    function update_status(
        Status _status,
        string calldata _title
    ) external ValidPayroll(_title) {
        // Get the payroll contract address
        address payrollAddr = p.payroll[msg.sender][_title];

        // Update status in the Payroll contract
        IPayroll _payroll = IPayroll(payrollAddr);
        _payroll.update_status(_status);

        // Update status in the PayrollInfo struct in p.allPayrolls array
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].payrollAddress == payrollAddr) {
                p.allPayrolls[i].status = _status;
                break;
            }
        }
    }

    function update_token(
        address _token,
        string calldata _title
    ) external ValidPayroll(_title) {
        // Get the payroll contract address
        address payrollAddr = p.payroll[msg.sender][_title];

        // Update token in the Payroll contract
        IPayroll _payroll = IPayroll(payrollAddr);
        _payroll.update_token(_token);

        // Update token in the PayrollInfo struct in allPayrolls array
        for (uint256 i = 0; i < p.allPayrolls.length; i++) {
            if (p.allPayrolls[i].payrollAddress == payrollAddr) {
                p.allPayrolls[i].tokenAddress = _token;
                break;
            }
        }
    }
}
