;; OVER-COLLATERALIZED STX LENDING PROTOCOL
;; Protocol Name: Over-Collateralized STX Lending Protocol Smart Contract
;;
;; Description:
;; A robust decentralized finance (DeFi) protocol that enables secure lending operations
;; using STX tokens as collateral. Users can lock their STX holdings to mint USD-pegged
;; loans while maintaining ownership of their assets. The protocol enforces strict
;; over-collateralization requirements and features automated liquidation mechanisms
;; to protect the ecosystem from default risk. Built with transparency, security,
;; and capital efficiency as core principles.
;;
;; Protocol Features:
;; - Secure STX-backed lending with USD loan issuance
;; - Minimum 150% over-collateralization requirement
;; - Automated liquidation at 130% collateral threshold
;; - Real-time oracle-based asset price feeds
;; - Governance-controlled protocol parameters
;; - Comprehensive position health monitoring
;; - Fee-based sustainable protocol economics

;; ERROR CODE DEFINITIONS

(define-constant ERR-UNAUTHORIZED-CALLER u1)
(define-constant ERR-COLLATERAL-BALANCE-INSUFFICIENT u2)
(define-constant ERR-PROTOCOL-TREASURY-INSUFFICIENT u3)
(define-constant ERR-COLLATERAL-COVERAGE-INADEQUATE u4)
(define-constant ERR-BORROWING-POSITION-MISSING u5)
(define-constant ERR-BORROWING-POSITION-EXISTS u6)
(define-constant ERR-TRANSACTION-AMOUNT-INVALID u7)
(define-constant ERR-LIQUIDATION-THRESHOLD-NOT-REACHED u8)
(define-constant ERR-PROTOCOL-FEE-LIMIT-EXCEEDED u9)
(define-constant ERR-ZERO-VALUE-TRANSACTION-REJECTED u10)

;; PROTOCOL PARAMETER CONSTANTS

(define-constant required-over-collateralization-percentage u150)
(define-constant automatic-liquidation-trigger-percentage u130)
(define-constant maximum-safe-integer-value u340282366920938463463374607431768211455)
(define-constant protocol-fee-ceiling-percentage u10)
(define-constant standard-loan-origination-fee u1)

;; GLOBAL PROTOCOL STATE

(define-data-var protocol-governance-authority principal tx-sender)
(define-data-var aggregate-stx-collateral-balance uint u0)
(define-data-var aggregate-usd-loan-obligations uint u0)
(define-data-var total-active-borrowing-accounts uint u0)
(define-data-var applicable-protocol-fee-percentage uint standard-loan-origination-fee)

;; CORE DATA MAPPINGS

;; Individual borrower account management
(define-map individual-borrower-accounts
  { account-holder-address: principal }
  {
    locked-stx-collateral-amount: uint,
    outstanding-usd-loan-balance: uint,
    account-last-activity-block: uint
  }
)

;; Cryptocurrency market price oracle
(define-map asset-market-price-feeds
  { digital-asset-ticker: (string-ascii 32) }
  { market-price-in-usd-cents: uint }
)

;; ACCOUNT INFORMATION RETRIEVAL

;; Retrieve individual borrower account details
(define-read-only (get-individual-borrower-account (account-holder-address principal))
  (map-get? individual-borrower-accounts { account-holder-address: account-holder-address })
)

;; Fetch current STX market valuation
(define-read-only (get-current-stx-market-price)
  (default-to u100 
    (get market-price-in-usd-cents 
      (map-get? asset-market-price-feeds { digital-asset-ticker: "STX" })))
)

;; Calculate borrower's collateralization health ratio
(define-read-only (calculate-borrower-collateralization-health (account-holder-address principal))
  (let (
    (borrower-account-data (get-individual-borrower-account account-holder-address))
  )
  (match borrower-account-data
    account-information
    (let (
      (total-collateral-value-usd (* (get locked-stx-collateral-amount account-information) (get-current-stx-market-price)))
      (total-loan-obligations (get outstanding-usd-loan-balance account-information))
    )
    (if (is-eq total-loan-obligations u0)
      u0
      (/ (* total-collateral-value-usd u100) total-loan-obligations)))
    u0
  ))
)

