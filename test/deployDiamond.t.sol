// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/PayrollFactory.sol";
import "../contracts/facets/Staking.sol";
import "./MockER20.sol";
import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../contracts/Diamond.sol";
import "../contracts/interfaces/IDiamond.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    MockERC20 public token2;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;

    PayrollFactory payrollFactory;

    IDiamond i_diamond;

    address alice = mkaddr("alice");
    address bob = mkaddr("bob");

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function setUp() public {
        //deploy facets

        switchSigner(alice);
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        payrollFactory = new PayrollFactory();

        token2 = new MockERC20("Test Token", "TST");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](3);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(payrollFactory),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("PayrollFactory")
            })
        );

        // cut[3] = (
        //     FacetCut({
        //         facetAddress: address(new Staking()),
        //         action: FacetCutAction.Add,
        //         functionSelectors: generateSelectors("Staking")
        //     })
        // );

        i_diamond = IDiamond(address(diamond));

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
        payrollFactory = PayrollFactory(address(diamond));
    }

    //tests new_payroll, deposit, disburse
    function test_Disburse() public {
        // Setup test data
        string memory title = "Test Payroll";
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients1 = new Receipient[](2);
        recipients1[0] = Receipient({
            username: "User1",
            amount: 10,
            _address: address(0x2222),
            valid: true
        });
        recipients1[1] = Receipient({
            username: "User2",
            amount: 20,
            _address: address(0x3333),
            valid: true
        });

        // Mint tokens for alice (the owner)
        token2.mint(alice, 2000);

        // Debug log: Alice's balance after minting
        console.log("Alice's balance after minting:", token2.balanceOf(alice));

        // Switch to alice's address for the call
        switchSigner(alice);

        // Create payroll
        payrollFactory.new_payroll(
            title,
            recipients1,
            address(token2),
            start_date,
            Frequency.Monthly
        );

        // Debug log: Payroll creation
        address storedAddr = payrollFactory.getPayrollAddress(alice, title);
        console.log("Stored payroll address:", storedAddr);

        // Get payroll details
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );
        console.log("Payroll title:", info.title);

        // Approve the Payroll contract to spend Alice's tokens
        switchSigner(alice);
        token2.approve(info.payrollAddress, 300); // Approve tokens for transfer to the Payroll contract
        console.log("Alice's balance after approval:", token2.balanceOf(alice));

        // Deposit tokens into the payroll contract
        switchSigner(alice);
        token2.approve(address(payrollFactory), 300);
        switchSigner(alice);
        token2.approve(info.payrollAddress, 300);
        switchSigner(alice);
        payrollFactory.deposit(address(token2), 300, title);

        console.log("Alice's balance after deposit:", token2.balanceOf(alice));

        // Mint additional tokens to the payroll contract for disbursement
        console.log(
            "Payroll contract balance after deposit:",
            token2.balanceOf(info.payrollAddress)
        );

        // Debug logs
        console.log(
            "Alice's balance before disbursement:",
            token2.balanceOf(alice)
        );
        console.log(
            "Payroll contract balance before disbursement:",
            token2.balanceOf(info.payrollAddress)
        );
        console.log(
            "User1 balance before disbursement:",
            token2.balanceOf(recipients1[0]._address)
        );
        console.log(
            "User2 balance before disbursement:",
            token2.balanceOf(recipients1[1]._address)
        );

        // Timewarp 30 days
        uint256 thirtyDaysInSeconds = 30 days;
        vm.warp(start_date + thirtyDaysInSeconds);

        // Switch to alice's address before calling disburse
        switchSigner(alice);
        payrollFactory.disburse(title);

        // Get balances after disbursement
        uint256 blAfter_user1 = token2.balanceOf(recipients1[0]._address);
        uint256 blAfter_user2 = token2.balanceOf(recipients1[1]._address);

        // Debug logs
        console.log(
            "Alice's balance after disbursement:",
            token2.balanceOf(alice)
        );
        console.log("User1 balance after disbursement:", blAfter_user1);
        console.log("User2 balance after disbursement:", blAfter_user2);

        // Assert balances
        assertEq(
            blAfter_user1,
            10,
            "User1 balance should be 10 after disbursement"
        );
        assertEq(
            blAfter_user2,
            20,
            "User2 balance should be 20 after disbursement"
        );

        // Verify payroll status
        switchSigner(alice);
        (PayrollInfo memory infoAfter, , , ) = payrollFactory
            .getFullPayrollInfo(title);
        assertEq(
            uint256(infoAfter.status),
            uint256(Status.Active),
            "Payroll status should still be Active after disbursement"
        );
    }

    function test_Withdraw() public {
        // Setup test data
        string memory title = "Test Payroll";
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients1 = new Receipient[](2);
        recipients1[0] = Receipient({
            username: "User1",
            amount: 10,
            _address: address(0x2222),
            valid: true
        });
        recipients1[1] = Receipient({
            username: "User2",
            amount: 20,
            _address: address(0x3333),
            valid: true
        });

        // Mint tokens for alice (the owner)
        token2.mint(alice, 1000);

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients1,
            address(token2),
            start_date,
            Frequency.Monthly
        );

        // Get payroll details
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );

        // Approve tokens for transfer
        switchSigner(alice);
        token2.approve(address(payrollFactory), 200);

        // Approve tokens for payroll contract (if needed based on your architecture)
        switchSigner(alice);
        token2.approve(info.payrollAddress, 200);

        // Deposit tokens into the payroll contract
        switchSigner(alice);
        payrollFactory.deposit(address(token2), 100, title);

        // Check alice's balance after deposit
        uint256 aliceBalanceAfterDeposit = token2.balanceOf(alice);
        console.log("Alice's balance after deposit:", aliceBalanceAfterDeposit);

        // Check payroll contract's balance
        uint256 payrollBalanceAfterDeposit = token2.balanceOf(
            info.payrollAddress
        );
        console.log(
            "Payroll contract balance after deposit:",
            payrollBalanceAfterDeposit
        );

        // Now withdraw some tokens
        switchSigner(alice);
        payrollFactory.withdraw(address(token2), 50, title);

        // Check alice's balance after withdrawal
        uint256 aliceBalanceAfterWithdraw = token2.balanceOf(alice);
        console.log(
            "Alice's balance after withdrawal:",
            aliceBalanceAfterWithdraw
        );

        // Check payroll contract's balance after withdrawal
        uint256 payrollBalanceAfterWithdraw = token2.balanceOf(
            info.payrollAddress
        );
        console.log(
            "Payroll contract balance after withdrawal:",
            payrollBalanceAfterWithdraw
        );

        // Verify the withdrawal amount
        assertEq(
            aliceBalanceAfterWithdraw,
            aliceBalanceAfterDeposit + 50,
            "Alice should have received 50 tokens back"
        );

        assertEq(
            payrollBalanceAfterWithdraw,
            payrollBalanceAfterDeposit - 50,
            "Payroll contract should have 50 fewer tokens"
        );
    }

    function test_DeletePayroll() public {
        // create a payroll to delete
        string memory title = "Test Delete Payroll";
        address token = address(0x1234);
        uint256 start_date = block.timestamp;

        // recipients array
        Receipient[] memory recipients = new Receipient[](2);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });
        recipients[1] = Receipient({
            username: "User2",
            amount: 200,
            _address: address(0x2222),
            valid: true
        });

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Delete the payroll as alice
        switchSigner(alice);
        payrollFactory.delete_payroll(title);

        // Verify payroll status is updated to Paused
        PayrollInfo[] memory allPayrolls = payrollFactory.getAllPayrolls();
        assertEq(
            uint256(allPayrolls[0].status),
            uint256(Status.Deleted),
            "Payroll status not updated to Paused"
        );

        // Try to access the deleted payroll (should revert)
        switchSigner(alice);
        vm.expectRevert("INVALID_PAYROLL");
        payrollFactory.getPayrollDetails(title);

        // Test that bob cannot delete alice's payroll
        string memory bobTitle = "Bob's Payroll";
        switchSigner(bob);
        payrollFactory.new_payroll(
            bobTitle,
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Alice trying to delete Bob's payroll (should revert)
        switchSigner(alice);
        vm.expectRevert("INVALID_PAYROLL");

        payrollFactory.delete_payroll(bobTitle);
    }

    function test_GetAllPayrolls() public {
        // Setup common variables
        address token = address(0x1234);
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](2);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });
        recipients[1] = Receipient({
            username: "User2",
            amount: 200,
            _address: address(0x2222),
            valid: true
        });

        // Create first payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 1",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Create second payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 2",
            recipients,
            token,
            start_date,
            Frequency.Weekly
        );

        // Create payroll as bob
        switchSigner(bob);
        payrollFactory.new_payroll(
            "Bob Payroll",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Get all payrolls and verify
        PayrollInfo[] memory allPayrolls = payrollFactory.getAllPayrolls();

        // Log all payrolls for debugging
        console.log("Total number of payrolls:", allPayrolls.length);
        for (uint256 i = 0; i < allPayrolls.length; i++) {
            console.log("Payroll", i);
            console.log("Title:", allPayrolls[i].title);
            console.log("Owner:", allPayrolls[i].ownerAddress);
            console.log("Status:", uint256(allPayrolls[i].status));
            console.log("------------------");
        }

        // Verify the total number of payrolls
        assertEq(allPayrolls.length, 3, "Wrong number of payrolls");

        // Verify first payroll details
        assertEq(
            allPayrolls[0].title,
            "Alice Payroll 1",
            "Wrong title for first payroll"
        );
        assertEq(
            allPayrolls[0].ownerAddress,
            alice,
            "Wrong owner for first payroll"
        );
        assertEq(
            uint256(allPayrolls[0].status),
            uint256(Status.Active),
            "Wrong status for first payroll"
        );

        // Verify second payroll details
        assertEq(
            allPayrolls[1].title,
            "Alice Payroll 2",
            "Wrong title for second payroll"
        );
        assertEq(
            allPayrolls[1].ownerAddress,
            alice,
            "Wrong owner for second payroll"
        );
        assertEq(
            uint256(allPayrolls[1].status),
            uint256(Status.Active),
            "Wrong status for second payroll"
        );

        // Verify third payroll details
        assertEq(
            allPayrolls[2].title,
            "Bob Payroll",
            "Wrong title for third payroll"
        );
        assertEq(
            allPayrolls[2].ownerAddress,
            bob,
            "Wrong owner for third payroll"
        );
        assertEq(
            uint256(allPayrolls[2].status),
            uint256(Status.Active),
            "Wrong status for third payroll"
        );
    }

    function test_GetFullPayrollInfo() public {
        // Setup test data
        string memory title = "Test Payroll";
        address token = address(0x1234);
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](2);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });
        recipients[1] = Receipient({
            username: "User2",
            amount: 200,
            _address: address(0x2222),
            valid: true
        });

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Verify payroll creation
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );
        assertEq(info.title, title, "Payroll creation failed");

        // Get full payroll info
        switchSigner(alice);
        (
            PayrollInfo memory infoAfter,
            Receipient[] memory returnedRecipients,
            uint256 totalAmount,
            uint256 lastPayrollDate
        ) = payrollFactory.getFullPayrollInfo(title);

        // Verify PayrollInfo
        assertEq(infoAfter.title, title, "Wrong title");
        assertEq(infoAfter.ownerAddress, alice, "Wrong owner");
        assertEq(
            uint256(infoAfter.status),
            uint256(Status.Active),
            "Wrong status"
        );
        assertTrue(
            infoAfter.payrollAddress != address(0),
            "Invalid payroll address"
        );

        // Verify recipients
        assertEq(returnedRecipients.length, 2, "Wrong number of recipients");
        assertEq(
            returnedRecipients[0].username,
            "User1",
            "Wrong username for first recipient"
        );
        assertEq(
            returnedRecipients[0].amount,
            100,
            "Wrong amount for first recipient"
        );
        assertEq(
            returnedRecipients[0]._address,
            address(0x1111),
            "Wrong address for first recipient"
        );
        assertEq(
            returnedRecipients[0].valid,
            true,
            "Wrong valid status for first recipient"
        );

        // Verify total amount
        assertEq(totalAmount, 300, "Wrong total amount");

        // Verify last payroll date
        assertEq(lastPayrollDate, 0, "Wrong last payroll date for new payroll");
    }

    function test_GetPayrollsByOwner() public {
        // Setup common variables
        address token = address(0x1234);
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](1);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });

        // Create multiple payrolls for Alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 1",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 2",
            recipients,
            token,
            start_date,
            Frequency.Weekly
        );

        // Create one payroll for Bob
        switchSigner(bob);
        payrollFactory.new_payroll(
            "Bob Payroll",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Get Alice's payrolls
        PayrollInfo[] memory alicePayrolls = payrollFactory.getPayrollsByOwner(
            alice
        );

        console.log("Alice's Payrolls:");
        console.log("Total count:", alicePayrolls.length);
        for (uint256 i = 0; i < alicePayrolls.length; i++) {
            console.log("\nPayroll", i + 1);
            console.log("Title:", alicePayrolls[i].title);
            console.log("Owner:", alicePayrolls[i].ownerAddress);
            console.log("Status:", uint256(alicePayrolls[i].status));
        }

        // Verify Alice's payrolls
        assertEq(alicePayrolls.length, 2, "Wrong number of payrolls for Alice");
        assertEq(
            alicePayrolls[0].title,
            "Alice Payroll 1",
            "Wrong title for first payroll"
        );
        assertEq(
            alicePayrolls[1].title,
            "Alice Payroll 2",
            "Wrong title for second payroll"
        );
        assertEq(
            alicePayrolls[0].ownerAddress,
            alice,
            "Wrong owner for first payroll"
        );
        assertEq(
            alicePayrolls[1].ownerAddress,
            alice,
            "Wrong owner for second payroll"
        );

        // Get Bob's payrolls
        PayrollInfo[] memory bobPayrolls = payrollFactory.getPayrollsByOwner(
            bob
        );

        console.log("\nBob's Payrolls:");
        console.log("Total count:", bobPayrolls.length);
        for (uint256 i = 0; i < bobPayrolls.length; i++) {
            console.log("\nPayroll", i + 1);
            console.log("Title:", bobPayrolls[i].title);
            console.log("Owner:", bobPayrolls[i].ownerAddress);
            console.log("Status:", uint256(bobPayrolls[i].status));
        }

        // Verify Bob's payrolls
        assertEq(bobPayrolls.length, 1, "Wrong number of payrolls for Bob");
        assertEq(
            bobPayrolls[0].title,
            "Bob Payroll",
            "Wrong title for Bob's payroll"
        );
        assertEq(
            bobPayrolls[0].ownerAddress,
            bob,
            "Wrong owner for Bob's payroll"
        );

        // Check for non-existent owner
        address charlie = makeAddr("charlie");
        PayrollInfo[] memory charliePayrolls = payrollFactory
            .getPayrollsByOwner(charlie);
        assertEq(
            charliePayrolls.length,
            0,
            "Should have no payrolls for non-existent owner"
        );
    }

    function test_GetTotalPayrollCounts() public {
        // Setup common variables
        address token = address(0x1234);
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](1);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });

        // Create first payroll as alice (Active)
        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 1",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Create second payroll as alice (Active)
        switchSigner(alice);
        payrollFactory.new_payroll(
            "Alice Payroll 2",
            recipients,
            token,
            start_date,
            Frequency.Weekly
        );

        // Create payroll as bob (Active)
        switchSigner(bob);
        payrollFactory.new_payroll(
            "Bob Payroll",
            recipients,
            token,
            start_date,
            Frequency.Monthly
        );

        // Check initial state using both functions
        (uint256 total, uint256 active) = payrollFactory.getTotalPayrolls();
        PayrollInfo[] memory activePayrolls = payrollFactory
            .getActivePayrolls();

        // Verify initial counts
        assertEq(total, 3, "Wrong total number of payrolls");
        assertEq(
            active,
            3,
            "Wrong number of active payrolls from getTotalPayrolls"
        );
        assertEq(
            activePayrolls.length,
            3,
            "Wrong number of active payrolls from getActivePayrolls"
        );

        // Delete (pause) one of Alice's payrolls
        switchSigner(alice);
        payrollFactory.delete_payroll("Alice Payroll 1");

        // Check state after deletion using both functions
        (total, active) = payrollFactory.getTotalPayrolls();
        activePayrolls = payrollFactory.getActivePayrolls();

        // Verify counts after deletion
        assertEq(total, 3, "Wrong total number of payrolls after deletion");
        assertEq(
            active,
            2,
            "Wrong number of active payrolls from getTotalPayrolls after deletion"
        );
        assertEq(
            activePayrolls.length,
            2,
            "Wrong number of active payrolls from getActivePayrolls after deletion"
        );

        // Verify the remaining active payrolls content
        bool foundActiveAlice2 = false;
        bool foundActiveBob = false;

        for (uint256 i = 0; i < activePayrolls.length; i++) {
            if (
                keccak256(abi.encodePacked(activePayrolls[i].title)) ==
                keccak256(abi.encodePacked("Alice Payroll 2"))
            ) {
                foundActiveAlice2 = true;
            }
            if (
                keccak256(abi.encodePacked(activePayrolls[i].title)) ==
                keccak256(abi.encodePacked("Bob Payroll"))
            ) {
                foundActiveBob = true;
            }

            assertEq(
                uint256(activePayrolls[i].status),
                uint256(Status.Active),
                "Found inactive payroll in active list"
            );
            assertTrue(
                keccak256(abi.encodePacked(activePayrolls[i].title)) !=
                    keccak256(abi.encodePacked("Alice Payroll 1")),
                "Found deleted payroll in active list"
            );
        }

        assertTrue(
            foundActiveAlice2 && foundActiveBob,
            "Not all active payrolls found after deletion"
        );

        // Log the results
        console.log("\nFinal Payroll Counts:");
        console.log("Total Payrolls:", total);
        console.log("Active Payrolls (from getTotalPayrolls):", active);
        console.log(
            "Active Payrolls (from getActivePayrolls):",
            activePayrolls.length
        );

        console.log("\nActive Payrolls Details:");
        for (uint256 i = 0; i < activePayrolls.length; i++) {
            console.log("\nPayroll", i + 1);
            console.log("Title:", activePayrolls[i].title);
            console.log("Owner:", activePayrolls[i].ownerAddress);
            console.log("Status:", uint256(activePayrolls[i].status));
        }
    }

    function test_UpdateFrequency() public {
        // Setup test data
        string memory title = "Test Payroll";
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](1);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients,
            address(token2),
            start_date,
            Frequency.Monthly
        );

        // Get payroll details
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );

        // Update frequency to Weekly
        switchSigner(alice);
        payrollFactory.update_frequency(Frequency.Weekly, title);

        // Verify the frequency update
        switchSigner(alice);
        (PayrollInfo memory updatedInfo, , , ) = payrollFactory
            .getFullPayrollInfo(title);
        assertEq(
            uint256(updatedInfo.frequency),
            uint256(Frequency.Weekly),
            "Frequency should be updated to Weekly"
        );
    }

    function test_UpdateStatus() public {
        // Setup test data
        string memory title = "Test Payroll";
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](1);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients,
            address(token2),
            start_date,
            Frequency.Monthly
        );

        // Get payroll details
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );

        // Update status to Paused
        switchSigner(alice);
        payrollFactory.update_status(Status.Paused, title);

        // Verify the status update
        switchSigner(alice);
        (PayrollInfo memory updatedInfo, , , ) = payrollFactory
            .getFullPayrollInfo(title);
        assertEq(
            uint256(updatedInfo.status),
            uint256(Status.Paused),
            "Status should be updated to Paused"
        );
    }

    function test_UpdateToken() public {
        // Setup test data
        string memory title = "Test Payroll";
        uint256 start_date = block.timestamp;

        // Create test recipients array
        Receipient[] memory recipients = new Receipient[](1);
        recipients[0] = Receipient({
            username: "User1",
            amount: 100,
            _address: address(0x1111),
            valid: true
        });

        // Create payroll as alice
        switchSigner(alice);
        payrollFactory.new_payroll(
            title,
            recipients,
            address(token2),
            start_date,
            Frequency.Monthly
        );

        // Get payroll details
        switchSigner(alice);
        (PayrollInfo memory info, , , ) = payrollFactory.getFullPayrollInfo(
            title
        );

        // Create a new token
        MockERC20 newToken = new MockERC20("New Token", "NEW");

        // Update token to the new token
        switchSigner(alice);
        payrollFactory.update_token(address(newToken), title);

        // Verify the token update
        switchSigner(alice);
        (PayrollInfo memory updatedInfo, , , ) = payrollFactory
            .getFullPayrollInfo(title);
        assertEq(
            updatedInfo.tokenAddress,
            address(newToken),
            "Token address should be updated to the new token"
        );
    }

    // function testStake() public {
    //     console2.log("Haloha");
    //     vm.expectRevert(abi.encodeWithSelector(UNAUTHORIZED.selector));
    //     i_diamond.list_user(address(1), 50);
    // }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
