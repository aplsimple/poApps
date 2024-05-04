# Module:         poUkazUtil
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2017 / 03 /12 
#
# Distributed under BSD license.

namespace eval poUkazUtil {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetLutColor
    namespace export Clear
    namespace export Draw Draw_X_Y Draw_X_Ind Draw_Ind_Y

    namespace export Init

    # Init is called at package load time.
    proc Init {} {
    }

    proc GetLutColor { index } {
        set lut [list black red green blue magenta]
        if { $index < 0 } {
            set index 0
        }
        return [lindex $lut [expr { $index % [llength $lut] }]]
    }

    proc Clear { w } {
        # Clear graph display and reset zoom stack.

        $w clear
        $w set auto x
        $w set auto y
    }

    proc Draw { w dataList args } {
        $w plot $dataList {*}$args
    }

    proc Draw_X_Y { w xList yList args } {
        foreach x $xList  y $yList {
            lappend dataList $x $y
        }
        $w plot $dataList {*}$args
    }

    proc Draw_X_Ind { w xList args } {
        set ind 0
        foreach x $xList {
            lappend dataList $x $ind
            incr ind
        }
        $w plot $dataList {*}$args
    }

    proc Draw_Ind_Y { w yList args } {
        set ind 0
        foreach y $yList {
            lappend dataList $ind $y
            incr ind
        }
        $w plot $dataList {*}$args
    }
}

poUkazUtil Init
