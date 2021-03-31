# Module:         poLogOpt
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 12 / 02
#
# Distributed under BSD license.
#
# Module for handling the logging settings.

namespace eval poLogOpt {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export Test

    proc Init {} {
        variable msgStr
        variable settChanged
        variable logOptions
        variable consEnable
        variable consOldMode

        set consEnable 0
        set consOldMode $consEnable
        set logOptions([poLog LevelInfo])      [poLog LevelOff]
        set logOptions([poLog LevelWarning])   [poLog LevelOff]
        set logOptions([poLog LevelError])     [poLog LevelOff]
        set logOptions([poLog LevelDebug])     [poLog LevelOff]
        set logOptions([poLog LevelCallstack]) [poLog LevelOff]

        set settChanged false

        array set msgStr [list \
            ConsEnable "Show logging console" \
            LogInfo    "Log info messages" \
            LogWarn    "Log warning messages" \
            LogError   "Log error messages" \
            LogDebug   "Log debug messages" \
            LogCall    "Log callstack messages" \
            Cancel     "Cancel" \
            OK         "OK" \
            Confirm    "Confirmation" \
            WinTitle   "Logging options" \
        ]
    }

    proc Str { key args } {
        variable msgStr

        set str $msgStr($key)
        return [eval {format $str} $args]
    }

    proc CloseWin { w } {
        catch { destroy $w }
    }

    proc SetOpt { } {
        variable consEnable
        variable consOldMode
        variable logOptions

        if { $consEnable == 0 } {
            poLog SetShowConsole 0
        } else {
            if { $consEnable != $consOldMode } {
                poLog SetShowConsole 1
            }
        }

        set logList {}
        foreach name [array names logOptions] {
            if { $logOptions($name) != [poLog LevelOff] } {
                 lappend logList $logOptions($name)
            }
        }
        poLog SetDebugLevels $logList
    }

    proc ChangedOpts {} {
        variable settChanged

        return $settChanged
    }

    proc CancelWin { w args } {
        variable logOptions
        variable consEnable
        variable settChanged

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        set settChanged false
        CloseWin $w
    }

    proc OkWin { w } {
        SetOpt
        CloseWin $w
    }

    proc OpenWin { fr } {
        variable ns
        variable settChanged
        variable consEnable
        variable consOldMode
        variable logOptions

        set tw $fr

        foreach lev [lindex [poLog GetDebugLevels] 0] {
            set logOptions($lev) $lev
        }
        set consEnable [poLog GetShowConsole]
        set consOldMode $consEnable

        set settChanged true

        set varList {}
        ttk::frame $tw.fr
        pack $tw.fr -side top -fill x -expand 1
        ttk::checkbutton $tw.fr.cb1 -text [Str ConsEnable] \
                    -variable ${ns}::consEnable \
                    -onvalue 1 -offvalue 0
        ttk::checkbutton $tw.fr.cb2 -text [Str LogInfo] \
                    -variable ${ns}::logOptions([poLog LevelInfo]) \
                    -onvalue [poLog LevelInfo] -offvalue [poLog LevelOff]
        ttk::checkbutton $tw.fr.cb3 -text [Str LogWarn] \
                    -variable ${ns}::logOptions([poLog LevelWarning]) \
                    -onvalue [poLog LevelWarning] -offvalue [poLog LevelOff]
        ttk::checkbutton $tw.fr.cb4 -text [Str LogError] \
                    -variable ${ns}::logOptions([poLog LevelError]) \
                    -onvalue [poLog LevelError] -offvalue [poLog LevelOff]
        ttk::checkbutton $tw.fr.cb5 -text [Str LogDebug] \
                    -variable ${ns}::logOptions([poLog LevelDebug]) \
                    -onvalue [poLog LevelDebug] -offvalue [poLog LevelOff]
        ttk::checkbutton $tw.fr.cb6 -text [Str LogCall] \
                    -variable ${ns}::logOptions([poLog LevelCallstack]) \
                    -onvalue [poLog LevelCallstack] -offvalue [poLog LevelOff]
        pack $tw.fr.cb1 -side top -anchor w -pady 4
        pack $tw.fr.cb2 $tw.fr.cb3 $tw.fr.cb4 $tw.fr.cb5 $tw.fr.cb6 \
             -side top -anchor w

        set tmpList [list [list consEnable] [list $consEnable]]
        lappend varList $tmpList
        set tmpList [list [list logOptions([poLog LevelInfo])] \
                          [list $logOptions([poLog LevelInfo])]]
        lappend varList $tmpList
        set tmpList [list [list logOptions([poLog LevelWarning])] \
                          [list $logOptions([poLog LevelWarning])]]
        lappend varList $tmpList
        set tmpList [list [list logOptions([poLog LevelError])] \
                          [list $logOptions([poLog LevelError])]]
        lappend varList $tmpList
        set tmpList [list [list logOptions([poLog LevelDebug])] \
                          [list $logOptions([poLog LevelDebug])]]
        lappend varList $tmpList
        set tmpList [list [list logOptions([poLog LevelCallstack])] \
                          [list $logOptions([poLog LevelCallstack])]]
        lappend varList $tmpList

        return $varList
    }
}

poLogOpt Init
