# Module:         poHistogram
# Copyright:      Paul Obermeier 2013-2020 / paul@poSoft.de
# First Version:  2013 / 10 / 26
#
# Distributed under BSD license.
#
# Module for handling image histograms.

namespace eval poHistogram {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export GetShowHistoTable SetShowHistoTable
    namespace export UpdateHistoLines
    namespace export ChangeHistoType
    namespace export ShowHistoWin CloseHistoWin CloseAllHistoWin
    namespace export SaveHistogramValues

    proc Init {} {
        variable ns
        variable sPo

        set sPo(winNum) 0
        set sPo(showHistoTable) 1
        set sPo(lastDir) [pwd]
    }

    proc GetShowHistoTable {} {
        variable sPo

        return $sPo(showHistoTable)
    }

    proc SetShowHistoTable { onOff } {
        variable sPo

        set sPo(showHistoTable) $onOff
    }

    proc CloseHistoWin { winNum } {
        variable sPo

        if { ! [info exists sPo($winNum,toplevel)] } {
            # Already destroyed internally
            return
        }
        if { $sPo($winNum,toplevel) ne "" } {
            catch { destroy $sPo($winNum,toplevel) }
            unset sPo($winNum,toplevel)
        }
        image delete $sPo($winNum,photoId)
        unset sPo($winNum,photoId)
        foreach key [array names sPo "$winNum,*,*,*"] {
            unset sPo($key)
        }
    }

    proc CloseAllHistoWin { { groupName "" } } {
        variable sPo

        foreach key [array names sPo "*,toplevel"] {
            if { $sPo($key) ne "" } {
                # Only close toplevel windows, no embedded histogram frames.
                set winNum [lindex [split $key ","] 0]
                if { $groupName eq "" || $sPo($winNum,groupName) eq $groupName } {
                    CloseHistoWin $winNum
                }
            }
        }
    }

    proc SelectHistoVal { tableId x y } {
        set rowInd [poMisc Min $x 255]
        $tableId selection clear 0 end
        $tableId selection set $rowInd
        $tableId activate $rowInd
        $tableId see $rowInd
    }

    proc ShowHistoVal { winNum tableId } {
        variable ns

        set indList [$tableId curselection]
        if { [llength $indList] == 0 } {
            return
        }
        set rowNum [lindex $indList 0]
        PrintHistoVal $winNum $rowNum
    }


    proc PrintHistoVal { winNum x } {
        variable sPo

        set sx [poMisc Min $x 255]
        set numImgs $sPo($winNum,numImgs)
        for { set imgNum 0 } { $imgNum < $numImgs } { incr imgNum } {
            foreach color { "red" "green" "blue" } {
                set canvasId $sPo($winNum,$imgNum,$color,canvasId)
                if { [info exists sPo($winNum,$imgNum,histoDict)] && [winfo exists $canvasId] } {
                    set histoList [dict get $sPo($winNum,$imgNum,histoDict) $color]
                    set val [lindex $histoList $sx]
                    $canvasId raise value
                    $canvasId itemconfigure value -text \
                              [format "Intensity %3d: %d values" $sx $val]
                    $canvasId itemconfigure "line" -fill $color
                    $canvasId itemconfigure "line_$sx" -fill black
                }
            }
        }
    }

    proc DrawHistoLines { winNum histoType tw tableId } {
        variable ns
        variable sPo

        set hw 256
        set hh [poImgAppearance GetHistogramHeight]
        set numImgs $sPo($winNum,numImgs)

        set col 1
        for { set imgNum 0 } { $imgNum < $numImgs } { incr imgNum } {
            set histoDict $sPo($winNum,$imgNum,histoDict)
            if { [poImgAppearance UsePoImg] } {
                set scaledDict [poImgUtil ScaleHistogram $histoDict $hh $histoType]
            } else  {
                set scaledDict [poPhotoUtil ScaleHistogram $histoDict $hh $histoType]
            }
            foreach color { "red" "green" "blue" } {
                set histoList  [dict get $histoDict $color]
                set scaledList [dict get $scaledDict $color]
                set canvName $tw.workfr.cfr.c_${col}_${color}
                # Delete lines from a previous histogram
                $canvName delete "line"
                for { set i 0 } { $i < $hw } { incr i } {
                    set val [lindex $scaledList $i]
                    $canvName create line $i $hh $i [expr {$hh-$val}] -fill $color \
                              -tags [list "line" "line_$i"]
                }
                $canvName raise histo
                $canvName bind histo <Motion> "${ns}::PrintHistoVal $winNum %x"
                $canvName bind histo <ButtonRelease-1> "${ns}::SelectHistoVal $tableId %x %y"
            }
            incr col
        }
    }

