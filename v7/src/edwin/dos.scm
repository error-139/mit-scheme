;;; -*-Scheme-*-
;;;
;;;	$Id: dos.scm,v 1.34 1996/02/28 16:42:39 adams Exp $
;;;
;;;	Copyright (c) 1992-95 Massachusetts Institute of Technology
;;;
;;;	This material was developed by the Scheme project at the
;;;	Massachusetts Institute of Technology, Department of
;;;	Electrical Engineering and Computer Science.  Permission to
;;;	copy this software, to redistribute it, and to use it for any
;;;	purpose is granted, subject to the following restrictions and
;;;	understandings.
;;;
;;;	1. Any copy made of this software must include this copyright
;;;	notice in full.
;;;
;;;	2. Users of this software agree to make their best efforts (a)
;;;	to return to the MIT Scheme project any improvements or
;;;	extensions that they make, so that these may be included in
;;;	future releases; and (b) to inform MIT of noteworthy uses of
;;;	this software.
;;;
;;;	3. All materials developed as a consequence of the use of this
;;;	software shall duly acknowledge such use, in accordance with
;;;	the usual standards of acknowledging credit in academic
;;;	research.
;;;
;;;	4. MIT has made no warrantee or representation that the
;;;	operation of this software will be error-free, and MIT is
;;;	under no obligation to provide any services, by way of
;;;	maintenance, update, or otherwise.
;;;
;;;	5. In conjunction with products arising from the use of this
;;;	material, there shall be no use of the name of the
;;;	Massachusetts Institute of Technology nor of any adaptation
;;;	thereof in any advertising, promotional, or sales literature
;;;	without prior written consent from MIT in each case.
;;;
;;; NOTE: Parts of this program (Edwin) were created by translation
;;; from corresponding parts of GNU Emacs.  Users should be aware that
;;; the GNU GENERAL PUBLIC LICENSE may apply to these parts.  A copy
;;; of that license should have been included along with this file.
;;;

;;;; DOS Customizations for Edwin

(declare (usual-integrations))

