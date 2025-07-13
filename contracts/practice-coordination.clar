;; Practice Coordination Contract
;; Facilitates conversation opportunities and skill application

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-SESSION-NOT-FOUND (err u501))
(define-constant ERR-INVALID-LANGUAGE (err u502))
(define-constant ERR-ALREADY-JOINED (err u503))
(define-constant ERR-SESSION-FULL (err u504))
(define-constant ERR-INVALID-STATUS (err u505))
(define-constant ERR-INVALID-DURATION (err u506))

;; Data Variables
(define-data-var next-session-id uint u1)
(define-data-var next-group-id uint u1)
(define-data-var platform-token-reward uint u10)

;; Data Maps
(define-map practice-sessions
  uint
  {
    host: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    language: (string-ascii 20),
    skill-focus: (string-ascii 50),
    max-participants: uint,
    current-participants: uint,
    scheduled-time: uint,
    duration-minutes: uint,
    status: (string-ascii 20),
    created-at: uint,
    session-type: (string-ascii 30)
  }
)

(define-map session-participants
  uint
  (list 20 principal)
)

(define-map user-sessions
  principal
  (list 100 uint)
)

(define-map study-groups
  uint
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    language: (string-ascii 20),
    creator: principal,
    members: (list 50 principal),
    max-members: uint,
    created-at: uint,
    active: bool,
    focus-areas: (list 10 (string-ascii 50))
  }
)

(define-map user-groups
  principal
  (list 20 uint)
)

(define-map session-feedback
  {session-id: uint, participant: principal}
  {
    rating: uint,
    feedback: (string-ascii 200),
    skills-practiced: (list 5 (string-ascii 30)),
    submitted-at: uint
  }
)

;; Private Functions
(define-private (is-valid-language (language (string-ascii 20)))
  (or
    (is-eq language "english")
    (is-eq language "spanish")
    (is-eq language "french")
    (is-eq language "german")
    (is-eq language "chinese")
  )
)

(define-private (is-valid-duration (duration uint))
  (and (>= duration u15) (<= duration u180)) ;; 15 minutes to 3 hours
)

(define-private (is-participant (session-id uint) (user principal))
  (let
    (
      (participants (default-to (list) (map-get? session-participants session-id)))
    )
    (is-some (index-of participants user))
  )
)

;; Public Functions
(define-public (create-practice-session
  (title (string-ascii 100))
  (description (string-ascii 300))
  (language (string-ascii 20))
  (skill-focus (string-ascii 50))
  (max-participants uint)
  (scheduled-time uint)
  (duration-minutes uint)
  (session-type (string-ascii 30))
)
  (let
    (
      (session-id (var-get next-session-id))
    )
    (asserts! (is-valid-language language) ERR-INVALID-LANGUAGE)
    (asserts! (is-valid-duration duration-minutes) ERR-INVALID-DURATION)
    (asserts! (> max-participants u1) ERR-NOT-AUTHORIZED)
    (asserts! (> scheduled-time block-height) ERR-NOT-AUTHORIZED)

    (map-set practice-sessions session-id
      {
        host: tx-sender,
        title: title,
        description: description,
        language: language,
        skill-focus: skill-focus,
        max-participants: max-participants,
        current-participants: u1,
        scheduled-time: scheduled-time,
        duration-minutes: duration-minutes,
        status: "scheduled",
        created-at: block-height,
        session-type: session-type
      }
    )

    ;; Add host as first participant
    (map-set session-participants session-id (list tx-sender))

    ;; Add to user's sessions
    (let
      (
        (user-session-list (default-to (list) (map-get? user-sessions tx-sender)))
      )
      (map-set user-sessions tx-sender
        (unwrap! (as-max-len? (append user-session-list session-id) u100) ERR-NOT-AUTHORIZED)
      )
    )

    (var-set next-session-id (+ session-id u1))
    (ok session-id)
  )
)

