;; AetherFi Multi-Asset Lending Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant INTEREST-RATE u500) ;; 5% APR
(define-constant COLLATERAL-RATIO u15000) ;; 150% collateralization required 
(define-constant LIQUIDATION-THRESHOLD u13000) ;; 130% liquidation threshold
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-NO-LOAN-EXISTS (err u102))
(define-constant ERR-ABOVE-LIQUIDATION-THRESHOLD (err u103))
(define-constant ERR-INVALID-TOKEN (err u104))
(define-constant ERR-UNAUTHORIZED (err u105))
(define-constant ERR-PROTOCOL-PAUSED (err u106))
(define-constant ERR-ZERO-AMOUNT (err u107))
(define-constant MAX-LOAN-AMOUNT u1000000000000)

;; Protocol State
(define-data-var protocol-paused bool false)

;; [Previous data variables remain unchanged...]

;; Enhanced Repayment Function
(define-public (repay (token (string-ascii 8)) (amount uint))
  (let (
    (loan (unwrap! (map-get? borrows { user: tx-sender, token: token }) ERR-NO-LOAN-EXISTS))
    (total-due (+ (get amount loan) (calculate-interest (get amount loan) (- block-height (get start-block loan)))))
  )
  (begin
    (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer repayment
    (match token
      "stx" (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      "xbtc" (try! (contract-call? .xbtc transfer amount tx-sender (as-contract tx-sender)))
      "alex" (try! (contract-call? .alex transfer amount tx-sender (as-contract tx-sender)))
      ERR-INVALID-TOKEN
    )

    ;; Handle full or partial repayment
    (if (>= amount total-due)
      ;; Full repayment
      (begin
        (match (get collateral-token loan)
          "stx" (try! (as-contract (stx-transfer? (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
          "xbtc" (try! (as-contract (contract-call? .xbtc transfer (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
          "alex" (try! (as-contract (contract-call? .alex transfer (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
          ERR-INVALID-TOKEN
        )
        (map-delete borrows { user: tx-sender, token: token })
      )
      ;; Partial repayment
      (begin
        (map-set borrows 
          { user: tx-sender, token: token }
          (merge loan {
            amount: (- (get amount loan) amount),
            start-block: block-height
          })
        )
      )
    )

    (create-event "repay" tx-sender token amount)
    (ok true)
  ))
)

;; [Rest of the contract remains unchanged...]
