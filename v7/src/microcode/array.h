/* -*-C-*-

Copyright (c) 1987 Massachusetts Institute of Technology

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

/* $Header: /Users/cph/tmp/foo/mit-scheme/mit-scheme/v7/src/microcode/Attic/array.h,v 9.21 1987/01/22 14:14:45 jinx Exp $ */

/* The following two macros determine what kind of arrays we deal with.
   Use float to save space for image-processing 
   */

#define REAL float
#define REAL_SIZE ((sizeof(Pointer)+sizeof(REAL)-1)/ sizeof(Pointer))


/****************** Scheme_Array *****************/
/*  using NON_MARKED_VECTOR                      */
/* This assumes that object.h is included also */

#define TC_ARRAY TC_NON_MARKED_VECTOR
#define TC_MANIFEST_ARRAY TC_MANIFEST_NM_VECTOR
#define ARRAY_HEADER 0                                      /* NM_VECTOR_HEADER  */
/* contains the number of actual cells (words) allocated, used in gc */
#define ARRAY_LENGTH 1                                      /* NM_ENTRY_COUNT */
#define ARRAY_DATA 2                                        /* NM_DATA */
#define ARRAY_HEADER_SIZE 2

#define Array_Ref(P,N)      ((Get_Pointer(P))[N+2])

#define Nth_Array_Loc(P,N)  (Scheme_Array_To_C_Array(P) + N)

#define Scheme_Array_To_C_Array(Scheme_Array) 		\
   ((REAL *) Nth_Vector_Loc(Scheme_Array, ARRAY_DATA))

#define Array_Length(Scheme_Array)                  \
   ((long) Vector_Ref(Scheme_Array, ARRAY_LENGTH))

#define Allocate_Array(result, Length, allocated_cells)		                \
  allocated_cells = (Length*REAL_SIZE) + ARRAY_HEADER_SIZE;	                \
  Primitive_GC_If_Needed(allocated_cells);			                \
  result = Make_Pointer(TC_ARRAY, Free);                                        \
  Free[ARRAY_HEADER] = Make_Non_Pointer(TC_MANIFEST_ARRAY, allocated_cells-1);  \
  Free[ARRAY_LENGTH] = Length;                                                  \
  Free = Free+allocated_cells;


/* SOME MORE MACROS */
  
#define ARRAY_MAX_LENGTH 1000000                                              /* 4 Mbytes */

#define Make_List_From_3_Pointers(pointer1, pointer2, pointer3, Result)   \
{ Primitive_GC_If_Needed(6);                \
  Result = Make_Pointer(TC_LIST, Free);     \
  *Free++ = pointer1;                       \
  *Free++ = Make_Pointer(TC_LIST, Free+1);  \
  *Free++ = pointer2;                       \
  *Free++ = Make_Pointer(TC_LIST, Free+1);  \
  *Free++ = pointer3;                       \
  *Free++ = NIL;                            \
}
  
#define Float_Range_Check(variable, Scheme_Pointer, Low, High, Error_Message)       \
{ REAL value;                                                                       \
  int err;                                                                          \
  err = Scheme_Number_To_REAL(Scheme_Pointer, &value);                              \
  if ((err == 1) || (err == 2)) Primitive_Error(Error_Message);                     \
  if ((value<Low) || (value>High)) Primitive_Error(Error_Message);                  \
  variable = ((float) value);                                                       \
}

#define REAL_Range_Check(variable, Scheme_Pointer, Low, High, Error_Message)       \
{ REAL value;                                                                      \
  int err;                                                                         \
  err = Scheme_Number_To_REAL(Scheme_Pointer, &value);                             \
  if ((err == 1) || (err == 2)) Primitive_Error(Error_Message);                    \
  if ((value<Low) || (value>High)) Primitive_Error(Error_Message);                 \
  else variable = value;                                                           \
}

