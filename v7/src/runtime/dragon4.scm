#| -*-Scheme-*-

$Id: dragon4.scm,v 1.9 1997/02/12 08:00:19 cph Exp $

Copyright (c) 1989-97 Massachusetts Institute of Technology

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

;;;; Floating Point Number Unparser
;;; package: (runtime number)

(declare (usual-integrations))

(define (flo:->string x radix)
  (let ((inf?
	 (lambda (x)
	   (and (flo:> x 1.)
		(flo:= x (flo:/ x 2.)))))
	(x>0
	 (lambda (x)
	   (let ((p flo:significand-digits-base-2))
	     (with-values (lambda () (dragon4-normalize x p))
	       (lambda (f e)
		 (with-values flonum-unparser-cutoff-args
		   (lambda (cutoff-mode cutoff display-mode)
		     (dragon4 f e p radix cutoff-mode cutoff
		       (lambda (u k generate)
			 (let ((digits
				(list->string
				 (let loop ((u u) (k k) (generate generate))
				   k	;ignore
				   (if (negative? u)
				       '()
				       (cons (digit->char u radix)
					     (generate loop)))))))
			   (case display-mode
			     ((ENGINEERING)
			      (scientific-output digits k radix (modulo k 3)))
			     ((SCIENTIFIC)
			      (scientific-output digits k radix 0))
			     (else
			      (normal-output digits k radix))))))))))))))
    (or (and flonum-unparser-hook
	     (flonum-unparser-hook x radix))
	(cond ((flo:positive? x)
	       (if (inf? x)
		   (string-copy "#[+inf]")
		   (x>0 x)))
	      ((flo:negative? x)
	       (let ((x (flo:negate x)))
		 (if (inf? x)
		     (string-copy "#[-inf]")
		     (string-append "-" (x>0 x)))))
	      ((flo:zero? x)
	       (string-copy "0."))
	      (else
	       (string-copy "#[NaN]"))))))