;; Determine available borrowing capacity for account
(define-read-only (calculate-available-borrowing-capacity (account-holder-address principal))
  (let (
    (borrower-account-data (get-individual-borrower-account account-holder-address))
  )
  (match borrower-account-data
    account-information
    (let (
      (collateral-portfolio-value (* (get locked-stx-collateral-amount account-information) (get-current-stx-market-price)))
    )
    (/ (* collateral-portfolio-value u100) required-over-collateralization-percentage))
    u0
  ))
)

;; Assess liquidation vulnerability status
(define-read-only (evaluate-liquidation-vulnerability (account-holder-address principal))
  (let (
    (current-collateralization-ratio (calculate-borrower-collateralization-health account-holder-address))
  )
  (and 
    (> current-collateralization-ratio u0)
    (< current-collateralization-ratio automatic-liquidation-trigger-percentage)
  ))
)

;; Calculate position safety index (100% = liquidation threshold)
(define-read-only (calculate-position-safety-index (account-holder-address principal))
  (let (
    (current-collateralization-ratio (calculate-borrower-collateralization-health account-holder-address))
  )
  (if (is-eq current-collateralization-ratio u0)
    u0
    (/ (* current-collateralization-ratio u100) automatic-liquidation-trigger-percentage)
  ))
)

;; ACCOUNT SETUP AND MANAGEMENT

;; Establish new borrowing account for user
(define-public (establish-new-borrowing-account)
  (let (
    (requesting-user tx-sender)
  )
  ;; Confirm user doesn't have existing account
  (asserts! (is-none (get-individual-borrower-account requesting-user)) 
            (err ERR-BORROWING-POSITION-EXISTS))
  
  ;; Initialize fresh account with zero balances
  (map-set individual-borrower-accounts
    { account-holder-address: requesting-user }
    {
      locked-stx-collateral-amount: u0,
      outstanding-usd-loan-balance: u0,
      account-last-activity-block: block-height
    }
  )
  
  ;; Update protocol-wide account statistics
  (var-set total-active-borrowing-accounts 
           (+ (var-get total-active-borrowing-accounts) u1))
  (ok true))
)

;; Secure STX tokens as loan collateral
(define-public (secure-stx-as-collateral (stx-collateral-deposit-amount uint))
  (let (
    (depositing-user tx-sender)
    (current-account-status (unwrap! (get-individual-borrower-account depositing-user) 
                               (err ERR-BORROWING-POSITION-MISSING)))
    (existing-collateral-balance (get locked-stx-collateral-amount current-account-status))
  )
  ;; Validate collateral deposit amount
  (asserts! (> stx-collateral-deposit-amount u0) (err ERR-ZERO-VALUE-TRANSACTION-REJECTED))
  
  ;; Prevent arithmetic overflow conditions
  (asserts! (<= (+ existing-collateral-balance stx-collateral-deposit-amount) maximum-safe-integer-value) 
            (err ERR-TRANSACTION-AMOUNT-INVALID))
  (asserts! (<= (+ (var-get aggregate-stx-collateral-balance) stx-collateral-deposit-amount) maximum-safe-integer-value) 
            (err ERR-TRANSACTION-AMOUNT-INVALID))
  
  ;; Execute STX transfer to protocol vault
  (try! (stx-transfer? stx-collateral-deposit-amount depositing-user (as-contract tx-sender)))
  
  ;; Update borrower account collateral balance
  (map-set individual-borrower-accounts
    { account-holder-address: depositing-user }
    {
      locked-stx-collateral-amount: (+ existing-collateral-balance stx-collateral-deposit-amount),
      outstanding-usd-loan-balance: (get outstanding-usd-loan-balance current-account-status),
      account-last-activity-block: block-height
    }
  )
  
  ;; Update protocol aggregate collateral tracking
  (var-set aggregate-stx-collateral-balance 
           (+ (var-get aggregate-stx-collateral-balance) stx-collateral-deposit-amount))
  (ok true))
)

