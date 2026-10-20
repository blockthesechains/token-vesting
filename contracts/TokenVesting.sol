// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint64 public immutable start;
    uint64 public immutable cliffDuration;
    uint64 public immutable duration;

    uint256 public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    error ZeroAddress();
    error InvalidDuration();
    error NotBeneficiary();
    error NothingToRelease();

    constructor(
        address token_,
        address beneficiary_,
        uint64 start_,
        uint64 cliffDuration_,
        uint64 duration_
    ) {
        if (token_ == address(0) || beneficiary_ == address(0)) revert ZeroAddress();
        if (duration_ == 0 || cliffDuration_ > duration_) revert InvalidDuration();

        token = IERC20(token_);
        beneficiary = beneficiary_;
        start = start_;
        cliffDuration = cliffDuration_;
        duration = duration_;
    }

    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        uint256 totalAllocation = token.balanceOf(address(this)) + released;

        if (timestamp < start + cliffDuration) {
            return 0;
        } else if (timestamp >= start + duration) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start)) / duration;
        }
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    function release() external {
        if (msg.sender != beneficiary) revert NotBeneficiary();

        uint256 amount = releasable();
        if (amount == 0) revert NothingToRelease();

        released += amount;
        token.safeTransfer(beneficiary, amount);

        emit TokensReleased(beneficiary, amount);
    }
}