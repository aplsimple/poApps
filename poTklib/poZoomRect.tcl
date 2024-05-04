# Module:         poZoomRect
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2013 / 03 / 01
#
# Distributed under BSD license.
#
# Module for handling one or two zoom rectangle previews on a canvas.

namespace eval poZoomRect {
    variable ns [namespace current]

    namespace ensemble create

    namespace export SetColor          GetColor
    namespace export SetSize           GetSize
    namespace export SetFactor         GetFactor
    namespace export SetZoomRectParams GetZoomRectParams

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export Enable Disable
    namespace export IsEnabled
    namespace export NewZoomRect DeleteZoomRect ChangeZoom

    # Internal procedures of this module.
    proc _GetZoomRectColor { buttonId } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(zoomRectColor)]
        if { $newColor ne "" } {
            set sPo(zoomRectColor) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $buttonId configure -background $newColor }
        }
    }

    # Public procedures used for configuration settings.
    proc SetColor { color } {
        variable sPo

        set sPo(zoomRectColor) $color
    }

    proc GetColor {} {
        variable sPo

        return $sPo(zoomRectColor)
    }

    proc SetSize { size } {
        variable sPo

        set sPo(zoomRectSize) $size
    }

    proc GetSize {} {
        variable sPo

        return $sPo(zoomRectSize)
    }

    proc SetFactor { factor } {
        variable sPo

        set sPo(zoomRectFactor) $factor
    }

    proc GetFactor {} {
        variable sPo

        return $sPo(zoomRectFactor)
    }

    proc SetZoomRectParams { size factor color } {
        SetSize   $size
        SetFactor $factor
        SetColor  $color
    }

    proc GetZoomRectParams {} {
        return [list [GetSize] \
                     [GetFactor] \
                     [GetColor] ]
    }

    # Public procedures of this module.
    proc Init {} {
        variable sPo

        set sPo(use)  false
        set sPo(zoom) 1.0

        SetColor  "red"
        SetSize   10
        SetFactor  4
    }

    proc Enable { canvId name } {
        variable ns
        variable sPo
        variable sBindings

        # Save the current bindings of the canvas for restoring in procedure Disable.
        foreach binding [bind $canvId] {
            set sBindings($canvId,$binding) [bind $canvId $binding]
        }

        # Now establish the bindings needed for this module.
        bind $canvId <1>      "${ns}::UpdateZoomRect $name %x %y %X %Y"
        bind $canvId <Motion> "+${ns}::UpdateZoomRect $name %x %y %X %Y"

        set sPo(use) true
    }

    proc Disable { canvId name } {
        variable sPo
        variable sBindings

        # Disable the bindings established in procedure Enable.
        bind $canvId <1>      ""
        bind $canvId <Motion> ""

        # Enable the original bindings stored when called procedure Enable.
        foreach key [array names sBindings "$canvId,*"] {
            set binding [lindex [split $key ","] 1]
            bind $canvId $binding $sBindings($key)
        }

        set sPo(use) false
    }

    proc IsEnabled {} {
        variable sPo

        return $sPo(use)
    }

    proc ChangeZoom { canvId name zoomFactor } {
        variable sPo

        set sPo(zoom) $zoomFactor
    }

    proc NewZoomRect { name x y canvIdLeft phImgLeft { canvIdRight "" } { phImgRight "" } } {
        variable sPo

        if { $phImgLeft eq "" } {
            return
        }

        # Create the toplevel window for the ZoomPreview, a window showing the inside
        # of the area of the ZoomRectangle just above the ZoomRectangle.
        set tw .poZoomRect_ZoomPreview_$name
        set sPo(zoomPreview) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm overrideredirect $tw true
        wm withdraw $tw

        frame $tw.workfr
        pack $tw.workfr -side top

        set w [expr {2 * $sPo(zoomRectSize) * $sPo(zoomRectFactor)}]
        set h $w
        set sPo(canvId,left,main)  ""
        set sPo(canvId,right,main) ""
        set sPo(canvId,left,zoom)  ""
        set sPo(canvId,right,zoom) ""
        set sPo(srcImg,left,photo)  ""
        set sPo(srcImg,right,photo) ""
        set sPo(zoomRect,left,photo)  ""
        set sPo(zoomRect,right,photo) ""

        if { $phImgLeft ne "" } {
            frame $tw.workfr.lfr -background $sPo(zoomRectColor) -borderwidth 2
            set canv(left) [canvas $tw.workfr.lfr.canv -width $w -height $h]
            pack $canv(left) -side top
            set phId(left) [image create photo -width $w -height $h]
            $canv(left) create image 0 0 -anchor nw -image $phId(left) -tags $phId(left)
            set sPo(canvId,left,main) $canvIdLeft
            set sPo(canvId,left,zoom) $canv(left)
            set sPo(srcImg,left,photo) $phImgLeft
            set sPo(zoomRect,left,photo) $phId(left)
        }

        if { $phImgRight ne "" } {
            frame $tw.workfr.rfr -background $sPo(zoomRectColor) -borderwidth 2
            set canv(right) [canvas $tw.workfr.rfr.canv -width $w -height $h]
            pack $canv(right) -side top
            set phId(right) [image create photo -width $w -height $h]
            $canv(right) create image 0 0 -anchor nw -image $phId(right) -tags $phId(right)
            set sPo(canvId,right,main) $canvIdRight
            set sPo(canvId,right,zoom) $canv(right)
            set sPo(srcImg,right,photo) $phImgRight
            set sPo(zoomRect,right,photo) $phId(right)
        }
        if { [info exists canv(left)] } {
            pack {*}[winfo children $tw.workfr] -side left
        }

        # Create the ZoomRectangle itself, i.e. a rectangle showing the
        # area being shown in the ZoomPreview window.
        set x1 [expr {$x - $sPo(zoomRectSize)/2}]
        set y1 [expr {$y + $sPo(zoomRectSize)/2}]
        set x2 [expr {$x + $sPo(zoomRectSize)/2}]
        set y2 [expr {$y - $sPo(zoomRectSize)/2}]
        $canvIdLeft create rectangle $x1 $y1 $x2 $y2 -outline $sPo(zoomRectColor) -tags [list $name]
        if { $canvIdRight ne "" } {
            $canvIdRight create rectangle $x1 $y1 $x2 $y2 -outline $sPo(zoomRectColor) -tags [list $name]
        }

        if { $canvIdLeft ne "" } {
            Enable $canvIdLeft $name
        }
        if { $canvIdRight ne "" } {
            Enable $canvIdRight $name
        }

    }

    proc DeleteZoomRect { name canvIdLeft { canvIdRight "" } } {
        variable sPo

        Disable $canvIdLeft $name
        $canvIdLeft delete $name
        if { $canvIdRight ne "" } {
            Disable $canvIdRight $name
            $canvIdRight delete $name
        }
        if { [info exists sPo(zoomPreview)] && [winfo exists $sPo(zoomPreview)] } {
            destroy $sPo(zoomPreview)
        }
    }

    proc UpdateZoomRect { name cx cy sx sy } {
        variable sPo

        wm deiconify $sPo(zoomPreview)
        set size $sPo(zoomRectSize)

        foreach side { "left" "right" } {
            set canvId $sPo(canvId,$side,main)

            if { $canvId ne "" } {
                set px [expr {int([$canvId canvasx $cx] / $sPo(zoom))}]
                set py [expr {int([$canvId canvasy $cy] / $sPo(zoom))}]

                set x1 [expr {($px - $size) * $sPo(zoom)}]
                set y1 [expr {($py - $size) * $sPo(zoom)}]
                set x2 [expr {($px + $size) * $sPo(zoom)}]
                set y2 [expr {($py + $size) * $sPo(zoom)}]

                $canvId raise $name
                $canvId coords $name $x1 $y1 $x2 $y2
                $canvId itemconfigure $name -outline $sPo(zoomRectColor)
            }
        }

        if { [info exists sPo(zoomPreview)] && [winfo exists $sPo(zoomPreview)] } {
            set srcLeft  $sPo(srcImg,left,photo)
            set srcRight $sPo(srcImg,right,photo)
            set dstLeft  $sPo(zoomRect,left,photo)
            set dstRight $sPo(zoomRect,right,photo)
            
            set x1 [expr {($px - $sPo(zoomRectSize))}]
            set y1 [expr {($py - $sPo(zoomRectSize))}]
            set x2 [expr {($px + $sPo(zoomRectSize))}]
            set y2 [expr {($py + $sPo(zoomRectSize))}]
            if { [catch {$dstLeft copy $srcLeft \
                         -from $x1 $y1 $x2 $y2 -to 0 0 \
                         -zoom $sPo(zoomRectFactor)}] } {
                $dstLeft blank
            }
            if { $dstRight ne "" } {
                if { [catch {$dstRight copy $srcRight \
                             -from $x1 $y1 $x2 $y2 -to 0 0 \
                             -zoom $sPo(zoomRectFactor)}] } {
                    $dstRight blank
                }
            }
            scan [wm geometry $sPo(zoomPreview)] "%dx%d" zw zh
            wm geometry $sPo(zoomPreview) \
                [format "+%d+%d" \
                [expr {$sx - $zw/2}] \
                [expr {$sy - $zh - int($sPo(zoomRectSize) * $sPo(zoom)) -1}]]
            raise $sPo(zoomPreview)
            update
        }
        # puts "Frame: [winfo geometry $sPo(zoomPreview).workfr.lfr]"
        # puts "Canvas: [winfo geometry $sPo(zoomPreview).workfr.lfr.canv]"
        # puts "Image: [image width $sPo(zoomRect,left,photo)] [image height $sPo(zoomRect,left,photo)]"
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
            "Size of zoom rectangle (Pixel):" \
            "Zoom factor:" \
            "Color of zoom rectangle:" ] {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Generate right column with entries and buttons.
        set varList [list]

        # ZoomRectangle size
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(zoomRectSize) \
                                    -row $row -width 3 -min 5 -max 30
        
        set tmpList [list [list sPo(zoomRectSize)] [list $sPo(zoomRectSize)]]
        lappend varList $tmpList

        # Zoom factor
        set row 1
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(zoomRectFactor) \
                                    -row $row -width 3 -min 2 -max 8

        set tmpList [list [list sPo(zoomRectFactor)] [list $sPo(zoomRectFactor)]]
        lappend varList $tmpList

        # ZoomRectangle color
        set row 2
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(zoomRectColor)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetZoomRectColor $tw.fr$row.l"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(zoomRectColor)] [list $sPo(zoomRectColor)]]
        lappend varList $tmpList

        return $varList
    }
}

poZoomRect Init
