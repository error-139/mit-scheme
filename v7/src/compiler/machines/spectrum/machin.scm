#| -*-Scheme-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/compiler/machines/spectrum/machin.scm,v 4.20 1990/01/25 16:27:42 jinx Exp $
$MC68020-Header: machin.scm,v 4.20 90/01/18 22:43:44 GMT cph Exp $

Copyright (c) 1988, 1989, 1990 Massachusetts Institute of Technology

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

;;; Machine Model for Spectrum

(declare (usual-integrations))

;;;; Architecture Parameters

(define-integrable endianness 'BIG)
(define-integrable addressing-granularity 8)
(define-integrable scheme-object-width 32)
(define-integrable scheme-type-width 6)	;or 8

(define-integrable scheme-datum-width
  (- scheme-object-width scheme-type-width))

(define-integrable type-scale-factor
  (expt 2 (- 8 scheme-type-width)))

(define-integrable flonum-size 2)
(define-integrable float-alignment 64)

;;; It is currently required that both packed characters and objects
;;; be integrable numbers of address units.  Furthermore, the number
;;; of address units per object must be an integral multiple of the
;;; number of address units per character.  This will cause problems
;;; on a machine that is word addressed, in which case we will have to
;;; rethink the character addressing strategy.

(define-integrable address-units-per-object
  (quotient scheme-object-width addressing-granularity))

(define-integrable address-units-per-packed-char 1)

(define-integrable signed-fixnum/upper-limit (expt 2 (-1+ scheme-datum-width)))
(define-integrable signed-fixnum/lower-limit (- signed-fixnum/upper-limit))
(define-integrable unsigned-fixnum/upper-limit (* 2 signed-fixnum/upper-limit))

(define-integrable (stack->memory-offset offset) offset)
(define-integrable ic-block-first-parameter-offset 2)
(define-integrable closure-block-first-offset 3)

;;;; Machine Registers

(define-integrable g0 0)
(define-integrable g1 1)
(define-integrable g2 2)
(define-integrable g3 3)
(define-integrable g4 4)
(define-integrable g5 5)
(define-integrable g6 6)
(define-integrable g7 7)
(define-integrable g8 8)
(define-integrable g9 9)
(define-integrable g10 10)
(define-integrable g11 11)
(define-integrable g12 12)
(define-integrable g13 13)
(define-integrable g14 14)
(define-integrable g15 15)
(define-integrable g16 16)
(define-integrable g17 17)
(define-integrable g18 18)
(define-integrable g19 19)
(define-integrable g20 20)
(define-integrable g21 21)
(define-integrable g22 22)
(define-integrable g23 23)
(define-integrable g24 24)
(define-integrable g25 25)
(define-integrable g26 26)
(define-integrable g27 27)
(define-integrable g28 28)
(define-integrable g29 29)
(define-integrable g30 30)
(define-integrable g31 31)

;; fp0 - fp3 are status registers.  The rest are real registers
(define-integrable fp0 32)
(define-integrable fp1 33)
(define-integrable fp2 34)
(define-integrable fp3 35)
(define-integrable fp4 36)
(define-integrable fp5 37)
(define-integrable fp6 38)
(define-integrable fp7 39)
(define-integrable fp8 40)
(define-integrable fp9 41)
(define-integrable fp10 42)
(define-integrable fp11 43)
(define-integrable fp12 44)
(define-integrable fp13 45)
(define-integrable fp14 46)
(define-integrable fp15 47)

(define-integrable number-of-machine-registers 48)
(define-integrable number-of-temporary-registers 256)

;;; Fixed-use registers for Scheme compiled code.
(define-integrable regnum:return-value g2)
(define-integrable regnum:scheme-to-interface-ble g3)
(define-integrable regnum:regs-pointer g4)
(define-integrable regnum:quad-bitmask g5)
(define-integrable regnum:dynamic-link g19)
(define-integrable regnum:memtop-pointer g20)
(define-integrable regnum:free-pointer g21)
(define-integrable regnum:stack-pointer g22)

;;; Fixed-use registers due to architecture or OS calling conventions.
(define-integrable regnum:zero g0)
(define-integrable regnum:addil-result g1)
(define-integrable regnum:C-global-pointer g27)
(define-integrable regnum:C-return-value g28)
(define-integrable regnum:C-stack-pointer g30)
(define-integrable regnum:ble-return g31)
(define-integrable regnum:fourth-arg g23)
(define-integrable regnum:third-arg g24)
(define-integrable regnum:second-arg g25)
(define-integrable regnum:first-arg g26)

(define (machine-register-value-class register)
  (cond ((or (= register 0)
	     (<= 6 register 18)
	     (<= 23 register 26)
	     (= register 29)
	     (= register 31))
	 value-class=word)
	((or (= register 2) (= register 28))
	 value-class=object)
	((or (= register 1) (= register 3))
	 value-class=unboxed)
	((or (= register 4)
	     (<= 19 register 22)
	     (= register 27)
	     (= register 30))
	 value-class=address)
	((= register 5)
	 value-class=immediate)
	((<= 32 register 47)
	 value-class=float)
	(else
	 (error "illegal machine register" register))))

(define-integrable (machine-register-known-value register)
  register				;ignore
  false)

;;;; Interpreter Registers

(define-integrable (interpreter-free-pointer)
  (rtl:make-machine-register regnum:free-pointer))

(define (interpreter-free-pointer? expression)
  (and (rtl:register? expression)
       (= (rtl:register-number expression) regnum:free-pointer)))

(define-integrable (interpreter-regs-pointer)
  (rtl:make-machine-register regnum:regs-pointer))

(define (interpreter-regs-pointer? expression)
  (and (rtl:register? expression)
       (= (rtl:register-number expression) regnum:regs-pointer)))

(define-integrable (interpreter-value-register)
  (rtl:make-machine-register regnum:return-value))

(define (interpreter-value-register? expression)
  (and (rtl:register? expression)
       (= (rtl:register-number expression) regnum:return-value)))

(define-integrable (interpreter-stack-pointer)
  (rtl:make-machine-register regnum:stack-pointer))

(define (interpreter-stack-pointer? expression)
  (and (rtl:register? expression)
       (= (rtl:register-number expression) regnum:stack-pointer)))

(define-integrable (interpreter-dynamic-link)
  (rtl:make-machine-register regnum:dynamic-link))

(define (interpreter-dynamic-link? expression)
  (and (rtl:register? expression)
       (= (rtl:register-number expression) regnum:dynamic-link)))

(define-integrable (interpreter-environment-register)
  (rtl:make-offset (interpreter-regs-pointer) 3))

(define (interpreter-environment-register? expression)
  (and (rtl:offset? expression)
       (interpreter-regs-pointer? (rtl:offset-base expression))
       (= 3 (rtl:offset-number expression))))

(define-integrable (interpreter-register:access)
  (rtl:make-machine-register g28))

(define-integrable (interpreter-register:cache-reference)
  (rtl:make-machine-register g28))

(define-integrable (interpreter-register:cache-unassigned?)
  (rtl:make-machine-register g28))

(define-integrable (interpreter-register:lookup)
  (rtl:make-machine-register g28))

(define-integrable (interpreter-register:unassigned?)
  (rtl:make-machine-register g28))

(define-integrable (interpreter-register:unbound?)
  (rtl:make-machine-register g28))

;;;; RTL Registers, Constants, and Primitives

(define (rtl:machine-register? rtl-register)
  (case rtl-register
    ((STACK-POINTER)
     (interpreter-stack-pointer))
    ((DYNAMIC-LINK)
     (interpreter-dynamic-link))
    ((VALUE)
     (interpreter-value-register))
    ((INTERPRETER-CALL-RESULT:ACCESS)
     (interpreter-register:access))
    ((INTERPRETER-CALL-RESULT:CACHE-REFERENCE)
     (interpreter-register:cache-reference))
    ((INTERPRETER-CALL-RESULT:CACHE-UNASSIGNED?)
     (interpreter-register:cache-unassigned?))
    ((INTERPRETER-CALL-RESULT:LOOKUP)
     (interpreter-register:lookup))
    ((INTERPRETER-CALL-RESULT:UNASSIGNED?)
     (interpreter-register:unassigned?))
    ((INTERPRETER-CALL-RESULT:UNBOUND?)
     (interpreter-register:unbound?))
    (else false)))

(define (rtl:interpreter-register? rtl-register)
  (case rtl-register
    ((MEMORY-TOP) 0)
    ((STACK-GUARD) 1)
    ((ENVIRONMENT) 3)
    ((TEMPORARY) 4)
    (else false)))

(define (rtl:interpreter-register->offset locative)
  (or (rtl:interpreter-register? locative)
      (error "Unknown register type" locative)))

(define (rtl:constant-cost expression)
  ;; Magic numbers.
  (let ((if-integer
	 (lambda (value)
	   (cond ((zero? value) 1)
		 ((fits-in-5-bits-signed? value) 2)
		 (else 3)))))
    (let ((if-synthesized-constant
	   (lambda (type datum)
	     (if-integer (make-non-pointer-literal type datum)))))
      (case (rtl:expression-type expression)
	((CONSTANT)
	 (let ((value (rtl:constant-value expression)))
	   (if (non-pointer-object? value)
	       (if-synthesized-constant (object-type value)
					(object-datum value))
	       3)))
	((MACHINE-CONSTANT)
	 (if-integer (rtl:machine-constant-value expression)))
	((ENTRY:PROCEDURE
	  ENTRY:CONTINUATION
	  ASSIGNMENT-CACHE
	  VARIABLE-CACHE
	  OFFSET-ADDRESS)
	 3)
	((CONS-POINTER)
	 (and (rtl:machine-constant? (rtl:cons-pointer-type expression))
	      (rtl:machine-constant? (rtl:cons-pointer-datum expression))
	      (if-synthesized-constant
	       (rtl:machine-constant-value (rtl:cons-pointer-type expression))
	       (rtl:machine-constant-value
		(rtl:cons-pointer-datum expression)))))
	(else false)))))

(define compiler:open-code-floating-point-arithmetic?
  true)

(define compiler:primitives-with-no-open-coding
  '(MULTIPLY-FIXNUM INTEGER-MULTIPLY &*
    DIVIDE-FIXNUM GCD-FIXNUM FIXNUM-QUOTIENT FIXNUM-REMAINDER
    INTEGER-QUOTIENT INTEGER-REMAINDER &/
    FLONUM-SIN FLONUM-COS FLONUM-TAN FLONUM-ASIN FLONUM-ACOS
    FLONUM-ATAN FLONUM-EXP FLONUM-LOG FLONUM-TRUNCATE))