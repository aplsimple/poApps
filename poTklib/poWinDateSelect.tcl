# Module:         poWinDateSelect
# Copyright:      Paul Obermeier 2014-2020 / paul@poSoft.de
# First Version:  2014 / 09 / 06
#
# Distributed under BSD license.
#
# Module with functions for creating a megawidget to select date and time.
# The megawidget consists of a label, a combobox for selecting the date compare mode,
# an entry widget for editing and and display of the date and time.
# To the right of the entry widget is a label displaying a green OK
# or red Bad bitmap indicating a valid resp. invalid date/time combination.
# A button to select a date via a popup menu finishes this megawidget.

namespace eval poWinDateSelect {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export GetDate SetDate
    namespace export CompareDate 
    namespace export GetCompareMode SetCompareMode
    namespace export IsIgnore
    namespace export CreateDateSelect

    proc Init {} {
        variable sett

        set sett(dateCmpModes) [list "ignore" "newer" "older"]
    }

    proc _CalcCmpExpr { comboId } {
        variable sett

        set sett($comboId,dateCmpStr) ""
        if { $sett($comboId,dateCmpMode) ne "ignore" } {
            set date [clock scan $sett($comboId,dateCmp) -format $sett($comboId,dateFormat)]
            if { $sett($comboId,dateCmpMode) eq "newer" } {
                set sett($comboId,dateCmpStr) " > $date"
            } elseif { $sett($comboId,dateCmpMode) eq "older" } {
                set sett($comboId,dateCmpStr) " < $date"
            }
        }
    }

    proc _CalcDate { comboId entryId labelId name1 name2 op } {
        variable sett

        if { [poWin CheckValidDateOrTime $entryId $labelId $sett($comboId,dateFormat)] } {
            _CalcCmpExpr $comboId
        }
    }

    proc IsIgnore { comboId } {
        variable sett

        if { $sett($comboId,dateCmpStr) eq "" } {
            return 1
        }
        return 0
    }

    proc CompareDate { comboId date } {
        variable sett

        set dateCmpStr $sett($comboId,dateCmpStr)
        if { $dateCmpStr eq "" } {
            return 0
        }
        return [eval expr { $date $dateCmpStr }]
    }

    proc GetDate { comboId { asFmtString true } } {
        variable sett

        if { $asFmtString } {
            return $sett($comboId,dateCmp)
        } else {
            return [clock scan $sett($comboId,dateCmp) -format $sett($comboId,dateFormat)]
        }
    }

    proc SetDate { comboId date } {
        variable sett

        if { [string is integer $date] } {
            set sett($comboId,dateCmp) [clock format $date -format $sett($comboId,dateFormat)]
        } else {
            set sett($comboId,dateCmp) $date
        }
        _CalcCmpExpr $comboId
    }

    proc _SelectDate { comboId } {
        variable sett

        set dateFormat $sett($comboId,dateFormat)
        set startDate  $sett($comboId,dateCmp)
        set retVal [catch { clock scan $startDate -format $dateFormat } dateVal]
        if { $retVal != 0 } {
            set startDate [clock format [clock seconds] -format $dateFormat]
        }
        set root [poWin GetRootWidget $comboId]
        lassign [winfo pointerxy $root] x y
        set newDate [poCalendar ShowCalendarWindow $x $y $dateFormat $startDate]
        if { $newDate ne "" } {
            set sett($comboId,dateCmp) $newDate
        }
    }

    proc _UpdateCombo { cb showInd } {
        variable sett

        $cb configure -values $sett(dateCmpModes)
        $cb current $showInd
    }

    proc GetCompareMode { comboId } {
        variable sett

        return $sett($comboId,dateCmpMode)
    }

    proc SetCompareMode { comboId cmpMode } {
        variable sett

        set indCmpMode [lsearch -exact $sett(dateCmpModes) $cmpMode]
        if { $indCmpMode < 0 } {
            set indCmpMode 0
        }
        _UpdateCombo $comboId $indCmpMode
        set sett($comboId,dateCmpMode) [lindex $sett(dateCmpModes) $indCmpMode]
        _CalcCmpExpr $comboId
    }

    proc _ComboCB { comboId } {
        variable sett

        set sett($comboId,dateCmpMode) [$comboId get]
        _CalcCmpExpr $comboId
    }

    # Create a megawidget for date and time selection.
    # "masterFr" is the frame, where the components of the megawidgets are placed.
    # "cmpMode" is a flag indicating the display of the date comparison combobox.
    # "buttonText" is an optional string displayed on the select button. If an empty string
    # is supplied, the select button is not drawn.
    proc CreateDateSelect { masterFr { cmpMode true } { buttonText "Select ..." } { dateFormat "%Y-%m-%d %H:%M" } } {
        variable ns
        variable sett

        set comboId ${masterFr}.cb
        # Initialize date widget specific values.
        set sett($comboId,dateCmpStr) ""
        set sett($comboId,dateCmpMode) "ignore"
        if { $cmpMode } {
            ttk::label ${masterFr}.lMatch -text "Date match:"
            ttk::combobox $comboId -state readonly -width 6 -values $sett(dateCmpModes) \
                                   -textvariable ${ns}::sett($comboId,dateCmpMode)
            poToolhelp AddBinding $comboId "Date compare mode"
            _UpdateCombo $comboId 0
            bind $comboId <<ComboboxSelected>> "${ns}::_ComboCB %W"
        }

        if { ! [info exists sett($comboId,dateCmp)] } {
            set sett($comboId,dateFormat) $dateFormat
            set sett($comboId,dateCmp) [clock format [clock seconds] -format $sett($comboId,dateFormat)]
        }
        ttk::entry ${masterFr}.e -takefocus 1 -textvariable ${ns}::sett($comboId,dateCmp) -width 17
        poToolhelp AddBinding ${masterFr}.e "$sett($comboId,dateFormat)"
        label ${masterFr}.l
        trace add variable ${ns}::sett($comboId,dateCmp) write "${ns}::_CalcDate $comboId ${masterFr}.e ${masterFr}.l"
        if { $buttonText ne "" } {
            ttk::button ${masterFr}.b -command "${ns}::_SelectDate $comboId" -text $buttonText -style Toolbutton
            poToolhelp AddBinding ${masterFr}.b "Select date"
        }
        pack {*}[winfo children $masterFr] -fill x -anchor w -side left
        poWin CheckValidDateOrTime ${masterFr}.e ${masterFr}.l $sett($comboId,dateFormat)

        focus ${masterFr}.e
        return $comboId
    }
}

poWinDateSelect Init
