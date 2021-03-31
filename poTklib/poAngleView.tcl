# Module:         poAngleView
# Copyright:      Paul Obermeier 2016-2020 / paul@poSoft.de
# First Version:  2016 / 05 / 02
#
# Distributed under BSD license.
#
# Widget to visualize Euler angles.

namespace eval poAngleView {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export Create Update

    proc Init {} {
        variable ns
        variable sPo

        set sPo(lastDir) [pwd]
        set sPo(angleWin,x) 300
        set sPo(angleWin,y) 30
    }

    proc _CreateCross { canv size name arrowHoriz labelHoriz arrowVert labelVert } {
        set size2 [expr $size / 2]
        set off 20
        set textOff 10

        $canv create text 1 1 -fill black -anchor nw -tags $name

        set ty [expr $size2 - $textOff]
        if { $arrowHoriz == "right" } {
            set tx [expr $size - $textOff]
            set anchor "e"
            set where "last"
        } else {
            set tx $textOff
            set anchor "w"
            set where "first"
        }
        $canv create line $off $size2 [expr $size - $off] $size2 -fill black -arrow $where
        $canv create text $tx $ty -fill black -text $labelHoriz -anchor $anchor

        set tx [expr $size2 + $textOff]
        if { $arrowVert == "down" } {
            set ty [expr $size - $textOff]
            set anchor "sw"
            set where "last"
        } else {
            set ty $textOff
            set anchor "nw"
            set where "first"
        }
        $canv create line $size2 $off $size2 [expr $size - $off] -fill black -arrow $where
        $canv create text $tx $ty -fill black -text $labelVert
    }

    proc Update { headDeg pitchDeg rollDeg } {
        variable sPo

        set size2 [expr { $sPo(angleCanvSize) / 2 }]
        set size4 [expr { $sPo(angleCanvSize) / 4 }]

        set headRad [poMisc DegToRad [expr { $headDeg - 90.0 }]]
        set p1x [expr { int (cos ($headRad) * $size4) }]
        set p1y [expr { int (sin ($headRad) * $size4) }]
        set p2x [expr { -1 * $p1x }]
        set p2y [expr { -1 * $p1y }]
        $sPo(headCanv) coords HEADING [expr { $p2x + $size2 }] [expr { $p2y + $size2 }] \
                                      [expr { $p1x + $size2 }] [expr { $p1y + $size2 }]
        set headDeg [format "%.2f°" $headDeg]
        $sPo(headCanv) itemconfigure HEADING_TEXT -text "Head: $headDeg"

        set pitchRad [poMisc DegToRad $pitchDeg]
        set p1x [expr { int (cos ($pitchRad) * $size4) }]
        set p1y [expr { int (sin ($pitchRad) * $size4) }]
        set p2x [expr { -1 * $p1x }]
        set p2y [expr { -1 * $p1y }]
        $sPo(pitchCanv) coords PITCH [expr { $p2x + $size2 }] [expr { $p2y + $size2 }] \
                                     [expr { $p1x + $size2 }] [expr { $p1y + $size2 }]
        set pitchDeg [format "%.2f°" $pitchDeg]
        $sPo(pitchCanv) itemconfigure PITCH_TEXT -text "Pitch: $pitchDeg"

        set rollRad [poMisc DegToRad $rollDeg]
        set p1x [expr { int (cos ($rollRad) * $size4) }]
        set p1y [expr { int (sin ($rollRad) * $size4) }]
        set p2x [expr { -1 * $p1x }]
        set p2y [expr { -1 * $p1y }]
        $sPo(rollCanv) coords ROLL [expr { $p2x + $size2 }] [expr { $p2y + $size2 }] \
                                   [expr { $p1x + $size2 }] [expr { $p1y + $size2 }]
        set rollDeg [format "%.2f°" $rollDeg]
        $sPo(rollCanv) itemconfigure ROLL_TEXT -text "Roll: $rollDeg"
    }

    proc Create {} {
        variable sPo

        set tw .mdsViewer_angleViewWin

        if { [winfo exists $tw] } {
            ::poWin::Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Angle Viewer"
        wm resizable $tw false false
        wm geometry $tw [format "+%d+%d" $sPo(angleWin,x) $sPo(angleWin,y)]
        
        set sPo(angleViewWin) $tw
        frame $tw.headfr  -relief sunken -borderwidth 1
        frame $tw.pitchfr -relief sunken -borderwidth 1
        frame $tw.rollfr  -relief sunken -borderwidth 1
        frame $tw.fr
        pack $tw.headfr  -side top
        pack $tw.pitchfr -side top
        pack $tw.rollfr  -side top
        pack $tw.fr -side top -expand 1 -fill x

        set sPo(angleCanvSize) 200
        set sPo(headCanv)  $tw.headfr.c
        set sPo(pitchCanv) $tw.pitchfr.c
        set sPo(rollCanv)  $tw.rollfr.c
        canvas $sPo(headCanv)  -width $sPo(angleCanvSize) -height $sPo(angleCanvSize)
        canvas $sPo(pitchCanv) -width $sPo(angleCanvSize) -height $sPo(angleCanvSize)
        canvas $sPo(rollCanv)  -width $sPo(angleCanvSize) -height $sPo(angleCanvSize)
        pack $sPo(headCanv) 
        pack $sPo(pitchCanv) 
        pack $sPo(rollCanv) 

        _CreateCross $sPo(headCanv)  $sPo(angleCanvSize) "HEADING_TEXT" "right" "East"  "up"   "North"
        _CreateCross $sPo(pitchCanv) $sPo(angleCanvSize) "PITCH_TEXT"   "right" "North" "down" "Down"
        _CreateCross $sPo(rollCanv)  $sPo(angleCanvSize) "ROLL_TEXT"    "right" "East"  "down" "Down"

        set size2 [expr { $sPo(angleCanvSize) / 2 }]
        set size4 [expr { $sPo(angleCanvSize) / 4 }]

        $sPo(headCanv)  create line $size2 [expr 3 * $size4] $size2 $size4 \
                        -fill red -arrow last -width 1 -tags HEADING
        $sPo(pitchCanv) create line $size4 $size2 [expr 3 * $size4] $size2 \
                        -fill red -arrow last -width 1 -tags PITCH
        $sPo(rollCanv)  create line $size4 $size2 [expr 3 * $size4] $size2 \
                        -fill red -arrow none -width 1 -tags ROLL
        $sPo(rollCanv)  create oval [expr $size2 -20] [expr $size2 -20] \
                                    [expr $size2 +20] [expr $size2 +20] \
                                    -outline red -width 2
    }
}

poAngleView Init