;; Release surplus collateral from account
(define-public (release-surplus-collateral (stx-collateral-withdrawal-amount uint))
  (let (
    (withdrawing-user tx-sender)
    (current-account-status (unwrap! (get-individual-borrower-account withdrawing-user) 
                               (err ERR-BORROWING-POSITION-MISSING)))
    (available-collateral-balance (get locked-stx-collateral-amount current-account-status))
    (existing-loan-obligations (get outstanding-usd-loan-balance current-account-status))
  )
    ;; Validate withdrawal request parameters
    (asserts! (> stx-collateral-withdrawal-amount u0) (err ERR-ZERO-VALUE-TRANSACTION-REJECTED))
    (asserts! (<= stx-collateral-withdrawal-amount available-collateral-balance) 
              (err ERR-COLLATERAL-BALANCE-INSUFFICIENT))
    
    ;; Calculate post-withdrawal collateralization status
    (let (
      (remaining-collateral-after-withdrawal (- available-collateral-balance stx-collateral-withdrawal-amount))
      (remaining-collateral-market-value (* remaining-collateral-after-withdrawal (get-current-stx-market-price)))
      (projected-collateralization-ratio (if (is-eq existing-loan-obligations u0)
                               u0
                               (/ (* remaining-collateral-market-value u100) existing-loan-obligations)))
    )
      ;; Ensure withdrawal maintains adequate collateralization
      (asserts! (or (is-eq existing-loan-obligations u0) 
                    (>= projected-collateralization-ratio required-over-collateralization-percentage)) 
                (err ERR-COLLATERAL-COVERAGE-INADEQUATE))
      
      ;; Execute STX return to user wallet
      (try! (as-contract (stx-transfer? stx-collateral-withdrawal-amount 
                                       (as-contract tx-sender) 
                                       withdrawing-user)))
      
      ;; Update account collateral balance
      (map-set individual-borrower-accounts
        { account-holder-address: withdrawing-user }
        {
          locked-stx-collateral-amount: remaining-collateral-after-withdrawal,
          outstanding-usd-loan-balance: existing-loan-obligations,
          account-last-activity-block: block-height
        }
      )
      
      ;; Update protocol aggregate collateral tracking
      (var-set aggregate-stx-collateral-balance 
               (- (var-get aggregate-stx-collateral-balance) stx-collateral-withdrawal-amount))
      (ok true)
    ))
)

;; LOAN ORIGINATION AND SERVICING

;; Issue collateral-backed loan to borrower
(define-public (issue-collateral-backed-loan (requested-loan-principal uint))
  (let (
    (loan-applicant tx-sender)
    (current-account-status (unwrap! (get-individual-borrower-account loan-applicant) 
                               (err ERR-BORROWING-POSITION-MISSING)))
    (pledged-collateral-balance (get locked-stx-collateral-amount current-account-status))
    (existing-debt-obligations (get outstanding-usd-loan-balance current-account-status))
  )
  ;; Validate loan application amount
  (asserts! (> requested-loan-principal u0) (err ERR-ZERO-VALUE-TRANSACTION-REJECTED))
  
  ;; Prevent integer overflow scenarios
  (asserts! (<= (+ existing-debt-obligations requested-loan-principal) maximum-safe-integer-value) 
            (err ERR-TRANSACTION-AMOUNT-INVALID))
  
  ;; Verify collateral adequacy for requested loan
  (let (
    (total-pledged-collateral-value (* pledged-collateral-balance (get-current-stx-market-price)))
    (maximum-allowable-loan-amount (/ (* total-pledged-collateral-value u100) required-over-collateralization-percentage))
    (total-debt-after-new-loan (+ existing-debt-obligations requested-loan-principal))
  )
    ;; Ensure loan maintains over-collateralization requirements
    (asserts! (<= total-debt-after-new-loan maximum-allowable-loan-amount) 
              (err ERR-COLLATERAL-COVERAGE-INADEQUATE))
    
    ;; Verify protocol treasury has sufficient liquidity
    (asserts! (<= requested-loan-principal (stx-get-balance (as-contract tx-sender))) 
              (err ERR-PROTOCOL-TREASURY-INSUFFICIENT))
    
    ;; Disburse approved loan amount to borrower
    (try! (as-contract (stx-transfer? requested-loan-principal 
                                     (as-contract tx-sender) 
                                     loan-applicant)))
    
    ;; Update borrower account with new debt obligation
    (map-set individual-borrower-accounts
      { account-holder-address: loan-applicant }
      {
        locked-stx-collateral-amount: pledged-collateral-balance,
        outstanding-usd-loan-balance: total-debt-after-new-loan,
        account-last-activity-block: block-height
      }
    )
    
    ;; Update protocol aggregate debt tracking
    (var-set aggregate-usd-loan-obligations 
             (+ (var-get aggregate-usd-loan-obligations) requested-loan-principal))
    (ok true)
  ))
)

