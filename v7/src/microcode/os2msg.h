/* -*-C-*-

$Id: os2msg.h,v 1.5 1995/02/08 01:19:11 cph Exp $

Copyright (c) 1994-95 Massachusetts Institute of Technology

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

#ifndef SCM_OS2MSG_H
#define SCM_OS2MSG_H

typedef enum
{
  /* This is sent to acknowledge that the other end of a qid pair has
     been opened.  Sometimes it is necessary to wait until the
     connection is established before proceeding.  */
  mt_init,

  /* This is sent by a "readahead" thread whenever it has some data to
     give to the other end of the connection.  These messages are
     generated asynchronously whenever the readahead is available.  */
  mt_readahead,

  /* This is sent by the receiver of a readahead message.  It is used
     to regulate the amount of readahead in the connection.
     Typically, the readahead thread won't generate any more readahead
     messages until the readahead_ack is received.  */
  mt_readahead_ack,

  /* This is a console interrupt event.  It is generated automatically
     by the console readahead thread, and causes a Scheme character
     interrupt to be signalled in the interrupt-code register.  */
  mt_console_interrupt,

  /* This is a timer interrupt event.  It is generated automatically
     by the timer thread when the timer is active.  */
  mt_timer_event,
  
  /* This event signals the termination of a child process.  It is
     generated automatically by the thread that monitors child
     processes.  */
  mt_child_death,

  /* These are error messages.  They are sent as a reply to a request
     when an error is generated during the processing of the request.  */
  mt_error,
  mt_syscall_error,

  /* This is a generic reply that is used to acknowledge requests that
     return no meaningful data other than that they have completed.  */
  mt_generic_reply,

  /* These are messages that command the PM thread to perform specific
     actions.  A command that does not have a specific reply type will
     receive a generic reply when the PM code is configured to do
     handshaking; normally such a command has no reply.  */
  mt_window_open_request,	/* open a window */
  mt_window_open_reply,
  mt_window_close,		/* close a window */
  mt_window_show,		/* show/hide a window */
  mt_window_move_cursor,	/* move a window's text cursor */
  mt_window_shape_cursor,	/* set the text cursor shape of a window */
  mt_window_show_cursor,	/* show/hide a window's text cursor */
  mt_window_scroll,		/* scroll a window rectangle */
  mt_window_invalidate,		/* invalidate a window rectangle */
  mt_window_set_grid,		/* set a window's resizing grid */
  mt_window_activate,		/* activate a window (get the focus) */
  mt_window_pos_request,	/* request position of window's frame */
  mt_window_pos_reply,
  mt_window_set_pos,		/* set position of window's frame */
  mt_window_size_request,	/* request size of window's client area */
  mt_window_size_reply,
  mt_window_frame_size_request,	/* request size of window's frame */
  mt_window_frame_size_reply,
  mt_window_set_size,		/* set size of window's client area */
  mt_window_focusp_request,	/* request focus state of window */
  mt_window_focusp_reply,
  mt_window_set_state,		/* raise/lower/hide/min/max/restore window */
  mt_window_set_title,		/* set title-bar text */

  /* These are also PM thread commands, but they operate on
     presentation spaces rather than on windows.  */
  mt_bitmap_ps_open_request,	/* open a bitmap PS */
  mt_bitmap_ps_open_reply,
  mt_bitmap_ps_close,		/* close a bitmap PS */
  mt_ps_bitblt,			/* PS bitblt operation */
  mt_ps_write,			/* write chars in a PS */
  mt_ps_clear,			/* clear a PS rectangle */
  mt_ps_set_font_request,	/* change the text font in a PS */
  mt_ps_set_font_reply,
  mt_ps_set_colors,		/* set fg/bg colors of PS */
  mt_ps_move_gcursor,		/* move graphics cursor */
  mt_ps_line,			/* draw line from graphics cursor to point */
  mt_ps_poly_line,		/* draw multiple connected lines */
  mt_ps_poly_line_disjoint,	/* draw multiple disjoint lines */
  mt_ps_set_line_type,		/* set line type */
  mt_ps_query_caps,		/* query display capabilities */

  /* These are messages that are automatically generated by the PM
     thread when the corresponding events occur.  */
  mt_button_event,		/* mouse button press */
  mt_close_event,		/* window close (user command) */
  mt_focus_event,		/* window focus change */
  mt_key_event,			/* key press */
  mt_paint_event,		/* window needs painting */
  mt_resize_event,		/* window resized */
  mt_visibility_event,		/* window visibility change */

  /* This requests the thread on the other end of the connection to
     kill itself.  At present this request is not used.  */
  mt_kill_request,
  mt_supremum
} msg_type_t;
#define MSG_TYPE_SUP ((unsigned int) mt_supremum)
#define MSG_TYPE_MAX (MSG_TYPE_SUP - 1)

