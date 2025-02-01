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

;; Data Variables
(define-data-var total-deposits {
  stx: uint,
  xbtc: uint,
  alex: uint
} {
  stx: u0,
  xbtc: u0, 
  alex: u0
})

(define-data-var total-borrows {
  stx: uint,
  xbtc: uint,
  alex: uint
} {
  stx: u0,
  xbtc: u0,
  alex: u0
})

;; Data Maps
(define-map deposits 
  { user: principal, token: (string-ascii 8) }
  uint
)

(define-map borrows
  { user: principal, token: (string-ascii 8) }
  { 
    amount: uint,
    collateral-token: (string-ascii 8),
    collateral-amount: uint,
    start-block: uint
  }
)

(define-map token-prices
  (string-ascii 8)
  uint
)

;; Helper Functions
(define-private (calculate-interest (principal uint) (blocks uint))
  (let (
    (interest-per-block (/ (* principal INTEREST-RATE) (* u100 u144 u365)))
  )
  (* interest-per-block blocks)
  )
)

(define-private (get-token-price (token (string-ascii 8)))
  (default-to u0 (map-get? token-prices token))
)

(define-private (get-collateral-ratio (borrow-amount uint) (borrow-token (string-ascii 8)) (collateral-amount uint) (collateral-token (string-ascii 8)))
  (let (
    (borrow-value (* borrow-amount (get-token-price borrow-token)))
    (collateral-value (* collateral-amount (get-token-price collateral-token)))
  )
  (/ (* collateral-value u10000) borrow-value)
  )
)

;; Admin Functions
(define-public (set-token-price (token (string-ascii 8)) (price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (map-set token-prices token price)
    (ok true)
  )
)

;; Public Functions  
(define-public (deposit (token (string-ascii 8)) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? deposits { user: tx-sender, token: token })))
  )
  (match token
    "stx" (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    "xbtc" (try! (contract-call? .xbtc transfer amount tx-sender (as-contract tx-sender)))
    "alex" (try! (contract-call? .alex transfer amount tx-sender (as-contract tx-sender)))
    ERR-INVALID-TOKEN
  )
  (map-set deposits { user: tx-sender, token: token } (+ current-balance amount))
  (match token 
    "stx" (var-set total-deposits (merge (var-get total-deposits) { stx: (+ (get stx (var-get total-deposits)) amount) }))
    "xbtc" (var-set total-deposits (merge (var-get total-deposits) { xbtc: (+ (get xbtc (var-get total-deposits)) amount) }))
    "alex" (var-set total-deposits (merge (var-get total-deposits) { alex: (+ (get alex (var-get total-deposits)) amount) }))
  )
  (ok true)
  )
)

(define-public (withdraw (token (string-ascii 8)) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? deposits { user: tx-sender, token: token })))
  )
  (if (<= amount current-balance)
    (begin
      (match token
        "stx" (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        "xbtc" (try! (as-contract (contract-call? .xbtc transfer amount (as-contract tx-sender) tx-sender)))
        "alex" (try! (as-contract (contract-call? .alex transfer amount (as-contract tx-sender) tx-sender)))
        ERR-INVALID-TOKEN
      )
      (map-set deposits { user: tx-sender, token: token } (- current-balance amount))
      (match token
        "stx" (var-set total-deposits (merge (var-get total-deposits) { stx: (- (get stx (var-get total-deposits)) amount) }))
        "xbtc" (var-set total-deposits (merge (var-get total-deposits) { xbtc: (- (get xbtc (var-get total-deposits)) amount) }))
        "alex" (var-set total-deposits (merge (var-get total-deposits) { alex: (- (get alex (var-get total-deposits)) amount) }))
      )
      (ok true)
    )
    ERR-INSUFFICIENT-BALANCE
  ))
)

(define-public (borrow (token (string-ascii 8)) (amount uint) (collateral-token (string-ascii 8)) (collateral-amount uint))
  (let (
    (collateral-ratio (get-collateral-ratio amount token collateral-amount collateral-token))
  )
  (if (>= collateral-ratio COLLATERAL-RATIO)
    (begin
      (match collateral-token
        "stx" (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        "xbtc" (try! (contract-call? .xbtc transfer collateral-amount tx-sender (as-contract tx-sender)))
        "alex" (try! (contract-call? .alex transfer collateral-amount tx-sender (as-contract tx-sender)))
        ERR-INVALID-TOKEN
      )
      (match token
        "stx" (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
        "xbtc" (try! (as-contract (contract-call? .xbtc transfer amount (as-contract tx-sender) tx-sender)))
        "alex" (try! (as-contract (contract-call? .alex transfer amount (as-contract tx-sender) tx-sender)))
        ERR-INVALID-TOKEN
      )
      (map-set borrows { user: tx-sender, token: token } {
        amount: amount,
        collateral-token: collateral-token,
        collateral-amount: collateral-amount,
        start-block: block-height
      })
      (match token
        "stx" (var-set total-borrows (merge (var-get total-borrows) { stx: (+ (get stx (var-get total-borrows)) amount) }))
        "xbtc" (var-set total-borrows (merge (var-get total-borrows) { xbtc: (+ (get xbtc (var-get total-borrows)) amount) }))
        "alex" (var-set total-borrows (merge (var-get total-borrows) { alex: (+ (get alex (var-get total-borrows)) amount) }))
      )
      (ok true)
    )
    ERR-INSUFFICIENT-COLLATERAL
  ))
)

;; Read-only functions
(define-read-only (get-deposit-balance (user principal) (token (string-ascii 8)))
  (ok (default-to u0 (map-get? deposits { user: user, token: token })))
)

(define-read-only (get-loan-data (user principal) (token (string-ascii 8))) 
  (ok (map-get? borrows { user: user, token: token }))
)

(define-read-only (get-protocol-stats)
  (ok {
    total-deposits: (var-get total-deposits),
    total-borrows: (var-get total-borrows)
  })
)
