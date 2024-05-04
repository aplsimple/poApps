# Module:         poWinInfo
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2013 / 08 / 26
#
# Distributed under BSD license.

namespace eval poWinInfo {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Create CreateInfoFrame 
    namespace export CreateInfoWin DeleteInfoWin
    namespace export SetTitle Clear
    namespace export UpdateImgInfo UpdateFileInfo

    proc _Init {} {
        variable sett

        set sett(InfoWinNum) 1
        SetWindowPos 30 30 500 300
    }

    proc SetWindowPos { x y w h } {
        variable sett

        set sett(win,x) $x
        set sett(win,y) $y
        set sett(win,w) $w
        set sett(win,h) $h
    }

    proc GetWindowPos {} {
        variable sett

        if { [info exists sett(win,name)] && \
            [winfo exists $sett(win,name)] } {
            scan [wm geometry $sett(win,name)] "%dx%d+%d+%d" w h x y
        } else {
            set x $sett(win,x)
            set y $sett(win,y)
            set w $sett(win,w)
            set h $sett(win,h)
        }
        return [list $x $y $w $h]
    }

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

    proc _TabChanged { nbId masterFr fileOrDirName } {
        variable sett

        set tabId [$nbId select]
        set tabTitle [$nbId tab $tabId -text]
        if { $tabTitle eq "Preview" } {
            poWinPreview Update $sett($masterFr,previewFrame) $fileOrDirName true
        }
    }

