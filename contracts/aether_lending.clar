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

;; Protocol State
(define-data-var protocol-paused bool false)

;; Data Variables
[Previous data variables remain unchanged...]

;; Events
(define-data-var last-event-id uint u0)

(define-map protocol-events 
  uint 
  {
    event-type: (string-ascii 12),
    user: principal,
    token: (string-ascii 8),
    amount: uint,
    block: uint
  }
)

;; Helper Functions
(define-private (create-event (event-type (string-ascii 12)) (user principal) (token (string-ascii 8)) (amount uint))
  (let ((event-id (+ (var-get last-event-id) u1)))
    (begin
      (map-set protocol-events event-id {
        event-type: event-type,
        user: user,
        token: token,
        amount: amount,
        block: block-height
      })
      (var-set last-event-id event-id)
    )
  )
)

;; [Previous helper functions remain unchanged...]

;; Admin Functions
(define-public (toggle-protocol-pause)
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (ok (var-set protocol-paused (not (var-get protocol-paused))))
  )
)

;; [Previous admin functions remain unchanged...]

;; New Repayment Function
(define-public (repay (token (string-ascii 8)) (amount uint))
  (let (
    (loan (unwrap! (map-get? borrows { user: tx-sender, token: token }) ERR-NO-LOAN-EXISTS))
    (total-due (+ (get amount loan) (calculate-interest (get amount loan) (- block-height (get start-block loan)))))
  )
  (begin
    (asserts! (not (var-get protocol-paused)) ERR-PROTOCOL-PAUSED)
    
    ;; Transfer repayment
    (match token
      "stx" (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      "xbtc" (try! (contract-call? .xbtc transfer amount tx-sender (as-contract tx-sender)))
      "alex" (try! (contract-call? .alex transfer amount tx-sender (as-contract tx-sender)))
      ERR-INVALID-TOKEN
    )

    ;; Return collateral if full repayment
    (when (>= amount total-due)
      (match (get collateral-token loan)
        "stx" (try! (as-contract (stx-transfer? (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
        "xbtc" (try! (as-contract (contract-call? .xbtc transfer (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
        "alex" (try! (as-contract (contract-call? .alex transfer (get collateral-amount loan) (as-contract tx-sender) tx-sender)))
        ERR-INVALID-TOKEN
      )
      (map-delete borrows { user: tx-sender, token: token })
    )

    (create-event "repay" tx-sender token amount)
    (ok true)
  ))
)

;; [Rest of the contract remains unchanged...]
