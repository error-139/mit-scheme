#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/base/debug.scm,v 4.1 1987/12/04 20:00:58 cph Exp $

Copyright (c) 1987 Massachusetts Institute of Technology

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

;;;; Compiler Debugging Support

(declare (usual-integrations))

(define (po object)
  (let ((object (->tagged-vector object)))
    (write-line object)
    (for-each pp ((tagged-vector/description object) object))))

(define (dump-rtl filename)
  (write-instructions
   (lambda ()
     (with-output-to-file (pathname-new-type (->pathname filename) "rtl")
       (lambda ()
	 (for-each show-rtl-instruction
		   ((access linearize-rtl rtl-generator-package)
		    *rtl-graphs*)))))))

(define (show-rtl rtl)
  (pp-instructions
   (lambda ()
     (for-each show-rtl-instruction rtl))))

(define (show-bblock-rtl bblock)
  (pp-instructions
   (lambda ()
     (bblock-walk-forward (->tagged-vector bblock)
       (lambda (rinst)
	 (show-rtl-instruction (rinst-rtl rinst)))))))

(define (write-instructions thunk)
  (fluid-let ((*show-instruction* write-line)
	      (*unparser-radix* 16))
    (thunk)))

(define (pp-instructions thunk)
  (fluid-let ((*show-instruction* pp)
	      ((access *pp-primitives-by-name* scheme-pretty-printer) false)
	      (*unparser-radix* 16))
    (thunk)))

(define *show-instruction*)

(define (show-rtl-instruction rtl)
  (if (memq (car rtl)
	    '(LABEL PROCEDURE-HEAP-CHECK CONTINUATION-HEAP-CHECK SETUP-LEXPR))
      (newline))
  (*show-instruction* rtl))

(package (show-fg)

(define *procedure-queue*)
(define *procedures*)

(define-export (show-fg)
  (fluid-let ((*procedure-queue* (make-queue))
	      (*procedures* '()))
    (write-string "\n---------- Expression ----------")
    (fg/print-object *root-expression*)
    (with-new-node-marks
     (lambda ()
       (fg/print-entry-node (expression-entry-node *root-expression*))
       (queue-map! *procedure-queue*
	 (lambda (procedure)
	   (if (procedure-continuation? procedure)
	       (write-string "\n\n---------- Continuation ----------")
	       (write-string "\n\n---------- Procedure ----------"))
	   (fg/print-object procedure)
	   (fg/print-entry-node (procedure-entry-node procedure))))))
    (write-string "\n\n---------- Blocks ----------")
    (fg/print-blocks (expression-block *root-expression*))))

(define (fg/print-entry-node node)
  (if node
      (fg/print-node node)))

(define (fg/print-object object)
  (newline)
  (po object))

(define (fg/print-blocks block)
  (fg/print-object block)
  (for-each fg/print-object (block-bound-variables block))
  (if (not (block-parent block))
      (for-each fg/print-object (block-free-variables block)))
  (for-each fg/print-blocks (block-children block))
  (for-each fg/print-blocks (block-disowned-children block)))

(define (fg/print-node node)
  (if (not (node-marked? node))      (begin
	(node-mark! node)
	(fg/print-object node)
	(cfg-node-case (tagged-vector/tag node)
	  ((PARALLEL)
	   (for-each fg/print-subproblem (parallel-subproblems node))
	   (fg/print-node (snode-next node)))
	  ((APPLICATION)
	   (fg/print-rvalue (application-operator node))
	   (for-each fg/print-rvalue (application-operands node)))
	  ((VIRTUAL-RETURN)
	   (fg/print-rvalue (virtual-return-operand node))
	   (fg/print-node (snode-next node)))
	  ((POP)
	   (fg/print-rvalue (pop-continuation node))
	   (fg/print-node (snode-next node)))
	  ((ASSIGNMENT)
	   (fg/print-rvalue (assignment-rvalue node))
	   (fg/print-node (snode-next node)))
	  ((DEFINITION)
	   (fg/print-rvalue (definition-rvalue node))
	   (fg/print-node (snode-next node)))
	  ((TRUE-TEST)
	   (fg/print-rvalue (true-test-rvalue node))
	   (fg/print-node (pnode-consequent node))
	   (fg/print-node (pnode-alternative node)))))))

(define (fg/print-rvalue rvalue)
  (let ((rvalue (rvalue-known-value rvalue)))
    (if (and rvalue
	     (rvalue/procedure? rvalue)
	     (not (memq rvalue *procedures*)))
	(begin
	  (set! *procedures* (cons rvalue *procedures*))
	  (enqueue! *procedure-queue* rvalue)))))

(define (fg/print-subproblem subproblem)
  (fg/print-object subproblem)
  (if (subproblem-canonical? subproblem)
      (fg/print-rvalue (subproblem-continuation subproblem)))
  (let ((prefix (subproblem-prefix subproblem)))
    (if (not (cfg-null? prefix))
	(fg/print-node (cfg-entry-node prefix)))))

;;; end SHOW-FG
)