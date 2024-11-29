;; title: Carbon Offset Marketplace Smart Contract
;; summary: A smart contract for managing carbon offset credits, validators, and transactions.
;; description: This contract allows users to create, validate, buy, transfer, and retire carbon offset credits. It also manages validators and their reputations, and includes functionality for updating platform fees. The contract ensures secure and transparent transactions, with explicit error handling and validation checks.

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-credit-not-available (err u105))
(define-constant err-invalid-status (err u106))
(define-constant err-transfer-failed (err u107))

;; Data Variables
(define-data-var next-credit-id uint u0)
(define-data-var next-validator-id uint u0)
(define-data-var platform-fee uint u25) ;; 2.5% fee

;; Principal Variables
(define-map credits
  { credit-id: uint }
  {
    owner: principal,
    amount: uint,
    price: uint,
    status: (string-ascii 20),
    validator: uint,
    metadata: (string-ascii 256)
  }
)

(define-map balances principal uint)

(define-map validators
  { validator-id: uint }
  {
    address: principal,
    name: (string-ascii 50),
    reputation: uint
  }
)

;; Private Functions
;; Transfers STX internally between sender and recipient
(define-private (transfer-stx-internal (amount uint) (sender principal) (recipient principal))
  (match (stx-transfer? amount sender recipient)
    success true
    error false
  )
)

;; Calculates the platform fee based on the given amount
(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee)) u1000)
)

;; Read-Only Functions
;; Retrieves the details of a specific credit by its ID
(define-read-only (get-credit (credit-id uint))
  (match (map-get? credits { credit-id: credit-id })
    credit (ok credit)
    (err err-not-found)
  )
)

;; Retrieves the balance of a specific user
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? balances user))
)

;; Retrieves the details of a specific validator by its ID
(define-read-only (get-validator (validator-id uint))
  (match (map-get? validators { validator-id: validator-id })
    validator (ok validator)
    (err err-not-found)
  )
)

;; Public Functions
;; Creates a new carbon offset credit
(define-public (create-credit (amount uint) (price uint) (metadata (string-ascii 256)))
  (let
    (
      (credit-id (var-get next-credit-id))
      (new-credit {
        owner: tx-sender,
        amount: amount,
        price: price,
        status: "pending",
        validator: u0,
        metadata: metadata
      })
    )
    ;; Additional input validation
    (asserts! (> amount u0) (err err-invalid-amount))
    (asserts! (> price u0) (err err-invalid-amount))
    
    (map-set credits { credit-id: credit-id } new-credit)
    (var-set next-credit-id (+ credit-id u1))
    (ok credit-id)
  )
)

;; Validates a carbon offset credit by a validator
(define-public (validate-credit (credit-id uint) (validator-id uint) (new-status (string-ascii 20)))
  (let
    (
      (credit (unwrap! (get-credit credit-id) (err err-not-found)))
      (validator (unwrap! (get-validator validator-id) (err err-not-found)))
    )
    (asserts! (is-eq (get address validator) tx-sender) (err err-unauthorized))
    (asserts! (is-eq (get status credit) "pending") (err err-invalid-status))
    (map-set credits { credit-id: credit-id }
      (merge credit { status: new-status, validator: validator-id })
    )
    (ok true)
  )
)

;; Allows a user to buy a carbon offset credit
(define-public (buy-credit (credit-id uint) (amount uint))
  (let
    (
      (credit (unwrap! (get-credit credit-id) (err err-not-found)))
      (total-cost (* amount (get price credit)))
      (fee (calculate-fee total-cost))
      (seller (get owner credit))
    )
    (asserts! (is-eq (get status credit) "validated") (err err-invalid-status))
    (asserts! (<= amount (get amount credit)) (err err-credit-not-available))
    (asserts! (>= (stx-get-balance tx-sender) total-cost) (err err-insufficient-balance))
    
    ;; Use explicit error handling for transfers
    (if (and 
          (transfer-stx-internal total-cost tx-sender seller)
          (transfer-stx-internal fee seller contract-owner)
        )
        (begin
          (map-set credits { credit-id: credit-id }
            (merge credit { amount: (- (get amount credit) amount) })
          )
          
          (map-set balances tx-sender
            (+ (get-balance tx-sender) amount)
          )
          
          (ok true)
        )
        (err err-transfer-failed)
    )
  )
)

;; Transfers credits from one user to another
(define-public (transfer-credits (recipient principal) (amount uint))
  (begin
    ;; Explicit validation checks
    (asserts! (not (is-eq tx-sender recipient)) (err err-unauthorized))
    (asserts! (> amount u0) (err err-invalid-amount))
    
    (let
      (
        (sender-balance (get-balance tx-sender))
        (recipient-balance (get-balance recipient))
      )
      (asserts! (>= sender-balance amount) (err err-insufficient-balance))
      
      (map-set balances tx-sender
        (- sender-balance amount)
      )
      (map-set balances recipient
        (+ recipient-balance amount)
      )
      
      (ok true)
    )
  )
)

;; Retires a specified amount of credits
(define-public (retire-credits (amount uint))
  (let
    (
      (user-balance (get-balance tx-sender))
    )
    (asserts! (> amount u0) (err err-invalid-amount))
    (asserts! (>= user-balance amount) (err err-insufficient-balance))
    
    (map-set balances tx-sender
      (- user-balance amount)
    )
    
    (ok true)
  )
)

;; Adds a new validator to the system
(define-public (add-validator (name (string-ascii 50)))
  (begin
    ;; Additional input validation
    (asserts! (> (len name) u0) (err err-invalid-amount))
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    
    (let
      (
        (validator-id (var-get next-validator-id))
      )
      (map-set validators { validator-id: validator-id }
        {
          address: tx-sender,
          name: name,
          reputation: u100
        }
      )
      (var-set next-validator-id (+ validator-id u1))
      (ok validator-id)
    )
  )
)

;; Updates the reputation of a validator
(define-public (update-validator-reputation (validator-id uint) (new-reputation uint))
  (let
    (
      (validator (unwrap! (get-validator validator-id) (err err-not-found)))
    )
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (and (>= new-reputation u0) (<= new-reputation u100)) (err err-invalid-amount))
    
    (map-set validators { validator-id: validator-id }
      (merge validator { reputation: new-reputation })
    )
    (ok true)
  )
)

;; Updates the platform fee
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (and (>= new-fee u0) (<= new-fee u100)) (err err-invalid-amount))
    (var-set platform-fee new-fee)
    (ok true)
  )
)