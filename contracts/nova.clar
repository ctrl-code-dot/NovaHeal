;; NovaHeal - Decentralized Wellness Support Ecosystem
;; Revolutionizing healthcare funding through quantum-secured blockchain technology
;; Built on Stacks blockchain for ultimate transparency and community trust

;; Error Constants
(define-constant ERR-UNAUTHORIZED-QUANTUM-ACCESS (err u100))
(define-constant ERR-HEALER-ALREADY-REGISTERED (err u101))
(define-constant ERR-HEALER-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-QUANTUM-RESERVES (err u103))
(define-constant ERR-CONTRIBUTION-BELOW-THRESHOLD (err u104))
(define-constant ERR-ECOSYSTEM-MAINTENANCE-MODE (err u105))
(define-constant ERR-INVALID-QUANTUM-AMOUNT (err u106))
(define-constant ERR-INVALID-WELLNESS-TIER (err u107))
(define-constant ERR-INVALID-NEXUS-GUARDIAN (err u108))
(define-constant ERR-QUANTUM-FLOW-LIMIT-EXCEEDED (err u109))

;; Core Ecosystem Variables
(define-data-var nexus-guardian principal tx-sender)
(define-data-var quantum-reserve-pool uint u0)
(define-data-var ecosystem-online bool true)
(define-data-var minimum-quantum-threshold uint u1000000) ;; 1 STX
(define-data-var emergency-protocol-active bool false)
(define-data-var daily-quantum-flow-limit uint u10000000) ;; 10 STX per day
(define-data-var total-quantum-contributors uint u0)

;; Wellness Healers Registry
(define-map wellness-healers-registry 
    principal 
    {
        is-verified-healer: bool,
        total-quantum-received: uint,
        last-quantum-timestamp: uint,
        wellness-tier-status: (string-ascii 20),
        emergency-priority-status: bool
    }
)

;; Quantum Contributors Registry
(define-map quantum-contributors-registry
    principal
    {
        lifetime-quantum-contributions: uint,
        last-quantum-timestamp: uint,
        contributor-nexus-tier: (string-ascii 15)
    }
)

;; Daily Quantum Flow Tracking
(define-map daily-quantum-flow-tracker
    uint ;; day (block-height / 144)
    uint ;; total quantum flowed today
)

;; Read-only Ecosystem Information Functions
(define-read-only (get-nexus-guardian)
    (var-get nexus-guardian)
)

(define-read-only (get-quantum-reserve-pool)
    (var-get quantum-reserve-pool)
)

(define-read-only (get-healer-profile (healer-address principal))
    (map-get? wellness-healers-registry healer-address)
)

(define-read-only (get-contributor-profile (contributor-address principal))
    (map-get? quantum-contributors-registry contributor-address)
)

(define-read-only (is-ecosystem-operational)
    (and (var-get ecosystem-online) (not (var-get emergency-protocol-active)))
)

(define-read-only (get-ecosystem-metrics)
    {
        total-quantum-reserves: (var-get quantum-reserve-pool),
        active-quantum-contributors: (var-get total-quantum-contributors),
        minimum-quantum-contribution: (var-get minimum-quantum-threshold),
        daily-quantum-limit: (var-get daily-quantum-flow-limit),
        emergency-protocol: (var-get emergency-protocol-active)
    }
)

;; Private Utility Functions
(define-private (verify-nexus-guardian-access)
    (is-eq tx-sender (var-get nexus-guardian))
)

(define-private (update-quantum-contributor-profile (contributor-address principal) (quantum-amount uint))
    (let (
        (existing-profile (default-to 
            { 
                lifetime-quantum-contributions: u0, 
                last-quantum-timestamp: u0,
                contributor-nexus-tier: "bronze"
            } 
            (map-get? quantum-contributors-registry contributor-address)
        ))
        (new-total (+ (get lifetime-quantum-contributions existing-profile) quantum-amount))
        (new-tier (determine-quantum-contributor-tier new-total))
    )
    (map-set quantum-contributors-registry
        contributor-address
        {
            lifetime-quantum-contributions: new-total,
            last-quantum-timestamp: block-height,
            contributor-nexus-tier: new-tier
        }
    ))
)