;; Process borrower loan payment
(define-public (process-borrower-loan-payment (payment-amount uint))
  (let (
    (paying-borrower tx-sender)
    (current-account-status (unwrap! (get-individual-borrower-account paying-borrower) 
                               (err ERR-BORROWING-POSITION-MISSING)))
    (outstanding-debt-balance (get outstanding-usd-loan-balance current-account-status))
  )
  ;; Validate payment amount
  (asserts! (> payment-amount u0) (err ERR-ZERO-VALUE-TRANSACTION-REJECTED))
  
  ;; Calculate payment distribution
  (let (
    (actual-payment-processed (if (> payment-amount outstanding-debt-balance) 
                         outstanding-debt-balance 
                         payment-amount))
    (protocol-service-fee-amount (/ (* actual-payment-processed (var-get applicable-protocol-fee-percentage)) u100))
    (principal-reduction-amount (- actual-payment-processed protocol-service-fee-amount))
  )
    ;; Accept payment from borrower
    (try! (stx-transfer? actual-payment-processed paying-borrower (as-contract tx-sender)))
    
    ;; Update borrower account with reduced debt
    (map-set individual-borrower-accounts
      { account-holder-address: paying-borrower }
      {
        locked-stx-collateral-amount: (get locked-stx-collateral-amount current-account-status),
        outstanding-usd-loan-balance: (- outstanding-debt-balance principal-reduction-amount),
        account-last-activity-block: block-height
      }
    )
    
    ;; Update protocol aggregate debt tracking
    (var-set aggregate-usd-loan-obligations 
             (- (var-get aggregate-usd-loan-obligations) principal-reduction-amount))
    (ok true)
  ))
)

;; LIQUIDATION EXECUTION SYSTEM

;; Execute liquidation of vulnerable borrower position
(define-public (execute-borrower-liquidation (vulnerable-borrower-address principal))
  (let (
    (liquidation-executor tx-sender)
  )
  ;; First validate that the address is eligible for liquidation
  (asserts! (evaluate-liquidation-vulnerability vulnerable-borrower-address) 
            (err ERR-LIQUIDATION-THRESHOLD-NOT-REACHED))
  
  ;; Now safely retrieve the account data since we know it exists and is vulnerable
  (let (
    (vulnerable-account-data (unwrap! (get-individual-borrower-account vulnerable-borrower-address) 
                             (err ERR-BORROWING-POSITION-MISSING)))
    (seizable-collateral-amount (get locked-stx-collateral-amount vulnerable-account-data))
    (liquidatable-debt-amount (get outstanding-usd-loan-balance vulnerable-account-data))
  )
    ;; Validate liquidation target has assets
    (asserts! (> seizable-collateral-amount u0) (err ERR-TRANSACTION-AMOUNT-INVALID))
    (asserts! (> liquidatable-debt-amount u0) (err ERR-TRANSACTION-AMOUNT-INVALID))
    
    ;; Double-check liquidation threshold breach with current price
    (let (
      (current-collateral-market-value (* seizable-collateral-amount (get-current-stx-market-price)))
      (borrower-collateralization-ratio (/ (* current-collateral-market-value u100) liquidatable-debt-amount))
    )
      ;; Position must breach liquidation threshold
      (asserts! (< borrower-collateralization-ratio automatic-liquidation-trigger-percentage) 
                (err ERR-LIQUIDATION-THRESHOLD-NOT-REACHED))
      
      ;; Liquidation executor covers outstanding debt
      (try! (stx-transfer? liquidatable-debt-amount liquidation-executor (as-contract tx-sender)))
      
      ;; Liquidation executor receives collateral assets
      (try! (as-contract (stx-transfer? seizable-collateral-amount 
                                       (as-contract tx-sender) 
                                       liquidation-executor)))
      
      ;; Clear liquidated borrower account
      (map-set individual-borrower-accounts
        { account-holder-address: vulnerable-borrower-address }
        {
          locked-stx-collateral-amount: u0,
          outstanding-usd-loan-balance: u0,
          account-last-activity-block: block-height
        }
      )
      
      ;; Update protocol aggregate accounting
      (var-set aggregate-stx-collateral-balance 
               (- (var-get aggregate-stx-collateral-balance) seizable-collateral-amount))
      (var-set aggregate-usd-loan-obligations 
               (- (var-get aggregate-usd-loan-obligations) liquidatable-debt-amount))
      (ok true)
    )))
)

;; PROTOCOL GOVERNANCE CONTROLS

