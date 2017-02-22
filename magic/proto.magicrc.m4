#	$(CAD_ROOT)/magic/sys/.magicrc 
# 	System wide start up file for magic, defines default macros.
#
#	rcsid $Header: /usr/cvsroot/magic-8.0/magic/proto.magicrc.m4,v 1.4 2008/12/11 04:20:09 tim Exp $
#
dnl
dnl	Source file proto.magicrc.m4
dnl	Process this file with the m4 macro processor
dnl
changequote([,])dnl
ifdef([MAGIC_WRAPPER],[dnl
puts stdout "Processing system .magicrc file"
])dnl (MAGIC_WRAPPER)
ifelse(USE_NEW_MACROS,1,[dnl
###############################################################################
#  Default .magicrc macro file (new macros)
###############################################################################
# A key
macro a "select visible"
macro A "select more visible"
macro ^A "select less visible"
# B key
macro b "box"
macro B "findbox"
# C key
macro c "copy"
# D key
macro d "delete"
macro ^D "erase $"
# E key
macro e "edit"
# F key
macro f "sideways"
macro F "upsidedown"
# G key
macro g "grid"
macro G "grid 2"
# I key
macro i "select cell"
macro I "select more cell"
ifdef([XLIB],[macro Control_XK_i "select less cell"],[dnl])
# L key
ifdef([USE_READLINE],[imacro l "label "],[dnl])
ifdef([MAGIC_WRAPPER],[imacro l "label "],[dnl])
macro L "shell ls"
macro ^L "redraw"
# M key
macro m "move"
macro M "stretch"
# N key
macro ^N ""
# O key
macro o "openwindow"
macro O "closewindow"
# P key
ifdef([USE_READLINE],[imacro p "paint "],[dnl])
ifdef([MAGIC_WRAPPER],[imacro p "paint "],[dnl])
# Q key
ifdef([XLIB],[macro Control_Shift_XK_q "quit"],[dnl])
# R key
macro r "clockwise"
macro R "clockwise 270"
macro ^R "clockwise 180"
# S key
macro s "select"
macro S "select more"
macro ^S "select less"
ifdef([XLIB],[macro Control_Shift_XK_s "undo ; select"],[dnl])
# U key
macro u "undo"
macro U "redo"
# V key
macro v "view"
macro V "xview"
# W key
macro w "writeall"
macro W "writeall force"
# X key
macro x "expand"
macro X "unexpand"
macro ^X "expand toggle"
# Z key
macro z "zoom .5"
macro Z "zoom 2"
macro ^Z "findbox zoom"
ifdef([XLIB],[macro Control_Shift_XK_z "center"],[dnl])
# Question mark
macro ? "drc why"
macro / "select area; what ; select clear"
# Comma key
macro , "select clear"
# Exclamation mark
ifdef([USE_READLINE],[imacro ! "shell "],[dnl])
# Space bar
macro " " "tool"
# Colon and semicolon (interactive command)
imacro XK_colon ":"
imacro XK_semicolon ":"
ifdef([XLIB],[dnl
macro Shift_XK_space "tool box"
macro Control_XK_space "tool wiring"
# Arrow keys (X11 versions only)
macro XK_Left "scroll l .1 w"
macro Shift_XK_Left "scroll l 1 w"
macro Control_XK_Left "box grow w 1"
macro Control_Shift_XK_Left "box shrink e 1"
macro XK_Right "scroll r .1 w"
macro Shift_XK_Right "scroll r 1 w"
macro Control_XK_Right "box grow e 1"
macro Control_Shift_XK_Right "box shrink w 1"
macro XK_Up "scroll u .1 w"
macro Shift_XK_Up "scroll u 1 w"
macro Control_XK_Up "box grow n 1"
macro Control_Shift_XK_Up "box shrink s 1"
macro XK_Down "scroll d .1 w"
macro Shift_XK_Down "scroll d 1 w"
macro Control_XK_Down "box grow s 1"
macro Control_Shift_XK_Down "box shrink n 1"
# Keypad keys (X11 versions only)
# Functions duplicated for use both with Num_Lock ON and OFF
macro XK_KP_Delete "box size 0 0"
macro XK_KP_Insert "box size 4 4"
macro XK_KP_0 "box size 7 2"
macro Shift_XK_KP_0 "box size 7 2"
macro XK_0 "box size 7 2"
macro Control_XK_KP_0 "box size 2 7"
macro Control_XK_KP_Insert "box size 2 7"
macro XK_KP_End "move sw 1"
macro XK_KP_Down "move d 1"
macro XK_KP_2 "stretch d 1"
macro Shift_XK_KP_2 "stretch d 1"
macro XK_2 "stretch d 1"
macro XK_KP_Next "move se 1"
macro XK_KP_Left "move l 1"
macro XK_KP_4 "stretch l 1"
macro Shift_XK_KP_4 "stretch l 1"
macro XK_4 "stretch l 1"
macro XK_KP_Begin "findbox zoom"
macro XK_KP_5 "findbox"
macro Shift_XK_KP_5 "findbox"
macro XK_5 "findbox"
macro XK_KP_Right "move r 1"
macro XK_KP_6 "stretch r 1"
macro Shift_XK_KP_6 "stretch r 1"
macro XK_6 "stretch r 1"
macro XK_KP_Home "move nw 1"
macro XK_KP_Up "move u 1"
macro XK_KP_8 "stretch u 1"
macro Shift_XK_KP_8 "stretch u 1"
macro XK_8 "stretch u 1"
macro XK_KP_Prior "move ne 1"
# Scroll wheel bindings
macro XK_Pointer_Button4 "scroll u .05 w"
macro XK_Pointer_Button5 "scroll d .05 w"
# Quick macro function keys for scmos tech (X11 versions only)
macro XK_F1  "paint ndiff"
macro XK_F2  "paint pdiff"
macro XK_F3  "paint poly"
macro XK_F4  "paint poly2"
macro XK_F5  "paint m1"
macro XK_F6  "paint m2"
macro XK_F7  "paint m3"
macro XK_F8  "paint m4"
macro XK_F9  "paint ndc"
macro XK_F10 "paint pdc"
macro XK_F11 "paint pc"
macro XK_F12 "paint via"
])dnl  (ifdef XLIB)
],[dnl (else !USE_NEW_MACROS)
###############################################################################
#  Default .magicrc macro file (original)
###############################################################################
echo ""
macro s "select"
macro S "select more"
macro a "select area"
macro A "select more area"
macro f "select cell"
macro C "select clear"
macro d "delete"
macro ^D "erase $"
macro t "move"
macro T "stretch"
macro c "copy"
macro ^X "expand toggle"
macro x "expand"
macro X "unexpand"
macro q "move left 1"
macro w "move down 1"
macro e "move up 1"
macro r "move right 1"
macro Q "stretch left 1"
macro W "stretch down 1"
macro E "stretch up 1"
macro R "stretch right 1"
macro g "gridspace"
macro G "gridspace 2"
macro u "undo"
macro U "redo"
macro v "view"
macro z "findbox zoom"
macro Z "zoom 2"
macro b "box"
macro B "findbox"
macro , "center"
macro y "drc why"
macro ^L "redraw"
macro y "drc why"
macro ? "help"
macro o "openwindow"
macro O "closewindow"
macro " " "tool"
imacro XK_colon ":"
imacro XK_semicolon ":"
macro ^R "iroute route -dBox"
macro ^N "iroute route -dSelection"
])dnl	(ifdef USE_NEW_MACROS)
# Allow some box manipulation from all tools.
ifdef([MAGIC_WRAPPER],[
macro Control_Button1 "*bypass box move bl cursor"
macro Control_Button2 "*bypass paint cursor"
macro Control_Button3 "*bypass box corner ur cursor"
# Box tool button bindings
macro Button1 "*bypass box move bl cursor"
macro Shift_Button1 "*bypass box corner bl cursor"
macro Button2 "*bypass paint cursor"
macro Shift_Button2 "*bypass erase cursor"
macro Button3 "*bypass box corner ur cursor"
macro Shift_Button3 "*bypass box move ur cursor"
],[
macro Control_Button1 "box move bl cursor"
macro Control_Button2 "paint cursor"
macro Control_Button3 "box corner ur cursor"
# Box tool button bindings
macro Button1 "box move bl cursor"
macro Shift_Button1 "box corner bl cursor"
macro Button2 "paint cursor"
macro Shift_Button2 "erase cursor"
macro Button3 "box corner ur cursor"
macro Shift_Button3 "box move ur cursor"
])
# Color window button bindings
macro color Button1 "pushbutton left"
macro color Button2 "pushbutton middle"
macro color Button3 "pushbutton right"
macro color u "undo"
macro color U "redo"
macro color plus "color next"
macro color minus "color last"
# Netlist window button bindings
macro netlist Button1 "pushbutton left"
macro netlist Button2 "pushbutton middle"
macro netlist Button3 "pushbutton right"
# Wind3D window key bindings
macro wind3d  L "level up"
macro wind3d  l "level down"
macro wind3d  C "cif"
macro wind3d  " " "defaults"
macro wind3d  ^L "refresh"
macro wind3d  Z "zoom 2.0 1 rel"
macro wind3d  z "zoom 0.5 1 rel"
macro wind3d  1 "view 0 10 0 rel"
macro wind3d  2 "view 0 -10 0 rel"
macro wind3d  3 "view 10 0 0 rel"
macro wind3d  4 "view -10 0 0 rel"
macro wind3d  5 "view 0 0 10 rel"
macro wind3d  6 "view 0 0 -10 rel"
macro wind3d  7 "view 0 1 0 rel"
macro wind3d  8 "view 0 -1 0 rel"
macro wind3d  9 "view 1 0 0 rel"
macro wind3d  0 "view -1 0 0 rel"
ifdef([XLIB],[dnl
macro wind3d  XK_Up "scroll 0 -0.25 0 rel"
macro wind3d  XK_Down "scroll 0 0.25 0 rel"
macro wind3d  XK_Left "scroll 0.25 0 0 rel"
macro wind3d  XK_Right "scroll -0.25 0 0 rel"
macro wind3d  XK_minus "view 0 0 1 rel"
macro wind3d  XK_equal "view 0 0 -1 rel"
macro wind3d  XK_greater "zoom 1 2.0 rel"
macro wind3d  XK_less "zoom 1 0.5 rel"
])dnl  (ifdef XLIB)
#
# Load basic set of fonts
#
setlabel font FreeSans.pt3 0.58
setlabel font FreeSerif.pt3 0.58
setlabel font FreeMono.pt3 0.6
#
# Additions for Tcl GUI wrapper
#
changequote(<,>)dnl
ifelse(MAGIC_WRAPPER,1,<dnl
magic::suspendout
if {![catch {set Opts(tools)}]} { magic::enable_tools }
set GND "gnd!"
set VDD "vdd!"
magic::resumeout
catch {source ${CAD_ROOT}/magic/sys/site.def}
>,<dnl
>)dnl (MAGIC_WRAPPER)
changequote([,])dnl
#
ifdef([SCHEME_INTERPRETER],[dnl
#
# additions for default scm path
#
define scm-library-path "CAD_DIR/lib/magic/scm"
load-scm "default.scm"
load-scm "layout.scm"
])dnl (SCHEME_INTERPRETER)
