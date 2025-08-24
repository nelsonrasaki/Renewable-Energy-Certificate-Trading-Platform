;; Carbon Footprint Calculator Contract
;; Calculates carbon offsets and environmental impact

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-INVALID-CALCULATION (err u501))
(define-constant ERR-INVALID-ENERGY-TYPE (err u502))
(define-constant ERR-CALCULATION-NOT-FOUND (err u503))

;; Carbon emission factors (kg CO2 per MWh)
(define-constant COAL-EMISSION-FACTOR u820000) ;; 820 kg CO2/MWh
(define-constant NATURAL-GAS-EMISSION-FACTOR u490000) ;; 490 kg CO2/MWh
(define-constant GRID-AVERAGE-EMISSION-FACTOR u400000) ;; 400 kg CO2/MWh (US average)
(define-constant SOLAR-EMISSION-FACTOR u40000) ;; 40 kg CO2/MWh (lifecycle)
(define-constant WIND-EMISSION-FACTOR u11000) ;; 11 kg CO2/MWh (lifecycle)

;; Data Variables
(define-data-var next-calculation-id uint u1)
(define-data-var total-carbon-offset uint u0)
(define-data-var total-calculations uint u0)

;; Data Maps
(define-map carbon-calculations
  uint
  {
    entity: principal,
    energy-type: (string-ascii 20),
    energy-amount-mwh: uint,
    emission-factor: uint,
    total-emissions: uint,
    offset-amount: uint,
    calculation-date: uint,
    verified: bool
  }
)

(define-map entity-calculations principal (list 100 uint))
(define-map emission-factors (string-ascii 20) uint)
(define-map authorized-calculators principal bool)

;; Initialize emission factors
(map-set emission-factors "coal" COAL-EMISSION-FACTOR)
(map-set emission-factors "natural-gas" NATURAL-GAS-EMISSION-FACTOR)
(map-set emission-factors "grid-average" GRID-AVERAGE-EMISSION-FACTOR)
(map-set emission-factors "solar" SOLAR-EMISSION-FACTOR)
(map-set emission-factors "wind" WIND-EMISSION-FACTOR)

;; Authorization Functions
(define-public (add-authorized-calculator (calculator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-calculators calculator true))
  )
)

(define-public (update-emission-factor (energy-type (string-ascii 20)) (factor uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> factor u0) ERR-INVALID-CALCULATION)
    (ok (map-set emission-factors energy-type factor))
  )
)

;; Carbon Calculation Functions
(define-public (calculate-carbon-emissions
  (energy-type (string-ascii 20))
  (energy-amount-mwh uint)
)
  (let
    (
      (emission-factor (unwrap! (map-get? emission-factors energy-type) ERR-INVALID-ENERGY-TYPE))
      (total-emissions (/ (* energy-amount-mwh emission-factor) u1000)) ;; Convert to kg
      (calculation-id (var-get next-calculation-id))
    )
    (asserts! (> energy-amount-mwh u0) ERR-INVALID-CALCULATION)

    (map-set carbon-calculations calculation-id
      {
        entity: tx-sender,
        energy-type: energy-type,
        energy-amount-mwh: energy-amount-mwh,
        emission-factor: emission-factor,
        total-emissions: total-emissions,
        offset-amount: u0,
        calculation-date: block-height,
        verified: false
      }
    )

    ;; Update entity calculations
    (let
      (
        (current-calculations (default-to (list) (map-get? entity-calculations tx-sender)))
      )
      (map-set entity-calculations tx-sender
        (unwrap! (as-max-len? (append current-calculations calculation-id) u100) ERR-INVALID-CALCULATION))
    )

    (var-set next-calculation-id (+ calculation-id u1))
    (var-set total-calculations (+ (var-get total-calculations) u1))

    (ok {
      calculation-id: calculation-id,
      total-emissions: total-emissions
    })
  )
)

