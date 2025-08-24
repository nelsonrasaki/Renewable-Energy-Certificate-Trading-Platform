;; Certificate Manager Contract
;; Issues and manages renewable energy certificates

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-CERTIFICATE (err u201))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u202))
(define-constant ERR-CERTIFICATE-RETIRED (err u203))
(define-constant ERR-INVALID-TRANSFER (err u204))
(define-constant ERR-GENERATION-NOT-VERIFIED (err u205))

;; Data Variables
(define-data-var next-certificate-id uint u1)
(define-data-var total-certificates-issued uint u0)
(define-data-var total-certificates-retired uint u0)

;; Data Maps
(define-map authorized-issuers principal bool)
(define-map certificates
  uint
  {
    generation-record-id: uint,
    owner: principal,
    mwh-amount: uint,
    issue-date: uint,
    expiration-date: uint,
    retired: bool,
    retirement-date: (optional uint),
    certificate-type: (string-ascii 20)
  }
)

(define-map owner-certificates principal (list 100 uint))
(define-map certificate-transfers
  uint
  {
    from: principal,
    to: principal,
    transfer-date: uint,
    certificate-id: uint
  }
)

;; Authorization Functions
(define-public (add-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-issuers issuer true))
  )
)

(define-public (remove-authorized-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-issuers issuer))
  )
)

;; Certificate Issuance
(define-public (issue-certificate
  (generation-record-id uint)
  (owner principal)
  (mwh-amount uint)
  (expiration-date uint)
  (certificate-type (string-ascii 20))
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
    )
    (asserts! (default-to false (map-get? authorized-issuers tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> mwh-amount u0) ERR-INVALID-CERTIFICATE)
    (asserts! (> expiration-date block-height) ERR-INVALID-CERTIFICATE)

    ;; Note: In a real implementation, we would verify the generation record exists and is verified
    ;; For this demo, we assume the generation-record-id is valid

    (map-set certificates certificate-id
      {
        generation-record-id: generation-record-id,
        owner: owner,
        mwh-amount: mwh-amount,
        issue-date: block-height,
        expiration-date: expiration-date,
        retired: false,
        retirement-date: none,
        certificate-type: certificate-type
      }
    )

    ;; Update owner's certificate list
    (let
      (
        (current-certs (default-to (list) (map-get? owner-certificates owner)))
      )
      (map-set owner-certificates owner (unwrap! (as-max-len? (append current-certs certificate-id) u100) ERR-INVALID-CERTIFICATE))
    )

    (var-set next-certificate-id (+ certificate-id u1))
    (var-set total-certificates-issued (+ (var-get total-certificates-issued) u1))

    (ok certificate-id)
  )
)

;; Certificate Transfer
(define-public (transfer-certificate (certificate-id uint) (new-owner principal))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
    )
    (asserts! (is-eq (get owner certificate) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get retired certificate)) ERR-CERTIFICATE-RETIRED)
    (asserts! (< block-height (get expiration-date certificate)) ERR-INVALID-CERTIFICATE)

    ;; Update certificate ownership
    (map-set certificates certificate-id
      (merge certificate { owner: new-owner })
    )

    ;; Record transfer
    (map-set certificate-transfers certificate-id
      {
        from: tx-sender,
        to: new-owner,
        transfer-date: block-height,
        certificate-id: certificate-id
      }
    )

    ;; Update owner certificate lists
    (let
      (
        (old-owner-certs (default-to (list) (map-get? owner-certificates tx-sender)))
        (new-owner-certs (default-to (list) (map-get? owner-certificates new-owner)))
      )
      (map-set owner-certificates new-owner
        (unwrap! (as-max-len? (append new-owner-certs certificate-id) u100) ERR-INVALID-TRANSFER))
    )

    (ok true)
  )
)

;; Certificate Retirement
(define-public (retire-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
    )
    (asserts! (is-eq (get owner certificate) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get retired certificate)) ERR-CERTIFICATE-RETIRED)

    (map-set certificates certificate-id
      (merge certificate {
        retired: true,
        retirement-date: (some block-height)
      })
    )

    (var-set total-certificates-retired (+ (var-get total-certificates-retired) u1))
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates certificate-id)
)

(define-read-only (get-owner-certificates (owner principal))
  (default-to (list) (map-get? owner-certificates owner))
)

(define-read-only (get-certificate-transfer (certificate-id uint))
  (map-get? certificate-transfers certificate-id)
)

(define-read-only (get-total-certificates-issued)
  (var-get total-certificates-issued)
)

(define-read-only (get-total-certificates-retired)
  (var-get total-certificates-retired)
)

(define-read-only (is-authorized-issuer (issuer principal))
  (default-to false (map-get? authorized-issuers issuer))
)

(define-read-only (is-certificate-valid (certificate-id uint))
  (match (map-get? certificates certificate-id)
    certificate (and
      (not (get retired certificate))
      (< block-height (get expiration-date certificate))
    )
    false
  )
)
