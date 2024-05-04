# Module:         poDiff
# Copyright:      Paul Obermeier 1999-2023 / paul@poSoft.de
# First Version:  1999 / 08 / 12
#
# Distributed under BSD license.
#
# A wrapper for standalone tkdiff program.
# See http://www.poSoft.de for screenshots and examples.

namespace eval poTkDiff {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin ParseCommandLine IsOpen
    namespace export CloseAppWindow
    namespace export GetUsageMsg

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo
        variable ns

        set sPo(tw)      ".tkdiff" ; # Name of toplevel window
        set sPo(appName) "tkdiff"  ; # Name of tool

        set sPo(cmpMode)    2
        set sPo(ignEolChar) 0
        set sPo(ignOneHour) 0
    }

    proc LoadSettings { cfgDir } {
        variable sPo
        variable ns
    }

    proc SaveSettings {} {
        variable sPo
        variable ns
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[File1\] \[File2\]\n"
        append msg "\n"
        append msg "Load 2 files for comparison. If no option is specified, the files\n"
        append msg "are loaded in tkdiff's graphical user interface for interactive comparison.\n"
        append msg "\n"
        append msg "Batch processing information:\n"
        append msg "  An exit status of 0 indicates identical files.\n"
        append msg "  An exit status of 1 indicates differing files.\n"
        append msg "  Any other exit status indicates an error when comparing.\n"
        append msg "  On Windows the exit status is stored in ERRORLEVEL.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--compare <string> : Compare files using specified mode.\n"
        append msg "                     Possible modes: \"size\", \"date\", \"content\".\n"
        append msg "                     Default: \"[poMisc GetCmpModeString $sPo(cmpMode)]\".\n"
        append msg "--ignoreeol <bool> : Ignore EOL characters when comparing in \"content\" mode.\n"
        append msg "                     Default: $sPo(ignEolChar).\n"
        append msg "--ignorehour <bool>: Ignore 1 hour differences when comparing in \"date\" mode.\n"
        append msg "                     Default: $sPo(ignOneHour).\n"

        return $msg
    }

    proc ShowMainWin {} {
        variable sPo
        variable ns
    }

    proc ParseCommandLine { argList } {
        variable sPo
        variable ns

        set sPo(param1) ""
        set sPo(param2) ""
        set whatFile 1
        set curArg  0
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "compare" } {
                    incr curArg
                    set sPo(cmpMode) [poMisc GetCmpMode [lindex $argList $curArg]]
                } elseif { $curOpt eq "ignoreeol" } {
                    incr curArg
                    set sPo(ignEolChar) [poMisc BoolAsInt [lindex $argList $curArg]]
                } elseif { $curOpt eq "ignorehour" } {
                    incr curArg
                    set sPo(ignOneHour) [poMisc BoolAsInt [lindex $argList $curArg]]
                }
            } else {
                set sPo(param$whatFile) $curParam
                incr whatFile
            }
            incr curArg
        }
        if { [poApps UseBatchMode] } {
            set catchVal [catch { \
                poMisc FileIdent $sPo(param1) $sPo(param2) \
                $sPo(cmpMode) $sPo(ignEolChar) $sPo(ignOneHour) } areIdent]
            if { $catchVal } {
                puts "Error: $areIdent."
                exit 2
            } else {
                if { [poApps GetVerbose] } {
                    puts -nonewline "Files are equal: "
                    if { $areIdent } {
                        puts "YES"
                    } else {
                        puts "NO"
                    }
                }
                if { $areIdent } {
                    exit 0
                } else {
                    exit 1
                }
            }
        } else {
            if { [file isfile $sPo(param1)] && [file isfile $sPo(param2)] } {
                if { ! [poType IsBinary $sPo(param1)] && ! [poType IsBinary $sPo(param2)] } {
                    poExtProg ShowTkDiff [list $sPo(param1) $sPo(param2)]
                } else {
                    poExtProg ShowTkDiffHexDiff $sPo(param1) $sPo(param2)
                }
            } else {
                set msg    "You must select 2 files for comparison.\n"
                append msg "Use drag-and-drop or the Open menu to load files into the working set."
                tk_messageBox -message $msg \
                              -type ok -icon warning -title "TkDiff message"
                poApps StartApp deiconify
            }
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }

    proc CloseAppWindow {} {
        variable sPo

        if { [IsOpen] && [info commands tkdiff-CloseAppWindow] ne "" } {
            tkdiff-CloseAppWindow
        }
    }
}

poTkDiff Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
