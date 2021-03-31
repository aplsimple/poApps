# Module:         poCombobox
# Copyright:      Paul Obermeier 2019-2020 / paul@poSoft.de
# First Version:  2019 / 09 / 01
#
# Distributed under BSD license.
#
# Module for extending the ttk::combobox widget.
# Code taken from https://github.com/jcowgar/misctcl/blob/master/combobox/combobox.tcl
# and slightly modified.

proc ttk::combobox::CaseSensitiveSearch { onOff } {
    variable sCaseSearch

    if { $onOff } {
        set sCaseSearch ""
    } else {
        set sCaseSearch "-nocase"
    }
}

# Required to escape a few characters due to the string match used.
proc ttk::combobox::EscapeKey { key } {
    switch -- $key {
        bracketleft  { return {\[} }
        bracketright { return {\]} }
        asterisk     { return {\*} }
        question     { return {\?} }
        quotedbl     { return {\"} }
        quoteright   -
        quoteleft    { return {\'} }
        default      { return $key }
    }
}

proc ttk::combobox::PrevNext { W dir } {
    set cur [$W current]

    switch -- $dir {
        up {
            if {$cur <= 0} {
                return
            }
            incr cur -1
        }
        down {
            incr cur
            if {$cur == [llength [$W cget -values]]} {
                return
            }
        }
    }
    $W current $cur
    event generate $W <<ComboboxSelected>> -when mark
}

proc ttk::combobox::CompleteEntry { W key } {
    variable sCaseSearch

    if { [string length $key] > 1 && [string tolower $key] != $key } {
        return
    }

    if { [$W instate readonly] } {
        set value [EscapeKey $key]
    } else {
        set value [string map { {[} {\[} {]} {\]} {?} {\?} {*} {\*} } [$W get]]
        if { [string equal $value ""] } {
            return
        }
    }

    set values [$W cget -values]

    set start 0
    if { [string match {*}$sCaseSearch $value* [$W get]] } {
        set start [expr { [$W current] + 1 }]
    }

    set x [lsearch {*}$sCaseSearch -start $start $values $value*]
    if { $x < 0 } {
        if { $start > 0} {
            set x [lsearch {*}$sCaseSearch $values $value*]

            if { $x < 0 } {
                return
            }
        } else {
            return
        }
    }

    set index [$W index insert]
    $W set [lindex $values $x]
    $W icursor $index
    $W selection range insert end

    if { [$W instate readonly] } {
        event generate $W <<ComboboxSelected>> -when mark
    }
}

proc ttk::combobox::CompleteList { W key { start -1 } } {
    set key [EscapeKey $key]

    if { $start == -1 } {
        set start [expr { [$W curselection] + 1 }]
    }

    for { set idx $start } { $idx < [$W size] } { incr idx } {
        if { [string match -nocase $key* [$W get $idx]] } {
            $W selection clear 0 end
            $W selection set $idx
            $W see $idx
            $W activate $idx
            return
        }
    }

    if { $start > 0 } {
        CompleteList $W $key 0
    }
}

bind ComboboxListbox <KeyPress>   { ttk::combobox::CompleteList %W %K }
bind TCombobox       <KeyRelease> { ttk::combobox::CompleteEntry %W %K }

bind TCombobox       <Alt-Up>     { ttk::combobox::PrevNext %W up }
bind TCombobox       <Alt-Down>   { ttk::combobox::PrevNext %W down }

ttk::combobox::CaseSensitiveSearch 0