    proc UpdateHistoLines { winNum numMarkLines adjustColor } {
        variable sPo

        set numImgs $sPo($winNum,numImgs)

        set col 1
        for { set imgNum 0 } { $imgNum < $numImgs } { incr imgNum } {
            foreach color { "red" "green" "blue" } {
                set canvName $sPo($winNum,tw).workfr.cfr.c_${col}_${color}
                set histoDict $sPo($winNum,$imgNum,histoDict)
                set histoList  [dict get $histoDict $color]
                for { set i 0 } { $i <= $numMarkLines } { incr i } {
                    $canvName itemconfigure "line_$i" -fill $adjustColor
                }
                for { set i [expr {$numMarkLines +1}] } { $i < 256 } { incr i } {
                    $canvName itemconfigure "line_$i" -fill $color
                }
            }
            incr col
        }
    }

    proc ChangeHistoType { winNum histoType } {
        variable sPo

        DrawHistoLines $winNum $histoType $sPo($winNum,tw) $sPo($winNum,tableId)
        set sPo(histoType) $histoType
        poImgAppearance SetHistogramType $histoType
    }

    proc ToggleHistoTable {} {
        variable sPo

        if { ! $sPo(showHistoTable) } {
            pack forget $sPo(tableFr)
        } else {
            pack $sPo(tableFr) -side left -fill both -expand true
        }
    }

