;;; -*-Scheme-*-
;;;
;;; $Id: method.scm,v 1.1 1997/06/04 06:08:49 cph Exp $
;;;
;;; Copyright (c) 1995-96 Massachusetts Institute of Technology
;;;
;;; This material was developed by the Scheme project at the
;;; Massachusetts Institute of Technology, Department of Electrical
;;; Engineering and Computer Science.  Permission to copy this
;;; software, to redistribute it, and to use it for any purpose is
;;; granted, subject to the following restrictions and understandings.
;;;
;;; 1. Any copy made of this software must include this copyright
;;; notice in full.
;;;
;;; 2. Users of this software agree to make their best efforts (a) to
;;; return to the MIT Scheme project any improvements or extensions
;;; that they make, so that these may be included in future releases;
;;; and (b) to inform MIT of noteworthy uses of this software.
;;;
;;; 3. All materials developed as a consequence of the use of this
;;; software shall duly acknowledge such use, in accordance with the
;;; usual standards of acknowledging credit in academic research.
;;;
;;; 4. MIT has made no warrantee or representation that the operation
;;; of this software will be error-free, and MIT is under no
;;; obligation to provide any services, by way of maintenance, update,
;;; or otherwise.
;;;
;;; 5. In conjunction with products arising from the use of this
;;; material, there shall be no use of the name of the Massachusetts
;;; Institute of Technology nor of any adaptation thereof in any
;;; advertising, promotional, or sales literature without prior
;;; written consent from MIT in each case.

;;;; Methods and Effective Method Procedures

(declare (usual-integrations))

;;;; Adding/Removing Methods