    proc CreateInfoFrame { masterFr fileOrDirName { selectTab "File" } } {
        variable ns
        variable sett

        # If fileOrDirName is a directory, just show the number
        # of sub-directories and files.
        if { [file isdirectory $fileOrDirName] } {
            set name [file tail $fileOrDirName]
            set dirInfo [poMisc CountDirsAndFiles $fileOrDirName]
            set msgStr "Directory $name: [lindex $dirInfo 0] subdirs, [lindex $dirInfo 1] files"
            ttk::label $masterFr.l -text $msgStr
            pack $masterFr.l -fill both -expand true
            return
        }

        set haveImage     false
        set haveMultiPage false
        set haveExif      false
        set imgFmt        ""

        if { [poImgMisc IsImageFile $fileOrDirName] } {
            set haveImage true
        }

        # Check, if we have an image with multiple pages or EXIF information.
        if { $haveImage } {
            set typeDict [poType GetFileType $fileOrDirName]
            if { [dict exists $typeDict fmt] } {
                set fmt [string tolower [dict get $typeDict fmt]]
                set numImgs [poImgPages GetNumPages $fileOrDirName]
                if { $numImgs > 1 } {
                    set haveMultiPage true
                }
                switch -exact -- $fmt {
                    "graphic" {
                        if { [dict exists $typeDict subfmt] } {
                            set subfmt [string tolower [dict get $typeDict subfmt]]
                            switch -exact -- $subfmt {
                                "jpeg" {
                                    if { [dict exists $typeDict imgsubfmt] && \
                                         [dict get $typeDict imgsubfmt] eq "exif" } {
                                        set haveExif true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        set nbId $masterFr.nb
        ttk::notebook $nbId -style Hori.TNotebook
        pack $nbId -fill both -expand true -padx 2 -pady 3
        ttk::notebook::enableTraversal $nbId

        set selTabInd 0
        set curTabInd 0

        set fileFr $nbId.fileFr
        ttk::frame $fileFr
        pack $fileFr -expand true -fill both
        $nbId add $fileFr -text "File"
        set sett($masterFr,fileInfoFrame) [poWinInfo Create $fileFr ""]
        poWinInfo UpdateFileInfo $sett($masterFr,fileInfoFrame) $fileOrDirName
        if { $selectTab eq "File" } {
            set selTabInd $curTabInd
        }
        incr curTabInd

        if { $haveImage } {
            set imgFr $nbId.imgFr
            ttk::frame $imgFr
            pack $imgFr -expand true -fill both
            $nbId add $imgFr -text "Image"
            set sett($masterFr,imgInfoFrame) [poWinInfo Create $imgFr ""]
            poWinInfo UpdateImgInfo $sett($masterFr,imgInfoFrame) $fileOrDirName
            if { $selectTab eq "Image" } {
                set selTabInd $curTabInd
            }
            incr curTabInd
        }

        if { $haveMultiPage } {
            set pageFr $nbId.pageFr
            ttk::frame $pageFr
            pack $pageFr -expand true -fill both
            $nbId add $pageFr -text "Pages"
            set sett($masterFr,pageInfoFrame) [poImgPages Create $pageFr ""]
            poImgPages Update $sett($masterFr,pageInfoFrame) $fileOrDirName
        } else {
            set previewFr $nbId.previewFr
            ttk::frame $previewFr
            pack $previewFr -expand true -fill both
            $nbId add $previewFr -text "Preview"
            set sett($masterFr,previewFrame) [poWinPreview Create $previewFr ""]
            $nbId select $curTabInd
            update
            poWinPreview Update $sett($masterFr,previewFrame) $fileOrDirName
        }
        if { $selectTab eq "Preview" || $selectTab eq "Pages" } {
            set selTabInd $curTabInd
        }
        incr curTabInd

        if { $haveExif } {
            set exifFr $nbId.exifFr
            ttk::frame $exifFr
            pack $exifFr -expand true -fill both
            $nbId add $exifFr -text "EXIF"
            poImgExif ShowExifDetail $exifFr $fileOrDirName
            if { $selectTab eq "EXIF" } {
                set selTabInd $curTabInd
            }
            incr curTabInd
        }
        $nbId select $selTabInd
        bind $nbId <<NotebookTabChanged>> [list ${ns}::_TabChanged $nbId $masterFr $fileOrDirName]
    }

    proc _DestroyInfoWin { tw args } {
        variable sett

        if { [winfo exists $tw] } {
            SetWindowPos {*}[GetWindowPos]
        }
        # Call the Clear methods of the frames displaying images,
        # so that the images are freed.
        foreach fr $args {
            if { [info exists sett($fr,previewFrame)] } {
                poWinPreview Clear $sett($fr,previewFrame)
            }
            if { [info exists sett($fr,pageInfoFrame)] } {
                poImgPages Clear $sett($fr,pageInfoFrame)
            }
        }
        destroy $tw
    }

    proc CreateInfoWin { fileOrDirName1 args } {
        variable ns
        variable sett

        set opts [dict create \
            -file ""     \
            -tab  "File" \
        ]

        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                if { $value eq "" } {
                    error "CreateInfoWin: No value specified for key \"$key\""
                }
                dict set opts $key $value
            } else {
                error "CreateInfoWin: Unknown option \"$key\" specified"
            }
        }

        set fileOrDirName2 [dict get $opts "-file"]
        set selectTab      [dict get $opts "-tab"]

        set tw .poWinInfo_InfoWin$sett(InfoWinNum)
        incr sett(InfoWinNum)
        toplevel $tw
        if { $fileOrDirName2 ne "" } {
            wm title $tw "Info: [poAppearance CutFilePath $fileOrDirName1] vs. [poAppearance CutFilePath $fileOrDirName2]"
        } else {
            wm title $tw "Info: [poAppearance CutFilePath $fileOrDirName1]"
        }
        wm resizable $tw true true
        set sett(win,name) $tw
        wm geometry $sett(win,name) [format "%dx%d+%d+%d" \
                    $sett(win,w) $sett(win,h) $sett(win,x) $sett(win,y)]

        set fr $tw.fr
        ttk::frame $fr
        pack $fr -fill both -expand true

        ttk::frame $fr.left
        pack $fr.left -fill both -expand true -side left
        if { $fileOrDirName2 ne "" } {
            ttk::frame $fr.right
            pack $fr.right -fill both -expand true -side left
        }
        update

        CreateInfoFrame $fr.left $fileOrDirName1 $selectTab
        lappend sett($tw) $fr.left
        if { $fileOrDirName2 ne "" } {
            CreateInfoFrame $fr.right $fileOrDirName2 $selectTab
            lappend sett($tw) $fr.right
        }

        bind $tw <Escape> "${ns}::_DestroyInfoWin $tw $fr.left $fr.right"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::_DestroyInfoWin $tw $fr.left $fr.right"
        focus $tw
        return $tw
    }

    proc DeleteInfoWin { w } {
        variable sett

        if { [info exists sett($w)] } {
            _DestroyInfoWin $w {*}$sett($w)
        }
    }

    proc SetTitle { w title } {
        poWin SetScrolledTitle $w $title
    }

    proc _Update { w attrList valList } {
        $w delete 0 end
        foreach attr $attrList val $valList {
            $w insert end [list $attr $val]
        }
    }

    proc Clear { w } {
        _Update $w [list] [list]
    }

    proc UpdateImgInfo { w imgFile { phImg "" } { poImg "" } { rawDict "" } } {
        set createdNewImg false
        if { $phImg eq "" } {
            set ext [file extension $imgFile]
            set fmtStr [poImgType GetFmtByExt $ext]
            set optStr [poImgType GetOptByFmt $fmtStr "read"]
            set retVal [catch { poImgMisc LoadImg $imgFile $optStr } imgDict]
            if { $retVal == 0 } {
                set phImg [dict get $imgDict phImg]
                set createdNewImg true
            } else {
                return
            }
        }
        set imgWidth  [image width  $phImg]
        set imgHeight [image height $phImg]

        set minRaw ""
        set maxRaw ""
        set medRaw ""
        set stdRaw ""
        if { $rawDict ne "" } {
            set minRaw "Raw: [pawt GetImageMinAsString    rawDict] "
            set maxRaw "Raw: [pawt GetImageMaxAsString    rawDict] "
            set medRaw "Raw: [pawt GetImageMeanAsString   rawDict] "
            set stdRaw "Raw: [pawt GetImageStdDevAsString rawDict] "
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
        lappend valList [poImgPages GetNumPages $imgFile]
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
        _Update $w $attrList $valList
        if { $createdNewImg } {
            image delete $phImg
        }
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
        _Update $w $attrList $valList
    }
}

poWinInfo::_Init