(define (normal-output digits k radix)
  (let ((k+1 (+ k 1)))
    (let ((k+1-l (- k+1 (string-length digits)))
	  (n (flo:significand-digits radix)))
      (cond ((< k+1-l (- n))
	     (scientific-output digits k radix 0))
	    ((negative? k)
	     (string-append "." (make-string (- k+1) #\0) digits))
	    ((negative? k+1-l)
	     (string-append (string-head digits k+1)
			    "."
			    (string-tail digits k+1)))
	    ((<= k n)
	     (string-append digits (make-string k+1-l #\0) "."))
	    (else
	     (scientific-output digits k radix 0))))))

(define (scientific-output digits k radix kr)
  (let ((l (string-length digits))
	(i (+ kr 1))
	(exponent (int:->string (- k kr) radix)))
    (cond ((< l i)
	   (string-append digits (make-string (- i l) #\0) "e" exponent))
	  ((= l i)
	   (string-append digits "e" exponent))
	  (else
	   (string-append (string-head digits i)
			  "."
			  (string-tail digits i)
			  "e"
			  exponent)))))

(define (flonum-unparser-cutoff-args)
  (cond ((eq? 'NORMAL flonum-unparser-cutoff)
	 (values 'NORMAL 0 'NORMAL))
	((and (pair? flonum-unparser-cutoff)
	      (pair? (cdr flonum-unparser-cutoff))
	      (let ((mode (car flonum-unparser-cutoff))
		    (place (cadr flonum-unparser-cutoff)))
		(and (memq mode '(ABSOLUTE RELATIVE NORMAL))
		     (exact-integer? place)
		     (or (not (eq? 'RELATIVE mode))
			 (positive? place))))
	      (or (null? (cddr flonum-unparser-cutoff))
		  (and (pair? (cddr flonum-unparser-cutoff))
		       (null? (cdddr flonum-unparser-cutoff))
		       (memq (caddr flonum-unparser-cutoff)
			     '(NORMAL SCIENTIFIC ENGINEERING)))))
	 (values (car flonum-unparser-cutoff)
		 (- (cadr flonum-unparser-cutoff))
		 (if (null? (cddr flonum-unparser-cutoff))
		     'NORMAL
		     (caddr flonum-unparser-cutoff))))
	(else
	 (warn "illegal flonum unparser cutoff parameter"
	       flonum-unparser-cutoff)
	 (values 'NORMAL 0 'NORMAL))))

(define flonum-unparser-hook #f)
(define flonum-unparser-cutoff 'NORMAL)

(define (dragon4-normalize x precision)
  (with-values (lambda () (flo:normalize x))
    (lambda (f e-p)
      (values (flo:->integer (flo:denormalize f precision))
	      (- e-p precision)))))

(define (dragon4 f e p radix cutoff-mode cutoff format)
  (with-values
      (lambda ()
	(cond ((positive? e)
	       (let ((shift (expt 2 e)))
		 (dragon4-fixup f p radix cutoff-mode cutoff
				(* f shift) 1 shift)))
	      ((negative? e)
	       (dragon4-fixup f p radix cutoff-mode cutoff
			      f (expt 2 (- e)) 1))
	      (else
	       (dragon4-fixup f p radix cutoff-mode cutoff f 1 1))))
    (lambda (k r s m- m+ cutoff round-up?)
      (let ((2s (* 2 s)))
	(let loop ((r r) (m- m-) (m+ m+) (k k) (format format))
	  (let ((qr (integer-divide (* r radix) s)))
	    (let ((k (-1+ k))
		  (u (integer-divide-quotient qr))
		  (r (integer-divide-remainder qr))
		  (m- (* m- radix))
		  (m+ (* m+ radix)))
	      (let ((2r (* 2 r)))
		(let ((high?
		       (if round-up?
			   (>= 2r (- 2s m+))
			   (> 2r (- 2s m+))))
		      (round
		       (lambda ()
			 (dragon4-done format (if (<= 2r s) u (1+ u)) k))))
		  (cond ((< 2r m-)
			 (if high? (round) (dragon4-done format u k)))
			(high?
			 (dragon4-done format (1+ u) k))
			((= k cutoff)
			 (round))
			(else
			 (format u k
			   (lambda (format)
			     (loop r m- m+ k format))))))))))))))

(define (dragon4-done format u k)
  (format u k
    (letrec ((fill
	      (lambda (k)
		(lambda (format)
		  (format -1 k (fill (-1+ k)))))))
      (fill (-1+ k)))))

(define (dragon4-fixup f p radix cutoff-mode cutoff r s m-)
  (with-values
      (lambda ()
	(if (= f (expt 2 (-1+ p)))
	    (values (* 2 r) (* 2 s) (* 2 m-))
	    (values r s m-)))
    (lambda (r s m+)
      (with-values
	  (lambda ()
	    (let ((s/radix (integer-ceiling s radix)))
	      (let loop ((k 0) (r r) (m- m-) (m+ m+))
		(if (< r s/radix)
		    (loop (-1+ k) (* r radix) (* m- radix) (* m+ radix))
		    (values k r m- m+)))))
	(lambda (k r m- m+)
	  (let ((2r (* 2 r)))
	    (let loop ((k k) (s s) (m- m-) (m+ m+) (round-up? #f))
	      (with-values
		  (lambda ()
		    (let ((2r+m+ (+ 2r m+)))
		      (let loop ((s s) (k k))
			(if (<= (* 2 s) 2r+m+)
			    (loop (* s radix) (1+ k))
			    (values s k)))))
		(lambda (s k)
		  (let ((cutoff-adjust
			 (lambda (cutoff)
			   (let ((a (- cutoff k)))
			     (let ((y (ceiling (* s (expt radix a)))))
			       (let ((m- (max y m-))
				     (m+ (max y m+)))
				 (let ((round-up? (or (= m+ y) round-up?)))
				   (if (<= (* 2 s) (+ 2r m+))
				       (loop k s m- m+ round-up?)
				       (values k r s m- m+ cutoff
					       round-up?)))))))))
		    (case cutoff-mode
		      ((normal) (values k r s m- m+ k round-up?))
		      ((absolute) (cutoff-adjust cutoff))
		      ((relative) (cutoff-adjust (+ k cutoff)))
		      (else
		       (error:wrong-type-datum cutoff-mode false)))))))))))))