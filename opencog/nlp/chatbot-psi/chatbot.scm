(use-modules (opencog)
             (opencog nlp)
             (opencog nlp chatbot)
             (opencog nlp relex2logic)
             (opencog nlp sureal)
             (opencog nlp aiml)
             (opencog exec)
             (opencog openpsi))

; Load the utilities
(load "utils.scm")

; Load the available contexts
(load "contexts.scm")

; Load the available actions
(load "actions.scm")
(load "external-sources.scm")

; Load the psi-rules
(load "psi-rules.scm")

; Load r2l-rules
(load-r2l-rulebase)

;-------------------------------------------------------------------------------
; Schema function for chatting

(define-public (chat utterance)
    (reset-all-states)

    (let ((sent-node (car (nlp-parse utterance))))
        (State input-utterance
            (Reference
                sent-node
                (Node utterance)
                (get-word-list sent-node)
            )
        )
    )

    *unspecified*
)

;-------------------------------------------------------------------------------
; Skip the demand (ConceptNode "OpenPsi: AIML chat demand"), a temp workaround

; Define the demand here to prevent error if this chatbot is loaded before
; loading the aiml psi-rules
(define aiml-chat-demand (psi-demand "AIML chat demand" .8))
(psi-demand-skip aiml-chat-demand)
(psi-reset-valid-demand-cache)

;-------------------------------------------------------------------------------
; Set relex-server-host
(set-relex-server-host)

;-------------------------------------------------------------------------------
; Run OpenPsi if it's not already running
(if (not (psi-running?))
    (psi-run)
)