typedef unsigned char qid_t;
#define QID_MAX (UCHAR_MAX - 1)
#define QID_NONE UCHAR_MAX

typedef unsigned short msg_length_t;
#define MSG_LENGTH_MAX USHRT_MAX

/* Fields of message header:
   type: msg_type_t identifying the type of message
   sender: qid identifying the message sender (used for replies)
   */

#define DECLARE_MSG_HEADER_FIELDS					\
  msg_type_t type;							\
  qid_t sender

typedef struct
{
  DECLARE_MSG_HEADER_FIELDS;
} msg_t;

#define _MSG(m) ((msg_t *) (m))
#define MSG_TYPE(m) ((_MSG (m)) -> type)
#define MSG_SENDER(m) ((_MSG (m)) -> sender)

typedef enum
{
  tqt_std,
  tqt_scm,
  tqt_pm
} tqueue_type_t;

typedef struct
{
  tqueue_type_t type;
} tqueue_t;
#define TQUEUE_TYPE(q) (((tqueue_t *) (q)) -> type)

typedef msg_t * (* qid_receive_filter_t) (msg_t *);

typedef enum { mat_not_available, mat_available, mat_interrupt } msg_avail_t;

extern tqueue_t * OS2_scheme_tqueue;
extern qid_t OS2_interrupt_qid;
extern char OS2_scheme_tqueue_avail_map [QID_MAX + 1];

extern void OS2_make_qid_pair (qid_t *, qid_t *);
extern void OS2_open_qid (qid_t, tqueue_t *);
extern int OS2_qid_openp (qid_t);
extern void OS2_close_qid (qid_t);
extern qid_t OS2_qid_twin (qid_t);
extern void OS2_close_qid_pair (qid_t);
extern void OS2_set_qid_receive_filter (qid_t, qid_receive_filter_t);
extern msg_length_t OS2_message_type_length (msg_type_t);
extern void OS2_set_message_type_length (msg_type_t, msg_length_t);
extern msg_t * OS2_create_message_1 (msg_type_t, msg_length_t);
extern void OS2_destroy_message (msg_t *);
extern void OS2_send_message (qid_t, msg_t *);
extern msg_t * OS2_receive_message (qid_t, int, int);
extern msg_avail_t OS2_message_availablep (qid_t, int);
extern msg_t * OS2_wait_for_message (qid_t, msg_type_t);
extern msg_t * OS2_message_transaction (qid_t, msg_t *, msg_type_t);
extern void OS2_unread_message (qid_t, msg_t *);
extern int OS2_tqueue_select (tqueue_t *, int);
extern tqueue_t * OS2_make_std_tqueue (void);
extern void OS2_close_std_tqueue (tqueue_t *);

#define MSG_LENGTH(m) (OS2_message_type_length (MSG_TYPE (m)))

#define SET_MSG_TYPE_LENGTH(t, s)					\
  OS2_set_message_type_length ((t), (sizeof (s)))

#define OS2_create_message(type) OS2_create_message_1 ((type), 0)

typedef struct msg_list_s
{
  msg_t * message;
  struct msg_list_s * next;
} msg_list_t;

typedef struct
{
  DECLARE_MSG_HEADER_FIELDS;
  int code;
} sm_console_interrupt_t;
#define SM_CONSOLE_INTERRUPT_CODE(m) (((sm_console_interrupt_t *) (m)) -> code)

typedef msg_t sm_timer_event_t;
typedef msg_t sm_init_t;
typedef msg_t sm_generic_reply_t;

#endif /* SCM_OS2MSG_H */
