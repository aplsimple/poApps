# Module:         poDial
# Copyright:      Paul Obermeier 2016-2020 / paul@poSoft.de
# First Version:  2016 / 05 / 03
#
# Distributed under BSD license.
#
# A mouse dragable "dial" widget from the side view - visible
# is the knurled area.
#
# Modified version of the idea, as described in http://wiki.tcl.tk/26357
# Copyright (c) Gerhard Reithofer, Tech-EDV 2010-05
#
# Syntax:
#   poDial::Create w ?-width wid? ?-height hgt? ?-value floatval?
#        ?-bg|-background bcol? ?-fg|-foreground fcol? ?-step density?
#        ?-callback script? ?-scale factor?
#        ?-slow sfact? ?-fast ffact? ?-orient horizontal|vertical?
#        ?-textvar|-textvariable? -precision prec?
#        ?-from lowerValue? ?-to upperValue?
#   poDial::CreateCombi w ?-textwidth wid? ?-scalemin min? ?-scalemax max? ?args?
#

namespace eval poDial {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export Create CreateCombi
    namespace export GetOption SetOption

    proc Init {} {
        variable sPo
        variable sDefaults
        variable sCombiDefaults

        set sPo(sector) 88

        # Constants to reduce expr calls.
        set sPo(d2r)   [expr { atan(1.0) / 45.0 }]
        set sPo(ssize) [expr { sin($sPo(sector) * $sPo(d2r)) }]
    
        # Dial widget default values.
        array set sDefaults {
            background "#dfdfdf"
            foreground "black"
            callback   ""
            textvar    ""
            orient     horizontal 
            width      80
            height     10 
            step       10 
            value       0.0
            slow        0.1 
            fast       10.0
            scale       1.0 
            precision   2
            from       -1.7976931348623158e+308
	    to          1.7976931348623158e+308
            draw       true
        }

        # DialText widget default values.
        array set sCombiDefaults {
            textwidth   20
            scalemin   -3
            scalemax    3
        }
    }

    proc _GenError { err { msg "" } } {
        if { $msg eq "" } {
            set msg "must be -bg, -background, -fg, -foreground, -value, -width, -precision, -from, -to\
                    -height, -callback, -textvariable, -scale, -slow, -fast -orient, -step, -draw"
        }
        error "$err: $msg" 
    }

    proc SetOption { w nopt val args } {
        variable sPo
        variable sDefaults
        variable sOpts
        variable sScaleFactor

        if { [llength $args] % 2 } {
            _GenError "Invalid syntax" "must be \"SetOption opt arg ?opt arg? ...\""
        }

        set drawDials true
        set args [linsert $args 0 $nopt $val]
        foreach { o arg } $args {
            if { [string index $o 0] ne "-" } {
                _GenError "Invalid option \"$nopt\""
            }
            switch -- $o {
                "-bg" { set o "-background" }
                "-fg" { set o "-foreground" }
                "-scale" {
                    set arg [expr { $arg*1.0 }]
                    set sScaleFactor($w) [format "%.0E" $arg]
                }
                "-value" {
                    set arg [expr { $arg }]
                }
                "-textvariable" {
                    set o "-textvar"
                }
                "-draw" {
                    set drawDials [expr { $arg }]
                }
            }
            set okey [string range $o 1 end]
            if { ! [info exists sOpts($okey,$w)] } {
                _GenError "Unknown option \"$o\""
            }
            # Canvas resize isn't part of draw method
            if { $o eq "-width" || $o eq "-height" } {
                $w SetOption $o $arg
            }
            set sOpts($okey,$w) $arg
            # sfact depends on width
            if { $o eq "-width" } {
                set sPo(sfact,$w) [expr { $sPo(ssize) * 2 / $sOpts(width,$w) }]
            } elseif { $o eq "-textvar" } {
                set vname $arg
                if { [info exists $vname] } {
                    _SetCheckedValue $w [set $vname]
                } else {
                    uplevel \#0 [list set $vname $sDefaults(value)]
                }
                _SetTrace $w $vname
            }
        }

        _SetCheckedValue $w $sOpts(value,$w)
        _Draw $w $sOpts(value,$w) $drawDials
    }

