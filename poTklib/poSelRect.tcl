# Module:         poSelRect
# Copyright:      Paul Obermeier 2013-2020 / paul@poSoft.de
# First Version:  2013 / 03 / 01
#
# Distributed under BSD license.
#
# Module for handling a selection rectangle on a canvas.

namespace eval poSelRect {
    variable ns [namespace current]

    namespace ensemble create

    namespace export SetDisabledColor        GetDisabledColor
    namespace export SetEnabledColor         GetEnabledColor
    namespace export SetHaloSize             GetHaloSize
    namespace export SetShowText             GetShowText
    namespace export SetTextHorizontalOffset GetTextHorizontalOffset
    namespace export SetTextVerticalOffset   GetTextVerticalOffset
    namespace export SetSelRectParams        GetSelRectParams

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export Enable Disable
    namespace export IsEnabled IsAvailable
    namespace export NewSelection
    namespace export CheckSelection
    namespace export GetNumSelRects
    namespace export SetSize SetCoords GetCoords
    namespace export ChangeZoom

    # Internal procedures.
    proc _GetTagRect { name } {
        return [format "%sRect" $name]
    }

    proc _GetTagText { name } {
        return [format "%sText" $name]
    }

    proc _NormalizeCoords { coordList { invert false } } {
        variable sPo

        set newCoords [list]
        foreach p $coordList {
            if { $invert } {
                lappend newCoords [expr {int ($p * $sPo(zoom))}]
            } else {
                lappend newCoords [expr {int ($p / $sPo(zoom))}]
            }
        }
        return $newCoords
    }

    proc _UpdateText { canvId name cx cy } {
        variable sPo

        set tagRect [_GetTagRect $name]
        set tagText [_GetTagText $name]
        if { [GetShowText] } {
            set coordList [_NormalizeCoords [$canvId coords $tagRect]]
            lassign $coordList x1 y1 x2 y2
            set w [expr {$x2 - $x1 + 1}]
            set h [expr {$y2 - $y1 + 1}]
            set msg [format "(%d,%d)-(%d,%d)\nSize:%dx%d" \
                    $x1 $y1 $x2 $y2 $w $h]
            $canvId itemconfigure $tagText -anchor $sPo(text,anchor) -text $msg
            $canvId coords $tagText [expr {$cx + $sPo(text,dx)}] [expr {$cy + $sPo(text,dy)}]
        } else {
            $canvId coords $tagText -1000 -1000
        }
    }

    proc _HiliteSelection { canvId name cx cy onOff } {
        variable sPo

        set tagRect [_GetTagRect $name]
        set tagText [_GetTagText $name]
        if { $onOff } {
            $canvId itemconfigure $tagRect -outline [GetEnabledColor]
            $canvId itemconfigure $tagText -fill [GetEnabledColor]
            _UpdateText $canvId $name $cx $cy
        } else {
            $canvId itemconfigure $tagRect -outline [GetDisabledColor]
            $canvId itemconfigure $tagText -fill    [GetDisabledColor]
            $canvId coords $tagText -1000 -1000
        }
    }

