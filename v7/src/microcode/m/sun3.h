/* -*-C-*-
   Machine file for Sun 3

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/m/Attic/sun3.h,v 1.4 1991/10/15 22:53:36 cph Exp $

Copyright (c) 1989-91 Massachusetts Institute of Technology

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
MIT in each case. */

#define PROC_TYPE PROC_TYPE_68020

#ifndef ALTERNATE_CC

/* If your machine doesn't have a 68881 coprocessor, remove
   "-f68881" from this line and the LD_SWITCH_MACHINE line. */
#define C_SWITCH_MACHINE -Dsun3 -DTYPE_CODE_LENGTH=6 -DCOMPILER_PROCESSOR_TYPE=COMPILER_MC68040_TYPE -f68881
#define LD_SWITCH_MACHINE -f68881

#else /* ALTERNATE_CC */

#define C_SWITCH_MACHINE -Dsun3 -DTYPE_CODE_LENGTH=6 -DCOMPILER_PROCESSOR_TYPE=COMPILER_MC68040_TYPE

#endif
