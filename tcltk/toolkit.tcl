#-----------------------------------------------------
# Magic/TCL general-purpose toolkit procedures
#-----------------------------------------------------
# Tim Edwards
# February 11, 2007
# Revision 0
#--------------------------------------------------------------
# Sets up the environment for a toolkit.  The toolkit must
# supply a namespace that is the "library name".  For each
# parameter-defined device ("gencell") type, the toolkit must
# supply three procedures:
#
# 1. ${library}::${gencell_type}_params {gname} {...}
# 2. ${library}::${gencell_type}_check  {gname} {...}
# 3. ${library}::${gencell_type}_draw   {gname} {...}
#
# The first defines the parameters used by the gencell, and
# declares default parameters to use when first generating
# the window that prompts for the device parameters prior to
# creating the device.  The second checks the parameters for
# legal values.  The third draws the device.
#
# If "library" is not specified then it defaults to "toolkit".
#--------------------------------------------------------------

# Initialize toolkit menus to the wrapper window

global Opts

#----------------------------------------------------------------
# Add a menu button to the Magic wrapper window for the toolkit
#----------------------------------------------------------------

proc magic::add_toolkit_menu {framename button_text {library toolkit}} {
   menubutton ${framename}.titlebar.mbuttons.${library} \
		-text $button_text \
		-relief raised \
		-menu ${framename}.titlebar.mbuttons.${library}.toolmenu \
		-borderwidth 2

   menu ${framename}.titlebar.mbuttons.${library}.toolmenu -tearoff 0
   pack ${framename}.titlebar.mbuttons.${library} -side left
}

#-----------------------------------------------------------------
# Add a menu item to the toolkit menu calling the default function
#-----------------------------------------------------------------

proc magic::add_toolkit_button {framename button_text gencell_type \
		{library toolkit}} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add command -label "$button_text" -command \
	"magic::gencell_params {} $gencell_type $library"
}

#----------------------------------------------------------------
# Add a menu item to the toolkit menu that calls the provided
# function
#----------------------------------------------------------------

proc magic::add_toolkit_command {framename button_text \
		command {library toolkit}} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add command -label "$button_text" -command $command
}

#----------------------------------------------------------------
# Add a separator to the toolkit menu
#----------------------------------------------------------------

proc magic::add_toolkit_separator {framename {library toolkit}} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add separator
}

#-----------------------------------------------------
# Device selection
#-----------------------------------------------------

proc magic::gen_params {} {
    
    # Find selected item  (to-do:  handle multiple selections)
    set wlist [what -list]
    set clist [lindex $wlist 2]
    set ccell [lindex $clist 0]
    set cdef [lindex $ccell 1]
    if {[regexp {^(.*_[0-9]*)$} $cdef valid gname] != 0} {
       set library [cellname property $gname library]
       if {$library == {}} {
	  error "Gencell has no associated library!"
       } else {
          regexp {^(.*)_[0-9]*$} $cdef valid gencell_type
	  magic::gencell_params $gname $gencell_type $library
       }
    } else {
       # Error message
       error "No gencell device is selected!"
    }
}

#-----------------------------------------------------
# Add "Ctrl-P" key callback for device selection
#-----------------------------------------------------

magic::macro ^P magic::gen_params

#-------------------------------------------------------------
# gencell_setparams
#
#   Go through the parameter window and collect all of the
#   named parameters and their values, and generate the
#   associated properties in celldef "$gname".
#-------------------------------------------------------------