    proc GetOption { w nopt } {
        variable sOpts

        switch -- $nopt {
            "-bg" { set nopt "-background" }
            "-fg" { set nopt "-foreground" }
            "-textvariable" {
                set nopt "-textvar"
            }
        }
        set okey [string range $nopt 1 end]
        if { ![info exists sOpts($okey,$w)] && [string index $nsOpts 0] ne "-" } {
            _GenError "GetOption: unknown option \"$nopt\""
        }
        if { $nopt eq "-value" } {
            return [expr { $sOpts($okey,$w) }]
        } else  {
            return $sOpts($okey,$w)
        }
    }

    proc _FormatValue { w val } {
        variable sOpts

        set prec $sOpts(precision,$w)
        return [format "%.${prec}f" $val]
    }
 
    proc _SetCheckedValue { w value } {
        variable sOpts

        if { ! [string is double -strict $value] } {
            set value 0.0
        }
        if { $value < $sOpts(from,$w) } {
            set value $sOpts(from,$w)
        }
        if { $value > $sOpts(to,$w) } {
            set value $sOpts(to,$w)
        }
        set sOpts(value,$w) [_FormatValue $w $value]
    }
    
    # Draw the thumb wheel view
    proc _Draw { w val { drawDials true } } {
        variable sPo
        variable sOpts

        set stp $sOpts(step,$w)
        set wid $sOpts(width,$w)
        set hgt $sOpts(height,$w)
        set dfg $sOpts(foreground,$w)
        set dbg $sOpts(background,$w)

        if { $drawDials } {
            $w delete all
            if { $sOpts(orient,$w) eq "horizontal" } {
                # Every value is mapped to the visible sector
                set mod [expr { $val - $sPo(sector) * int($val / $sPo(sector)) }]
                $w create rectangle 0 0 $wid $hgt -fill $dbg
                # From normalized value to left end
                for { set ri $mod } { $ri >= -$sPo(sector) } { set ri [expr { $ri - $stp }] } {
                    set offs [expr { ($sPo(ssize) + sin($ri * $sPo(d2r))) / $sPo(sfact,$w) }]
                    $w create line $offs 0 $offs $hgt -fill $dfg
                }
                # From normalized value to right end
                for { set ri [expr { $mod + $stp }] } { $ri <= $sPo(sector) } { set ri [expr { $ri + $stp }] } {
                    set offs [expr {($sPo(ssize)+sin($ri*$sPo(d2r)))/$sPo(sfact,$w)}]
                    $w create line $offs 0 $offs $hgt -fill $dfg
                }
            } else {
                # Every value is mapped to the visible sector
                set mod [expr { $sPo(sector) * int($val / $sPo(sector)) - $val }]
                $w create rectangle 0 0 $hgt $wid -fill $dbg
                # From normalized value to upper end
                for { set ri $mod } { $ri >=- $sPo(sector) } { set ri [expr { $ri-$stp }] } {
                    set offs [expr { ($sPo(ssize) + sin($ri * $sPo(d2r))) / $sPo(sfact,$w) }]
                    $w create line 0 $offs $hgt $offs -fill $dfg
                }
                # From normalized value to lower end
                for { set ri [expr { $mod + $stp }] } { $ri <= $sPo(sector) } { set ri [expr { $ri + $stp }] } {
                    set offs [expr { ($sPo(ssize) + sin($ri * $sPo(d2r))) / $sPo(sfact,$w) }]
                    $w create line 0 $offs $hgt $offs -fill $dfg
                }
            }
        }
        set sOpts(value,$w) $val

        if { $sOpts(textvar,$w) ne "" } {
            set vname $sOpts(textvar,$w)
            uplevel \#0 [list set $vname $val]
        }
    }

    proc _DrawFromEntry { w } {
        variable sPo
        variable sOpts

        _SetCheckedValue $w $sPo($w,val)
        # Call callback procedure, if defined.
        if { $sOpts(callback,$w) ne "" } {
            {*}$sOpts(callback,$w) $sOpts(value,$w) false
        }
        _Draw $w $sOpts(value,$w)
    }

    proc _InitDrag { w coord } {
        variable sPo

        set sPo(ovalue,$w)  $coord
        set sPo(omotion,$w) false
    }

