# Module:         poImgview
# Copyright:      Paul Obermeier 1999-2020 / paul@poSoft.de
# First Version:  1999 / 05 / 20
#
# Distributed under BSD license.
#
# A portable image viewer.


namespace eval poImgview {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin ParseCommandLine IsOpen
    namespace export GetUsageMsg
    namespace export ReadImg AddImg DelImg
    namespace export GetImgNumByPhoto

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo
        variable sConv
        variable sImg

        set sPo(tw)      ".poImgview"  ; # Name of toplevel window
        set sPo(appName) "poImgview"   ; # Name of tool
        set sPo(cfgDir)  ""            ; # Directory containing config files

        set sPo(optBatch)            false
        set sPo(optConvert)          false
        set sPo(optKeepAspect)       false
        set sPo(optAdjustResolution) false
        set sPo(optCompose)          false
        set sPo(optRawInfo)          false
        set sPo(optEqualSizedImgs)   false

        set sPo(optPaletteFile)      ""
        set sPo(optPaletteMapMode)   ""

        set sConv(inFmtOpt)  ""
        set sConv(outFmtOpt) ""

        set sPo(stopJob) 0

        ClearSelRect

        set sImg(curNo)  -1
        SetNumImgs 0

        poWatch Start swatch

        # Determine machine dependent fixed font.
        set sPo(fixedFont) [poWin GetFixedFont]
    }

    # The following functions are used for loading/storing poImgview specific
    # settings in a configuration file.

    proc SetWindowPos { winName x y w h } {
        variable sPo

        set sPo($winName,x) $x
        set sPo($winName,y) $y
        set sPo($winName,w) $w
        set sPo($winName,h) $h
    }

    proc GetWindowPos { winName } {
        variable sPo

        if { [info exists sPo($winName,name)] && \
            [winfo exists $sPo($winName,name)] } {
            scan [wm geometry $sPo($winName,name)] "%dx%d+%d+%d" w h x y
        } else {
            set x $sPo($winName,x)
            set y $sPo($winName,y)
            set w $sPo($winName,w)
            set h $sPo($winName,h)
        }
        return [list $winName $x $y $w $h]
    }

    proc SetMainWindowSash { sashX0 sashX1 sashY } {
        variable sPo

        set sPo(sashX0) $sashX0
        set sPo(sashX1) $sashX1
        set sPo(sashY) $sashY
    }

    proc GetMainWindowSash {} {
        variable sPo

        if { [info exists sPo(paneHori)] && \
            [winfo exists $sPo(paneHori)] } {
            set sashX0 [$sPo(paneHori) sashpos 0]
            set sashX1 [$sPo(paneHori) sashpos 1]
        } else {
            set sashX0 $sPo(sashX0)
            set sashX1 $sPo(sashX1)
        }
        if { [info exists sPo(paneVert)] && \
            [winfo exists $sPo(paneVert)] } {
            set sashY [$sPo(paneVert) sashpos 0]
        } else {
            set sashY  $sPo(sashY)
        }
        return [list $sashX0 $sashX1 $sashY]
    }

    proc SetCurFile { curFile } {
        variable sPo

        set sPo(lastFile) $curFile
    }

    proc GetCurFile {} {
        variable sPo

        return [list $sPo(lastFile)]
    }

    proc SetNewImgParams { width height color { text "Lorem ipsum dolor sit amet, " } } {
        variable sPo

        set sPo(new,w) $width
        set sPo(new,h) $height
        set sPo(new,c) $color
        set sPo(new,t) $text
    }

    proc GetNewImgParams {} {
        variable sPo

        return [list $sPo(new,w) \
                     $sPo(new,h) \
                     $sPo(new,c) \
                     $sPo(new,t)]
    }

    proc SetNewImgResolution { xdpi ydpi } {
        variable sPo

        set sPo(new,xdpi) $xdpi
        set sPo(new,ydpi) $ydpi
    }

    proc GetNewImgResolution {} {
        variable sPo

        return [list $sPo(new,xdpi) \
                     $sPo(new,ydpi)]
    }

    proc SetLoadAsNewImg { newImgFlag } {
        variable sPo

        set sPo(loadAsNewImg) $newImgFlag
    }

    proc GetLoadAsNewImg {} {
        variable sPo

        return [list $sPo(loadAsNewImg) ]
    }

    proc ToggleLoadAsNewImg {} {
        variable sPo

        set sPo(loadAsNewImg) [expr ! $sPo(loadAsNewImg)]
    }

    proc SetScaleParams { keepAspect { adjustResolution 1 } } {
        variable sPo

        set sPo(scale,keepAspect)       $keepAspect
        set sPo(scale,adjustResolution) $adjustResolution
    }

    proc GetScaleParams {} {
        variable sPo

        return [list $sPo(scale,keepAspect) \
                     $sPo(scale,adjustResolution) ]
    }

    proc SetNoiseParams { size seed period coherence z_slice } {
        variable sPo

        set sPo(noise,size)      $size
        set sPo(noise,seed)      $seed
        set sPo(noise,period)    $period
        set sPo(noise,coherence) $coherence
        set sPo(noise,z-slice)   $z_slice

        set sPo(noise,previewSize) 128
    }

    proc GetNoiseParams {} {
        variable sPo

        return [list $sPo(noise,size)      \
                     $sPo(noise,seed)      \
                     $sPo(noise,period)    \
                     $sPo(noise,coherence) \
                     $sPo(noise,z-slice)]
    }

    proc SetTileParams { xrepeat yrepeat xmirror ymirror { maxRepeatX 30 } { maxRepeatY 30 } } {
        variable sPo

        set sPo(tile,xrepeat)    $xrepeat
        set sPo(tile,yrepeat)    $yrepeat
        set sPo(tile,xmirror)    $xmirror
        set sPo(tile,ymirror)    $ymirror
        set sPo(tile,maxRepeatX) $maxRepeatX
        set sPo(tile,maxRepeatY) $maxRepeatY
    }

    proc GetTileParams {} {
        variable sPo

        return [list $sPo(tile,xrepeat) \
                     $sPo(tile,yrepeat) \
                     $sPo(tile,xmirror) \
                     $sPo(tile,ymirror) \
                     $sPo(tile,maxRepeatX) \
                     $sPo(tile,maxRepeatY)]
    }

    proc SetComposeParams { numColumns maxColumns } {
        variable sPo

        set sPo(compose,numCols) $numColumns
        set sPo(compose,maxCols) $maxColumns
    }

    proc GetComposeParams {} {
        variable sPo

        return [list $sPo(compose,numCols) \
                     $sPo(compose,maxCols)]
    }

    proc SetImageMapParams { type rectWidth rectHeight circleRadius defText defRef } {
        variable sPo

        set sPo(imageMap,type)         $type
        set sPo(imageMap,rect,w)       $rectWidth
        set sPo(imageMap,rect,h)       $rectHeight
        set sPo(imageMap,circle,r)     $circleRadius
        set sPo(imageMap,default,text) $defText
        set sPo(imageMap,default,ref)  $defRef
    }

    proc GetImageMapParams {} {
        variable sPo

        return [list $sPo(imageMap,type)   \
                     $sPo(imageMap,rect,w) \
                     $sPo(imageMap,rect,h) \
                     $sPo(imageMap,circle,r) \
                     $sPo(imageMap,default,text) \
                     $sPo(imageMap,default,ref)]
    }

    proc SetImageMapViewParams { activeColor otherColor viewText viewRef } {
        variable sPo

        set sPo(imageMap,color,active) $activeColor
        set sPo(imageMap,color,other)  $otherColor
        set sPo(imageMap,showText)     $viewText
        set sPo(imageMap,showRef)      $viewRef
    }

    proc GetImageMapViewParams {} {
        variable sPo

        return [list $sPo(imageMap,color,active) \
                     $sPo(imageMap,color,other) \
                     $sPo(imageMap,showText) \
                     $sPo(imageMap,showRef)]
    }

    proc SetLogoParams { color position xoff yoff logoFilename } {
        variable sLogo

        set sLogo(color) $color
        set sLogo(pos)   $position
        set sLogo(xoff)  $xoff
        set sLogo(yoff)  $yoff
        set sLogo(file)  $logoFilename
    }

    proc GetLogoParams {} {
        variable sLogo

        return [list $sLogo(color) \
                     $sLogo(pos)   \
                     $sLogo(xoff)  \
                     $sLogo(yoff)  \
                     $sLogo(file)]
    }

    proc SetDtedParams { useDted levelToUse minMapVal maxMapVal } {
        variable sPo

        set sPo(useDtedExt)  $useDted
        set sPo(dted,level)  $levelToUse
        set sPo(dted,minVal) $minMapVal
        set sPo(dted,maxVal) $maxMapVal
    }

    proc GetDtedParams {} {
        variable sPo

        return [list $sPo(useDtedExt)  \
                     $sPo(dted,level)  \
                     $sPo(dted,minVal) \
                     $sPo(dted,maxVal)]
    }

    proc SetConversionParams { outputFormat outputName useOutputDir outputDir { outputNum 1 } } {
        variable sConv

        set sConv(outFmt)    $outputFormat
        set sConv(name)      $outputName
        set sConv(useOutDir) $useOutputDir
        set sConv(outDir)    $outputDir
        set sConv(num)       $outputNum
    }

    proc GetConversionParams {} {
        variable sConv

        return [list $sConv(outFmt)    \
                     $sConv(name)      \
                     $sConv(useOutDir) \
                     $sConv(outDir)    \
                     $sConv(num)]
    }

    proc SetZoomParams { autofit zoomValue } {
        variable sPo

        set sPo(zoom,autofit) $autofit
        set sPo(zoom) $zoomValue
    }

    proc GetZoomParams {} {
        variable sPo

        return [list $sPo(zoom,autofit) \
                     $sPo(zoom)]
    }

    proc SetViewParams { showImgInfo showFileInfo } {
        variable sPo

        set sPo(showImgInfo)  $showImgInfo
        set sPo(showFileInfo) $showFileInfo
    }

    proc GetViewParams {} {
        variable sPo

        return [list $sPo(showImgInfo) \
                     $sPo(showFileInfo)]
    }

    # Procedures to handle the number of images used in poImgview.
    proc GetCurImg {} {
        if { ! [HaveImgs] } {
            return ""
        } else {
            return [GetCurImgPhoto]
        }
    }

    proc GetCurImgNum {} {
        variable sImg

        return $sImg(curNo)
    }

    proc SetCurImgNum { imgNum } {
        variable sImg

        set sImg(curNo) $imgNum
    }

    proc GetImgName { imgNum } {
        variable sImg

        return $sImg(name,$imgNum)
    }

    proc GetCurImgName {} {
        if { [HaveImgs] } {
            return [GetImgName [GetCurImgNum]]
        } else {
            return ""
        }
    }

    proc GetImgNames {} {
        set nameList [list]
        for { set imgNum 0 } { $imgNum < [GetNumImgs] } { incr imgNum } {
            lappend nameList [GetImgName $imgNum]
        }
        return $nameList
    }

    proc GetImgPhoto { imgNum } {
        variable sImg

        return $sImg(photo,$imgNum)
    }

    proc GetCurImgPhoto {} {
        return [GetImgPhoto [GetCurImgNum]]
    }

    proc GetCurImgPhotoWidth {} {
        return [image width [GetCurImgPhoto]]
    }

    proc GetCurImgPhotoHeight {} {
        return [image height [GetCurImgPhoto]]
    }

    proc GetCurImgPhotoHoriResolution {} {
        return [lindex [poImgType GetResolution [GetCurImgPhoto]] 0]
    }

    proc GetCurImgPhotoVertResolution {} {
        return [lindex [poImgType GetResolution [GetCurImgPhoto]] 1]
    }

    proc GetImgNumByPhoto { phImg } {
        variable sImg

        for { set imgNum 0 } { $imgNum < [GetNumImgs] } { incr imgNum } {
            if { [GetImgPhoto $imgNum] eq $phImg } {
                return $imgNum
            }
        }
        return -1
    }

    proc SetNumImgs { value } {
        variable sImg

        set sImg(num) $value
    }

    proc IncrNumImgs { value } {
        variable sImg

        incr sImg(num) $value
    }

    proc GetNumImgs {} {
        variable sImg

        return $sImg(num)
    }

    proc HaveImgs {} {
        return [expr [GetNumImgs] > 0]
    }

    proc PrintImgList { msg } {
        variable sImg

        puts "$msg"
        parray sImg
        catch {puts "Number of images left: [llength [image names]]"}
        catch {puts "poImages left: [info commands poImage*]"}
    }

    proc GenDefaultLogo {} {
        variable sPo
        variable sLogo

        set sLogo(photo) [::poImgData::pwrdLogo200]
        set sLogo(file)  ""
        if { [poImgAppearance UsePoImg] } {
            set sLogo(poImg) [poImage NewImageFromPhoto $sLogo(photo)]
        }
    }

    proc GetComboValue { comboId } {
        variable sPo
        variable ns

        set curVal [poWinSelect GetValue $comboId]
        if { [file isdirectory $curVal] } {
            ::poImgBrowse::OpenDir $curVal
        } elseif { [file isfile $curVal] } {
            if { ! $sPo(loadAsNewImg) } {
                DelImg [expr [GetNumImgs] -1] false
            }
            ReadImg $curVal
            ScanCurDirForImgs
        }
    }

    proc ToggleZoomRect {} {
        variable sPo

        if { $sPo(zoomRectExists) } {
            poZoomRect NewZoomRect "ZoomRect" 0 0 $sPo(mainCanv) [GetCurImg]
        } else {
            poZoomRect DeleteZoomRect "ZoomRect" $sPo(mainCanv)
        }
    }

    proc SwitchZoomRect {} {
        variable sPo

        set sPo(zoomRectExists) [expr ! $sPo(zoomRectExists)]
        ToggleZoomRect
    }

    proc StartAppBitmap {} {
        set argList [list]
        if { [GetNumImgs] > 0 } {
            lappend argList [GetCurImgName]
        }
        poApps StartApp poBitmap $argList
    }

    proc StartAppImgBrowse {} {
        set argList [list]
        if { [GetNumImgs] > 0 } {
            lappend argList [file dirname [GetCurImgName]]
        }
        poApps StartApp poImgBrowse $argList
    }

    proc ToggleRowOrder { w } {
        poImgAppearance ToggleRowOrderCount
        $w configure -image [poImgAppearance GetRowOrderCountBitmap]
        poToolhelp AddBinding $w "Row order count: [poImgAppearance GetRowOrderCount]"
    }

    proc InitPixelInfoRollUp { masterFr } {
        variable ns
        variable sPo

        ClearPixelValue

        ttk::frame $masterFr.posFr
        ttk::frame $masterFr.colFr
        ttk::frame $masterFr.rawFr
        ttk::frame $masterFr.palFr
        pack $masterFr.posFr -anchor w -side top -pady 2 -ipadx 5
        pack $masterFr.colFr -anchor w -side top -pady 2 -ipadx 5
        pack $masterFr.rawFr -anchor w -side top -pady 2 -ipadx 5
        pack $masterFr.palFr -anchor w -side top -pady 2 -ipadx 5

        ttk::label $masterFr.posFr.l -text "Position:"
        ttk::label $masterFr.posFr.ex -textvariable ${ns}::sPo(curPos,x) -width 4 -anchor e
        ttk::label $masterFr.posFr.ey -textvariable ${ns}::sPo(curPos,y) -width 4 -anchor e
        ttk::button $masterFr.posFr.row -image [poImgAppearance GetRowOrderCountBitmap] \
                    -style Toolbutton -command "${ns}::ToggleRowOrder $masterFr.posFr.row"
        poToolhelp AddBinding $masterFr.posFr.row "Row order count: [poImgAppearance GetRowOrderCount]"
        pack $masterFr.posFr.l -anchor w -side left
        pack $masterFr.posFr.ex $masterFr.posFr.ey $masterFr.posFr.row -anchor e -side left

        set sPo(curCol,hex) $masterFr.colFr.rgb_c
        ttk::label $masterFr.colFr.rgb_l -text "Color:"
        label $sPo(curCol,hex) -width 3 -relief sunken
        ttk::label $masterFr.colFr.rgb_er -textvariable ${ns}::sPo(curCol,r) -width 3 -anchor e
        ttk::label $masterFr.colFr.rgb_eg -textvariable ${ns}::sPo(curCol,g) -width 3 -anchor e
        ttk::label $masterFr.colFr.rgb_eb -textvariable ${ns}::sPo(curCol,b) -width 3 -anchor e
        grid $masterFr.colFr.rgb_l  -row 0 -column 0 -sticky news
        grid $masterFr.colFr.rgb_c  -row 0 -column 1 -sticky news
        grid $masterFr.colFr.rgb_er -row 0 -column 2 -sticky news -padx 1
        grid $masterFr.colFr.rgb_eg -row 0 -column 3 -sticky news -padx 1
        grid $masterFr.colFr.rgb_eb -row 0 -column 4 -sticky news -padx 1
        if { [poMisc HaveTcl87OrNewer] } {
            ttk::label $masterFr.colFr.rgb_ea -textvariable ${ns}::sPo(curCol,a) -width 3 -anchor e
            grid $masterFr.colFr.rgb_ea -row 0 -column 5 -sticky news -padx 1
        }

        set sPo(medCol,hex) $masterFr.colFr.mean_c
        ttk::label $masterFr.colFr.mean_l -text "Mean:"
        label $sPo(medCol,hex) -width 3 -relief sunken
        ttk::label $masterFr.colFr.mean_er -textvariable ${ns}::sPo(medCol,r) -width 3 -anchor e
        ttk::label $masterFr.colFr.mean_eg -textvariable ${ns}::sPo(medCol,g) -width 3 -anchor e
        ttk::label $masterFr.colFr.mean_eb -textvariable ${ns}::sPo(medCol,b) -width 3 -anchor e
        grid $masterFr.colFr.mean_l  -row 1 -column 0 -sticky news
        grid $masterFr.colFr.mean_c  -row 1 -column 1 -sticky news -pady 2
        grid $masterFr.colFr.mean_er -row 1 -column 2 -sticky news -padx 1
        grid $masterFr.colFr.mean_eg -row 1 -column 3 -sticky news -padx 1
        grid $masterFr.colFr.mean_eb -row 1 -column 4 -sticky news -padx 1

        ttk::label $masterFr.rawFr.val_l -text "Raw value:"
        ttk::label $masterFr.rawFr.val_e -textvariable ${ns}::sPo(curCol,raw) -anchor e
        grid $masterFr.rawFr.val_l -row 0 -column 0 -sticky news
        grid $masterFr.rawFr.val_e -row 0 -column 1 -sticky news -padx 2

        ttk::label $masterFr.palFr.l -text "Palette:"
        ttk::label $masterFr.palFr.ind  -textvariable ${ns}::sPo(curPal,ind)  -anchor e -width 3
        ttk::label $masterFr.palFr.name -textvariable ${ns}::sPo(curPal,name) -anchor w
        grid $masterFr.palFr.l    -row 0 -column 0 -sticky news
        grid $masterFr.palFr.ind  -row 0 -column 1 -sticky news -padx 0
        grid $masterFr.palFr.name -row 0 -column 2 -sticky news -padx 0
    }

    proc ClearRawImgInfo {} {
        variable sPo

        set sPo(curCol,raw) ""
    }

    proc ClearSelRect {} {
        variable sPo

        set sPo(selRect,x1) ""
        set sPo(selRect,x2) ""
        set sPo(selRect,y1) ""
        set sPo(selRect,y2) ""
        set sPo(selRect,w)  ""
        set sPo(selRect,h)  ""
    }

    proc GetSelRectCoords { { index -1 } } {
        variable sPo

        set coordList [poSelRect GetCoords $sPo(mainCanv) "SelectRect" $index]
        if { [llength $coordList] == 4 } {
            lassign $coordList sPo(selRect,x1) sPo(selRect,y1) sPo(selRect,x2) sPo(selRect,y2)
            set sPo(selRect,w) [expr {$sPo(selRect,x2) - $sPo(selRect,x1) + 1}]
            set sPo(selRect,h) [expr {$sPo(selRect,y2) - $sPo(selRect,y1) + 1}]
        } else {
            ClearSelRect
        }
    }

    proc SetSelRectSize {} {
        variable sPo

        if { $sPo(selRect,x1) eq "" || $sPo(selRect,y1) == "" || \
             $sPo(selRect,w)  eq "" || $sPo(selRect,h)  == "" } {
            return
        }
        poSelRect SetSize $sPo(mainCanv) "SelectRect" \
                  $sPo(selRect,x1) $sPo(selRect,y1) $sPo(selRect,w) $sPo(selRect,h)
    }

    proc ShiftSelRect { dx dy } {
        variable sPo

        if { $sPo(selRect,x1) eq "" || $sPo(selRect,y1) == "" || \
             $sPo(selRect,w)  eq "" || $sPo(selRect,h)  == "" } {
            return
        }
        set sPo(selRect,x1) [expr {$sPo(selRect,x1) + $dx}]
        set sPo(selRect,y1) [expr {$sPo(selRect,y1) + $dy}]
        SetSelRectSize

        set x [expr int( ($sPo(selRect,x1) + $sPo(selRect,w) / 2 + 2) * $sPo(zoom))]
        set y [expr int( ($sPo(selRect,y1) + $sPo(selRect,h) / 2 + 2) * $sPo(zoom))]
        poSelRect CheckSelection $sPo(mainCanv) "SelectRect" $x $y
    }

    proc ScaleSelRect { dx1 dy1 dx2 dy2 } {
        variable sPo

        if { $sPo(selRect,x1) eq "" || $sPo(selRect,y1) == "" || \
             $sPo(selRect,w)  eq "" || $sPo(selRect,h)  == "" } {
            return
        }
        set sPo(selRect,x1) [expr { $sPo(selRect,x1) + $dx1 }]
        set sPo(selRect,y1) [expr { $sPo(selRect,y1) + $dy1 }]
        set sPo(selRect,w)  [expr { $sPo(selRect,w)  + $dx2 }]
        set sPo(selRect,h)  [expr { $sPo(selRect,h)  + $dy2 }]
        SetSelRectSize

        set x [expr int( ($sPo(selRect,x1) + $sPo(selRect,w) / 2 + 2) * $sPo(zoom))]
        set y [expr int( ($sPo(selRect,y1) + $sPo(selRect,h) / 2 + 2) * $sPo(zoom))]
        poSelRect CheckSelection $sPo(mainCanv) "SelectRect" $x $y
    }

    proc SetSelRect { dir } {
        variable sPo

        set numSelRects [poSelRect GetNumSelRects "SelectRect"]
        if { $numSelRects == 0 } {
            return
        }
        if { ! [info exists sPo(selRect,curIndex)] } {
            set sPo(selRect,curIndex) [expr {$numSelRects - 2}]
        }
        set sPo(selRect,curIndex) [expr {$sPo(selRect,curIndex) + $dir}]
        if { $sPo(selRect,curIndex) < 0 } {
            set sPo(selRect,curIndex) [expr {$numSelRects - 1}]
        } elseif { $sPo(selRect,curIndex) >= $numSelRects } {
            set sPo(selRect,curIndex) 0
        }
        GetSelRectCoords $sPo(selRect,curIndex)
        SetSelRectSize
    }

    proc InitSelRectInfoRollUp { masterFr } {
        variable ns
        variable sPo

        set row 0
        ttk::label $masterFr.tl_l -text "Top-Left:"
        set maxVal 100000
        spinbox $masterFr.tl_ex -textvariable ${ns}::sPo(selRect,x1) -width 4 -justify right \
                -increment 1 -from -$maxVal -to $maxVal -command ${ns}::SetSelRectSize
        spinbox $masterFr.tl_ey -textvariable ${ns}::sPo(selRect,y1) -width 4 -justify right \
                -increment 1 -from -$maxVal -to $maxVal -command ${ns}::SetSelRectSize
        grid $masterFr.tl_l  -row $row -column 0 -sticky news
        grid $masterFr.tl_ex -row $row -column 1 -sticky news -padx 2
        grid $masterFr.tl_ey -row $row -column 2 -sticky news -padx 2
        incr row

        ttk::label $masterFr.s_l -text "Size:"
        spinbox $masterFr.s_ex -textvariable ${ns}::sPo(selRect,w) -width 4 -justify right \
                -increment 1 -from -$maxVal -to $maxVal -command ${ns}::SetSelRectSize
        spinbox $masterFr.s_ey -textvariable ${ns}::sPo(selRect,h) -width 4 -justify right \
                -increment 1 -from -$maxVal -to $maxVal -command ${ns}::SetSelRectSize
        grid $masterFr.s_l  -row $row -column 0 -sticky news
        grid $masterFr.s_ex -row $row -column 1 -sticky news -padx 2
        grid $masterFr.s_ey -row $row -column 2 -sticky news -padx 2
        incr row

        ttk::label  $masterFr.h_l -text "History:"
        ttk::button $masterFr.h_p -image [poBmpData::undo] -style Toolbutton -command "${ns}::SetSelRect -1"
        ttk::button $masterFr.h_c -image [poBmpData::redo] -style Toolbutton -command "${ns}::SetSelRect  1"
        grid $masterFr.h_l -row $row -column 0 -sticky news
        grid $masterFr.h_p -row $row -column 1 -sticky ns
        grid $masterFr.h_c -row $row -column 2 -sticky ns
        incr row

        bind $masterFr.tl_ex <Key-Return> ${ns}::SetSelRectSize
        bind $masterFr.tl_ey <Key-Return> ${ns}::SetSelRectSize
        bind $masterFr.s_ex  <Key-Return> ${ns}::SetSelRectSize
        bind $masterFr.s_ey  <Key-Return> ${ns}::SetSelRectSize
        bind $sPo(mainCanv) <<poSelRect>> ${ns}::GetSelRectCoords

        ClearSelRect
    }

    proc ReadImgByDrop { canvasId fileList } {
        _PushInfoState
        foreach f $fileList {
            if { [file isfile $f] } {
                ReadImg $f
            }
        }
        _PopInfoState
        ShowCurrent
        ScanCurDirForImgs
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo
        variable sLogo
        variable sConv

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        # Create the windows title.
        UpdateMainTitle ""
        wm minsize $sPo(tw) 300 200
        set sw [winfo screenwidth $sPo(tw)]
        set sh [winfo screenheight $sPo(tw)]
        wm maxsize $sPo(tw) [expr $sw -20] [expr $sh -40]
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create 4 frames: The menu frame on top, info frame beneath menu,
        # toolbar frame at the left and an image frame.
        ttk::frame $sPo(tw).toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).workfr
        pack $sPo(tw).toolfr -side top -fill x -anchor w
        pack $sPo(tw).workfr -side top -fill both -expand 1

        ttk::frame $sPo(tw).workfr.pixfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).workfr.imgfr
        ttk::frame $sPo(tw).workfr.statfr -borderwidth 1

        grid $sPo(tw).workfr.pixfr  -row 0 -column 0 -sticky news
        grid $sPo(tw).workfr.imgfr  -row 1 -column 0 -sticky news
        grid $sPo(tw).workfr.statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).workfr 1 -weight 1
        grid columnconfigure $sPo(tw).workfr 0 -weight 1

        ttk::frame $sPo(tw).workfr.imgfr.fr
        pack $sPo(tw).workfr.imgfr.fr -expand 1 -fill both
        
        set sPo(paneHori) $sPo(tw).workfr.imgfr.fr.pane
        ttk::panedwindow $sPo(paneHori) -orient horizontal
        pack $sPo(paneHori) -side top -expand 1 -fill both

        set lf $sPo(paneHori).lfr
        set rf $sPo(paneHori).rfr
        set pf $sPo(paneHori).pfr
        ttk::frame $lf -relief sunken -borderwidth 1
        ttk::frame $rf -relief sunken -borderwidth 1
        ttk::frame $pf -relief sunken -borderwidth 1
        grid $lf -row 0 -column 0 -sticky ns
        grid $rf -row 0 -column 1 -sticky news
        grid $pf -row 0 -column 2 -sticky ns
        grid rowconfigure    $sPo(tw).workfr.imgfr.fr 0 -weight 1
        grid columnconfigure $sPo(tw).workfr.imgfr.fr 0 -weight 0
        grid columnconfigure $sPo(tw).workfr.imgfr.fr 1 -weight 1
        $sPo(paneHori) add $lf
        $sPo(paneHori) add $rf
        $sPo(paneHori) add $pf

        # The pane splitting the image window and the image info window.
        ttk::frame $rf.fr
        pack $rf.fr -expand 1 -fill both
        set sPo(paneVert) $rf.fr.pane
        ttk::panedwindow $sPo(paneVert) -orient vertical
        pack $sPo(paneVert) -side top -expand 1 -fill both
        set tf $rf.fr.pane.tfr
        set bf $rf.fr.pane.bfr
        ttk::frame $tf -relief sunken -borderwidth 1
        ttk::frame $bf -relief sunken -borderwidth 1
        pack $tf -expand 1 -fill both -side top
        pack $bf -expand 1 -fill both -side top
        $sPo(paneVert) add $tf
        $sPo(paneVert) add $bf

        ttk::frame $bf.lfr
        ttk::frame $bf.rfr
        pack $bf.lfr -side left -expand 1 -fill both
        pack $bf.rfr -side left -expand 1 -fill both

        set sPo(imgInfoWidget)  [poWinInfo Create $bf.lfr]
        set sPo(fileInfoWidget) [poWinInfo Create $bf.rfr]
        poWinInfo SetTitle $sPo(imgInfoWidget)  "Image information"
        poWinInfo SetTitle $sPo(fileInfoWidget) "File information"
        UpdateInfoWidget

        set thumbFr $lf.tfr
        ttk::frame $thumbFr
        pack $thumbFr -side top -expand 1 -fill both

        # Add buttons for slideshow and playing loaded images.
        set playfr $thumbFr.playFr
        ttk::frame $playfr
        pack $playfr -side top -fill x
        poToolbar New $playfr
        poToolbar AddButton $playfr [::poBmpData::redo] \
                  "${ns}::ReloadImgs" "Reload images"
        poToolbar AddButton $playfr [::poBmpData::playrev] \
                  "${ns}::ShowPlay -1" "Play reverse (o)"
        poToolbar AddButton $playfr [::poBmpData::playfwd] \
                  "${ns}::ShowPlay  1" "Play forward (p)"
        poToolbar AddButton $playfr [::poBmpData::stop] \
                  "${ns}::ShowStop" "Stop playing (s)"

        # Add buttons for first/previous/next/last image.
        set selfr $thumbFr.selFr
        ttk::frame $selfr
        pack $selfr -side top -fill x
        poToolbar New $selfr
        poToolbar AddButton $selfr [::poBmpData::playbegin] \
                  ${ns}::ShowFirst "Show first loaded image (Home)"
        poToolbar AddButton $selfr [::poBmpData::playrevstep] \
                  ${ns}::ShowPrev "Show previous loaded image (Page Up)"
        poToolbar AddButton $selfr [::poBmpData::playfwdstep] \
                  ${ns}::ShowNext "Show next loaded image (Page Down)"
        poToolbar AddButton $selfr [::poBmpData::playend] \
                  ${ns}::ShowLast "Show last loaded image (End)"

        # Add buttons for marking left/right image.
        set markfr $thumbFr.markFr
        ttk::frame $markfr
        pack $markfr -side top -fill x
        poToolbar New $markfr
        poToolbar AddRadioButton $markfr [::poBmpData::left] \
                  "${ns}::ToggleMarkImgs 0" "Mark current image as left/bottom (Ctrl+L)" \
                  -variable ${ns}::sPo(markImg,cur) -value 0
        poToolbar AddRadioButton $markfr [::poBmpData::right] \
                  "${ns}::ToggleMarkImgs 1" "Mark current image as right/top (Ctrl+R)" \
                  -variable ${ns}::sPo(markImg,cur) -value 1
        poToolbar AddButton $markfr [::poBmpData::up] \
                  ${ns}::MoveUp "Move current image up"
        poToolbar AddButton $markfr [::poBmpData::down] \
                  ${ns}::MoveDown "Move current image down"

         # Now create the scrolled frame widget containing the thumbnail images.
        set sPo(thumbFr) [poWin CreateScrolledFrame $thumbFr true "Thumbnails"]

        set pixelFr $sPo(tw).workfr.pixfr

        ttk::frame $pixelFr.nextFr
        ttk::separator $pixelFr.sep -orient vertical
        ttk::frame $pixelFr.selFr
        pack $pixelFr.nextFr -side left -anchor w
        pack $pixelFr.sep    -side left -padx 2 -fill y
        pack $pixelFr.selFr  -side left -anchor w -expand 1 -fill x

        poToolbar New $pixelFr.nextFr
        poToolbar AddButton $pixelFr.nextFr [::poBmpData::playbegin] \
                  "${ns}::LoadNextImg 0" "Show first image in directory"
        poToolbar AddButton $pixelFr.nextFr [::poBmpData::playrevstep] \
                  "${ns}::LoadNextImg -1" "Show previous image in directory (j)"
        poToolbar AddButton $pixelFr.nextFr [::poBmpData::playfwdstep] \
                  "${ns}::LoadNextImg 1" "Show next image in directory (k)"
        poToolbar AddButton $pixelFr.nextFr [::poBmpData::playend] \
                  "${ns}::LoadNextImg end" "Show last image in directory"
        poToolbar AddGroup $pixelFr.nextFr
        set curImgIndId [poToolbar AddEntry $pixelFr.nextFr ${ns}::sPo(imgsInDir,cur) \
                         "Current image index" -width 6 -justify right]
        poToolbar AddLabel $pixelFr.nextFr "of" ""
        poToolbar AddEntry $pixelFr.nextFr ${ns}::sPo(imgsInDir,max) \
                  "Number of images in directory" -width 6 -justify right -state disabled
        bind $curImgIndId <Key-Return> "${ns}::LoadNextImg"

        bind $sPo(tw) <Key-j> "${ns}::LoadNextImg -1"
        bind $sPo(tw) <Key-k> "${ns}::LoadNextImg  1"

        set fileComboMaster $pixelFr.selFr
        set sPo(fileCombo) [poWinSelect CreateFileSelect $fileComboMaster \
                            $sPo(lastFile) "open" ""]
        poWinSelect SetFileTypes $sPo(fileCombo) [poImgType GetSelBoxTypes]
        bind $sPo(fileCombo) <Key-Return>     "${ns}::GetComboValue $sPo(fileCombo)"
        bind $sPo(fileCombo) <<FileSelected>> "${ns}::GetComboValue $sPo(fileCombo)"

        set sPo(mainCanv) [poWin CreateScrolledCanvas $tf true "" \
                           -width $sPo(mainWin,w) -height [expr $sPo(mainWin,h) -50] \
                           -borderwidth 0 -highlightthickness 0]
        # Set the canvas background color to the stored value.
        # Get the system default canvas background color as reset value.
        poImgAppearance SetCanvasResetColor [$sPo(mainCanv) cget -background]
        $sPo(mainCanv) configure -background [poImgAppearance GetCanvasBackgroundColor]

        $sPo(mainCanv) create line 0 0 1 1 \
                       -fill $sLogo(color) -tags LogoLine -arrow last
        $sPo(mainCanv) create rectangle 0 0 1 1 \
                       -outline $sLogo(color) -tags LogoRect
        $sPo(mainCanv) create text 0 0 \
                       -fill $sLogo(color) -text Logo -tags LogoText
        $sPo(mainCanv) create image 0 0 -anchor nw -tags "MyImage"

        poSelRect NewSelection $sPo(mainCanv) "SelectRect"

        # Create a Drag-And-Drop binding for the image canvas.
        poDragAndDrop AddCanvasBinding $sPo(mainCanv) ${ns}::ReadImgByDrop
 
        # Create menus File, Edit, View, Settings and Help
        set hMenu $sPo(tw).menufr
        menu $hMenu -borderwidth 2 -relief sunken
        if { $::tcl_platform(os) eq "Darwin" } {
            $hMenu add cascade -menu $hMenu.apple -label "poApps"
            set appleMenu $hMenu.apple
            menu $appleMenu -tearoff 0
            poMenu AddCommand $appleMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $appleMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $appleMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        set fileMenu $hMenu.file
        set editMenu $hMenu.edit
        set viewMenu $hMenu.view
        set toolMenu $hMenu.tool
        set settMenu $hMenu.sett
        set winMenu  $hMenu.win
        set helpMenu $hMenu.help
        $hMenu add cascade -menu $fileMenu -label File     -underline 0
        $hMenu add cascade -menu $editMenu -label Edit     -underline 0
        $hMenu add cascade -menu $viewMenu -label View     -underline 0
        $hMenu add cascade -menu $toolMenu -label Tools    -underline 0
        $hMenu add cascade -menu $settMenu -label Settings -underline 0
        $hMenu add cascade -menu $winMenu  -label Window   -underline 0
        $hMenu add cascade -menu $helpMenu -label Help     -underline 0

        # Menu File
        menu $fileMenu -tearoff 0
        set sPo(openMenu)   $fileMenu.open
        set sPo(browseMenu) $fileMenu.browse

        poMenu AddCommand $fileMenu "New ..."     "Ctrl+N" ${ns}::New
        $fileMenu add cascade -label "Open"   -menu $sPo(openMenu)
        $fileMenu add cascade -label "Browse" -menu $sPo(browseMenu)
        if { $sPo(useDtedExt) } {
            poMenu AddCommand $fileMenu "Browse DTED ..." "" ${ns}::BrowseDted
        }

        menu $sPo(openMenu) -tearoff 0 -postcommand "${ns}::AddRecentFiles $sPo(openMenu)"
        poMenu AddCommand $sPo(openMenu) "Select ..." "Ctrl+O" ${ns}::Open
        $sPo(openMenu) add separator

        menu $sPo(browseMenu) -tearoff 0 -postcommand "${ns}::AddRecentDirs $sPo(browseMenu)"
        poMenu AddCommand $sPo(browseMenu) "Select ..." "Ctrl+B" ${ns}::BrowseDir
        $sPo(browseMenu) add separator

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Save As ..."    "Ctrl+S" ${ns}::SaveAs
        poMenu AddCommand $fileMenu "Capture canvas" "F2"     ${ns}::CaptureCanv
        poMenu AddCommand $fileMenu "Capture window" "F4"     ${ns}::CaptureWin

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }
        bind $sPo(tw) <Control-n>  ${ns}::New
        bind $sPo(tw) <Control-o>  ${ns}::Open
        bind $sPo(tw) <Control-b>  ${ns}::BrowseDir
        bind $sPo(tw) <Control-s> ${ns}::SaveAs
        bind $sPo(tw) <Key-F2>    ${ns}::CaptureCanv
        bind $sPo(tw) <Key-F4>    ${ns}::CaptureWin
        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Edit
        set selMenu  $editMenu.sel
        set combMenu $editMenu.comb
        set rotMenu  $editMenu.rot
        set flipMenu $editMenu.flip
        menu $editMenu -tearoff 0
        if { $::tcl_platform(platform) eq "windows" } {
            poMenu AddCommand $editMenu "Copy"  "Ctrl+C" ${ns}::CopyImg
            poMenu AddCommand $editMenu "Paste" "Ctrl+V" ${ns}::PasteImg
            $editMenu add separator
            if { [poApps HavePkg "cawt"] } {
                poMenu AddCommand $editMenu "Copy to Excel"    "" ${ns}::ImgToExcel
                poMenu AddCommand $editMenu "Paste from Excel" "" ${ns}::ExcelToImg
                $editMenu add separator
            }
        }
        poMenu AddCommand $editMenu "Clear"      "F9" ${ns}::DelImg
        poMenu AddCommand $editMenu "Clear all"  ""   ${ns}::DelAll
        $editMenu add separator
        $editMenu add cascade -label "Mark" -menu $selMenu
        menu $selMenu -tearoff 0
        poMenu AddRadio   $selMenu "as left"  "Ctrl+L" ${ns}::sPo(markImg,cur) 0 "${ns}::ToggleMarkImgs 0"
        poMenu AddRadio   $selMenu "as right" "Ctrl+R" ${ns}::sPo(markImg,cur) 1 "${ns}::ToggleMarkImgs 1"
        poMenu AddCommand $editMenu "Diff marked images" "Ctrl+D" ${ns}::DiffImgs
        $editMenu add cascade -label "Combine marked" -menu $combMenu
        menu $combMenu -tearoff 0
        poMenu AddCommand $combMenu "horizontally" "" "${ns}::CombineImgs horizontal"
        poMenu AddCommand $combMenu "vertically"   "" "${ns}::CombineImgs vertical"
        $editMenu add separator
        poMenu AddCommand $editMenu "Crop" "Ctrl+P" ${ns}::DoCropImg
        $editMenu add cascade -label "Rotate" -menu $rotMenu
        menu $rotMenu -tearoff 0
        poMenu AddCommand $rotMenu "90° left"   "" "${ns}::RotImg  90"
        poMenu AddCommand $rotMenu "90° right"  "" "${ns}::RotImg -90"
        $editMenu add cascade -label "Flip" -menu $flipMenu
        menu $flipMenu -tearoff 0
        poMenu AddCommand $flipMenu "horizontal" "" "${ns}::FlipImg horizontal"
        poMenu AddCommand $flipMenu "vertical"   "" "${ns}::FlipImg vertical"
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Control-c> ${ns}::CopyImg
            bind $sPo(tw) <Control-v> ${ns}::PasteImg
        }
        bind $sPo(tw) <Control-l> "${ns}::SwitchMarkImgs 0"
        bind $sPo(tw) <Control-r> "${ns}::SwitchMarkImgs 1"
        bind $sPo(tw) <Control-d> ${ns}::DiffImgs
        bind $sPo(tw) <Key-F9>    ${ns}::DelImg
        bind $sPo(tw) <Control-p> ${ns}::DoCropImg

        # Menu View
        set zoomMenu  $viewMenu.zoom
        set histoMenu $viewMenu.histo
        set palMenu   $viewMenu.pal
        set rawMenu   $viewMenu.raw
        menu $viewMenu  -tearoff 0
        $viewMenu add cascade -label "Zoom"      -menu $zoomMenu
        poMenu AddCheck $viewMenu "Autofit" "" ${ns}::sPo(zoom,autofit) "${ns}::ShowCurrent"
        poMenu AddCheck $viewMenu "Zoom rectangle" "Ctrl+Y" ${ns}::sPo(zoomRectExists) "${ns}::ToggleZoomRect"
        $viewMenu add separator
        $viewMenu add cascade -label "Histogram" -menu $histoMenu
        poMenu AddCommand $viewMenu "Color count" "" "${ns}::ShowColorCount"
        $viewMenu add separator
        poMenu AddCommand $viewMenu "Slide show" "Ctrl+E" "${ns}::ShowSlideShow"
        $viewMenu add separator
        $viewMenu add cascade -label "Palette"   -menu $palMenu
        $viewMenu add cascade -label "RAW palette" -menu $rawMenu

        bind $sPo(tw) <Control-y>  ${ns}::SwitchZoomRect
        bind $sPo(tw) <Key-plus>   "${ns}::ChangeZoom 1"
        bind $sPo(tw) <Key-minus>  "${ns}::ChangeZoom -1"
        bind $sPo(tw) <Control-e>  "${ns}::ShowSlideShow"

        menu $zoomMenu -tearoff 0
        poMenu AddRadio $zoomMenu "  5%"  "" ${ns}::sPo(zoom) 0.05 "${ns}::ResetZoom 0.05"
        poMenu AddRadio $zoomMenu " 10%"  "" ${ns}::sPo(zoom) 0.10 "${ns}::ResetZoom 0.10"
        poMenu AddRadio $zoomMenu " 20%"  "" ${ns}::sPo(zoom) 0.20 "${ns}::ResetZoom 0.20"
        poMenu AddRadio $zoomMenu " 25%"  "" ${ns}::sPo(zoom) 0.25 "${ns}::ResetZoom 0.25"
        poMenu AddRadio $zoomMenu " 33%"  "" ${ns}::sPo(zoom) 0.33 "${ns}::ResetZoom 0.33"
        poMenu AddRadio $zoomMenu " 50%"  "" ${ns}::sPo(zoom) 0.50 "${ns}::ResetZoom 0.50"
        poMenu AddRadio $zoomMenu "100%"  "" ${ns}::sPo(zoom) 1.00 "${ns}::ResetZoom 1.00"
        poMenu AddRadio $zoomMenu "200%"  "" ${ns}::sPo(zoom) 2.00 "${ns}::ResetZoom 2.00"
        poMenu AddRadio $zoomMenu "300%"  "" ${ns}::sPo(zoom) 3.00 "${ns}::ResetZoom 3.00"
        poMenu AddRadio $zoomMenu "400%"  "" ${ns}::sPo(zoom) 4.00 "${ns}::ResetZoom 4.00"
        poMenu AddRadio $zoomMenu "500%"  "" ${ns}::sPo(zoom) 5.00 "${ns}::ResetZoom 5.00"
        bind $sPo(tw) <Control-m> ${ns}::ResetZoom

        menu $histoMenu -tearoff 0
        poMenu AddCommand $histoMenu "Uniform scaling"     "Ctrl+Shift+H" "${ns}::ShowHistogram lin"
        poMenu AddCommand $histoMenu "Logarithmic scaling" "Ctrl+H"       "${ns}::ShowHistogram log"
        bind $sPo(tw) <Control-H> "${ns}::ShowHistogram lin"
        bind $sPo(tw) <Control-h> "${ns}::ShowHistogram log"

        menu $palMenu -tearoff 0
        poMenu AddCommand $palMenu "New palette image"      "Ctrl+I"       "${ns}::ShowPaletteImage true  false"
        poMenu AddCommand $palMenu "Change to palette view" "Ctrl+Shift+I" "${ns}::ShowPaletteImage false false"
        bind $sPo(tw) <Control-i>  "${ns}::ShowPaletteImage true  false"
        bind $sPo(tw) <Control-I>  "${ns}::ShowPaletteImage false false"
        $palMenu add separator
        poMenu AddCommand $palMenu "New inverse palette image"      "Ctrl+J"       "${ns}::ShowPaletteImage true  true"
        poMenu AddCommand $palMenu "Change to inverse palette view" "Ctrl+Shift+J" "${ns}::ShowPaletteImage false true"
        bind $sPo(tw) <Control-j>  "${ns}::ShowPaletteImage true  true"
        bind $sPo(tw) <Control-J>  "${ns}::ShowPaletteImage false true"

        menu $rawMenu -tearoff 0
        poMenu AddCommand $rawMenu "Greyscale"   "" "${ns}::ShowRawAsPalette Greyscale"
        poMenu AddCommand $rawMenu "Pseudocolor" "" "${ns}::ShowRawAsPalette Pseudocolor"
        poMenu AddCommand $rawMenu "RG Color"    "" "${ns}::ShowRawAsPalette RedGreen"

        # Menu Tools
        menu $toolMenu -tearoff 0
        poMenu AddCommand $toolMenu "Image map ..."    "" ${ns}::ShowImageMapWin

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        $settMenu add cascade -label "Application settings" -menu $appSettMenu
        menu $appSettMenu -tearoff 0
        poMenu AddCommand $appSettMenu "Miscellaneous" "" [list ${ns}::ShowSpecificSettWin "Miscellaneous"]

        $settMenu add cascade -label "Image settings" -menu $imgSettMenu
        menu $imgSettMenu -tearoff 0
        poMenu AddCommand $imgSettMenu "Appearance"          "" [list poSettings ShowImgSettWin "Appearance"          ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Image types"         "" [list poSettings ShowImgSettWin "Image types"         ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Image browser"       "" [list poSettings ShowImgSettWin "Image browser"       ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Slide show"          "" [list poSettings ShowImgSettWin "Slide show"          ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Zoom rectangle"      "" [list poSettings ShowImgSettWin "Zoom rectangle"      ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Selection rectangle" "" [list poSettings ShowImgSettWin "Selection rectangle" ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Palette"             "" [list poSettings ShowImgSettWin "Palette"             ${ns}::SettingsOkCallback]

        $settMenu add cascade -label "General settings" -menu $genSettMenu
        menu $genSettMenu -tearoff 0
        poMenu AddCommand $genSettMenu "Appearance"   "" [list poSettings ShowGeneralSettWin "Appearance"]
        poMenu AddCommand $genSettMenu "File types"   "" [list poSettings ShowGeneralSettWin "File types"]
        poMenu AddCommand $genSettMenu "Edit/Preview" "" [list poSettings ShowGeneralSettWin "Edit/Preview"]
        poMenu AddCommand $genSettMenu "Logging"      "" [list poSettings ShowGeneralSettWin "Logging"]

        if { $sPo(useDtedExt) } {
            poMenu AddCommand $settMenu "DTED ..." "" ${ns}::ShowDtedSettWin
        }
        $settMenu add separator
        poMenu AddCheck   $settMenu "Save on exit"       "" poApps::gPo(autosaveOnExit) ""
        poMenu AddCommand $settMenu "View setting files" "" "poApps ViewSettingsDir"
        poMenu AddCommand $settMenu "Save settings"      "" "poApps SaveSettings"

        if { 0 } {
            menu $extMenu -tearoff 0
            poMenu AddCommand $extMenu "Open animated GIF ..." "" ${ns}::AskOpenAniGif
            poMenu AddCommand $extMenu "Save animated GIF ..." "" ${ns}::AskSaveAniGif
        }

        # Menu Window
        menu $winMenu -tearoff 0
        poMenu AddCommand $winMenu [poApps GetAppDescription main]        "" "poApps StartApp main"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgview]   "" "poApps StartApp poImgview" -state disabled
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgBrowse] "" ${ns}::StartAppImgBrowse
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" ${ns}::StartAppBitmap
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgdiff]   "" ${ns}::DiffImgs
        poMenu AddCommand $winMenu [poApps GetAppDescription poDiff]      "" "poApps StartApp poDiff"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poPresMgr]   "" "poApps StartApp poPresMgr"
        poMenu AddCommand $winMenu [poApps GetAppDescription poOffice]    "" "poApps StartApp poOffice"

        # Menu Help
        menu $helpMenu -tearoff 0
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $helpMenu "Help ..." "F1" ${ns}::HelpCont
            bind $sPo(tw) <Key-F1>  ${ns}::HelpCont
            poMenu AddCommand $helpMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $helpMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $helpMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        $sPo(tw) configure -menu $hMenu

        # Add new toolbar group and associated buttons.
        set toolfr $sPo(tw).toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::renOut] \
                  "" "Load file as new image (n)" -variable ${ns}::sPo(loadAsNewImg)
        poToolbar AddButton $toolfr [::poBmpData::open] \
                  ${ns}::Open "Open image file (Ctrl+O)"
        poToolbar AddButton $toolfr [::poBmpData::browse] \
                  ${ns}::BrowseDir "Browse directory (Ctrl+B)"
        poToolbar AddButton $toolfr [::poBmpData::save] \
                  ${ns}::SaveAs "Save current image ... (Ctrl+S)"
        bind $sPo(tw) <Key-n> ${ns}::ToggleLoadAsNewImg

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        if { $::tcl_platform(platform) eq "windows" } {
            poToolbar AddButton $toolfr [::poBmpData::copy] \
                      ${ns}::CopyImg "Copy to clipboard (Ctrl+C)"
            poToolbar AddButton $toolfr [::poBmpData::paste] \
                      ${ns}::PasteImg "Paste from clipboard (Ctrl+V)"
        }
        poToolbar AddButton $toolfr [::poBmpData::clear] \
                  ${ns}::DelImg "Clear current image (F9)"
        poToolbar AddButton $toolfr [::poBmpData::clearall] \
                  ${ns}::DelAll "Clear all images"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::diff] \
                  ${ns}::DiffImgs "Diff marked images (Ctrl+D)"
        poToolbar AddButton $toolfr [::poBmpData::combhori] \
                  "${ns}::CombineImgs horizontal" "Combine marked images horizontally"
        poToolbar AddButton $toolfr [::poBmpData::combvert] \
                  "${ns}::CombineImgs vertical" "Combine marked images vertically"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::crop] \
                  ${ns}::DoCropImg "Crop current image (Ctrl+P)"
        poToolbar AddButton $toolfr [::poBmpData::rotateleft] \
                  "${ns}::RotImg 90" "Rotate image left by 90 degrees"
        poToolbar AddButton $toolfr [::poBmpData::rotateright] \
                  "${ns}::RotImg -90" "Rotate image right by 90 degrees"
        poToolbar AddButton $toolfr [::poBmpData::fliphori] \
                  "${ns}::FlipImg horizontal" "Flip image horizontally"
        poToolbar AddButton $toolfr [::poBmpData::flipvert] \
                  "${ns}::FlipImg vertical" "Flip image vertically"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::hundred] \
                  ${ns}::ResetZoom "Reset image zoom (Ctrl+M)"
        poToolbar AddCheckButton $toolfr [::poBmpData::autofit] \
                  ${ns}::ShowCurrent "Toggle image autofit" \
                  -variable ${ns}::sPo(zoom,autofit)

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::histo] \
                  "${ns}::ShowHistogram log" "Show logarithmic histogram (Ctrl+H)"
        poToolbar AddButton $toolfr [::poBmpData::colorcount] \
                  "${ns}::ShowColorCount" "Show color count window"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::slideShowAll] \
                  "${ns}::ShowSlideShow" "Slide show of current image directory (Ctrl+E)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::linenum] \
                  "${ns}::ShowPaletteImage true false" \
                  "New palette image (Ctrl+I)\nChange to palette view (Ctrl+Shift+I)"
        poToolbar AddButton $toolfr [::poBmpData::linenuminv] \
                  "${ns}::ShowPaletteImage true true" \
                  "New inverse palette image (Ctrl+J)\nChange to inverse palette view (Ctrl+Shift+J)"

        # Create widget for status messages.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).workfr.statfr]
                  
        # Read in the image used as the logo.
        ReadIcon

        set infoFr $pf.tfr
        ttk::frame $infoFr
        pack $infoFr -side top -expand 1 -fill both

        set sPo(infoFr) [poWin CreateScrolledFrame $infoFr true ""]

        CreateInfoRollUp  $sPo(infoFr)
        CreateToolsRollUp $sPo(infoFr)

        # Create bindings for this application.
        catch {bind $sPo(tw) <Key-Page_Up>   ${ns}::ShowPrev}
        catch {bind $sPo(tw) <Key-Prior>     ${ns}::ShowPrev}
        catch {bind $sPo(tw) <Key-Page_Down> ${ns}::ShowNext}
        catch {bind $sPo(tw) <Key-Next>      ${ns}::ShowNext}
        catch {bind $sPo(tw) <Key-Home>      ${ns}::ShowFirst}
        catch {bind $sPo(tw) <Key-End>       ${ns}::ShowLast}
        catch {bind $sPo(tw) <Key-s>         ${ns}::ShowStop}
        catch {bind $sPo(tw) <Key-p>         "${ns}::ShowPlay  1"}
        catch {bind $sPo(tw) <Key-o>         "${ns}::ShowPlay -1"}

        bind $sPo(tw) <KeyPress-Escape>      "${ns}::StopJob"

        # Initialize rectangle for logo.
        set sLogo(show) 1
        SetLogoPos
        # Hide rectangle.
        set sLogo(show) 0
        SetLogoPos

        SwitchBindings "SelRect"
        WriteInfoStr $sPo(initStr)

        ScanCurDirForImgs

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        if { ! [poApps GetHideWindow] } {
            update
        }
        $sPo(paneHori) pane $lf -weight 0
        $sPo(paneHori) pane $rf -weight 1
        $sPo(paneHori) pane $pf -weight 0
        $sPo(paneHori) sashpos 0 $sPo(sashX0)
        $sPo(paneHori) sashpos 1 $sPo(sashX1)

        $sPo(paneVert) pane $tf -weight 1
        $sPo(paneVert) pane $bf -weight 0
        $sPo(paneVert) sashpos 0 $sPo(sashY)

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
    }

    proc UpdateInfoWidget {} {
        variable sPo
        variable sImg

        if { [HaveImgs] } {
            set phImg [GetCurImgPhoto]
            if { $sPo(showImgInfo) } {
                if { [info exists sImg(rawDict,[GetCurImgNum])] } {
                    poWinInfo UpdateImgInfo $sPo(imgInfoWidget) $phImg "" $sImg(rawDict,[GetCurImgNum])
                } else {
                    poWinInfo UpdateImgInfo $sPo(imgInfoWidget) $phImg
                }
            }
            if { $sPo(showFileInfo) } {
                poWinInfo UpdateFileInfo $sPo(fileInfoWidget) [GetCurImgName]
            }
        }
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc ReadRecentImg { f } {
        variable sPo

        if { ! $sPo(loadAsNewImg) } {
            DelImg [expr [GetNumImgs] -1] false
        }
        ReadImg $f
    }

    proc AddRecentFiles { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentFileList $menuId ${ns}::ReadRecentImg
    }

    proc AddRecentDirs { menuId } {
        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentDirList $menuId ::poImgBrowse::OpenDir
    }

    proc ShowHistogram { histoType } {
        variable sPo

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }

        poHistogram ShowHistoWin "Histogram display" $histoType [GetCurImgPhoto] \
                    [list [poAppearance CutFilePath [GetCurImgName]]] $sPo(appName)
    }
 
    proc ShowColorCount {} {
        variable sPo

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }

        poColorCount ShowWin "Color count display" [GetCurImgPhoto] \
                    [list [poAppearance CutFilePath [GetCurImgName]]] $sPo(appName)
    }

    proc ShowPaletteImage { { createNewImg true } { inverseMap false } } {
        variable sPo
        variable sImg

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }

        set paletteColorList [poImgPalette GetPaletteColorList]
        if { [llength $paletteColorList] == 0 } {
            WriteInfoStr "No palette loaded" "Error"
            return
        }
        poWatch Reset swatch
        set chanNum [poImgPalette GetChannelNum]
        set newImg [poPhotoUtil AssignPalette [GetCurImgPhoto] $chanNum $paletteColorList $inverseMap]
        WriteInfoStr [format "Assign palette (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        if { $createNewImg } {
            set imgName [GetCurImgName]
            AddImg $newImg "" $imgName
        } else {
            set cur [GetCurImgNum]
            image delete $sImg(photo,$cur)
            set sImg(photo,$cur) $newImg
            ShowImg $cur
            UpdateThumb [GetImgPhoto $cur]
        }
    }

    proc ImgToExcel {} {
        variable sPo

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }
        set phImg [GetCurImgPhoto]
        set sPo(Excel,w) [image width $phImg]
        set sPo(Excel,h) [image height $phImg]

        set appId [::Excel::Open true]
        set workbookId [::Excel::AddWorkbook $appId]
        set sPo(Excel,worksheetId) [::Excel::GetWorksheetIdByIndex $workbookId 1]
        ::Excel::SetWorksheetName $sPo(Excel,worksheetId) "Image"
        ::Excel::UseImgTransparency true
        ::Excel::ImgToWorksheet $phImg $sPo(Excel,worksheetId) 1 1  5 1
    }

    proc ExcelToImg {} {
        variable sPo

        set catchVal [catch { ::Excel::WorksheetToImg $sPo(Excel,worksheetId) 1 1 $sPo(Excel,w) $sPo(Excel,h) } phImg]
        if { $catchVal != 0 } {
            WriteInfoStr "No Excel instance available." "Error"
            return
        }
        AddImg $phImg "" [CreateNewImgFileName "ExcelImage"]
    }

    proc FlipImg { direction } {
        variable sPo
        variable sImg

        if { ! [HaveImgs] } {
            WriteInfoStr "Flip image: No images loaded" "Error"
            return
        }

        set cur [GetCurImgNum]
        set phImg [GetCurImgPhoto]
        poWatch Reset swatch
        if { $direction eq "vertical" } {
            set flipImg [poPhotoUtil FlipVertical $phImg]
        } else {
            set flipImg [poPhotoUtil FlipHorizontal $phImg]
        }
        WriteInfoStr [format "Flip image $direction (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        set sImg(photo,$cur) $flipImg
        image delete $phImg
        ShowImg $cur
        UpdateThumb [GetImgPhoto $cur]
    }

    proc GetNewImgName { fileName prefix } {
        variable sPo

        if { $sPo(optBatch) } {
            set newImgPath $fileName
        } else {
            set imgPath $fileName
            set newImgName [format "%s%s" $prefix [file tail $imgPath]]
            set newImgPath [file join [file dirname $imgPath] $newImgName]
        }
        return $newImgPath
    }

    proc CropImg { imgNum x1 y1 x2 y2 } {
        variable sPo
        variable sImg

        set retVal -1

        set dstImg ""
        if { [poApps GetVerbose] } {
            puts "Crop image [GetImgName $imgNum] to rectangle: ($x1,$y1) x ($x2,$y2)"
        }

        poWatch Reset swatch
        set srcPhoto [GetImgPhoto $imgNum]
        set sx [image width  $srcPhoto]
        set sy [image height $srcPhoto]
        set x1 [poMisc Max 0   $x1]
        set y1 [poMisc Max 0   $y1]
        set x2 [poMisc Min $sx $x2]
        set y2 [poMisc Min $sy $y2]
        set dw [expr {$x2 - $x1 + 1}]
        set dh [expr {$y2 - $y1 + 1}]
        if { $dw <= 0 || $dh <= 0 } {
            error "Invalid or no selection rectangle specified."
        }
        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sImg(poImg,$imgNum)] } {
                set sImg(poImg,$imgNum) [poImage NewImageFromPhoto $srcPhoto]
            }
            poImageMode GetFormat savePixFmt
            set poImg $sImg(poImg,$imgNum)
            $poImg GetImgInfo w h a g
            $poImg GetImgFormat fmtList
            poImageMode SetFormat $fmtList
            set dstImg [poImage NewImage $dw $dh [expr {double ($dw) / double ($dh)}] $g]
            set dstPhoto [image create photo -width $dw -height $dh]
            $dstImg CopyRect $poImg $x1 [expr {$sy - $y2 -1}] $x2 [expr {$sy - $y1 -1}] 0 0
            $dstImg AsPhoto $dstPhoto
            poImageMode SetFormat $savePixFmt
        } else {
            set dstPhoto [image create photo -width $dw -height $dh]
            if { [catch {$dstPhoto copy $srcPhoto \
                                   -from $x1 $y1 [expr {$x2 + 1}] [expr {$y2 + 1}] \
                                   -to 0 0} ] } {
                image delete $dstPhoto
                set dstPhoto ""
            }
        }
        if { $dstPhoto ne "" } {
            set newImgPath [GetNewImgName [GetImgName $imgNum] "Crop_"]
            set retVal [AddImg $dstPhoto $dstImg $newImgPath]
        }
        WriteInfoStr [format "Crop image (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        return $retVal
    }

    proc BatchCrop { cropX1 cropY1 cropX2 cropY2 } {
        variable sPo
        variable sImg

        set newImgNum [CropImg [GetCurImgNum] $cropX1 $cropY1 $cropX2 $cropY2]
    }

    proc DoCropImg {} {
        variable sPo
        variable sImg

        if { ! [HaveImgs] } {
            WriteInfoStr "Crop image: No images loaded" "Error"
            return
        }
        if { ! [poSelRect IsAvailable] } {
            WriteInfoStr "No selection rectangle defined." "Error"
            return
        }
        lassign [poSelRect GetCoords $sPo(mainCanv) "SelectRect"] x1 y1 x2 y2
        CropImg [GetCurImgNum] $x1 $y1 $x2 $y2
    }

    proc CombineImgs { direction } {
        variable sPo
        variable sImg

        set imgNum1 -1
        set imgNum2 -1
        foreach key [lsort -dictionary [array names sPo "markImg,side,*"]] {
            if { $sPo($key) == 0 } {
                set imgNum1 [lindex [split $key ","] 2]
            } elseif { $sPo($key) == 1 } {
                set imgNum2 [lindex [split $key ","] 2]
            }
        }
        if { $imgNum1 < 0 || $imgNum2 < 0 } {
            WriteInfoStr "Combine images: No images selected" "Error"
            return
        }

        set dstImg ""
        poWatch Reset swatch
        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sImg(poImg,$imgNum1)] } {
                set sImg(poImg,$imgNum1) [poImage NewImageFromPhoto [GetImgPhoto $imgNum1]]
            }
            if { ! [info exists sImg(poImg,$imgNum2)] } {
                set sImg(poImg,$imgNum2) [poImage NewImageFromPhoto [GetImgPhoto $imgNum2]]
            }
            poImageMode GetFormat savePixFmt
            set poImg1 $sImg(poImg,$imgNum1)
            set poImg2 $sImg(poImg,$imgNum2)
            $poImg1 GetImgInfo w1 h1 a1 g1
            $poImg1 GetImgFormat fmtList1
            $poImg2 GetImgInfo w2 h2 a2 g2
            $poImg2 GetImgFormat fmtList2
            poImageMode SetFormat $fmtList1
            if { $direction eq "vertical" } {
                set hn [expr {$h1 + $h2}]
                set wn [poMisc Max $w1 $w2]
            } else {
                set hn [poMisc Max $h1 $h2]
                set wn [expr {$w1 + $w2}]
            }
            set dstImg   [poImage NewImage $wn $hn [expr {double ($wn) / double ($hn)}] $g1]
            set dstPhoto [image create photo -width $wn -height $hn]
            $dstImg GetImgFormat fmtList1

            $dstPhoto blank
            $dstImg Blank
            if { $direction eq "vertical" } {
                $dstImg CopyRect $poImg1 0 0 $w1 $h1 0 0
                $dstImg CopyRect $poImg2 0 0 $w2 $h2 0 $h1
            } else {
                $dstImg CopyRect $poImg1 0 0 $w1 $h1 0 0
                $dstImg CopyRect $poImg2 0 0 $w2 $h2 $w1 0
            }
            $dstImg AsPhoto $dstPhoto
            poImageMode SetFormat $savePixFmt
        } else {
            set phImg1 [GetImgPhoto $imgNum1]
            set phImg2 [GetImgPhoto $imgNum2]
            if { $direction eq "vertical" } {
                set dstPhoto [::poPhotoUtil::Compose 1 $phImg2 $phImg1]
            } else {
                set dstPhoto [::poPhotoUtil::Compose 2 $phImg1 $phImg2]
            }
        }
        WriteInfoStr [format "Combine images $direction (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        return [AddImg $dstPhoto $dstImg [CreateNewImgFileName "CombinedImage"]]
    }

    proc BatchCompose { numColumns equalSizedImgs fileOrDirList } {
        variable sPo

        set numImgs [llength $fileOrDirList]
        if { $numImgs == 0 } {
            return 0
        }

        if { $equalSizedImgs } {
            # All images are of equal size. Calculate destination image size
            # in advance, so that no reallocations of the destination image
            # are needed. 
            set fileName [poMisc FileSlashName [lindex $fileOrDirList 0]]
            set imgDict [ReadImg $fileName 1 0]
            set phImg [dict get $imgDict phImg]
            set iw [image width  $phImg]
            set ih [image height $phImg]
            set dw [expr {$iw * $numColumns}]
            set dh [expr {($numImgs / $numColumns) * $ih}]
            DelImg
            set dest [image create photo -width $dw -height $dh]
        } else {
            set dest [image create photo]
        }

        set x 0
        set y 0
        set curCol 0
        set curRow 0
        set numImgs 0

        foreach fileOrDirName $fileOrDirList {
            if { [file isdirectory $fileOrDirName] } {
                continue
            }
            set fileName [poMisc FileSlashName $fileOrDirName]
            if { [poApps GetVerbose] } {
                WriteInfoStr "Compose [file tail $fileName] to row $curRow column $curCol" "Ok"
                puts "Compose [file tail $fileName] to row $curRow column $curCol"
            }
            set imgDict [ReadImg $fileName 1 0]
            set phImg [dict get $imgDict phImg]
            $dest copy $phImg -to $x $y
            incr x [image width $phImg]
            incr curCol
            if { $curCol >= $numColumns } {
                set x 0
                if { $equalSizedImgs } {
                    incr y $ih
                } else {
                    set y [image height $dest]
                }
                incr curRow
                set curCol 0
            }
            DelImg
            incr numImgs
        }
        AddImg $dest "" [CreateNewImgFileName "ComposedImage"]
        if { $sPo(optConvert) } {
            Convert
        }
        return $numImgs
    }

    proc RotImg { angle } {
        variable sPo
        variable sImg

        if { ! [HaveImgs] } {
            WriteInfoStr "Rotate image: No images loaded" "Error"
            return
        }

        set cur [GetCurImgNum]
        set phImg [GetCurImgPhoto]
        poWatch Reset swatch
        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sImg(poImg,$cur)] } {
                set sImg(poImg,$cur) [poImage NewImageFromPhoto $phImg]
            }
            poImageMode GetFormat savePixFmt
            set poImg $sImg(poImg,$cur)
            $poImg GetImgInfo w h a g
            $poImg GetImgFormat fmtList
            poImageMode SetFormat $fmtList
            set dstImg [poImage NewImage $h $w [expr 1.0/$a] $g]
            $dstImg GetImgFormat fmtList
            $dstImg Rotate $poImg $angle
            poImgUtil DeleteImg $poImg
            set sImg(poImg,$cur) $dstImg
            $sImg(photo,$cur) blank
            $dstImg AsPhoto [GetImgPhoto $cur]
            poImageMode SetFormat $savePixFmt
        } else {
            set rotImg [poPhotoUtil Rotate $phImg $angle]
            set sImg(photo,$cur) $rotImg
            image delete $phImg
        }
        WriteInfoStr [format "Rotate image $angle (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        ShowImg $cur
        UpdateThumb [GetImgPhoto $cur]
    }

    proc ResetZoom { { zoomValue 1.00 } } {
        variable sPo

        set sPo(zoom) $zoomValue
        set sPo(zoom,autofit) false
        ShowCurrent
    }

    proc ChangeZoom { dir } {
        variable sPo

        set zoomList [list 0.05 0.10 0.20 0.25 0.33 0.50 1.00 2.00 3.00 4.00 5.00]
        set curZoomInd [lsearch -exact $zoomList $sPo(zoom)]
        if { $curZoomInd < 0 } {
            set sPo(zoom) 1.00
        } else {
            incr curZoomInd $dir
            if { $curZoomInd < 0 } {
                set curZoomInd 0
            } elseif { $curZoomInd >= [llength $zoomList] } {
                set curZoomInd  [expr [llength $zoomList] -1]
            }
            set sPo(zoom) [lindex $zoomList $curZoomInd]
        }
        ShowCurrent
    }

    proc Zoom { zoomValue } {
        variable sPo
        variable sImg

        set curPhoto [GetCurImgPhoto]
        if { $sPo(zoom,autofit) } {
            set sw [winfo width  $sPo(mainCanv)]
            set sh [winfo height $sPo(mainCanv)]
            set w [image width  $curPhoto]
            set h [image height $curPhoto]
            set xzoom [expr {double ($sw) / $w}]
            set yzoom [expr {double ($sh) / $h}]
            set zoomFactor [poMisc Min $xzoom $yzoom]
            if { $zoomFactor >= 1.0 } {
                set zoomValue [format "%.2f" [expr int ($zoomFactor)]]
            } else {
                set zoomFactor [expr int (1.0 / $zoomFactor) + 1]
                set zoomValue [expr 1.0 / $zoomFactor]
            }
        }

        if { $zoomValue == 1.0 } {
            if { [info exists sPo(zoomPhoto)] } {
                image delete $sPo(zoomPhoto)
                unset sPo(zoomPhoto)
            }
        } else {
            set w [expr int ([image width  $curPhoto] * $zoomValue)]
            set h [expr int ([image height $curPhoto] * $zoomValue)]
            if { $zoomValue < 1.0 } {
                set sc [expr int (1.0 / $zoomValue)]
                set cmd "-subsample"
            } elseif { $zoomValue > 1.0 } {
                set sc [expr int($zoomValue)]
                set cmd "-zoom"
            }
            if { [info exists sPo(zoomPhoto)] } {
                set retVal [catch {$sPo(zoomPhoto) configure -width $w -height $h}]
                if { $retVal != 0 } {
                    WriteInfoStr "Could not zoom, because image would be too big." "Error"
                    set sPo(zoom) "1.00"
                    return
                }
            } else {
                set retVal [catch {image create photo -width $w -height $h} sPo(zoomPhoto)]
                if { $retVal != 0 } {
                    WriteInfoStr "Could not zoom, because image would be too big." "Error"
                    unset sPo(zoomPhoto)
                    set sPo(zoom) "1.00"
                    return
                }
            }
            $sPo(zoomPhoto) copy $curPhoto $cmd $sc $sc
        }
        UpdateImageMapAreas
        poSelRect  ChangeZoom $sPo(mainCanv) "SelectRect" $zoomValue
        poZoomRect ChangeZoom $sPo(mainCanv) "ZoomRect"   $zoomValue
        set sPo(zoom) [format "%.2f" $zoomValue]
        UpdateMainTitleStandard
    }

    proc DisplayLogo {} {
        variable sLogo

        set w $sLogo(w)
        set h $sLogo(h)

        if { $w > $h } {
            set ws [expr int ($sLogo(xIcon))]
            set hs [expr int ((double($h) / double ($w) ) * $sLogo(yIcon))]
        } else {
            set ws [expr int ((double($w) / double ($h) ) * $sLogo(xIcon))]
            set hs [expr int ($sLogo(yIcon))]
        }
        if { $w == $ws } {
            set xsub 1
        } else {
            set xsub [expr ($w / $ws) + 1]
        }
        if { $h == $hs } {
            set ysub 1
        } else {
            set ysub [expr ($h / $hs) + 1]
        }
        $sLogo(photoIcon) blank
        $sLogo(photoIcon) copy $sLogo(photo) -subsample $xsub $ysub -to 0 0
        if { $sLogo(file) eq "" } {
            set bindStr "Default logo"
        } else {
            set bindStr $sLogo(file)
        }
        poToolhelp AddBinding $sLogo(iconButton) $bindStr
        update
    }

    proc SwitchBindings { type } {
        variable ns
        variable sPo
        variable sLogo

        set tw $sPo(tw)
        set canv $sPo(mainCanv)

        # First disable all bindings related to the 3 different types.
        bind $tw <Key-Left>          ""
        bind $tw <Key-Right>         ""
        bind $tw <Key-Up>            ""
        bind $tw <Key-Down>          ""
        bind $tw <Shift-Key-Left>    ""
        bind $tw <Shift-Key-Right>   ""
        bind $tw <Shift-Key-Up>      ""
        bind $tw <Shift-Key-Down>    ""
        bind $tw <Control-Key-Left>  ""
        bind $tw <Control-Key-Right> ""
        bind $tw <Control-Key-Up>    ""
        bind $tw <Control-Key-Down>  ""

        $canv bind LogoText <Button-1>  ""
        $canv bind LogoRect <Button-1>  ""
        $canv bind LogoText <B1-Motion> ""
        $canv bind LogoRect <B1-Motion> ""

        poSelRect Disable $canv "SelectRect"

        set sPo(curCursor) "crosshair"
        $canv configure -closeenough 1

        $canv bind MyImage <Motion> "${ns}::PrintPixelValue $canv %x %y"
        $canv bind MyImage <Leave>  "${ns}::ClearPixelValue"

        set sLogo(show) 0
        SetLogoPos
        SetLogoColor
        if { ! [string is integer -strict $sLogo(xoff)] } {
            set sLogo(xoff) 0
        }
        if { ! [string is integer -strict $sLogo(yoff)] } {
            set sLogo(yoff) 0
        }

        switch -exact $type {
            "Area" {
                bind $tw <Key-Left>  "${ns}::ShiftArea -1  0"
                bind $tw <Key-Right> "${ns}::ShiftArea  1  0"
                bind $tw <Key-Up>    "${ns}::ShiftArea  0 -1"
                bind $tw <Key-Down>  "${ns}::ShiftArea  0  1"
                # ScaleArea leftSide topSide rightSide bottomSide
                bind $tw <Shift-Key-Up>      "${ns}::ScaleArea     { -1 -1  1  1 }"
                bind $tw <Shift-Key-Down>    "${ns}::ScaleArea     {  1  1 -1 -1 }"
                bind $tw <Control-Key-Left>  "${ns}::ScaleAreaRect {  1  0 -1  0 }"
                bind $tw <Control-Key-Right> "${ns}::ScaleAreaRect { -1  0  1  0 }"
                bind $tw <Control-Key-Up>    "${ns}::ScaleAreaRect {  0 -1  0  1 }"
                bind $tw <Control-Key-Down>  "${ns}::ScaleAreaRect {  0  1  0 -1 }"

                if { [GetNumAreas] > 0 } {
                    set tagName [CreateAreaName $sPo(imageMap,curArea)]
                    set coordList [$canv coords $tagName]
                    set dx [expr { [lindex $coordList 2] - [lindex $coordList 0] }]
                    set dy [expr { [lindex $coordList 3] - [lindex $coordList 1] }]
                    set closeEnough [expr [poMisc Max $dx $dy] * 0.5]
                    $canv configure -closeenough $closeEnough
                }
            }
            "Logo" {
                bind $tw <Key-Left>          "${ns}::SetLogoPosCB -1  0"
                bind $tw <Key-Right>         "${ns}::SetLogoPosCB  1  0"
                bind $tw <Key-Up>            "${ns}::SetLogoPosCB  0 -1"
                bind $tw <Key-Down>          "${ns}::SetLogoPosCB  0  1"
                bind $tw <Shift-Key-Left>    "${ns}::SetLogoPosCB -10   0"
                bind $tw <Shift-Key-Right>   "${ns}::SetLogoPosCB  10   0"
                bind $tw <Shift-Key-Up>      "${ns}::SetLogoPosCB   0 -10"
                bind $tw <Shift-Key-Down>    "${ns}::SetLogoPosCB   0  10"
                bind $tw <Control-Key-Left>  "${ns}::SetLogoPosCB [expr -1 * $sLogo(w)] 0"
                bind $tw <Control-Key-Right> "${ns}::SetLogoPosCB [expr  1 * $sLogo(w)] 0"
                bind $tw <Control-Key-Up>    "${ns}::SetLogoPosCB 0 [expr -1 * $sLogo(h)]"
                bind $tw <Control-Key-Down>  "${ns}::SetLogoPosCB 0 [expr  1 * $sLogo(h)]"

                $canv bind LogoText  <Button-1>  "${ns}::SetCurMousePos %x %y"
                $canv bind LogoRect  <Button-1>  "${ns}::SetCurMousePos %x %y"
                $canv bind LogoText  <B1-Motion> "${ns}::MoveViewportRect %x %y"
                $canv bind LogoRect  <B1-Motion> "${ns}::MoveViewportRect %x %y"
                set sPo(curCursor) "hand1"

                set closeEnough [expr [poMisc Max $sLogo(w) $sLogo(h)] * 0.5]
                $canv configure -closeenough $closeEnough

                set sLogo(show) 1
                $canv raise LogoText
                $canv raise LogoRect
                $canv raise LogoLine
                SetLogoPos
            }
            "SelRect" {
                poSelRect Enable $canv "SelectRect"

                bind $tw <Key-Left>  "${ns}::ShiftSelRect -1  0"
                bind $tw <Key-Right> "${ns}::ShiftSelRect  1  0"
                bind $tw <Key-Up>    "${ns}::ShiftSelRect  0 -1"
                bind $tw <Key-Down>  "${ns}::ShiftSelRect  0  1"

                bind $tw <Shift-Key-Right> "${ns}::ScaleSelRect  0  0  1  0"
                bind $tw <Shift-Key-Left>  "${ns}::ScaleSelRect  0  0 -1  0"
                bind $tw <Shift-Key-Down>  "${ns}::ScaleSelRect  0  0  0  1"
                bind $tw <Shift-Key-Up>    "${ns}::ScaleSelRect  0  0  0 -1"
            }
        }
        $canv configure -cursor $sPo(curCursor)
    }

    proc GetNewLogoColor { labelId } {
        variable sLogo

        set newColor [tk_chooseColor -initialcolor $sLogo(color)]
        if { $newColor ne "" } {
            set sLogo(color) $newColor
            $labelId configure -background $newColor
        }
    }

    proc TileImg {} {
        variable sPo

        if { $sPo(tile,xrepeat) < 1 || $sPo(tile,yrepeat) < 1 } {
            WriteInfoStr "Repeat factor must be greater than 0." "Error"
            return
        }
        if { ! [HaveImgs] } {
            WriteInfoStr "Tile images: No images loaded" "Error"
            return
        }
        poWatch Reset swatch
        set tileImg [poPhotoUtil Tile [GetCurImgPhoto] \
                                 $sPo(tile,xrepeat) $sPo(tile,yrepeat) \
                                 $sPo(tile,xmirror) $sPo(tile,ymirror)]
        WriteInfoStr [format "Tile images (%.2f sec)" [poWatch Lookup swatch]] "Ok"

        AddImg $tileImg "" [CreateNewImgFileName "Tiledimage"]
    }

    proc ComposeImgs {} {
        variable sPo

        set numColumns $sPo(compose,numCols)
        if { ! [poMath CheckIntRange $sPo(compose,numCols) 1 $sPo(compose,maxCols)] } {
            WriteInfoStr "Number of columns must be between 1 and $sPo(compose,maxCols)." "Error"
            return
        }
        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }
        set dest [image create photo]
        set x 0
        set y 0
        set curCol 0
        set curRow 0
        set numImgs 0

        for { set i 0 } { $i < [GetNumImgs] } { incr i } {
            WriteInfoStr "Compose image $i to row $curRow column $curCol ..." "Watch"
            set phImg [GetImgPhoto $i]
            $dest copy $phImg -to $x $y
            incr x [image width $phImg]
            incr curCol
            if { $curCol >= $numColumns } {
                set x 0
                set y [image height $dest]
                incr curRow
                set curCol 0
            }
            incr numImgs
        }
        WriteInfoStr "Composed [GetNumImgs] images in $numColumns columns" "Ok"
        AddImg $dest "" [CreateNewImgFileName "ComposedImage"]
    }

    proc SetResolution { phImg xdpi ydpi } {
        poImgType SetResolution $phImg $xdpi $ydpi
        UpdateInfoWidget
    }

    proc ScaleImg { imgNum nw nh xdpi ydpi } {
        variable sPo
        variable sImg

        if { $nw <= 0 || $nh <= 0 } {
            error "New image dimensions must be greater than 0."
        }

        if { [poApps GetVerbose] } {
            puts "Scale image [GetImgName $imgNum] to new size: $nw x $nh"
        }

        poWatch Reset swatch
        if { ! [info exists sImg(poImg,$imgNum)] } {
            set sImg(poImg,$imgNum) [poImage NewImageFromPhoto [GetImgPhoto $imgNum]]
        }
        set srcImg $sImg(poImg,$imgNum)
        poImageMode GetFormat savePixFmt
        $srcImg GetImgFormat fmtList
        poImageMode SetFormat $fmtList
        set dstImg [poImage NewImage $nw $nh]
        set dstPhoto [image create photo -width $nw -height $nh]

        $srcImg GetImgInfo sw sh a g
        $dstImg ScaleRect $srcImg 0 0 $sw $sh 0 0 $nw $nh true
        $dstImg AsPhoto $dstPhoto
        poImageMode SetFormat $savePixFmt
        WriteInfoStr [format "Scale image $nw $nh (%.2f sec)" [poWatch Lookup swatch]] "Ok"

        SetResolution $dstPhoto $xdpi $ydpi

        set newImgPath [GetNewImgName [GetImgName $imgNum] "Scale_"]
        return [AddImg $dstPhoto $dstImg $newImgPath]
    }

    proc BatchCount {} {
        set curPhoto [GetCurImgPhoto]
        poPhotoUtil CountColors $curPhoto pixelArray
        puts "Number of unique colors in [GetCurImgName]: [array size pixelArray]"

        if { [poApps GetVerbose] } {
            set colorNum 1
            foreach key [lsort -integer -index 0 [array names pixelArray]] {
                lassign $key r g b
                puts [format "Color %5d: %3d,%3d,%3d  Count: %d" $colorNum $r $g $b $pixelArray($key)]
                incr colorNum
            }
        }
    }

    proc BatchHistogram {} {
        set img [GetCurImgPhoto]
        set descr ""
        if { [poImgAppearance UsePoImg] } {
            if { [poImgMisc IsPhoto $img] } {
                set poImg [poImage NewImageFromPhoto $img]
            } else {
                set poImg $img
            }
            set histoDict [poImgUtil Histogram $poImg $descr]
            if { [poImgMisc IsPhoto $img] } {
                poImgUtil DeleteImg $poImg
            }
        } else  {
            set histoDict [poPhotoUtil Histogram $img $descr]
        }

        set colorList [list "red" "green" "blue"]
        # Write header line with column names.
        puts -nonewline "Index"
        foreach color $colorList {
            puts -nonewline [format ",%s" [string totitle $color]]
        }
        puts ""

        # Write values.
        for { set i 0 } { $i < 256 } { incr i } {
            puts -nonewline "$i"
            foreach color $colorList {
                set histoList [dict get $histoDict $color]
                puts -nonewline ",[lindex $histoList $i]"
            }
            puts ""
        }
    }

    proc BatchRawInfo { fileOrDirList } {
        set numFiles [llength $fileOrDirList]
        if { $numFiles == 0 } {
            return 0
        }

        set numImgs 0
        puts "FileName,Width,Height,PixelSize,NumChannels,Min,Max,Mean,StdDev"
        foreach fileOrDirName $fileOrDirList {
            if { [file isdirectory $fileOrDirName] } {
                continue
            }
            set fileName [poMisc FileSlashName $fileOrDirName]
            if { [poType IsImage $fileName "flir"] } {
                set rawDict [poFlirParse ReadImageFile $fileName]
            } elseif { [poType IsImage $fileName "ppm"] } {
                set rawDict [poPpmParse ReadImageFile $fileName]
            } else {
                set rawDict [poRawParse ReadImageFile $fileName]
            }
            poImgDict GetImageMinMax     rawDict
            poImgDict GetImageMeanStdDev rawDict

            set width    [poImgDict GetWidth             rawDict]
            set height   [poImgDict GetHeight            rawDict]
            set pixSize  [poImgDict GetPixelSize         rawDict]
            set numChans [poImgDict GetNumChannels       rawDict]
            set min      [poImgDict GetMinValueAsString  rawDict]
            set max      [poImgDict GetMaxValueAsString  rawDict]
            set mean     [poImgDict GetMeanValueAsString rawDict]
            set stdDev   [poImgDict GetStdDevAsString    rawDict]
            puts "[file tail $fileName],$width,$height,$pixSize,$numChans,$min,$max,$mean,$stdDev"
            incr numImgs
        }
        return $numImgs
    }

    proc BatchScale { scaleX scaleY } {
        variable sPo
        variable sImg

        set curNum   [GetCurImgNum]
        set curPhoto [GetCurImgPhoto]

        set ow [image width  $curPhoto]
        set oh [image height $curPhoto]

        set oxdpi [GetCurImgPhotoHoriResolution]
        set oydpi [GetCurImgPhotoVertResolution]

        set nw $scaleX
        set nh $scaleY

        if { $sPo(optKeepAspect) } {
            if { $ow > $oh } {
                set nh [expr {int ($scaleX * ( double ($oh) / double ($ow) )) }]
            } else {
                set nw [expr {int ($scaleY * ( double ($ow) / double ($oh) )) }]
            }
        } else {
            if { [string match "*%" $scaleX] } {
                scan $scaleX "%f" percent
                set nw [expr {int ($ow * $percent / 100.0)}]
            }
            if { [string match "*%" $scaleY] } {
                scan $scaleY "%f" percent
                set nh [expr {int ($oh * $percent / 100.0)}]
            }
        }
        if { $sPo(optAdjustResolution) } {
            set nxdpi [expr {$oxdpi * double ($nw) / double ($ow)}]
            set nydpi [expr {$oydpi * double ($nh) / double ($oh)}]
        } else {
            set nxdpi $oxdpi
            set nydpi $oydpi
        }
        set newImgNum [ScaleImg $curNum $nw $nh $nxdpi $nydpi]
    }

    proc BatchPalette { inverseMap } {
        variable sPo
        variable sImg

        set imgName [GetCurImgName]

        if { [poApps GetVerbose] } {
            puts "Mapping image $imgName with palette [file tail [poImgPalette GetPaletteFile]]"
        }

        set paletteColorList [poImgPalette GetPaletteColorList]
        if { [llength $paletteColorList] == 0 } {
            WriteInfoStr "No palette loaded" "Error"
            return
        }
        poWatch Reset swatch
        set chanNum [poImgPalette GetChannelNum]
        set newImg [poPhotoUtil AssignPalette [GetCurImgPhoto] $chanNum $paletteColorList $inverseMap]
        WriteInfoStr [format "Assign palette (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        AddImg $newImg "" $imgName
    }

    proc DoSetResolution {} {
        variable sPo

        set xdpi $sPo(scale,new,dpi,w)
        set ydpi $sPo(scale,new,dpi,h)
        SetResolution [GetCurImgPhoto] $xdpi $ydpi
    }

    proc DoScaleImg {} {
        variable sPo
        variable sImg

        set nw   $sPo(scale,new,pix,w)
        set nh   $sPo(scale,new,pix,h)
        set xdpi $sPo(scale,new,dpi,w)
        set ydpi $sPo(scale,new,dpi,h)

        if { $nw <= 0 || $nh <= 0 } {
            WriteInfoStr "New image dimensions must be greater than 0." "Error"
            return
        }

        FillScaleRollUp true
        ScaleImg [GetCurImgNum] $nw $nh $xdpi $ydpi
    }

    proc UpdateScaleFactors { scaleType dir } {
        variable sPo

        set curPix(w) $sPo(scale,cur,pix,w)
        set curPix(h) $sPo(scale,cur,pix,h)
        set curDpi(w) $sPo(scale,cur,dpi,w)
        set curDpi(h) $sPo(scale,cur,dpi,h)

        if { $dir eq "w" } {
            set otherDir "h"
        } else {
            set otherDir "w"
        }

        if { $scaleType eq "pix" } {
            if { $sPo(scale,new,pix,$dir) eq "" } {
                set sPo(scale,new,per,$dir) ""
                if { $sPo(scale,adjustResolution) } {
                    set sPo(scale,new,dpi,$dir) ""
                }
            } else {
                set sPo(scale,new,per,$dir) [format "%.2f" [expr {$sPo(scale,new,pix,$dir) * 100.0 / $curPix($dir)}]]
                if { $sPo(scale,keepAspect) } {
                    set sPo(scale,new,per,$otherDir) $sPo(scale,new,per,$dir)
                    set sPo(scale,new,pix,$otherDir) [expr {int ($curPix($otherDir) * $sPo(scale,new,per,$otherDir) / 100.0)}]
                }
                if { $sPo(scale,adjustResolution) } {
                    set dpi1 [expr { $sPo(scale,new,per,$dir)      / 100.0 * $curDpi($dir) }]
                    set dpi2 [expr { $sPo(scale,new,per,$otherDir) / 100.0 * $curDpi($otherDir) }]
                    set sPo(scale,new,dpi,$dir)      [format "%.2f" $dpi1]
                    set sPo(scale,new,dpi,$otherDir) [format "%.2f" $dpi2]
                } else {
                    set sPo(scale,new,dpi,$dir)      $curDpi($dir)
                    set sPo(scale,new,dpi,$otherDir) $curDpi($otherDir)
                }
            }
        } elseif { $scaleType eq "per" } {
            if { $sPo(scale,new,per,$dir) eq "" } {
                set sPo(scale,new,pix,$dir) ""
                if { $sPo(scale,adjustResolution) } {
                    set sPo(scale,new,dpi,$dir) ""
                }
            } else {
                set sPo(scale,new,pix,$dir) [expr {int ($curPix($dir) * $sPo(scale,new,per,$dir) / 100.0)}]
                if { $sPo(scale,keepAspect) } {
                    set sPo(scale,new,per,$otherDir) $sPo(scale,new,per,$dir)
                    set sPo(scale,new,pix,$otherDir) [expr {int ($curPix($otherDir) * $sPo(scale,new,per,$otherDir) / 100.0)}]
                }
                if { $sPo(scale,adjustResolution) } {
                    set dpi1 [expr { $sPo(scale,new,per,$dir)      / 100.0 * $curDpi($dir) }]
                    set dpi2 [expr { $sPo(scale,new,per,$otherDir) / 100.0 * $curDpi($otherDir) }]
                    set sPo(scale,new,dpi,$dir)      [format "%.2f" $dpi1]
                    set sPo(scale,new,dpi,$otherDir) [format "%.2f" $dpi2]
                } else {
                    set sPo(scale,new,dpi,$dir)      $curDpi($dir)
                    set sPo(scale,new,dpi,$otherDir) $curDpi($otherDir)
                }
            }
        }
    }

    proc CreateInfoRollUp { infoFr } {
        variable ns
        variable sPo

        set rollUp [poWinRollUp Create $infoFr "Information"]

        set sPo(pixelInfoRollUp) [poWinRollUp Add $rollUp "Image" true]
        InitPixelInfoRollUp $sPo(pixelInfoRollUp)

        set sPo(selRectInfoRollUp) [poWinRollUp Add $rollUp "Selection rectangle" false]
        InitSelRectInfoRollUp $sPo(selRectInfoRollUp)
    }

    proc CreateToolsRollUp { infoFr } {
        variable ns
        variable sPo

        set rollUp [poWinRollUp Create $infoFr "Tools"]

        set sPo(convertRollUp) [poWinRollUp Add $rollUp "Convert" false]
        InitConvertRollUp $sPo(convertRollUp)

        set sPo(composeRollUp) [poWinRollUp Add $rollUp "Compose" false]
        InitComposeRollUp $sPo(composeRollUp)

        set sPo(logoRollUp) [poWinRollUp Add $rollUp "Logo" false]
        bind $sPo(logoRollUp) <<RollUpOpened>> "${ns}::SwitchBindings Logo"
        bind $sPo(logoRollUp) <<RollUpClosed>> "${ns}::SwitchBindings SelRect"
        InitLogoRollUp $sPo(logoRollUp)

        set sPo(scaleRollUp) [poWinRollUp Add $rollUp "Scale" false]
        bind $sPo(scaleRollUp) <<RollUpOpened>> "${ns}::FillScaleRollUp"
        InitScaleRollUp $sPo(scaleRollUp)

        set sPo(tileRollUp) [poWinRollUp Add $rollUp "Tile" false]
        InitTileRollUp $sPo(tileRollUp)
    }

    proc UpdateRollUps { { forceClear false } } {
        variable sPo

        if { [poWinRollUp IsOpen $sPo(scaleRollUp)] } {
            FillScaleRollUp $forceClear
        }
    }

    proc InitConvertRollUp { masterFr } {
        variable ns
        variable sPo
        variable sConv

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Format:" \
                           "Template:" \
                           "Counter:" \
                           "Directory:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid  $masterFr.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Generate right column with entries and buttons.

        # Row 0: Output format
        set row 0
        ttk::frame $masterFr.fr$row
        grid  $masterFr.fr$row -row $row -column 1 -sticky news

        ttk::combobox $masterFr.fr$row.cb -state readonly

        set fmtList [poImgType GetFmtList]
        set fmtList [linsert $fmtList 0 "SameAsInput"]
        set ind 0
        foreach fmt $fmtList {
            if { $fmt eq "SameAsInput" } {
                set fmtSuff "*"
            } else {
                set fmtSuff [lindex [poImgType GetExtList $fmt] 0]
            }
            set str [format "%s (%s)" $fmt $fmtSuff]
            lappend strList $str
            if { $fmt eq $sConv(outFmt) } {
                set showInd $ind
            }
            incr ind
        }
        $masterFr.fr$row.cb configure -values $strList
        $masterFr.fr$row.cb current $showInd
        bind $masterFr.fr$row.cb <<ComboboxSelected>> "${ns}::UpdFileTypeCB $masterFr.fr$row.cb"

        pack $masterFr.fr$row.cb -side top -anchor w -fill x -expand 1

        # Row 1: Output filename template
        incr row
        ttk::entry $masterFr.e$row -textvariable ${ns}::sConv(name)
        grid $masterFr.e$row -row $row -column 1 -sticky news

        # Row 2: Output file number counter
        incr row
        ttk::entry $masterFr.e$row -textvariable ${ns}::sConv(num)
        grid $masterFr.e$row -row $row -column 1 -sticky news

        # Row 3: Output directory
        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky news

        ttk::radiobutton $masterFr.fr$row.rb1 -text "Same as input directory" \
                    -variable ${ns}::sConv(useOutDir) -value false
        ttk::radiobutton $masterFr.fr$row.rb2 -text "Use this directory for all images:" \
                    -variable ${ns}::sConv(useOutDir) -value true
        pack $masterFr.fr$row.rb1 $masterFr.fr$row.rb2 -side top -anchor w

        ttk::frame $masterFr.fr$row.fr
        pack $masterFr.fr$row.fr -side top -anchor w

        set comboId [poWinSelect CreateDirSelect $masterFr.fr$row.fr $sConv(outDir) [poBmpData openDir] \
                                                    "Select conversion output directory"]
        bind $comboId <<NameValid>> "${ns}::GetConvOutDir $comboId"

        # Row 3: Conversion buttons
        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news

        ttk::button $masterFr.fr$row.bcur -text "Convert current image" -command "${ns}::Convert"
        ttk::button $masterFr.fr$row.ball -text "Convert loaded images" -command "${ns}::ConvertAll"
        pack $masterFr.fr$row.bcur $masterFr.fr$row.ball -side top -anchor w -fill x -pady 2

        grid columnconfigure $masterFr 1 -weight 1
    }

    proc InitComposeRollUp { masterFr } {
        variable ns
        variable sPo

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Number of columns:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid $masterFr.l$row -row $row -column 0 -sticky news
            incr row
        }

        # Generate right column with entries and buttons.
        set row 0
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        spinbox $fr.e -textvariable ${ns}::sPo(compose,numCols) -width 2 \
                -from 1 -to $sPo(compose,maxCols) -increment 1 \
                -command "poWin CheckValidInt $fr.e $fr.l 1 $sPo(compose,maxCols)"
        ttk::label $fr.l
        poWin CheckValidInt $fr.e $fr.l 1 $sPo(compose,maxCols)
        bind $fr.e <Any-KeyRelease> "poWin CheckValidInt $fr.e $fr.l 1 $sPo(compose,maxCols)"

        pack $fr.e $fr.l -in $fr -side left -padx 2

        # Create Compose button
        incr row
        ttk::frame $masterFr.fr$row
        grid  $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news
        ttk::button $masterFr.fr$row.b1 -text "Compose loaded images" -command "${ns}::ComposeImgs" \
                                        -default active
        pack $masterFr.fr$row.b1 -side left -fill x -pady 2 -expand 1

        grid columnconfigure $masterFr 1 -weight 1
    }

    proc InitLogoRollUp { masterFr } {
        variable ns
        variable sPo
        variable sLogo

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Offset X:" \
                           "Offset Y:" \
                           "Position:" \
                           "Color:" \
                           "Image file:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid  $masterFr.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Generate right column with entries and buttons.
        # Row 0: Horizontal logo offset.
        set row 0
        ttk::entry $masterFr.e$row -textvariable ${ns}::sLogo(xoff)
        bind $masterFr.e$row <Any-KeyRelease> ${ns}::SetLogoPosCB
        grid $masterFr.e$row -row $row -column 1 -sticky new

        # Row 1: Vertical logo offset.
        incr row
        ttk::entry $masterFr.e$row -textvariable ${ns}::sLogo(yoff)
        bind $masterFr.e$row <Any-KeyRelease> ${ns}::SetLogoPosCB
        grid $masterFr.e$row -row $row -column 1 -sticky new

        # Row 2: Logo position.
        incr row
        ttk::frame $masterFr.fr$row
        grid  $masterFr.fr$row -row $row -column 1 -sticky new -pady 3

        ttk::radiobutton $masterFr.fr$row.tl -image [poBmpData topleft] -style Toolbutton \
                         -variable ${ns}::sLogo(pos) -value tl -command ${ns}::SetLogoPosCB
        ttk::radiobutton $masterFr.fr$row.tr -image [poBmpData topright] -style Toolbutton \
                         -variable ${ns}::sLogo(pos) -value tr -command ${ns}::SetLogoPosCB
        ttk::radiobutton $masterFr.fr$row.bl -image [poBmpData bottomleft] -style Toolbutton \
                         -variable ${ns}::sLogo(pos) -value bl -command ${ns}::SetLogoPosCB
        ttk::radiobutton $masterFr.fr$row.br -image [poBmpData bottomright] -style Toolbutton \
                         -variable ${ns}::sLogo(pos) -value br -command ${ns}::SetLogoPosCB
        ttk::radiobutton $masterFr.fr$row.ce -image [poBmpData center] -style Toolbutton \
                         -variable ${ns}::sLogo(pos) -value ce -command ${ns}::SetLogoPosCB
        pack $masterFr.fr$row.tl $masterFr.fr$row.tr $masterFr.fr$row.bl $masterFr.fr$row.br \
             $masterFr.fr$row.ce -side left -padx 2

        # Row 3: Logo color.
        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky new -pady 1

        label $masterFr.fr$row.l -width 10 -relief sunken -background $sLogo(color)
        ttk::button $masterFr.fr$row.b -text "Select ..." \
                                 -command "${ns}::GetNewLogoColor $masterFr.fr$row.l"
        pack $masterFr.fr$row.l $masterFr.fr$row.b -side left -fill x -expand 1

        # Row 4: Image file name used for logo.
        incr row
        set sLogo(photoIcon) $masterFr.p$row
        image create photo $sLogo(photoIcon) \
              -width $sLogo(xIcon) -height $sLogo(yIcon)
        ttk::button $masterFr.b$row -image $sLogo(photoIcon) -command ${ns}::OpenIcon
        grid $masterFr.b$row -row $row -column 1 -sticky new -pady 1
        set sLogo(iconButton) $masterFr.b$row

        # Row 5: Command buttons
        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news

        ttk::button $masterFr.fr$row.bcur -text "Add logo to current image" -command "${ns}::ApplyLogo"
        ttk::button $masterFr.fr$row.ball -text "Add logo to loaded images" -command "${ns}::ApplyLogoAll"
        pack $masterFr.fr$row.bcur $masterFr.fr$row.ball -side top -anchor w -fill x -pady 2

        DisplayLogo
    }

    proc InitNoiseRollUp { masterFr } {
        variable ns
        variable sPo

        set scaleLen  100
        set entryLen    6

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Seed:" \
                           "Period:" \
                           "Coherence:" \
                           "Z-Slice:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid  $masterFr.l$row -row $row -column 0 -sticky news
            incr row
        }

        set row 0
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky news
        ttk::scale $masterFr.fr$row.sx -from 0 -to 50 \
                            -length $scaleLen -orient horizontal \
                            -variable ${ns}::sPo(noise,seed) \
                            -command "${ns}::UpdateNoiseParam seed 0"
        ttk::entry $masterFr.fr$row.ex -textvariable ${ns}::sPo(noise,seed) -width $entryLen
        pack $masterFr.fr$row.sx $masterFr.fr$row.ex -side left -anchor w -pady 2
        bind $masterFr.fr$row.sx <ButtonRelease-1> ${ns}::UpdateNoiseImg
        bind $masterFr.fr$row.sx <ButtonRelease-2> ${ns}::UpdateNoiseImg

        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky news
        ttk::scale $masterFr.fr$row.sx -from 1 -to 12 \
                            -length $scaleLen -orient horizontal \
                            -variable ${ns}::sPo(noise,period) \
                            -command "${ns}::UpdateNoiseParam period 0"
        ttk::entry $masterFr.fr$row.ex -textvariable ${ns}::sPo(noise,period) -width $entryLen
        pack $masterFr.fr$row.sx $masterFr.fr$row.ex -side left -anchor w -pady 2
        bind $masterFr.fr$row.sx <ButtonRelease-1> ${ns}::UpdateNoiseImg
        bind $masterFr.fr$row.sx <ButtonRelease-2> ${ns}::UpdateNoiseImg

        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky news
        ttk::scale $masterFr.fr$row.sx -from 0 -to 11 \
                            -length $scaleLen -orient horizontal \
                            -variable ${ns}::sPo(noise,coherence) \
                            -command "${ns}::UpdateNoiseParam coherence 0"
        ttk::entry $masterFr.fr$row.ex -textvariable ${ns}::sPo(noise,coherence) -width $entryLen
        pack $masterFr.fr$row.sx $masterFr.fr$row.ex -side left -anchor w -pady 2
        bind $masterFr.fr$row.sx <ButtonRelease-1> ${ns}::UpdateNoiseImg
        bind $masterFr.fr$row.sx <ButtonRelease-2> ${ns}::UpdateNoiseImg

        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 1 -sticky news
        ttk::scale $masterFr.fr$row.sx -from -10.0 -to 10.0 \
                            -length $scaleLen -orient horizontal \
                            -variable ${ns}::sPo(noise,z-slice) \
                            -command "${ns}::UpdateNoiseParam z-slice 1"
        ttk::entry $masterFr.fr$row.ex -textvariable ${ns}::sPo(noise,z-slice) -width $entryLen
        pack $masterFr.fr$row.sx $masterFr.fr$row.ex -side left -anchor w -pady 2
        bind $masterFr.fr$row.sx <ButtonRelease-1> ${ns}::UpdateNoiseImg
        bind $masterFr.fr$row.sx <ButtonRelease-2> ${ns}::UpdateNoiseImg

        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news
        set sPo(noise,canv) $masterFr.fr$row.c
        canvas $sPo(noise,canv) -width $sPo(noise,previewSize) -height $sPo(noise,previewSize)
        pack $sPo(noise,canv) -expand 1 -fill both
        if { ! [info exists sPo(noise,phImg)] } {
            set sPo(noise,phImg) [image create photo -width $sPo(noise,previewSize) -height $sPo(noise,previewSize)]
        }
        $sPo(noise,canv) create image 0 0 -anchor nw -tags texImg
        $sPo(noise,canv) itemconfigure texImg -image $sPo(noise,phImg)

        grid columnconfigure $masterFr 1 -weight 1

        UpdateNoiseImg
    }
 
    proc InitTileRollUp { masterFr } {
        variable ns
        variable sPo

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Repeat horizontally:" \
                           "Repeat vertically:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid $masterFr.l$row -row $row -column 0 -sticky news
            incr row
        }

        # Generate right column with entries and buttons.
        set row 0
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        spinbox $fr.e -textvariable ${ns}::sPo(tile,xrepeat) -width 2 \
                -from 1 -to $sPo(tile,maxRepeatX) -increment 1 \
                -command "poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatX)"
        ttk::label $fr.l
        ttk::checkbutton $fr.b -text "Mirror" -variable ${ns}::sPo(tile,xmirror)
        poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatX)
        bind $fr.e <Any-KeyRelease> "poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatX)"
        pack $fr.e $fr.l $fr.b -in $fr -side left -padx 2

        incr row
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        spinbox $fr.e -textvariable ${ns}::sPo(tile,yrepeat) -width 2 \
                -from 1 -to $sPo(tile,maxRepeatY) -increment 1 \
                -command "poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatY)"
        ttk::label $fr.l
        ttk::checkbutton $fr.b -text "Mirror" -variable ${ns}::sPo(tile,ymirror)
        poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatY)
        bind $fr.e <Any-KeyRelease> "poWin CheckValidInt $fr.e $fr.l 1 $sPo(tile,maxRepeatY)"
        pack $fr.e $fr.l $fr.b -in $fr -side left -padx 2

        # Create Tile button
        incr row
        ttk::frame $masterFr.fr$row
        grid  $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news
        ttk::button $masterFr.fr$row.b1 -text "Tile current image" -command "${ns}::TileImg" \
                                  -default active
        pack $masterFr.fr$row.b1 -side left -fill x -pady 2 -expand 1

        grid columnconfigure $masterFr 1 -weight 1
    }

    proc InitScaleRollUp { masterFr } {
        variable ns
        variable sPo

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Current size (pixel):" \
                           "New size (pixel):" \
                           "New size (percent):" \
                           "New resolution (DPI):" \
                           "Options:" } {
            ttk::label $masterFr.l$row -text $labelStr
            grid $masterFr.l$row -row $row -column 0 -sticky new
            incr row
        }

        FillScaleRollUp

        # Generate right column with entries and buttons.

        # Info only: Current image size
        set row 0
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        ttk::entry $fr.w -textvariable ${ns}::sPo(scale,cur,pix,w) -width 6
        $fr.w configure -state readonly
        ttk::label $fr.x -text " x "
        ttk::entry $fr.h -textvariable ${ns}::sPo(scale,cur,pix,h) -width 6
        $fr.h configure -state readonly
        pack $fr.w $fr.x $fr.h -in $fr -side left -padx 2

        # Entry widgets for new size in pixels
        incr row
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        ttk::entry $fr.w -textvariable ${ns}::sPo(scale,new,pix,w) -width 6
        ttk::label $fr.x -text " x "
        ttk::entry $fr.h -textvariable ${ns}::sPo(scale,new,pix,h) -width 6
        pack $fr.w $fr.x $fr.h -in $fr -side left -padx 2
        bind $fr.w <Any-KeyRelease> "${ns}::UpdateScaleFactors pix w"
        bind $fr.h <Any-KeyRelease> "${ns}::UpdateScaleFactors pix h"

        # Entry widgets for new size in percent
        incr row
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        ttk::entry $fr.w -textvariable ${ns}::sPo(scale,new,per,w) -width 6
        ttk::label $fr.x -text " x "
        ttk::entry $fr.h -textvariable ${ns}::sPo(scale,new,per,h) -width 6
        pack $fr.w $fr.x $fr.h -in $fr -side left -padx 2
        bind $fr.w <Any-KeyRelease> "${ns}::UpdateScaleFactors per w"
        bind $fr.h <Any-KeyRelease> "${ns}::UpdateScaleFactors per h"

        # Entry widgets for new resolution in DPI
        incr row
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        ttk::entry $fr.w -textvariable ${ns}::sPo(scale,new,dpi,w) -width 6
        ttk::label $fr.x -text " x "
        ttk::entry $fr.h -textvariable ${ns}::sPo(scale,new,dpi,h) -width 6
        pack $fr.w $fr.x $fr.h -in $fr -side left -padx 2
        bind $fr.w <Any-KeyRelease> "${ns}::UpdateScaleFactors dpi w"
        bind $fr.h <Any-KeyRelease> "${ns}::UpdateScaleFactors dpi h"
        if { ! [poImgType HaveDpiSupport] } {
            $fr.w configure -state disabled
            $fr.h configure -state disabled
            poToolhelp AddBinding $fr.w "No resolution support available."
            poToolhelp AddBinding $fr.h "No resolution support available."
        }

        # Option buttons
        incr row
        set fr [ttk::frame $masterFr.fr$row]
        grid $fr -row $row -column 1 -sticky news
        ttk::checkbutton $fr.a -text "Preserve aspect ratio" -variable ${ns}::sPo(scale,keepAspect)
        ttk::checkbutton $fr.r -text "Adjust resolution"     -variable ${ns}::sPo(scale,adjustResolution)
        pack $fr.a $fr.r -in $fr -side top -padx 2 -anchor w
        if { ! [poImgType HaveDpiSupport] } {
            $fr.r configure -state disabled
            poToolhelp AddBinding $fr.r "No resolution support available."
        }

        # Create Scale button
        incr row
        ttk::frame $masterFr.fr$row
        grid $masterFr.fr$row -row $row -column 0 -columnspan 2 -sticky news

        ttk::button $masterFr.fr$row.b1 -text "Scale current image" -command "${ns}::DoScaleImg" 
        ttk::button $masterFr.fr$row.b2 -text "Set resolution of current image" -command "${ns}::DoSetResolution"
        pack $masterFr.fr$row.b1 $masterFr.fr$row.b2 -side top -fill x -expand 1 -anchor w
        if { ! [poImgType HaveDpiSupport] } {
            $masterFr.fr$row.b2 configure -state disabled
            poToolhelp AddBinding $masterFr.fr$row.b2 "No resolution support available."
        }

        grid columnconfigure $masterFr 1 -weight 1
    }

    proc FillScaleRollUp { { forceClear false } } {
        variable ns
        variable sPo

        if { [HaveImgs] && ! $forceClear } {
            set iw   [GetCurImgPhotoWidth]
            set ih   [GetCurImgPhotoHeight]
            set xdpi [expr {int ([GetCurImgPhotoHoriResolution])}]
            set ydpi [expr {int ([GetCurImgPhotoVertResolution])}]
            set sPo(scale,cur,pix,w) $iw
            set sPo(scale,cur,pix,h) $ih
            set sPo(scale,new,pix,w) [expr {int ($iw * $sPo(scale,new,per,w) / 100.0)}]
            set sPo(scale,new,pix,h) [expr {int ($ih * $sPo(scale,new,per,h) / 100.0)}]
            set sPo(scale,cur,dpi,w) $xdpi
            set sPo(scale,cur,dpi,h) $ydpi
            set sPo(scale,new,dpi,w) $xdpi
            set sPo(scale,new,dpi,h) $ydpi
        } else {
            set sPo(scale,cur,pix,w) ""
            set sPo(scale,cur,pix,h) ""
            set sPo(scale,new,pix,w) ""
            set sPo(scale,new,pix,h) ""
            set sPo(scale,new,per,w) 100
            set sPo(scale,new,per,h) 100
            set sPo(scale,cur,dpi,w) 0.0
            set sPo(scale,cur,dpi,h) 0.0
            set sPo(scale,new,dpi,w) 0.0
            set sPo(scale,new,dpi,h) 0.0
        }
    }

    # Convert the HTML string representation of an area into
    # a list of coordinates as used by the canvas widget.
    proc Html2Canvas { type htmlCoordStr } {
        set coordList [split $htmlCoordStr ","]
        switch $type {
            "rect" {
                # Nothing to do.
                return $coordList
            }
            "circle" {
                lassign $coordList x y r
                return [list [expr {$x - $r}] [expr {$y - $r}] \
                             [expr {$x + $r}] [expr {$y + $r}]]
            }
        }
    }

    # Convert a list of coordinates as used by the canvas widget
    # into the HTML string representation of an area.
    proc Canvas2Html { type canvasCoordList { zoomFactor 1.0 } } {
        set x1 [expr {int ([lindex $canvasCoordList 0] * $zoomFactor)}]
        set y1 [expr {int ([lindex $canvasCoordList 1] * $zoomFactor)}]
        set x2 [expr {int ([lindex $canvasCoordList 2] * $zoomFactor)}]
        set y2 [expr {int ([lindex $canvasCoordList 3] * $zoomFactor)}]
        switch $type {
            "rect" {
                set htmlCoordStr [format "%d,%d,%d,%d" $x1 $y1 $x2 $y2]
            }
            "circle" {
                set r [expr {($x2 - $x1)/2}]
                set x [expr {$x1 + $r}]
                set y [expr {$y1 + $r}]
                set htmlCoordStr [format "%d,%d,%d" $x $y $r]
            }
        }
        return $htmlCoordStr
    }

    # Convert the representation of an area as used in the GUI
    # (center and width/heigth or radius) into
    # a list of coordinates as used by the canvas widget.
    proc Gui2Canvas { type x y param1 { param2 0 } } {
        switch $type {
            "rect" {
                set w $param1
                set h $param2
                set x1 [expr {$x - $w/2}]
                set y1 [expr {$y + $h/2}]
                set x2 [expr {$x + $w/2}]
                set y2 [expr {$y - $h/2}]
            }
            "circle" {
                set r $param1
                set x1 [expr {$x - $r}]
                set y1 [expr {$y - $r}]
                set x2 [expr {$x + $r}]
                set y2 [expr {$y + $r}]
            }
        }
        return [list $x1 $y1 $x2 $y2]
    }

    proc CheckAreaSelection { x y } {
        variable sPo

        set sPo(imageMap,mx) $x
        set sPo(imageMap,my) $y
        set halo 10
        set selectedItems [$sPo(mainCanv) find closest $x $y $halo]
        foreach item $selectedItems {
            foreach tag [$sPo(mainCanv) itemcget $item -tags] {
                if { [string match "Area_*" $tag] } {
                    scan $tag "Area_%d" areaId
                    SelectArea $areaId
                }
            }
        }
    }

    proc UpdateAreaCoords { areaId } {
        variable sPo

        set areaInd [GetAreaIndex $areaId]
        set tagName [CreateAreaName $areaId]
        set coordList [$sPo(mainCanv) coords $tagName]
        set areaType [GetAreaType $areaInd]
        set htmlCoord [Canvas2Html $areaType $coordList [expr {1.0 / $sPo(zoom)}]]
        SetAreaCoords $areaInd $htmlCoord
    }

    proc MoveArea { x y } {
        variable sPo

        set tag [CreateAreaName $sPo(imageMap,curArea)]
        $sPo(mainCanv) move $tag \
                       [expr {$x - $sPo(imageMap,mx)}] \
                       [expr {$y - $sPo(imageMap,my)}]
        set sPo(imageMap,mx) $x
        set sPo(imageMap,my) $y
        UpdateAreaCoords $sPo(imageMap,curArea)
        UpdateAreaCanvasText $sPo(imageMap,curArea)
    }

    proc ShiftArea { dx dy } {
        variable sPo

        if { [GetNumAreas] > 0 } {
            set tag [CreateAreaName $sPo(imageMap,curArea)]
            $sPo(mainCanv) move $tag [expr {$dx * $sPo(zoom)}] [expr {$dy * $sPo(zoom)}]
            UpdateAreaCoords $sPo(imageMap,curArea)
            UpdateAreaCanvasText $sPo(imageMap,curArea)
        }
    }

    # Params leftSide topSide rightSide bottomSide
    proc ScaleArea { scaleList } {
        variable sPo

        if { [GetNumAreas] > 0 } {
            set tagName [CreateAreaName $sPo(imageMap,curArea)]
            set coordList [$sPo(mainCanv) coords $tagName]
            set newCoords [list]
            foreach p $coordList s $scaleList {
                lappend newCoords [expr {$p + $s}]
            }
            $sPo(mainCanv) coords $tagName $newCoords
            UpdateAreaCoords $sPo(imageMap,curArea)
            UpdateAreaCanvasText $sPo(imageMap,curArea)
        }
    }

    # Params leftSide topSide rightSide bottomSide
    proc ScaleAreaRect { scaleList } {
        variable sPo

        if { [GetAreaType $sPo(imageMap,curArea)] eq "rect" } {
            ScaleArea $scaleList
        }
    }

    proc GetNumAreas {} {
        variable sPo

        return [$sPo(imageMap,table) size]
    }

    proc GetAreaId { areaInd } {
        variable sPo

        return [lindex [$sPo(imageMap,table) get $areaInd] $sPo(imageMap,table,idColumn)]
    }

    proc GetAreaType { areaInd } {
        variable sPo
        return [lindex [$sPo(imageMap,table) get $areaInd] $sPo(imageMap,table,typeColumn)]
    }

    proc GetAreaCoords { areaInd { coordType "html" } } {
        variable sPo

        set htmlCoordStr [lindex [$sPo(imageMap,table) get $areaInd] $sPo(imageMap,table,coordColumn)]
        switch $coordType {
            "html" {
                return $htmlCoordStr
            }
            "canvas" {
                set type [GetAreaType $areaInd]
                return [Html2Canvas $type $htmlCoordStr]
            }
        }
    }

    proc SetAreaCoords { areaInd htmlCoordStr } {
        variable sPo

        set coordCol $sPo(imageMap,table,coordColumn)
        $sPo(imageMap,table) cellconfigure "$areaInd,$coordCol" -text $htmlCoordStr
    }

    proc GetAreaText { areaInd } {
        variable sPo
        return [lindex [$sPo(imageMap,table) get $areaInd] $sPo(imageMap,table,textColumn)]
    }

    proc GetAreaRef { areaInd } {
        variable sPo
        return [lindex [$sPo(imageMap,table) get $areaInd] $sPo(imageMap,table,refColumn)]
    }

    proc GetAreaIndex { areaId } {
        variable sPo

        for { set i 0 } { $i < [GetNumAreas] } { incr i } {
            if { [GetAreaId $i] == $areaId } {
                return $i
            }
        }
        # Area not found
        return -1
    }

    proc CreateAreaName { areaId } {
        return "Area_$areaId"
    }

    proc UpdateImageMapAreas {} {
        variable sPo

        if { [info exists sPo(imageMap,winOpen)] } {
            for { set i 0 } { $i < [GetNumAreas] } { incr i } {
                set areaId  [GetAreaId $i]
                set tagName [CreateAreaName $areaId]
                set coordList [GetAreaCoords $i "canvas"]
                set newCoords [list]
                foreach p $coordList {
                    lappend newCoords [expr {$p * $sPo(zoom)}]
                }
                $sPo(mainCanv) coords $tagName $newCoords
            }
            UpdateAreaCanvasText $sPo(imageMap,curArea)
        }
    }

    proc UpdateAreaCanvasText { areaId } {
        variable sPo

        set areaInd [GetAreaIndex $areaId]
        set areaName [CreateAreaName $areaId]
        set coordList [$sPo(mainCanv) coords $areaName]
        set px [expr {[lindex $coordList 2] +  5}]
        set ty [expr {[lindex $coordList 1] +  0}]
        set ry [expr {[lindex $coordList 1] + 10}]
        if { $sPo(imageMap,showText) } {
            $sPo(mainCanv) itemconfigure "AreaText" \
                           -text [GetAreaText $areaInd] \
                           -fill $sPo(imageMap,color,active)
            $sPo(mainCanv) coords "AreaText" $px $ty
        }
        if { $sPo(imageMap,showRef) } {
            $sPo(mainCanv) itemconfigure "AreaRef" \
                           -text [GetAreaRef $areaInd] \
                           -fill $sPo(imageMap,color,active)
            $sPo(mainCanv) coords "AreaRef" $px $ry
        }
    }

    proc SelectArea { areaId } {
        variable sPo

        set sPo(imageMap,curArea) $areaId

        set tagName [CreateAreaName $areaId]

        $sPo(mainCanv) raise $tagName
        $sPo(mainCanv) itemconfigure "Area"   -outline $sPo(imageMap,color,other)
        $sPo(mainCanv) itemconfigure $tagName -outline $sPo(imageMap,color,active)

        set areaInd [GetAreaIndex $areaId]

        UpdateAreaCanvasText $areaId

        $sPo(imageMap,table) selection clear 0 end
        $sPo(imageMap,table) selection set $areaInd $areaInd
        $sPo(imageMap,table) see $areaInd
    }

    proc SelectAreaByTable { tableId } {
        set indList [$tableId curselection]
        if { [llength $indList] == 0 } {
            return
        }
        set areaInd [lindex $indList 0]
        set areaId  [GetAreaId $areaInd]
        SelectArea $areaId
    }

    proc NewArea { { type "" } } {
        variable sPo

        if { $type eq "" } {
            set type $sPo(imageMap,type)
        } else {
            set sPo(imageMap,type) $type
        }

        if { $sPo(imageMap,nextArea) == 0 } {
            set xcenter 30
            set ycenter 30
        } else {
            set areaId $sPo(imageMap,curArea)
            set areaInd [GetAreaIndex $areaId]
            set coordList [GetAreaCoords $areaInd "canvas"]
            set w [expr { [lindex $coordList 2] - [lindex $coordList 0] }]
            set h [expr { [lindex $coordList 3] - [lindex $coordList 1] }]
            set xcenter [expr { [lindex $coordList 0] + $w/2 + 5}]
            set ycenter [expr { [lindex $coordList 1] + $h/2 + 5}]
        }
        switch $type {
            "rect" {
                set param1 $sPo(imageMap,$type,w)
                set param2 $sPo(imageMap,$type,h)
            }
            "circle" {
                set param1 $sPo(imageMap,$type,r)
                set param2 0
            }
        }
        set canvasCoordList [Gui2Canvas $type $xcenter $ycenter $param1 $param2]
        AddArea $type $canvasCoordList $sPo(imageMap,default,text) $sPo(imageMap,default,ref)
    }

    proc AddArea { type canvasCoordList text ref } {
        variable sPo

        set areaId $sPo(imageMap,nextArea)
        incr sPo(imageMap,nextArea)
        $sPo(imageMap,table) insert end [list "" $areaId $type [Canvas2Html $type $canvasCoordList] $text $ref]

        set x1 [expr {[lindex $canvasCoordList 0] * $sPo(zoom)}]
        set y1 [expr {[lindex $canvasCoordList 1] * $sPo(zoom)}]
        set x2 [expr {[lindex $canvasCoordList 2] * $sPo(zoom)}]
        set y2 [expr {[lindex $canvasCoordList 3] * $sPo(zoom)}]
        set areaName [CreateAreaName $areaId]
        switch $type {
            "rect" {
                $sPo(mainCanv) create rectangle $x1 $y1 $x2 $y2 \
                               -outline $sPo(imageMap,color,active) \
                               -tags [list "Area" $areaName]
            }
            "circle" {
                $sPo(mainCanv) create oval $x1 $y1 $x2 $y2 \
                               -outline $sPo(imageMap,color,active) \
                               -tags [list "Area" $areaName]
            }
        }
        SelectArea $areaId
    }

    proc DeleteArea {} {
        variable sPo

        set areaId $sPo(imageMap,curArea)
        set areaInd [GetAreaIndex $areaId]

        $sPo(imageMap,table) delete $areaInd $areaInd
        $sPo(mainCanv) delete [CreateAreaName $areaId]

        # Now select the next best area.
        if { $areaInd >= [GetNumAreas] } {
            incr areaInd -1
        }
        if { $areaInd >= 0 } {
            set newId [GetAreaId $areaInd]
            SelectArea $newId
        }
        if { [GetNumAreas] == 0 } {
            $sPo(mainCanv) coords "AreaText" -100 -100
            $sPo(mainCanv) coords "AreaRef"  -100 -100
            set sPo(imageMap,nextArea) 0
        }
    }

    proc NewImageMap { { createNewArea true } } {
        variable sPo

        set sPo(imageMap,curArea)  0
        set sPo(imageMap,nextArea) 0
        set sPo(imageMap,mapName) "DefaultMap"
        $sPo(imageMap,table) delete 0 end
        $sPo(mainCanv) delete "Area"

        if { $createNewArea } {
            NewArea
        }
    }

    proc GetImageMapFileName { mode { initFile "" } } {
        variable ns
        variable sPo

        set fileTypes {
            {"HTML files" ".html .htm .txt"}
            {"All files"  "*"}
        }

        if { $mode eq "save" } {
            if { ! [info exists sPo(LastImageMapType)] } {
                set sPo(LastImageMapType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastImageMapType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }

            set fileName [tk_getSaveFile \
                         -filetypes $fileTypes \
                         -title "Save image map as" \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastImageMapType) \
                         -initialfile [file tail $initFile] \
                         -initialdir [file dirname $sPo(lastFile)]]
            if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
                set ext [poMisc GetExtensionByType $fileTypes $sPo(LastImageMapType)]
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
        } else {
            set fileName [tk_getOpenFile -filetypes $fileTypes \
                         -initialdir [file dirname $sPo(lastFile)]]
        }
        return $fileName
    }

    proc GetTagValue { str tag } {
        set value ""
        set tagInd [string first $tag $str]
        if { $tagInd >= 0 } {
            set quote1Ind [string first "\"" $str $tagInd]
            set quote2Ind [string first "\"" $str [expr {$quote1Ind +1}]]
            set value [string range $str $quote1Ind $quote2Ind]
            set value [string trim $value "\" ="]
        }
        return $value
    }

    proc GetImageMapFromHtmlString { imageMapStr } {
        variable sPo

        foreach line [split $imageMapStr "\n"] {
            if { [string match "*<map name=*" $line] } {
                set sPo(imageMap,mapName) [GetTagValue $line "name"]
            } elseif { [string match "*<area*" $line] } {
                set type   [GetTagValue $line "shape"]
                set coords [GetTagValue $line "coords"]
                set text   [GetTagValue $line "title"]
                set ref    [GetTagValue $line "href"]
                AddArea $type [Html2Canvas $type $coords] $text $ref
            } elseif { [string match "*</map*" $line] } {
                break
            }
        }
    }

    proc SaveImageMapAsHtmlString {} {
        variable sPo

        set str ""
        append str [format "<map name=\"%s\">\n" $sPo(imageMap,mapName)]
        for { set i 0 } { $i < [GetNumAreas] } { incr i } {
            set type   [GetAreaType $i]
            set coords [GetAreaCoords $i]
            set text   [GetAreaText $i]
            set ref    [GetAreaRef $i]
            append str [format "  <area shape=\"%s\" coords=\"%s\" alt=\"%s\" title=\"%s\" href=\"%s\">\n" \
                 $type $coords $text $text $ref]
        }
        append str "</map>\n"
        return $str
    }

    proc OpenImageMap {} {
        variable sPo

        set fileName [GetImageMapFileName "open" "$sPo(imageMap,mapName).html"]
        if { $fileName eq "" } {
            return
        }

        set retVal [catch {open $fileName r} fp]
        if { $retVal != 0 } {
            WriteInfoStr "Cannot open file $fileName for reading." "Error"
            return
        }

        NewImageMap false

        set imageMapStr [read $fp]
        GetImageMapFromHtmlString $imageMapStr

        close $fp
    }

    proc SaveImageMap {} {
        variable sPo

        set fileName [GetImageMapFileName "save" "$sPo(imageMap,mapName).html"]
        if { $fileName eq "" } {
            return
        }

        set retVal [catch {open $fileName w} fp]
        if { $retVal != 0 } {
            WriteInfoStr "Cannot open file $fileName for writing." "Error"
            return
        }

        puts $fp [SaveImageMapAsHtmlString]
        close $fp
    }

    proc GetNewAreaColor { labelId colorType } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(imageMap,color,$colorType)]
        if { $newColor ne "" } {
            set sPo(imageMap,color,$colorType) $newColor
            $labelId configure -background $newColor
            if { [GetNumAreas] > 0 } {
                SelectArea $sPo(imageMap,curArea)
            }
        }
    }

    proc ToggleAreaInfo {} {
        variable sPo

        if { ! $sPo(imageMap,showText) } {
            $sPo(mainCanv) coords "AreaText" -100 -100
        }
        if { ! $sPo(imageMap,showRef) } {
            $sPo(mainCanv) coords "AreaRef" -100 -100
        }
        if { [GetNumAreas] > 0 } {
            UpdateAreaCanvasText $sPo(imageMap,curArea)
        }
    }

    proc ShowImageMapWin {} {
        variable ns
        variable sPo
        variable sLogo

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }

        set tw .poImgview_imageMapWin
        set sPo(imageMapWin,name) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Image map generation"
        wm resizable $tw true true
        wm geometry $tw [format "+%d+%d" $sPo(imageMapWin,x) $sPo(imageMapWin,y)]

        ttk::frame      $tw.toolfr
        ttk::frame      $tw.paramfr
        ttk::labelframe $tw.areafr  -text "Areas"
        ttk::frame      $tw.tablefr
        grid $tw.toolfr  -row 0 -column 0 -sticky news
        grid $tw.paramfr -row 1 -column 0 -sticky news
        grid $tw.areafr  -row 2 -column 0 -sticky news
        grid $tw.tablefr -row 3 -column 0 -sticky news
        grid rowconfigure    $tw 3 -weight 1
        grid columnconfigure $tw 0 -weight 1

        set dispFr   $tw.paramfr.dispfr
        set createFr $tw.paramfr.createfr
        set textFr   $tw.paramfr.textfr
        ttk::labelframe $dispFr   -text "Area colors"
        ttk::labelframe $createFr -text "Creation sizes"
        ttk::labelframe $textFr   -text "Creation texts"
        pack $dispFr $createFr $textFr -side left -anchor n

        # Add a toolbar with buttons for image map handling.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::newfile] \
                  ${ns}::NewImageMap "New image map"
        poToolbar AddButton $toolfr [::poBmpData::open] \
                  ${ns}::OpenImageMap "Open image map file"
        poToolbar AddButton $toolfr [::poBmpData::save] \
                  ${ns}::SaveImageMap "Save current image map"

        # Add the widgets for the image map name to the toolbar.
        poToolbar AddGroup $toolfr

        poToolbar AddLabel $toolfr "Map name:" ""
        poToolbar AddEntry $toolfr ${ns}::sPo(imageMap,mapName) ""

        # Widgets for area color display and selection.
        ttk::label $dispFr.lactivename -text "Active:"
        label $dispFr.lactivecolor -width 10 -relief sunken -background $sPo(imageMap,color,active)
        ttk::button $dispFr.bactive -text "Select ..." \
                                    -command "${ns}::GetNewAreaColor $dispFr.lactivecolor active"

        ttk::label $dispFr.lothername -text "Inactive:"
        label $dispFr.lothercolor -width 10 -relief sunken -background $sPo(imageMap,color,other)
        ttk::button $dispFr.bother -text "Select ..." \
                                   -command "${ns}::GetNewAreaColor $dispFr.lothercolor other"

        grid $dispFr.lactivename  -row 0 -column 0 -sticky news
        grid $dispFr.lactivecolor -row 0 -column 1 -sticky news
        grid $dispFr.bactive      -row 0 -column 2 -sticky news
        grid $dispFr.lothername   -row 1 -column 0 -sticky news
        grid $dispFr.lothercolor  -row 1 -column 1 -sticky news
        grid $dispFr.bother       -row 1 -column 2 -sticky news

        # Widgets for area sizes at creation time.
        ttk::label $createFr.lrect -text "Rectangle (W/H):"
        spinbox $createFr.width  -textvariable ${ns}::sPo(imageMap,rect,w) -width 4 \
                                 -from 2 -to 1000 -increment 1
        spinbox $createFr.height -textvariable ${ns}::sPo(imageMap,rect,h) -width 4 \
                                 -from 2 -to 1000 -increment 1

        ttk::label $createFr.lcircle -text "Circle (Radius):"
        spinbox $createFr.radius -textvariable ${ns}::sPo(imageMap,circle,r) -width 4 \
                                 -from 2 -to 1000 -increment 1
        grid $createFr.lrect   -row 0 -column 0 -sticky news
        grid $createFr.width   -row 0 -column 1 -sticky news
        grid $createFr.height  -row 0 -column 2 -sticky news
        grid $createFr.lcircle -row 1 -column 0 -sticky news
        grid $createFr.radius  -row 1 -column 1 -sticky news

        # Widgets for area default text and reference strings.
        ttk::label $textFr.ltext -text "Default text:"
        entry $textFr.etext -textvariable ${ns}::sPo(imageMap,default,text)

        ttk::label $textFr.lref -text "Default link:"
        entry $textFr.eref -textvariable ${ns}::sPo(imageMap,default,ref)

        grid $textFr.ltext -row 0 -column 0 -sticky news
        grid $textFr.etext -row 0 -column 1 -sticky news
        grid $textFr.lref  -row 1 -column 0 -sticky news
        grid $textFr.eref  -row 1 -column 1 -sticky news

        # Add a toolbar for managing the areas of an image map.
        set toolfr $tw.areafr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::cell] \
                  "${ns}::NewArea rect"   "New rectangle area"
        poToolbar AddButton $toolfr [::poBmpData::circle] \
                  "${ns}::NewArea circle" "New circle area"
        poToolbar AddButton $toolfr [::poBmpData::delete "red"] \
                  ${ns}::DeleteArea "Delete area"

        poToolbar AddGroup $toolfr
        poToolbar AddCheckButton $toolfr [::poBmpData::infofile] \
                  ${ns}::ToggleAreaInfo "Toggle display of text" \
                  -variable ${ns}::sPo(imageMap,showText)
        poToolbar AddCheckButton $toolfr [::poBmpData::infoimg] \
                  ${ns}::ToggleAreaInfo "Toggle display of reference" \
                  -variable ${ns}::sPo(imageMap,showRef)

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::left] \
                  "${ns}::ShiftArea -1 0" "Shift area left (Key-Left)"
        poToolbar AddButton $toolfr [::poBmpData::right] \
                  "${ns}::ShiftArea 1 0" "Shift area right (Key-Right)"
        poToolbar AddButton $toolfr [::poBmpData::up] \
                  "${ns}::ShiftArea 0 -1" "Shift area up (Key-Up)"
        poToolbar AddButton $toolfr [::poBmpData::down] \
                  "${ns}::ShiftArea 0 1" "Shift area down (Key-Down)"

        poToolbar AddButton $toolfr [::poBmpData::smaller] \
                  "${ns}::ScaleArea {1 1 -1 -1}" "Decrease area size (Shift-Key-Down)"
        poToolbar AddButton $toolfr [::poBmpData::larger] \
                  "${ns}::ScaleArea {-1 -1 1 1}" "Increase area size (Shift-Key-Up)"

        poToolbar AddButton $toolfr [::poBmpData::first] \
                  "${ns}::ScaleAreaRect {1 0 -1 0}" "Decrease horizontal area size (Control-Key-Left)"
        poToolbar AddButton $toolfr [::poBmpData::last] \
                  "${ns}::ScaleAreaRect {-1 0 1 0}" "Increase horizontal area size (Control-Key-Right)"
        poToolbar AddButton $toolfr [::poBmpData::top] \
                  "${ns}::ScaleAreaRect {0 -1 0 1}" "Increase vertical area size (Control-Key-Up)"
        poToolbar AddButton $toolfr [::poBmpData::bottom] \
                  "${ns}::ScaleAreaRect {0 1 0 -1}" "Decrease vertical area size (Control-Key-Down)"

        set tableId [poWin CreateScrolledTablelist $tw.tablefr true "" \
                    -width 80 -height 10 -exportselection false \
                    -columns { 0 "#"     "right"
                               0 "ID"     "right"
                               0 "Shape"  "left"
                               0 "Coords" "left"
                               0 "Title"  "left"
                               0 "HRef"   "left" } \
                    -stretch 5 \
                    -setfocus 1 \
                    -stripebackground [poAppearance GetStripeColor] \
                    -selectmode extended \
                    -showseparators yes]
        $tableId columnconfigure 0 -showlinenumbers true
        $tableId columnconfigure 1 -hide true
        $tableId columnconfigure 2 -editable false
        $tableId columnconfigure 3 -editable false
        $tableId columnconfigure 4 -editable true
        $tableId columnconfigure 5 -editable true
        bind $tableId <<ListboxSelect>> "${ns}::SelectAreaByTable %W"
        set sPo(imageMap,table) $tableId
        set sPo(imageMap,table,idColumn)    1
        set sPo(imageMap,table,typeColumn)  2
        set sPo(imageMap,table,coordColumn) 3
        set sPo(imageMap,table,textColumn)  4
        set sPo(imageMap,table,refColumn)   5

        wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseImageMapWindow $tw"

        $sPo(mainCanv) create text -100 -100 -anchor nw \
                       -fill $sPo(imageMap,color,active) -text "AreaTex" -tags [list "AreaText"]
        $sPo(mainCanv) create text -100 -100 -anchor nw \
                       -fill $sPo(imageMap,color,active) -text "AreaRef" -tags [list "AreaRef"]

        $sPo(mainCanv) bind "Area" <Button-1>  [list ${ns}::CheckAreaSelection %x %y]
        $sPo(mainCanv) bind "Area" <B1-Motion> [list ${ns}::MoveArea %x %y]
        if { [info exists sPo(imageMap,history)] } {
            NewImageMap false
            GetImageMapFromHtmlString $sPo(imageMap,history)
        } else {
            NewImageMap
        }

        SwitchBindings "Area"

        set sPo(imageMap,winOpen) 1
        focus $tw
    }

    proc CloseImageMapWindow { tw } {
        variable sPo

        catch { unset sPo(imageMap,history) }
        if { [GetNumAreas] > 0 } {
            set sPo(imageMap,history) [SaveImageMapAsHtmlString]
        }
        $sPo(mainCanv) delete "AreaText"
        $sPo(mainCanv) delete "AreaRef"
        NewImageMap false
        SwitchBindings "SelRect"
        unset sPo(imageMap,winOpen)
        destroy $tw
    }

    proc UpdateNoiseImg { { updatePreview true } } {
        variable sPo

        # Save current image state settings for later restoring.
        poImageMode GetFormat   savePixFmt
        poImageMode GetDrawMask saveDrawMask
        poImageMode GetDrawMode saveDrawMode

        # Set the correct drawing states for drawing into the green channel.
        poImgUtil SetFormatChan    $::GREEN $::UBYTE
        poImgUtil SetDrawMaskChan  $::GREEN $::ON
        poImgUtil SetDrawModeChan  $::GREEN $::REPLACE

        if { $updatePreview } {
            set xsize $sPo(noise,previewSize)
            set ysize $sPo(noise,previewSize)
            set phImg $sPo(noise,phImg)
        } else {
            set xsize $sPo(new,w)
            set ysize $sPo(new,h)
            set phImg [image create photo -width $xsize -height $ysize]
        }

        # Allocate a new poImage and generate fractal noise according to the
        # settings made in the GUI. Then copy the green channel into the RGB
        # channels of the photo image of the canvas.
        poWatch Reset swatch
        set poImg [poImage NewImage $xsize $ysize]
        $poImg GenNoise $::GREEN $sPo(noise,seed) $sPo(noise,period) \
                        $sPo(noise,coherence) $sPo(noise,z-slice)
        set chanMap [list $::GREEN $::GREEN $::GREEN]
        $poImg AsPhoto $phImg $chanMap
        poImgUtil DeleteImg $poImg
        WriteInfoStr [format "Noise image (%.2f sec)" [poWatch Lookup swatch]] "Ok"

        # Restore the image states.
        poImageMode SetFormat   $savePixFmt
        poImageMode SetDrawMask $saveDrawMask
        poImageMode SetDrawMode $saveDrawMode
        if { ! $updatePreview } {
            return $phImg
        }
    }

    proc AddNoiseImg { imgName } {
        set noiseImg [UpdateNoiseImg false]
        AddImg $noiseImg "" $imgName
    }

    proc UpdateNoiseParam { param res scaleValue } {
        variable sPo

        set fmtStr "%.${res}f"
        set sPo(noise,$param) [format $fmtStr $scaleValue]
    }

    proc CancelSettingsWin { tw args } {
        variable sPo

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        UpdateFileName
        destroy $tw
    }

    proc OKSettingsWin { tw args } {
        variable sPo

        destroy $tw
    }

    proc ShowDtedSettWin {} {
        variable ns
        variable sPo

        set tw .poImgview_dtedWin
        set sPo(dtedWin,name) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "DTED settings"
        wm resizable $tw false false
        wm geometry $tw [format "+%d+%d" $sPo(dtedWin,x) $sPo(dtedWin,y)]

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "DTED Level:" \
                           "Global min value:" \
                           "Global max value:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky nw
            incr row
        }

        set varList [list]
        # Generate right column with entries and buttons.
        # Row 0: DTED Level
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(dted,level) -width 2
        pack  $tw.fr$row.e -side top -anchor w -in $tw.fr$row -pady 2 -ipadx 2

        set tmpList [list [list sPo(dted,level)] [list $sPo(dted,level)]]
        lappend varList $tmpList

        # Row 1: Minimum elevation value for all files.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(dted,minVal) -width 6
        pack  $tw.fr$row.e -side top -anchor w -in $tw.fr$row -pady 2 -ipadx 2

        set tmpList [list [list sPo(dted,minVal)] [list $sPo(dted,minVal)]]
        lappend varList $tmpList

        # Row 2: Maximum elevation value for all files.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(dted,maxVal) -width 6
        pack  $tw.fr$row.e -side top -anchor w -in $tw.fr$row -pady 2 -ipadx 2

        set tmpList [list [list sPo(dted,maxVal)] [list $sPo(dted,maxVal)]]
        lappend varList $tmpList

        # Create Cancel and OK buttons
        incr row
        ttk::frame $tw.fr$row
        grid  $tw.fr$row -row $row -column 0 -columnspan 2 -sticky news

        bind  $tw <KeyPress-Escape> "${ns}::CancelSettingsWin $tw $varList"
        ttk::button $tw.fr$row.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                             -compound left -command "${ns}::CancelSettingsWin $tw $varList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelSettingsWin $tw $varList"

        bind  $tw <KeyPress-Return> "${ns}::OKSettingsWin $tw"
        ttk::button $tw.fr$row.b2 -text "OK" -image [poWin GetOkBitmap] \
                             -compound left -default active \
                             -command "${ns}::OKSettingsWin $tw"
        pack $tw.fr$row.b1 $tw.fr$row.b2 -side left -fill x -padx 2 -pady 2 -expand 1
        focus $tw
    }

    proc ShowMiscTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "View:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList {}
        # Generate right column with entries and buttons.
        # Part 1: View settings
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Show image info" -variable ${ns}::sPo(showImgInfo)
        ttk::checkbutton $tw.fr$row.cb2 -text "Show file info"  -variable ${ns}::sPo(showFileInfo)
        pack $tw.fr$row.cb1 $tw.fr$row.cb2 -side top -anchor w

        set tmpList [list [list sPo(showImgInfo)] [list $sPo(showImgInfo)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(showFileInfo)] [list $sPo(showFileInfo)]]
        lappend varList $tmpList

        return $varList
    }

    proc ShowSpecificSettWin { { selectTab "Miscellaneous" } } {
        variable sPo
        variable ns

        set tw .poImgview:specWin
        set sPo(specWin,name) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Image view specific settings"
        wm resizable $tw true true
        wm geometry $tw [format "+%d+%d" $sPo(specWin,x) $sPo(specWin,y)]

        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1

        set nb $tw.fr.nb
        ttk::notebook $nb -style [poAppearance GetTabStyle]
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        set varList [list]
        set selTabInd 0

        ttk::frame $nb.miscFr
        set tmpList [ShowMiscTab $nb.miscFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.miscFr -text "Miscellaneous" -underline 0 -padding 2
        if { $selectTab eq "Miscellaneous" } {
            set selTabInd 0
        }
        $nb select $selTabInd

        # Create Cancel and OK buttons
        ttk::frame $tw.frOk
        pack $tw.frOk -side bottom -fill x

        ttk::button $tw.frOk.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                -compound left -command "${ns}::CancelSettingsWin $tw $varList"
        bind $tw <KeyPress-Escape> "${ns}::CancelSettingsWin $tw $varList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelSettingsWin $tw $varList"

        ttk::button $tw.frOk.b2 -text "OK" -image [poWin GetOkBitmap] \
                -compound left -command "${ns}::OKSettingsWin $tw" -default active
        pack $tw.frOk.b1 $tw.frOk.b2 -side left -fill x -padx 10 -pady 2 -expand 1
        focus $tw
    }

    proc SettingsOkCallback {} {
        variable sPo

        $sPo(mainCanv) configure -background [poImgAppearance GetCanvasBackgroundColor]
    }

    proc SelectConvOutDir { widgetToUpdate } {
        variable sConv

        set tmpDir [tk_chooseDirectory -initialdir $sConv(outDir) \
                    -mustexist 1 -title "Select conversion output directory"]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            set sConv(outDir) $tmpDir
            poToolhelp AddBinding $widgetToUpdate "$tmpDir"
        }
    }

    proc GetConvOutDir { comboId } {
        variable sConv

        set sConv(outDir) [poWinSelect GetValue $comboId]
    }

    proc GetSideName { side } {
        if { $side == 0 } {
            return "Left"
        } elseif { $side == 1 } {
            return "Right"
        } else {
            return ""
        }
    }

    proc SwitchMarkImgs { side } {
        variable sPo

        set sPo(markImg,cur) $side
        ToggleMarkImgs $side
    }

    proc ToggleMarkImgs { side } {
        variable sPo
        variable sImg

        if { ! [HaveImgs] } {
            return
        }
        # If there is an image already marked with given side, set it to an invalid side.
        foreach key [lsort -dictionary [array names sPo "markImg,side,*"]] {
            if { $sPo($key) == $side } {
                set sPo($key) 2
            }
        }
        set sPo(markImg,side,[GetCurImgNum]) $side
        set sPo(markImg,cur) $side
        # Mark the thumbnails of the selected images.
        foreach key [lsort -dictionary [array names sPo "markImg,side,*"]] {
            set imgNum [lindex [split $key ","] 2]
            set btnName $sImg(thumbBtn,$imgNum)
            $btnName configure -text [GetSideName $sPo($key)] -compound left
        }
    }

    proc DiffImgs {} {
        variable sPo
        variable sImg

        poImgdiff ShowMainWin
        foreach key [lsort -dictionary [array names sPo "markImg,side,*"]] {
            set imgNum  [lindex [split $key ","] 2]
            set imgName [GetImgName $imgNum]
            set phImg   [GetImgPhoto $imgNum]
            if { [info exists sImg(poImg,$imgNum)] } {
                set poImg $sImg(poImg,$imgNum)
            } else {
                set poImg ""
            }
            set phCopy ""
            set poCopy ""
            if { $phImg ne "" } {
                set phCopy [poPhotoUtil CopyImg $phImg]
            }
            if { $poImg ne "" } {
                set poCopy [poImgUtil CopyImg $poImg]
            }
            if { $sPo($key) == 0 } {
                poImgdiff AddImg $phCopy $poCopy $imgName left
            } elseif { $sPo($key) == 1 } {
                poImgdiff AddImg $phCopy $poCopy $imgName right
            }
        }
        poImgdiff ShowDiffImgOnStartup
    }

    proc CreateNewImgFileName { imgName } {
        set imgFormat [poImgAppearance GetLastImgFmtUsed]
        if { $imgFormat eq "" } {
            set imgFormat "PNG"
        }
        set ext [lindex [poImgType GetExtList $imgFormat] 0]
        set fileName [format "%s%s" $imgName $ext]
        return [file join [GetCurDir] $fileName]
    }

    proc GetNewImgColor { labelId } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(new,c)]
        if { $newColor ne "" } {
            set sPo(new,c) $newColor
            $labelId configure -background $newColor
        }
    }

    proc UpdateNewImgTable { tableId scrolledFrame } {
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }
        set curInd [poTablelistUtil GetFirstSelectedRow $tableId]
        set newImgType [lindex [$tableId get $curInd] 0]

        GenNewImgOptWidgets $newImgType $scrolledFrame
    }
    
    proc GenNewImgOptWidgets { newImgType scrolledFrame } {
        variable ns
        variable sPo

        # Destroy the frame before inserting new values.
        set fr $scrolledFrame.fr
        catch { destroy $fr }
        ttk::frame $fr
        pack $fr -in $scrolledFrame -expand 1 -fill both

        switch $newImgType {
            "Uniform" {
                ttk::label $fr.l -text "Color:"
                grid $fr.l -row 0 -column 0 -sticky news
                ttk::frame $fr.fr
                grid $fr.fr -row 0 -column 1 -sticky nwe
                label $fr.fr.l -width 10 -relief sunken -background $sPo(new,c)
                ttk::button $fr.fr.b -text "Select ..." \
                            -command "${ns}::GetNewImgColor $fr.fr.l"
                pack $fr.fr.l $fr.fr.b -side left -fill x -expand 1
            }
            "Noise" {
                if { [poImgAppearance UsePoImg] } {
                    InitNoiseRollUp $fr
                } else {
                    ttk::label $fr.l -text "Noise generator needs the poImg extension"
                    grid $fr.l -row 0 -column 0 -sticky news
                }
            }
            "TestImage1" -
            "Text" {
                ttk::entry $fr.e -textvariable ${ns}::sPo(new,t) -width 40 
                grid $fr.e -row 0 -column 0 -sticky news
            }
        }
        set sPo(curNewImgType) $newImgType
    }
    
    proc CreateNewImg {} {
        variable sPo

        if { $sPo(new,w) < 1 || $sPo(new,h) < 1 } {
            WriteInfoStr "Image size must be at least 1." "Error"
            return
        }
        if { ! $sPo(loadAsNewImg) } {
            DelImg [expr [GetNumImgs] -1] false
        }

        set imgName [CreateNewImgFileName $sPo(curNewImgType)]

        switch $sPo(curNewImgType) {
            "Uniform" {
                CreateUniformImage $sPo(new,w) $sPo(new,h) $sPo(new,c) $imgName
            }
            "Noise" {
                if { [poImgAppearance UsePoImg] } {
                    AddNoiseImg $imgName
                }
            }
            "Pattern" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h)]
                AddImg $phImg "" $imgName
            }
            "Grid" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h)]
                AddImg $phImg "" $imgName
            }
            "ColorBar" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h)]
                AddImg $phImg "" $imgName
            }
            "TestImage1" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h) $sPo(new,t)]
                AddImg $phImg "" $imgName
            }
            "TestImage2" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h)]
                AddImg $phImg "" $imgName
            }
            "Text" {
                set phImg [poImgTig Draw $sPo(curNewImgType) $sPo(new,w) $sPo(new,h) $sPo(new,t)]
                AddImg $phImg "" $imgName
            }
            default {
                puts "Unknown image type $sPo(curNewImgType)"
                poLog Error "Unknown image type $sPo(curNewImgType)"
            }
        }
        SetResolution [GetCurImgPhoto] $sPo(new,xdpi) $sPo(new,ydpi)
    }

    proc NewImgComboCB { comboId } {
        variable sPo

        set match [$comboId get]
        if { [scan $match "%dx%d" sPo(new,w) sPo(new,h)] != 2 } {
            set sPo(new,w) [winfo screenwidth  $sPo(tw)]
            set sPo(new,h) [winfo screenheight $sPo(tw)]
        }
    }

    proc ShowNewImgWin { title { numChars 10 } } {
        variable ns
        variable sPo

        set tw "$sPo(tw)_newImageWin"
        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw $title
        wm geometry $tw "400x350"
        bind $tw <KeyPress-Escape> "${ns}::CloseNewImgWin"

        set typeFr $tw.typefr
        set sizeFr $tw.sizefr
        set optFr  $tw.optfr
        set btnFr  $tw.btnfr

        ttk::frame $typeFr -borderwidth 1
        ttk::frame $sizeFr -borderwidth 1
        ttk::frame $optFr  -borderwidth 0
        ttk::frame $btnFr  -borderwidth 0
        grid $typeFr -row 0 -column 0 -sticky news -rowspan 2
        grid $sizeFr -row 0 -column 1 -sticky news
        grid $optFr  -row 1 -column 1 -sticky news
        grid $btnFr  -row 2 -column 0 -sticky news -columnspan 2
        grid rowconfigure    $tw 1 -weight 1
        grid columnconfigure $tw 1 -weight 1

        # Fill Type frame: Create a tablelist for selecting the type of the new image.
        set newImgTypeList [list \
            "Uniform" \
            "Noise" \
            "ColorBar" \
            "Grid" \
            "Pattern" \
            "TestImage1" \
            "TestImage2" \
            "Text" \
        ]
        set selInd 0
        set tableId [poWin CreateScrolledTablelist $typeFr true ""  \
            -columns [list 0  "Image type:" "left"] \
            -height [llength $newImgTypeList] \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch all \
            -showlabels false \
            -showseparators 1]
        foreach type $newImgTypeList {
            $tableId insert end [list $type]
        }
        $tableId selection set $selInd

        # Fill Size frame: Create widgets for specifying the size of the new image.
        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Specific sizes:" \
                           "Width (pixel):" \
                           "Height (pixel):" \
                           "Horizontal DPI:" \
                           "Vertical DPI:" \
                           "Options:" } {
            ttk::label $sizeFr.l$row -text $labelStr
            grid $sizeFr.l$row -row $row -column 0 -sticky news
            incr row
        }

        # Generate right column with text entries.
        set sizesList [list "Screensize" "256x256" "512x512" "1024x1024" "640x480" "720x576" "1920x1080"]

        set row 0
        ttk::frame $sizeFr.fr$row
        grid $sizeFr.fr$row -row $row -column 1 -sticky new
        ttk::combobox $sizeFr.fr$row.cb -state readonly
        pack $sizeFr.fr$row.cb -side top -expand 1 -fill x
        $sizeFr.fr$row.cb configure -values $sizesList
        bind $sizeFr.fr$row.cb <<ComboboxSelected>> "${ns}::NewImgComboCB %W"

        incr row
        ttk::frame $sizeFr.fr$row
        grid $sizeFr.fr$row -row $row -column 1 -sticky new
        poWin CreateCheckedIntEntry $sizeFr.fr$row ${ns}::sPo(new,w) -row $row -width 10 -min 1

        incr row
        ttk::frame $sizeFr.fr$row
        grid $sizeFr.fr$row -row $row -column 1 -sticky new
        poWin CreateCheckedIntEntry $sizeFr.fr$row ${ns}::sPo(new,h) -row $row -width 10 -min 1

        incr row
        ttk::frame $sizeFr.fr$row
        grid $sizeFr.fr$row -row $row -column 1 -sticky new
        set xdpiWin [poWin CreateCheckedRealEntry $sizeFr.fr$row ${ns}::sPo(new,xdpi) -row $row -width 10 -min 0.0]

        incr row
        ttk::frame $sizeFr.fr$row
        grid $sizeFr.fr$row -row $row -column 1 -sticky new
        set ydpiWin [poWin CreateCheckedRealEntry $sizeFr.fr$row ${ns}::sPo(new,ydpi) -row $row -width 10 -min 0.0]

        if { ! [poImgType HaveDpiSupport] } {
            $xdpiWin configure -state disabled
            $ydpiWin configure -state disabled
            poToolhelp AddBinding $xdpiWin "No resolution support available."
            poToolhelp AddBinding $ydpiWin "No resolution support available."
        }

        # Fill Option frame: Create a scrolled frame containing the type specific options.
        set scrolledFrame [poWin CreateScrolledFrame $optFr true ""]
        GenNewImgOptWidgets [lindex $newImgTypeList $selInd] $scrolledFrame

        bind $tableId <<TablelistSelect>> "${ns}::UpdateNewImgTable $tableId $scrolledFrame"

        # Fill Button frame: Create "Create" button.
        ttk::button $btnFr.b -text "Create image" \
                             -command ${ns}::CreateNewImg -default active
        pack $btnFr.b -side left -expand 1 -fill x -pady 2 -padx 2

        focus $tw
    }

    proc CloseNewImgWin {} {
        variable sPo

        destroy $sPo(tw)_newImageWin
    }

    proc LoadSettings { cfgDir } {
        variable sPo
        variable sLogo
        variable sConv

        # Init global variables not stored in the configuration file.
        set sLogo(xtxt)  25                 ; # Logo text horizontal offset
        set sLogo(ytxt)  25                 ; # Logo text vertical offset
        set sLogo(xIcon) 100                ; # Logo icon width in settings window
        set sLogo(yIcon) 100                ; # Logo icon height in settings window
        set sLogo(show)  0                  ; # Show logo rectangle in canvas

        set sPo(curCursor) "crosshair"
        set sPo(license)   "POEVAL-BX3320-FY0432-DR7537"

        set sPo(zoomRectExists) 0

        # Init all variables stored in the configuration file with default values.
        SetWindowPos mainWin      30 30 1000 650
        SetWindowPos specWin     100 50    0   0
        SetWindowPos genWin      120 50    0   0
        SetWindowPos dtedWin     140 50    0   0
        SetWindowPos imageMapWin 180 50    0   0

        SetMainWindowSash 120 800 400

        SetCurFile ""

        SetScaleParams 1 1
        SetLoadAsNewImg 1

        SetConversionParams "SameAsInput" "Conv_%s" false [pwd] 1
        set sConv(counter) $sConv(num)

        SetZoomParams 1 1.00
        SetViewParams 1 1

        SetNewImgParams 256 256 "#FF0000"
        SetNewImgResolution 72 72

        SetLogoParams "#FFFFFF" "tl" 25 25 ""

        SetTileParams 2 2 0 0 30 30
        SetComposeParams 3 30
        SetNoiseParams 256 0 5 4 0.0
        SetImageMapParams "rect" 20 20 10 "Text" "Reference"
        SetImageMapViewParams "green" "black" 1 0

        SetDtedParams 0 0 0 255

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file found. Using default values."
        }
        set sPo(cfgDir) $cfgDir
    }

    proc PrintCmd { fp cmdName } {
        puts $fp "\n# Set${cmdName} [info args Set${cmdName}]"
        puts $fp "catch {Set${cmdName} [Get${cmdName}]}"
    }

    proc SaveSettings {} {
        variable sPo
        variable sLogo
        variable sConv

        set cfgFile [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetWindowPos [info args SetWindowPos]"

            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos specWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos genWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos imageMapWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos dtedWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetWindowPos [GetWindowPos specWin]
            eval SetWindowPos [GetWindowPos genWin]
            eval SetWindowPos [GetWindowPos imageMapWin]
            eval SetWindowPos [GetWindowPos dtedWin]

            eval SetMainWindowSash [GetMainWindowSash]

            PrintCmd $fp "MainWindowSash"

            PrintCmd $fp "LogoParams"
            PrintCmd $fp "TileParams"
            PrintCmd $fp "ComposeParams"
            PrintCmd $fp "NoiseParams"
            PrintCmd $fp "ImageMapParams"
            PrintCmd $fp "ImageMapViewParams"
            PrintCmd $fp "DtedParams"
            PrintCmd $fp "ConversionParams"
            PrintCmd $fp "NewImgParams"
            PrintCmd $fp "NewImgResolution"
            PrintCmd $fp "ScaleParams"
            PrintCmd $fp "LoadAsNewImg"
            PrintCmd $fp "ZoomParams"
            PrintCmd $fp "ViewParams"

            PrintCmd $fp "CurFile"

            close $fp
        }
    }

    proc ShowImg { imgNum } {
        variable sPo
        variable sLogo
        variable sImg

        ClearRawImgInfo
        if { $imgNum < 0 } {
            UpdateMainTitle "(No images loaded)"
            UpdateRollUps true
        } else {
            if { ! [HaveImgs] } {
                return
            }
            if { $sPo(optBatch) && ! [poApps GetDisplayImage] } {
                return
            }

            Zoom $sPo(zoom)

            if { $sPo(zoom) == 1.00 } {
                $sPo(mainCanv) itemconfigure MyImage -image [GetImgPhoto $imgNum]
                set iw [image width  [GetImgPhoto $imgNum]]
                set ih [image height [GetImgPhoto $imgNum]]
                set sPo(mainWin,w) $iw
                set sPo(mainWin,h) $ih
            } else {
                $sPo(mainCanv) itemconfigure MyImage -image $sPo(zoomPhoto)
                set iw [image width  $sPo(zoomPhoto)]
                set ih [image height $sPo(zoomPhoto)]
                set sPo(mainWin,w) [image width  [GetImgPhoto $imgNum]]
                set sPo(mainWin,h) [image height [GetImgPhoto $imgNum]]
            }
            set sw [winfo screenwidth $sPo(tw)]
            set sh [winfo screenheight $sPo(tw)]
            $sPo(mainCanv) configure -width  [poMisc Min $iw $sw] \
                                     -height [poMisc Min $ih $sh]
            $sPo(mainCanv) configure -scrollregion "0 0 $iw $ih"
            SetLogoPos
            $sPo(mainCanv) raise LogoText
            $sPo(mainCanv) raise LogoRect
            $sPo(mainCanv) raise LogoLine
            set sImg(thumbSelected) [GetImgPhoto $imgNum]
            UpdateFileName
            UpdateRawInfo $imgNum $sImg(name,$imgNum)
            if { ! $sPo(optBatch) } {
                UpdateInfoWidget
            }
            set sPo(markImg,cur) $sPo(markImg,side,$imgNum)
            UpdateRollUps
            set fraction [expr { double ($imgNum) / double ([GetNumImgs]) }]
            poWin SetScrolledFrameFraction $sPo(thumbFr) $fraction
        }
        update
    }

    proc UpdFileTypeCB { combo } {
        variable sPo
        variable sConv

        set fmtString [$combo get]
        set ret [regexp -nocase -- {([^\(]*)\((\.*[^\)]*)\)} $fmtString \
                total fmtName fmtSuff]
        set sConv(outFmt) [string trim $fmtName]
        UpdateFileName
    }

    proc CheckOutDir { entryId labelId } {
        variable sPo

        set curPath [file nativename [$entryId get]]
        if { ! [file isdirectory $curPath] } {
            $labelId configure -image [poWin GetWrongBitmap]
        } else {
            $labelId configure -image [poWin GetOkBitmap]
        }
    }

    proc UpdateFileName {} {
        variable sPo
        variable sConv
        variable sImg

        if { [GetCurImgNum] < 0 } {
            return
        }

        poWinSelect SetValue $sPo(fileCombo) [GetCurImgName]
        UpdateMainTitleStandard
    }

    proc UpdateThumb { phImg } {
        variable ns
        variable sPo
        variable sImg

        if { $sPo(optBatch) } {
            # Do not calculate thumb image in batch processing mode
            return
        }
        set curNum [GetCurImgNum]
        set thumbImg [poImgMisc CreateThumbImg $phImg [poImgBrowse GetThumbSize]]
        set btnName $sImg(thumbBtn,$curNum)
        image delete $sImg(thumb,$curNum)
        set sImg(thumb,$curNum) $thumbImg
        $btnName configure -image $thumbImg
        $btnName configure -command "${ns}::ShowImgByName $phImg"
    }

    proc AddThumb { phImg imgName } {
        variable ns
        variable sPo
        variable sImg

        set thumbFile [::poImgBrowse::GetThumbFile $imgName]
        set thumbInfo [::poImgBrowse::ReadThumbFile $thumbFile]
        set thumbImg  [lindex $thumbInfo 0]
        if { $thumbImg eq "" } {
            # No thumb file. Create thumb on the fly.
            set thumbImg [poImgMisc CreateThumbImg $phImg [poImgBrowse GetThumbSize]]
        }
        set btnName [poWin AddToScrolledFrame ttk::radiobutton $sPo(thumbFr) $phImg \
                     -image $thumbImg \
                     -variable ${ns}::sImg(thumbSelected) -style Toolbutton \
                     -value $phImg -command "${ns}::ShowImgByName $phImg"]
        update
        poWin SetScrolledFrameFraction $sPo(thumbFr) 1.0
        set sImg(thumb,[GetNumImgs]) $thumbImg
        set sImg(thumbBtn,[GetNumImgs]) $btnName
        poToolhelp AddBinding $btnName $imgName
    }

    proc UpdateRawInfo { imgNum imgName } {
        variable sImg

        if { [info exists sImg(rawDict,$imgNum)] } {
            return
        }
        if { [poImgAppearance GetShowRawCurValue] || [poImgAppearance GetShowRawImgInfo] } {
            set haveDict false
            if { [file exists $imgName] } {
                if { [poImgAppearance GetShowRawCurValue] } {
                    if { [poType IsImage $imgName "raw"] || \
                         [poImgType GetFmtByExt [file extension $imgName]] eq "RAW" } {
                        set optStr [poImgType GetOptByFmt "RAW" "read"]
                        set sImg(rawDict,$imgNum) [poRawParse ReadImageFile $imgName $optStr]
                        set haveDict true
                    } elseif { [poType IsImage $imgName "flir"] || \
                               [poImgType GetFmtByExt [file extension $imgName]] eq "FLIR" } {
                        set optStr [poImgType GetOptByFmt "FLIR" "read"]
                        set sImg(rawDict,$imgNum) [poFlirParse ReadImageFile $imgName $optStr]
                        set haveDict true
                    } elseif { [poType IsImage $imgName "ppm"] || \
                               [poImgType GetFmtByExt [file extension $imgName]] eq "PPM" } {
                        set optStr [poImgType GetOptByFmt "PPM" "read"]
                        set sImg(rawDict,$imgNum) [poPpmParse ReadImageFile $imgName $optStr]
                        set haveDict true
                    }
                }
                if { $haveDict && [poImgAppearance GetShowRawImgInfo] } {
                    # The minimum and maximum values are stored in the dict and will be used in ShowImg.
                    catch { poImgDict GetImageMinMax     sImg(rawDict,$imgNum) }
                    catch { poImgDict GetImageMeanStdDev sImg(rawDict,$imgNum) }
                }
            }
        }
    }

    proc AddImg { phImg poImg imgName } {
        variable sPo
        variable sImg

        if { ! $sPo(optBatch) } {
            # Add thumb image only in interactive mode.
            AddThumb $phImg $imgName
        }
        set sImg(photo,[GetNumImgs]) $phImg
        if { $poImg ne "" } {
            set sImg(poImg,[GetNumImgs]) $poImg
        }
        set sImg(name,[GetNumImgs]) $imgName
        UpdateRawInfo [GetNumImgs] $imgName

        SetCurImgNum [GetNumImgs]
        set sPo(markImg,side,[GetCurImgNum]) 2  ; # Use invalid side number. 0=left, 1=right
        IncrNumImgs 1
        ShowImg [expr [GetNumImgs] -1]

        if { ! $sPo(optBatch) } {
            # Thumb image available only in interactive mode.
            set haveLeft  false
            set haveRight false
            foreach key [lsort -dictionary [array names sPo "markImg,side,*"]] {
                if { $sPo($key) == 0 } {
                    set haveLeft true
                } elseif { $sPo($key) == 1 } {
                    set haveRight true
                }
            }
            if { ! $haveLeft } {
                ToggleMarkImgs 0
            } elseif { ! $haveRight } {
                ToggleMarkImgs 1
            }
        }
        return [GetCurImgNum]
    }

    proc UpdateMainTitle { msg } {
        variable sPo

        wm title $sPo(tw) [format "poApps - %s %s" [poApps GetAppDescription $sPo(appName)] $msg]
    }

    proc UpdateMainTitleStandard {} {
        variable sPo
        variable sImg

        set zoomStr [format "%d%%" [expr {int ($sPo(zoom) * 100.0)}]]
        UpdateMainTitle "(Image [expr [GetCurImgNum] +1] of [GetNumImgs]) Zoom: $zoomStr"
    }

    proc DelImg { { imgNum -1 } { updateDisplay true } } {
        variable sPo
        variable sImg

        if { [HaveImgs] } {
            if { $imgNum >= 0 && $imgNum < [GetNumImgs] } {
                set cur $imgNum
                SetCurImgNum $imgNum
            } else {
                set cur [GetCurImgNum]
            }
            set lastImgNum [expr [GetNumImgs] -1]
            image delete [GetImgPhoto $cur]
            poWinInfo Clear $sPo(imgInfoWidget)
            poWinInfo Clear $sPo(fileInfoWidget)
            if { [info exists sImg(thumb,$cur)] } {
                image delete $sImg(thumb,$cur)
                destroy $sImg(thumbBtn,$cur)
            }
            if { [info exists sImg(poImg,$cur)] } {
                poImgUtil DeleteImg $sImg(poImg,$cur)
                unset sImg(poImg,$cur)
            }
            if { [info exists sImg(rawDict,$cur)] } {
                unset sImg(rawDict,$cur)
            }
            for { set i $cur } { $i < $lastImgNum } { incr i } {
                set j [expr ($i + 1)]
                set sImg(photo,$i) [GetImgPhoto $j]
                set sImg(name,$i)  [GetImgName $j]
                catch {unset sImg(thumb,$i)}
                if { [info exists sImg(thumb,$j)] } {
                    set sImg(thumb,$i) $sImg(thumb,$j)
                    set sImg(thumbBtn,$i) $sImg(thumbBtn,$j)
                }
                catch {unset sImg(poImg,$i)}
                if { [info exists sImg(poImg,$j)] } {
                    set sImg(poImg,$i) $sImg(poImg,$j)
                }
                catch {unset sImg(rawDict,$i)}
                if { [info exists sImg(rawDict,$j)] } {
                    set sImg(rawDict,$i) $sImg(rawDict,$j)
                }
                catch {unset sImg(markImg,side,$i)}
                if { [info exists sPo(markImg,side,$j)] } {
                    set sPo(markImg,side,$i) $sPo(markImg,side,$j)
                }
            }
            catch {unset sImg(photo,$lastImgNum)}
            catch {unset sImg(thumb,$lastImgNum)}
            catch {unset sImg(thumbBtn,$lastImgNum)}
            catch {unset sImg(poImg,$lastImgNum)}
            catch {unset sImg(rawDict,$lastImgNum)}
            catch {unset sImg(name,$lastImgNum)}
            catch {unset sPo(markImg,side,$lastImgNum)}
            catch {unset sPo(markImg,cur)}

            IncrNumImgs -1
            if { $updateDisplay } {
                ShowImg -1
                if { $cur > 0 } {
                    ShowPrev
                } else {
                    if { [HaveImgs] } {
                       ShowCurrent
                    }
                }
            }
            if { ! [HaveImgs] && [info exists sPo(zoomPhoto)] } {
                image delete $sPo(zoomPhoto)
                unset sPo(zoomPhoto)
            }
        }
    }

    proc CopyImg { } {
        variable sPo

        set selectedValue [poWinSelect GetSelectedValue $sPo(fileCombo)]
        if { $selectedValue ne "" } {
            clipboard clear
            clipboard append $selectedValue
            WriteInfoStr "Copied to clipboard: $selectedValue" "OK"
        } elseif { [HaveImgs] } {
            poWin Img2Clipboard [GetCurImgPhoto]
            WriteInfoStr "Copied image to clipboard" "OK"
        }
    }

    proc PasteImg { } {
        set retVal [catch { poWin Clipboard2Img } phImg]
        if { $retVal == 0 } {
            AddImg $phImg "" [CreateNewImgFileName "ClipboardImage"]
            WriteInfoStr "Pasted image from clipboard" "OK"
        } else {
            WriteInfoStr "$phImg" "Error"
        }
    }

    proc SwapArrayElements { arr elem1 elem2 } {
        upvar $arr a

        if { [info exists a($elem1)] } {
            set tmp $a($elem1)
        }
        if { [info exists a($elem2)] } {
            set a($elem1) $a($elem2)
        }
        if { [info exists tmp] } {
            set a($elem2) $tmp
        } else {
            if { [info exists a($elem2)] } {
                unset a($elem2)
            }
        }
    }

    proc SwapPackedWidgets { fr elem1 elem2 } {
        variable sPo
        variable sImg

        set btnList [pack slaves $fr]

        set tmp [lindex $btnList $elem1]
        lset btnList $elem1  [lindex $btnList $elem2]
        lset btnList $elem2 $tmp

        foreach w $btnList {
            set packOpts($w) [pack info $w]
            pack forget $w
        }
        foreach w $btnList {
            pack $w {*}$packOpts($w)
        }

        SwapArrayElements sImg "thumb,$elem1"        "thumb,$elem2"
        SwapArrayElements sImg "thumbBtn,$elem1"     "thumbBtn,$elem2"
        SwapArrayElements sImg "photo,$elem1"        "photo,$elem2"
        SwapArrayElements sImg "name,$elem1"         "name,$elem2"
        SwapArrayElements sImg "poImg,$elem1"        "poImg,$elem2"
        SwapArrayElements sPo  "markImg,side,$elem1" "markImg,side,$elem2"
    }

    proc MoveUp {} {
        variable sPo
        variable sImg

        set cur [GetCurImgNum]
        if { $cur <= 0 || ! [HaveImgs] } {
            return
        }
        set prev [expr { $cur - 1 }]

        SwapPackedWidgets $sPo(thumbFr) $prev $cur

        SetCurImgNum $prev
    }

    proc MoveDown {} {
        variable sPo
        variable sImg

        set cur [GetCurImgNum]
        if { $cur >= [expr { [GetNumImgs] - 1 }] || ! [HaveImgs] } {
            return
        }
        set next [expr { $cur + 1 }]

        SwapPackedWidgets $sPo(thumbFr) $next $cur

        SetCurImgNum $next
    }

    proc ShowImgByName { phImg } {
        variable sImg

        for { set i 0 } { $i < [GetNumImgs] } { incr i } {
            if { $phImg eq [GetImgPhoto $i] } {
                SetCurImgNum $i
                ShowImg $i
            }
        }
    }

    proc ShowCurrent {} {
        ShowImg [GetCurImgNum]
    }

    proc ShowFirst {} {
        variable sImg

        if { [HaveImgs] } {
            SetCurImgNum 0
            ShowCurrent
        }
    }

    proc ShowLast {} {
        variable sImg

        if { [HaveImgs] } {
            SetCurImgNum [expr ([GetNumImgs] -1)]
            ShowCurrent
        }
    }

    proc ShowPrev {} {
        variable sImg

        if { [HaveImgs] && [GetCurImgNum] > 0 } {
            incr sImg(curNo) -1
            ShowCurrent
        }
    }

    proc ShowNext {} {
        variable sImg

        if { [HaveImgs] } {
            if { [GetCurImgNum] < [expr ([GetNumImgs] -1)] } {
                incr sImg(curNo) 1
                ShowCurrent
            }
        }
    }

    proc ShowPlay { { dir 1 } } {
        variable sImg

        if { ! [HaveImgs] } {
            return
        }
        set sImg(stopPlay) 0
        _PushInfoState
        if { $dir == 1 } {
            while { [GetCurImgNum] < [expr ([GetNumImgs] -1)] && ! $sImg(stopPlay) } {
                incr sImg(curNo) 1
                ShowCurrent
            }
        } else {
            while { [GetCurImgNum] > 0 && ! $sImg(stopPlay) } {
                incr sImg(curNo) -1
                ShowCurrent
            }
        }
        _PopInfoState
        ShowCurrent
        ScanCurDirForImgs
    }

    proc ShowStop {} {
        variable sImg

        set sImg(stopPlay) 1
    }

    proc ShowRawAsPalette { mode } {
        variable sImg
        variable sPo

        set cur [GetCurImgNum]

        if { ! [info exists sImg(rawDict,$cur)] } {
            tk_messageBox -message "You must load a RAW image first." \
                          -type ok -icon warning
            focus $sPo(tw)
            return
        }
        set numChan   [poImgDict GetNumChannels sImg(rawDict,$cur)]
        set pixelSize [poImgDict GetPixelSize   sImg(rawDict,$cur)]
        if { ! ($numChan == 1 && $pixelSize == 2) } {
            tk_messageBox -message "Palette display only possible for 16-bit images with 1 channel." \
                          -type ok -icon warning
            focus $sPo(tw)
            return
        }

        set phImg [GetCurImgPhoto]
        poWatch Reset swatch

        if { $mode eq "Greyscale" } {
            set imgDict [poImgMisc LoadImg [GetCurImgName]]
            set newImg  [dict get $imgDict phImg]
        } else {
            set newImg [poImgDict CreatePseudoColorPhoto $sImg(rawDict,$cur) $mode]
        }
        WriteInfoStr [format "$mode image (%.2f sec)" [poWatch Lookup swatch]] "Ok"

        set sImg(photo,$cur) $newImg
        image delete $phImg
        ShowImg $cur
        UpdateThumb [GetImgPhoto $cur]
    }

    proc SlideShowFinished { cmdString code result op } {
        variable ns

        if { $result } {
            set markedImgs [poSlideShow::GetMarkedImgs]
            set imgNameList [GetImgNames]
            foreach markedImg $markedImgs {
                if { [lsearch -exact $imgNameList $markedImg] < 0 } {
                    ReadImg $markedImg
                }
            }
        }
        trace remove execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
    }

    proc GetCurDir {} {
        variable sPo

        if { [HaveImgs] } {
            set fileName [GetCurImgName]
        } else {
            set fileName [poWinSelect GetValue $sPo(fileCombo)]
        }
        set dirName [file dirname $fileName]
        if { ! [file isdirectory $dirName] } {
            set dirName [pwd]
        }
        return $dirName
    }

    proc ShowSlideShow { { useDirOfCurImg true } } {
        variable ns
        variable sPo
        variable sImg

        trace add execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
        if { $useDirOfCurImg } {
            set dirName [GetCurDir]
            poApps StartApp poSlideShow [list $dirName]
            poSlideShow SetFileMarkList [GetImgNames]
        } else {
            poApps StartApp poSlideShow [GetImgNames]
        }
        poSlideShow SetInitialFile [GetCurImgName]
    }

    proc SetLogoColor {} {
        variable sLogo
        variable sPo

        $sPo(mainCanv) itemconfigure LogoText -fill    $sLogo(color)
        $sPo(mainCanv) itemconfigure LogoRect -outline $sLogo(color)
        $sPo(mainCanv) itemconfigure LogoLine -fill    $sLogo(color)
    }

    proc SetLogoPosCB { { xoff 0 } { yoff 0 } } {
        variable sPo
        variable sLogo

        if { [string is integer -strict $sLogo(xoff)] } {
            incr sLogo(xoff) $xoff
        }
        if { [string is integer -strict $sLogo(yoff)] } {
            incr sLogo(yoff) $yoff
        }
        SetLogoPos
    }

    proc SetLogoPos {} {
        variable sPo
        variable sLogo

        if { $sLogo(show) == 0 } {
            $sPo(mainCanv) coords LogoRect -100 -100 -90 -90
            $sPo(mainCanv) coords LogoText -100 -100
            $sPo(mainCanv) coords LogoLine -100 -100 -90 -90
            return
        }

        set retVal [catch {set xoff [expr int ($sLogo(xoff))] }]
        if { $retVal != 0 } {
            set xoff 0
        }
        set retVal [catch {set yoff [expr int ($sLogo(yoff))] }]
        if { $retVal != 0 } {
            set yoff 0
        }

        switch $sLogo(pos) {
            tl { set x $xoff
                 set y $yoff
                 set xscroll 0
                 set yscroll 0
               }
            tr { set x [expr $sPo(mainWin,w) - $xoff - $sLogo(w)]
                 set y $yoff
                 set xscroll 1
                 set yscroll 0
               }
            bl { set x $xoff
                 set y [expr $sPo(mainWin,h) - $yoff - $sLogo(h)]
                 set xscroll 0
                 set yscroll 1
               }
            br { set x [expr $sPo(mainWin,w) - $xoff - $sLogo(w)]
                 set y [expr $sPo(mainWin,h) - $yoff - $sLogo(h)]
                 set xscroll 1
                 set yscroll 1
               }
            ce { set x [expr int(($sPo(mainWin,w) - $sLogo(w)) / 2) - $xoff]
                 set y [expr int(($sPo(mainWin,h) - $sLogo(h)) / 2) - $yoff]
                 set xscroll 1
                 set yscroll 1
               }
        }
        Xview moveto $xscroll
        Yview moveto $yscroll
        $sPo(mainCanv) coords LogoRect \
            [expr $x * $sPo(zoom)] [expr $y * $sPo(zoom)] \
            [expr ($x + $sLogo(w)) * $sPo(zoom)] \
            [expr ($y + $sLogo(h)) * $sPo(zoom)]
        $sPo(mainCanv) coords LogoText [expr ($x + $sLogo(xtxt)) * $sPo(zoom)] \
                                       [expr ($y + $sLogo(ytxt)) * $sPo(zoom)]
        set sLogo(rect) [$sPo(mainCanv) coords LogoRect]
    }

    proc ApplyLogo {} {
        variable sPo
        variable sLogo
        variable sImg

        if { ! [HaveImgs] } {
            WriteInfoStr "Apply logo: No images loaded" "Error"
            return
        }
        $sPo(mainCanv) config -cursor watch
        update

        lassign [poMisc RgbToDec $sLogo(color)] r g b
        set sr [expr $r / 255.0]
        set sg [expr $g / 255.0]
        set sb [expr $b / 255.0]

        set ic $sLogo(rect)
        set ix1 [expr int ([lindex $ic 0] / $sPo(zoom))]
        set iy1 [expr int ([lindex $ic 1] / $sPo(zoom))]
        set ix2 [expr int ([lindex $ic 2] / $sPo(zoom))]
        set iy2 [expr int ([lindex $ic 3] / $sPo(zoom))]

        set cur [GetCurImgNum]
        if { [poApps GetVerbose] } {
            puts "Add logo to image [GetCurImgName]"
        }
        poWatch Reset swatch
        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sImg(poImg,$cur)] } {
                set sImg(poImg,$cur) [poImage NewImageFromPhoto [GetCurImgPhoto]]
            }
            set img $sImg(poImg,$cur)
            $img ApplyLogo $sLogo(poImg) $ix1 $iy1 $sr $sg $sb $sPo(license)
            $img AsPhoto [GetCurImgPhoto]
        } else {
            set phImg [GetCurImgPhoto]
            $phImg copy $sLogo(photo) -to $ix1 $iy1
        }
        WriteInfoStr [format "Apply logo (%.2f sec)" [poWatch Lookup swatch]] "Ok"
        ShowImg $cur
        UpdateThumb [GetCurImgPhoto]
        $sPo(mainCanv) config -cursor $sPo(curCursor)
    }

    proc ApplyLogoAll {} {
        ShowFirst
        for { set i 0 } { $i < [GetNumImgs] } { incr i } {
            ApplyLogo
            ShowNext
        }
    }

    proc DelAll {} {
        variable sPo

        for { set i [expr [GetNumImgs] -1] } { $i >= 0 } { incr i -1 } {
            DelImg $i false
        }
        SetNumImgs 0
        ShowImg -1
    }

    proc CloseSubWindows {} {
        variable sPo

        catch {destroy $sPo(histoWin,name)}
        catch {destroy $sPo(logoWin,name)}
        catch {destroy $sPo(countColorWin,name)}
        catch {CloseImageMapWindow $sPo(imageMapWin,name)}
        catch {CloseNewImgWin}
        poHistogram CloseAllHistoWin $sPo(appName)
        poColorCount CloseAllWin $sPo(appName)
    }

    proc CloseAppWindow {} {
        variable sPo
        variable sLogo

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }
        DelAll

        catch { image delete $sLogo(photo) }
        if { [poImgAppearance UsePoImg] && [info exists sLogo(poImg)] } {
            poImgUtil DeleteImg $sLogo(poImg)
        }

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        CloseAppWindow
        poApps ExitApp
    }

    proc GetFileName { mode { initFile "" } } {
        variable ns
        variable sPo

        set imgFormat ""
        if { [poImgAppearance GetUseLastImgFmt] } {
            set imgFormat [poImgAppearance GetLastImgFmtUsed] } {
        }
        set fileTypes [poImgType GetSelBoxTypes $imgFormat]
        if { $mode eq "save" } {
            if { ! [info exists sPo(LastImgType)] } {
                set sPo(LastImgType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastImgType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }
            if { ! [info exists sPo(lastDir)] } {
                set sPo(lastDir) [file dirname $sPo(lastFile)]
            }
            set fileName [tk_getSaveFile \
                         -filetypes $fileTypes \
                         -title "Save image as" \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastImgType) \
                         -initialfile [file tail $initFile] \
                         -initialdir $sPo(lastDir)]
            if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
                set ext [poMisc GetExtensionByType $fileTypes $sPo(LastImgType)]
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
                if { $fileName ne "" } {
                    set sPo(lastDir) [file dirname $fileName]
                }
            }
        } else {
            set fileName [tk_getOpenFile -filetypes $fileTypes \
                         -initialdir [file dirname $sPo(lastFile)]]
        }
        return $fileName
    }

    proc AskOpenAniGif {} {
        set imgName [GetFileName "open"]
        if { $imgName ne "" } {
            ReadAniGif $imgName 0
        }
    }

    proc AskSaveAniGif {} {
        set imgName [GetFileName "save"]
        if { $imgName ne "" } {
            WriteAniGif $imgName
        }
    }

    proc ReadAniGif { imgName { saveImgsToFile 0 } } {
        variable sPo

        set sPo(stopJob) 0

        set canvasId $sPo(mainCanv)
        $canvasId config -cursor watch
        update

        poWatch Reset swatch
        set retVal 0
        set poImg ""
        set ind 0
        set showDialog 1
        while { $retVal == 0 } {
            set retVal [catch {set phImg [image create photo -file $imgName \
                                          -format "GIF -index $ind"]} err1]
            if { $retVal == 0 } {
                # We suceeded in reading an image from the AniGif file.
                poLog Info [format "Read AniGif %s (%.2f sec)" $imgName [poWatch Lookup swatch]]

                set prefix [file rootname $imgName]
                set frameName [format "%s%03d.gif" $prefix [expr $ind +1]]
                AddImg $phImg $poImg $frameName
                if { $saveImgsToFile } {
                    set choice 0
                    if { [file exists $frameName] && $showDialog } {
                        set choice [tk_dialog .readAniGif "Confirmation" \
                          "File $frameName exists. Overwrite ?" question 2 \
                          "Yes" "Yes to all" "No" "Cancel"]
                    }
                    if { $choice <= 1 } {
                        $phImg write $frameName -format "GIF"
                        if { $choice == 1 } {
                            set showDialog 0
                        }
                    } elseif { $choice == 3 || $choice < 0 } {
                        break
                    }
                }
                incr ind
                if { $sPo(stopJob) } {
                    WriteInfoStr "GIF's not completely loaded" "Warning"
                    break
                }
            }
        }
        $canvasId config -cursor $sPo(curCursor)
    }

    proc WriteAniGif { imgName } {
        variable sImg

        set curDir [pwd]
        cd [file dirname [GetImgName 0]]

        ShowFirst
        set cmdStr "gifsicle"
        for { set i 0 } { $i < [GetNumImgs] } { incr i } {
            append cmdStr " "
            append cmdStr [file tail [GetImgName $i]]
            ShowNext
        }
        append cmdStr " -o $imgName"
        poLog Info "Write AniGif ($cmdStr)"
        eval exec $cmdStr
        cd $curDir
    }

    proc ReadImg { imgName { showInCanvas 1 } { addToRecentFileList 1 } } {
        variable sPo
        variable sConv

        set canvasId $sPo(mainCanv)
        $canvasId config -cursor watch
        update

        poWatch Reset swatch
        set retVal [catch {poImgMisc LoadImg $imgName $sConv(inFmtOpt)} imgDict]

        if { $retVal == 0 } {
            # We suceeded in reading an image from file.
            set saveTime [poWatch Lookup swatch]
            set phImg [dict get $imgDict phImg]
            set poImg [dict get $imgDict poImg]

            if { $showInCanvas } {
                AddImg $phImg $poImg $imgName
            }
            poLog Info [format "Display image (%.2f sec)" [expr [poWatch Lookup swatch] - $saveTime]]

            set curFile [poMisc FileSlashName $imgName]
            if { $addToRecentFileList } {
                poAppearance AddToRecentFileList $curFile
            }
            poAppearance AddToRecentDirList [file dirname $curFile]
            poImgAppearance StoreLastImgFmtUsed $curFile
            set sPo(lastFile) $curFile
            set totalTime [poWatch Lookup swatch]
            WriteInfoStr "Read image [file tail $imgName] ([format %.2f $totalTime] sec)" "Ok"
        } else {
            poWinSelect SetValue $sPo(fileCombo) $imgName
            WriteInfoStr "Error reading image: $imgDict" "Error"
        }
        $canvasId config -cursor $sPo(curCursor)
        event generate $sPo(fileCombo) <Key-Escape>
        return $imgDict
    }

    proc _PushInfoState {} {
        variable sPo

        set sPo(showImgInfoSave)  $sPo(showImgInfo)
        set sPo(showFileInfoSave) $sPo(showFileInfo)
        set sPo(showImgInfo)  0
        set sPo(showFileInfo) 0
        set sPo(ShowRawCurValueSave) [poImgAppearance GetShowRawCurValue] 
        set sPo(ShowRawImgInfoSave)  [poImgAppearance GetShowRawImgInfo]
        poImgAppearance SetShowRawCurValue 0
        poImgAppearance SetShowRawImgInfo  0
    }

    proc _PopInfoState {} {
        variable sPo

        set sPo(showImgInfo)  $sPo(showImgInfoSave)
        set sPo(showFileInfo) $sPo(showFileInfoSave)
        poImgAppearance SetShowRawCurValue $sPo(ShowRawCurValueSave) 
        poImgAppearance SetShowRawImgInfo  $sPo(ShowRawImgInfoSave)
        UpdateInfoWidget
    }

    proc ReloadImgs {} {
        variable sPo

        set imgNameList [GetImgNames]
        DelAll
        _PushInfoState
        foreach imgName $imgNameList {
            ReadImg $imgName 1 0
        }
        _PopInfoState
        ShowCurrent
        ScanCurDirForImgs
    }

    proc ReadIcon {} {
        variable ns
        variable sPo
        variable sLogo

        set logoName $sLogo(file)
        if { ! [file exists $logoName] } {
            poLog Warning "Logo image does not exist: Generating default icon"
            GenDefaultLogo
        } else {
            if { [poImgAppearance UsePoImg] && [info exists sLogo(poImg)] } {
                poImgUtil DeleteImg $sLogo(poImg)
            }
            if { [info exists sLogo(photo)] } {
                image delete $sLogo(photo)
            }
            set imgDict [ReadImg $logoName 0]
            if { ! [dict exists $imgDict phImg] } {
                poLog Warning "Unknown image format: Generating default icon"
                GenDefaultLogo
            } else {
                set sLogo(photo) [dict get $imgDict phImg]
                set sLogo(poImg) [dict get $imgDict poImg ]
                if { [poImgAppearance UsePoImg] && $sLogo(poImg) eq "" } {
                    set sLogo(poImg) [poImage NewImageFromPhoto $sLogo(photo)]
                }
            }
        }
        set sLogo(w) [image width  $sLogo(photo)]
        set sLogo(h) [image height $sLogo(photo)]
    }

    proc OpenIcon {} {
        variable sPo
        variable sLogo

        if { $sLogo(file) eq "" } {
            set pathName [file join [pwd] "logo"]
        } else {
            set pathName $sLogo(file)
        }
        set logoDir [file dirname $pathName]
        if { ! [file isdirectory $logoDir] } {
            set logoDir [pwd]
        }
        if { [file exists $pathName] } {
            set logoFile [file tail $pathName]
        } else {
            set logoFile ""
        }
        set imgFormat ""
        if { [poImgAppearance GetUseLastImgFmt] } {
            set imgFormat [poImgAppearance GetLastImgFmtUsed] } {
        }
        set fileTypes [poImgType GetSelBoxTypes $imgFormat]
        set imgName  [tk_getOpenFile -filetypes $fileTypes \
                      -title "Choose logo image" \
                      -initialdir $logoDir -initialfile $logoFile]
        if { $imgName ne "" } {
            set sLogo(file) $imgName
            ReadIcon
            DisplayLogo
            SetLogoPos
            SwitchBindings "Logo"
        }
    }

    proc Open {} {
        variable sPo

        set imgName [GetFileName "open"]
        if { $imgName ne "" } {
            if { ! $sPo(loadAsNewImg) } {
                DelImg [expr [GetNumImgs] -1] false
            }
            ReadImg $imgName
        }
    }

    proc ScanCurDirForImgs {} {
        variable sPo

        set curFile [poWinSelect GetValue $sPo(fileCombo)]
        set sPo(imgsInDir,cur)   0
        set sPo(imgsInDir,max)   0
        set sPo(imgsInDir,dir)   ""
        set sPo(imgsInDir,files) [list]
        if { [file isfile $curFile] || [file isdirectory $curFile] } {
            if { [file isfile $curFile] } {
                set dirName [file dirname $curFile]
            } else {
                set dirName $curFile
            }
            set fileList [lsort -dictionary [lindex [poMisc GetDirsAndFiles $dirName -showdirs false] 1] ]
            foreach ext [poImgType GetExtList ""] {
                lappend matchList [format "*%s" $ext]
            }
            foreach f $fileList {
                foreach patt $matchList {
                    if { [string match -nocase $patt $f] } {
                        lappend sPo(imgsInDir,files) $f
                        break
                    }
                }
            }
            if { [file isfile $curFile] } {
                set imgInd [lsearch -exact $sPo(imgsInDir,files) [file tail $curFile]]
            } else {
                set imgInd 0
            }
            set sPo(imgsInDir,cur) [expr { $imgInd + 1 }]
            set sPo(imgsInDir,max) [llength $sPo(imgsInDir,files)]
            set sPo(imgsInDir,dir) $dirName
        }
    }

    proc LoadNextImg { { dir "" } } {
        variable sPo

        if { $dir ne "" } {
            ScanCurDirForImgs
        }
        set imgInd [expr { $sPo(imgsInDir,cur) - 1 }]
        if { $imgInd < 0 } {
            return
        }
        set numImgs $sPo(imgsInDir,max)
        if { $dir == 0 } {
            set imgInd 0
        } elseif { $dir eq "end" } {
            set imgInd [expr { $numImgs - 1 }]
        } elseif { $dir == -1 && $imgInd > 0 } {
            incr imgInd -1
        } elseif { $dir == 1 && $imgInd < [expr { $numImgs -1 }] } {
            incr imgInd 1
        } else {
            set ind [expr { $sPo(imgsInDir,cur) - 1 }]
            if { $ind >= 0 && $ind < $numImgs } {
                set imgInd $ind
            }
        }
        set imgName [lindex $sPo(imgsInDir,files) $imgInd]
        set sPo(imgsInDir,cur) [expr { $imgInd + 1 }]
        if { ! $sPo(loadAsNewImg) } {
            DelImg [expr [GetNumImgs] -1] false
        }
        ReadImg [file join $sPo(imgsInDir,dir) $imgName] 1 0
    }

    proc CreateUniformImage { w h c imgName } {
        set phImg [image create photo -width $w -height $h]
        set poImg ""

        if { [poImgAppearance UsePoImg] } {
            set rgb [poMisc RgbToDec $c]
            set r [expr [lindex $rgb 0] / 255.0]
            set g [expr [lindex $rgb 1] / 255.0]
            set b [expr [lindex $rgb 2] / 255.0]
            poImgUtil SetFormatRGBA $::UBYTE $::UBYTE $::UBYTE $::OFF
            poImgUtil SetDrawColorRGB $r $g $b
            set poImg [poImage NewImage $w $h]
            $poImg DrawRect 0 0 $w $h
            $poImg AsPhoto $phImg
        } else {
            set scanline [list]
            for { set x 0 } { $x < $w } { incr x } {
                lappend scanline $c
            }
            set data [list]
            lappend data $scanline
            for { set y 0 } { $y < $h } { incr y } {
                $phImg put $data -to 0 $y
            }
        }
        AddImg $phImg $poImg $imgName
    }

    proc New {} {
        ShowNewImgWin "New image"
    }

    proc BrowseDir {} {
        variable sPo

        ::poImgBrowse::OpenDir [GetCurDir]
    }

    proc SwitchOnDtedCell { btn ew ns } {
        variable sDted

        if { $sDted($ew,$ns) == 0 } {
            incr sDted(cellsSelected) 1
        }
        set sDted($ew,$ns) 1
        $btn configure -background green
    }

    proc SwitchOffDtedCell { btn ew ns } {
        variable sDted

        if { $sDted($ew,$ns) == 1 } {
            incr sDted(cellsSelected) -1
        }
        set sDted($ew,$ns) 0
        $btn configure -background white
    }

    proc RangeSelDtedCell { msg ew ns onOff } {
        variable sDted

        set ewMin [poMisc Min $ew $sDted(ewLastSel)]
        set ewMax [poMisc Max $ew $sDted(ewLastSel)]
        set nsMin [poMisc Min $ns $sDted(nsLastSel)]
        set nsMax [poMisc Max $ns $sDted(nsLastSel)]
        for { set i $ewMin } { $i <= $ewMax } { incr i } {
            for { set j $nsMin } { $j <= $nsMax } { incr j } {
                if { [info exists sDted($i,$j)] } {
                    if { $onOff } {
                        SwitchOnDtedCell  $sDted(btn,$i,$j) $i $j
                    } else {
                        SwitchOffDtedCell $sDted(btn,$i,$j) $i $j
                    }
                }
            }
        }
        $msg configure -text "Available cells: $sDted(cellsAvailable) \
                             ($sDted(cellsSelected) selected)"
    }

    proc ToggleDtedCell { msg btn ew ns } {
        variable sDted

        if { $sDted($ew,$ns) == 0 } {
            SwitchOnDtedCell $btn $ew $ns
        } else {
            SwitchOffDtedCell $btn $ew $ns
        }
        set sDted(ewLastSel) $ew
        set sDted(nsLastSel) $ns
        $msg configure -text "Available cells: $sDted(cellsAvailable) \
                             ($sDted(cellsSelected) selected)"
    }

    proc LoadDtedFiles { tw } {
        variable sPo
        variable sDted

        set sPo(stopJob) 0
        for { set ew $sDted(ewMin) } { $ew <= $sDted(ewMax) } { incr ew } {
            for { set ns $sDted(nsMin) } { $ns <= $sDted(nsMax) } { incr ns } {
                if { [info exists sDted($ew,$ns)] && $sDted($ew,$ns) == 1 } {
                    update
                    if { $sPo(stopJob) } {
                        WriteInfoStr "DTED loading stopped by user." "Warning"
                        break
                    }
                    ReadImg $sDted($ew,$ns,filename) 1 0
                }
            }
            if { $sPo(stopJob) } {
                break
            }
        }
    }

    proc ShowDtedSelWin { ewMin ewMax nsMin nsMax } {
        variable ns
        variable sPo
        variable sDted

        # puts "Drawing cells. EW: $ewMin $ewMax  NS: $nsMin $nsMax"
        set tw .poImgview_dtedSelWin

        catch { destroy $tw }

        toplevel $tw
        wm title $tw "DTED selection window"
        wm resizable $tw true true

        frame $tw.fr1
        frame $tw.fr2
        frame $tw.fr3
        pack $tw.fr1 -expand 1 -fill both
        pack $tw.fr2 -expand 1 -fill x
        pack $tw.fr3 -expand 1 -fill x

        set msg $tw.fr2.l
        set cellBmp [::poBmpData::cell]
        set col 1
        for { set lon $ewMin } { $lon <= $ewMax } { incr lon } {
            label $tw.fr1.lew_$lon -text [format "%03d" [poMisc Abs $lon]]
            grid  $tw.fr1.lew_$lon -row 0 -column $col -sticky nw
            set row 1
            for { set lat $nsMax } { $lat >= $nsMin } { incr lat -1 } {
                if { $lon == $ewMin } {
                    label $tw.fr1.lns_$lat -text [format "%02d" [poMisc Abs $lat]]
                    grid  $tw.fr1.lns_$lat -row $row -column 0 -sticky nw
                }
                set bName [format "%d_%d" $lon $lat]
                set btn $tw.fr1.b_$bName
                set sDted(btn,$lon,$lat) $btn
                if { [info exists sDted($lon,$lat)] } {
                    button $btn -image $cellBmp -relief flat -background white
                    bind $btn <ButtonRelease-1> \
                              "${ns}::ToggleDtedCell $msg $btn $lon $lat"
                    bind $btn <Shift-ButtonRelease-1> \
                              "${ns}::RangeSelDtedCell $msg $lon $lat 1"
                    bind $btn <Control-ButtonRelease-1> \
                              "${ns}::RangeSelDtedCell $msg $lon $lat 0"
                } else {
                    button $btn -image $cellBmp -relief flat -background red \
                           -state disabled
                }
                grid $btn -row $row -column $col -sticky news
                incr row
            }
            incr col
          }

        # Create message label
        label $msg -text "Available cells: $sDted(cellsAvailable)"
        pack  $msg -expand 1 -fill x

        # Create Cancel and OK buttons
        bind  $tw <KeyPress-Escape> "destroy $tw"
        button $tw.fr3.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                          -compound left -command "destroy $tw"
        wm protocol $tw WM_DELETE_WINDOW "destroy $tw"

        bind  $tw <KeyPress-Return> "${ns}::LoadDtedFiles $tw"
        button $tw.fr3.b2 -text "OK" -image [poWin GetOkBitmap] \
                           -compound left -default active \
                           -command "${ns}::LoadDtedFiles $tw"
        pack $tw.fr3.b1 $tw.fr3.b2 -side left -fill x -padx 2 -pady 2 -expand 1
        focus $tw
    }

    proc ScanDtedRoot { dtedRoot } {
        variable sPo
        variable sDted

        # OPA set fileList {}
        catch {unset sDted}
        set sDted(cellsAvailable) 0
        set sDted(cellsSelected)  0
        set sDted(ewMin) 180 ; set sDted(ewMax) -180
        set sDted(nsMin)  90 ; set sDted(nsMax)  -90

        # OPA !!! This has to be changed, if using non-standard DTED directories.
        set dtedCont [poMisc GetDirsAndFiles $dtedRoot 1 -showfiles false -showhiddendirs false -showhiddenfiles false -filepattern "e??? E??? w??? W???"]
        set dtedDirs [lindex $dtedCont 0]
        set matchStr [format "*.dt%d *.DT%d" $sPo(dted,level) $sPo(dted,level)]
        foreach dir $dtedDirs {
            set dirList [poMisc GetDirsAndFiles $dir -showdirs false -showhiddendirs false -showhiddenfiles false -filepattern $matchStr]
            set dtedFiles [lindex $dirList 1]
            if { [llength $dtedFiles] > 0 } {
                # Subdirectories specify East-West directions. Store cell number in
                # appr. array.
                set shortDirName [file tail $dir]
                scan $shortDirName "%1s%3d" ew ewNum
                if { [string compare -nocase -length 1 "w" $ew] == 0 } {
                    set ewNum [expr -1 * $ewNum]
                }
                if { $ewNum > $sDted(ewMax) } { set sDted(ewMax) $ewNum }
                if { $ewNum < $sDted(ewMin) } { set sDted(ewMin) $ewNum }
                # Scan each file and extract cell numbers as we did for directories.
                foreach fName $dtedFiles {
                    # OPA lappend fileList [file join $dir $fName]
                    scan $fName "%1s%2d" ns nsNum
                    if { [string compare -nocase -length 1 "s" $ns] == 0 } {
                        set nsNum [expr -1 * $nsNum]
                    }
                    set sDted($ewNum,$nsNum) 0
                    set sDted($ewNum,$nsNum,filename) [file join $dir $fName]
                    incr sDted(cellsAvailable)
                    if { $nsNum > $sDted(nsMax) } { set sDted(nsMax) $nsNum }
                    if { $nsNum < $sDted(nsMin) } { set sDted(nsMin) $nsNum }
                }
            }
        }
        ShowDtedSelWin $sDted(ewMin) $sDted(ewMax) $sDted(nsMin) $sDted(nsMax)
    }

    proc BrowseDted {} {
        variable sPo

        if { ! [poApps HavePkg "Img"] } {
            tk_messageBox -title "Information" -type ok -icon info \
                -message "Dted browsing needs the Img extension.\n\
                          See Help->About Tcl/Tk for download address."
            focus $sPo(tw)
            return
        }

        set tmpDir [poWin ChooseDir "Select DTED root directory" [file dirname $sPo(lastFile)]]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            ScanDtedRoot $tmpDir
        }
    }

    proc SaveImg { imgName } {
        variable sPo
        variable sConv
        variable sImg

        set ext    [file extension $imgName]
        set fmtStr [poImgType GetFmtByExt $ext]
        if { $fmtStr eq "" } {
            WriteInfoStr "Extension \"$ext\" not supported." "Error"
            return
        }

        $sPo(mainCanv) config -cursor watch
        update
        poWatch Reset swatch

        if { $sConv(outFmtOpt) eq "" } {
            set optStr [poImgType GetOptByFmt $fmtStr "write"]
        } else {
            set optStr $sConv(outFmtOpt)
        }
        set retVal [catch { $sImg(photo,$sImg(curNo)) write $imgName -format "$fmtStr $optStr" } errMsg]
        if { $retVal != 0 } {
            WriteInfoStr "Error saving image: $errMsg" "Error"
        } else {
            set sImg(name,$sImg(curNo)) $imgName
            set totalTime [poWatch Lookup swatch]
            WriteInfoStr "Saved image [file tail $imgName] ([format %.2f $totalTime] sec)" "Ok"
            poImgAppearance StoreLastImgFmtUsed $imgName
            UpdateFileName
        }
        $sPo(mainCanv) config -cursor $sPo(curCursor)
    }

    proc CaptureWin {} {
        variable sPo

        set defName [CreateNewImgFileName "CapturedWindow"]
        $sPo(mainCanv) config -cursor watch
        WriteInfoStr "Capturing window ..." "Watch"
        update
        set phImg [poWin Windows2Img $sPo(tw)]
        set retVal [AddImg $phImg "" $defName]
        WriteInfoStr "Window captured" "Ok"
        $sPo(mainCanv) config -cursor $sPo(curCursor)
        return $retVal
    }

    proc CaptureCanv {} {
        variable sPo

        if { ! [HaveImgs] } {
            WriteInfoStr "No images loaded" "Error"
            return
        }
        set defName [file rootname [file tail [GetCurImgName]]]
        $sPo(mainCanv) config -cursor watch
        WriteInfoStr "Capturing canvas ..." "Watch"
        update
        set phImg [poWin Canvas2Img $sPo(mainCanv)]
        set retVal [AddImg $phImg "" $defName]
        WriteInfoStr "Canvas captured" "Ok"
        $sPo(mainCanv) config -cursor $sPo(curCursor)
        return $retVal
    }

    proc SaveAs {} {
        variable sImg

        if { ! [HaveImgs] } {
            return
        }
        set imgName [GetFileName "save" [GetCurImgName]]
        if { $imgName ne "" } {
            SaveImg $imgName
        }
    }

    proc BuildOutputFilename { inName } {
        variable sConv

        if { $sConv(useOutDir) } {
            set dirName $sConv(outDir)
        } else {
            set dirName [file dirname $inName]
        }
        if { ! [file isdirectory $dirName] } {
            file mkdir $dirName
        }
        set rootName [file rootname [file tail $inName]]
        set ext [file extension [file tail $inName]]
        if { $sConv(outFmt) ne "SameAsInput" } {
            set ext [lindex [poImgType GetExtList $sConv(outFmt)] 0]
        }
        set template $sConv(name)
        if { [string match "*%s*%*d*" $template] } {
            set imgName [format $template $rootName $sConv(counter)]
        } elseif { [string match "*%*d*%s*" $template] } {
            set imgName [format $template $sConv(counter) $rootName]
        } elseif { [string match "*%s*" $template] } {
            set imgName [format $template $rootName]
        } elseif { [string match "*%*d*" $template] } {
            set imgName [format $template $sConv(counter)]
        } else {
            set imgName [format "%s%s" $template $rootName]
        }
        set fullName [file join $dirName $imgName]
        append fullName $ext
        incr sConv(counter)
        return $fullName
    }

    proc Convert {} {
        variable sImg
        variable sPo

        set fileName [GetCurImgName]
        set imgName [BuildOutputFilename $fileName]
        set dirName [file dirname $imgName]
        if { ! [file isdirectory $dirName] } {
            set retVal [tk_messageBox \
                -message "Directory \"$dirName\" does not exist." \
                -title "Error" -type ok -icon error]
            return 0
        }
        if { [poApps GetVerbose] } {
            puts "Convert [file tail $fileName] to $imgName"
        }
        if { $imgName ne "" } {
            set retVal yes
            if { ! [poApps GetOverwrite] } {
                if { [file exists $imgName] } {
                    set retVal [tk_messageBox \
                      -message "File \"$imgName\" already exists.\n\
                                Do you want to overwrite it?" \
                      -title "Confirmation" -type yesnocancel -default no -icon info]
                }
            }
            if { $retVal eq "cancel" } {
                return 0
            }
            if { $retVal eq "yes" } {
                WriteInfoStr "Convert [file tail $fileName] to $imgName" "Ok"
                SaveImg $imgName
            }
            focus $sPo(tw)
        }
        return 1
    }

    proc ConvertAll {} {
        variable sConv

        ShowFirst
        set sConv(counter) $sConv(num)
        for { set i 0 } { $i < [GetNumImgs] } { incr i } {
            if { ! [Convert] } {
                break
            }
            ShowNext
        }
    }

    proc SetCurMousePos { x y } {
        variable sPo

        set sPo(mouse,x) $x
        set sPo(mouse,y) $y
    }

    proc MoveViewportRect { x y } {
        variable sPo
        variable sLogo

        $sPo(mainCanv) move LogoRect \
                       [expr $x - $sPo(mouse,x)] \
                       [expr $y - $sPo(mouse,y)]
        $sPo(mainCanv) move LogoText \
                       [expr $x - $sPo(mouse,x)] \
                       [expr $y - $sPo(mouse,y)]
        set sPo(mouse,x) $x
        set sPo(mouse,y) $y

        set sLogo(rect) [$sPo(mainCanv) coords LogoRect]
        set sLogo(xoff) [expr int ([lindex $sLogo(rect) 0])]
        set sLogo(yoff) [expr int ([lindex $sLogo(rect) 1])]
    }

    proc View { dir args } {
        variable sPo

        if { $dir eq "x" } {
            eval {$sPo(mainCanv) xview} $args
        } else {
            eval {$sPo(mainCanv) yview} $args
        }
    }

    proc Xview { args } {
        eval View x $args
    }

    proc Yview { args } {
        eval View y $args
    }

    proc FormatColorVal { val } {
        variable sPo

        if { [poImgAppearance GetShowColorInHex] } {
            return [format "%02X" $val]
        } else {
            return $val
        }
    }

    proc ClearPixelValue {} {
        variable sPo

        set sPo(curPos,x) "X"
        set sPo(curPos,y) "Y"
        set sPo(curCol,r) "R"
        set sPo(curCol,g) "G"
        set sPo(curCol,b) "B"
        set sPo(curCol,a) "A"
        set sPo(medCol,r) "R"
        set sPo(medCol,g) "G"
        set sPo(medCol,b) "B"
        set sPo(curCol,raw)  ""
        set sPo(curPal,ind)  ""
        set sPo(curPal,name) ""
    }

    proc PrintPixelValue { canvasId x y } {
        variable sPo
        variable sImg

        set px [expr {int([$canvasId canvasx $x] / $sPo(zoom))}]
        set py [expr {int([$canvasId canvasy $y] / $sPo(zoom))}]

        if { [HaveImgs] } {
            set w [GetCurImgPhotoWidth]
            set h [GetCurImgPhotoHeight]
            if { $px >= 0 && $py >= 0 && $px < $w && $py < $h } {
                set sPo(curPos,x) $px
                if { [poImgAppearance GetRowOrderCount] eq "TopDown" } {
                    set sPo(curPos,y) $py
                } else {
                    set sPo(curPos,y) [expr {$h - $py - 1}]
                }
                set srcImg [GetCurImgPhoto]
                if { [poMisc HaveTcl87OrNewer] } {
                    set retVal [catch {set rgb [$srcImg get $px $py -withalpha] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b a
                        set sPo(curCol,r) [FormatColorVal $r]
                        set sPo(curCol,g) [FormatColorVal $g]
                        set sPo(curCol,b) [FormatColorVal $b]
                        set sPo(curCol,a) [FormatColorVal $a]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(curCol,hex) configure -background $rgbHex
                    }
                } else {
                    set retVal [catch {set rgb [$srcImg get $px $py] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b
                        set sPo(curCol,r) [FormatColorVal $r]
                        set sPo(curCol,g) [FormatColorVal $g]
                        set sPo(curCol,b) [FormatColorVal $b]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(curCol,hex) configure -background $rgbHex
                    }
                }

                set sPo(curPal,ind)  ""
                set sPo(curPal,name) ""
                set entryIndex [poImgPalette GetPaletteEntryIndex $r $g $b]
                set entryName  [poImgPalette GetPaletteEntryName  $r $g $b]
                if { $entryName ne "" } {
                    set sPo(curPal,ind)  $entryIndex
                    set sPo(curPal,name) $entryName
                }

                set zoomRectSize [poZoomRect GetSize]
                set x1 [expr {($px - $zoomRectSize)}]
                set y1 [expr {($py - $zoomRectSize)}]
                set x2 [expr {($px + $zoomRectSize)}]
                set y2 [expr {($py + $zoomRectSize)}]
                set statDict [poPhotoUtil GetImgStats $srcImg false $x1 $y1 $x2 $y2]
                if { [dict get $statDict num] > 0 } {
                    set medR [expr round ([dict get $statDict mean red])]
                    set medG [expr round ([dict get $statDict mean green])]
                    set medB [expr round ([dict get $statDict mean blue])]
                    set sPo(medCol,r) [FormatColorVal $medR]
                    set sPo(medCol,g) [FormatColorVal $medG]
                    set sPo(medCol,b) [FormatColorVal $medB]
                    set medHex [format "#%02X%02X%02X" $medR $medG $medB]
                    $sPo(medCol,hex) configure -background $medHex
                }
                set curImgNum [GetCurImgNum]
                if { [info exists sImg(rawDict,$curImgNum)] } {
                    set sPo(curCol,raw) [poImgDict GetPixelValueAsString sImg(rawDict,$curImgNum) $px $py]
                }
            } else {
                ClearPixelValue
            }
        }
    }

    proc GetUsageMsg {} {
        variable sPo
        variable sConv

        if { $sConv(useOutDir) } {
            set outDir $sConv(outDir)
        } else {
            set outDir "SameAsInput"
        }
        if { $sConv(outFmt) eq "SameAsInput" } {
            set optStr "Depending on input format"
        } else {
            set optStr [poImgType GetOptByFmt $sConv(outFmt) "write"]
        }
        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[ImageFile1]\ \[ImageFileN\]\n"
        append msg "\n"
        append msg "Load images for viewing and processing.\n"
        append msg "If no option is specified, the images are loaded in a graphical user\n"
        append msg "interface for interactive manipulation.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--opt <string>        : Use specified format option for the input images.\n"
        append msg "--convfmt <string>    : Use specified format for the converted images.\n"
        append msg "                        Default: \"$sConv(outFmt)\".\n"
        append msg "--convopt <string>    : Use specified format option for the converted images.\n"
        append msg "                        Default: \"$optStr\".\n"
        append msg "--convname <string>   : Template for converted image files.\n"
        append msg "                        Use \"%s\" to insert original name without file extension.\n"
        append msg "                        Use \"%d\" or a printf variation to insert a number.\n"
        append msg "                        Default: \"$sConv(name)\".\n"
        append msg "--convnum <int>       : Start value for filename numbering while converting.\n"
        append msg "                        Default: $sConv(num).\n"
        append msg "--convdir <dir>       : Directory for converted image files.\n"
        append msg "                        Default: \"$outDir\".\n"
        append msg "--palettefile <string>: Use specified palette file for mapping images.\n"

        append msg "\n"
        append msg "Processing of multiple images into one image:\n"
        append msg "--equalsize          : All supplied images are of equal size. Hint for compose algorithmn.\n"
        append msg "--compose <int>      : Compose supplied image files into one image.\n"
        append msg "                       The images are arranged left to right, top to bottom,\n"
        append msg "                       assuming specified number of columns.\n"

        append msg "\n"
        append msg "Processing of single images:\n"
        append msg "--logo               : Put logo onto images.\n"
        append msg "                       Default: No\n"
        append msg "--crop <x1 y1 x2 y2> : Crop image to given rectangle.\n"
        append msg "                       <x1, y1> specify top-left corner.\n"
        append msg "                       Default: No cropping.\n"
        append msg "--scale <x y>        : Scale image to given size. Append a \"%\" to the numbers\n"
        append msg "                       to specify new size in percentages.\n"
        append msg "                       Default: No scaling.\n"
        append msg "--keepaspect         : Use in conjunction with option \"--scale\" to preserve\n"
        append msg "                       aspect ratio. No effect when sizes are specified\n"
        append msg "                       in percentage.\n"
        if { [poImgType HaveDpiSupport] } {
            append msg "--adjustresolution   : Use in conjunction with option \"--scale\" to adjust the\n"
            append msg "                       physical resolution according to the scale factor.\n"
        }
        append msg "--countcolors        : Find unique colors in image and print count to stdout.\n"
        append msg "                       If verbose mode is on, all unique colors are printed.\n"
        append msg "--palettemap <mode>  : Map loaded images according to specified palette file.\n"
        append msg "                       If <mode> is \"map\", indices are mapped to color images.\n"
        append msg "                       If <mode> is \"inv\", color images are mapped to index images.\n"
        append msg "                       Specify option \"--batch\" to perform in batch mode.\n"
        append msg "--histogram          : Print histogram values to stdout in CSV format.\n"
        append msg "--rawinfo            : Print RAW image information to stdout in CSV format.\n"
        append msg "\n"
        append msg "Available conversion output formats (use --helpimg for more info):\n"
        append msg "  [poImgType GetFmtList]\n"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
    }

    proc StopJob {} {
        variable sPo

        set sPo(stopJob) 1
        focus $sPo(tw)
    }

    proc PrintUsage {} {
        puts [GetUsageMsg]
    }

    proc PrintErrorAndExit { showMsgBox msg } {
        variable sPo

        puts "\nError: $msg"
        PrintUsage
        if { $showMsgBox } {
            tk_messageBox -title "Error" -icon error -message "$msg"
        }
        exit 1
    }

    proc ParseCommandLine { argList } {
        variable ns
        variable sPo
        variable sConv

        set curArg 0
        set fileList  [list]
        set batchList [list]
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "opt" } {
                    incr curArg
                    set sConv(inFmtOpt) [lindex $argList $curArg]
                } elseif { $curOpt eq "convfmt" } {
                    incr curArg
                    set sConv(outFmt) [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "convopt" } {
                    incr curArg
                    set sConv(outFmtOpt) [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "convname" } {
                    incr curArg
                    set sConv(name) [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "convnum" } {
                    incr curArg
                    set sConv(num) [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "convdir" } {
                    incr curArg
                    set sConv(useOutDir) true
                    set sConv(outDir) [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "logo" } {
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                    lappend batchList "ApplyLogo"
                } elseif { $curOpt eq "scale" } {
                    incr curArg
                    set scaleX [lindex $argList $curArg]
                    incr curArg
                    set scaleY [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                    lappend batchList "BatchScale $scaleX $scaleY ; DelImg 0"
                } elseif { $curOpt eq "keepaspect" } {
                    set sPo(optKeepAspect) true
                } elseif { $curOpt eq "adjustresolution" } {
                    if { [poImgType HaveDpiSupport] } {
                        set sPo(optAdjustResolution) true
                    }
                } elseif { $curOpt eq "crop" } {
                    incr curArg
                    set cropX1 [lindex $argList $curArg]
                    incr curArg
                    set cropY1 [lindex $argList $curArg]
                    incr curArg
                    set cropX2 [lindex $argList $curArg]
                    incr curArg
                    set cropY2 [lindex $argList $curArg]
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                    lappend batchList "BatchCrop $cropX1 $cropY1 $cropX2 $cropY2 ; DelImg 0"
                } elseif { $curOpt eq "compose" } {
                    incr curArg
                    set sConv(composeColumns) [lindex $argList $curArg]
                    set sPo(optCompose) true
                    set sPo(optConvert) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "equalsize" } {
                    set sPo(optEqualSizedImgs) true
                } elseif { $curOpt eq "countcolors" } {
                    set sPo(optBatch) true
                    lappend batchList "BatchCount"
                } elseif { $curOpt eq "histogram" } {
                    set sPo(optBatch) true
                    lappend batchList "BatchHistogram"
                } elseif { $curOpt eq "rawinfo" } {
                    set sPo(optRawInfo) true
                    set sPo(optBatch)   true
                } elseif { $curOpt eq "palettefile" } {
                    incr curArg
                    set sPo(optPaletteFile) [lindex $argList $curArg]
                } elseif { $curOpt eq "palettemap" } {
                    incr curArg
                    set sPo(optPaletteMapMode) [lindex $argList $curArg]
                }
            } else {
                lappend fileList $curParam
            }
            incr curArg
        }

        # Check the specified command line parameters.
        if { $sPo(optBatch) } {
            # Do not save settings to file and do not autofit images.
            poApps SetAutosaveOnExit false
            SetZoomParams 0 1.00
            poImgAppearance SetShowRawCurValue false
            poImgAppearance SetShowRawImgInfo  false
            if { [llength $fileList] == 0 } {
                PrintErrorAndExit false "No images specified for batch processing."
            }
            if { $sConv(outFmt) ne "SameAsInput" } {
                if { [lindex [poImgType GetExtList $sConv(outFmt)] 0] eq "" } {
                    PrintErrorAndExit false "Image format \"$sConv(outFmt)\" not supported."
                }
            }
        }

        if { $sPo(optPaletteFile) ne "" } {
            poImgPalette SetPaletteParams \
                [poImgPalette GetChannelNum] \
                [poImgPalette GetUnusedColor] \
                $sPo(optPaletteFile)
        }
        if { $sPo(optPaletteMapMode) ne "" } { 
            set useInversePaletteMap false
            if { $sPo(optPaletteMapMode) eq "inv" } {
                set useInversePaletteMap true
            }
            if { $sPo(optBatch) } {
                lappend batchList "BatchPalette $useInversePaletteMap ; DelImg 0"
            }
        }

        # If arguments are given, try to load the corresponding image files.
        set numImgs 0
        set sConv(counter) $sConv(num)
        if { $sPo(optCompose) } {
            set numImgs [BatchCompose $sConv(composeColumns) $sPo(optEqualSizedImgs) $fileList]
        } elseif { $sPo(optRawInfo) } {
            set numImgs [BatchRawInfo $fileList]
        } else {
            _PushInfoState
            foreach fileOrDirName $fileList {
                if { [file isdirectory $fileOrDirName] } {
                    set curDir [poMisc FileSlashName $fileOrDirName]
                    ::poImgBrowse::OpenDir $curDir
                    poAppearance AddToRecentDirList $curDir
                } else {
                    $sPo(mainCanv) config -cursor watch
                    set fileName [poMisc FileSlashName $fileOrDirName]
                    set imgDict [ReadImg $fileName 1 0]
                    if { $sPo(optPaletteMapMode) ne "" && ! $sPo(optBatch) } { 
                        ShowPaletteImage false $useInversePaletteMap
                    }
                    if { [dict exists $imgDict phImg] } {
                        if { $sPo(optBatch) } {
                            foreach batchCmd $batchList {
                                eval $batchCmd
                            }
                            if { $sPo(optConvert) } {
                                if { ! [Convert] } {
                                    break
                                }
                            }
                            DelImg
                        }
                        incr numImgs
                        update
                    } else {
                        if { $sPo(optBatch) } {
                            puts "Error: Could not read image $fileName"
                        } else {
                            WriteInfoStr "Error: Could not read image $fileName" "Error"
                        }
                    }
                    if { $sPo(stopJob) } {
                        WriteInfoStr "Image loading stopped by user." "Warning"
                        break
                    }
                    $sPo(mainCanv) config -cursor $sPo(curCursor)
                }
            }
            _PopInfoState
            ShowCurrent
            ScanCurDirForImgs
        }
        if { $sPo(optBatch) } {
            if { [poApps GetVerbose] } {
                set imgStr [format "image%s" [poMisc Plural $numImgs]]
                WriteInfoStr "$numImgs $imgStr processed." "Ok"
                puts "$numImgs $imgStr processed."
            }
            exit 0
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poImgview Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
