# Module:         poLog
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 03 / 20
#
# Distributed under BSD license.
#
# Module for logging information.


# OPA TODO
#  set ::DEBUG 1
#  if {[info exists ::DEBUG] && $::DEBUG} \
#  { interp alias {} PUTS {} puts } \
#  else \
#  {
#    proc NULL {args} {}
#    interp alias {} PUTS {} NULL
#  }
#

namespace eval poLog {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export PrintCallStack
    namespace export GetShowConsole SetShowConsole
    namespace export GetDebugLevels SetDebugLevels
    namespace export GetDebugFile SetDebugFile
    namespace export Info Warning Error Debug Callstack
    namespace export LevelOff LevelInfo LevelWarning LevelError LevelDebug LevelCallstack
    namespace export Test

    proc Init {} {
        # Public variables.
        variable levelOff       0
        variable levelInfo      1
        variable levelWarning   2
        variable levelError     3
        variable levelDebug     4
        variable levelCallstack 5

        # Private variables.
        variable debugLevels
        variable debugFp
        variable debugFile
        variable debugFileOpen
        variable levelOff
        variable isInititialized

        if { ! [info exists isInititialized] } {
            SetDebugLevels [list $levelOff]
            SetShowConsole 0
            SetDebugFile ""
            set debugFileOpen false
            set debugFp stdout
            set isInititialized true
        }
    }

    proc PrintCallStack { { maxFrames -1 } { maxCharacters -1 } } {
        set numFrames [info frame]
        puts "Call stack: [expr {$numFrames - 2}] frames"
        if { $maxFrames < 0 } {
            set numFramesToPrint $numFrames
        } else {
            set numFramesToPrint [poMisc Min [expr {$maxFrames + 2}] $numFrames]
        }
        for { set frameNum 2 } { $frameNum < $numFramesToPrint } { incr frameNum } {
            set caller [info frame -$frameNum]
            set fileName "Unknown"
            set lineNum  "-1"
            if { [dict exists $caller file] } {
                set fileName [file tail [dict get $caller file]]
            }
            if { [dict exists $caller line] } {
                set lineNum  [file tail [dict get $caller line]]
            }
            set cmd [dict get $caller cmd]
            set len [string length $cmd]
            if { $maxCharacters < 0 } {
                set endRange end
            } else {
                set endRange [poMisc Min $maxCharacters $len]
            }
            puts "${fileName}:${lineNum}: [string range $cmd 0 $endRange]" 
        }
    }

    proc SetShowConsole { { onOff 1 } } {
        global tcl_platform
        variable levelOff
        variable consoleMode

        if { $onOff } {
            catch { poConsole Create .poSoftConsole {po> } {poSoft Console} }
            set consoleMode 1
        } else {
            catch { destroy .poSoftConsole }
            set consoleMode 0
        }
    }

    proc GetShowConsole {} {
        variable consoleMode

        return $consoleMode
    }

    proc GetDebugLevels {} {
        variable debugLevels

        return [list $debugLevels]
    }

    proc SetDebugLevels { levelList } {
        variable debugLevels
        variable levelOff

        set debugLevels {}
        foreach lev $levelList {
            if { $lev > $levelOff } {
                lappend debugLevels $lev
            } else {
                set debugLevels $levelOff
                return
            }
        }
    }

    proc GetDebugFile {} {
        variable debugFile

        return [list $debugFile]
    }

    proc SetDebugFile { fileName } {
        variable debugFile

        set debugFile $fileName
    }

    proc IsLoggingEnabled {} {
        variable consoleMode
        variable debugFile

        if { $consoleMode || $debugFile ne "" } {
            return true
        } else {
            return false
        }
    }

    proc LevelOff {} {
        variable levelOff
        return $levelOff
    }

    proc LevelInfo {} {
        variable levelInfo
        return $levelInfo
    }

    proc LevelWarning {} {
        variable levelWarning
        return $levelWarning
    }

    proc LevelError {} {
        variable levelError
        return $levelError
    }

    proc LevelDebug {} {
        variable levelDebug
        return $levelDebug
    }

    proc LevelCallstack {} {
        variable levelCallstack
        return $levelCallstack
    }

    # Utility function for the following message setting functions.
    proc _PrintLogging { str level } {
        variable debugLevels
        variable debugFp
        variable debugFile
        variable debugFileOpen
        variable levelOff
        variable consoleMode

        if { $debugFile ne "" && ! $debugFileOpen } {
            set retVal [catch {open $debugFile w} fp]
            if { $retVal == 0 } {
                set debugFp $fp
                set debugFileOpen true
            }
        }

        if { ! [IsLoggingEnabled] } {
            return
        }

        if { [lsearch -exact $debugLevels $level] >= 0 } {
            #for { set i 0 } { $i < [info level] } { incr i } {
            #    catch { puts -nonewline $debugFp "  " }
            #}
            catch { puts $debugFp "[info level -1]" }
            catch { flush $debugFp }
        }
    }

    proc Info { str } {
        variable levelInfo
        _PrintLogging $str $levelInfo
    }

    proc Warning { str } {
        variable levelWarning
        _PrintLogging $str $levelWarning
    }

    proc Error { str } {
        variable levelError
        _PrintLogging $str $levelError
    }

    proc Debug { str } {
        variable levelDebug
        _PrintLogging $str $levelDebug
    }

    proc Callstack { str } {
        variable levelCallstack
        _PrintLogging $str $levelCallstack
    }

    # Utility function for Test.
    proc _P { str verbose } {
        if { $verbose } {
            puts $str
        }
    }

    proc Test { { verbose true } } {
        variable levelOff
        variable levelInfo
        variable levelWarning
        variable levelError
        variable levelDebug
        variable levelCallstack

        set retVal 1

        _P "" $verbose
        _P "Start of debug test" $verbose

        SetShowConsole 1
        for { set l $levelOff } { $l <= $levelDebug } { incr l } {
            _P "Setting debug level to: $l" $verbose
            SetDebugLevels $l

            Info      "This debug message should be printed at level Info"
            Warning   "This debug message should be printed at level Warning"
            Error     "This debug message should be printed at level Error"
            Debug     "This debug message should be printed at level Debug"
            Callstack "This debug message should be printed at level Callstack"

            _P "" $verbose
        }

        _P "Test finished" $verbose
        return $retVal
    }
}

poLog Init