    proc _Drag { w coord mode motion } {
        variable sPo
        variable sOpts

        if { [info exists sPo($w,entry)] } {
            set state [$sPo($w,entry) cget -state]
            if { $state eq "disabled" } {
                return
            }
        }
        
        # Calculate new value
        if { $sOpts(orient,$w) eq "horizontal" } {
            set diff [expr { $coord - $sPo(ovalue,$w) }]
        } else {
            set diff [expr { $sPo(ovalue,$w) - $coord }]
        }
        if { $motion == $sPo(omotion,$w) && $diff == 0 } {
            if { $coord < $sOpts(width,$w) / 2 } {
                set diff -1
            } else {
                set diff 1
            }
        }
        if { $mode<0 } {
            set diff [expr { $diff * $sOpts(slow,$w) }]
        } elseif { $mode>0 } {
            set diff [expr { $diff * $sOpts(fast,$w) }]
        }
        _SetCheckedValue $w [expr { $sOpts(value,$w) + $diff * $sOpts(scale,$w) }]

        # Call callback procedure, if defined.
        if { $sOpts(callback,$w) ne "" } {
            {*}$sOpts(callback,$w) $sOpts(value,$w) $motion
        }

        # Draw knob with new angle
        _Draw $w $sOpts(value,$w)

        # Store "old" value for diff
        set sPo(ovalue,$w)  $coord
        set sPo(omotion,$w) $motion
    }
 
