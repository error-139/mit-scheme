/* -*-C-*-

$Id: asmcvt.c,v 1.1 1995/10/15 00:34:08 cph Exp $

Copyright (c) 1995 Massachusetts Institute of Technology

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

/* Program to preprocess assembly files for Intel assembler.  */

#include <stdio.h>

void
main (unsigned int argc, const char ** argv)
{
  if ((argc > 1) && ((strcmp ((argv[1]), "pre")) == 0))
    {
      /* Convert '#' to ';' and eliminate formfeeds.  */
      printf("changecom(`;')\n");
      while (1)
	{
	  int c = (getchar ());
	  switch (c)
	    {
	    case EOF: exit (0);
	    case '#': putchar (';'); break;
	    case '\f': break;
	    default: putchar (c); break;
	    }
	}
    }
  else
    {
      /* Delete blank lines.  */
      enum state { line_start, line_middle };
      enum state s = line_start;
      while (1)
	{
	  int c = (getchar ());
	  if (c == EOF)
	    exit (0);
	  if (c == '\n')
	    {
	      if (s == line_middle)
		{
		  putchar (c);
		  s = line_start;
		}
	    }
	  else
	    {
	      putchar (c);
	      s = line_middle;
	    }
	}
    }
}
