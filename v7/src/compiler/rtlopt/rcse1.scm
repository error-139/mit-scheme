#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/rtlopt/rcse1.scm,v 4.15 1988/11/08 11:15:07 cph Exp $

Copyright (c) 1988 Massachusetts Institute of Technology

This material was developed by the Scheme project at the Massachusetts
Institute of Technology, Department of Electrical Engineering and
Computer Science.  Permission to copy this software, to redistribute
it, and to use it for any purpose is granted, subject to the following
restrictions and understandings.

1. Any copy made of this software must include this copyright notice
in full.

2. Users of this software agree to make their best efforts (a) to
return to the MIT Scheme project any improvements or extensions that
they make, so that these may be included in future releases; and (b)
to inform MIT of noteworthy uses of this software.

3. All materials developed as a consequence of the use of this
software shall duly acknowledge such use, in accordance with the usual
standards of acknowledging credit in academic research.

4. MIT has made no warrantee or representation that the operation of
this software will be error-free, and MIT is under no obligation to
provide any services, by way of maintenance, update, or otherwise.

5. In conjunction with products arising from the use of this material,
there shall be no use of the name of the Massachusetts Institute of
Technology nor of any adaptation thereof in any advertising,
promotional, or sales literature without prior written consent from
MIT in each case. |#

;;;; RTL Common Subexpression Elimination: Codewalker
;;;  Based on the GNU C Compiler

(declare (usual-integrations))

(define *initial-queue*)
(define *branch-queue*)

(define (common-subexpression-elimination rgraphs)
  (with-new-node-marks (lambda () (for-each cse-rgraph rgraphs))))