proc magic::gencell_setparams {gname} {
   set slist [grid slaves .params.edits]
   foreach s $slist {
      if {[regexp {^.params.edits.(.*)_ent$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
         cellname property $gname $pname $value
      } elseif {[regexp {^.params.edits.(.*)_chk$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
         cellname property $gname $pname $value
      } elseif {[regexp {^.params.edits.(.*)_sel$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
         cellname property $gname $pname $value
      }
   }
}

#-------------------------------------------------------------
# gencell_getparam
#
#   Go through the parameter window, find the named parameter,
#   and return its value.
#-------------------------------------------------------------

proc magic::gencell_getparam {gname pname} {
   set slist [grid slaves .params.edits]
   foreach s $slist {
      if {[regexp {^.params.edits.(.*)_ent$} $s valid ptest] != 0} {
	 if {$pname == $ptest} {
	    return [subst \$magic::${ptest}_val]
	 }
      } elseif {[regexp {^.params.edits.(.*)_chk$} $s valid ptest] != 0} {
	 if {$pname == $ptest} {
	    return [subst \$magic::${ptest}_val]
	 }
      } elseif {[regexp {^.params.edits.(.*)_sel$} $s valid pname] != 0} {
	 if {$pname == $ptest} {
	    return [subst \$magic::${ptest}_val]
	 }
      }
   }
}

#-------------------------------------------------------------
# gencell_change
#
#   Redraw a gencell with new parameters.
#-------------------------------------------------------------

proc magic::gencell_change {gname gencell_type library} {
    if {[cellname list exists $gname] != 0} {
	if {[eval "${library}::${gencell_type}_check $gname"]} {
	    suspendall
	    pushstack $gname
	    select cell
	    erase *
	    magic::gencell_draw $gname $gencell_type $library
	    popstack
	    resumeall
	} else {
	    error "Parameter out of range!"
	}
    } else {
	error "Cell $gname does not exist!"
    }
}

#-------------------------------------------------------------
# gencell_create
#
#   Instantiate a new gencell called $gname.  If $gname
#   does not already exist, create it by calling its
#   drawing routine.
#
#   Don't rely on pushbox/popbox since we don't know what
#   the drawing routine is going to do to the stack!
#-------------------------------------------------------------

proc magic::gencell_create {gname gencell_type library} {
    suspendall
    if {[cellname list exists $gname] == 0} {
	cellname create $gname
	set snaptype [snap list]
	snap internal
	set savebox [box values]
	pushstack $gname
	magic::gencell_draw $gname $gencell_type $library
	popstack
	eval "box values $savebox"
	snap $snaptype
    }
    getcell $gname
    expand
    resumeall
}

#-------------------------------------------------------------
#-------------------------------------------------------------

proc magic::gencell_check {gname gencell_type library} {
    return [eval "${library}::${gencell_type}_check $gname"]
}

#-------------------------------------------------------------
#-------------------------------------------------------------

proc magic::gencell_draw {gname gencell_type library} {

   # Set the parameters passed from the window text entries
   magic::gencell_setparams $gname

   # Call the draw routine
   eval "${library}::${gencell_type}_draw $gname"

   # Find the namespace of the draw procedure and set propery "library"
   cellname property $gname library $library
}

#-----------------------------------------------------
#  Add a standard entry parameter to the gencell window 
#-----------------------------------------------------

proc magic::add_param {gname pname ptext default_value} {

   # Check if the parameter exists.  If so, override the default
   # value with the current value.

   set value {}
   if {[cellname list exists $gname] != 0} {
      set value [cellname property $gname $pname]
   }
   if {$value == {}} {set value $default_value}
   
   set numrows [lindex [grid size .params.edits] 1]
   label .params.edits.${pname}_lab -text $ptext -textvariable magic::${pname}_val
   entry .params.edits.${pname}_ent -background white
   grid .params.edits.${pname}_lab -row $numrows -column 0 -sticky ens
   grid .params.edits.${pname}_ent -row $numrows -column 1 -sticky ewns
   .params.edits.${pname}_ent insert end $value
   set magic::${pname}_val $value
}

#----------------------------------------------------------
#  Add a standard checkbox parameter to the gencell window 
#----------------------------------------------------------

proc magic::add_checkbox {gname pname ptext default_value} {

   # Check if the parameter exists.  If so, override the default
   # value with the current value.

   set value {}
   if {[cellname list exists $gname] != 0} {
      set value [cellname property $gname $pname]
   }
   if {$value == {}} {set value $default_value}
   
   set numrows [lindex [grid size .params.edits] 1]
   label .params.edits.${pname}_lab -text $ptext
   checkbutton .params.edits.${pname}_chk -variable magic::${pname}_val
   grid .params.edits.${pname}_lab -row $numrows -column 0 -sticky ens
   grid .params.edits.${pname}_chk -row $numrows -column 1 -sticky wns
   set magic::${pname}_val $value
}

#----------------------------------------------------------
#  Add a selectable-list parameter to the gencell window 
#----------------------------------------------------------

proc magic::add_selectlist {gname pname ptext all_values default_value} {

   # Check if the parameter exists.  If so, override the default
   # value with the current value.

   set value {}
   if {[cellname list exists $gname] != 0} {
      set value [cellname property $gname $pname]
   }
   if {$value == {}} {set value $default_value}
   
   set numrows [lindex [grid size .params.edits] 1]
   label .params.edits.${pname}_lab -text $ptext
   menubutton .params.edits.${pname}_sel -menu .params.edits.${pname}_sel.menu \
		-relief groove -text ${value} 
   grid .params.edits.${pname}_lab -row $numrows -column 0 -sticky ens
   grid .params.edits.${pname}_sel -row $numrows -column 1 -sticky wns
   menu .params.edits.${pname}_sel.menu -tearoff 0
   foreach item ${all_values} {
       .params.edits.${pname}_sel.menu add radio -label $item \
	-variable magic::${pname}_val -value $item \
	-command ".params.edits.${pname}_sel configure -text $item"
   }
   set magic::${pname}_val $value
}

#-----------------------------------------------------
# Update the properties of a cell 
#-----------------------------------------------------

proc magic::update_params {gname ptext default_value} {
}

#-------------------------------------------------------------
# gencell_params ---
# 1) If gname is NULL and gencell_type is set, then we
#    create a new cell of type gencell_type.
# 2) If gname is non-NULL, then we edit the existing
#    cell of type $gname.
# 3) If gname is non-NULL and gencell_type or library
#    is NULL or unspecified, then we derive the gencell_type
#    and library from the existing cell's property strings
#-------------------------------------------------------------

proc magic::gencell_params {gname {gencell_type {}} {library {}}} {

   if {$gname == {}} {
      set pidx 1
      while {[cellname list exists ${gencell_type}_$pidx] != 0} {
	  incr pidx
      }
      set gname ${gencell_type}_$pidx

      set ttext "New device"
      set btext "Create"
      set bcmd "magic::gencell_create $gname $gencell_type $library"
   } else {
      if {$gencell_type == {}} {
	 set gencell_type [cellname property ${gname} gencell]
      }
      if {$library == {}} {
	 set library [cellname property ${gname} library]
      }

      set ttext "Edit device"
      set btext "Apply"
      set bcmd "magic::gencell_change $gname $gencell_type $library"
   }

   catch {destroy .params}
   toplevel .params
   label .params.title -text "$ttext $gname"
   frame .params.edits
   frame .params.buttons
   pack .params.title
   pack .params.edits
   pack .params.buttons

   button .params.buttons.apply \
	-text "$btext" \
	-command [subst { $bcmd ; \
	.params.buttons.apply configure -text Apply}]
   button .params.buttons.close -text "Close" -command {destroy .params}

   pack .params.buttons.apply -padx 10 -side left
   pack .params.buttons.close -padx 10 -side right

   # Invoke the callback procedure that creates the parameter entries

   eval "${library}::${gencell_type}_params $gname"
}

#-------------------------------------------------------------
