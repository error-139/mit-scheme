#| -*-Scheme-*-

$Id: rtlobj.scm,v 4.11 1993/10/12 07:28:23 cph Exp $

Copyright (c) 1988-92 Massachusetts Institute of Technology

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

;;;; Register Transfer Language: Object Datatypes

(declare (usual-integrations))

(define-structure (rtl-expr
		   (conc-name rtl-expr/)
		   (constructor make-rtl-expr
				(rgraph label entry-edge debugging-info))
		   (print-procedure
		    (standard-unparser (symbol->string 'RTL-EXPR)
		      (lambda (state expression)
			(unparse-object state (rtl-expr/label expression))))))
  (rgraph false read-only true)
  (label false read-only true)
  (entry-edge false read-only true)
  (debugging-info false read-only true))

(define-integrable (rtl-expr/entry-node expression)
  (edge-right-node (rtl-expr/entry-edge expression)))

(define-structure (rtl-procedure
		   (conc-name rtl-procedure/)
		   (constructor make-rtl-procedure
				(rgraph label entry-edge name n-required
					n-optional rest? closure?
					dynamic-link? type
					debugging-info
					next-continuation-offset stack-leaf?))
		   (print-procedure
		    (standard-unparser (symbol->string 'RTL-PROCEDURE)
		      (lambda (state procedure)
			(unparse-object state
					(rtl-procedure/label procedure))))))
  (rgraph false read-only true)
  (label false read-only true)
  (entry-edge false read-only true)
  (name false read-only true)
  (n-required false read-only true)
  (n-optional false read-only true)
  (rest? false read-only true)
  (closure? false read-only true)
  (dynamic-link? false read-only true)
  (type false read-only true)
  (%external-label false)
  (debugging-info false read-only true)
  (next-continuation-offset false read-only true)
  (stack-leaf? false read-only true))

(define-integrable (rtl-procedure/entry-node procedure)
  (edge-right-node (rtl-procedure/entry-edge procedure)))

(define (rtl-procedure/external-label procedure)
  (or (rtl-procedure/%external-label procedure)
      (let ((label (generate-label (rtl-procedure/name procedure))))
	(set-rtl-procedure/%external-label! procedure label)
	label)))

(define-structure (rtl-continuation
		   (conc-name rtl-continuation/)
		   (constructor make-rtl-continuation
				(rgraph label entry-edge
					next-continuation-offset
					debugging-info))
		   (print-procedure
		    (standard-unparser (symbol->string 'RTL-CONTINUATION)
		      (lambda (state continuation)
			(unparse-object
			 state
			 (rtl-continuation/label continuation))))))
  (rgraph false read-only true)
  (label false read-only true)
  (entry-edge false read-only true)
  (next-continuation-offset false read-only true)
  (debugging-info false read-only true))

(define-integrable (rtl-continuation/entry-node continuation)
  (edge-right-node (rtl-continuation/entry-edge continuation)))

(define (make/label->object expression procedures continuations)
  (let ((hash-table
	 (make-eq-hash-table
	  (+ (if expression 1 0)
	     (length procedures)
	     (length continuations)))))
    (if expression
	(hash-table/put! hash-table
			 (rtl-expr/label expression)
			 expression))
    (for-each (lambda (procedure)
		(hash-table/put! hash-table
				 (rtl-procedure/label procedure)
				 procedure))
	      procedures)
    (for-each (lambda (continuation)
		(hash-table/put! hash-table
				 (rtl-continuation/label continuation)
				 continuation))
	      continuations)
    (lambda (label)
      (let ((datum (hash-table/get hash-table label #f)))
	(if (not datum)
	    (error "Undefined label:" label))
	datum))))