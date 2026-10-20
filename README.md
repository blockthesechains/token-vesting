# Token Vesting

A Solidity token vesting contract with a cliff and linear release schedule, built with OpenZeppelin and Hardhat 3, with a full Foundry-style test suite.

## How it works

- Holds ERC-20 tokens for a single beneficiary
- Nothing unlocks before the cliff
- After the cliff, tokens unlock linearly until the end of the vesting period
- The beneficiary calls `release()` to claim whatever has vested so far

## Security design

- Token, beneficiary, and schedule are `immutable` and cannot be changed after deployment
- Constructor rejects zero addresses and cliffs longer than the vesting period
- `release()` follows checks-effects-interactions, updating state before transferring tokens
- Uses OpenZeppelin `SafeERC20` for token transfers
- Custom errors for clear, gas-efficient reverts

## Tests

12 Solidity tests using `forge-std`, run through Hardhat 3:

- Constructor values and input validation
- Nothing vested before the cliff
- Exact amounts at the midpoint and end of vesting
- Single and multiple releases add up to the full allocation
- `TokensReleased` event emission
- Reverts for releasing before the cliff and for non-beneficiaries
- Fuzz test: vested amount never exceeds the allocation (256 runs)

Time-based behavior is tested with `vm.warp`.

## Running locally

    npm install
    npx hardhat compile
    npx hardhat test

## Tech

Solidity 0.8.x · OpenZeppelin Contracts · Hardhat 3 · forge-std