(define-private (determine-quantum-contributor-tier (total-contributed uint))
    (if (>= total-contributed u50000000) ;; 50+ STX
        "platinum"
        (if (>= total-contributed u20000000) ;; 20+ STX
            "gold"
            (if (>= total-contributed u5000000) ;; 5+ STX
                "silver"
                "bronze"
            )
        )
    )
)

(define-private (get-current-quantum-day)
    (/ block-height u144) ;; Approximate blocks per day
)

(define-private (check-daily-quantum-flow-limit (quantum-amount uint))
    (let (
        (current-day (get-current-quantum-day))
        (today-flowed (default-to u0 (map-get? daily-quantum-flow-tracker current-day)))
        (proposed-total (+ today-flowed quantum-amount))
    )
    (<= proposed-total (var-get daily-quantum-flow-limit))
    )
)

(define-private (update-daily-quantum-flow-tracker (quantum-amount uint))
    (let (
        (current-day (get-current-quantum-day))
        (today-flowed (default-to u0 (map-get? daily-quantum-flow-tracker current-day)))
    )
    (map-set daily-quantum-flow-tracker
        current-day
        (+ today-flowed quantum-amount)
    ))
)

;; Validation Functions
(define-private (validate-quantum-contribution-amount (amount uint))
    (and 
        (> amount u0)
        (<= amount u1000000000000) ;; Reasonable upper limit
        (>= amount (var-get minimum-quantum-threshold))
    )
)

(define-private (validate-wellness-tier (tier-level (string-ascii 20)))
    (or 
        (is-eq tier-level "active")
        (is-eq tier-level "priority")
        (is-eq tier-level "critical")
        (is-eq tier-level "recovering")
        (is-eq tier-level "graduated")
    )
)

(define-private (validate-nexus-guardian-address (new-guardian principal))
    (and 
        (not (is-eq new-guardian (var-get nexus-guardian)))
        (not (is-eq new-guardian (as-contract tx-sender)))
    )
)

;; Core Ecosystem Functions
(define-public (contribute-quantum-energy)
    (let (
        (quantum-contribution (stx-get-balance tx-sender))
    )
    (asserts! (validate-quantum-contribution-amount quantum-contribution) ERR-CONTRIBUTION-BELOW-THRESHOLD)
    (asserts! (is-ecosystem-operational) ERR-ECOSYSTEM-MAINTENANCE-MODE)
    
    (try! (stx-transfer? quantum-contribution tx-sender (as-contract tx-sender)))
    (var-set quantum-reserve-pool (+ (var-get quantum-reserve-pool) quantum-contribution))
    (update-quantum-contributor-profile tx-sender quantum-contribution)
    
    ;; Increment contributor count if first-time contributor
    (if (is-none (map-get? quantum-contributors-registry tx-sender))
        (var-set total-quantum-contributors (+ (var-get total-quantum-contributors) u1))
        true
    )
    
    (ok quantum-contribution))
)

(define-public (register-wellness-healer (healer-address principal) (initial-tier (string-ascii 20)))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (validate-wellness-tier initial-tier) ERR-INVALID-WELLNESS-TIER)
        (asserts! (is-none (map-get? wellness-healers-registry healer-address)) ERR-HEALER-ALREADY-REGISTERED)
        
        (map-set wellness-healers-registry 
            healer-address
            {
                is-verified-healer: true,
                total-quantum-received: u0,
                last-quantum-timestamp: u0,
                wellness-tier-status: initial-tier,
                emergency-priority-status: (is-eq initial-tier "critical")
            }
        )
        (ok true)
    )
)