(define (add-method generic method)
  (guarantee-valid-method method generic 'ADD-METHOD)
  (for-each
   (lambda (method)
     (modify-methods generic
       (lambda (methods)
	 (let ((tail
		(if (computed-emp? method)
		    (and (computed-emp-key method)
			 (computed-emp-member method methods))
		    (method-member method methods))))
	   (if tail
	       (begin
		 (warn "Replacing method"
		       (car tail)
		       (error-irritant/noise " with")
		       method
		       (error-irritant/noise " in procedure")
		       generic
		       (error-irritant/noise "."))
		 (set-car! tail method)
		 methods)
	       (cons method methods))))))
   (if (computed-emp? method)
       (list method)
       (enumerate-union-specializers method)))
  (if (computed-emp? method)
      (purge-generic-procedure-cache generic)
      (purge-method-entries generic method)))

(define method-member
  (member-procedure
   (lambda (x y)
     (and (not (computed-emp? x))
	  (not (computed-emp? y))
	  (specializers=? (method-specializers x) (method-specializers y))))))

(define computed-emp-member
  (member-procedure
   (lambda (x y)
     (and (computed-emp? x)
	  (computed-emp? y)
	  (equal? (computed-emp-key x) (computed-emp-key y))))))

(define (delete-method generic method)
  (guarantee-valid-method method generic 'DELETE-METHOD)
  (modify-methods generic (lambda (methods) (delq! method methods)))
  (purge-method-entries generic method))

(define (guarantee-valid-method method generic name)
  (guarantee-method method name)
  (guarantee-generic-procedure generic name)
  ;; Assumes that method instantiation has guaranteed that there is at
  ;; least one specializer.  This is handled by GUARANTEE-SPECIALIZERS.
  (if (< (arity-min (generic-procedure-arity generic))
	 (length (method-specializers method)))
      (error:bad-range-argument method name)))

(define (guarantee-method method name)
  (if (not (method? method))
      (error:wrong-type-argument method "method" name)))

(define (purge-method-entries generic method)
  (purge-generic-procedure-cache generic
    (lambda (generic tags)
      generic
      (method-applicable? method (map dispatch-tag->class tags)))))

(define (add-methods generic methods)
  (for-each (lambda (method) (add-method generic method)) methods))

;;;; Method Combinators

(define (method-combinator-record generic intern?)
  (let ((combinator
	 (or (list-search-positive (generic-procedure-generator-list generic)
	       method-combinator?)
	     (and intern?
		  (let ((combinator (make-method-combinator)))
		    (add-generic-procedure-generator generic combinator)
		    combinator)))))
    (and combinator
	 (apply-hook-extra combinator))))

(define (method-combinator? object)
  (and (apply-hook? object)
       (combinator-record? (apply-hook-extra object))))

(define (make-method-combinator)
  (make-apply-hook (lambda (generic tags)
		     (compute-effective-method-procedure
		      generic
		      (map dispatch-tag->class tags)))
		   (make-combinator-record)))

(define-structure (combinator-record (constructor make-combinator-record ()))
  (methods '()))

(define (modify-methods generic modifier)
  (let ((record (method-combinator-record generic #t)))
    (set-combinator-record-methods!
     record
     (modifier (combinator-record-methods record)))))

(define (generic-procedure-methods generic)
  (guarantee-generic-procedure generic 'GENERIC-PROCEDURE-METHODS)
  (let ((record (method-combinator-record generic #f)))
    (if record
	(list-copy (combinator-record-methods record))
	'())))

;;;; Effective Method Procedures

(define (compute-method generic classes)
  (let ((emp (compute-effective-method-procedure generic classes)))
    (and emp
	 (make-method classes emp))))

(define (compute-effective-method-procedure generic classes)
  (or (try-emp-short-circuits generic classes)
      (let ((methods (compute-methods generic classes)))
	(or (try-computed-emps generic classes methods)
	    (and (not (null? methods))
		 (let loop ((methods methods))
		   (if (chained-method? (car methods))
		       ((method-procedure (car methods))
			(if (null? (cdr methods))
			    (lambda args
			      (error:no-applicable-methods generic args))
			    (loop (cdr methods))))
		       (method-procedure (car methods)))))))))

(define (try-computed-emps generic classes methods)
  (let loop
      ((generators
	(sort-methods (list-transform-positive
			  (append-map enumerate-union-specializers
				      (list-transform-positive
					  (generic-procedure-methods generic)
					computed-emp?))
			(lambda (method)
			  (method-applicable? method classes)))
		      classes)))
    (and (not (null? generators))
	 (let ((result (apply (method-procedure (car generators)) classes)))
	   (cond ((not result)
		  (loop (cdr generators)))
		 ((or (there-exists? (cdr generators)
			(lambda (generator)
			  (and (specializers=?
				(method-specializers generator)
				(method-specializers (car generators)))
			       (apply (method-procedure generator) classes))))
		      (there-exists? methods
			(lambda (method)
			  (specializers=? (method-specializers method)
					  classes))))
		  (lambda args
		    (error:extra-applicable-methods generic args)))
		 (else result))))))

(define (compute-methods generic classes)
  (sort-methods (compute-methods-1 generic classes) classes))

(define (compute-methods-1 generic classes)
  (let ((methods
	 (list-transform-positive (generic-procedure-methods generic)
	   (lambda (method)
	     (and (not (computed-emp? method))
		  (method-applicable? method classes))))))
    (let ((results (list-transform-negative methods computed-method?)))
      (for-each
       (lambda (method)
	 (let ((result (apply (method-procedure method) classes)))
	   (if result
	       (begin
		 (set! results
		       (cons (make-method (method-specializers method) result)
			     results))
		 unspecific))))
       (list-transform-positive methods computed-method?))
      results)))

(define (method-applicable? method classes)
  (guarantee-method method 'METHOD-APPLICABLE?)
  (subclasses? classes (method-specializers method)))

(define (subclasses? classes specializers)
  (let loop ((classes classes) (specializers specializers))
    (or (null? specializers)
	(and (subclass? (car classes) (car specializers))
	     (loop (cdr classes) (cdr specializers))))))

(define (sort-methods methods classes)
  (sort methods
	(lambda (m1 m2)
	  (let loop
	      ((s1 (method-specializers m1))
	       (s2 (method-specializers m2))
	       (classes classes))
	    (and (not (null? s1))
		 (or (null? s2)
		     (if (eq? (car s1) (car s2))
			 (loop (cdr s1) (cdr s2) (cdr classes))
			 (memq (car s2)
			       (cdr (memq (car s1)
					  (class-precedence-list
					   (car classes))))))))))))

;;;; Method Specializers

(define (specializers? object)
  (and (list? object)
       (not (null? object))
       (for-all? object specializer?)))

(define (specializer? object)
  (or (class? object)
      (record-type? object)
      (union-specializer? object)))

(define (guarantee-specializers specializers non-null? name)
  (if (not (specializers? specializers))
      (error:wrong-type-argument specializers "list of method specializers"
				 name))
  (if (and non-null? (null? specializers))
      (error:bad-range-argument specializers name))
  (map (lambda (specializer)
	 (if (record-type? specializer)
	     (record-type-class specializer)
	     specializer))
       specializers))

(define (specializers=? s1 s2)
  (cond ((null? s1)
	 (let loop ((s2 s2))
	   (or (null? s2)
	       (and (eq? <object> (car s2))
		    (loop (cdr s2))))))
	((null? s2)
	 (let loop ((s1 s1))
	   (and (eq? <object> (car s1))
		(or (null? (cdr s1))
		    (loop (cdr s1))))))
	(else
	 (and (specializer=? (car s1) (car s2))
	      (specializers=? (cdr s1) (cdr s2))))))

(define (specializer=? s1 s2)
  (or (eq? s1 s2)
      (and (union-specializer? s1)
	   (union-specializer? s2)
	   (union-specializer=? s1 s2))))

(define union-spec-rtd (make-record-type 'UNION-SPECIALIZER '(CLASSES)))
(define make-union-specializer (record-constructor union-spec-rtd))
(define union-specializer? (record-predicate union-spec-rtd))
(define union-specializer-classes (record-accessor union-spec-rtd 'CLASSES))

(define (union-specializer . specializers)
  (make-union-specializer
   (append-map (lambda (specializer)
		 (if (union-specializer? specializer)
		     (union-specializer-classes specializer)
		     (list specializer)))
	       (guarantee-specializers specializers #f 'UNION-SPECIALIZER))))

(define (union-specializer=? s1 s2)
  (eq-set=? (union-specializer-classes s1) (union-specializer-classes s2)))

(define (eq-set=? x y)
  (and (for-all? x (lambda (x) (memq x y)))
       (for-all? y (lambda (y) (memq y x)))))

(define (enumerate-union-specializers method)
  (let ((specializers (method-specializers method)))
    (if (let loop ((specializers specializers))
	  (and (not (null? specializers))
	       (or (union-specializer? (car specializers))
		   (loop (cdr specializers)))))
	(map (lambda (specializers)
	       (new-method-specializers method specializers))
	     (let loop ((specializers specializers))
	       (let ((classes
		      (let ((specializer (car specializers)))
			(if (union-specializer? specializer)
			    (union-specializer-classes specializer)
			    (list specializer)))))
		 (if (null? (cdr specializers))
		     (map (lambda (class) (list class)) classes)
		     (let ((tails (loop (cdr specializers))))
		       (append-map (lambda (class)
				     (map (lambda (tail)
					    (cons class tail))
					  tails))
				   classes))))))
	(list method))))

(define (new-method-specializers method specializers)
  (cond ((computed-method? method)
	 (make-computed-method specializers (method-procedure method)))
	((computed-emp? method)
	 (make-computed-emp (computed-emp-key method)
			    specializers
			    (method-procedure method)))
	((chained-method? method)
	 (make-chained-method specializers (method-procedure method)))
	(else
	 (make-method specializers (method-procedure method)))))

;;;; Method Types

(define <method>
  (make-class '<METHOD> '() '(SPECIALIZERS PROCEDURE)))

(define make-method
  (let ((%make (instance-constructor <method> '(SPECIALIZERS PROCEDURE))))
    (lambda (specializers procedure)
      (%make (guarantee-specializers specializers #t 'MAKE-METHOD)
	     procedure))))

(define method?
  (instance-predicate <method>))

(define method-specializers
  (make-generic-procedure 1 'METHOD-SPECIALIZERS))

(define method-procedure
  (make-generic-procedure 1 'METHOD-PROCEDURE))


(define <chained-method>
  (make-class '<CHAINED-METHOD> (list <method>) '()))

(define make-chained-method
  (let ((%make
	 (instance-constructor <chained-method> '(SPECIALIZERS PROCEDURE))))
    (lambda (specializers procedure)
      (%make (guarantee-specializers specializers #t 'MAKE-CHAINED-METHOD)
	     procedure))))

(define chained-method?
  (instance-predicate <chained-method>))


(define <computed-method>
  (make-class '<COMPUTED-METHOD> (list <method>) '()))

(define make-computed-method
  (let ((%make
	 (instance-constructor <computed-method> '(SPECIALIZERS PROCEDURE))))
    (lambda (specializers procedure)
      (%make (guarantee-specializers specializers #t 'MAKE-COMPUTED-METHOD)
	     procedure))))

(define computed-method?
  (instance-predicate <computed-method>))


(define <computed-emp>
  (make-class '<COMPUTED-EMP> (list <method>) '(KEY)))

(define make-computed-emp
  (let ((%make
	 (instance-constructor <computed-emp> '(KEY SPECIALIZERS PROCEDURE))))
    (lambda (key specializers procedure)
      (%make key
	     (guarantee-specializers specializers #t 'MAKE-COMPUTED-EMP)
	     procedure))))

(define computed-emp?
  (instance-predicate <computed-emp>))

(define computed-emp-key
  (make-generic-procedure 1 'COMPUTED-EMP-KEY))

;;; This short-circuits the computation for method accessors.  These
;;; would otherwise need to be called in order to compute the result
;;; for themselves, which would cause an infinite loop.  This is done
;;; as a three-stage process: (1) define the short-circuit hook, (2)
;;; create method combinators for each of the accessors, to cause the
;;; hook to be called, and (3) define the ordinary accessor methods,
;;; which are used when the built-in method classes are subclassed.

(define (try-emp-short-circuits generic classes)
  (let ((entry (assq generic emp-short-circuits)))
    (and entry
	 (memq (car classes) (cadr entry))
	 ((caddr entry) generic (map class->dispatch-tag classes)))))

(define emp-short-circuits
  (let ((get-specializers (%record-accessor-generator 'SPECIALIZERS))
	(get-procedure (%record-accessor-generator 'PROCEDURE)))
    (list (list method-specializers
		(list <method> <chained-method> <computed-method>)
		get-specializers)
	  (list method-procedure
		(list <method> <chained-method> <computed-method>)
		get-procedure)
	  (list computed-emp-key
		(list <computed-emp>)
		(%record-accessor-generator 'KEY)))))

(method-combinator-record method-specializers #t)
(method-combinator-record method-procedure #t)
(method-combinator-record computed-emp-key #t)

(add-method method-specializers
	    (slot-accessor-method <method> 'SPECIALIZERS))

(add-method method-procedure
	    (slot-accessor-method <method> 'PROCEDURE))

(add-method computed-emp-key
	    (slot-accessor-method <computed-emp> 'KEY))