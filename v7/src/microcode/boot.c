/* -*-C-*-

$Id: boot.c,v 9.86 1993/10/26 03:04:06 jawilson Exp $

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
MIT in each case. */

/* This file contains `main' and associated startup code. */

#include "scheme.h"
#include "prims.h"
#include "version.h"
#include "option.h"
#ifndef islower
#include <ctype.h>
#endif
#include "ostop.h"
#include "ostty.h"

extern PTR EXFUN (malloc, (unsigned int size));
extern void EXFUN (free, (PTR ptr));
extern void EXFUN (init_exit_scheme, (void));
extern void EXFUN (Clear_Memory, (int, int, int));
extern void EXFUN (Setup_Memory, (int, int, int));
extern void EXFUN (compiler_initialize, (long fasl_p));
extern SCHEME_OBJECT EXFUN (make_primitive, (char *, int));

static void EXFUN (Start_Scheme, (int, CONST char *));
static void EXFUN (Enter_Interpreter, (void));

CONST char * scheme_program_name;
CONST char * OS_Name;
CONST char * OS_Variant;
struct obstack scratch_obstack;
PTR initial_C_stack_pointer;
static char * reload_saved_string;
static unsigned int reload_saved_string_length;

/* If true, this is an executable created by dump-world. */
Boolean scheme_dumped_p = false;

PTR
DEFUN (obstack_chunk_alloc, (size), unsigned int size)
{
  PTR result = (malloc (size));
  if (result == 0)
    {
      outf_fatal ("\n%s: unable to allocate obstack chunk of %d bytes\n",
	       scheme_program_name, size);
      Microcode_Termination (TERM_EXIT);
    }
  return (result);
}

#define obstack_chunk_free free

#ifndef INIT_FIXED_OBJECTS
#define INIT_FIXED_OBJECTS() Fixed_Objects = (make_fixed_objects_vector ())
#endif

/* Declare the outermost critical section. */
DECLARE_CRITICAL_SECTION ();

#define BLOCKS_TO_BYTES(n) ((n) * 1024)

static void
DEFUN (usage, (error_string), CONST char * error_string)
{
  outf_fatal ("%s: %s\n\n", scheme_program_name, error_string);
  termination_init_error ();
}

/* Exit is done in a different way on some operating systems (eg. VMS)  */

#ifndef main_type
#define main_type void
#endif

#ifndef main_name
#define main_name main
#endif

#define FILE_READABLE(filename) ((access ((filename), 4)) >= 0)

main_type
DEFUN (main_name, (argc, argv),
       int argc AND CONST char ** argv)
{
  init_exit_scheme ();
  scheme_program_name = (argv[0]);
  initial_C_stack_pointer = ((PTR) (&argc));
  obstack_init (&scratch_obstack);
  reload_saved_string = 0;
  reload_saved_string_length = 0;
  read_command_line_options (argc, argv);

  if (scheme_dumped_p)
    {
      extern SCHEME_OBJECT compiler_utilities;
      extern void EXFUN (compiler_reset, (SCHEME_OBJECT));

      if (! ((Heap_Size == ((long) option_heap_size))
	     && (Stack_Size == ((long) option_stack_size))
	     && (Constant_Size == ((long) option_constant_size))))
	{
	  outf_error ("%s: warning: ignoring allocation parameters.\n",
		      scheme_program_name);
	  outf_flush_error ();
	}
      OS_reset ();
      compiler_reset (compiler_utilities);
      if (!option_band_specified)
	{
	  outf_console ("Scheme Microcode Version %d.%d\n",
	                VERSION, SUBVERSION);
	  OS_initialize ();
	  Enter_Interpreter ();
	}
      else
	{
	  Clear_Memory ((BLOCKS_TO_BYTES (Heap_Size)),
			(BLOCKS_TO_BYTES (Stack_Size)),
			(BLOCKS_TO_BYTES (Constant_Size)));
	  /* We are reloading from scratch anyway. */
	  scheme_dumped_p = false;
	  if (option_fasl_file)
	    Start_Scheme (BOOT_FASLOAD, option_fasl_file);
	  else
	    Start_Scheme (BOOT_LOAD_BAND, option_band_file);
	}
    }
  else
    {
      extern void EXFUN (initialize_primitives, (void));

      Heap_Size = option_heap_size;
      Stack_Size = option_stack_size;
      Constant_Size = option_constant_size;
      Setup_Memory ((BLOCKS_TO_BYTES (Heap_Size)),
		    (BLOCKS_TO_BYTES (Stack_Size)),
		    (BLOCKS_TO_BYTES (Constant_Size)));
      initialize_primitives ();
      if (! option_fasl_file)
	{
	  compiler_initialize (0);
	  Start_Scheme (BOOT_LOAD_BAND, option_band_file);
	}
#ifdef NATIVE_CODE_IS_C
      else if (! (FILE_READABLE (option_fasl_file)))
      {
	compiler_initialize (1);
	Start_Scheme (BOOT_EXECUTE, option_fasl_file);
      }
#endif /* NATIVE_CODE_IS_C */
      else
	{
	  compiler_initialize (1);
	  Start_Scheme (BOOT_FASLOAD, option_fasl_file);
	}
    }
  termination_init_error ();
}