    proc _VarUpdate { w var idx op } {
        variable sOpts

        set vname $var
        if { $idx ne "" } {
            append vname "(" $idx ")" 
        }
        if { $op eq "unset" } {
            uplevel \#0 [unset $vname]
            set sOpts(textvar,$w) ""
            _RemoveTrace $w $vname 
        } else {
            _SetCheckedValue $w [uplevel \#0 [list set $vname]]

            # Call callback procedure, if defined.
            if { $sOpts(callback,$w) ne "" } {
                {*}$sOpts(callback,$w) $sOpts(value,$w) false
            }
        }

        _Draw $w $sOpts(value,$w)
    }

    proc _SetTrace { w var } {
        variable ns

        upvar \#0 $var locvar
        trace add variable locvar { write unset } "${ns}::_VarUpdate $w"
    }

    proc _RemoveTrace { w var } {
        variable ns

        upvar \#0 $var locvar
        trace remove variable locvar { write unset } "${ns}::_VarUpdate $w"
    }

    proc _SetDialScale { w  name1 name2 op } {
        variable sScaleFactor

        set newScale [expr $sScaleFactor($w)]
        SetOption $w -scale $newScale
        event generate $w <<ScaleChanged>>
    }

    proc _OpenContextMenu { w x y } {
        variable ns
        variable sCombiOpts
        variable sScaleFactor

        for { set s $sCombiOpts(scalemin,$w) } { $s <= $sCombiOpts(scalemax,$w) } { incr s } {
            lappend scaleFactorList [format "%.0E" [expr { pow (10, $s) }]]
        }
        set cw .poDial:contextMenu
        catch { destroy $cw }
        menu $cw -tearoff false
        $cw add command -label "Choose dial scale" -state disabled
        foreach value $scaleFactorList {
            $cw add radiobutton -value $value -label $value -variable ${ns}::sScaleFactor($w)
        }
        tk_popup $cw $x $y
    }

    proc CreateCombi { masterFrame args } {
        variable ns
        variable sPo
        variable sCombiOpts
        variable sCombiDefaults
        variable sScaleFactor

        set fr $masterFrame.fr
        ttk::frame $fr
        pack $fr -expand true -fill both

        ttk::frame $fr.top
        ttk::frame $fr.bot
        pack {*}[winfo children $fr] -side top -anchor w

        set entry $fr.top.entry
        set dial  $fr.bot.dial
        set sPo($dial,entry) $entry

        set optionList [array names sCombiDefaults]
        # Set default values.
        foreach d $optionList {
            set sCombiOpts($d,$dial) $sCombiDefaults($d)
        }
        # Handle command parameters 
        set dialArgs [list]
        foreach { tmp arg } $args {
            set o [string range $tmp 1 end]
            switch -exact -- $o {
                "textwidth" -
                "scalemin" -
                "scalemax" {
                    set sCombiOpts($o,$dial) $arg
                }
                default {
                    lappend dialArgs $tmp $arg
                }
            }
        }

        # Fill top frame with text entry.
        ttk::entry $entry -textvariable ${ns}::sPo($dial,val) -width $sCombiOpts(textwidth,$dial) -justify right -exportselection false
        bind $entry <Key-Escape> "focus [focus -lastfor $entry]"
        bind $entry <Key-Return> "${ns}::_DrawFromEntry $dial"
        trace add variable ${ns}::sScaleFactor($dial) write "${ns}::_SetDialScale $dial"
        pack {*}[winfo children $fr.top] -side left -anchor w
        # Update needed, because we want the size of the top frame to make the dial same size.
        update

        # Fill bottom frame with the dial widget.
        set topWidth [winfo width $fr.top]
        Create $dial -textvariable ${ns}::sPo($dial,val) -width $topWidth {*}$dialArgs
        _InitDrag $dial 0
        pack $dial

        # Get current scale factor of dial and store it in sScaleFactor in the same format
        # as the list of scale factors in the context menu.
        set sScaleFactor($dial) [format "%.0E" [GetOption $dial -scale]]
        return $dial
    }

    proc Create { w args } {
        variable ns
        variable sPo
        variable sDefaults
        variable sOpts

        set optionList [array names sDefaults]
        # set default values
        foreach d $optionList {
            set sOpts($d,$w) $sDefaults($d) 
        }
        # handle command parameters 
        foreach { tmp arg } $args {
            set o [string range $tmp 1 end]
            switch -- $o {
                "bg" { set o background }
                "fg" { set o foreground }
                "textvariable" {
                    set o "textvar"
                }
                "scale" {
                    set arg [expr {$arg*1.0}]
                }
            }
            if { [lsearch $optionList $o] < 0 || [string index $tmp 0] ne "-" } {
                _GenError "Bad option \"$o\""
            }
            set sOpts($o,$w) $arg
        }
        if { $sOpts(textvar,$w) ne "" } {
            set vname $sOpts(textvar,$w)
            if { [info exists $vname] } {
                _SetCheckedValue $w [set $vname]
            } else {
                uplevel \#0 [list set $vname $sDefaults(value)]
            }
            #_SetTrace $w $vname 
        }

        # Width specific scale constant
        set sPo(sfact,$w) [expr { $sPo(ssize) * 2 / $sOpts(width,$w) }]
        
        set wid $sOpts(width,$w)
        set hgt $sOpts(height,$w)
        set bgc $sOpts(background,$w)
 
        # Create canvas and bindings
        if { $sOpts(orient,$w) eq "horizontal" } {
            canvas $w -width $wid -height $hgt
            # Standard bindings
            bind $w <ButtonPress-1>   [list ${ns}::_InitDrag %W %x]
            bind $w <B1-Motion>       [list ${ns}::_Drag %W %x 0 true]
            bind $w <ButtonRelease-1> [list ${ns}::_Drag %W %x 0 false]
            # Fine movement
            bind $w <Shift-ButtonPress-1>   [list ${ns}::_InitDrag %W %x]
            bind $w <Shift-B1-Motion>       [list ${ns}::_Drag %W %x -1 true]
            bind $w <Shift-ButtonRelease-1> [list ${ns}::_Drag %W %x -1 false]
            # Course movement
            bind $w <Control-ButtonPress-1>   [list ${ns}::_InitDrag %W %x]
            bind $w <Control-B1-Motion>       [list ${ns}::_Drag %W %x 1 true]
            bind $w <Control-ButtonRelease-1> [list ${ns}::_Drag %W %x 1 false]
        } else {
            canvas $w -width $hgt -height $wid
            # Standard bindings
            bind $w <ButtonPress-1>   [list ${ns}::_InitDrag %W %y]
            bind $w <B1-Motion>       [list ${ns}::_Drag %W %y 0 true]
            bind $w <ButtonRelease-1> [list ${ns}::_Drag %W %y 0 false]
            # Fine movement
            bind $w <Shift-ButtonPress-1>   [list ${ns}::_InitDrag %W %y]
            bind $w <Shift-B1-Motion>       [list ${ns}::_Drag %W %y -1 true]
            bind $w <Shift-ButtonRelease-1> [list ${ns}::_Drag %W %y -1 false]
            # Course movement
            bind $w <Control-ButtonPress-1>   [list ${ns}::_InitDrag %W %y]
            bind $w <Control-B1-Motion>       [list ${ns}::_Drag %W %y 1 true]
            bind $w <Control-ButtonRelease-1> [list ${ns}::_Drag %W %y 1 false]
        }
        if { $::tcl_platform(os) eq "Darwin" } {
            bind $w <ButtonPress-2> [list ${ns}::_OpenContextMenu $w %X %Y]
        } else {
            bind $w <ButtonPress-3> [list ${ns}::_OpenContextMenu $w %X %Y]
        }

        _Draw $w $sOpts(value,$w)
        return $w
    }
}

poDial Init
