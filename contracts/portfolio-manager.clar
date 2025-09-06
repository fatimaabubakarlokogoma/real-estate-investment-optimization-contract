;; Portfolio Diversification And Risk Management Smart Contract
;; A comprehensive system for managing real estate investment portfolios
;; with advanced diversification analysis, risk management, and performance tracking

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-INVALID-PORTFOLIO (err u202))
(define-constant ERR-INVALID-AMOUNT (err u203))
(define-constant ERR-UNAUTHORIZED (err u204))
(define-constant ERR-INVALID-PERCENTAGE (err u205))
(define-constant ERR-PORTFOLIO-FULL (err u206))

;; Data Variables
(define-data-var next-portfolio-id uint u1)
(define-data-var contract-active bool true)
(define-data-var management-fee-rate uint u100) ;; 1% management fee
(define-data-var min-diversification-threshold uint u50) ;; Minimum diversification score

;; Data Maps
(define-map portfolios
  uint
  {
    owner: principal,
    name: (string-ascii 50),
    total-value: uint,
    property-count: uint,
    diversification-score: uint, ;; 0-100 scale
    risk-score: uint, ;; Weighted average risk 1-10
    expected-annual-return: uint, ;; Expected return percentage * 100
    created-at: uint,
    last-rebalanced: uint,
    status: (string-ascii 20) ;; "active", "paused", "liquidating"
  }
)

(define-map portfolio-holdings
  { portfolio-id: uint, holding-id: uint }
  {
    property-address: (string-ascii 100),
    property-type: (string-ascii 20),
    purchase-price: uint,
    current-value: uint,
    allocation-percentage: uint, ;; Percentage * 100 for precision
    location-region: (string-ascii 30),
    risk-level: uint,
    annual-income: uint,
    monthly-expenses: uint,
    acquired-at: uint
  }
)

(define-map portfolio-performance
  uint
  {
    total-monthly-income: uint,
    total-monthly-expenses: uint,
    net-monthly-cash-flow: int,
    capital-appreciation: int, ;; Total appreciation amount
    total-return: int, ;; Cash flow + appreciation
    performance-period: uint, ;; Number of months tracked
    last-updated: uint
  }
)

(define-map diversification-analysis
  uint
  {
    concentration-risk: uint, ;; 0-100 (100 = highly concentrated)
    diversification-score: uint, ;; 0-100 overall diversification
    analysis-date: uint
  }
)

(define-map user-portfolios
  principal
  (list 10 uint) ;; User can have up to 10 portfolios
)

;; Read-only functions

(define-read-only (get-portfolio (portfolio-id uint))
  (map-get? portfolios portfolio-id)
)

(define-read-only (get-portfolio-holding (portfolio-id uint) (holding-id uint))
  (map-get? portfolio-holdings { portfolio-id: portfolio-id, holding-id: holding-id })
)

(define-read-only (get-portfolio-performance (portfolio-id uint))
  (map-get? portfolio-performance portfolio-id)
)

(define-read-only (get-diversification-analysis (portfolio-id uint))
  (map-get? diversification-analysis portfolio-id)
)

(define-read-only (get-user-portfolios (user principal))
  (default-to (list) (map-get? user-portfolios user))
)

(define-read-only (get-contract-info)
  {
    owner: CONTRACT-OWNER,
    active: (var-get contract-active),
    next-portfolio-id: (var-get next-portfolio-id),
    management-fee-rate: (var-get management-fee-rate),
    min-diversification-threshold: (var-get min-diversification-threshold)
  }
)

(define-read-only (calculate-diversification-score (portfolio-id uint))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) u0))
    (property-count (get property-count portfolio))
    ;; Simple diversification calculation based on property count
    (base-score (* property-count u15)) ;; 15 points per property
    (max-score (if (> base-score u100) u100 base-score))
  )
  max-score)
)

(define-read-only (get-portfolio-health-score (portfolio-id uint))
  (let (
    (diversification (calculate-diversification-score portfolio-id))
    (portfolio (unwrap! (get-portfolio portfolio-id) u0))
    (risk-penalty (* (get risk-score portfolio) u5))
    (return-bonus (/ (get expected-annual-return portfolio) u10))
    (health-score (+ diversification return-bonus (if (> risk-penalty diversification) u0 (- diversification risk-penalty))))
  )
  (if (> health-score u100) u100 health-score))
)

;; Public functions

(define-public (create-portfolio (name (string-ascii 50)))
  (let (
    (portfolio-id (var-get next-portfolio-id))
    (user-portfolio-list (get-user-portfolios tx-sender))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (< (len user-portfolio-list) u10) ERR-PORTFOLIO-FULL)
    
    (map-set portfolios portfolio-id
      {
        owner: tx-sender,
        name: name,
        total-value: u0,
        property-count: u0,
        diversification-score: u0,
        risk-score: u5, ;; Start with neutral risk
        expected-annual-return: u0,
        created-at: block-height,
        last-rebalanced: block-height,
        status: "active"
      }
    )
    
    ;; Add portfolio to user's list
    (map-set user-portfolios tx-sender
      (unwrap! (as-max-len? (append user-portfolio-list portfolio-id) u10) ERR-PORTFOLIO-FULL)
    )
    
    (var-set next-portfolio-id (+ portfolio-id u1))
    (ok portfolio-id)
  )
)

