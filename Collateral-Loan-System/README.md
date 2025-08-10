# Over-Collateralized STX Lending Protocol

A robust decentralized finance (DeFi) protocol built on Stacks that enables secure lending operations using STX tokens as collateral. Users can lock their STX holdings to mint USD-pegged loans while maintaining ownership of their assets through strict over-collateralization requirements and automated liquidation mechanisms.

## Features

- **Secure STX-backed lending** with USD loan issuance
- **Minimum 150% over-collateralization** requirement for all loans
- **Automated liquidation** at 130% collateral threshold
- **Real-time oracle-based** asset price feeds
- **Governance-controlled** protocol parameters
- **Comprehensive position** health monitoring
- **Fee-based sustainable** protocol economics

## Protocol Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Required Collateralization | 150% | Minimum collateral ratio for new loans |
| Liquidation Threshold | 130% | Automatic liquidation trigger point |
| Maximum Protocol Fee | 10% | Upper limit on protocol fees |
| Standard Origination Fee | 1% | Default fee on loan payments |

## Contract Architecture

### Core Data Structures

#### Individual Borrower Accounts
```clarity
{
  locked-stx-collateral-amount: uint,
  outstanding-usd-loan-balance: uint,
  account-last-activity-block: uint
}
```

#### Asset Market Price Feeds
```clarity
{
  digital-asset-ticker: (string-ascii 32),
  market-price-in-usd-cents: uint
}
```

### Global State Variables
- `protocol-governance-authority`: Current protocol administrator
- `aggregate-stx-collateral-balance`: Total STX locked in protocol
- `aggregate-usd-loan-obligations`: Total outstanding loan amount
- `total-active-borrowing-accounts`: Number of active borrowers
- `applicable-protocol-fee-percentage`: Current protocol fee rate

## Public Functions

### Account Management

#### `establish-new-borrowing-account()`
Creates a new borrowing account for the caller.
- **Returns**: `(ok true)` on success
- **Errors**: `ERR-BORROWING-POSITION-EXISTS` if account already exists

#### `secure-stx-as-collateral(stx-collateral-deposit-amount)`
Deposits STX tokens as collateral into the caller's account.
- **Parameters**: 
  - `stx-collateral-deposit-amount` (uint): Amount of STX to deposit
- **Returns**: `(ok true)` on success
- **Errors**: Various validation errors

#### `release-surplus-collateral(stx-collateral-withdrawal-amount)`
Withdraws excess collateral while maintaining required ratios.
- **Parameters**: 
  - `stx-collateral-withdrawal-amount` (uint): Amount of STX to withdraw
- **Returns**: `(ok true)` on success
- **Errors**: Insufficient balance or inadequate collateralization

### Loan Operations

#### `issue-collateral-backed-loan(requested-loan-principal)`
Issues a new loan against deposited collateral.
- **Parameters**: 
  - `requested-loan-principal` (uint): Loan amount requested
- **Returns**: `(ok true)` on success
- **Errors**: Inadequate collateral or insufficient protocol treasury

#### `process-borrower-loan-payment(payment-amount)`
Processes loan repayments with automatic fee calculation.
- **Parameters**: 
  - `payment-amount` (uint): Payment amount
- **Returns**: `(ok true)` on success
- **Errors**: Invalid payment amount

### Liquidation System

#### `execute-borrower-liquidation(vulnerable-borrower-address)`
Liquidates undercollateralized positions.
- **Parameters**: 
  - `vulnerable-borrower-address` (principal): Address of borrower to liquidate
- **Returns**: `(ok true)` on success
- **Errors**: Position not eligible for liquidation

### Governance Functions (Admin Only)

#### `update-cryptocurrency-pricing-oracle(digital-asset-ticker, updated-price-usd-cents)`
Updates asset price feeds.

#### `modify-protocol-fee-parameters(revised-fee-percentage)`
Adjusts protocol fee structure.

#### `transfer-protocol-governance-authority(designated-new-authority)`
Transfers admin privileges to new address.

