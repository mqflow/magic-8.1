#!/usr/bin/wish
#
# A Tcl shell in a text widget
# Brent Welch, from "Practical Programming in Tcl and Tk"
#

package provide tkshell 1.0

# "namespace eval" is needed to force the creation of the namespace,
# even if it doesn't actually evaluate anything.  Otherwise, the use
# of "proc tkshell::..." generates an undefined namespace error.

namespace eval tkshell {}

#-----------------------------------------------
# Create a simple text widget with a Y scrollbar
#-----------------------------------------------

proc tkshell::YScrolled_Text { f args } {
	frame $f
	eval {text $f.text -wrap none \
		-yscrollcommand [list $f.yscroll set]} $args
	scrollbar $f.yscroll -orient vertical \
		-command [list $f.text yview]
	grid $f.text $f.yscroll -sticky news
	grid rowconfigure $f 0 -weight 1
	grid columnconfigure $f 0 -weight 1
	return $f.text
}

#---------------------------------------------------------
# Create the shell window in Tk
#---------------------------------------------------------

proc tkshell::MakeEvaluator { {t .eval} {prompt "tcl>"} {prefix ""}} {

  # Text tags give script output, command errors, command
  # results, and the prompt a different appearance

  $t tag configure prompt -foreground brown3
  $t tag configure result -foreground purple
  $t tag configure stderr -foreground red
  $t tag configure stdout -foreground blue

  # Insert the prompt and initialize the limit mark

  $t insert insert "${prompt} " prompt
  $t mark set limit insert
  $t mark gravity limit left

  # Key bindings that limit input and eval things. The break in
  # the bindings skips the default Text binding for the event.

  bind $t <Return> "tkshell::EvalTypein $t $prefix $prompt; break"
  bind $t <BackSpace> {
	if {[%W tag nextrange sel 1.0 end] != ""} {
		%W delete sel.first sel.last
	} elseif {[%W compare insert > limit]} {
		%W delete insert-1c
		%W see insert
	}
	break
  }
  bind $t <Key> {
	if [%W compare insert < limit] {
		%W mark set insert end
	}
  }
}

#-----------------------------------------------------------
# Evaluate everything between limit and end as a Tcl command
#-----------------------------------------------------------

proc tkshell::EvalTypein {t prefix prompt} {
	$t insert insert \n
	set command [$t get limit end]
	if [info complete $command] {
		$t mark set limit insert
		tkshell::Eval $t $prefix $prompt $command
	}
}

#-----------------------------------------------------------
# Evaluate a command and display its result
#-----------------------------------------------------------

proc tkshell::Eval {t prefix prompt command} {
	$t mark set insert end
	set fullcommand "${prefix} "
	append fullcommand $command
	if [catch {eval $fullcommand} result] {
		$t insert insert $result error
	} else {
		$t insert insert $result result
	}
	if {[$t compare insert != "insert linestart"]} {
		$t insert insert \n
	}
	$t insert insert "${prompt} " prompt
	$t see insert
	$t mark set limit insert
	return
}

#--------------------------------------------------------------
# This "puts" alias puts stdout and stderr into the text widget
#--------------------------------------------------------------

proc tkshell::PutsTkShell {t args} {
	if {[llength $args] > 3} {
		error "invalid arguments"
	}
	set newline "\n"
	if {[string match "-nonewline" [lindex $args 0]]} {
		set newline ""
		set args [lreplace $args 0 0]
	}
	if {[llength $args] == 1} {
		set chan stdout
		set string [lindex $args 0]$newline
	} else {
		set chan [lindex $args 0]
		set string [lindex $args 1]$newline
	}
	if [regexp (stdout|stderr) $chan] {
		${t}.text mark gravity limit right
		${t}.text insert limit $string $chan
		${t}.text see limit
		${t}.text mark gravity limit left
	} else {
		puts -nonewline $chan $string
	}
}

#--------------------------------------------------------------
# A few lines is all that's needed to run this thing.
#--------------------------------------------------------------
# tkshell::YScrolled_Text .eval -width 90 -height 5
# pack .eval -fill both -expand true
# tkshell::MakeEvaluator .eval.text "magic> "
#--------------------------------------------------------------
