#| -*- Scheme -*-

$Id: ed-ffi.scm,v 1.43 2008/09/03 02:49:03 cph Exp $

Copyright (C) 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994,
    1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005,
    2006, 2007, 2008 Massachusetts Institute of Technology

This file is part of MIT/GNU Scheme.

MIT/GNU Scheme is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at
your option) any later version.

MIT/GNU Scheme is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with MIT/GNU Scheme; if not, write to the Free Software
Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301,
USA.

|#

;;;; Edwin buffer packaging info

(declare (usual-integrations))

(standard-scheme-find-file-initialization
 '#(("advice"	(runtime advice))
    ("apply"	(runtime apply))
    ("apropos"	(runtime apropos))
    ("arith"	(runtime number))
    ("bitstr"	(runtime bit-string))
    ("blowfish"	(runtime blowfish))
    ("boole"	(runtime boolean))
    ("boot"	(runtime boot-definitions))
    ("char"	(runtime character))
    ("chrset"	(runtime character-set))
    ("chrsyn"	(runtime char-syntax))
    ("codwlk"	(runtime scode-walker))
    ("conpar"	(runtime continuation-parser))
    ("contin"	(runtime continuation))
    ("cpoint"	(runtime control-point))
    ("cpress"	(runtime compress))
    ("crypto"	(runtime crypto))
    ("datime"	(runtime date/time))
    ("dbgcmd"	(runtime debugger-command-loop))
    ("dbgutl"	(runtime debugger-utilities))
    ("debug"	(runtime debugger))
    ("defstr"	(runtime defstruct))
    ("dospth"	(runtime pathname dos))
    ("dragon4"	(runtime number))
    ("emacs"	(runtime emacs-interface))
    ("equals"	(runtime equality))
    ("error"	(runtime error-handler))
    ("events"	(runtime event-distributor))
    ("fileio"	(runtime file-i/o-port))
    ("fixart"	(runtime fixnum-arithmetic))
    ("format"	(runtime format))
    ("framex"	(runtime debugging-info))
    ("gc"	(runtime garbage-collector))
    ("gcdemn"	(runtime gc-daemons))
    ("gcfinal"	(runtime gc-finalizer))
    ("gcnote"	(runtime gc-notification))
    ("gcstat"	(runtime gc-statistics))
    ("gdatab"	(runtime global-database))
    ("gdbm"	(runtime gdbm))
    ("gencache"	(runtime generic-procedure))
    ("geneqht"	(runtime generic-procedure))
    ("generic"	(runtime generic-procedure))
    ("genio"	(runtime generic-i/o-port))
    ("genmult"	(runtime generic-procedure multiplexer))
    ("gensym"	(runtime gensym))
    ("gentag"	(runtime generic-procedure))
    ("global"	(runtime miscellaneous-global))
    ("graphics"	(runtime graphics))
    ("hash"	(runtime hash))
    ("hashtb"	(runtime hash-table))
    ("histry"	(runtime history))
    ("html-form-codec" (runtime html-form-codec))
    ("http-client" (runtime http-client))
    ("httpio"	(runtime http-i/o))
    ("illdef"	(runtime illegal-definitions))
    ("infstr"	(runtime compiler-info))
    ("infutl"	(runtime compiler-info))
    ("input"	(runtime input-port))
    ("intrpt"	(runtime interrupt-handler))
    ("io"	(runtime primitive-io))
    ("krypt"	(runtime krypt))
    ("kryptdum"	(runtime krypt))
    ("lambda"	(runtime lambda-abstraction))
    ("lambdx"	(runtime alternative-lambda))
    ("list"	(runtime list))
    ("list-parser" (runtime list-parser))
    ("load"	(runtime load))
    ("mime-codec" (runtime mime-codec))
    ("mit-syntax" (runtime syntactic-closures))
    ("msort"	(runtime merge-sort))
    ("ntdir"	(runtime directory))
    ("ntprm"	(runtime os-primitives))
    ("numint"	(runtime number interface))
    ("numpar"	(runtime number-parser))
    ("option"	(runtime options))
    ("ordvec"	(runtime ordered-vector))
    ("os2ctype"	(runtime os2-graphics))
    ("os2dir"	(runtime directory))
    ("os2graph"	(runtime os2-graphics))
    ("os2prm"	(runtime os-primitives))
    ("os2winp"	(runtime os2-window-primitives))
    ("output"	(runtime output-port))
    ("packag"	(package))
    ("parse"	(runtime parser))
    ("parser-buffer" (runtime parser-buffer))
    ("partab"	(runtime parser-table))
    ("pathnm"	(runtime pathname))
    ("pgsql"	(runtime postgresql))
    ("poplat"	(runtime population))
    ("port"	(runtime port))
    ("pp"	(runtime pretty-printer))
    ("prgcop"	(runtime program-copier))
    ("process"	(runtime subprocess))
    ("prop1d"	(runtime 1d-property))
    ("prop2d"	(runtime 2D-property))
    ("qsort"	(runtime quick-sort))
    ("queue"	(runtime simple-queue))
    ("random"	(runtime random-number))
    ("rbtree"	(runtime rb-tree))
    ("record"	(runtime record))
    ("recslot"	(runtime record-slot-access))
    ("regexp"	(runtime regular-expression))
    ("rep"	(runtime rep))
    ("rexp"	(runtime rexp))
    ("rfc2822-headers" (runtime rfc2822-headers))
    ("rgxcmp"	(runtime regular-expression-compiler))
    ("savres"	(runtime save/restore))
    ("scan"	(runtime scode-scan))
    ("scode"	(runtime scode))
    ("scomb"	(runtime scode-combinator))
    ("sdata"	(runtime scode-data))
    ("sfile"	(runtime simple-file-ops))
    ("socket"	(runtime socket))
    ("starbase"	(runtime starbase-graphics))
    ("stream"	(runtime stream))
    ("string"	(runtime string))
    ("stringio"	(runtime string-i/o-port))
    ("symbol"	(runtime symbol))
    ("syncproc"	(runtime synchronous-subprocess))
    ("syntactic-closures" (runtime syntactic-closures))
    ("syntax-check" (runtime syntactic-closures))
    ("syntax-output" (runtime syntactic-closures))
    ("syntax-rules" (runtime syntactic-closures))
    ("syntax-transforms" (runtime syntactic-closures))
    ("sysclk"	(runtime system-clock))
    ("sysmac"	(runtime system-macros))
    ("system"	(runtime system))
    ("thread"	(runtime thread))
    ("tscript"	(runtime transcript))
    ("ttyio"	(runtime console-i/o-port))
    ("tvector"	(runtime tagged-vector))
    ("udata"	(runtime microcode-data))
    ("uenvir"	(runtime environment))
    ("uerror"	(runtime microcode-errors))
    ("unicode"	(runtime unicode))
    ("unpars"	(runtime unparser))
    ("unsyn"	(runtime unsyntaxer))
    ("unxdir"	(runtime directory))
    ("unxprm"	(runtime os-primitives))
    ("unxpth"	(runtime pathname unix))
    ("uproc"	(runtime procedure))
    ("url"	(runtime uri))
    ("urtrap"	(runtime reference-trap))
    ("usrint"	(runtime user-interface))
    ("utabs"	(runtime microcode-tables))
    ("vector"	(runtime vector))
    ("version"	(runtime))
    ("where"	(runtime environment-inspector))
    ("wind"	(runtime state-space))
    ("wrkdir"	(runtime working-directory))
    ("wttree"	(runtime wt-tree))
    ("x11graph"	(runtime X-graphics))
    ("xeval"	(runtime extended-scode-eval))
    ("ystep"	(runtime stepper))))