## Read-Only Functions

### Account Information
- `get-individual-borrower-account(account-holder-address)`: Get account details
- `calculate-borrower-collateralization-health(account-holder-address)`: Get collateral ratio
- `calculate-available-borrowing-capacity(account-holder-address)`: Get borrowing capacity
- `evaluate-liquidation-vulnerability(account-holder-address)`: Check liquidation risk
- `calculate-position-safety-index(account-holder-address)`: Get safety score

### Protocol Analytics
- `generate-comprehensive-protocol-metrics()`: Get protocol-wide statistics
- `calculate-capital-utilization-efficiency()`: Get capital efficiency ratio
- `generate-detailed-borrower-assessment(account-holder-address)`: Get detailed account info
- `get-current-stx-market-price()`: Get current STX price

## Economic Model

### Collateralization Requirements
- **New Loans**: Minimum 150% collateralization ratio
- **Liquidation**: Triggered at 130% collateralization ratio
- **Safety Buffer**: 20% buffer between minimum and liquidation thresholds

### Fee Structure
- **Origination Fee**: 1% of loan payments (configurable)
- **Maximum Fee Cap**: 10% (hard-coded limit)
- **Fee Distribution**: Retained by protocol treasury

## Risk Management

### Liquidation Mechanism
When a borrower's collateralization ratio falls below 130%:
1. Any user can call the liquidation function
2. Liquidator pays off the borrower's debt
3. Liquidator receives the borrower's collateral
4. Position is cleared from the system

### Oracle Dependency
The protocol relies on external price feeds for STX valuation. Price updates are controlled by governance and should be updated regularly to ensure accurate collateral valuations.

## Security Considerations

### Access Control
- Governance functions restricted to protocol administrator
- User functions validate caller permissions
- No external contract dependencies

### Overflow Protection
- All arithmetic operations include overflow checks
- Maximum safe integer value enforced: `u340282366920938463463374607431768211455`

### Validation
- Comprehensive input validation on all functions
- Zero-value transaction prevention
- Collateral adequacy checks before loan issuance

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-UNAUTHORIZED-CALLER | Caller lacks required permissions |
| u2 | ERR-COLLATERAL-BALANCE-INSUFFICIENT | Insufficient collateral balance |
| u3 | ERR-PROTOCOL-TREASURY-INSUFFICIENT | Protocol lacks funds for loan |
| u4 | ERR-COLLATERAL-COVERAGE-INADEQUATE | Inadequate collateralization |
| u5 | ERR-BORROWING-POSITION-MISSING | Account does not exist |
| u6 | ERR-BORROWING-POSITION-EXISTS | Account already exists |
| u7 | ERR-TRANSACTION-AMOUNT-INVALID | Invalid transaction amount |
| u8 | ERR-LIQUIDATION-THRESHOLD-NOT-REACHED | Position not eligible for liquidation |
| u9 | ERR-PROTOCOL-FEE-LIMIT-EXCEEDED | Fee exceeds maximum allowed |
| u10 | ERR-ZERO-VALUE-TRANSACTION-REJECTED | Zero-value transaction not allowed |

## Getting Started

### Prerequisites
- Stacks blockchain environment
- STX tokens for collateral
- Understanding of DeFi lending mechanics

### Basic Workflow

1. **Setup Account**
   ```clarity
   (contract-call? .lending-protocol establish-new-borrowing-account)
   ```

2. **Deposit Collateral**
   ```clarity
   (contract-call? .lending-protocol secure-stx-as-collateral u1000000) ;; 1 STX
   ```

3. **Take Loan**
   ```clarity
   (contract-call? .lending-protocol issue-collateral-backed-loan u500000) ;; 0.5 STX worth
   ```

4. **Monitor Position**
   ```clarity
   (contract-call? .lending-protocol calculate-borrower-collateralization-health tx-sender)
   ```

5. **Repay Loan**
   ```clarity
   (contract-call? .lending-protocol process-borrower-loan-payment u100000)
   ```