// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {Escrow} from "../src/Escrow.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 v) external {
        _mint(to, v);
    }
}

contract EscrowTest is Test {
    MockToken token;
    Escrow escrow;

    address buyer = makeAddr("buyer");
    address stranger = makeAddr("stranger");
    uint256 constant AMOUNT = 100e18;

    // the test contract itself is the seller (it deploys the escrow)
    function setUp() public {
        token = new MockToken();
        escrow = new Escrow(buyer, address(token), AMOUNT);
        token.mint(buyer, AMOUNT);
    }

    // helper: buyer approves and deposits
    function _fund() internal {
        vm.startPrank(buyer);
        token.approve(address(escrow), AMOUNT);
        escrow.deposit();
        vm.stopPrank();
    }

    // ---------- constructor ----------

    function test_ConstructorSetsValues() public view {
        assertEq(escrow.buyer(), buyer);
        assertEq(escrow.seller(), address(this));
        assertEq(address(escrow.token()), address(token));
        assertEq(escrow.amount(), AMOUNT);
        assertEq(uint256(escrow.phase()), uint256(Escrow.Phases.Waiting));
    }

    function test_RevertWhen_BuyerIsZero() public {
        vm.expectRevert(Escrow.ZeroAddr.selector);
        new Escrow(address(0), address(token), AMOUNT);
    }

    function test_RevertWhen_TokenIsZero() public {
        vm.expectRevert(Escrow.ZeroAddr.selector);
        new Escrow(buyer, address(0), AMOUNT);
    }

    function test_RevertWhen_AmountIsZero() public {
        vm.expectRevert(Escrow.ZeroAmt.selector);
        new Escrow(buyer, address(token), 0);
    }

    function test_RevertWhen_BuyerIsSeller() public {
        vm.expectRevert(Escrow.NotOwner.selector);
        new Escrow(address(this), address(token), AMOUNT);
    }

    // ---------- deposit ----------

    function test_Deposit() public {
        _fund();
        assertEq(token.balanceOf(address(escrow)), AMOUNT);
        assertEq(token.balanceOf(buyer), 0);
        assertEq(uint256(escrow.phase()), uint256(Escrow.Phases.Funded));
    }

    function test_DepositEmitsEvent() public {
        vm.startPrank(buyer);
        token.approve(address(escrow), AMOUNT);

        vm.expectEmit(true, false, false, true);
        emit Escrow.Funded(buyer, AMOUNT);
        escrow.deposit();
        vm.stopPrank();
    }

    function test_RevertWhen_StrangerDeposits() public {
        vm.prank(stranger);
        vm.expectRevert();
        escrow.deposit();
    }

    function test_RevertWhen_DepositTwice() public {
        _fund();
        token.mint(buyer, AMOUNT);

        vm.startPrank(buyer);
        token.approve(address(escrow), AMOUNT);
        vm.expectRevert(Escrow.WrongPhase.selector);
        escrow.deposit();
        vm.stopPrank();
    }

    // ---------- release ----------

    function test_Release() public {
        _fund();

        vm.prank(buyer);
        escrow.releaseFunds();

        assertEq(token.balanceOf(address(this)), AMOUNT); // seller got paid
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(uint256(escrow.phase()), uint256(Escrow.Phases.Complete));
    }

    function test_RevertWhen_ReleaseBeforeDeposit() public {
        vm.prank(buyer);
        vm.expectRevert(Escrow.WrongPhase.selector);
        escrow.releaseFunds();
    }

    function test_RevertWhen_SellerReleases() public {
        _fund();
        vm.expectRevert(); // caller is the seller (this contract), not the buyer
        escrow.releaseFunds();
    }

    function test_RevertWhen_ReleaseTwice() public {
        _fund();

        vm.startPrank(buyer);
        escrow.releaseFunds();
        vm.expectRevert(Escrow.WrongPhase.selector);
        escrow.releaseFunds();
        vm.stopPrank();
    }

    // ---------- refund ----------

    function test_Refund() public {
        _fund();

        escrow.refund(); // this contract is the seller

        assertEq(token.balanceOf(buyer), AMOUNT); // buyer got money back
        assertEq(token.balanceOf(address(escrow)), 0);
        assertEq(uint256(escrow.phase()), uint256(Escrow.Phases.Complete));
    }

    function test_RevertWhen_BuyerRefunds() public {
        _fund();

        vm.prank(buyer);
        vm.expectRevert();
        escrow.refund();
    }

    function test_RevertWhen_RefundBeforeDeposit() public {
        vm.expectRevert(Escrow.WrongPhase.selector);
        escrow.refund();
    }

    function test_RevertWhen_RefundAfterRelease() public {
        _fund();

        vm.prank(buyer);
        escrow.releaseFunds();

        vm.expectRevert(Escrow.WrongPhase.selector);
        escrow.refund();
    }
}