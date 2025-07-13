;; Cultural Immersion Contract
;; Provides authentic cultural context and experiences

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-EXPERIENCE-NOT-FOUND (err u401))
(define-constant ERR-INVALID-CULTURE (err u402))
(define-constant ERR-ALREADY-ENROLLED (err u403))
(define-constant ERR-ENROLLMENT-NOT-FOUND (err u404))
(define-constant ERR-INVALID-RATING (err u405))

;; Data Variables
(define-data-var next-experience-id uint u1)
(define-data-var next-enrollment-id uint u1)

;; Data Maps
(define-map cultural-experiences
  uint
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    culture: (string-ascii 30),
    language: (string-ascii 20),
    difficulty-level: uint,
    duration-minutes: uint,
    creator: principal,
    rating: uint,
    total-participants: uint,
    cost: uint,
    active: bool,
    created-at: uint
  }
)

(define-map enrollments
  uint
  {
    participant: principal,
    experience-id: uint,
    enrolled-at: uint,
    completed: bool,
    completion-time: uint,
    rating-given: uint,
    cultural-points-earned: uint
  }
)

(define-map user-enrollments
  principal
  (list 50 uint)
)

(define-map experience-enrollments
  uint
  (list 100 uint)
)

(define-map user-cultural-points
  principal
  uint
)

(define-map supported-cultures
  (string-ascii 30)
  bool
)

;; Initialize supported cultures
(map-set supported-cultures "american" true)
(map-set supported-cultures "british" true)
(map-set supported-cultures "spanish" true)
(map-set supported-cultures "mexican" true)
(map-set supported-cultures "french" true)
(map-set supported-cultures "german" true)
(map-set supported-cultures "chinese" true)
(map-set supported-cultures "japanese" true)

;; Private Functions
(define-private (is-valid-culture (culture (string-ascii 30)))
  (default-to false (map-get? supported-cultures culture))
)

(define-private (is-valid-difficulty (level uint))
  (and (>= level u1) (<= level u5))
)

(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

(define-private (calculate-cultural-points (difficulty uint) (duration uint))
  (* difficulty (/ duration u30)) ;; Points based on difficulty and duration
)

;; Public Functions
(define-public (create-cultural-experience
  (title (string-ascii 100))
  (description (string-ascii 500))
  (culture (string-ascii 30))
  (language (string-ascii 20))
  (difficulty-level uint)
  (duration-minutes uint)
  (cost uint)
)
  (let
    (
      (experience-id (var-get next-experience-id))
    )
    (asserts! (is-valid-culture culture) ERR-INVALID-CULTURE)
    (asserts! (is-valid-difficulty difficulty-level) ERR-NOT-AUTHORIZED)

    (map-set cultural-experiences experience-id
      {
        title: title,
        description: description,
        culture: culture,
        language: language,
        difficulty-level: difficulty-level,
        duration-minutes: duration-minutes,
        creator: tx-sender,
        rating: u5,
        total-participants: u0,
        cost: cost,
        active: true,
        created-at: block-height
      }
    )

    (var-set next-experience-id (+ experience-id u1))
    (ok experience-id)
  )
)

(define-public (enroll-in-experience (experience-id uint))
  (let
    (
      (enrollment-id (var-get next-enrollment-id))
      (experience (unwrap! (map-get? cultural-experiences experience-id) ERR-EXPERIENCE-NOT-FOUND))
      (user-enrollments-list (default-to (list) (map-get? user-enrollments tx-sender)))
      (experience-enrollments-list (default-to (list) (map-get? experience-enrollments experience-id)))
    )
    (asserts! (get active experience) ERR-NOT-AUTHORIZED)

    (map-set enrollments enrollment-id
      {
        participant: tx-sender,
        experience-id: experience-id,
        enrolled-at: block-height,
        completed: false,
        completion-time: u0,
        rating-given: u0,
        cultural-points-earned: u0
      }
    )

    (map-set user-enrollments tx-sender
      (unwrap! (as-max-len? (append user-enrollments-list enrollment-id) u50) ERR-ALREADY-ENROLLED)
    )

    (map-set experience-enrollments experience-id
      (unwrap! (as-max-len? (append experience-enrollments-list enrollment-id) u100) ERR-NOT-AUTHORIZED)
    )

    (var-set next-enrollment-id (+ enrollment-id u1))
    (ok enrollment-id)
  )
)

(define-public (complete-experience (enrollment-id uint))
  (let
    (
      (enrollment (unwrap! (map-get? enrollments enrollment-id) ERR-ENROLLMENT-NOT-FOUND))
      (experience-id (get experience-id enrollment))
      (experience (unwrap! (map-get? cultural-experiences experience-id) ERR-EXPERIENCE-NOT-FOUND))
      (points-earned (calculate-cultural-points (get difficulty-level experience) (get duration-minutes experience)))
      (current-points (default-to u0 (map-get? user-cultural-points tx-sender)))
    )
    (asserts! (is-eq (get participant enrollment) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed enrollment)) ERR-NOT-AUTHORIZED)

    (map-set enrollments enrollment-id
      (merge enrollment {
        completed: true,
        completion-time: block-height,
        cultural-points-earned: points-earned
      })
    )

    (map-set user-cultural-points tx-sender (+ current-points points-earned))

    ;; Update experience participant count
    (map-set cultural-experiences experience-id
      (merge experience {total-participants: (+ (get total-participants experience) u1)})
    )

    (ok points-earned)
  )
)