SCHEME_OBJECT
DEFUN_VOID (make_fixed_objects_vector)
{
  extern SCHEME_OBJECT EXFUN (initialize_history, (void));
  extern SCHEME_OBJECT EXFUN (initialize_interrupt_handler_vector, (void));
  extern SCHEME_OBJECT EXFUN (initialize_interrupt_mask_vector, (void));

  /* Create the fixed objects vector,
     with 4 extra slots for expansion and debugging. */
  fast SCHEME_OBJECT fixed_objects_vector =
    (make_vector ((NFixed_Objects + 4), SHARP_F, false));
  FAST_VECTOR_SET (fixed_objects_vector, Me_Myself, fixed_objects_vector);
  FAST_VECTOR_SET
    (fixed_objects_vector, Non_Object, (MAKE_OBJECT (TC_TRUE, 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     System_Interrupt_Vector,
     (initialize_interrupt_handler_vector ()));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     FIXOBJ_INTERRUPT_MASK_VECTOR,
     (initialize_interrupt_mask_vector ()));
  /* Error vector is not needed at boot time */
  FAST_VECTOR_SET (fixed_objects_vector, System_Error_Vector, SHARP_F);
  FAST_VECTOR_SET
    (fixed_objects_vector,
     OBArray,
     (make_vector (OBARRAY_SIZE, EMPTY_LIST, false)));
  FAST_VECTOR_SET
    (fixed_objects_vector, Dummy_History, (initialize_history ()));
  FAST_VECTOR_SET (fixed_objects_vector, State_Space_Tag, SHARP_T);
  FAST_VECTOR_SET (fixed_objects_vector, Bignum_One, (long_to_bignum (1)));
  FAST_VECTOR_SET (fixed_objects_vector, FIXOBJ_EDWIN_AUTO_SAVE, EMPTY_LIST);

  (*Free++) = EMPTY_LIST;
  (*Free++) = EMPTY_LIST;
  FAST_VECTOR_SET
    (fixed_objects_vector,
     The_Work_Queue,
     (MAKE_POINTER_OBJECT (TC_LIST, (Free - 2))));

  FAST_VECTOR_SET
    (fixed_objects_vector,
     Utilities_Vector,
     (make_vector (0, SHARP_F, false)));

  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_ZERO_P,
     (make_primitive ("INTEGER-ZERO?", 1)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_POSITIVE_P,
     (make_primitive ("INTEGER-POSITIVE?", 1)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_NEGATIVE_P,
     (make_primitive ("INTEGER-NEGATIVE?", 1)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_SUCCESSOR,
     (make_primitive ("INTEGER-ADD-1", 1)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_PREDECESSOR,
     (make_primitive ("INTEGER-SUBTRACT-1", 1)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_EQUAL_P,
     (make_primitive ("INTEGER-EQUAL?", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_LESS_P,
     (make_primitive ("INTEGER-LESS?", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_GREATER_P,
     (make_primitive ("INTEGER-GREATER?", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_ADD,
     (make_primitive ("INTEGER-ADD", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_SUBTRACT,
     (make_primitive ("INTEGER-SUBTRACT", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_MULTIPLY,
     (make_primitive ("INTEGER-MULTIPLY", 2)));
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_DIVIDE,
     SHARP_F);
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_QUOTIENT,
     SHARP_F);
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_REMAINDER,
     SHARP_F);
  FAST_VECTOR_SET
    (fixed_objects_vector,
     GENERIC_TRAMPOLINE_MODULO,
     SHARP_F);

  /* This guarantees that it will not be EQ? to anything
     until smashed by the runtime system.
   */

  (*Free++) = EMPTY_LIST;
  (*Free++) = EMPTY_LIST;
  FAST_VECTOR_SET
    (fixed_objects_vector,
     ARITY_DISPATCHER_TAG,
     (MAKE_POINTER_OBJECT (TC_LIST, (Free - 2))));

#ifdef DOS386
  {
    extern void EXFUN (DOS_initialize_fov, (SCHEME_OBJECT));

    DOS_initialize_fov (fixed_objects_vector);
  }
#endif /* DOS386 */

#ifdef WINNT
  {
    extern void EXFUN (NT_initialize_fov, (SCHEME_OBJECT));
    
    NT_initialize_fov (fixed_objects_vector);
  }
#endif /* WINNT */

  return (fixed_objects_vector);
}

/* Boot Scheme */

#ifndef ENTRY_HOOK
#  define ENTRY_HOOK() do { } while (0)
#endif

static void
DEFUN (Start_Scheme, (Start_Prim, File_Name),
       int Start_Prim AND CONST char * File_Name)
{
  SCHEME_OBJECT FName, expr, * inner_arg, prim;
  /* fast long i; */
  /* Parallel processor test */
  Boolean I_Am_Master = (Start_Prim != BOOT_GET_WORK);
  if (I_Am_Master)
    {
      outf_console ("Scheme Microcode Version %d.%d\n",  VERSION, SUBVERSION);
      outf_flush_console ();
    }
  OS_initialize ();
  if (I_Am_Master)
  {
    Current_State_Point = SHARP_F;
    Fluid_Bindings = EMPTY_LIST;
    INIT_FIXED_OBJECTS ();
  }

  /* The initial program to execute is one of
        (SCODE-EVAL (BINARY-FASLOAD <file-name>) SYSTEM-GLOBAL-ENVIRONMENT),
	(LOAD-BAND <file-name>), or
	((GET-WORK))
	(SCODE-EVAL (INITIALIZE-C-COMPILED-BLOCK <file>) GLOBAL-ENV)
     depending on the value of Start_Prim. */
  switch (Start_Prim)
  {
    case BOOT_FASLOAD:	/* (SCODE-EVAL (BINARY-FASLOAD <file>) GLOBAL-ENV) */
      FName = (char_pointer_to_string ((unsigned char *) File_Name));
      prim = (make_primitive ("BINARY-FASLOAD", 1));
      inner_arg = Free;
      *Free++ = prim;
      *Free++ = FName;
      prim = (make_primitive ("SCODE-EVAL", 2));
      expr = MAKE_POINTER_OBJECT (TC_PCOMB2, Free);
      *Free++ = prim;
      *Free++ = MAKE_POINTER_OBJECT (TC_PCOMB1, inner_arg);
      *Free++ = MAKE_OBJECT (GLOBAL_ENV, GO_TO_GLOBAL);
      break;

    case BOOT_LOAD_BAND:	/* (LOAD-BAND <file>) */
      FName = (char_pointer_to_string ((unsigned char *) File_Name));
      prim = (make_primitive ("LOAD-BAND", 1));
      inner_arg = Free;
      *Free++ = prim;
      *Free++ = FName;
      expr = MAKE_POINTER_OBJECT (TC_PCOMB1, inner_arg);
      break;

    case BOOT_GET_WORK:		/* ((GET-WORK)) */
      prim = (make_primitive ("GET-WORK", 0));
      inner_arg = Free;
      *Free++ = prim;
      *Free++ = SHARP_F;
      expr = MAKE_POINTER_OBJECT (TC_COMBINATION, Free);
      *Free++ = MAKE_OBJECT (TC_MANIFEST_VECTOR, 1);
      *Free++ = MAKE_POINTER_OBJECT (TC_PCOMB1, inner_arg);
      break;

    case BOOT_EXECUTE:
      /* (SCODE-EVAL (INITIALIZE-C-COMPILED-BLOCK <file>) GLOBAL-ENV) */
      FName = (char_pointer_to_string ((unsigned char *) File_Name));
      prim = (make_primitive ("INITIALIZE-C-COMPILED-BLOCK", 1));
      inner_arg = Free;
      *Free++ = prim;
      *Free++ = FName;
      prim = (make_primitive ("SCODE-EVAL", 2));
      expr = (MAKE_POINTER_OBJECT (TC_PCOMB2, Free));
      *Free++ = prim;
      *Free++ = (MAKE_POINTER_OBJECT (TC_PCOMB1, inner_arg));
      *Free++ = (MAKE_OBJECT (GLOBAL_ENV, GO_TO_GLOBAL));
      break;
      

    default:
      outf_fatal ("Unknown boot time option: %d\n", Start_Prim);
      Microcode_Termination (TERM_BAD_PRIMITIVE);
      /*NOTREACHED*/
  }

  /* Setup registers */
  INITIALIZE_INTERRUPTS ();
  SET_INTERRUPT_MASK (0);
  Env = (MAKE_OBJECT (GLOBAL_ENV, 0));
  Trapping = false;
  Return_Hook_Address = NULL;

  /* Give the interpreter something to chew on, and ... */
 Will_Push (CONTINUATION_SIZE);
  Store_Return (RC_END_OF_COMPUTATION);
  Store_Expression (SHARP_F);
  Save_Cont ();
 Pushed ();

  Store_Expression (expr);

  /* Go to it! */
  if ((Stack_Pointer <= Stack_Guard) || (Free > MemTop))
  {
    outf_fatal ("Configuration won't hold initial data.\n");
    termination_init_error ();
  }
  ENTRY_HOOK ();
  Enter_Interpreter ();
}

#ifdef WINNT
  extern void EXFUN (WinntEnterHook, (void (*) (void)));
# define HOOK_ENTER_INTERPRETER WinntEnterHook
#endif

#ifndef HOOK_ENTER_INTERPRETER
#  define HOOK_ENTER_INTERPRETER(func) func ()
#endif

static void
DEFUN_VOID (Do_Enter_Interpreter)
{
  Interpret (scheme_dumped_p);
  outf_fatal ("\nThe interpreter returned to top level!\n");
  Microcode_Termination (TERM_EXIT);
}

static void
DEFUN_VOID (Enter_Interpreter)
{
  HOOK_ENTER_INTERPRETER (Do_Enter_Interpreter);
}

/* This must be used with care, and only synchronously. */

extern SCHEME_OBJECT EXFUN (Re_Enter_Interpreter, (void));

SCHEME_OBJECT
DEFUN_VOID (Re_Enter_Interpreter)
{
  Interpret (true);
  return  Val;
}

/* Garbage collection debugging utilities. */

extern SCHEME_OBJECT
  *deadly_free,
  *deadly_scan;

extern unsigned long
  gc_counter;

extern void EXFUN (gc_death,
		   (long code, char *, SCHEME_OBJECT *, SCHEME_OBJECT *));
extern void EXFUN (stack_death, (CONST char *));

extern char
  gc_death_message_buffer[];

SCHEME_OBJECT
  *deadly_free,
  *deadly_scan;

unsigned long
  gc_counter = 0;

char
  gc_death_message_buffer[100];

void
DEFUN (gc_death, (code, message, scan, free),
       long code AND char * message
       AND SCHEME_OBJECT * scan AND SCHEME_OBJECT * free)
{
  outf_fatal ("\n%s.\n", message);
  outf_fatal ("scan = 0x%lx; free = 0x%lx\n", scan, free);
  deadly_scan = scan;
  deadly_free = free;
  Microcode_Termination (code);
  /*NOTREACHED*/
}

void
DEFUN (stack_death, (name), CONST char * name)
{
  outf_fatal
    ("\n%s: The stack has overflowed and overwritten adjacent memory.\n",
     name);
  outf_fatal ("This was probably caused by a runaway recursion.\n");
  Microcode_Termination (TERM_STACK_OVERFLOW);
  /*NOTREACHED*/
}

/* Utility primitives. */

#define IDENTITY_LENGTH 	20	/* Plenty of room */
#define ID_RELEASE		0	/* System release (string) */
#define ID_MICRO_VERSION	1	/* Microcode version (fixnum) */
#define ID_MICRO_MOD		2	/* Microcode modification (fixnum) */
#define ID_PRINTER_WIDTH	3	/* TTY width (# chars) */
#define ID_PRINTER_LENGTH	4	/* TTY height (# chars) */
#define ID_NEW_LINE_CHARACTER	5	/* #\Newline */
#define ID_FLONUM_PRECISION	6	/* Flonum mantissa (# bits) */
#define ID_FLONUM_EPSILON	7	/* Flonum epsilon (flonum) */
#define ID_OS_NAME		8	/* OS name (string) */
#define ID_OS_VARIANT		9	/* OS variant (string) */
#define ID_STACK_TYPE		10	/* Scheme stack type (string) */

#ifdef USE_STACKLETS
#define STACK_TYPE_STRING "stacklets"
#else
#define STACK_TYPE_STRING "standard"
#endif

DEFINE_PRIMITIVE ("MICROCODE-IDENTIFY", Prim_microcode_identify, 0, 0, 0)
{
  fast SCHEME_OBJECT Result;
  PRIMITIVE_HEADER (0);
  Result = (make_vector (IDENTITY_LENGTH, SHARP_F, true));
  FAST_VECTOR_SET (Result, ID_RELEASE,
		   (char_pointer_to_string ((unsigned char *) RELEASE)));
  FAST_VECTOR_SET
    (Result, ID_MICRO_VERSION, (LONG_TO_UNSIGNED_FIXNUM (VERSION)));
  FAST_VECTOR_SET
    (Result, ID_MICRO_MOD, (LONG_TO_UNSIGNED_FIXNUM (SUBVERSION)));
  FAST_VECTOR_SET
    (Result, ID_PRINTER_WIDTH, (LONG_TO_UNSIGNED_FIXNUM (OS_tty_x_size ())));
  FAST_VECTOR_SET
    (Result, ID_PRINTER_LENGTH, (LONG_TO_UNSIGNED_FIXNUM (OS_tty_y_size ())));
  FAST_VECTOR_SET
    (Result, ID_NEW_LINE_CHARACTER, (ASCII_TO_CHAR ('\n')));
  FAST_VECTOR_SET
    (Result, ID_FLONUM_PRECISION, (LONG_TO_UNSIGNED_FIXNUM (DBL_MANT_DIG)));
  FAST_VECTOR_SET
    (Result, ID_FLONUM_EPSILON, (double_to_flonum ((double) DBL_EPSILON)));
  FAST_VECTOR_SET
    (Result, ID_OS_NAME, (char_pointer_to_string ((unsigned char *) OS_Name)));
  FAST_VECTOR_SET (Result, ID_OS_VARIANT,
		   (char_pointer_to_string ((unsigned char *) OS_Variant)));
  FAST_VECTOR_SET (Result, ID_STACK_TYPE,
		   (char_pointer_to_string
		    ((unsigned char *) STACK_TYPE_STRING)));
  PRIMITIVE_RETURN (Result);
}

DEFINE_PRIMITIVE ("MICROCODE-TABLES-FILENAME", Prim_microcode_tables_filename, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  PRIMITIVE_RETURN
    (char_pointer_to_string ((unsigned char *) option_utabmd_file));
}

DEFINE_PRIMITIVE ("MICROCODE-LIBRARY-PATH", Prim_microcode_library_path, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  {
    CONST char ** scan = option_library_path;
    CONST char ** end = option_library_path;
    while (1)
      if ((*end++) == 0)
	{
	  end -= 1;
	  break;
	}
    {
      SCHEME_OBJECT result =
	(allocate_marked_vector (TC_VECTOR, (end - scan), 1));
      SCHEME_OBJECT * scan_result = (VECTOR_LOC (result, 0));
      while (scan < end)
	(*scan_result++) =
	  (char_pointer_to_string ((unsigned char *) *scan++));
      PRIMITIVE_RETURN (result);
    }
  }
}

static SCHEME_OBJECT
DEFUN (argv_to_object, (argc, argv), int argc AND CONST char ** argv)
{
  SCHEME_OBJECT result = (allocate_marked_vector (TC_VECTOR, argc, 1));
  CONST char ** scan = argv;
  CONST char ** end = (scan + argc);
  SCHEME_OBJECT * scan_result = (VECTOR_LOC (result, 0));
  while (scan < end)
    (*scan_result++) = (char_pointer_to_string ((unsigned char *) *scan++));
  return (result);
}

DEFINE_PRIMITIVE ("GET-COMMAND-LINE", Prim_get_command_line, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  PRIMITIVE_RETURN (argv_to_object (option_saved_argc, option_saved_argv));
}

DEFINE_PRIMITIVE ("GET-UNUSED-COMMAND-LINE", Prim_get_unused_command_line, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  if (option_unused_argv == 0)
    PRIMITIVE_RETURN (SHARP_F);
  {
    SCHEME_OBJECT result =
      (argv_to_object (option_unused_argc, option_unused_argv));
    option_unused_argv = 0;
    PRIMITIVE_RETURN (result);
  }
}

DEFINE_PRIMITIVE ("RELOAD-SAVE-STRING", Prim_reload_save_string, 1, 1, 0)
{
  PRIMITIVE_HEADER (1);
  if (reload_saved_string != 0)
    {
      free (reload_saved_string);
      reload_saved_string = 0;
    }
  if ((ARG_REF (1)) != SHARP_F)
    {
      CHECK_ARG (1, STRING_P);
      {
	unsigned int length = (STRING_LENGTH (ARG_REF (1)));
	reload_saved_string = (malloc (length));
	if (reload_saved_string == 0)
	  error_external_return ();
	reload_saved_string_length = length;
	{
	  char * scan = ((char *) (STRING_LOC ((ARG_REF (1)), 0)));
	  char * end = (scan + length);
	  char * scan_result = reload_saved_string;
	  while (scan < end)
	    (*scan_result++) = (*scan++);
	}
      }
    }
  PRIMITIVE_RETURN (UNSPECIFIC);
}

DEFINE_PRIMITIVE ("RELOAD-RETRIEVE-STRING", Prim_reload_retrieve_string, 0, 0, 0)
{
  PRIMITIVE_HEADER (0);
  if (reload_saved_string == 0)
    PRIMITIVE_RETURN (SHARP_F);
  {
    SCHEME_OBJECT result =
      (memory_to_string (reload_saved_string_length,
			 ((unsigned char *) reload_saved_string)));
    free (reload_saved_string);
    reload_saved_string = 0;
    PRIMITIVE_RETURN (result);
  }
}