;; Update cryptocurrency pricing oracle
(define-public (update-cryptocurrency-pricing-oracle (digital-asset-ticker (string-ascii 32)) (updated-price-usd-cents uint))
  (begin
    ;; Verify governance authority
    (asserts! (is-eq tx-sender (var-get protocol-governance-authority)) 
              (err ERR-UNAUTHORIZED-CALLER))
    
    ;; Validate input parameters
    (asserts! (> updated-price-usd-cents u0) (err ERR-ZERO-VALUE-TRANSACTION-REJECTED))
    (asserts! (> (len digital-asset-ticker) u0) (err ERR-TRANSACTION-AMOUNT-INVALID))
    
    ;; Update market price oracle feed
    (map-set asset-market-price-feeds 
      { digital-asset-ticker: digital-asset-ticker } 
      { market-price-in-usd-cents: updated-price-usd-cents }
    )
    (ok true)
  )
)

;; Modify protocol fee parameters
(define-public (modify-protocol-fee-parameters (revised-fee-percentage uint))
  (begin
    ;; Verify governance authority
    (asserts! (is-eq tx-sender (var-get protocol-governance-authority)) 
              (err ERR-UNAUTHORIZED-CALLER))
    
    ;; Enforce fee ceiling constraints
    (asserts! (<= revised-fee-percentage protocol-fee-ceiling-percentage) 
              (err ERR-PROTOCOL-FEE-LIMIT-EXCEEDED))
    
    ;; Apply revised fee structure
    (var-set applicable-protocol-fee-percentage revised-fee-percentage)
    (ok true))
)

;; Transfer protocol governance authority
(define-public (transfer-protocol-governance-authority (designated-new-authority principal))
  (begin
    ;; Verify current governance authority
    (asserts! (is-eq tx-sender (var-get protocol-governance-authority)) 
              (err ERR-UNAUTHORIZED-CALLER))
    
    ;; Prevent transfer to null address
    (asserts! (not (is-eq designated-new-authority 'SP000000000000000000002Q6VF78)) 
              (err ERR-UNAUTHORIZED-CALLER))
    
    ;; Execute authority transfer
    (var-set protocol-governance-authority designated-new-authority)
    (ok true))
)

;; PROTOCOL ANALYTICS AND REPORTING

;; Generate comprehensive protocol performance metrics
(define-read-only (generate-comprehensive-protocol-metrics)
  {
    total-stx-collateral-secured: (var-get aggregate-stx-collateral-balance),
    total-usd-loans-outstanding: (var-get aggregate-usd-loan-obligations),
    active-borrower-accounts: (var-get total-active-borrowing-accounts),
    current-protocol-fee-rate: (var-get applicable-protocol-fee-percentage),
    governance-authority: (var-get protocol-governance-authority),
    capital-utilization-efficiency: (calculate-capital-utilization-efficiency),
    stx-current-market-price: (get-current-stx-market-price)
  }
)

;; Calculate protocol capital utilization efficiency
(define-read-only (calculate-capital-utilization-efficiency)
  (let (
    (aggregate-collateral-market-value (* (var-get aggregate-stx-collateral-balance) (get-current-stx-market-price)))
    (aggregate-outstanding-loans (var-get aggregate-usd-loan-obligations))
  )
  (if (is-eq aggregate-collateral-market-value u0)
    u0
    (/ (* aggregate-outstanding-loans u100) aggregate-collateral-market-value)
  ))
)

;; Generate detailed borrower account assessment
(define-read-only (generate-detailed-borrower-assessment (account-holder-address principal))
  (let (
    (account-details (get-individual-borrower-account account-holder-address))
  )
  (match account-details
    borrower-account-info
    {
      secured-stx-collateral: (get locked-stx-collateral-amount borrower-account-info),
      outstanding-loan-balance: (get outstanding-usd-loan-balance borrower-account-info),
      last-account-activity: (get account-last-activity-block borrower-account-info),
      position-safety-score: (calculate-position-safety-index account-holder-address),
      collateralization-health-ratio: (calculate-borrower-collateralization-health account-holder-address),
      additional-borrowing-capacity: (calculate-available-borrowing-capacity account-holder-address),
      liquidation-vulnerability-status: (evaluate-liquidation-vulnerability account-holder-address)
    }
    {
      secured-stx-collateral: u0,
      outstanding-loan-balance: u0,
      last-account-activity: u0,
      position-safety-score: u0,
      collateralization-health-ratio: u0,
      additional-borrowing-capacity: u0,
      liquidation-vulnerability-status: false
    }
  ))
)