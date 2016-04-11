; Copyright (C) 2015-2016 OpenCog Foundation

(use-modules (ice-9 threads)) ; For `par-map`
(use-modules (srfi srfi-1)) ; For set-difference

(use-modules (opencog) (opencog exec) (opencog rule-engine))

(load-from-path "openpsi/action-selector.scm")
(load-from-path "openpsi/demand.scm")
(load-from-path "openpsi/goal-selector.scm")
(load-from-path "openpsi/utilities.scm")

; --------------------------------------------------------------
(define-public (psi-asp)
"
  Create the active-schema-pool as a URE rulebase and return the node
  representing it.
"
    (let ((asp (ConceptNode (string-append (psi-prefix-str) "asp"))))

        (ure-define-rbs asp 1)

        ; Load all default actions because they should always run. If they
        ; aren't always.
        (if (null? (ure-rbs-rules asp))
            (map (lambda (x) (MemberLink x asp)) (psi-get-action-rules-default)))

        asp
    )
)

; --------------------------------------------------------------
(define-public (psi-step)
"
  The main function that steps OpenPsi active-schema-pool(asp). The asp
  is a rulebase, that is modified depending on the demand-values, on every
  cogserver cycle.

  Returns a list of results from the step.
"
    (let* ((asp (psi-asp)))
        (cog-fc (SetLink) asp (SetLink))
    )
)

; --------------------------------------------------------------
(define-public (psi-update-asp asp action-rules)
"
  It modifies the member action-rules of OpenPsi's active-schema-pool(asp),
  by removing all action-rules that are members of all the known demand
  rule-bases, with the exception of default-actions, from the asp and replaces
  them by the list of actions passed.

  If the action-rule list passed is empty the asp isn't modified, because the
  policy is that no change occurs without it being explicitly specified. This
  doesn't and must not check what goal is selected.

  asp:
  - The node for the active-schema-pool.

  action-rules:
  - A list of action-rule nodes. The nodes are the alias nodes for the
    action-rules.
"
    (define (remove-node node) (cog-extract-recursive (MemberLink node asp)))
    (define (add-node node) (begin (MemberLink node asp) node))

    (let* ((current-actions (ure-rbs-rules asp))
           (actions-to-keep (psi-get-action-rules-default))
           (actions-to-add
                (lset-difference equal? action-rules current-actions))
           (final-asp (lset-union equal? actions-to-keep action-rules)))

           ; Remove actions except those that should be kept and those that
           ; are to be added.
           (par-map
                (lambda (x)
                    (if (member x final-asp)
                        x
                        (remove-node x))
                )
                current-actions)

           ; Add the actions that are not member of the asp.
           (par-map add-node actions-to-add)
    )
)

(define (psi-rule context action demand-goal)
    ; Check arguments
    (if (not (list? context))
        (error "Expected first argument to psi-rule to be a list, got: "
            context))

    ; These memberships are needed for making filtering and searching simpler..
    ; If GlobNode had worked with GetLink at the time of coding this ,
    ; that might have been; better,(or not as it might need as much chasing)
    (MemberLink
        action
        (ConceptNode (string-append (psi-prefix-str) "action")))

    (MemberLink
        (ImplicationLink (AndLink context action) demand-goal)
        (ConceptNode (string-append (psi-prefix-str) "rule")))
)

(define (psi-get-all-actions) ; get openpsi actions
    (cog-outgoing-set (cog-execute! (GetLink
        (MemberLink (VariableNode "x")
        (ConceptNode (string-append (psi-prefix-str) "action")))))))

(define (psi-action? x)
    (if (member x (psi-get-all-actions)) #t #f))

(define (psi-get-rules) ; get all openpsi rules
    (cog-chase-link 'MemberLink 'ImplicationLink
        (ConceptNode (string-append (psi-prefix-str) "rule"))))

(define (psi-get-context rule) ; get the context of an openpsi-rule
    (define (get-c&a x) ; get context and action list from ImplicationLink
        (cog-outgoing-set (list-ref (cog-outgoing-set x) 0)))

    (remove psi-action? (get-c&a rule))
)

(define (psi-get-action rule) ; get the context of an openpsi-rule
    (define (get-c&a x) ; get context and action list from ImplicationLink
        (cog-outgoing-set (list-ref (cog-outgoing-set x) 0)))

    (filter psi-action? (get-c&a rule))
)

(define (psi-satisfiable? rule) ; check if the rule is satisfiable
    (let* ((pattern (SatisfactionLink (AndLink (psi-get-context rule))))
           (result (cog-evaluate! pattern)))
          (cog-delete pattern)

          ; FIXME: Regardless of what 'result' is, the following always returns
          ; '#f'
          ; (equal? (stv 1 1) result)
          result
    )
)
