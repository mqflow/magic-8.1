#-----------------------------------------------------
# Magic/TCL general-purpose toolkit procedures
#-----------------------------------------------------
# Tim Edwards
# February 11, 2007
# Revision 0
# December 15, 2016
# Revision 1
#--------------------------------------------------------------
# Sets up the environment for a toolkit.  The toolkit must
# supply a namespace that is the "library name".  For each
# parameter-defined device ("gencell") type, the toolkit must
# supply four procedures:
#
# 1. ${library}::${gencell_type}_defaults {}
# 2. ${library}::${gencell_type}_dialog   {parameters}
# 3. ${library}::${gencell_type}_check    {parameters}
# 4. ${library}::${gencell_type}_draw     {parameters}
#
# The first defines the parameters used by the gencell, and
# declares default parameters to use when first generating
# the window that prompts for the device parameters prior to
# creating the device.  The second builds the dialog window
# for entering device parameters.  The third checks the
# parameters for legal values.  The fourth draws the device.
#
# If "library" is not specified then it defaults to "toolkit".
# Otherwise, where specified, the name "gencell_fullname"
# is equivalent to "${library}::${gencell_type}"
#
# Each gencell is defined by cell properties as created by
# the "cellname property" command.  Specific properties used
# by the toolkit are:
#
# library    --- name of library (see above, default "toolkit")
# gencell    --- base name of gencell (gencell_type, above)
# parameters --- list of gencell parameter-value pairs
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
		{library toolkit} args} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add command -label "$button_text" -command \
	"magic::gencell $library::$gencell_type {} $args"
}

#----------------------------------------------------------------
# Add a menu item to the toolkit menu that calls the provided
# function
#----------------------------------------------------------------

proc magic::add_toolkit_command {framename button_text \
		command {library toolkit} args} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add command -label "$button_text" -command "$command $args"
}

#----------------------------------------------------------------
# Add a separator to the toolkit menu
#----------------------------------------------------------------

proc magic::add_toolkit_separator {framename {library toolkit}} {
   set m ${framename}.titlebar.mbuttons.${library}.toolmenu
   $m add separator
}

#-----------------------------------------------------
# Add "Ctrl-P" key callback for device selection
#-----------------------------------------------------

magic::macro ^P "magic::gencell {}"

#-------------------------------------------------------------
# gencell
#
#   Main routine to call a cell from either a menu button or
#   from a script or command line.  The name of the device
#   is required, followed by the name of the instance, followed
#   by an optional list of parameters.  Handling depends on
#   instance and args:
#
#   gencell_name is either the name of an instance or the name
#   of the gencell in the form <library>::<device>.
#
#   name        args      action
#-----------------------------------------------------------------
#   none        empty     interactive, new device w/defaults
#   none        specified interactive, new device w/parameters
#   instance    empty     interactive, edit device
#   instance    specified non-interactive, change device
#   device      empty     non-interactive, new device w/defaults
#   device	specified non-interactive, new device w/parameters
#
#-------------------------------------------------------------
# Also, if instance is empty and gencell_name is not specified,
# and if a device is selected in the layout, then gencell
# behaves like line 3 above (instance exists, args is empty).
# Note that macro Ctrl-P calls gencell this way.  If gencell_name
# is not specified and nothing is selected, then gencell{}
# does nothing.
#-------------------------------------------------------------

