;;; -*-Scheme-*-
;;;
;;; $Id: parser-macro.scm,v 1.1 2001/07/06 20:50:43 cph Exp $
;;;
;;; Copyright (c) 2001 Massachusetts Institute of Technology
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 2 of the
;;; License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
;;; 02111-1307, USA.

;;;; XML parser macros

(declare (usual-integrations))

(define-*parser-macro S			;[3]
  `(NOISE (+ (ALPHABET CHAR-SET:XML-WHITESPACE))))

(define-*parser-macro S?
  `(NOISE (* (ALPHABET CHAR-SET:XML-WHITESPACE))))

(define-*parser-macro (bracket description open close . body)
  (let ((v (generate-uninterned-symbol)))
    `(WITH-POINTER ,v
       (SEQ ,open
	    ,@body
	    (ALT ,close
		 (SEXP
		  (LAMBDA (BUFFER)
		    BUFFER
		    (ERROR
		     ,(if (string? description)
			  (string-append "Unterminated " description " at")
			  `(STRING-APPEND "Unterminated " ,description " at"))
		     (PARSER-BUFFER-POSITION-STRING ,v)))))))))

(define-*parser-macro (sbracket description open close . body)
  `(BRACKET ,description (NOISE (STRING ,open)) (NOISE (STRING ,close))
     ,@body))

(define-*parser-macro (require-success message body)
  `(ALT ,body
	(SEXP
	 (LAMBDA (BUFFER)
	   (ERROR ,(if (string? message)
		       (string-append message " at")
		       `(STRING-APPEND ,message " at"))
		  (PARSER-BUFFER-POSITION-STRING BUFFER))))))