(define (cse-rgraph rgraph)
  (fluid-let ((*current-rgraph* rgraph)
	      (*next-quantity-number* 0)
	      (*initial-queue* (make-queue))
	      (*branch-queue* '()))
    (for-each (lambda (edge)
		(enqueue!/unsafe *initial-queue* (edge-right-node edge)))
	      (rgraph-initial-edges rgraph))
    (fluid-let ((*register-tables*
		 (register-tables/make (rgraph-n-registers rgraph)))
		(*hash-table*)
		(*stack-offset*)
		(*stack-reference-quantities*))
      (continue-walk))))

(define (continue-walk)
  (cond ((not (null? *branch-queue*))
	 (let ((entry (car *branch-queue*)))
	   (set! *branch-queue* (cdr *branch-queue*))
	   (let ((state (car entry)))
	     (set! *register-tables* (state/register-tables state))
	     (set! *hash-table* (state/hash-table state))
	     (set! *stack-offset* (state/stack-offset state))
	     (set! *stack-reference-quantities*
		   (state/stack-reference-quantities state)))
	   (walk-bblock (cdr entry))))
	((not (queue-empty? *initial-queue*))
	 (state/reset!)
	 (walk-bblock (dequeue!/unsafe *initial-queue*)))))

(define-structure (state (type vector) (conc-name state/))
  (register-tables false read-only true)
  (hash-table false read-only true)
  (stack-offset false read-only true)
  (stack-reference-quantities false read-only true))

(define (state/reset!)
  (register-tables/reset! *register-tables*)
  (set! *hash-table* (make-hash-table))
  (set! *stack-offset* 0)
  (set! *stack-reference-quantities* '())
  unspecific)

(define (state/get)
  (make-state (register-tables/copy *register-tables*)
	      (hash-table-copy *hash-table*)
	      *stack-offset*
	      (list-copy *stack-reference-quantities*)))

(define (walk-bblock bblock)
  (let loop ((rinst (bblock-instructions bblock)))
    (let ((rtl (rinst-rtl rinst)))
      ((if (eq? (rtl:expression-type rtl) 'ASSIGN)
	   cse/assign
	   (let ((entry (assq (rtl:expression-type rtl) cse-methods)))
	     (if (not entry)
		 (error "Missing CSE method" (rtl:expression-type rtl)))
	     (cdr entry)))
       rtl))
    (if (rinst-next rinst)
	(loop (rinst-next rinst))))
  (node-mark! bblock)
  (if (sblock? bblock)
      (let ((next (snode-next bblock)))
	(if (walk-next? next)
	    (walk-next next)
	    (continue-walk)))
      (let ((consequent (pnode-consequent bblock))
	    (alternative (pnode-alternative bblock)))
	(if (walk-next? consequent)
	    (if (walk-next? alternative)
		(if (node-previous>1? consequent)
		    (begin (enqueue!/unsafe *initial-queue* consequent)
			   (walk-next alternative))
		    (begin (if (node-previous>1? alternative)
			       (enqueue!/unsafe *initial-queue* alternative)
			       (set! *branch-queue*
				     (cons (cons (state/get) alternative)
					   *branch-queue*)))
			   (walk-bblock consequent)))
		(walk-next consequent))
	    (if (walk-next? alternative)
		(walk-next alternative)
		(continue-walk))))))

(define-integrable (walk-next? bblock)
  (and bblock (not (node-marked? bblock))))

(define-integrable (walk-next bblock)
  (if (node-previous>1? bblock) (state/reset!))
  (walk-bblock bblock))

(define (define-cse-method type method)
  (let ((entry (assq type cse-methods)))
    (if entry
	(set-cdr! entry method)
	(set! cse-methods (cons (cons type method) cse-methods))))
  type)

(define cse-methods
  '())

(define (cse/assign statement)
  (expression-replace! rtl:assign-expression rtl:set-assign-expression!
		       statement
    (lambda (volatile? insert-source!)
      (let ((address (rtl:assign-address statement)))
	(cond ((rtl:register? address)
	       (if (interpreter-stack-pointer? address)
		   (let ((expression (rtl:assign-expression statement)))
		     (if (and (rtl:offset? expression)
			      (interpreter-stack-pointer?
			       (rtl:offset-register expression)))
			 (stack-pointer-adjust! (rtl:offset-number expression))
			 (begin
			   (stack-invalidate!)
			   (stack-pointer-invalidate!))))
		   (register-expression-invalidate! address))
	       (if (and (not volatile?)
			(not (rtl:machine-register-expression?
			      (rtl:assign-expression statement))))
		   (insert-register-destination! address (insert-source!))))
	      ((stack-reference? address)
	       (stack-reference-invalidate! address)
	       (if (not volatile?)
		   (insert-stack-destination! address (insert-source!))))
	      ((interpreter-register-reference? address)
	       (let ((hash (expression-hash address)))
		 (let ((memory-invalidate!
			(lambda ()
			  (hash-table-delete! hash
					      (hash-table-lookup hash
								 address)))))
		   (if volatile?
		       (memory-invalidate!)
		       (assignment-memory-insertion address
						    hash
						    insert-source!
						    memory-invalidate!)))))
	      (else
	       (let ((address (expression-canonicalize address)))
		 (rtl:set-assign-address! statement address)
		 (full-expression-hash address
		   (lambda (hash volatile?* in-memory?)
		     in-memory?
		     (let ((memory-invalidate!
			    (cond ((stack-push/pop? address)
				   (lambda () 'DONE))
				  ((and (memq (rtl:expression-type address)
					      '(PRE-INCREMENT POST-INCREMENT))
					(interpreter-free-pointer?
					 (rtl:address-register address)))
				   (lambda ()
				     (register-expression-invalidate!
				      (rtl:address-register address))))
				  ((expression-address-varies? address)
				   (lambda ()
				     (hash-table-delete-class!
				      element-in-memory?)))
				  (else
				   (lambda ()
				     (hash-table-delete!
				      hash
				      (hash-table-lookup hash address))
				     (varying-address-invalidate!))))))
		       (if (or volatile? volatile?*)
			   (memory-invalidate!)
			   (assignment-memory-insertion address
							hash
							insert-source!
							memory-invalidate!)))))
		 (notice-push/pop! address)))))
      (notice-push/pop! (rtl:assign-expression statement)))))

(define (notice-push/pop! expression)
  ;; **** Kludge.  Works only because stack-pointer
  ;; gets used in very fixed way by code generator.
  (if (stack-push/pop? expression)
      (stack-pointer-adjust! (rtl:address-number expression))))

(define (assignment-memory-insertion address hash insert-source!
				     memory-invalidate!)
  #|
  ;; This does not cause bugs (false hash number passed to
  ;; insert-memory-destination! fixed one), but does not do anything
  ;; useful.  The idea of doing optimization on the address of a
  ;; memory assignment does not work since the RTL does not
  ;; distinguish addresses from references.  When the RTL is changed,
  ;; we can do CSE on the memory address.
  (let ((address (find-cheapest-expression address hash false)))
    (let ((element (insert-source!)))
      (memory-invalidate!)
      (insert-memory-destination! address element false)))
  |#
  hash
  (insert-source!)
  (memory-invalidate!)
  (mention-registers! address))

(define (trivial-action volatile? insert-source!)
  (if (not volatile?)
      (insert-source!)))

(define (define-trivial-one-arg-method type get set)
  (define-cse-method type
    (lambda (statement)
      (expression-replace! get set statement trivial-action))))

(define (define-trivial-two-arg-method type get-1 set-1 get-2 set-2)
  (define-cse-method type
    (lambda (statement)
      (expression-replace! get-1 set-1 statement trivial-action)
      (expression-replace! get-2 set-2 statement trivial-action))))

(define-trivial-two-arg-method 'EQ-TEST
  rtl:eq-test-expression-1 rtl:set-eq-test-expression-1!
  rtl:eq-test-expression-2 rtl:set-eq-test-expression-2!)

(define-trivial-one-arg-method 'FIXNUM-PRED-1-ARG
  rtl:fixnum-pred-1-arg-operand rtl:set-fixnum-pred-1-arg-operand!)

(define-trivial-two-arg-method 'FIXNUM-PRED-2-ARGS
  rtl:fixnum-pred-2-args-operand-1 rtl:set-fixnum-pred-2-args-operand-1!
  rtl:fixnum-pred-2-args-operand-2 rtl:set-fixnum-pred-2-args-operand-2!)
(define-trivial-one-arg-method 'TRUE-TEST
  rtl:true-test-expression rtl:set-true-test-expression!)

(define-trivial-one-arg-method 'TYPE-TEST
  rtl:type-test-expression rtl:set-type-test-expression!)

(define-trivial-one-arg-method 'UNASSIGNED-TEST
  rtl:type-test-expression rtl:set-unassigned-test-expression!)

(define (method/noop statement)
  statement
  unspecific)

(define-cse-method 'OVERFLOW-TEST method/noop)

(define-cse-method 'POP-RETURN method/noop)

(define-cse-method 'CONTINUATION-ENTRY method/noop)
(define-cse-method 'CONTINUATION-HEADER method/noop)
(define-cse-method 'IC-PROCEDURE-HEADER method/noop)
(define-cse-method 'OPEN-PROCEDURE-HEADER method/noop)
(define-cse-method 'PROCEDURE-HEADER method/noop)
(define-cse-method 'CLOSURE-HEADER method/noop)

(define-cse-method 'INVOCATION:APPLY method/noop)
(define-cse-method 'INVOCATION:JUMP method/noop)
(define-cse-method 'INVOCATION:COMPUTED-JUMP method/noop)
(define-cse-method 'INVOCATION:LEXPR method/noop)
(define-cse-method 'INVOCATION:COMPUTED-LEXPR method/noop)
(define-cse-method 'INVOCATION:UUO-LINK method/noop)
(define-cse-method 'INVOCATION:PRIMITIVE method/noop)

(define-cse-method 'INVOCATION:SPECIAL-PRIMITIVE
  (lambda (statement)
    statement
    (stack-pointer-adjust! (rtl:invocation:special-primitive-pushed statement))
    (expression-invalidate! (interpreter-value-register))
    (expression-invalidate! (interpreter-free-pointer))))

(define-trivial-one-arg-method 'INVOCATION:CACHE-REFERENCE
  rtl:invocation:cache-reference-name rtl:set-invocation:cache-reference-name!)

(define-trivial-one-arg-method 'INVOCATION:LOOKUP
  rtl:invocation:lookup-environment rtl:set-invocation:lookup-environment!)
(define-cse-method 'INVOCATION-PREFIX:MOVE-FRAME-UP
  (lambda (statement)
    (expression-replace! rtl:invocation-prefix:move-frame-up-locative
			 rtl:set-invocation-prefix:move-frame-up-locative!
			 statement
			 trivial-action)
    (stack-invalidate!)
    (stack-pointer-invalidate!)))

(define-cse-method 'INVOCATION-PREFIX:DYNAMIC-LINK
  (lambda (statement)
    (expression-replace! rtl:invocation-prefix:dynamic-link-locative
			 rtl:set-invocation-prefix:dynamic-link-locative!
			 statement
			 trivial-action)
    (expression-replace! rtl:invocation-prefix:dynamic-link-register
			 rtl:set-invocation-prefix:dynamic-link-register!
			 statement
			 trivial-action)
    (stack-invalidate!)
    (stack-pointer-invalidate!)))

(define (define-lookup-method type get-environment set-environment! register)
  (define-cse-method type
    (lambda (statement)
      (expression-replace! get-environment set-environment! statement
	(lambda (volatile? insert-source!)
	  (expression-invalidate! (register))
	  (non-object-invalidate!)
	  (if (not volatile?) (insert-source!)))))))

(define-lookup-method 'INTERPRETER-CALL:ACCESS
  rtl:interpreter-call:access-environment
  rtl:set-interpreter-call:access-environment!
  interpreter-register:access)

(define-lookup-method 'INTERPRETER-CALL:CACHE-REFERENCE
  rtl:interpreter-call:cache-reference-name
  rtl:set-interpreter-call:cache-reference-name!
  interpreter-register:cache-reference)

(define-lookup-method 'INTERPRETER-CALL:CACHE-UNASSIGNED?
  rtl:interpreter-call:cache-unassigned?-name
  rtl:set-interpreter-call:cache-unassigned?-name!
  interpreter-register:cache-unassigned?)

(define-lookup-method 'INTERPRETER-CALL:LOOKUP
  rtl:interpreter-call:lookup-environment
  rtl:set-interpreter-call:lookup-environment!
  interpreter-register:lookup)

(define-lookup-method 'INTERPRETER-CALL:UNASSIGNED?
  rtl:interpreter-call:unassigned?-environment
  rtl:set-interpreter-call:unassigned?-environment!
  interpreter-register:unassigned?)

(define-lookup-method 'INTERPRETER-CALL:UNBOUND?
  rtl:interpreter-call:unbound?-environment
  rtl:set-interpreter-call:unbound?-environment!
  interpreter-register:unbound?)

(define (define-assignment-method type
	  get-environment set-environment!
	  get-value set-value!)
  (define-cse-method type
    (lambda (statement)
      (expression-replace! get-value set-value! statement trivial-action)
      (expression-replace! get-environment set-environment! statement
	(lambda (volatile? insert-source!)
	  (varying-address-invalidate!)
	  (non-object-invalidate!)
	  (if (not volatile?) (insert-source!)))))))

(define-assignment-method 'INTERPRETER-CALL:CACHE-ASSIGNMENT
  rtl:interpreter-call:cache-assignment-name
  rtl:set-interpreter-call:cache-assignment-name!
  rtl:interpreter-call:cache-assignment-value
  rtl:set-interpreter-call:cache-assignment-value!)

(define-assignment-method 'INTERPRETER-CALL:DEFINE
  rtl:interpreter-call:define-environment
  rtl:set-interpreter-call:define-environment!
  rtl:interpreter-call:define-value
  rtl:set-interpreter-call:define-value!)

(define-assignment-method 'INTERPRETER-CALL:SET!
  rtl:interpreter-call:set!-environment
  rtl:set-interpreter-call:set!-environment!
  rtl:interpreter-call:set!-value
  rtl:set-interpreter-call:set!-value!)