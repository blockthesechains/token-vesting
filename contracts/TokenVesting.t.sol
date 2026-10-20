// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TokenVesting} from "./TokenVesting.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract TokenVestingTest is Test {
    MockToken token;
    TokenVesting vesting;

    address beneficiary = address(0xBEEF);
    address stranger = address(0xBAD);

    uint64 start;
    uint64 constant CLIFF = 90 days;
    uint64 constant DURATION = 365 days;
    uint256 constant ALLOCATION = 1_000 ether;

    function setUp() public {
        token = new MockToken();
        start = uint64(block.timestamp);
        vesting = new TokenVesting(address(token), beneficiary, start, CLIFF, DURATION);
        token.transfer(address(vesting), ALLOCATION);
    }

    // ---------- Deployment ----------

    function test_ConstructorSetsValues() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.start(), start);
        assertEq(vesting.cliffDuration(), CLIFF);
        assertEq(vesting.duration(), DURATION);
    }

    function test_RevertWhen_BeneficiaryIsZero() public {
        vm.expectRevert(TokenVesting.ZeroAddress.selector);
        new TokenVesting(address(token), address(0), start, CLIFF, DURATION);
    }

    function test_RevertWhen_CliffLongerThanDuration() public {
        vm.expectRevert(TokenVesting.InvalidDuration.selector);
        new TokenVesting(address(token), beneficiary, start, DURATION + 1, DURATION);
    }

    // ---------- Vesting schedule ----------

    function test_NothingVestedBeforeCliff() public {
        vm.warp(start + CLIFF - 1);
        assertEq(vesting.releasable(), 0);
    }

    function test_HalfVestedAtMidpoint() public {
        vm.warp(start + DURATION / 2);
        assertEq(vesting.releasable(), ALLOCATION / 2);
    }

    function test_FullyVestedAtEnd() public {
        vm.warp(start + DURATION);
        assertEq(vesting.releasable(), ALLOCATION);
    }

    // ---------- Releasing ----------

    function test_ReleaseTransfersVestedTokens() public {
        vm.warp(start + DURATION / 2);
        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), ALLOCATION / 2);
        assertEq(vesting.released(), ALLOCATION / 2);
    }

    function test_MultipleReleasesAddUpToTotal() public {
        vm.warp(start + DURATION / 2);
        vm.prank(beneficiary);
        vesting.release();

        vm.warp(start + DURATION);
        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_ReleaseEmitsEvent() public {
        vm.warp(start + DURATION);
        vm.expectEmit(true, false, false, true, address(vesting));
        emit TokenVesting.TokensReleased(beneficiary, ALLOCATION);
        vm.prank(beneficiary);
        vesting.release();
    }

    function test_RevertWhen_ReleasingBeforeCliff() public {
        vm.warp(start + CLIFF - 1);
        vm.prank(beneficiary);
        vm.expectRevert(TokenVesting.NothingToRelease.selector);
        vesting.release();
    }

    function test_RevertWhen_StrangerReleases() public {
        vm.warp(start + DURATION);
        vm.prank(stranger);
        vm.expectRevert(TokenVesting.NotBeneficiary.selector);
        vesting.release();
    }

    // ---------- Fuzzing ----------

    function testFuzz_VestedNeverExceedsAllocation(uint64 timestamp) public view {
        timestamp = uint64(bound(timestamp, start, start + DURATION * 2));
        assertLe(vesting.vestedAmount(timestamp), ALLOCATION);
    }
}