proc magic::gencell {gencell_name {instance {}} args} {

    set argpar [dict create {*}$args]
    if {$gencell_name == {}} { 
	# Find selected item  (to-do:  handle multiple selections)

	set wlist [what -list]
	set clist [lindex $wlist 2]
	set ccell [lindex $clist 0]
	set ginst [lindex $ccell 0]
	set gname [lindex $ccell 1]
	set library [cellname list property $gname library]
	if {$library == {}} {
	    set library toolkit
        }
	set gencell_type [cellname list property $gname gencell]
	if {$gencell_type == {}} {
	   if {![regexp {^(.*)_[0-9]*$} $gname valid gencell_type]} {
	      # Error message
	      error "No gencell device is selected!"
	   }
	}
        # need to incorporate argpar?
        set parameters [cellname list property $gname parameters]
	
	# if "nocell" is set in parameters, then overwrite additional
        # parameters from the instance.  Reserved parameters names are
	# nx, ny, pitchx, and pitchy
	if {[dict exists $parameters nocell]} {
	    set arcount [array -list count]
	    set arpitch [array -list pitch]

	    dict set parameters nx [expr [lindex $arcount 1] - [lindex $arcount 0] + 1]
	    dict set parameters ny [expr [lindex $arcount 3] - [lindex $arcount 2] + 1]
	    dict set parameters pitchx [lindex $arpitch 0]
	    dict set parameters pitchy [lindex $arpitch 1]
	}
	magic::gencell_dialog $ginst $gencell_type $library $parameters
    } else {
	# Parse out library name from gencell_name, otherwise default
	# library is assumed to be "toolkit".
	if {[regexp {^([^:]+)::([^:]+)$} $gencell_name valid library gencell_type] \
			== 0} {
	    set library "toolkit"
	    set gencell_type $gencell_name
	}

	if {$instance == {}} {
	    # Case:  Interactive, new device with parameters in args (if any)
	    set parameters [magic::gencell_defaults $gencell_type $library $argpar]
	    magic::gencell_dialog {} $gencell_type $library $parameters
	} else {
	    # Check if instance exists or not
	    if {[instance list exists $instance] != ""} {
		# Case:  Change existing instance, parameters in args (if any)
		set cellname [instance list celldef $instance]
		set parameters [cellname list property $gname parameters]
		if {[dict exists $parameters nocell]} {
		    set arcount [array -list count]
		    set arpitch [array -list pitch]
	
		    dict set parameters nx [lindex $arcount 1]
		    dict set parameters ny [lindex $arcount 3]
		    dict set parameters pitchx $delx
		    dict set parameters pitchy $dely
		}
		if {[dict size $argpar] == 0} {
		    # No changes entered on the command line, so start dialog
		    magic::gencell_dialog $instance $gencell_type $library $parameters
		} else {
		    # Apply specified changes without invoking the dialog
		    set parameters [dict merge $parameters $argpar]
		    magic::gencell_change $instance $gencell_type $library $parameters
		}
	    } else {
		# Case:  Non-interactive, create new device with parameters
		# in args (if any)
	        set parameters [magic::gencell_defaults $gencell_type $library $argpar]
		set inst_defaultname [magic::gencell_create \
				$gencell_type $library $parameters]
		select cell $inst_defaultname
		identify $instance
	    }
	}
    }
}

#-------------------------------------------------------------
# gencell_getparams
#
#   Go through the parameter window and collect all of the
#   named parameters and their values.  Return the result as
#   a dictionary.
#-------------------------------------------------------------

