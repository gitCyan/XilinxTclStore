####################################################################################
#
# create_rqs_run.tcl (create a run based on the suggested strategy by report_qor_suggestions via Tcl)
#
# Script created on 30/11/2017 by Xilinx, Inc.
#
# 2018.1 - v1.0 (rev 1)
#  * initial version
#
####################################################################################
package require Vivado 1.2014.1

namespace eval ::tclapp::xilinx::projutils {
  namespace export create_rqs_run
}

namespace eval ::tclapp::xilinx::projutils {
proc create_rqs_run { args } {
  # Summary:
  # Creates and launches a new run based on the suggestions by report_qor_suggestions.

  # Argument Usage:
  # -dir <arg>: Specify the directory from where the xdc files and tcl files need to fetched.
  # -new_name <arg>: Specify the name of the new run
  # -synth_name <arg>: Specify the name of the already existing synth run. This run will be the parent run for the newly created impl run
  # -opt_more_options <arg> - optional argument. Specify the value for opt_design step's more option property which will be set on newly created run.
  # -place_more_options <arg> - optional argument. Specify the value for place_design step's more option property which will be set on newly created run.

  # Return Value:
  # None 

  # Categories: xilinxtclstore, projutils

  # member variables
  array set xdcFileMap {}
  array set tclFileMap {}

  # process options 
  for { set index 0 } { $index < [ llength $args ] } { incr index } {
    set option [ string trim [ lindex $args $index ] ]
    switch -regexp -- $option {
      "-new_name"   { incr index; set newProjName [ lindex $args $index ] }
      "-dir"         { incr index; set outputDir [ lindex $args $index ] }
      "-synth_name"         { incr index; set synthRunName [ lindex $args $index ] }
      "-opt_more_options"         { incr index; set optOptions [ lindex $args $index ] }
      "-place_more_options "         { incr index; set placeOptions [ lindex $args $index ] }
      default {
        # is incorrect switch specified?
        if { [ regexp {^-} $option ] } {
          send_msg_id Vivado-projutils-501 ERROR "Unknown option '$option', type 'create_rqs_run -help' for usage info.\n"
          return 1
        }
      }
    }
  }
  # check if required arguments are specified 
  if { [info exists newProjName] != 1 } {
    send_msg_id Vivado-projutils-502 ERROR "The run name (-new_name) is required yet it was not specified, type 'create_rqs_run -help' for usage info.\n"
  }

  if { [info exists outputDir] != 1 } {
    send_msg_id Vivado-projutils-502 ERROR "The directory (-dir) from which the required files are feteched is not specified, type 'create_rqs_run -help' for usage info.\n"
  }

  #end of business logic
  
  #check if the specified directory exists
  if { [file isdirectory $outputDir] != 1 } {
    send_msg_id Vivado-projutils-503 ERROR "The specified directory (-dir) '$outputDir' does not exist, please specify a valid directory. Type 'create_rqs_run -help' for usage info.\n"
  }
  
  if { [info exists synthRunName] == 1 } {
    #check if there is a run with name $synthRunName
    set isRun [get_runs $synthRunName]
    if { $isRun eq "" } {
      send_msg_id Vivado-projutils-503 ERROR "The specified synth run name (-synthRunName) does not correspond to a valid synthesis run, please specify a valid synth run. Type 'create_rqs_run -help' for usage info.\n"
    }
  }
  
  set createNewSynthRun 1
  if { [info exists synthRunName] == 1 } {
    set createNewSynthRun 0
  }

  set synthKey PreSynth
  set implKey Impl
  set preImplKey PreImpl
  
  #read xdc files from the directory, and classify them into synth files and impl files based on the file name.

  set preSynthXdcFile RQSPreSynth_${newProjName}.xdc
  set implCommonXdcFile RQSImplCommon_${newProjName}.xdc
  set preImplTclFile RQSPreImpl_${newProjName}.tcl
  set implCommonTclFile RQSImplCommon_${newProjName}.tcl

  set xdcFiles [glob -directory $outputDir -nocomplain -- "*.xdc"]
  foreach fl $xdcFiles {
    if { [ string first $preSynthXdcFile $fl ] != -1 } {
      set xdcFileMap($synthKey) $fl
    } elseif { [string first $implCommonXdcFile $fl] != -1} {
      set xdcFileMap($implKey) $fl
    }
  }
  set tclFiles [glob -directory $outputDir -nocomplain -- "*.tcl"]
  foreach fl $tclFiles {
    if { [string first $preImplTclFile $fl] != -1 } {
      set tclFileMap($preImplKey) $fl
    } elseif { [string first $implCommonTclFile $fl] != -1 } {
      set tclFileMap($implKey) $fl
    }
  }

  #create new synth and impl runs 
  set impl_run [get_runs [current_run ]]
  if { $createNewSynthRun == 1 } {
    set synth_run [get_runs [get_property parent $impl_run]]
    set new_synth_run ${synth_run}_${newProjName}
    copy_run $synth_run -name $new_synth_run 
    set synth_constr [get_property constrset $synth_run] 
    set new_synth_constr ${synth_constr}_${newProjName}
    create_fileset -constrset $new_synth_constr 
    if { [get_files -of $synth_constr] != ""} { 
      set synth_constr_files [get_files -of $synth_constr]; 
      add_files -fileset $new_synth_constr $synth_constr_files; 
    } 
    if { [info exists xdcFileMap($synthKey)] } {
    	add_files -fileset $new_synth_constr $xdcFileMap($synthKey)  
    	set_property used_in synthesis [get_files $xdcFileMap($synthKey) ] 
    }
    set_property constrset $new_synth_constr [get_runs $new_synth_run] 
  } else {
    set new_synth_run [get_runs $synthRunName]
    set new_synth_constr [get_property constrset $new_synth_run ]
  }

  set impl_parent_run [get_runs $new_synth_run]

  set new_impl_run ${impl_run}_${newProjName}
  copy_run $impl_run -name $new_impl_run -parent_run [get_runs $impl_parent_run]
  set impl_constr [get_property constrset $impl_run] 
  set new_impl_constr ${impl_constr}_${newProjName}
  if { $new_impl_constr != $new_synth_constr } {
    create_fileset -constrset $new_impl_constr
  }
  if { [get_files -of $impl_constr] != ""} { 
    set impl_constr_files [get_files -of $impl_constr]; 
    add_files -fileset $new_impl_constr $impl_constr_files; 
  }
  if { [info exists xdcFileMap($implKey)] } {
  	add_files -fileset $new_impl_constr $xdcFileMap($implKey) 
        set xdcFlName RQSImplCommon_${newProjName}.xdc
        if { [file exists $xdcFlName ] } {
          if { $createNewSynthRun == 1 } {
  	    set_property used_in {synthesis implementation} [get_files RQSImplCommon_${newProjName}.xdc]
	  } else {
  	    set_property used_in {implementation} [get_files RQSImplCommon_${newProjName}.xdc] 
	  }
        }
  }
  
  if { ( [info exists xdcFileMap($preImplKey)] ) && ( $createNewSynthRun == 0 ) } {
  	add_files -fileset $new_impl_constr $xdcFileMap($preImplKey)
  	set_property used_in implementation [get_files $xdcFileMap($preImplKey)] 
  }
  set_property constrset $new_impl_constr [get_runs $new_impl_run]

  if { ( [info exists tclFileMap($preImplKey)] ) && ( $createNewSynthRun == 0 ) } {
     set fileName $tclFileMap($preImplKey)
     if { [file exists $fileName] } {
       set_property STEPS.OPT_DESIGN.TCL.PRE $fileName [get_runs $new_impl_run]
     }
  } elseif { [info exists tclFileMap($implKey)] } {
      set fileName $tclFileMap($implKey)
      if { [file exists $fileName] } {
        set_property STEPS.OPT_DESIGN.TCL.PRE $fileName [get_runs $new_impl_run]
      }
  }

  if { [info exists optOptions ] } {
    set_property {STEPS.OPT_DESIGN.ARGS.MORE OPTIONS} $optOptions [get_runs $new_impl_run]
  }
  if { [info exists placeOptions ] } {
    set_property {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} $placeOptions [get_runs $new_impl_run]
  }
  current_run [get_runs $new_synth_run] 
  launch_runs [get_runs $new_impl_run] 
}

}