(define dos/encoding-pathname-types
  '())

(define dos/executable-pathname-types
  ;; Not sure if there are other possibilities under WinNT and/or Win95.
  '("exe" "com" "bat"))

(define dos/default-shell-file-name
  ;; Not sure if this is right for WinNT and/or Win95.
  "command.com")

(define (os/form-shell-command command)
  ;; Not sure if this is right.
  (list "/c" command))

(define (os/directory-list directory)
  (os/directory-list-completions directory ""))

(define (os/directory-list-completions directory prefix)
  (let ((plen (string-length prefix)))
    (let loop ((pathnames (directory-read (pathname-as-directory directory))))
      (if (null? pathnames)
	  '()
	  (let ((filename (file-namestring (car pathnames))))
	    (if (and (fix:>= (string-length filename) plen)
		     (string-ci=? prefix (substring filename 0 plen)))
		(cons filename (loop (cdr pathnames)))
		(loop (cdr pathnames))))))))

(define (os/set-file-modes-writable! pathname)
  (set-file-modes! pathname #o777))

(define (os/scheme-can-quit?)
  #t)

(define (os/quit dir)
  (with-real-working-directory-pathname dir %quit))

(define (with-real-working-directory-pathname dir thunk)
  (let ((inside (->namestring (directory-pathname-as-file dir)))
	(outside false))
    (dynamic-wind
     (lambda ()
       (stop-thread-timer)
       (set! outside
	     (->namestring
	      (directory-pathname-as-file (working-directory-pathname))))
       (set-working-directory-pathname! inside)
       ((ucode-primitive set-working-directory-pathname! 1) inside))
     thunk
     (lambda ()
       (set! inside
	     (->namestring
	      (directory-pathname-as-file (working-directory-pathname))))
       ((ucode-primitive set-working-directory-pathname! 1) outside)
       (set-working-directory-pathname! outside)
       (start-thread-timer)))))

(define cut-and-paste-active? #T)

(define (os/interprogram-cut string push?)
  push?
  (if cut-and-paste-active?
      (win32-clipboard-write-text
       (let ((string (convert-newline-to-crlf string)))
	 ;; Some programs can't handle strings over 64k.
	 (if (fix:< (string-length string) #x10000) string "")))))

(define (os/interprogram-paste)
  (if cut-and-paste-active?
      (let ((text (win32-clipboard-read-text)))
	(and text
	     (convert-crlf-to-newline text)))))

(define (convert-newline-to-crlf string)
  (let ((end (string-length string)))
    (let ((n-newlines
	   (let loop ((start 0) (n-newlines 0))
	     (let ((newline
		    (substring-find-next-char string start end #\newline)))
	       (if newline
		   (loop (fix:+ newline 1) (fix:+ n-newlines 1))
		   n-newlines)))))
      (if (fix:= n-newlines 0)
	  string
	  (let ((copy (make-string (fix:+ end n-newlines))))
	    (let loop ((start 0) (cindex 0))
	      (let ((newline
		     (substring-find-next-char string start end #\newline)))
		(if newline
		    (begin
		      (%substring-move! string start newline copy cindex)
		      (let ((cindex (fix:+ cindex (fix:- newline start))))
			(string-set! copy cindex #\return)
			(string-set! copy (fix:+ cindex 1) #\newline)
			(loop (fix:+ newline 1) (fix:+ cindex 2))))
		    (%substring-move! string start end copy cindex))))
	    copy)))))

(define (convert-crlf-to-newline string)
  (let ((end (string-length string)))
    (let ((n-crlfs
	   (let loop ((start 0) (n-crlfs 0))
	     (let ((cr
		    (substring-find-next-char string start end #\return)))
	       (if (and cr
			(not (fix:= (fix:+ cr 1) end))
			(char=? (string-ref string (fix:+ cr 1)) #\linefeed))
		   (loop (fix:+ cr 2) (fix:+ n-crlfs 1))
		   n-crlfs)))))
      (if (fix:= n-crlfs 0)
	  string
	  (let ((copy (make-string (fix:- end n-crlfs))))
	    (let loop ((start 0) (cindex 0))
	      (let ((cr
		     (substring-find-next-char string start end #\return)))
		(if (not cr)
		    (%substring-move! string start end copy cindex)
		    (let ((cr
			   (if (and (not (fix:= (fix:+ cr 1) end))
				    (char=? (string-ref string (fix:+ cr 1))
					    #\linefeed))
			       cr
			       (fix:+ cr 1))))
		      (%substring-move! string start cr copy cindex)
		      (loop (fix:+ cr 1) (fix:+ cindex (fix:- cr start)))))))
	    copy)))))

(define (os/read-file-methods) '())
(define (os/write-file-methods) '())
(define (os/alternate-pathnames group pathname) group pathname '())

(define (os/sendmail-program) "sendmail.exe")
(define (os/rmail-pop-procedure) #f)
(define (os/hostname) (error "OS/HOSTNAME procedure unimplemented."))

;;;; Dired customization

(define-variable dired-listing-switches
  "Dired listing format -- Ignored under DOS."
  "-l"
  string?)

(define-variable list-directory-brief-switches
  "list-directory brief listing format -- Ignored under DOS."
  "-l"
  string?)

(define-variable list-directory-verbose-switches
  "list-directory verbose listing format -- Ignored under DOS."
  "-l"
  string?)

(define (insert-directory! file switches mark type)
  switches				; ignored
  ;; Insert directory listing for FILE at MARK.
  ;; TYPE can have one of three values:
  ;;   'WILDCARD means treat FILE as shell wildcard.
  ;;   'DIRECTORY means FILE is a directory and a full listing is expected.
  ;;   'FILE means FILE itself should be listed, and not its contents.
  ;; SWITCHES are ignored.
  (generate-dired-listing! (if (eq? type 'DIRECTORY)
			       (pathname-as-directory file)
			       file)
			   mark))

(define (generate-dired-listing! pathname point)
  (let ((files (directory-read pathname)))
    (for-each (lambda (file) (generate-dired-entry! file point))
	      files)))

(define (generate-dired-entry! file point)
  (define (file-attributes/ls-time-string attr)
    (let ((time-string
	   (file-time->string (file-attributes/modification-time attr))))
      ;; Move the year from end to start, carrying leading space.
      (let ((index (fix:- (string-length time-string) 5)))
	(string-append (string-tail time-string index)
		       " "
		       (string-head time-string index)))))

  (let ((name (file-namestring file))
	(attr (or (file-attributes file) (dummy-file-attributes))))
    (let ((entry (string-append
		  (string-pad-right	; Mode string
		   (file-attributes/mode-string attr) 12 #\Space)
		  (string-pad-left    ; Length
		   (number->string (file-attributes/length attr)) 10 #\Space)
		  (string-pad-right   ; Mod time
		   (file-attributes/ls-time-string attr) 26 #\Space)
		  name)))
      (let ((point (mark-left-inserting-copy point)))
	(insert-string entry point)
	(insert-newline point)
	(mark-temporary! point)))))

(define-integrable (dummy-file-attributes)
  '#(#f 0 0 0 0 0 0 0 "----------" 0))