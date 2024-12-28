;; AetherFi Lending Protocol

;; Constants
(define-constant contract-owner tx-sender)
(define-constant INTEREST-RATE u500) ;; 5% APR
(define-constant COLLATERAL-RATIO u15000) ;; 150% collateralization required
(define-constant LIQUIDATION-THRESHOLD u13000) ;; 130% liquidation threshold
(define-constant ERR-INSUFFICIENT-BALANCE (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-NO-LOAN-EXISTS (err u102))
(define-constant ERR-ABOVE-LIQUIDATION-THRESHOLD (err u103))

;; Data Variables
(define-data-var total-deposits uint u0)
(define-data-var total-borrows uint u0)

;; Data Maps
(define-map deposits principal uint)
(define-map borrows 
    principal 
    { amount: uint, collateral: uint, start-block: uint })

;; Helper Functions
(define-private (calculate-interest (principal uint) (blocks uint))
    (let (
        (interest-per-block (/ (* principal INTEREST-RATE) (* u100 u144 u365)))
    )
    (* interest-per-block blocks)
    )
)

(define-private (get-collateral-ratio (borrow-amount uint) (collateral-amount uint))
    (/ (* collateral-amount u10000) borrow-amount)
)

;; Public Functions
(define-public (deposit (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? deposits tx-sender)))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set deposits tx-sender (+ current-balance amount))
    (var-set total-deposits (+ (var-get total-deposits) amount))
    (ok true)
    )
)

(define-public (withdraw (amount uint))
    (let (
        (current-balance (default-to u0 (map-get? deposits tx-sender)))
    )
    (if (<= amount current-balance)
        (begin
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (map-set deposits tx-sender (- current-balance amount))
            (var-set total-deposits (- (var-get total-deposits) amount))
            (ok true)
        )
        ERR-INSUFFICIENT-BALANCE
    ))
)

(define-public (borrow (amount uint) (collateral uint))
    (let (
        (collateral-ratio (get-collateral-ratio amount collateral))
    )
    (if (>= collateral-ratio COLLATERAL-RATIO)
        (begin
            (try! (stx-transfer? collateral tx-sender (as-contract tx-sender)))
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (map-set borrows tx-sender {
                amount: amount,
                collateral: collateral,
                start-block: block-height
            })
            (var-set total-borrows (+ (var-get total-borrows) amount))
            (ok true)
        )
        ERR-INSUFFICIENT-COLLATERAL
    ))
)

(define-public (repay (amount uint))
    (let (
        (loan (unwrap! (map-get? borrows tx-sender) ERR-NO-LOAN-EXISTS))
        (interest (calculate-interest (get amount loan) (- block-height (get start-block loan))))
        (total-due (+ amount interest))
    )
    (try! (stx-transfer? total-due tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? (get collateral loan) (as-contract tx-sender) tx-sender)))
    (map-delete borrows tx-sender)
    (var-set total-borrows (- (var-get total-borrows) amount))
    (ok true)
    )
)

(define-public (liquidate (borrower principal))
    (let (
        (loan (unwrap! (map-get? borrows borrower) ERR-NO-LOAN-EXISTS))
        (current-ratio (get-collateral-ratio 
            (+ (get amount loan) 
               (calculate-interest (get amount loan) (- block-height (get start-block loan))))
            (get collateral loan)
        ))
    )
    (if (< current-ratio LIQUIDATION-THRESHOLD)
        (begin
            (try! (stx-transfer? (get amount loan) tx-sender (as-contract tx-sender)))
            (try! (as-contract (stx-transfer? (get collateral loan) (as-contract tx-sender) tx-sender)))
            (map-delete borrows borrower)
            (var-set total-borrows (- (var-get total-borrows) (get amount loan)))
            (ok true)
        )
        ERR-ABOVE-LIQUIDATION-THRESHOLD
    ))
)

;; Read-only functions
(define-read-only (get-deposit-balance (user principal))
    (ok (default-to u0 (map-get? deposits user)))
)

(define-read-only (get-loan-data (user principal))
    (ok (map-get? borrows user))
)

(define-read-only (get-protocol-stats)
    (ok {
        total-deposits: (var-get total-deposits),
        total-borrows: (var-get total-borrows)
    })
)