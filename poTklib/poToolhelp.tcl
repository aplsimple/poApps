# Module:         poToolhelp
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 01 / 22
#
# Distributed under BSD license.
#
# Module for handling a toolhelp window. 

namespace eval poToolhelp {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export HideToolhelp
    namespace export AddBinding

    proc Init { tw { bgColor yellow } { fgColor black } { xoff 0 } { yoff 20 } } {
        variable pkgInt

        set pkgInt(tw)   $tw
        set pkgInt(bg)   $bgColor
        set pkgInt(fg)   $fgColor
        set pkgInt(xoff) $xoff
        set pkgInt(yoff) $yoff
    }
    
    proc _ShowToolhelp { w msg xoff yoff bgColor fgColor } {
        variable pkgInt

        set t $pkgInt(tw)
        catch {destroy $t}
        toplevel $t -bg $pkgInt(bg)
        wm overrideredirect $t yes
        if {[string equal [tk windowingsystem] aqua]}  {
            ::tk::unsupported::MacWindowStyle style $t help none
        }
        label $t.l -text [subst -novariables -nobackslashes -nocommands $msg] \
              -bg $bgColor -fg $fgColor -relief ridge -justify left
        pack $t.l -padx 1 -pady 1
        set width  [expr {[winfo reqwidth $t.l]  + 2}]
        set height [expr {[winfo reqheight $t.l] + 2}]
        set xMax   [expr {[winfo screenwidth $w]  - $width}]
        set yMax   [expr {[winfo screenheight $w] - $height}]
        set x      [expr {[winfo pointerx $w] + $xoff}]
        set y      [expr {[winfo pointery $w] + $yoff}]
        if {$x > $xMax} then {
            set x $xMax
        }
        if {$y > $yMax} then {
            set y $yMax
        }
        wm geometry $t +$x+$y
        set destroyScript [list destroy $t]
        bind $t <Enter> [list after cancel $destroyScript]
        bind $t <Leave> $destroyScript
    }

    proc HideToolhelp {} {
        variable pkgInt

        if { [info exists pkgInt(tw)] } {
            destroy $pkgInt(tw)
        }
    }

    proc AddBinding { w msg args } {
        variable ns
        variable pkgInt

        if { ! [info exists pkgInt(tw)] } {
            Init .poToolhelp
        }

        set xoff $pkgInt(xoff)
        set yoff $pkgInt(yoff)
        set bg   $pkgInt(bg)
        set fg   $pkgInt(fg)
        foreach { key value } $args {
            switch -exact $key {
                "-xoff" { set xoff $value }
                "-yoff" { set yoff $value }
                "-bg"   { set bg   $value }
                "-fg"   { set fg   $value }
            }
        }

        array set opt [concat { -tag "" }]
        if { $msg ne "" } then {
            set toolTipScript [list ${ns}::_ShowToolhelp %W [string map {% %%} $msg] $xoff $yoff $bg $fg]
            set enterScript [list after 200 $toolTipScript]
            set leaveScript [list after cancel $toolTipScript]
            append leaveScript \n [list after 200 [list destroy $pkgInt(tw)]]
        } else {
            set enterScript {}
            set leaveScript {}
        }
        if {$opt(-tag) ne ""} then {
            switch -- [winfo class $w] {
                Text {
                    $w tag bind $opt(-tag) <Enter> $enterScript
                    $w tag bind $opt(-tag) <Leave> $leaveScript
                }
                Canvas {
                    $w bind $opt(-tag) <Enter> $enterScript
                    $w bind $opt(-tag) <Leave> $leaveScript
                }
                default {
                    bind $w <Enter> $enterScript
                    bind $w <Leave> $leaveScript
                }
            }
        } else {
            bind $w <Enter> $enterScript
            bind $w <Leave> $leaveScript
        }
    }
}