#define C_Make_Polar(Real, Imag, Mag_Cell, Phase_Cell)                         \
{ double double_Real=((double) Real), double_Imag=((double) Imag);             \
  Mag_Cell = (REAL) sqrt((double_Real*double_Real)+(double_Imag*double_Imag)); \
  Phase_Cell = (REAL) atan2(double_Imag, double_Real);                         \
}
/* atan has no problem with division by zero */

#define Linear_Map(slope,offset,From,To) { (To) = (((slope)*(From))+offset); }

#define C_Find_Magnitude(Real, Imag, Mag_Cell)                                 \
{ double double_Real=((double) Real), double_Imag=((double) Imag);             \
  Mag_Cell = (REAL) sqrt((double_Real*double_Real)+(double_Imag*double_Imag)); \
}

#define mabs(x)		(((x)<0) ? -(x) : (x))
#define max(x,y)	(((x)<(y)) ? (y) : (x))
#define min(x,y)	(((x)<(y)) ? (x) : (y))


/* FROM ARRAY.C */
extern int    Scheme_Number_To_REAL();
extern int    Scheme_Number_To_Double();
extern void   C_Array_Copy();        /* REAL *From_Array,*To_Array; long Length; */

extern void   C_Array_Find_Min_Max();          /* Find the index of the minimum (*nmin), maximum (*nmax). */
extern void   C_Array_Find_Average();
extern void   C_Array_Make_Histogram();  /* REAL *Array,*Histogram; long Length,npoints */


/* DATATYPE CONVERSIONS */

/* macro: REAL *Scheme_Array_To_C_Array(); */
extern Pointer C_Array_To_Scheme_Array();
/* there is also a macro: Allocate_Array(Result,Length,allocated_cells); 
 */

extern Pointer Scheme_Vector_To_Scheme_Array();
extern Pointer Scheme_Array_To_Scheme_Vector();

extern Pointer C_Array_To_Scheme_Vector();
extern void    Scheme_Vector_To_C_Array(); 
/* Pointer Scheme_Vector; REAL *Array; 
 */


/* FROM BOB-XT.C */
extern void   Find_Offset_Scale_For_Linear_Map();   /* REAL Min,Max, New_Min,New_Max, *Offset,*Scale; */


#define My_Store_Flonum_Result(Ans, Value_Cell) 		        \
  (Value_Cell) = (Allocate_Float( ((double) Ans)));
/*
#define Allocate_Float(Ans)                                             \
  Primitive_GC_If_Needed(FLONUM_SIZE + 1);			        \
  *Free = Make_Non_Pointer(TC_MANIFEST_NM_VECTOR, FLONUM_SIZE);		\
  Get_Float(C_To_Scheme(Free)) = (Ans);					\
  Free += FLONUM_SIZE+1;						\
  (Value_Cell) = Make_Pointer(TC_BIG_FLONUM, Free-(1+FLONUM_SIZE));
*/

#define My_Store_Reduced_Flonum_Result(Ans, Value_Cell)                 \
  { double Number = ((double) Ans);					\
    double floor();							\
    Pointer result;							\
    if (floor(Number) != Number)					\
    { My_Store_Flonum_Result(Number, Value_Cell);		        \
    }									\
    else if (Number == 0) (Value_Cell) = FIXNUM_0;      		\
    if ((floor(Number) == Number) && (Number != 0))                     \
    { int exponent;							\
      double frexp();							\
      frexp(Number, &exponent);						\
      if (exponent <= FIXNUM_LENGTH)					\
      { double_into_fixnum(Number, result);				\
	(Value_Cell) = result;                                          \
      }									\
      /* Since the float has no fraction, we will not gain		\
	 precision if its mantissa has enough bits to support		\
	 the exponent. */						\
      else if (exponent <= FLONUM_MANTISSA_BITS)		 	\
      {	result = Float_To_Big(Number);					\
	(Value_Cell) = result;                                          \
      }									\
      else if (Number != 0)                                             \
      { My_Store_Flonum_Result( (Ans), (Value_Cell));	                \
      }                                                                 \
    }									\
  }



/* the end */
