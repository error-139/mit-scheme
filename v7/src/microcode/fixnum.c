/* -*-C-*-

$Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/fixnum.c,v 9.30 1990/06/25 18:18:20 jinx Exp $

Copyright (c) 1987, 1988, 1989, 1990 Massachusetts Institute of Technology

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

/* Support for fixed point arithmetic.  This should be used instead of
   generic arithmetic when it is desired to tell the compiler to perform
   open coding of fixnum arithmetic.  It is probably a short-term kludge
   that will eventually go away. */

#include "scheme.h"
#include "prims.h"

static long
arg_fixnum (n)
     int n;
{
  fast SCHEME_OBJECT argument = (ARG_REF (n));
  if (! (FIXNUM_P (argument)))
    error_wrong_type_arg (n);
  return (FIXNUM_TO_LONG (argument));
}

/* Predicates */

DEFINE_PRIMITIVE ("ZERO-FIXNUM?", Prim_zero_fixnum, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) == 0));
}

DEFINE_PRIMITIVE ("NEGATIVE-FIXNUM?", Prim_negative_fixnum, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) < 0));
}

DEFINE_PRIMITIVE ("POSITIVE-FIXNUM?", Prim_positive_fixnum, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) > 0));
}

DEFINE_PRIMITIVE ("EQUAL-FIXNUM?", Prim_equal_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) == (arg_fixnum (2))));
}

DEFINE_PRIMITIVE ("LESS-THAN-FIXNUM?", Prim_less_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) < (arg_fixnum (2))));
}

DEFINE_PRIMITIVE ("GREATER-THAN-FIXNUM?", Prim_greater_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  PRIMITIVE_RETURN (BOOLEAN_TO_OBJECT ((arg_fixnum (1)) > (arg_fixnum (2))));
}

/* Operators */

#define FIXNUM_RESULT(fixnum)						\
{									\
  fast long result = (fixnum);						\
  if (! (LONG_TO_FIXNUM_P (result)))					\
    error_bad_range_arg (1);						\
  PRIMITIVE_RETURN (LONG_TO_FIXNUM (result));				\
}

DEFINE_PRIMITIVE ("ONE-PLUS-FIXNUM", Prim_one_plus_fixnum, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  FIXNUM_RESULT ((arg_fixnum (1)) + 1);
}

DEFINE_PRIMITIVE ("MINUS-ONE-PLUS-FIXNUM", Prim_m_1_plus_fixnum, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  FIXNUM_RESULT ((arg_fixnum (1)) - 1);
}

DEFINE_PRIMITIVE ("PLUS-FIXNUM", Prim_plus_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  FIXNUM_RESULT ((arg_fixnum (1)) + (arg_fixnum (2)));
}

DEFINE_PRIMITIVE ("MINUS-FIXNUM", Prim_minus_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  FIXNUM_RESULT ((arg_fixnum (1)) - (arg_fixnum (2)));
}

DEFINE_PRIMITIVE ("FIXNUM-NEGATE", Prim_fixnum_negate, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  FIXNUM_RESULT (- (arg_fixnum (1)));
}

/* Fixnum multiplication routine with overflow detection. */
#include "mul.c"

DEFINE_PRIMITIVE ("MULTIPLY-FIXNUM", Prim_multiply_fixnum, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  CHECK_ARG (1, FIXNUM_P);
  CHECK_ARG (2, FIXNUM_P);
  {
    fast long result = (Mul ((ARG_REF (1)), (ARG_REF (2))));
    if (result == SHARP_F)
      error_bad_range_arg (1);
    PRIMITIVE_RETURN (result);
  }
}