(define-public (distribute-quantum-healing (healer-address principal) (quantum-amount uint))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (is-ecosystem-operational) ERR-ECOSYSTEM-MAINTENANCE-MODE)
        (asserts! (>= (var-get quantum-reserve-pool) quantum-amount) ERR-INSUFFICIENT-QUANTUM-RESERVES)
        (asserts! (check-daily-quantum-flow-limit quantum-amount) ERR-QUANTUM-FLOW-LIMIT-EXCEEDED)
        (asserts! 
            (is-some (map-get? wellness-healers-registry healer-address)) 
            ERR-HEALER-NOT-FOUND
        )
        
        (try! (as-contract (stx-transfer? quantum-amount tx-sender healer-address)))
        (var-set quantum-reserve-pool (- (var-get quantum-reserve-pool) quantum-amount))
        (update-daily-quantum-flow-tracker quantum-amount)
        
        (let (
            (healer-profile (unwrap! (map-get? wellness-healers-registry healer-address) ERR-HEALER-NOT-FOUND))
        )
        (map-set wellness-healers-registry
            healer-address
            {
                is-verified-healer: (get is-verified-healer healer-profile),
                total-quantum-received: (+ (get total-quantum-received healer-profile) quantum-amount),
                last-quantum-timestamp: block-height,
                wellness-tier-status: (get wellness-tier-status healer-profile),
                emergency-priority-status: (get emergency-priority-status healer-profile)
            }
        )
        (ok quantum-amount))
    )
)

;; Enhanced Management Functions
(define-public (batch-distribute-quantum-healing (healers (list 10 {healer: principal, amount: uint})))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (is-ecosystem-operational) ERR-ECOSYSTEM-MAINTENANCE-MODE)
        
        (fold batch-distribute-quantum-helper healers (ok u0))
    )
)

(define-private (batch-distribute-quantum-helper (healer-data {healer: principal, amount: uint}) (previous-result (response uint uint)))
    (match previous-result
        success-value (distribute-quantum-healing (get healer healer-data) (get amount healer-data))
        error-value (err error-value)
    )
)

(define-public (update-minimum-quantum-threshold (new-threshold uint))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (validate-quantum-contribution-amount new-threshold) ERR-INVALID-QUANTUM-AMOUNT)
        (var-set minimum-quantum-threshold new-threshold)
        (ok true)
    )
)

(define-public (toggle-ecosystem-status)
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (var-set ecosystem-online (not (var-get ecosystem-online)))
        (ok true)
    )
)

(define-public (activate-emergency-protocol)
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (var-set emergency-protocol-active true)
        (var-set daily-quantum-flow-limit u50000000) ;; Emergency limit: 50 STX
        (ok true)
    )
)

(define-public (deactivate-emergency-protocol)
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (var-set emergency-protocol-active false)
        (var-set daily-quantum-flow-limit u10000000) ;; Normal limit: 10 STX
        (ok true)
    )
)

(define-public (update-healer-wellness-tier (healer-address principal) (new-tier (string-ascii 20)))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (validate-wellness-tier new-tier) ERR-INVALID-WELLNESS-TIER)
        (asserts! 
            (is-some (map-get? wellness-healers-registry healer-address)) 
            ERR-HEALER-NOT-FOUND
        )
        
        (let (
            (current-profile (unwrap! (map-get? wellness-healers-registry healer-address) ERR-HEALER-NOT-FOUND))
        )
        (map-set wellness-healers-registry
            healer-address
            {
                is-verified-healer: (get is-verified-healer current-profile),
                total-quantum-received: (get total-quantum-received current-profile),
                last-quantum-timestamp: (get last-quantum-timestamp current-profile),
                wellness-tier-status: new-tier,
                emergency-priority-status: (is-eq new-tier "critical")
            }
        )
        (ok true))
    )
)

(define-public (transfer-nexus-guardianship (new-guardian-address principal))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (validate-nexus-guardian-address new-guardian-address) ERR-INVALID-NEXUS-GUARDIAN)
        (var-set nexus-guardian new-guardian-address)
        (ok true)
    )
)

(define-public (set-daily-quantum-flow-limit (new-limit uint))
    (begin
        (asserts! (verify-nexus-guardian-access) ERR-UNAUTHORIZED-QUANTUM-ACCESS)
        (asserts! (and (> new-limit u0) (<= new-limit u100000000)) ERR-INVALID-QUANTUM-AMOUNT)
        (var-set daily-quantum-flow-limit new-limit)
        (ok true)
    )
)