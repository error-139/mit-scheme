#| -*-Scheme-*-

$Id: bittop.scm,v 1.18 1993/12/09 01:17:55 gjr Exp $

Copyright (c) 1988-1993 Massachusetts Institute of Technology

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

;;;; Assembler Top Level
;;; package: (compiler assembler)

(declare (usual-integrations))

(define *equates*)
(define *objects*)
(define *entry-points*)
(define *the-symbol-table*)
(define *start-label*)
(define *end-label*)
(define *padding-present?*)

;;;; Assembler top level procedure

(define (assemble start-label instructions)
  (fluid-let ((*equates* (make-queue))
	      (*objects* (make-queue))
	      (*entry-points* (make-queue))
	      (*the-symbol-table* (make-symbol-table))
	      (*start-label* start-label)
	      (*end-label* (generate-uninterned-symbol 'END-LABEL-))
	      (*padding-present?* false))
    (initialize-symbol-table!)
    (with-values
	(lambda ()
	  (initial-phase
	   (if (null? instructions)
	       '()
	       (let ((holder (list 'HOLDER)))
		 (let loop ((tail holder)
			    (instructions
			     (let ((i instructions))
			       (set! instructions)
			       i)))
		   (if (not (null? instructions))
		       (let ((first (car instructions)))
			 (if (and (pair? first)
				  (eq? (car first) 'COMMENT))
			     (loop tail (cdr instructions))
			     (begin
			       (set-cdr! tail
					 (lap:syntax-instruction first))
			       (loop (last-pair tail) (cdr instructions)))))))
		 (cdr holder)))))
      (lambda (directives vars)
	(let* ((count (relax! directives vars))
	       (block (assemble-objects (final-phase directives))))
	  (values count
		  block
		  (queue->list *entry-points*)
		  (symbol-table->assq-list *the-symbol-table*)))))))

(define (relax! directives vars)
  (define (continue widening? count)
    (clear-symbol-table!)
    (initialize-symbol-table!)
    (loop widening?
	  (phase-1 widening? directives)
	  (1+ count)))

  (define (loop widening? vars count)
    (finish-symbol-table!)
    (if (null? vars)
	count
	(with-values (lambda () (phase-2 widening? vars))
	  (lambda (any-modified? number-of-vars)
	    (cond (any-modified?
		   (continue false count))
		  ((or (zero? number-of-vars)
		       (not *padding-present?*))
		   count)
		  (else
		   (continue (not widening?) count)))))))
  (loop false vars 0))

;;; Vector header and NMV header for code section

(define compiler-output-block-number-of-header-words 2)

(define starting-pc
  (* compiler-output-block-number-of-header-words scheme-object-width))

;;;; Output block generation

(define (final-phase directives)
  ;; Label values are now integers.
  (for-each (lambda (pair)
	      (let ((val (binding-value (cdr pair))))
		(if (interval? val)
		    (set-binding-value! (cdr pair) (interval-low val)))))
	    (symbol-table-bindings *the-symbol-table*))
  (let ((code-block
	 (bit-string-allocate (- (* addressing-granularity
				    (symbol-table-value *the-symbol-table*
							*end-label*))
				 starting-pc))))
    (assemble-directives!
     code-block
     directives
     (instruction-initial-position code-block))
    code-block))

#|

(define (assemble-objects code-block)
  (let ((objects (map assemble-an-object (queue->list *objects*))))
    (if compiler:cross-compiling?
	(vector 'DEBUGGING-INFO-SLOT code-block objects scheme-object-width)
	(let* ((bl (quotient (bit-string-length code-block)
			     scheme-object-width))
	       (non-pointer-length
		((ucode-primitive make-non-pointer-object) bl))
	       (output-block (make-vector (1+ (+ (length objects) bl)))))
	  (with-absolutely-no-interrupts
	    (lambda ()
	      (vector-set! output-block 0
			   ((ucode-primitive primitive-object-set-type)
			    (ucode-type manifest-nm-vector)
			    non-pointer-length))))
	  (write-bits! output-block
		       ;; After header just inserted.
		       (* scheme-object-width 2)
		       code-block)
	  (insert-objects! output-block objects (1+ bl))
	  (object-new-type (ucode-type compiled-code-block)
			   output-block)))))

|#

(define (assemble-objects code-block)
  (let ((objects (map assemble-an-object (queue->list *objects*))))
    (if compiler:cross-compiling?
	(vector 'DEBUGGING-INFO-SLOT code-block objects scheme-object-width)
	(let* ((bl (quotient (bit-string-length code-block)
			     scheme-object-width))
	       (non-pointer-length
		((ucode-primitive make-non-pointer-object) bl))
	       (objects-length (length objects))
	       (total-length (fix:+ 1 (fix:+ objects-length bl)))
	       (flo-length
		(let ((flo-size (fix:quotient float-width scheme-datum-width)))
		  (fix:quotient (fix:+ total-length (fix:- flo-size 1))
				flo-size)))
	       (output-block
		(object-new-type (ucode-type compiled-code-block)
				 (flo:vector-cons flo-length))))
	  (with-absolutely-no-interrupts
	    (lambda ()
	      (let ((ob (object-new-type (ucode-type vector) output-block)))
		(subvector-fill! ob
				 (fix:+ bl 1)
				 (vector-length ob)
				 #f)
		(vector-set! ob 0
			     ((ucode-primitive primitive-object-set-type)
			      (ucode-type manifest-nm-vector)
			      non-pointer-length)))))
	  (write-bits! output-block
		       ;; After header just inserted.
		       (* scheme-object-width 2)
		       code-block)
	  ((ucode-primitive primitive-object-set! 3)
	   output-block 0
	   (object-new-type (ucode-type null) total-length))
	  (insert-objects! output-block objects (fix:+ bl 1))
	  output-block))))

(define (assemble-an-object object)
  (case (car object)
    ((SCHEME-OBJECT)
     ;; (SCHEME-OBJECT <deflabel> <object>)
     (cdr object))
    ((SCHEME-EVALUATION)
     ;; (SCHEME-EVALUATION <deflabel> <offlabel>)
     (list (cadr object) (evaluate (caddr object) false)))
    (else
     (error "assemble-an-object: Unknown kind"
	    object))))

(define (insert-objects! v objects where)
  (cond ((not (null? objects))
	 (system-vector-set! v where (cadar objects))
	 (insert-objects! v (cdr objects) (fix:+ where 1)))
	((not (fix:= where (system-vector-length v)))
	 (error "insert-objects!: object phase error" where))
	(else unspecific)))

(define (assemble-directives! block directives initial-position)

  (define (loop directives dir-stack pc pc-stack position last-blabel blabel)

    (define (actual-bits bits l)
      (instruction-insert! bits block position
       (lambda (np)
	 (declare (integrate np))
	 (loop (cdr directives) dir-stack (+ pc l) pc-stack np
	       last-blabel blabel))))

    (define (block-offset offset last-blabel blabel)
      (instruction-insert!
       (block-offset->bit-string offset (eq? blabel *start-label*))
       block position
       (lambda (np)
	 (declare (integrate np))
	 (loop (cdr directives) dir-stack
	       (+ pc block-offset-width)
	       pc-stack np
	       last-blabel blabel))))

    (define (evaluation handler expression l)
      (actual-bits (handler
		    (evaluate expression
			      (if (null? pc-stack)
				  (->machine-pc pc)
				  (car pc-stack))))
		   l))

    (define (end-assembly)
      (cond ((not (null? dir-stack))
	     (loop (car dir-stack) (cdr dir-stack) pc pc-stack position
		   last-blabel blabel))
	    ((not (= (abs (- position initial-position))
		     (- pc starting-pc)))
	     (error "assemble-directives!: phase error"
		    `(PC ,starting-pc ,pc)
		    `(BIT-POSITION ,initial-position ,position)))
	    ((not (= (symbol-table-value *the-symbol-table* *end-label*)
		     (->machine-pc (final-pad pc))))
	     (error "assemble-directives!: phase error"
		    `(LABEL ,*end-label*)
		    `(ACTUAL-PC ,(->machine-pc (final-pad pc)))
		    `(RESOLVED-PC ,(symbol-table-value
				    *the-symbol-table*
				    *end-label*))))
	    (else
	     (final-pad! block pc position))))

    (if (null? directives)
	(end-assembly)
	(let ((this (car directives)))
	  (case (vector-ref this 0)
	    ((LABEL)
	     (let* ((label (vector-ref this 1))
		    (pcdef (symbol-table-value *the-symbol-table* label)))
	       (if (not (= pcdef (->machine-pc pc)))
		   (error "assemble-directives!: phase error"
			  `(LABEL ,label)
			  `(ACTUAL-PC ,pc)
			  `(RESOLVED-PC ,pcdef))))
	     (loop (cdr directives) dir-stack pc pc-stack position
		   last-blabel blabel))
	    ((TICK)
	     (loop (cdr directives) dir-stack
		   pc
		   (if (vector-ref this 1)
		       (cons (->machine-pc pc) pc-stack)
		       (cdr pc-stack))
		   position
		   last-blabel blabel))
	    ((FIXED-WIDTH-GROUP)
	     (loop (vector-ref this 2) (cons (cdr directives) dir-stack)
		   pc pc-stack
		   position
		   last-blabel blabel))
	    ((CONSTANT)
	     (let ((bs (vector-ref this 1)))
	       (actual-bits bs (bit-string-length bs))))
	    ((EVALUATION)
	     (evaluation (vector-ref this 3)
			 (vector-ref this 1)
			 (vector-ref this 2)))
	    ((VARIABLE-WIDTH-EXPRESSION)
	     (let ((sel (car (vector-ref this 3))))
	       (evaluation (variable-handler-wrapper (selector/handler sel))
			   (vector-ref this 1)
			   (selector/length sel))))
	    ((BLOCK-OFFSET)
	     (let* ((label (vector-ref this 1))
		    (offset (evaluate `(- ,label ,blabel) '())))
	       (if (> offset maximum-block-offset)
		   (block-offset (evaluate `(- ,label ,last-blabel) '())
				 label last-blabel)
		   (block-offset offset label blabel))))
	    ((PADDING)
	     (let ((remdr (vector-ref this 1))
		   (divsr (vector-ref this 2))
		   (padding-string (vector-ref this 3)))
	       (let* ((pc* (->bitstring-pc (paddify (->machine-pc pc)
						    remdr divsr)))
		      (pc-diff (- pc* pc))
		      (padding-length (bit-string-length padding-string)))
		 (if (not (zero? (remainder pc-diff padding-length)))
		     (error "assemble-directives!: Bad padding"
			    pc this)
		     (actual-bits (replicate padding-string
					     (quotient pc-diff padding-length))
				  pc-diff)))))
	    (else
	     (error "assemble-directives!: Unknown directive" this))))))

  (loop directives '() starting-pc '() initial-position
	*start-label* *start-label*))

;;;; Input conversion

(define (initial-phase input)
  (let ((directives (make-queue)))
    (define (loop to-convert pcmin pcmax pc-stack group vars)
      (define (collect-group!)
	(if (not (null? group))
	    (add-to-queue! directives
			   (vector 'FIXED-WIDTH-GROUP
				   (car group)
				   (reverse! (cdr group))))))

      (define (new-directive! dir)
	(collect-group!)
	(add-to-queue! directives dir))

      (define (process-label! label)
	(symbol-table-define! *the-symbol-table*
			      (cadr label)
			      (make-machine-interval pcmin pcmax))
	(new-directive! (list->vector label)))

      (define (process-fixed-width directive width)
	(loop (cdr to-convert)
	      (+ width pcmin) (+ width pcmax) pc-stack
	      (if (null? group)
		  (cons width (list directive))
		  (cons (+ width (car group))
			(cons directive (cdr group))))
	      vars))

      (define (process-variable-width directive)
	(new-directive! directive)
	(variable-width-lengths directive
	 (lambda (minl maxl)
	   (loop (cdr to-convert)
		 (+ pcmin minl) (+ pcmax maxl)
		 pc-stack '()
		 (cons directive vars)))))

      (define (process-trivial-directive)
	(loop (cdr to-convert)
	      pcmin pcmax pc-stack
	      group vars))

      (if (null? to-convert)
	  (let ((emin (final-pad pcmin))
		(emax (+ pcmax maximum-padding-length)))
	    (symbol-table-define! *the-symbol-table*
				  *end-label*
				  (make-machine-interval emin emax))
	    (collect-group!)
	    (values (queue->list directives) vars))

	  (let ((this (car to-convert)))
	    (cond ((bit-string? this)
		   (process-fixed-width (vector 'CONSTANT this)
					(bit-string-length this)))
		  ((not (pair? this))
		   (error "initial-phase: Unknown directive" this))
		  (else
		   (case (car this)
		     ((CONSTANT)
		      (process-fixed-width (list->vector this)
					   (bit-string-length (cadr this))))

		     ((EVALUATION)
		      (process-fixed-width (list->vector this)
					   (caddr this)))

		     ((VARIABLE-WIDTH-EXPRESSION)
		      (process-variable-width
		       (vector 'VARIABLE-WIDTH-EXPRESSION
			       (cadr this)
			       (if (null? pc-stack)
				   (make-machine-interval pcmin pcmax)
				   (car pc-stack))
			       (map list->vector (cddr this)))))
		     ((GROUP)
		      (new-directive! (vector 'TICK true))
		      (loop (append (cdr this)
				    (cons '(TICK-OFF) (cdr to-convert)))
			    pcmin pcmax
			    (cons (make-machine-interval pcmin pcmax) pc-stack)
			    '() vars))
		     ((TICK-OFF)
		      (new-directive! (vector 'TICK false))
		      (loop (cdr to-convert) pcmin pcmax
			    (cdr pc-stack) '() vars))
		     ((LABEL)
		      (process-label! this)
		      (loop (cdr to-convert) pcmin pcmax pc-stack '() vars))
		     ((BLOCK-OFFSET)
		      (process-fixed-width (list->vector this)
					   block-offset-width))
		     ((EQUATE)
		      (add-to-queue! *equates* (cdr this))
		      (process-trivial-directive))
		     ((SCHEME-OBJECT SCHEME-EVALUATION)
		      (add-to-queue! *objects* this)
		      (process-trivial-directive))
		     ((ENTRY-POINT)
		      (add-to-queue! *entry-points* (cadr this))
		      (process-trivial-directive))
		     ((PADDING)
		      (set! *padding-present?* true)
		      (let ((directive (->padding-directive this)))
			(new-directive! directive)
			(after-padding
			 directive pcmin pcmax
			 (lambda (pcmin pcmax)
			   (loop (cdr to-convert) pcmin pcmax
				 pc-stack '() vars)))))
		     (else
		      (error "initial-phase: Unknown directive" this))))))))
    (loop input starting-pc starting-pc '() '() '())))

(define (phase-1 widening? directives)
  (define (loop rem pcmin pcmax pc-stack vars)
    (if (null? rem)
	(let* ((emin (final-pad pcmin))
	       (emax (if (not widening?)
			 (+ pcmax maximum-padding-length)
			 emin)))
	  (symbol-table-define! *the-symbol-table*
				*end-label*
				(make-machine-interval emin emax))
	  vars)
	(let ((this (car rem)))
	  (case (vector-ref this 0)
	    ((LABEL)
	     (symbol-table-define! *the-symbol-table*
				   (vector-ref this 1)
				   (make-machine-interval pcmin pcmax))
	     (loop (cdr rem) pcmin pcmax pc-stack vars))
	    ((FIXED-WIDTH-GROUP)
	     (let ((l (vector-ref this 1)))
	       (loop (cdr rem)
		     (+ pcmin l)
		     (+ pcmax l)
		     pc-stack
		     vars)))
	    ((VARIABLE-WIDTH-EXPRESSION)
	     (vector-set! this 2
			  (if (null? pc-stack)
			      (make-machine-interval pcmin pcmax)
			      (car pc-stack)))
	     (variable-width-lengths
	      this
	      (lambda (minl maxl)
		(loop (cdr rem)
		      (+ pcmin minl)
		      (+ pcmax (if widening? minl maxl))
		      pc-stack
		      (cons this vars)))))
	    ((TICK)
	     (loop (cdr rem)
		   pcmin pcmax
		   (if (vector-ref this 1)
		       (cons (make-machine-interval pcmin pcmax) pc-stack)
		       (cdr pc-stack))
		   vars))
	    ((PADDING)
	     (after-padding
	      this pcmin pcmax
	      (lambda (pcmin pcmax)
		(loop (cdr rem) pcmin pcmax pc-stack vars))))
	    (else
	     (error "phase-1: Unknown directive" this))))))
  (loop directives starting-pc starting-pc '() '()))

(define (phase-2 widening? vars)
  (define (loop vars modified? count)
    (if (null? vars)
	(values modified? count)
	(let ((var (car vars)))
	  (let ((interval (->interval
			   (evaluate (vector-ref var 1)
				     (vector-ref var 2)))))
	    (with-values
	     (lambda ()
	       (process-variable var
				 widening?
				 (interval-low interval)
				 (interval-high interval)))
	     (lambda (determined? filtered?)
	       (loop (cdr vars)
		     (or modified? filtered?)
		     (if determined? count (1+ count)))))))))
  (loop vars false 0))

(define (process-variable var widening? minval maxval)
  (define (loop sels dropped-some?)
    (cond ((null? sels)
	   (error "variable-width-expression: minimum value is too large"
		  var minval))
	  ((not (selector/fits? minval (car sels)))
	   (loop (cdr sels) true))
	  ((selector/fits? maxval (car sels))
	   (cond ((not widening?)
		  (variable-width->fixed! var (car sels)))
		 (dropped-some?
		  (vector-set! var 3 sels)))
	   (values true dropped-some?))
	  (dropped-some?
	   (vector-set! var 3 sels)
	   (values false true))
	  (else (values false false))))
  (loop (vector-ref var 3) false))

(define (variable-width->fixed! var sel)
  (let* ((l (selector/length sel))
	 (v (vector 'EVALUATION
		    (vector-ref var 1)	; Expression
		    (selector/length sel)
		    (variable-handler-wrapper (selector/handler sel)))))
    (vector-set! var 0 'FIXED-WIDTH-GROUP)
    (vector-set! var 1 l)
    (vector-set! var 2 (list v))
    (vector-set! var 3 '())))

(define (variable-handler-wrapper handler)
  (lambda (value)
    (let ((l (handler value)))
      (if (null? l)
	  (bit-string-allocate 0)
	  (list->bit-string l)))))

(define (list->bit-string l)
  (if (null? (cdr l))
      (car l)
      (instruction-append (car l)
			  (list->bit-string (cdr l)))))

(define (replicate bstring n-times)
  (let* ((blength (bit-string-length bstring))
	 (result (make-bit-string (* n-times blength) false)))
    (do ((offset 0 (+ offset blength))
	 (ctr 0 (1+ ctr)))
	((>= ctr n-times))
      (bit-substring-move-right! bstring 0 blength result offset))
    result))

(define (final-pad! block pc position)
  (instruction-insert!
   (replicate padding-string
	      (quotient (- (final-pad pc) pc)
			(bit-string-length padding-string)))
   block
   position
   (lambda (new-position)
     new-position			; ignored
     unspecific)))

(define (->padding-directive this)
  (let ((remdr (cadr this))
	(divsr (caddr this))
	(bstring (if (null? (cdddr this))
		     padding-string
		     (cadddr this))))
    (vector 'PADDING (modulo remdr divsr) divsr bstring)))

(define-integrable (after-padding directive pcmin pcmax recvr)
  (let ((remdr (vector-ref directive 1))
	(divsr (vector-ref directive 2)))
    (recvr (->bitstring-pc (paddify (->machine-pc pcmin) remdr divsr))
	   (->bitstring-pc (paddify (->machine-pc pcmax) remdr divsr)))))