;; Investment Opportunity Analysis And Evaluation Smart Contract
;; A comprehensive system for analyzing real estate investment opportunities
;; with advanced ROI calculations, risk assessment, and market analysis

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PROPERTY (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-UNAUTHORIZED (err u104))
(define-constant ERR-INVALID-SCORE (err u105))
(define-constant ERR-PROPERTY-EXISTS (err u106))

;; Data Variables
(define-data-var next-property-id uint u1)
(define-data-var contract-active bool true)
(define-data-var analysis-fee uint u1000000) ;; 1 STX analysis fee
(define-data-var total-properties-analyzed uint u0)

;; Data Maps
(define-map properties
  uint
  {
    address: (string-ascii 100),
    price: uint,
    annual-rental-income: uint,
    monthly-expenses: uint,
    property-type: (string-ascii 20),
    location-score: uint, ;; 1-100 scale
    market-trend: (string-ascii 10), ;; "bullish", "bearish", "stable"
    risk-level: uint, ;; 1-10 scale (1=low risk, 10=high risk)
    owner: principal,
    created-at: uint,
    verified: bool
  }
)

(define-map property-analysis
  uint
  {
    roi-percentage: uint, ;; ROI * 100 for precision
    monthly-cash-flow: int, ;; Net monthly cash flow
    payback-period: uint, ;; Months to break even
    investment-score: uint, ;; Overall investment score 1-100
    market-rating: (string-ascii 20),
    recommendation: (string-ascii 30),
    analyzed-at: uint,
    analyzer: principal
  }
)

(define-map market-conditions
  (string-ascii 50) ;; Location identifier
  {
    average-price: uint,
    price-trend: (string-ascii 10),
    rental-yield: uint, ;; Average rental yield * 100
    vacancy-rate: uint, ;; Vacancy rate * 100
    market-volatility: uint, ;; Volatility score 1-100
    last-updated: uint
  }
)

(define-map user-preferences
  principal
  {
    max-risk-level: uint,
    min-roi-target: uint,
    preferred-property-types: (list 3 (string-ascii 20)),
    max-investment-amount: uint,
    investment-timeline: uint ;; Months
  }
)

(define-map property-ratings
  uint
  {
    total-ratings: uint,
    sum-ratings: uint,
    average-rating: uint ;; Average * 10 for precision
  }
)

;; Read-only functions

(define-read-only (get-property (property-id uint))
  (map-get? properties property-id)
)

(define-read-only (get-property-analysis (property-id uint))
  (map-get? property-analysis property-id)
)

(define-read-only (get-market-conditions (location (string-ascii 50)))
  (map-get? market-conditions location)
)

(define-read-only (get-user-preferences (user principal))
  (map-get? user-preferences user)
)

(define-read-only (get-property-rating (property-id uint))
  (map-get? property-ratings property-id)
)

(define-read-only (get-contract-stats)
  {
    owner: CONTRACT-OWNER,
    active: (var-get contract-active),
    next-property-id: (var-get next-property-id),
    total-analyzed: (var-get total-properties-analyzed),
    analysis-fee: (var-get analysis-fee)
  }
)

(define-read-only (calculate-roi (price uint) (annual-income uint) (annual-expenses uint))
  (if (> price u0)
    (let ((net-income (if (>= annual-income annual-expenses) (- annual-income annual-expenses) u0)))
      (/ (* net-income u10000) price)) ;; ROI * 10000 for precision
    u0)
)

(define-read-only (calculate-monthly-cash-flow (annual-income uint) (monthly-expenses uint))
  (let ((monthly-income (/ annual-income u12)))
    (if (>= monthly-income monthly-expenses)
      (to-int (- monthly-income monthly-expenses))
      (to-int (- monthly-expenses monthly-income))))
)

(define-read-only (calculate-investment-score 
  (location-score uint) 
  (risk-level uint) 
  (roi uint) 
  (market-trend (string-ascii 10)))
  (let (
    (location-points (/ location-score u1)) ;; Max 100 points
    (risk-points (- u11 risk-level)) ;; Invert risk: lower risk = higher score
    (roi-points (if (> roi u800) u30 (/ roi u27))) ;; Max 30 points for ROI
    (market-points (if (is-eq market-trend "bullish") u20 
                     (if (is-eq market-trend "stable") u10 u5)))
    (total-score (+ location-points (* risk-points u8) roi-points market-points))
  )
  (if (> total-score u100) u100 total-score))
)

;; Public functions

(define-public (add-property 
  (address (string-ascii 100))
  (price uint)
  (annual-rental-income uint)
  (monthly-expenses uint)
  (property-type (string-ascii 20))
  (location-score uint)
  (market-trend (string-ascii 10))
  (risk-level uint))
  (let ((property-id (var-get next-property-id)))
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (asserts! (<= location-score u100) ERR-INVALID-SCORE)
    (asserts! (and (>= risk-level u1) (<= risk-level u10)) ERR-INVALID-SCORE)
    
    (map-set properties property-id
      {
        address: address,
        price: price,
        annual-rental-income: annual-rental-income,
        monthly-expenses: monthly-expenses,
        property-type: property-type,
        location-score: location-score,
        market-trend: market-trend,
        risk-level: risk-level,
        owner: tx-sender,
        created-at: block-height,
        verified: false
      }
    )
    
    (var-set next-property-id (+ property-id u1))
    (ok property-id)
  )
)