(define-public (join-practice-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? practice-sessions session-id) ERR-SESSION-NOT-FOUND))
      (participants (default-to (list) (map-get? session-participants session-id)))
      (user-session-list (default-to (list) (map-get? user-sessions tx-sender)))
    )
    (asserts! (is-eq (get status session) "scheduled") ERR-INVALID-STATUS)
    (asserts! (< (get current-participants session) (get max-participants session)) ERR-SESSION-FULL)
    (asserts! (not (is-participant session-id tx-sender)) ERR-ALREADY-JOINED)

    ;; Add participant to session
    (map-set session-participants session-id
      (unwrap! (as-max-len? (append participants tx-sender) u20) ERR-SESSION-FULL)
    )

    ;; Update participant count
    (map-set practice-sessions session-id
      (merge session {current-participants: (+ (get current-participants session) u1)})
    )

    ;; Add to user's sessions
    (map-set user-sessions tx-sender
      (unwrap! (as-max-len? (append user-session-list session-id) u100) ERR-NOT-AUTHORIZED)
    )

    (ok true)
  )
)

(define-public (start-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? practice-sessions session-id) ERR-SESSION-NOT-FOUND))
    )
    (asserts! (is-eq (get host session) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status session) "scheduled") ERR-INVALID-STATUS)
    (asserts! (>= block-height (get scheduled-time session)) ERR-NOT-AUTHORIZED)

    (map-set practice-sessions session-id
      (merge session {status: "active"})
    )
    (ok true)
  )
)

(define-public (end-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? practice-sessions session-id) ERR-SESSION-NOT-FOUND))
    )
    (asserts! (is-eq (get host session) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status session) "active") ERR-INVALID-STATUS)

    (map-set practice-sessions session-id
      (merge session {status: "completed"})
    )

    ;; Reward participants with tokens
    (let
      (
        (participants (default-to (list) (map-get? session-participants session-id)))
        (reward-per-participant (var-get platform-token-reward))
      )
      ;; In a full implementation, would distribute tokens to participants
      (ok true)
    )
  )
)

(define-public (submit-session-feedback
  (session-id uint)
  (rating uint)
  (feedback (string-ascii 200))
  (skills-practiced (list 5 (string-ascii 30)))
)
  (let
    (
      (session (unwrap! (map-get? practice-sessions session-id) ERR-SESSION-NOT-FOUND))
    )
    (asserts! (is-participant session-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status session) "completed") ERR-INVALID-STATUS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-NOT-AUTHORIZED)

    (map-set session-feedback {session-id: session-id, participant: tx-sender}
      {
        rating: rating,
        feedback: feedback,
        skills-practiced: skills-practiced,
        submitted-at: block-height
      }
    )
    (ok true)
  )
)

(define-public (create-study-group
  (name (string-ascii 100))
  (description (string-ascii 300))
  (language (string-ascii 20))
  (max-members uint)
  (focus-areas (list 10 (string-ascii 50)))
)
  (let
    (
      (group-id (var-get next-group-id))
      (user-group-list (default-to (list) (map-get? user-groups tx-sender)))
    )
    (asserts! (is-valid-language language) ERR-INVALID-LANGUAGE)
    (asserts! (> max-members u1) ERR-NOT-AUTHORIZED)

    (map-set study-groups group-id
      {
        name: name,
        description: description,
        language: language,
        creator: tx-sender,
        members: (list tx-sender),
        max-members: max-members,
        created-at: block-height,
        active: true,
        focus-areas: focus-areas
      }
    )

    (map-set user-groups tx-sender
      (unwrap! (as-max-len? (append user-group-list group-id) u20) ERR-NOT-AUTHORIZED)
    )

    (var-set next-group-id (+ group-id u1))
    (ok group-id)
  )
)

;; Read-only Functions
(define-read-only (get-practice-session (session-id uint))
  (map-get? practice-sessions session-id)
)

(define-read-only (get-session-participants (session-id uint))
  (map-get? session-participants session-id)
)

(define-read-only (get-user-sessions (user principal))
  (map-get? user-sessions user)
)

(define-read-only (get-study-group (group-id uint))
  (map-get? study-groups group-id)
)

(define-read-only (get-user-groups (user principal))
  (map-get? user-groups user)
)

(define-read-only (get-session-feedback (session-id uint) (participant principal))
  (map-get? session-feedback {session-id: session-id, participant: participant})
)

(define-read-only (get-upcoming-sessions (language (string-ascii 20)))
  ;; Simplified - would need more complex filtering in production
  (list u1 u2 u3 u4 u5)
)

(define-read-only (get-platform-token-reward)
  (var-get platform-token-reward)
)
