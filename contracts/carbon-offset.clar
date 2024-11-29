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