    proc _GetColor { buttonId type } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(color,$type)]
        if { $newColor ne "" } {
            set sPo(color,$type) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $buttonId configure -background $newColor }
        }
    }

    proc _IsValidRect { x1 y1 x2 y2 } {
        if { $x1 < $x2 && $y1 < $y2 } {
            return true
        } else {
            return false
        }
    }

    proc _AddToSelList { name x1 y1 x2 y2 } {
        variable sPo

        if { [_IsValidRect $x1 $y1 $x2 $y2] } {
            lappend sPo($name,selRectList) [_NormalizeCoords [list $x1 $y1 $x2 $y2]]
        }
    }

    # Public procedures used for configuration settings.
    proc SetDisabledColor { color } {
        variable sPo

        set sPo(color,off) $color
    }

    proc GetDisabledColor {} {
        variable sPo

        return $sPo(color,off)
    }

    proc SetEnabledColor { color } {
        variable sPo

        set sPo(color,on) $color
    }

    proc GetEnabledColor {} {
        variable sPo

        return $sPo(color,on)
    }

    proc SetHaloSize { halo } {
        variable sPo

        set sPo(halo) $halo
    }

    proc GetHaloSize {} {
        variable sPo

        return $sPo(halo)
    }

    proc SetShowText { onOff } {
        variable sPo

        set sPo(text,show) $onOff
    }

    proc GetShowText {} {
        variable sPo

        return $sPo(text,show)
    }

    proc SetTextHorizontalOffset { offset } {
        variable sPo

        set sPo(text,offX) $offset
    }

    proc SetTextVerticalOffset { offset } {
        variable sPo

        set sPo(text,offY) $offset
    }

    proc GetTextHorizontalOffset {} {
        variable sPo

        return $sPo(text,offX)
    }

    proc GetTextVerticalOffset {} {
        variable sPo

        return $sPo(text,offY)
    }

    proc SetSelRectParams { haloSize colorOn colorOff showText textOffX textOffY } {
        SetHaloSize             $haloSize
        SetEnabledColor         $colorOn
        SetDisabledColor        $colorOff
        SetShowText             $showText
        SetTextHorizontalOffset $textOffX
        SetTextVerticalOffset   $textOffY
    }

    proc GetSelRectParams {} {
        return [list [GetHaloSize] \
                     [GetEnabledColor] \
                     [GetDisabledColor] \
                     [GetShowText] \
                     [GetTextHorizontalOffset] \
                     [GetTextVerticalOffset] ]
    }

    # Public procedures.
    proc Init {} {
        variable sPo

        set sPo(ok)   false
        set sPo(use)  false
        set sPo(move) false

        set sPo(zoom) 1.0

        SetShowText             true
        SetTextHorizontalOffset 10
        SetTextVerticalOffset   10
        SetHaloSize             10
        SetDisabledColor        "red"
        SetEnabledColor         "green"
    }

    proc Enable { canvId name } {
        variable ns
        variable sPo
        variable sBindings

        # Save the current bindings of the canvas for restoring in procedure Disable.
        foreach binding [bind $canvId] {
            set sBindings($binding) [bind $canvId $binding]
        }

        # Now establish the bindings needed for this module.
        bind $canvId <Button-1>        "${ns}::StartSelection  $canvId $name %x %y"
        bind $canvId <B1-Motion>       "${ns}::MoveSelection   $canvId $name %x %y"
        bind $canvId <ButtonRelease-1> "${ns}::SetSelection    $canvId $name %x %y"
        bind $canvId <ButtonRelease-3> "${ns}::_PrintSelection $canvId $name"
        bind $canvId <Motion>          "+${ns}::CheckSelection $canvId $name %x %y"

        set sPo(use) true
    }

    proc Disable { canvId name } {
        variable sPo
        variable sBindings

        # Disable the bindings established in procedure Enable.
        bind $canvId <Button-1>        ""
        bind $canvId <B1-Motion>       ""
        bind $canvId <ButtonRelease-1> ""
        bind $canvId <ButtonRelease-3> ""
        bind $canvId <Motion>          ""

        # Enable the original bindings stored when called procedure Enable.
        foreach binding [array names sBindings "*"] {
            bind $canvId $binding $sBindings($binding)
        }
        set sPo(use) false
    }

    proc IsEnabled {} {
        variable sPo

        return $sPo(use)
    }

    proc IsAvailable {} {
        variable sPo

        return $sPo(ok)
    }

    proc GetNumSelRects { name } {
        variable sPo

        return [llength $sPo($name,selRectList)]
    }

    proc SetCoords { canvId name x1 y1 x2 y2 } {
        variable sPo

        set coordList [_NormalizeCoords [list $x1 $y1 $x2 $y2] true]
        $canvId coords [_GetTagRect $name] {*}$coordList
        set sPo(ok) true
    }

    proc SetSize { canvId name x1 y1 w h } {
        variable sPo

        lassign [_NormalizeCoords [list $x1 $y1 $w $h] true] nx1 ny1 nw nh
        set nx2 [expr {$nx1 + $nw - 1}]
        set ny2 [expr {$ny1 + $nh - 1}]

        set coordList [list $nx1 $ny1 $nx2 $ny2]
        $canvId coords [_GetTagRect $name] {*}$coordList
        $canvId raise  [_GetTagText $name]
        set sPo(ok) true
    }

    proc GetCoords { canvId name { index -1 } } {
        variable sPo

        if { $index eq "end" } {
            return [lindex $sPo($name,selRectList) end]
        } elseif { $index >= 0 && $index < [llength $sPo($name,selRectList)] } {
            return [lindex $sPo($name,selRectList) $index]
        } else {
            if { ! $sPo(ok) } {
                return [list]
            }
            return [_NormalizeCoords [$canvId coords [_GetTagRect $name]]]
        }
    }

    proc NewSelection { canvId name { x1 -1000 } { y1 -1000 } { x2 -1000 } { y2 -1000 } } {
        variable sPo

        set sPo(cursor) [$canvId cget -cursor]
        $canvId create rectangle $x1 $y1 $x2 $y2 -tags [list $name [_GetTagRect $name]]
        $canvId create text -1000 -1000 -anchor nw -tags [list $name [_GetTagText $name]]
        set sPo($name,selRectList) [list]
        set sPo(rect,x1) $x1
        set sPo(rect,y1) $y1
        set sPo(rect,x2) $x2
        set sPo(rect,y2) $y2
        if { [_IsValidRect $x1 $y1 $x2 $y2] } {
            set sPo(ok) true
        } else {
            set sPo(ok) false
        }
        _HiliteSelection $canvId $name $x1 $y1 false
        Enable $canvId $name
    }

    proc DeleteSelection { canvId name } {
        variable sPo

        $canvId delete $name
    }

    proc GetZoom {} {
        variable sPo

        return $sPo(zoom)
    }

    proc ChangeZoom { canvId name zoomFactor } {
        variable sPo

        if { $sPo(ok) } {
            # puts "ChangeZoom $name $zoomFactor"
            if { $zoomFactor != $sPo(zoom) } {
                set coordList [$canvId coords [_GetTagRect $name]]
                set newCoords [list]
                foreach p $coordList {
                    lappend newCoords [expr {$p * $zoomFactor / $sPo(zoom)}]
                }
                $canvId coords [_GetTagRect $name] $newCoords
            }
        }
        set sPo(zoom) $zoomFactor
    }

    proc StartSelection { canvId name x y } {
        variable sPo

        set cx [$canvId canvasx $x]
        set cy [$canvId canvasy $y]
        if { $sPo(move) } {
            # puts "StartSelection rect $name $cx $cy"
            $canvId raise [_GetTagRect $name]
            $canvId raise [_GetTagText $name]
            set sPo(move,x1) $cx
            set sPo(move,y1) $cy
            set coordList [$canvId coords [_GetTagRect $name]]
            lassign $coordList sPo(rect,x1) sPo(rect,y1) sPo(rect,x2) sPo(rect,y2)
        } else {
            # puts "StartSelection new $name $cx $cy"
            set sPo(rect,x1) $cx
            set sPo(rect,y1) $cy
        }
    }

    proc MoveSelection { canvId name x y } {
        variable sPo

        set cx [$canvId canvasx $x]
        set cy [$canvId canvasy $y]
        if { $sPo(move) } {
            # puts "MoveSelection rect $name $x $y $cx $cy"
            set dx [expr {$cx - $sPo(move,x1)}]
            set dy [expr {$cy - $sPo(move,y1)}]
            set x1 [expr {$sPo(rect,x1) + $dx * $sPo(move,x1Use)}]
            set y1 [expr {$sPo(rect,y1) + $dy * $sPo(move,y1Use)}]
            set x2 [expr {$sPo(rect,x2) + $dx * $sPo(move,x2Use)}]
            set y2 [expr {$sPo(rect,y2) + $dy * $sPo(move,y2Use)}]
            $canvId coords [_GetTagRect $name] $x1 $y1 $x2 $y2

            _UpdateText $canvId $name $cx $cy
        } else {
            # puts "MoveSelection new $name $cx $cy"
            $canvId coords [_GetTagRect $name] $sPo(rect,x1) $sPo(rect,y1) $cx $cy
        }
        event generate $canvId <<poSelRect>>
    }

    proc SetSelection { canvId name x y } {
        variable sPo

        set cx [$canvId canvasx $x]
        set cy [$canvId canvasy $y]
        if { $sPo(move) } {
            # puts "SetSelection rect $name $cx $cy"
            set coordList [$canvId coords [_GetTagRect $name]]
            lassign $coordList sPo(rect,x1) sPo(rect,y1) sPo(rect,x2) sPo(rect,y2)
        } else {
            # puts "SetSelection new $name $cx $cy"
            set sPo(rect,x2) $cx
            set sPo(rect,y2) $cy
            # If mouse button was pressed and released without moving, clear selection.
            if { $sPo(rect,x1) == $sPo(rect,x2) && \
                 $sPo(rect,y1) == $sPo(rect,y2) } {
                $canvId coords [_GetTagRect $name] -1000 -1000 -1000 -1000
                set sPo(ok) false
            } else {
                set sPo(ok) true
            }
            # x1 and y1 must be smaller than x2 and y2.
            if { $sPo(rect,x1) > $sPo(rect,x2) } {
                set tmp $sPo(rect,x1)
                set sPo(rect,x1) $sPo(rect,x2)
                set sPo(rect,x2) $tmp
            }
            if { $sPo(rect,y1) > $sPo(rect,y2) } {
                set tmp $sPo(rect,y1)
                set sPo(rect,y1) $sPo(rect,y2)
                set sPo(rect,y2) $tmp
            }
        }
        _AddToSelList $name $sPo(rect,x1) $sPo(rect,y1) $sPo(rect,x2) $sPo(rect,y2)
        event generate $canvId <<poSelRect>>
    }

    proc CheckSelection { canvId name x y } {
        variable sPo

        set cx [$canvId canvasx $x]
        set cy [$canvId canvasy $y]
        set coordList [$canvId coords [_GetTagRect $name]]
        lassign $coordList x1 y1 x2 y2
        if { $x1 <= $cx && $cx <= $x2 && $y1 <= $cy && $cy <= $y2 } {
            set halo [GetHaloSize]
            set offX [GetTextHorizontalOffset]
            set offY [GetTextVerticalOffset]
            set sPo(move,x1Use) 0
            set sPo(move,y1Use) 0
            set sPo(move,x2Use) 0
            set sPo(move,y2Use) 0
            set sPo(move) true
            set dx1 [expr {$cx - $x1}]
            set dy1 [expr {$cy - $y1}]
            set dx2 [expr {$x2 - $cx}]
            set dy2 [expr {$y2 - $cy}]
            set halfX [expr {$x1 + ($x2 - $x1) / 2}]
            set halfY [expr {$y1 + ($y2 - $y1) / 2}]
            if { $cx < $halfX && $cy < $halfY } {
                # puts "Top left quadrant"
                set sPo(text,anchor) "nw"
                set sPo(text,dx) $offX
                set sPo(text,dy) $offY
            } elseif { $cx > $halfX && $cy < $halfY } {
                # puts "Top right quadrant"
                set sPo(text,anchor) "ne"
                set sPo(text,dx) -$offX
                set sPo(text,dy) $offY
            } elseif { $cx < $halfX && $cy > $halfY } {
                # puts "Bottom left quadrant"
                set sPo(text,anchor) "sw"
                set sPo(text,dx) $offX
                set sPo(text,dy) -$offY
            } else {
                # puts "Bottom right quadrant"
                set sPo(text,anchor) "se"
                set sPo(text,dx) -$offX
                set sPo(text,dy) -$offY
            }
            if { $dx1 <= $halo && $dy2 <= $halo } {
                $canvId configure -cursor bottom_left_corner
                set sPo(move,x1Use) 1
                set sPo(move,y2Use) 1
            } elseif { $dx2 <= $halo && $dy2 <= $halo } {
                $canvId configure -cursor bottom_right_corner
                set sPo(move,x2Use) 1
                set sPo(move,y2Use) 1
            } elseif { $dx1 <= $halo && $dy1 <= $halo } {
                $canvId configure -cursor top_left_corner
                set sPo(move,x1Use) 1
                set sPo(move,y1Use) 1
            } elseif { $dx2 <= $halo && $dy1 <= $halo } {
                $canvId configure -cursor top_right_corner
                set sPo(move,x2Use) 1
                set sPo(move,y1Use) 1
            } elseif { $dx1 <= $halo } {
                $canvId configure -cursor left_side
                set sPo(move,x1Use) 1
            } elseif { $dx2 <= $halo } {
                $canvId configure -cursor right_side
                set sPo(move,x2Use) 1
            } elseif { $dy1 <= $halo } {
                $canvId configure -cursor top_side
                set sPo(move,y1Use) 1
            } elseif { $dy2 <= $halo } {
                $canvId configure -cursor bottom_side
                set sPo(move,y2Use) 1
            } else {
                $canvId configure -cursor fleur
                set sPo(move,x1Use) 1
                set sPo(move,y1Use) 1
                set sPo(move,x2Use) 1
                set sPo(move,y2Use) 1
            }
            _HiliteSelection $canvId $name $cx $cy true
        } else {
            set sPo(move) false
            $canvId configure -cursor $sPo(cursor)
            _HiliteSelection $canvId $name $cx $cy false
        }
    }

    proc _PrintSelection { canvId name } {
        puts [GetCoords $canvId $name]
    }

    proc CancelWin { w args } {
        variable sPo

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        catch { destroy $w }
    }

    proc OkWin { w } {
        destroy $w
    }

    proc OpenWin { fr } {
        variable ns
        variable sPo

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "Size of halo (Pixel):" \
                           "Color of enabled selection:" \
                           "Color of disabled selection:" \
                           "Information about selection:" \
                           "Horizontal text offset (Pixel):" \
                           "Vertical text offset (Pixel):" ] {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Generate right column with entries and buttons.
        set varList [list]

        # Row 0: Size of halo
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(halo) -row $row -width 3 -min 1

        set tmpList [list [list sPo(halo)] [list $sPo(halo)]]
        lappend varList $tmpList

        # Row 1: Color of enabled selection
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(color,on)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l on"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(color,on)] [list $sPo(color,on)]]
        lappend varList $tmpList

        # Row 2: Color of disabled selection
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(color,off)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l off"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(color,off)] [list $sPo(color,off)]]
        lappend varList $tmpList

        # Row 3: Information about selection
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb -text "Show inside rectangle" \
                    -variable ${ns}::sPo(text,show) \
                    -onvalue true -offvalue false
        pack $tw.fr$row.cb -side top -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(text,show)] [list $sPo(text,show)]]
        lappend varList $tmpList

        # Row 4: Horizontal text offset
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(text,offX) -row $row -width 3 -min 0

        set tmpList [list [list sPo(text,offX)] [list $sPo(text,offX)]]
        lappend varList $tmpList

        # Row 5: Vertical text offset
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(text,offY) -row $row -width 3 -min 0

        set tmpList [list [list sPo(text,offY)] [list $sPo(text,offY)]]
        lappend varList $tmpList

        return $varList
    }
}

poSelRect Init