(define-public (rate-experience (enrollment-id uint) (rating uint))
  (let
    (
      (enrollment (unwrap! (map-get? enrollments enrollment-id) ERR-ENROLLMENT-NOT-FOUND))
      (experience-id (get experience-id enrollment))
      (experience (unwrap! (map-get? cultural-experiences experience-id) ERR-EXPERIENCE-NOT-FOUND))
      (current-rating (get rating experience))
      (total-participants (get total-participants experience))
      (new-rating (if (> total-participants u0)
                    (/ (+ (* current-rating total-participants) rating) (+ total-participants u1))
                    rating))
    )
    (asserts! (is-eq (get participant enrollment) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get completed enrollment) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-rating rating) ERR-INVALID-RATING)
    (asserts! (is-eq (get rating-given enrollment) u0) ERR-NOT-AUTHORIZED)

    (map-set enrollments enrollment-id
      (merge enrollment {rating-given: rating})
    )

    (map-set cultural-experiences experience-id
      (merge experience {rating: new-rating})
    )

    (ok true)
  )
)

(define-public (toggle-experience-status (experience-id uint))
  (let
    (
      (experience (unwrap! (map-get? cultural-experiences experience-id) ERR-EXPERIENCE-NOT-FOUND))
    )
    (asserts! (is-eq (get creator experience) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set cultural-experiences experience-id
      (merge experience {active: (not (get active experience))})
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-cultural-experience (experience-id uint))
  (map-get? cultural-experiences experience-id)
)

(define-read-only (get-enrollment (enrollment-id uint))
  (map-get? enrollments enrollment-id)
)

(define-read-only (get-user-enrollments (user principal))
  (map-get? user-enrollments user)
)

(define-read-only (get-experience-enrollments (experience-id uint))
  (map-get? experience-enrollments experience-id)
)

(define-read-only (get-user-cultural-points (user principal))
  (default-to u0 (map-get? user-cultural-points user))
)

(define-read-only (get-supported-cultures)
  (list "american" "british" "spanish" "mexican" "french" "german" "chinese" "japanese")
)

(define-read-only (get-experiences-by-culture (culture (string-ascii 30)))
  ;; Simplified - would need more complex filtering in production
  (list u1 u2 u3 u4 u5)
)

(define-read-only (get-user-completion-rate (user principal))
  (let
    (
      (user-enrollment-ids (default-to (list) (map-get? user-enrollments user)))
    )
    (fold calculate-completion-rate user-enrollment-ids {total: u0, completed: u0})
  )
)

(define-private (calculate-completion-rate (enrollment-id uint) (acc {total: uint, completed: uint}))
  (let
    (
      (enrollment (map-get? enrollments enrollment-id))
    )
    (match enrollment
      enrollment-data
        {
          total: (+ (get total acc) u1),
          completed: (if (get completed enrollment-data)
                       (+ (get completed acc) u1)
                       (get completed acc))
        }
      acc
    )
  )
)