DEFINE_PRIMITIVE ("DIVIDE-FIXNUM", Prim_divide_fixnum, 2, 2, 0)
{
  fast long numerator;
  fast long denominator;
  fast long quotient;
  fast long remainder;
  PRIMITIVE_HEADER (2);
  numerator = (arg_fixnum (1));
  denominator = (arg_fixnum (2));
  if (denominator == 0)
    error_bad_range_arg (2);
  /* Now, unbelievable hair because C doesn't fully specify / and %
     when their arguments are negative.  We must get consistent
     answers for all valid arguments. */
  if (numerator < 0)
    {
      numerator = (- numerator);
      if (denominator < 0)
	{
	  denominator = (- denominator);
	  quotient = (numerator / denominator);
	}
      else
	quotient = (- (numerator / denominator));
      remainder = (- (numerator % denominator));
    }
  else
    {
      if (denominator < 0)
	{
	  denominator = (- denominator);
	  quotient = (- (numerator / denominator));
	}
      else
	quotient = (numerator / denominator);
      remainder = (numerator % denominator);
    }
  if (! (LONG_TO_FIXNUM_P (quotient)))
    error_bad_range_arg (1);
  PRIMITIVE_RETURN
    (cons ((LONG_TO_FIXNUM (quotient)), (LONG_TO_FIXNUM (remainder))));
}

DEFINE_PRIMITIVE ("FIXNUM-QUOTIENT", Prim_fixnum_quotient, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  {
    fast long numerator = (arg_fixnum (1));
    fast long denominator = (arg_fixnum (2));
    fast long quotient =
      ((denominator > 0)
       ? ((numerator < 0)
	  ? (- ((- numerator) / denominator))
	  : (numerator / denominator))
       : (denominator < 0)
       ? ((numerator < 0)
	  ? ((- numerator) / (- denominator))
	  : (- (numerator / (- denominator))))
       : (error_bad_range_arg (2), 0));
    if (! (LONG_TO_FIXNUM_P (quotient)))
      error_bad_range_arg (1);
    PRIMITIVE_RETURN (LONG_TO_FIXNUM (quotient));
  }
}

DEFINE_PRIMITIVE ("FIXNUM-REMAINDER", Prim_fixnum_remainder, 2, 2, 0)
{
  PRIMITIVE_HEADER (2);
  {
    fast long numerator = (arg_fixnum (1));
    fast long denominator = (arg_fixnum (2));
    PRIMITIVE_RETURN
      (LONG_TO_FIXNUM
       ((denominator > 0)
	? ((numerator < 0)
	   ? (- ((- numerator) % denominator))
	   : (numerator % denominator))
	: (denominator < 0)
	? ((numerator < 0)
	   ? (- ((- numerator) % (- denominator)))
	   : (numerator % (- denominator)))
	: (error_bad_range_arg (2), 0)));
  }
}

DEFINE_PRIMITIVE ("GCD-FIXNUM", Prim_gcd_fixnum, 2, 2, 0)
{
  fast long x;
  fast long y;
  fast long z;
  PRIMITIVE_HEADER (2);
  x = (arg_fixnum (1));
  y = (arg_fixnum (2));
  if (x < 0) x = (-x);
  if (y < 0) y = (-y);
  while (y != 0)
    {
      z = x;
      x = y;
      y = (z % y);
    }
  PRIMITIVE_RETURN (LONG_TO_FIXNUM (x));
}

/* Bitwise operations */

#define FIXNUM_BOOLEAN_BODY(operation)					\
do									\
{									\
  fast unsigned long x, y, z;						\
									\
  PRIMITIVE_HEADER (2);							\
									\
  x = (arg_fixnum (1));							\
  y = (arg_fixnum (2));							\
									\
  z = (x operation y);							\
  return (LONG_TO_FIXNUM (z));						\
} while (0)


DEFINE_PRIMITIVE ("FIXNUM-ANDC", Prim_fixnum_andc, 2, 2, 0)
{
  FIXNUM_BOOLEAN_BODY(& ~);
}


DEFINE_PRIMITIVE ("FIXNUM-AND", Prim_fixnum_and, 2, 2, 0)
{
  FIXNUM_BOOLEAN_BODY(&);
}


DEFINE_PRIMITIVE ("FIXNUM-OR", Prim_fixnum_or, 2, 2, 0)
{
  FIXNUM_BOOLEAN_BODY(|);
}


DEFINE_PRIMITIVE ("FIXNUM-XOR", Prim_fixnum_xor, 2, 2, 0)
{
  FIXNUM_BOOLEAN_BODY(^);
}


DEFINE_PRIMITIVE ("FIXNUM-NOT", Prim_fixnum_not, 1, 1, 0)
{
  fast unsigned long x, z;

  PRIMITIVE_HEADER (1);

  x = (arg_fixnum (1));

  z = (~ (x));
  return (LONG_TO_FIXNUM (z));
}
