#| -*-Scheme-*-

$Id: datime.scm,v 14.13 1996/04/24 03:22:03 cph Exp $

Copyright (c) 1988-96 Massachusetts Institute of Technology

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

;;;; Date and Time Routines
;;; package: (runtime date/time)

(declare (usual-integrations))

;;;; Decoded Time

;;; Based on Common Lisp definition.  Needs time zone stuff, and
;;; handling of abbreviated year specifications.

(define decoded-time-structure-tag "decoded-time")

(define-structure (decoded-time
		   (type vector)
		   (named decoded-time-structure-tag)
		   (conc-name decoded-time/)
		   (constructor %make-decoded-time)
		   (constructor allocate-decoded-time ()))
  (second #f read-only #t)
  (minute #f read-only #t)
  (hour #f read-only #t)
  (day #f read-only #t)
  (month #f read-only #t)
  (year #f read-only #t)
  (day-of-week #f read-only #t)
  (daylight-savings-time #f read-only #t)
  (zone #f))

(define (make-decoded-time second minute hour day month year)
  (let ((dt
	 (let ((limit
		(lambda (low number high)
		  (cond ((< number low) low)
			((> number high) high)
			(else number)))))
	   (let ((month (limit 1 month 12)))
	     (%make-decoded-time (limit 0 second 59)
				 (limit 0 minute 59)
				 (limit 0 hour 23)
				 (limit 1 day (month/max-days month))
				 month
				 (if (< year 0) 0 year)
				 0
				 -1
				 #f)))))
    ;; These calls fill in the other fields of the structure.
    ((ucode-primitive decode-time 2) dt ((ucode-primitive encode-time 1) dt))
    (if (decoded-time/zone dt)
	(set-decoded-time/zone! dt (/ (decoded-time/zone dt) 3600)))
    dt))

(define (decode-universal-time time)
  (let ((result (allocate-decoded-time)))
    ((ucode-primitive decode-time 2) result time)
    (if (decoded-time/zone result)
	(set-decoded-time/zone! result (/ (decoded-time/zone result) 3600)))
    result))

(define (encode-universal-time dt)
  ((ucode-primitive encode-time 1) dt))

(define (get-universal-time)
  ((ucode-primitive encoded-time 0)))

(define (get-decoded-time)
  (decode-universal-time (get-universal-time)))

(define (time-zone? object)
  (and (number? object)
       (exact? object)
       (<= -24 object 24)
       (integer? (* 3600 object))))

(define (decoded-time/daylight-savings-time? dt)
  (> (decoded-time/daylight-savings-time dt) 0))

(define (decoded-time/date-string time)
  (string-append (day-of-week/long-string (decoded-time/day-of-week time))
		 " "
		 (month/long-string (decoded-time/month time))
		 " "
		 (number->string (decoded-time/day time))
		 ", "
		 (number->string (decoded-time/year time))))

(define (decoded-time/time-string time)
  (let ((second (decoded-time/second time))
	(minute (decoded-time/minute time))
	(hour (decoded-time/hour time)))
    (string-append (number->string
		    (cond ((zero? hour) 12)
			  ((< hour 13) hour)
			  (else (- hour 12))))
		   (if (< minute 10) ":0" ":")
		   (number->string minute)
		   (if (< second 10) ":0" ":")
		   (number->string second)
		   " "
		   (if (< hour 12) "AM" "PM"))))

(define (universal-time->string time)
  (decoded-time->string (decode-universal-time time)))

(define (file-time->string time)
  (decoded-time->string (decode-file-time time)))

(define (decoded-time->string dt)
  ;; The returned string is in the format specified by RFC 822,
  ;; "Standard for the Format of ARPA Internet Text Messages",
  ;; provided that time-zone information is available from the C
  ;; library.
  (let ((d2 (lambda (n) (string-pad-left (number->string n) 2 #\0))))
    (string-append (day-of-week/short-string (decoded-time/day-of-week dt))
		   ", "
		   (number->string (decoded-time/day dt))
		   " "
		   (month/short-string (decoded-time/month dt))
		   " "
		   (number->string (decoded-time/year dt))
		   " "
		   (d2 (decoded-time/hour dt))
		   ":"
		   (d2 (decoded-time/minute dt))
		   ":"
		   (d2 (decoded-time/second dt))
		   (let ((zone (decoded-time/zone dt)))
		     (if zone
			 (string-append
			  " "
			  (time-zone->string
			   (if (decoded-time/daylight-savings-time? dt)
			       (- zone 1)
			       zone)))
			 "")))))

(define (time-zone->string tz)
  (if (not (time-zone? tz))
      (error:wrong-type-argument tz "time zone" 'TIME-ZONE->STRING))
  (let ((minutes (round (* 60 (- tz)))))
    (let ((qr (integer-divide (abs minutes) 60))
	  (d2 (lambda (n) (string-pad-left (number->string n) 2 #\0))))
      (string-append (if (< minutes 0) "-" "+")
		     (d2 (integer-divide-quotient qr))
		     (d2 (integer-divide-remainder qr))))))

(define (month/max-days month)
  (guarantee-month month 'MONTH/MAX-DAYS)
  (vector-ref '#(31 29 31 30 31 30 31 31 30 31 30 31) (- month 1)))

(define (month/short-string month)
  (guarantee-month month 'MONTH/SHORT-STRING)
  (vector-ref '#("Jan" "Feb" "Mar" "Apr" "May" "Jun"
		       "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
	      (- month 1)))

(define (month/long-string month)
  (guarantee-month month 'MONTH/LONG-STRING)
  (vector-ref '#("January" "February" "March" "April" "May" "June"
			   "July" "August" "September" "October"
			   "November" "December")
	      (- month 1)))

(define (guarantee-month month name)
  (if (not (exact-integer? month))
      (error:wrong-type-argument month "month integer" name))
  (if (not (<= 1 month 12))
      (error:bad-range-argument month name)))

(define (day-of-week/short-string day)
  (guarantee-day-of-week day 'DAY-OF-WEEK/SHORT-STRING)
  (vector-ref '#("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun") day))

(define (day-of-week/long-string day)
  (guarantee-day-of-week day 'DAY-OF-WEEK/LONG-STRING)
  (vector-ref '#("Monday" "Tuesday" "Wednesday" "Thursday" "Friday"
			  "Saturday" "Sunday")
	      day))

(define (guarantee-day-of-week day name)
  (if (not (exact-integer? day))
      (error:wrong-type-argument day "day-of-week integer" name))
  (if (not (<= 0 day 6))
      (error:bad-range-argument day name)))