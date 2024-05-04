# Module:         poExec
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Module to execute either an external program or a program contained in a starkit.


namespace eval poExec {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export Exec Kill
    namespace export SetForceFlag SetTraceFlag

    proc Init {} {
        variable sPo

        # 1: Display on stdout what's going on
        set sPo(trace) 0

        # 1: Force use of the VFS-internal program.
        # 0: First check, if an external program is available and use
        #    internal copy only if no external program was found.
        set sPo(force) 0  

        set retVal [catch {package require twapi} version]
    }

    proc SetForceFlag { flag } {
        variable sPo

        set sPo(force) $flag
    }

    proc SetTraceFlag { flag } {
        variable sPo

        set sPo(trace) $flag
    }

    proc Exec { args } {
        variable sPo

        set progIdx -1

        # locate the programspec in the exec-cmd
        foreach a $args {
            incr progIdx
            if { $a ne "-keepnewline" && $a ne "--" } {
                break
            }
        }
        set progCallOrg [lindex $args $progIdx]
        set progCallTst ""
        set progCallNew ""
        if { ! $sPo(force) } {
            # search for external callable program
            set progCallTst [auto_execok $progCallOrg]
        }
        if { $progCallTst eq "" } {
            # no external program available, or 'force' specified
            if { [info exists      starkit::topdir] && \
                 [file isdirectory $starkit::topdir] } {
                set toolDir [file join $starkit::topdir "lib"]
            } else {
                set toolDir [file normalize [file dirname [info script]]]
            }
            set progName [file tail $progCallOrg]
            if { $::tcl_platform(platform) eq "windows" } {
                if { [file extension $progName] ne ".exe" } {
                    append progName ".exe"
                }
            }
            set prog [file join $toolDir $progName]
            if { ! [file exists $prog] } {
                error "Requested program $prog does not exist"
            }
            set progCallNew [file join [poMisc GetTmpDir] $progName]
            if { ! [file exists $progCallNew] } {
                # puts "Copy $prog --> $progCallNew"
                set retVal [catch { file copy -force -- $prog $progCallNew }]
                if { $retVal != 0 } {
                    error "Error copying program to temp dir"
                }
                if { $::tcl_platform(platform) ne "windows" } {
                    file attributes $progCallNew -permissions "u+x"
                }
            } else {
                # puts "No need to copy"
            }
            lset args $progIdx [list $progCallNew]
        }
        if { $sPo(trace) } {
            puts -nonewline ">>> "
            puts $args
        }
        catch {eval ::exec $args} rc
        if { $progCallNew ne "" } {
            if {[lindex $args end] ne "&"} {
                # on can add an switch for -nodeltemp, if required
                # catch {file delete -force -- $progCallNew}
            } else {
                # see notes
                set sPo(running,$rc) $progCallNew
            }
        }
        return $rc
    }

    proc Kill { progName } {
        if { [poMisc HavePkg "twapi"] } {
            set pids [concat [twapi::get_process_ids -name $progName] \
                             [twapi::get_process_ids -path $progName]]
            foreach pid $pids {
                # Catch the error in case process does not exist any more
                catch {twapi::end_process $pid -force}
            }
        }
    }
}

poExec Init