(define-public (add-property-to-portfolio
  (portfolio-id uint)
  (property-address (string-ascii 100))
  (property-type (string-ascii 20))
  (purchase-price uint)
  (current-value uint)
  (location-region (string-ascii 30))
  (risk-level uint)
  (annual-income uint)
  (monthly-expenses uint))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND))
    (holding-id (get property-count portfolio))
    (new-total-value (+ (get total-value portfolio) current-value))
    (allocation-percentage (if (> new-total-value u0) 
                             (/ (* current-value u10000) new-total-value) 
                             u10000))
    (new-property-count (+ holding-id u1))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (> purchase-price u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= risk-level u1) (<= risk-level u10)) ERR-INVALID-AMOUNT)
    
    ;; Add holding to portfolio
    (map-set portfolio-holdings { portfolio-id: portfolio-id, holding-id: holding-id }
      {
        property-address: property-address,
        property-type: property-type,
        purchase-price: purchase-price,
        current-value: current-value,
        allocation-percentage: allocation-percentage,
        location-region: location-region,
        risk-level: risk-level,
        annual-income: annual-income,
        monthly-expenses: monthly-expenses,
        acquired-at: block-height
      }
    )
    
    ;; Update portfolio totals
    (map-set portfolios portfolio-id
      (merge portfolio
        {
          total-value: new-total-value,
          property-count: new-property-count,
          diversification-score: (calculate-diversification-score portfolio-id)
        }
      )
    )
    
    (ok holding-id)
  )
)

(define-public (update-portfolio-performance
  (portfolio-id uint)
  (monthly-income uint)
  (monthly-expenses uint)
  (capital-appreciation int))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND))
    (net-cash-flow (- (to-int monthly-income) (to-int monthly-expenses)))
    (total-return (+ net-cash-flow capital-appreciation))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    
    (map-set portfolio-performance portfolio-id
      {
        total-monthly-income: monthly-income,
        total-monthly-expenses: monthly-expenses,
        net-monthly-cash-flow: net-cash-flow,
        capital-appreciation: capital-appreciation,
        total-return: total-return,
        performance-period: u1, ;; Simplified to 1 month tracking
        last-updated: block-height
      }
    )
    
    (ok total-return)
  )
)

(define-public (analyze-diversification (portfolio-id uint))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND))
    (diversification-score (calculate-diversification-score portfolio-id))
    (concentration-risk (- u100 diversification-score))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    
    (map-set diversification-analysis portfolio-id
      {
        concentration-risk: concentration-risk,
        diversification-score: diversification-score,
        analysis-date: block-height
      }
    )
    
    (ok diversification-score)
  )
)

(define-public (rebalance-portfolio (portfolio-id uint))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND))
    (current-score (get diversification-score portfolio))
    (improved-score (+ current-score u10)) ;; Assume 10-point improvement
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    
    ;; Update portfolio with improved diversification
    (map-set portfolios portfolio-id
      (merge portfolio
        {
          diversification-score: (if (> improved-score u100) u100 improved-score),
          last-rebalanced: block-height
        }
      )
    )
    
    (ok {
      portfolio-id: portfolio-id,
      old-score: current-score,
      new-score: (if (> improved-score u100) u100 improved-score),
      rebalanced-at: block-height
    })
  )
)

(define-public (pause-portfolio (portfolio-id uint))
  (let ((portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND)))
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    
    (map-set portfolios portfolio-id
      (merge portfolio { status: "paused" })
    )
    (ok true)
  )
)

(define-public (activate-portfolio (portfolio-id uint))
  (let ((portfolio (unwrap! (get-portfolio portfolio-id) ERR-NOT-FOUND)))
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get owner portfolio) tx-sender) ERR-UNAUTHORIZED)
    
    (map-set portfolios portfolio-id
      (merge portfolio { status: "active" })
    )
    (ok true)
  )
)

;; Admin functions

(define-public (toggle-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

(define-public (update-management-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (<= new-rate u1000) ERR-INVALID-PERCENTAGE) ;; Max 10% fee
    (var-set management-fee-rate new-rate)
    (ok true)
  )
)

;; Advanced portfolio analysis functions

(define-read-only (compare-portfolios (portfolio-id-1 uint) (portfolio-id-2 uint))
  (let (
    (portfolio-1 (unwrap! (get-portfolio portfolio-id-1) none))
    (portfolio-2 (unwrap! (get-portfolio portfolio-id-2) none))
    (health-1 (get-portfolio-health-score portfolio-id-1))
    (health-2 (get-portfolio-health-score portfolio-id-2))
    (risk-1 (get risk-score portfolio-1))
    (risk-2 (get risk-score portfolio-2))
  )
    (some {
      portfolio-1: portfolio-id-1,
      portfolio-2: portfolio-id-2,
      healthier-portfolio: (if (> health-1 health-2) portfolio-id-1 portfolio-id-2),
      health-difference: (if (> health-1 health-2) (- health-1 health-2) (- health-2 health-1)),
      risk-comparison: (if (< risk-1 risk-2) "portfolio-1-safer" "portfolio-2-safer")
    })
  )
)

(define-read-only (get-portfolio-summary (portfolio-id uint))
  (let (
    (portfolio (unwrap! (get-portfolio portfolio-id) none))
    (health-score (get-portfolio-health-score portfolio-id))
    (diversification (get diversification-score portfolio))
    (performance (default-to 
      { total-return: 0, net-monthly-cash-flow: 0 }
      (get-portfolio-performance portfolio-id)))
  )
    (some {
      portfolio-id: portfolio-id,
      owner: (get owner portfolio),
      total-value: (get total-value portfolio),
      property-count: (get property-count portfolio),
      health-score: health-score,
      diversification-score: diversification,
      monthly-cash-flow: (get net-monthly-cash-flow performance),
      total-return: (get total-return performance),
      status: (get status portfolio)
    })
  )
)