proc magic::gencell_getparams {} {
   set parameters [dict create]
   set slist [grid slaves .params.edits]
   foreach s $slist {
      if {[regexp {^.params.edits.(.*)_ent$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
      } elseif {[regexp {^.params.edits.(.*)_chk$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
      } elseif {[regexp {^.params.edits.(.*)_sel$} $s valid pname] != 0} {
	 set value [subst \$magic::${pname}_val]
      }
      dict set parameters $pname $value
   }
   return $parameters
}

#-------------------------------------------------------------
# gencell_setparams
#
#   Fill in values in the dialog from a set of parameters
#-------------------------------------------------------------

proc magic::gencell_setparams {parameters} {
   set slist [grid slaves .params.edits]
   foreach s $slist {
      if {[regexp {^.params.edits.(.*)_ent$} $s valid pname] != 0} {
	 set value [dict get $parameters $pname]
         set magic::${pname}_val $value
      } elseif {[regexp {^.params.edits.(.*)_chk$} $s valid pname] != 0} {
	 set value [dict get $parameters $pname]
         set magic::${pname}_val $value
      } elseif {[regexp {^.params.edits.(.*)_sel$} $s valid pname] != 0} {
	 set value [dict get $parameters $pname]
         set magic::${pname}_val $value
      }
   }
}

#-------------------------------------------------------------
# gencell_change
#
#   Redraw a gencell with new parameters.
#-------------------------------------------------------------

proc magic::gencell_change {instance gencell_type library parameters} {
    suspendall

    if {$parameters == {}} {
        # Get device defaults
	set pdefaults [eval "${library}::${gencell_type}_defaults"]
        # Pull user-entered values from dialog
        set parameters [dict merge $pdefaults [magic::gencell_getparams]]
    }
    eval "${library}::${gencell_type}_check \$parameters"

    set snaptype [snap list]
    snap internal
    set savebox [box values]

    set gname [instance list celldef $instance]
    if [dict exists $parameters nocell] {
        select cell $instance
	delete
	set newinst [eval "${library}::${gencell_type}_draw \$parameters"]
	pushstack $gname
	property parameters $parameters
	popstack
        select cell $newinst
	identify $instance
    } else {
	pushstack $gname
	select cell
	tech unlock *
	erase *
	eval "${library}::${gencell_type}_draw \$parameters"
	property parameters $parameters
	tech revert
	popstack
    }
    eval "box values $savebox"
    snap $snaptype
    resumeall
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

proc magic::gencell_create {gencell_type library parameters} {
    suspendall

    # Get device defaults
    set pdefaults [eval "${library}::${gencell_type}_defaults"]
    if {$parameters == {}} {
        # Pull user-entered values from dialog
        set parameters [dict merge $pdefaults [magic::gencell_getparams]]
    } else {
        set parameters [dict merge $pdefaults $parameters]
    }

    eval "${library}::${gencell_type}_check \$parameters"

    set snaptype [snap list]
    snap internal
    set savebox [box values]

    if [dict exists $parameters nocell] {
	set instname [eval "${library}::${gencell_type}_draw \$parameters"]
	set gname [instance list celldef $instname]
	pushstack $gname
	property library $library 
	property gencell $gencell_type
	property parameters $parameters
	popstack
	eval "box values $savebox"
    } else {
	# Give cell a unique name
	set pidx 1
	while {[cellname list exists ${gencell_type}_$pidx] != 0} {
	    incr pidx
	}
        set gname ${gencell_type}_$pidx
	cellname create $gname
	pushstack $gname
	eval "${library}::${gencell_type}_draw \$parameters"
	property library $library 
	property gencell $gencell_type
	property parameters $parameters
	popstack
	eval "box values $savebox"
	set instname [getcell $gname]
	expand
    }
    snap $snaptype
    resumeall
    return $instname
}

#-----------------------------------------------------
#  Add a standard entry parameter to the gencell window 
#-----------------------------------------------------

proc magic::add_entry {pname ptext parameters} {

   if [dict exists $parameters $pname] {
        set value [dict get $parameters $pname]
   } else {
       set value ""
   }
   
   set numrows [lindex [grid size .params.edits] 1]
   label .params.edits.${pname}_lab -text $ptext
   entry .params.edits.${pname}_ent -background white -textvariable magic::${pname}_val
   grid .params.edits.${pname}_lab -row $numrows -column 0 -sticky ens
   grid .params.edits.${pname}_ent -row $numrows -column 1 -sticky ewns
   .params.edits.${pname}_ent insert end $value
   set magic::${pname}_val $value
}

#----------------------------------------------------------
# Add a dependency between entries.  When one updates, the
# others will be recomputed according to the callback
# function.
#
# The callback function is passed the value of all
# parameters for the device, overridden by the values
# in the dialog.  The routine computes the dependent
# values and writes them back to the parameter dictionary.
#----------------------------------------------------------

proc magic::add_dependency {callback gencell_type library args} {
    foreach pname $args {
	# Add callback on enter or focus out
	bind .params.edits.${pname}_ent <Return> \
		"magic::update_dialog $callback $pname $gencell_type $library"
    }
}

#----------------------------------------------------------
# Execute callback procedure
#----------------------------------------------------------

proc magic::update_dialog {callback pname gencell_type library} {
    set pdefaults [eval "${library}::${gencell_type}_defaults"]
    set parameters [dict merge $pdefaults [magic::gencell_getparams]]
    $callback $pname $parameters
    magic::gencell_setparams $parameters
}

#----------------------------------------------------------
#  Add a standard checkbox parameter to the gencell window 
#----------------------------------------------------------

proc magic::add_checkbox {pname ptext parameters} {

   if [dict exists $parameters $pname] {
        set value [dict get $parameters $pname]
   } else {
       set value ""
   }
   
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

proc magic::add_selectlist {pname ptext all_values parameters} {

   if [dict exists $parameters $pname] {
        set value [dict get $parameters $pname]
   } else {
       set value ""
   }

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

#-------------------------------------------------------------
# gencell_defaults ---
#
# Set all parameters for a device.  Start by calling the base
# device's default value list to generate a dictionary.  Then
# parse all values passed in 'parameters', overriding any
# defaults with the passed values.
#-------------------------------------------------------------

proc magic::gencell_defaults {gencell_type library parameters} {
    set basedict [eval "${library}::${gencell_type}_defaults"]
    set newdict [dict merge $basedict $parameters]
    return $newdict
}

#-------------------------------------------------------------
# gencell_dialog ---
#
# Create the dialog window for entering device parameters.  The
# general procedure then calls the dialog setup for the specific
# device.
#
# 1) If gname is NULL and gencell_type is set, then we
#    create a new cell of type gencell_type.
# 2) If gname is non-NULL, then we edit the existing
#    cell of type $gname.
# 3) If gname is non-NULL and gencell_type or library
#    is NULL or unspecified, then we derive the gencell_type
#    and library from the existing cell's property strings
#
# The device setup should be built using the API that defines
# these procedures:
#
# magic::add_entry	 Single text entry window
# magic::add_checkbox    Single checkbox
# magic::add_selectlist  Pull-down menu with list of selections
#
#-------------------------------------------------------------

proc magic::gencell_dialog {instance gencell_type library parameters} {

   if {$parameters == {}} {
      # "Create" dialog changes to "Change" dialog with same parameters
      set pdefaults [eval "${library}::${gencell_type}_defaults"]
      # Pull user-entered values from dialog
      set parameters [dict merge $pdefaults [magic::gencell_getparams]]
   }

   if {$instance == {}} {
      set pidx 1
      while {[cellname list exists ${gencell_type}_$pidx] != 0} {
	  incr pidx
      }
      set parameters [magic::gencell_defaults $gencell_type $library $parameters]
      set ttext "New device"
   } else {
      set gname [instance list celldef $instance]
      if {$gencell_type == {}} {
	 set gencell_type [cellname list property $gname gencell]
      }
      if {$library == {}} {
	 set library [cellname list property $gname library]
      }
      if {$parameters == {}} {
	 set parameters [cellname list property $gname parameters]
      }
      if {$parameters == {}} {
	 set parameters [eval "${library}::${gencell_type}_defaults"]
      }
      set ttext "Edit device"
   }

   catch {destroy .params}
   toplevel .params
   label .params.title -text "$ttext \"$gencell_type\" library \"$library\""
   frame .params.edits
   frame .params.buttons
   pack .params.title
   pack .params.edits
   pack .params.buttons

   if {$instance == {}} {
	button .params.buttons.apply -text "Create" -command \
		[subst {set inst \[magic::gencell_create \
		$gencell_type $library {}\] ; \
		magic::gencell_dialog \$inst $gencell_type $library {} }]
   } else {
	button .params.buttons.apply -text "Apply" -command \
		"magic::gencell_change $instance $gencell_type $library {}"
   }
   button .params.buttons.close -text "Close" -command {destroy .params}

   pack .params.buttons.apply -padx 10 -side left
   pack .params.buttons.close -padx 10 -side right

   # Invoke the callback procedure that creates the parameter entries

   return [eval "${library}::${gencell_type}_dialog \$parameters"]
}

#-------------------------------------------------------------
