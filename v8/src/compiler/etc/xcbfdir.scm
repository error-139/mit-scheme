#| -*-Scheme-*-

$Id: a9c028378b394ef547b76da41dfd54aecc327696 $

Copyright (c) 1989-1999 Massachusetts Institute of Technology

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
|#

;;;; Distributed directory recompilation.

(declare (usual-integrations))

(define (process-directory directory processor extension)
  (for-each
   (lambda (pathname)
     (let ((one (pathname-new-type pathname extension))
	   (two (pathname-new-type pathname "tch")))
       (call-with-current-continuation
	(lambda (here)
	  (bind-condition-handler (list condition-type:error)
	      (lambda (condition)
		(let ((port (current-output-port)))
		  (newline port)
		  (write-string ";; *** Aborting " port)
		  (display pathname port)
		  (write-string " ***" port)
		  (newline port)
		  (write-condition-report condition port)
		  (newline port))
		(here 'next))
	    (lambda ()
	      (let ((touch-created-file? false))
		(dynamic-wind
		 (lambda ()
		   ;; file-touch returns #T if the file did not exist,
		   ;; #F if it did.
		   (set! touch-created-file? (file-touch two))
		   unspecific)
		 (lambda ()
		   (if (and touch-created-file?
			    (let ((one-time (file-modification-time one)))
			      (or (not one-time)
				  (< one-time
				     (file-modification-time pathname)))))
		       (processor pathname
				  (pathname-new-type pathname extension))))
		 (lambda ()
		   (if touch-created-file?
		       (delete-file two)))))))))))
   (directory-read
    (merge-pathnames (pathname-as-directory (->pathname directory))
		     (->pathname "*.bin")))))

(define (recompile-directory dir)
  (let ((extn
	 (if (access compiler:cross-compiling?
		     (->environment '(compiler)))
	     "moc"
	     "com")))
    (process-directory dir compile-bin-file extn)))

(define (cross-compile-directory dir)
  (process-directory dir cross-compile-bin-file "moc"))