(define-public (analyze-property (property-id uint))
  (let (
    (property (unwrap! (get-property property-id) ERR-NOT-FOUND))
    (annual-expenses (* (get monthly-expenses property) u12))
    (roi (calculate-roi (get price property) (get annual-rental-income property) annual-expenses))
    (cash-flow (calculate-monthly-cash-flow (get annual-rental-income property) (get monthly-expenses property)))
    (payback-months (if (> cash-flow 0) (/ (get price property) (to-uint cash-flow)) u0))
    (investment-score (calculate-investment-score 
      (get location-score property)
      (get risk-level property)
      roi
      (get market-trend property)))
    (recommendation (if (>= investment-score u80) "Strong Buy"
                      (if (>= investment-score u60) "Buy"
                        (if (>= investment-score u40) "Hold" "Avoid"))))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    
    (map-set property-analysis property-id
      {
        roi-percentage: roi,
        monthly-cash-flow: cash-flow,
        payback-period: payback-months,
        investment-score: investment-score,
        market-rating: (get market-trend property),
        recommendation: recommendation,
        analyzed-at: block-height,
        analyzer: tx-sender
      }
    )
    
    (var-set total-properties-analyzed (+ (var-get total-properties-analyzed) u1))
    
    (ok {
      property-id: property-id,
      roi: roi,
      cash-flow: cash-flow,
      payback-period: payback-months,
      investment-score: investment-score,
      recommendation: recommendation
    })
  )
)

(define-public (update-market-conditions 
  (location (string-ascii 50))
  (average-price uint)
  (price-trend (string-ascii 10))
  (rental-yield uint)
  (vacancy-rate uint)
  (volatility uint))
  (begin
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (<= volatility u100) ERR-INVALID-SCORE)
    (asserts! (<= vacancy-rate u10000) ERR-INVALID-SCORE) ;; Max 100%
    
    (map-set market-conditions location
      {
        average-price: average-price,
        price-trend: price-trend,
        rental-yield: rental-yield,
        vacancy-rate: vacancy-rate,
        market-volatility: volatility,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-public (set-user-preferences 
  (max-risk uint)
  (min-roi uint)
  (property-types (list 3 (string-ascii 20)))
  (max-investment uint)
  (timeline uint))
  (begin
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (and (>= max-risk u1) (<= max-risk u10)) ERR-INVALID-SCORE)
    
    (map-set user-preferences tx-sender
      {
        max-risk-level: max-risk,
        min-roi-target: min-roi,
        preferred-property-types: property-types,
        max-investment-amount: max-investment,
        investment-timeline: timeline
      }
    )
    (ok true)
  )
)

(define-public (rate-property (property-id uint) (rating uint))
  (let (
    (current-rating (default-to 
      { total-ratings: u0, sum-ratings: u0, average-rating: u0 }
      (map-get? property-ratings property-id)))
    (new-total (+ (get total-ratings current-rating) u1))
    (new-sum (+ (get sum-ratings current-rating) rating))
    (new-average (/ (* new-sum u10) new-total))
  )
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    (asserts! (is-some (get-property property-id)) ERR-NOT-FOUND)
    (asserts! (and (>= rating u1) (<= rating u10)) ERR-INVALID-SCORE)
    
    (map-set property-ratings property-id
      {
        total-ratings: new-total,
        sum-ratings: new-sum,
        average-rating: new-average
      }
    )
    (ok new-average)
  )
)

(define-public (verify-property (property-id uint))
  (let ((property (unwrap! (get-property property-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (var-get contract-active) ERR-UNAUTHORIZED)
    
    (map-set properties property-id
      (merge property { verified: true })
    )
    (ok true)
  )
)

(define-public (toggle-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

(define-public (update-analysis-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (var-set analysis-fee new-fee)
    (ok true)
  )
)

;; Advanced analysis functions

(define-read-only (compare-properties (property-id-1 uint) (property-id-2 uint))
  (let (
    (analysis-1 (unwrap! (get-property-analysis property-id-1) none))
    (analysis-2 (unwrap! (get-property-analysis property-id-2) none))
    (score-1 (get investment-score analysis-1))
    (score-2 (get investment-score analysis-2))
    (roi-1 (get roi-percentage analysis-1))
    (roi-2 (get roi-percentage analysis-2))
  )
    (some {
      property-1: property-id-1,
      property-2: property-id-2,
      better-investment: (if (> score-1 score-2) property-id-1 property-id-2),
      score-difference: (if (> score-1 score-2) (- score-1 score-2) (- score-2 score-1)),
      roi-comparison: (if (> roi-1 roi-2) "property-1-higher" "property-2-higher")
    })
  )
)

(define-read-only (get-investment-recommendations (user principal))
  (match (get-user-preferences user)
    preferences
    (some {
      max-risk: (get max-risk-level preferences),
      min-roi: (get min-roi-target preferences),
      preferred-types: (get preferred-property-types preferences),
      recommendation: "Analyze properties matching your criteria"
    })
    none
  )
)