(define-public (calculate-carbon-offset
  (renewable-energy-mwh uint)
  (displaced-energy-type (string-ascii 20))
)
  (let
    (
      (renewable-factor (default-to SOLAR-EMISSION-FACTOR (map-get? emission-factors "solar")))
      (displaced-factor (unwrap! (map-get? emission-factors displaced-energy-type) ERR-INVALID-ENERGY-TYPE))
      (renewable-emissions (/ (* renewable-energy-mwh renewable-factor) u1000))
      (displaced-emissions (/ (* renewable-energy-mwh displaced-factor) u1000))
      (offset-amount (if (> displaced-emissions renewable-emissions)
        (- displaced-emissions renewable-emissions)
        u0
      ))
      (calculation-id (var-get next-calculation-id))
    )
    (asserts! (> renewable-energy-mwh u0) ERR-INVALID-CALCULATION)

    (map-set carbon-calculations calculation-id
      {
        entity: tx-sender,
        energy-type: "renewable-offset",
        energy-amount-mwh: renewable-energy-mwh,
        emission-factor: displaced-factor,
        total-emissions: displaced-emissions,
        offset-amount: offset-amount,
        calculation-date: block-height,
        verified: false
      }
    )

    ;; Update totals
    (var-set total-carbon-offset (+ (var-get total-carbon-offset) offset-amount))

    ;; Update entity calculations
    (let
      (
        (current-calculations (default-to (list) (map-get? entity-calculations tx-sender)))
      )
      (map-set entity-calculations tx-sender
        (unwrap! (as-max-len? (append current-calculations calculation-id) u100) ERR-INVALID-CALCULATION))
    )

    (var-set next-calculation-id (+ calculation-id u1))
    (var-set total-calculations (+ (var-get total-calculations) u1))

    (ok {
      calculation-id: calculation-id,
      offset-amount: offset-amount
    })
  )
)

;; Verification Functions
(define-public (verify-calculation (calculation-id uint))
  (let
    (
      (calculation (unwrap! (map-get? carbon-calculations calculation-id) ERR-CALCULATION-NOT-FOUND))
    )
    (asserts! (default-to false (map-get? authorized-calculators tx-sender)) ERR-NOT-AUTHORIZED)

    (map-set carbon-calculations calculation-id
      (merge calculation { verified: true })
    )

    (ok true)
  )
)

;; Portfolio Analysis
(define-public (calculate-portfolio-impact
  (renewable-mwh uint)
  (fossil-mwh uint)
)
  (let
    (
      (renewable-emissions (/ (* renewable-mwh SOLAR-EMISSION-FACTOR) u1000))
      (fossil-emissions (/ (* fossil-mwh GRID-AVERAGE-EMISSION-FACTOR) u1000))
      (total-emissions (+ renewable-emissions fossil-emissions))
      (total-energy (+ renewable-mwh fossil-mwh))
      (renewable-percentage (if (> total-energy u0)
        (/ (* renewable-mwh u100) total-energy)
        u0
      ))
      (emission-intensity (if (> total-energy u0)
        (/ total-emissions total-energy)
        u0
      ))
    )
    (ok {
      total-energy: total-energy,
      renewable-percentage: renewable-percentage,
      total-emissions: total-emissions,
      emission-intensity: emission-intensity,
      renewable-emissions: renewable-emissions,
      fossil-emissions: fossil-emissions
    })
  )
)

;; Read-only Functions
(define-read-only (get-carbon-calculation (calculation-id uint))
  (map-get? carbon-calculations calculation-id)
)

(define-read-only (get-entity-calculations (entity principal))
  (default-to (list) (map-get? entity-calculations entity))
)

(define-read-only (get-emission-factor (energy-type (string-ascii 20)))
  (map-get? emission-factors energy-type)
)

(define-read-only (get-total-carbon-offset)
  (var-get total-carbon-offset)
)

(define-read-only (get-total-calculations)
  (var-get total-calculations)
)

(define-read-only (calculate-emissions-for-energy
  (energy-type (string-ascii 20))
  (energy-amount-mwh uint)
)
  (match (map-get? emission-factors energy-type)
    factor (ok (/ (* energy-amount-mwh factor) u1000))
    ERR-INVALID-ENERGY-TYPE
  )
)

(define-read-only (compare-energy-sources
  (energy-amount-mwh uint)
  (source1 (string-ascii 20))
  (source2 (string-ascii 20))
)
  (let
    (
      (factor1 (unwrap! (map-get? emission-factors source1) ERR-INVALID-ENERGY-TYPE))
      (factor2 (unwrap! (map-get? emission-factors source2) ERR-INVALID-ENERGY-TYPE))
      (emissions1 (/ (* energy-amount-mwh factor1) u1000))
      (emissions2 (/ (* energy-amount-mwh factor2) u1000))
      (difference (if (> emissions1 emissions2)
        (- emissions1 emissions2)
        (- emissions2 emissions1)
      ))
    )
    (ok {
      source1-emissions: emissions1,
      source2-emissions: emissions2,
      difference: difference,
      cleaner-source: (if (< emissions1 emissions2) source1 source2)
    })
  )
)