    proc ShowHistoWin { fr histoType imgList descrList { groupName "" } } {
        variable sPo
        variable ns

        set winNum $sPo(winNum)
        incr sPo(winNum)

        if { [winfo exists $fr] && [string match -nocase "*frame" [winfo class $fr]] } {
            set tw $fr
            set sPo($winNum,toplevel) ""
        } else {
            set tw .poHistogram_win_$winNum
            if { [winfo exists $tw] } {
                destroy $tw
            }
            toplevel $tw
            wm title $tw $fr
            focus $tw
            set sPo($winNum,toplevel) $tw
        }
        set sPo($winNum,tw) $tw
        set sPo($winNum,groupName) $groupName

        ttk::frame $tw.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.workfr
        pack $tw.toolfr -side top -fill x -anchor w
        pack $tw.workfr -side top -fill both -expand 1

        set sPo(tableFr) $tw.workfr.tfr
        ttk::frame $tw.workfr.cfr
        ttk::frame $sPo(tableFr)
        pack $tw.workfr.cfr -side left -fill both
        pack $sPo(tableFr) -side left -fill both -expand true

        if { ! $sPo(showHistoTable) } {
            pack forget $sPo(tableFr)
        }

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::save] \
                  "${ns}::AskSaveHistogramValues $winNum" "Save histogram table to CSV file"
        if { [poApps HavePkg "cawt"] } {
            poToolbar AddButton $toolfr [::poBmpData::sheetIn] \
                      "${ns}::HistogramValuesToExcel $winNum" "Load histogram table to Excel"
        }

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        set sPo(histoType) $histoType
        poToolbar AddRadioButton $toolfr [::poBmpData::histolog] \
                  "${ns}::ChangeHistoType $winNum log" "Show logarithmic histogram (Ctrl+H)" \
                  -variable ${ns}::sPo(histoType) -value log
        poToolbar AddRadioButton $toolfr [::poBmpData::histo] \
                  "${ns}::ChangeHistoType $winNum lin" "Show linear histogram (Ctrl+Shift+H)" \
                  -variable ${ns}::sPo(histoType) -value lin

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::sheet] \
                  "${ns}::ToggleHistoTable" "Toggle display of histogram table" \
                  -variable ${ns}::sPo(showHistoTable)

        bind $tw <Control-h> "${ns}::ChangeHistoType $winNum log"
        bind $tw <Control-H> "${ns}::ChangeHistoType $winNum lin"

        set hw 256
        set hh [poImgAppearance GetHistogramHeight]

        set numImgs [llength $imgList]
        set sPo($winNum,numImgs) $numImgs

        set columnStr "0 # right "
        for { set imgNum 0 } { $imgNum < $numImgs } { incr imgNum } {
            append columnStr "0 R center  0 G center  0 B center "
        }

        # Create a tablelist for the histogram values.
        set tableId [poWin CreateScrolledTablelist $sPo(tableFr) true "Histogram values" \
                    -columns $columnStr \
                    -exportselection false \
                    -stretch all \
                    -setfocus 1 \
                    -width 0 \
                    -selectmode browse \
                    -stripebackground [poAppearance GetStripeColor] \
                    -showseparators yes]
        bind $tableId <<ListboxSelect>> "${ns}::ShowHistoVal $winNum %W"
        set sPo($winNum,tableId) $tableId

        # Create the labels and canvas for graphical display of histogram.
        ttk::label $tw.workfr.cfr.fill
        grid $tw.workfr.cfr.fill -row 0 -column 0 -sticky news
        set col 1
        foreach descr $descrList {
            ttk::label $tw.workfr.cfr.descr_$col -text $descr -anchor center
            grid $tw.workfr.cfr.descr_$col -row 0 -column $col -sticky news
            incr col
        }

        set photoId [image create photo -width $hw -height $hh]
        set sPo($winNum,photoId) $photoId
        $photoId blank
        set row 1
        foreach color { "red" "green" "blue" } {
            ttk::label $tw.workfr.cfr.c$color -text $color
            grid $tw.workfr.cfr.c$color -row $row -column 0 -ipadx 2 -ipady 2 -sticky news
            set imgNum 0
            for { set col 1 } { $col <= $numImgs } { incr col } {
                set canvName $tw.workfr.cfr.c_${col}_${color}
                set sPo($winNum,$imgNum,$color,canvasId) $canvName
                canvas $canvName -width $hw -height $hh -borderwidth 0 -highlightthickness 0
                grid $canvName -row $row -column $col -ipadx 2 -ipady 2 -sticky news
                $canvName create rectangle 0 0 $hw $hh -fill white
                $canvName create text 10 10 -anchor nw -tag value
                $canvName create image 0 0 -anchor nw -tags histo -image $photoId
                set sPo($col,$color,histocanvas) $canvName
                incr imgNum
            }
            incr row
        }

        set rowMin $row
        set rowMax [expr $rowMin + 1]
        for { set col 1 } { $col <= $numImgs } { incr col } {
            ttk::label $tw.workfr.cfr.min_$col -anchor w
            ttk::label $tw.workfr.cfr.max_$col -anchor w
            grid $tw.workfr.cfr.min_$col -row $rowMin -column $col -ipadx 2 -ipady 2 -sticky news
            grid $tw.workfr.cfr.max_$col -row $rowMax -column $col -ipadx 2 -ipady 2 -sticky news
        }

        set imgNum 0
        set col    1
        foreach img $imgList descr $descrList {
            if { [poImgAppearance UsePoImg] } {
                if { [poImgMisc IsPhoto $img] } {
                    # puts "Copying photo to poImage"
                    set poImg [poImage NewImageFromPhoto $img]
                } else {
                    set poImg $img
                }
                $poImg GetImgInfo w h a g
                set sPo($winNum,$imgNum,histoDict) [poImgUtil Histogram $poImg $descr]
                set statDict($imgNum)   [poImgUtil GetImgStats $poImg true 0 0 $w $h]
                if { [poImgMisc IsPhoto $img] } {
                    poImgUtil DeleteImg $poImg
                }
            } else  {
                set w [image width  $img]
                set h [image height $img]
                set sPo($winNum,$imgNum,histoDict) [poPhotoUtil Histogram $img $descr]
                set statDict($imgNum) [poPhotoUtil GetImgStats $img true 0 0 $w $h]
            }
            set minRed   [dict get $statDict($imgNum) min red  ]
            set minGreen [dict get $statDict($imgNum) min green]
            set minBlue  [dict get $statDict($imgNum) min blue ]
            set maxRed   [dict get $statDict($imgNum) max red  ]
            set maxGreen [dict get $statDict($imgNum) max green]
            set maxBlue  [dict get $statDict($imgNum) max blue ]
            set minStr [format "Minimum: (%d, %d, %d)" $minRed $minGreen $minBlue]
            set maxStr [format "Maximum: (%d, %d, %d)" $maxRed $maxGreen $maxBlue]

            $tw.workfr.cfr.min_$col configure -text $minStr
            $tw.workfr.cfr.max_$col configure -text $maxStr

            incr imgNum
            incr col
        }

        # Insert histogram values as vertical lines into the canvases.
        DrawHistoLines $winNum $histoType $tw $tableId

        # Insert histogram values into the tablelist.
        set numDiffValues 0
        for { set i 0 } { $i < 256 } { incr i } {
            set rowList [list $i]
            for { set imgNum 0 } { $imgNum < $numImgs } { incr imgNum } {
                foreach color { "red" "green" "blue" } {
                    set histoList [dict get $sPo($winNum,$imgNum,histoDict) $color]
                    lappend rowList [lindex $histoList $i]
                }
            }
            $tableId insert end $rowList

            if { $numImgs > 1 } {
                # Check, if the histogram values differ. Note, that list index 0
                # contains the row number.
                if { [lindex $rowList 1] != [lindex $rowList 4] || \
                     [lindex $rowList 2] != [lindex $rowList 5] || \
                     [lindex $rowList 3] != [lindex $rowList 6] } {
                    incr numDiffValues
                    $tableId rowconfigure end -foreground "red"
                    $tableId rowconfigure end -background "lightblue"
                }
            }
        }
        set titleStr "Histogram values"
        if { $numImgs > 1 } {
            if { $numDiffValues > 0 } {
                set titleStr [format "Histogram values (%s different)" $numDiffValues]
            } else {
                set titleStr "Histogram values (all identical)"
            }
        }
        poWin SetScrolledTitle $tableId $titleStr

        if { $sPo($winNum,toplevel) ne "" } {
            bind $tw <KeyPress-Escape> "${ns}::CloseHistoWin $winNum"
            wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseHistoWin $winNum"
        }
        $tw config -cursor crosshair
        poImgAppearance SetHistogramType $histoType
        return $winNum
    }

    proc AskSaveHistogramValues { winNum { initFile "histogram.csv" } } {
        variable ns
        variable sPo

        set fileTypes {
            {"CSV files" ".csv"}
            {"All files" "*"}
        }

        if { ! [info exists sPo(LastHistoType)] } {
            set sPo(LastHistoType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastHistoType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save histogram to CSV file" \
                     -parent $sPo($winNum,toplevel) \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sPo(LastHistoType) \
                     -initialfile [file tail $initFile] \
                     -initialdir $sPo(lastDir)]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sPo(LastHistoType)]
            if { $ext ne "*" } {
                append fileName $ext
            }
        }
        if { [file exists $fileName] } {
            set retVal [tk_messageBox \
                -message "File \"[file tail $fileName]\" already exists.\n\
                         Do you want to overwrite it?" \
                -title "Save confirmation" -type yesno -default no -icon info]
            if { $retVal eq "no" } {
                set fileName ""
            }
        }

        if { $fileName ne "" } {
            set sPo(lastDir) [file dirname $fileName]
            foreach key [array names sPo "$winNum,*,histoDict"] {
                lappend histoDictList $sPo($key)
            }
            eval SaveHistogramValues $fileName $histoDictList
        }
    }

    proc HistogramValuesToExcel { winNum } {
        variable sPo

        set appId [::Excel::Open true]
        set workbookId [::Excel::AddWorkbook $appId]
        set worksheetId [::Excel::GetWorksheetIdByIndex $workbookId 1]
        ::Excel::SetWorksheetName $worksheetId "Histogram"

        foreach key [array names sPo "$winNum,*,histoDict"] {
            lappend histoDictList $sPo($key)
        }
        foreach dictionary $histoDictList {
            set descr [dict get $dictionary "description"]
            lappend descrList $descr
            set histoDict($descr) $dictionary
        }
        set colorList [list "red" "green" "blue"]
        # Write header line with column names.
        foreach descr $descrList {
            foreach color $colorList {
                lappend headerList [format "%s(%s)" $descr [string totitle $color]]
            }
        }
        ::Excel::SetHeaderRow $worksheetId $headerList

        set rangeId [::Excel::SelectRangeByIndex $worksheetId 2 1 257 [llength $colorList]]
        ::Excel::SetRangeFormat $rangeId "int"

        # Write values.
        set row 2
        for { set i 0 } { $i < 256 } { incr i } {
            set rowList [list]
            foreach descr $descrList {
                foreach color $colorList {
                    set histoList [dict get $histoDict($descr) $color]
                    lappend rowList [expr { int ([lindex $histoList $i]) }]
                }
            }
            ::Excel::SetRowValues $worksheetId $row $rowList
            incr row
        }
        ::Excel::FreezePanes $worksheetId 1 0
    }

    # Save the values of supplied histogram dicts into CSV file "csvFileName".
    proc SaveHistogramValues { csvFileName args  } {
        foreach dictionary $args {
            set descr [dict get $dictionary "description"]
            lappend descrList $descr
            set histoDict($descr) $dictionary
        }
        set colorList [list "red" "green" "blue"]

        set retVal [catch {open $csvFileName w} fp]
        if { $retVal != 0 } {
            error "Can't write histogram values to CSV file $csvFileName ($fp)"
        }

        # Write header line with column names.
        puts -nonewline $fp "Index"
        foreach descr $descrList {
            foreach color $colorList {
                puts -nonewline $fp [format ";%s(%s)" $descr [string totitle $color]]
            }
        }
        puts $fp ""

        # Write values.
        for { set i 0 } { $i < 256 } { incr i } {
            puts -nonewline $fp "$i"
            foreach descr $descrList {
                foreach color $colorList {
                    set histoList [dict get $histoDict($descr) $color]
                    puts -nonewline $fp ";[lindex $histoList $i]"
                }
            }
            puts $fp ""
        }
        close $fp
    }
}

poHistogram Init
