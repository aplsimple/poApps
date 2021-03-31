# Module:         poWinInfo
# Copyright:      Paul Obermeier 2013-2020 / paul@poSoft.de
# First Version:  2013 / 08 / 26
#
# Distributed under BSD license.

namespace eval poWinInfo {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Create SetTitle Clear
    namespace export UpdateImgInfo UpdateFileInfo Update

    # Internal helper procedure to get image statistics.
    proc _GetImgStats { phImg poImg calcStdDev x1 y1 x2 y2 } {
        poWatch Start _poWinInfoSwatch
        set delPoImg false
        if { [poImgAppearance UsePoImg] } {
            if { $poImg eq "" } {
                set poImg [poImage NewImageFromPhoto $phImg]
                set delPoImg true
            }
            set statDict [poImgUtil GetImgStats $poImg $calcStdDev $x1 $y1 $x2 $y2]
            if { $delPoImg } {
                poImgUtil DeleteImg $poImg
            }
        } else {
            set statDict [poPhotoUtil GetImgStats $phImg $calcStdDev $x1 $y1 $x2 $y2]
        }
        poLog Info [format "%.2f sec: Calculate image statistics" [poWatch Lookup _poWinInfoSwatch]]
        return $statDict
    }

    # Create a megawidget for file or image information display.
    # "masterFr" is the frame, where the components of the megawidgets are placed.
    # "title" is an optional string displayed as title of the info widget.
    # Return an identifier for the new info widget.
    proc Create { masterFr { title "Image information" } } {
        set tableId [poWin CreateScrolledTablelist $masterFr true $title \
                    -exportselection false \
                    -columns { 0 "Attribute" "left"
                               0 "Value"     "left" } \
                    -stretch 1 \
                    -showlabels 0 \
                    -takefocus 0 \
                    -stripebackground [poAppearance GetStripeColor] \
                    -showseparators 1]
        $tableId columnconfigure 0 -editable false
        $tableId columnconfigure 1 -editable false
        return $tableId
    }

    proc SetTitle { w title } {
        poWin SetScrolledTitle $w $title
    }

    proc Update { w attrList valList } {
        $w delete 0 end
        foreach attr $attrList val $valList {
            $w insert end [list $attr $val]
        }
    }

    proc Clear { w } {
        Update $w [list] [list]
    }

    proc UpdateImgInfo { w phImg { poImg "" } { rawDict "" } } {
        set imgWidth  [image width  $phImg]
        set imgHeight [image height $phImg]

        set minRaw ""
        set maxRaw ""
        set medRaw ""
        set stdRaw ""
        if { $rawDict ne "" } {
            set minRaw "Raw: [poImgDict GetMinValueAsString  rawDict] "
            set maxRaw "Raw: [poImgDict GetMaxValueAsString  rawDict] "
            set medRaw "Raw: [poImgDict GetMeanValueAsString rawDict] "
            set stdRaw "Raw: [poImgDict GetStdDevAsString    rawDict] "
        }
        set statDict [_GetImgStats $phImg $poImg true 0 0 $imgWidth $imgHeight]
        set minRed   [dict get $statDict min red  ]
        set minGreen [dict get $statDict min green]
        set minBlue  [dict get $statDict min blue ]
        set maxRed   [dict get $statDict max red  ]
        set maxGreen [dict get $statDict max green]
        set maxBlue  [dict get $statDict max blue ]
        set medRed   [dict get $statDict mean red  ]
        set medGreen [dict get $statDict mean green]
        set medBlue  [dict get $statDict mean blue ]
        set stdRed   [dict get $statDict std red  ]
        set stdGreen [dict get $statDict std green]
        set stdBlue  [dict get $statDict std blue ]
        set pixCount [dict get $statDict num]
        lappend valList [format "%d" $imgWidth]
        lappend valList [format "%d" $imgHeight]
        lappend valList [format "%d" $pixCount]
        lappend valList [format "%s(%d, %d, %d)" $minRaw $minRed $minGreen $minBlue]
        lappend valList [format "%s(%d, %d, %d)" $maxRaw $maxRed $maxGreen $maxBlue]
        lappend valList [format "%s(%.3f, %.3f, %.3f)" $medRaw $medRed $medGreen $medBlue]
        lappend valList [format "%s(%.3f, %.3f, %.3f)" $stdRaw $stdRed $stdGreen $stdBlue]
        if { [poImgType HaveDpiSupport] } {
            set dpis [poImgType GetResolution $phImg]
            set xdpi [lindex $dpis 0]
            set ydpi [lindex $dpis 1]
            lappend valList [format "(%.0f, %.0f)" $xdpi $ydpi]
        }

        set attrList [poPhotoUtil GetImgStatsLabels 2]
        Update $w $attrList $valList
    }

    proc UpdateFileInfo { w fileName { showImgSize false } } {
        set attrList    [poMisc GetFileInfoLabels]
        set attrValList [poMisc FileInfo $fileName $showImgSize]
        if { [llength $attrValList] == 0 } {
            foreach entry $attrList {
                lappend valList ""
            }
            lset valList 0 [file tail $fileName]
            lset valList 1 [file nativename [file dirname $fileName]]

        } else {
            foreach entry $attrValList {
                lappend valList [lindex $entry 1]
            }
        }
        Update $w $attrList $valList
    }
}
