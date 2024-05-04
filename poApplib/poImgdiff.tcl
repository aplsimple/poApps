# Module:         poImgdiff
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 11 / 29
#
# Distributed under BSD license.
#
# This program can be used to compare two images.
# Images can be loaded with the GUI or by specifying them on the command line.
# Besides comparing the images visually, it offers the possibility to generate
# a difference image and the histograms of the images.
# These operations are available with standard Tcl/Tk, but are very slow for
# images greater than 200 square pixels.
# If using the poImg extension, they are quite fast.
#
# If working with large  images, you can improve speed by avoiding unneccessary expansive operations:
# Use "File info" instead of "Image info".
# Set the mix parameter in the Difference window to zero.
# Set zoom factor to 1, i.e. no zoom.
#
# Image formats available:
#   Tcl/Tk only:        GIF, XPM, PNG (Tk 8.6)
#   With Img extension: JPEG, TIFF, BMP, ...


namespace eval poImgdiff {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin CloseAppWindow
    namespace export ParseCommandLine IsOpen
    namespace export ShowDiffImg ShowDiffImgOnStartup
    namespace export AddImg
    namespace export GetUsageMsg

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poImgdiff" ; # Name of toplevel window
        set sPo(appName) "poImgdiff"  ; # Name of tool
        set sPo(cfgDir)  ""           ; # Directory containing config files

        # Default values for command line options.
        set sPo(optShowDiffOnStartup) false
        set sPo(optThresh)    0
        set sPo(optRawDiff)   false
        set sPo(optUsePoImg)  false
        set sPo(optSaveDiff)  ""
        set sPo(optSaveHisto) ""

        poWatch Start swatch
    }

    proc GetSupportedExtensions {} {
        set extList [list]
        foreach fmt [poImgType GetFmtList] {
            foreach ext [poImgType GetExtList $fmt] {
                lappend extList $ext
            }
        }
        return $extList
    }

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

    proc SetAdjustParams { threshold scale percentage whichImage adjustAlgo } {
        variable sPo

        set sPo(adjustThres)   $threshold
        set sPo(adjustScale)   $scale
        set sPo(adjustPercent) $percentage
        set sPo(curAdjustImg)  $whichImage
        set sPo(curAdjustAlgo) $adjustAlgo
    }

    proc GetAdjustParams {} {
        variable sPo

        return [list $sPo(adjustThres)   \
                     $sPo(adjustScale)   \
                     $sPo(adjustPercent) \
                     $sPo(curAdjustImg)  \
                     $sPo(curAdjustAlgo)]
    }

    proc SetAdjustMarkColor { color } {
        variable sPo

        set sPo(adjustColor) $color
    }

    proc GetAdjustMarkColor {} {
        variable sPo

        return $sPo(adjustColor)
    }

    proc SetRawAdjustParams { thres prec markPixels } {
        variable sPo

        set sPo(diff,raw,threshold) $thres
        set sPo(diff,raw,precision) $prec
        set sPo(diff,raw,mark)      $markPixels
    }

    proc GetRawAdjustParams {} {
        variable sPo

        return [list $sPo(diff,raw,threshold) \
                     $sPo(diff,raw,precision) \
                     $sPo(diff,raw,mark)]
    }

    proc SetCurFiles { curLeftFile curRightFile } {
        variable sPo

        set sPo(left,lastFile)  $curLeftFile
        set sPo(right,lastFile) $curRightFile
    }

    proc GetCurFiles {} {
        variable sPo

        return [list $sPo(left,lastFile) \
                     $sPo(right,lastFile)]
    }

    proc SetZoomParams { autofit zoomValue } {
        variable sPo

        set sPo(zoom,autofit) $autofit
        set sPo(zoomFactor) $zoomValue
    }

    proc GetZoomParams {} {
        variable sPo

        return [list $sPo(zoom,autofit) \
                     $sPo(zoomFactor)]
    }

    proc SetShowImageTab { infoTabNum } {
        variable sPo

        set sPo(showImageTab) $infoTabNum
    }

    proc GetShowImageTab {} {
        variable sPo

        return [list $sPo(showImageTab)]
    }

    proc SetMainWindowSash { sashY } {
        variable sPo

        set sPo(sashY) $sashY
    }

    proc GetMainWindowSash {} {
        variable sPo

        if { [info exists sPo(paneWin)] && \
            [winfo exists $sPo(paneWin)] } {
            set sashY [$sPo(paneWin) sashpos 0]
        } else {
            set sashY $sPo(sashY)
        }
        return [list $sashY]
    }

    proc SetDiffOnStartup { diffOnStartup } {
        variable sPo

        set sPo(diffOnStartup) $diffOnStartup
    }

    proc GetDiffOnStartup {} {
        variable sPo

        return [list $sPo(diffOnStartup)]
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

        set sPo(curPos,x)     "X"
        set sPo(curPos,y)     "Y"
        set sPo(leftCol,r)    "R"
        set sPo(leftCol,g)    "G"
        set sPo(leftCol,b)    "B"
        set sPo(leftCol,a)    "A"
        set sPo(leftCol,raw)  ""
        set sPo(rightCol,r)   "R"
        set sPo(rightCol,g)   "G"
        set sPo(rightCol,b)   "B"
        set sPo(rightCol,a)   "A"
        set sPo(rightCol,raw) ""
    }

    proc PrintPixelValue { canvasId x y printLog } {
        variable sPo

        set px [expr int([$canvasId canvasx $x] / $sPo($canvasId,zoomFactor))]
        set py [expr int([$canvasId canvasy $y] / $sPo($canvasId,zoomFactor))]

        if { [info exists sPo(left,photo)] } {
            set w [image width  $sPo(left,photo)]
            set h [image height $sPo(left,photo)]
            if { $px >= 0 && $py >= 0 && $px < $w && $py < $h } {
                set sPo(curPos,x) $px
                if { [poImgAppearance GetRowOrderCount] eq "TopDown" } {
                    set sPo(curPos,y) $py
                } else {
                    set sPo(curPos,y) [expr {$h - $py - 1}]
                }
                if { [poMisc HaveTcl87OrNewer] } {
                    set retVal [catch {set rgb [$sPo(left,photo) get $px $py -withalpha] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b a
                        set sPo(leftCol,r) [FormatColorVal $r]
                        set sPo(leftCol,g) [FormatColorVal $g]
                        set sPo(leftCol,b) [FormatColorVal $b]
                        set sPo(leftCol,a) [FormatColorVal $a]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(leftCol,hex) configure -background $rgbHex
                        if { [info exists sPo(left,rawDict)] } {
                            set sPo(leftCol,raw) [pawt GetImagePixelAsString sPo(left,rawDict) $px $py $sPo(diff,raw,precision)]
                        }
                    }
                } else {
                    set retVal [catch {set rgb [$sPo(left,photo) get $px $py] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b
                        set sPo(leftCol,r) [FormatColorVal $r]
                        set sPo(leftCol,g) [FormatColorVal $g]
                        set sPo(leftCol,b) [FormatColorVal $b]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(leftCol,hex) configure -background $rgbHex
                        if { [info exists sPo(left,rawDict)] } {
                            set sPo(leftCol,raw) [pawt GetImagePixelAsString sPo(left,rawDict) $px $py $sPo(diff,raw,precision)]
                        }
                    }
                }
            } else {
                ClearPixelValue
            }
        }
        if { [info exists sPo(right,photo)] } {
            set w [image width  $sPo(right,photo)]
            set h [image height $sPo(right,photo)]
            if { $px >= 0 && $py >= 0 && $px < $w && $py < $h } {
                set sPo(curPos,x) $px
                if { [poImgAppearance GetRowOrderCount] eq "TopDown" } {
                    set sPo(curPos,y) $py
                } else {
                    set sPo(curPos,y) [expr {$h - $py - 1}]
                }
                if { [poMisc HaveTcl87OrNewer] } {
                    set retVal [catch {set rgb [$sPo(right,photo) get $px $py -withalpha] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b a
                        set sPo(rightCol,r) [FormatColorVal $r]
                        set sPo(rightCol,g) [FormatColorVal $g]
                        set sPo(rightCol,b) [FormatColorVal $b]
                        set sPo(rightCol,a) [FormatColorVal $a]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(rightCol,hex) configure -background $rgbHex
                        if { [info exists sPo(right,rawDict)] } {
                            set sPo(rightCol,raw) [pawt GetImagePixelAsString sPo(right,rawDict) $px $py $sPo(diff,raw,precision)]
                        }
                    }
                } else {
                    set retVal [catch {set rgb [$sPo(right,photo) get $px $py] }]
                    if { $retVal == 0 } {
                        lassign $rgb r g b
                        set sPo(rightCol,r) [FormatColorVal $r]
                        set sPo(rightCol,g) [FormatColorVal $g]
                        set sPo(rightCol,b) [FormatColorVal $b]
                        set rgbHex [format "#%02X%02X%02X" $r $g $b]
                        $sPo(rightCol,hex) configure -background $rgbHex
                        if { [info exists sPo(right,rawDict)] } {
                            set sPo(rightCol,raw) [pawt GetImagePixelAsString sPo(right,rawDict) $px $py $sPo(diff,raw,precision)]
                        }
                    }
                }
            } else {
                ClearPixelValue
            }
        }
        if { $printLog } {
            if { [poLog GetShowConsole] } {
                if { [poMisc HaveTcl87OrNewer] } {
                    puts "$sPo(curPos,x) $sPo(curPos,y): \
                          $sPo(leftCol,r) $sPo(leftCol,g) $sPo(leftCol,b) $sPo(leftCol,a) \
                          $sPo(rightCol,r) $sPo(rightCol,g) $sPo(rightCol,b) $sPo(rightCol,a)"
                } else {
                    puts "$sPo(curPos,x) $sPo(curPos,y): \
                          $sPo(leftCol,r) $sPo(leftCol,g) $sPo(leftCol,b) \
                          $sPo(rightCol,r) $sPo(rightCol,g) $sPo(rightCol,b)"
                }
            }
        }
    }

    proc ClearDiffPixelValue {} {
        variable sPo

        set sPo(curPos,x)  ""
        set sPo(curPos,y)  ""
        set sPo(diffCol,r) ""
        set sPo(diffCol,g) ""
        set sPo(diffCol,b) ""
    }

    proc PrintDiffPixelValue { canvasId photoId x y printLog } {
        variable sPo

        set px [expr int([$canvasId canvasx $x] / $sPo($canvasId,zoomFactor))]
        set py [expr int([$canvasId canvasy $y] / $sPo($canvasId,zoomFactor))]

        set w [image width  $photoId]
        set h [image height $photoId]

        if { $px >= 0 && $py >= 0 && $px < $w && $py < $h } {
            set sPo(curPos,x) $px
            if { [poImgAppearance GetRowOrderCount] eq "TopDown" } {
                set sPo(curPos,y) $py
            } else {
                set sPo(curPos,y) [expr {$h - $py - 1}]
            }

            set retVal [catch {set rgb [$photoId get $px $py] }]
            if { $retVal == 0 } {
                lassign $rgb r g b
                set sPo(diffCol,r) [FormatColorVal $r]
                set sPo(diffCol,g) [FormatColorVal $g]
                set sPo(diffCol,b) [FormatColorVal $b]
                set rgbHex [format "#%02X%02X%02X" $r $g $b]
                $sPo(diffCol,hex) configure -background $rgbHex
                PrintPixelValue $sPo(left) $x $y $printLog
            }
        } else {
            ClearDiffPixelValue
        }
    }

    proc GetComboValue { comboId side } {
        set curVal [poWinSelect GetValue $comboId]
        if { [file isfile $curVal] } {
            ReadImg $curVal $side
        }
    }

    proc SwitchImageTab {} {
        variable sPo

        set sPo(showImageTab) [expr ! $sPo(showImageTab)]
        ToggleImageTab
    }

    proc ToggleImageTab {} {
        variable sPo

        $sPo(infoPaneL) select [expr ! $sPo(showImageTab)]
        $sPo(infoPaneR) select [expr ! $sPo(showImageTab)]
    }

    proc UpdateInfoWidget { side } {
        variable sPo

        if { [info exists sPo($side,photo)] } {
            if { [info exists sPo($side,rawDict)] } {
                poWinInfo UpdateImgInfo $sPo($side,ImgFrame) $sPo($side,name) $sPo($side,photo) "" $sPo($side,rawDict)
            } else {
                poWinInfo UpdateImgInfo $sPo($side,ImgFrame) $sPo($side,name) $sPo($side,photo)
            }
            poWinInfo UpdateFileInfo $sPo($side,FileFrame) $sPo($side,name)
        }
    }

    proc ToggleZoomRect {} {
        variable sPo

        if { $sPo(zoomRectExists) } {
            poZoomRect NewZoomRect "ZoomRect2" 0 0 \
                       $sPo(left) $sPo(left,photo) \
                       $sPo(right) $sPo(right,photo)
        } else {
            poZoomRect DeleteZoomRect "ZoomRect2" $sPo(left) $sPo(right)
        }
    }

    proc SwitchZoomRect {} {
        variable sPo

        set sPo(zoomRectExists) [expr ! $sPo(zoomRectExists)]
        ToggleZoomRect
    }

    proc SwitchAutofit {} {
        variable sPo

        set sPo(zoom,autofit) [expr ! $sPo(zoom,autofit)]
        Zoom2
    }

    proc SwitchDiffAutofit { winType photoId canvasId } {
        variable sPo

        set sPo($canvasId,autofit) [expr ! $sPo($canvasId,autofit)]
        ZoomDiff $winType $photoId $canvasId
    }

    proc SwitchFiles {} {
        variable sPo

        set leftFile  $sPo(left,name)
        set rightFile $sPo(right,name)

        set leftVal  [poWinSelect GetValue $sPo(left,fileCombo)]
        set rightVal [poWinSelect GetValue $sPo(right,fileCombo)]

        if { $rightFile ne "" } {
            ReadImg $rightFile left
        } else {
            poWinSelect SetValue $sPo(left,fileCombo) $rightVal
        }
        if { $leftFile ne "" } {
            ReadImg $leftFile right
        } else {
            poWinSelect SetValue $sPo(right,fileCombo) $leftVal
        }
    }

    proc StartAppImgBrowse {} {
        variable sPo

        set argList [list]
        set leftFile $sPo(left,name)
        if { [poMisc IsReadableFile $leftFile] } {
            lappend argList [file dirname $leftFile]
        }
        poApps StartApp poImgBrowse $argList
    }

    proc StartAppImgview {} {
        variable sPo

        set argList [list]
        set leftFile  $sPo(left,name)
        set rightFile $sPo(right,name)
        if { [poMisc IsReadableFile $leftFile] } {
            lappend argList $leftFile
        }
        if { [poMisc IsReadableFile $rightFile] } {
            lappend argList $rightFile
        }
        poApps StartApp poImgview $argList
    }

    proc StartAppDiff {} {
        variable sPo

        set argList [list]
        set leftFile  $sPo(left,name)
        set rightFile $sPo(right,name)
        if { [poMisc IsReadableFile $leftFile] } {
            lappend argList [file dirname $leftFile]
        }
        if { [poMisc IsReadableFile $rightFile] } {
            lappend argList [file dirname $rightFile]
        }
        poApps StartApp poDiff $argList
    }

    proc UpdateMainTitle { msg } {
        variable sPo

        wm title $sPo(tw) [format "poApps - %s %s" [poApps GetAppDescription $sPo(appName)] $msg]
    }

   proc ToggleRowOrder { w } {
        poImgAppearance ToggleRowOrderCount
        $w configure -image [poImgAppearance GetRowOrderCountBitmap]
        poToolhelp AddBinding $w "Row order count: [poImgAppearance GetRowOrderCount]"
    }

    proc ShowMainWin {} {
        variable sPo
        variable ns

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        # Create the windows title.
        UpdateMainTitle ""
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create frame containing gridded frames for Tool, Work and Info area.
        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both

        # Create 5 frames: The menu frame on top, category and search frame inside
        # temporary frame and the search result frame.
        ttk::frame $sPo(tw).fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).fr.pixfr
        ttk::frame $sPo(tw).fr.filefr
        ttk::frame $sPo(tw).fr.workfr
        ttk::frame $sPo(tw).fr.statfr -borderwidth 1

        grid $sPo(tw).fr.toolfr -row 0 -column 0 -sticky news
        grid $sPo(tw).fr.pixfr  -row 1 -column 0 -sticky news
        grid $sPo(tw).fr.filefr -row 2 -column 0 -sticky news
        grid $sPo(tw).fr.workfr -row 3 -column 0 -sticky news
        grid $sPo(tw).fr.statfr -row 4 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).fr 3 -weight 1
        grid columnconfigure $sPo(tw).fr 0 -weight 1

        ttk::frame $sPo(tw).fr.workfr.fr
        pack $sPo(tw).fr.workfr.fr -expand 1 -fill both

        set sPo(paneWin) $sPo(tw).fr.workfr.fr.pane
        ttk::panedwindow $sPo(paneWin) -orient vertical
        pack $sPo(paneWin) -side top -expand 1 -fill both

        set imgfr  $sPo(paneWin).imgfr
        set infofr $sPo(paneWin).infofr
        ttk::frame $imgfr  -relief sunken -borderwidth 1
        ttk::frame $infofr -relief sunken -borderwidth 1
        pack $imgfr  -expand 1 -fill both
        pack $infofr -expand 1 -fill both

        $sPo(paneWin) add $imgfr
        $sPo(paneWin) add $infofr

        ttk::frame $infofr.leftfr
        ttk::frame $infofr.rightfr
        grid $infofr.leftfr  -row 0 -column 0 -sticky news -ipadx 2
        grid $infofr.rightfr -row 0 -column 1 -sticky news -ipadx 2
        grid rowconfigure    $infofr 0 -weight 1
        grid columnconfigure $infofr 0 -weight 1 -uniform TwoCols
        grid columnconfigure $infofr 1 -weight 1 -uniform TwoCols

        ttk::frame $sPo(tw).fr.filefr.left
        ttk::frame $sPo(tw).fr.filefr.right
        pack $sPo(tw).fr.filefr.left $sPo(tw).fr.filefr.right -side left -expand 1 -fill x

        # Create menus File, View and Help
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
        set settMenu $hMenu.sett
        set winMenu  $hMenu.win
        set helpMenu $hMenu.help
        $hMenu add cascade -menu $fileMenu -label File     -underline 0
        $hMenu add cascade -menu $editMenu -label Edit     -underline 0
        $hMenu add cascade -menu $viewMenu -label View     -underline 0
        $hMenu add cascade -menu $settMenu -label Settings -underline 0
        $hMenu add cascade -menu $winMenu  -label Window   -underline 0
        $hMenu add cascade -menu $helpMenu -label Help     -underline 0

        # Menu File
        set lopenMenu  $fileMenu.lopen
        set ropenMenu  $fileMenu.ropen
        set saveMenu   $fileMenu.save
        set sPo(lopenMenu) $lopenMenu
        set sPo(ropenMenu) $ropenMenu

        menu $fileMenu -tearoff 0
        $fileMenu add cascade -label "Open left"  -menu $fileMenu.lopen
        $fileMenu add cascade -label "Open right" -menu $fileMenu.ropen
        $fileMenu add cascade -label "Save" -menu $fileMenu.save

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }

        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        menu $lopenMenu -tearoff 0 -postcommand "${ns}::AddRecentFiles $lopenMenu left"
        poMenu AddCommand $lopenMenu "Open ..."  "Ctrl+L" ${ns}::OpenLeftImgFile
        $lopenMenu add separator
        bind $sPo(tw) <Control-l>  ${ns}::OpenLeftImgFile

        menu $ropenMenu -tearoff 0 -postcommand "${ns}::AddRecentFiles $ropenMenu right"
        poMenu AddCommand $ropenMenu "Open ..." "Ctrl+R" ${ns}::OpenRightImgFile
        $ropenMenu add separator
        bind $sPo(tw) <Control-r>  ${ns}::OpenRightImgFile

        menu $saveMenu -tearoff 0
        poMenu AddCommand $saveMenu "left ..."  "Shift+L" ${ns}::SaveLeftImg
        poMenu AddCommand $saveMenu "right ..." "Shift+R" ${ns}::SaveRightImg
        bind $sPo(tw) <L>  ${ns}::SaveLeftImg
        bind $sPo(tw) <R>  ${ns}::SaveRightImg

        # Menu Edit
        menu $editMenu -tearoff 0
        poMenu AddCommand $editMenu "Clear left"   ""  ${ns}::ClearLeft
        poMenu AddCommand $editMenu "Clear right"  ""  ${ns}::ClearRight

        # Menu View
        set zoomMenu  $viewMenu.zoom
        set histoMenu $viewMenu.histo

        menu $viewMenu -tearoff 0
        $viewMenu add cascade -label "Zoom" -menu $viewMenu.zoom

        poMenu AddCheck $viewMenu "Autofit" "Ctrl+M" ${ns}::sPo(zoom,autofit) ${ns}::Zoom2
        $viewMenu add cascade -label "Histogram" -menu $viewMenu.histo

        poMenu AddCommand $viewMenu "Difference image"     "Ctrl+D" ${ns}::ShowDiffImg
        poMenu AddCommand $viewMenu "Difference RAW image" "Ctrl+N" ${ns}::ShowRawDiffImg
        poMenu AddCheck   $viewMenu "Show image tab"       "F9"     ${ns}::sPo(showImageTab) ${ns}::ToggleImageTab
        poMenu AddCheck   $viewMenu "Zoom rectangle"       "Ctrl+Y" ${ns}::sPo(zoomRectExists) "${ns}::ToggleZoomRect"
        bind $sPo(tw) <Control-m> ${ns}::SwitchAutofit
        bind $sPo(tw) <Control-y> ${ns}::SwitchZoomRect
        bind $sPo(tw) <Key-F9>    ${ns}::SwitchImageTab
        bind $sPo(tw) <Control-d> ${ns}::ShowDiffImg
        bind $sPo(tw) <Control-n> ${ns}::ShowRawDiffImg

        menu $zoomMenu -tearoff 0
        poMenu AddRadio $zoomMenu "  5%"  "" ${ns}::sPo(zoomFactor) 0.05 "${ns}::Zoom2 0.05"
        poMenu AddRadio $zoomMenu " 10%"  "" ${ns}::sPo(zoomFactor) 0.10 "${ns}::Zoom2 0.10"
        poMenu AddRadio $zoomMenu " 20%"  "" ${ns}::sPo(zoomFactor) 0.20 "${ns}::Zoom2 0.20"
        poMenu AddRadio $zoomMenu " 25%"  "" ${ns}::sPo(zoomFactor) 0.25 "${ns}::Zoom2 0.25"
        poMenu AddRadio $zoomMenu " 33%"  "" ${ns}::sPo(zoomFactor) 0.33 "${ns}::Zoom2 0.33"
        poMenu AddRadio $zoomMenu " 50%"  "" ${ns}::sPo(zoomFactor) 0.50 "${ns}::Zoom2 0.50"
        poMenu AddRadio $zoomMenu "100%"  "" ${ns}::sPo(zoomFactor) 1.00 "${ns}::Zoom2 1.00"
        poMenu AddRadio $zoomMenu "200%"  "" ${ns}::sPo(zoomFactor) 2.00 "${ns}::Zoom2 2.00"
        poMenu AddRadio $zoomMenu "300%"  "" ${ns}::sPo(zoomFactor) 3.00 "${ns}::Zoom2 3.00"
        poMenu AddRadio $zoomMenu "400%"  "" ${ns}::sPo(zoomFactor) 4.00 "${ns}::Zoom2 4.00"
        poMenu AddRadio $zoomMenu "500%"  "" ${ns}::sPo(zoomFactor) 5.00 "${ns}::Zoom2 5.00"

        menu $histoMenu -tearoff 0
        poMenu AddCommand $histoMenu "Uniform scaling"     "Shift+H" "${ns}::ShowHistogram lin"
        poMenu AddCommand $histoMenu "Logarithmic scaling" "Ctrl+H"  "${ns}::ShowHistogram log"
        bind $sPo(tw) <H>         "${ns}::ShowHistogram lin"
        bind $sPo(tw) <Control-h> "${ns}::ShowHistogram log"
        bind $sPo(tw) <Key-plus>  "${ns}::ChangeZoom2  1"
        bind $sPo(tw) <Key-minus> "${ns}::ChangeZoom2 -1"

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        $settMenu add cascade -label "Application settings" -menu $appSettMenu
        menu $appSettMenu -tearoff 0
        poMenu AddCommand $appSettMenu "Compare" "" [list ${ns}::ShowSpecificSettWin "Compare"]

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

        $settMenu add separator
        poMenu AddCheck   $settMenu "Save on exit"       "" poApps::gPo(autosaveOnExit) ""
        poMenu AddCommand $settMenu "View setting files" "" "poApps ViewSettingsDir"
        poMenu AddCommand $settMenu "Save settings"      "" "poApps SaveSettings"

        # Menu Window
        menu $winMenu -tearoff 0
        poMenu AddCommand $winMenu [poApps GetAppDescription main]        "" "poApps StartApp main"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgview]   "" ${ns}::StartAppImgview
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgBrowse] "" ${ns}::StartAppImgBrowse
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" "poApps StartApp poBitmap"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgdiff]   "" "poApps StartApp poImgdiff" -state disabled
        poMenu AddCommand $winMenu [poApps GetAppDescription poDiff]      "" ${ns}::StartAppDiff
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poPresMgr]   "" "poApps StartApp poPresMgr"
        poMenu AddCommand $winMenu [poApps GetAppDescription poOffice]    "" "poApps StartApp poOffice"

        # Menu help
        menu $helpMenu -tearoff 0
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $helpMenu "Help ..." "F1" ${ns}::HelpCont
            bind $sPo(tw) <Key-F1>  ${ns}::HelpCont
            poMenu AddCommand $helpMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $helpMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $helpMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        $sPo(tw) configure -menu $hMenu
        set canvasList [poWin CreateSyncCanvas $imgfr \
                        "" "" -borderwidth 0 -highlightthickness 0 -selectborderwidth 0]
        set sPo(left)  [lindex $canvasList 0]
        set sPo(right) [lindex $canvasList 1]
        # Get the system default canvas background color as reset value.
        # Set the canvas background color to the stored value.
        poImgAppearance SetCanvasResetColor [$sPo(left) cget -background]
        $sPo(left)  configure -background [poImgAppearance GetCanvasBackgroundColor]
        $sPo(right) configure -background [poImgAppearance GetCanvasBackgroundColor]

        $sPo(left)  create image 0 0 -anchor nw -tags $sPo(left)
        $sPo(right) create image 0 0 -anchor nw -tags $sPo(right)

        set sPo($sPo(left),zoomFactor)  1.00
        set sPo($sPo(right),zoomFactor) 1.00

        # Create Drag-And-Drop binding for the 2 image canvases.
        poDragAndDrop AddCanvasBinding $sPo(left)  ${ns}::ReadImgByDrop
        poDragAndDrop AddCanvasBinding $sPo(right) ${ns}::ReadImgByDrop

        # Create image and file info tabs for left and right files.
        set sPo(infoPaneL) $infofr.leftfr.nb
        ttk::notebook $sPo(infoPaneL) -style Hori.TNotebook
        pack $sPo(infoPaneL) -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $sPo(infoPaneL)

        set imgfrL  $sPo(infoPaneL).imgfr
        set filefrL $sPo(infoPaneL).filefr
        ttk::frame $imgfrL
        ttk::frame $filefrL
        pack  $imgfrL  -expand 0 -fill both
        pack  $filefrL -expand 0 -fill both

        $sPo(infoPaneL) add $imgfrL  -text "Image Info"
        $sPo(infoPaneL) add $filefrL -text "File Info"

        set sPo(infoPaneR) $infofr.rightfr.nb
        ttk::notebook $sPo(infoPaneR) -style Hori.TNotebook
        pack $sPo(infoPaneR) -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $sPo(infoPaneR)

        set imgfrR  $sPo(infoPaneR).imgfr
        set filefrR $sPo(infoPaneR).filefr
        ttk::frame $imgfrR
        ttk::frame $filefrR 
        pack  $imgfrR  -expand 0 -fill both
        pack  $filefrR -expand 0 -fill both

        $sPo(infoPaneR) add $imgfrR  -text "Image Info"
        $sPo(infoPaneR) add $filefrR -text "File Info"

        set sPo(left,ImgFrame)  [poWinInfo Create $imgfrL ""]
        set sPo(right,ImgFrame) [poWinInfo Create $imgfrR ""]

        set sPo(left,FileFrame)  [poWinInfo Create $filefrL ""]
        set sPo(right,FileFrame) [poWinInfo Create $filefrR ""]

        # Create Drag-And-Drop bindings for the info panes.
        poDragAndDrop AddTtkBinding $sPo(infoPaneL) ${ns}::ReadImgByDrop
        poDragAndDrop AddTtkBinding $sPo(infoPaneR) ${ns}::ReadImgByDrop

        set sPo(left,fileCombo) [poWinSelect CreateFileSelect $sPo(tw).fr.filefr.left \
                               $sPo(left,lastFile) "open" ""]
        poWinSelect SetFileTypes $sPo(left,fileCombo) [poImgType GetSelBoxTypes]
        bind $sPo(left,fileCombo) <Key-Return> \
             "${ns}::GetComboValue $sPo(left,fileCombo) left"
        bind $sPo(left,fileCombo) <<FileSelected>> \
             "${ns}::GetComboValue $sPo(left,fileCombo) left"
        set sPo(right,fileCombo) [poWinSelect CreateFileSelect $sPo(tw).fr.filefr.right \
                                $sPo(right,lastFile) "open" ""]
        poWinSelect SetFileTypes $sPo(right,fileCombo) [poImgType GetSelBoxTypes]
        bind $sPo(right,fileCombo) <Key-Return> \
             "${ns}::GetComboValue $sPo(right,fileCombo) right"
        bind $sPo(right,fileCombo) <<FileSelected>> \
             "${ns}::GetComboValue $sPo(right,fileCombo) right"

        set pixfr $sPo(tw).fr.pixfr
        ttk::frame $pixfr.posFr
        ttk::separator $pixfr.sep1 -orient vertical
        ttk::frame $pixfr.leftFr
        ttk::separator $pixfr.sep2 -orient vertical
        ttk::frame $pixfr.rightFr
        pack $pixfr.posFr -anchor w -side left
        pack $pixfr.sep1 -side left -padx 2 -fill y
        pack $pixfr.leftFr -anchor w -side left
        pack $pixfr.sep2 -side left -padx 2 -fill y
        pack $pixfr.rightFr -anchor w -side left

        ttk::label  $pixfr.posFr.l -text "Position:"
        ttk::label  $pixfr.posFr.ex -textvariable ${ns}::sPo(curPos,x) -width 4 -anchor e
        ttk::label  $pixfr.posFr.ey -textvariable ${ns}::sPo(curPos,y) -width 4 -anchor e
        ttk::button $pixfr.posFr.row -image [poImgAppearance GetRowOrderCountBitmap] \
                    -style Toolbutton -command "${ns}::ToggleRowOrder $pixfr.posFr.row"
        pack $pixfr.posFr.l -anchor w -side left
        pack $pixfr.posFr.ex $pixfr.posFr.ey $pixfr.posFr.row -anchor e -side left

        ClearPixelValue

        set sPo(leftCol,hex) $pixfr.leftFr.c
        ttk::label $pixfr.leftFr.l -text "Left:"
        label $sPo(leftCol,hex) -width 3 -relief sunken
        ttk::label $pixfr.leftFr.er -textvariable ${ns}::sPo(leftCol,r)   -width 3 -anchor e
        ttk::label $pixfr.leftFr.eg -textvariable ${ns}::sPo(leftCol,g)   -width 3 -anchor e
        ttk::label $pixfr.leftFr.eb -textvariable ${ns}::sPo(leftCol,b)   -width 3 -anchor e
        ttk::label $pixfr.leftFr.ew -textvariable ${ns}::sPo(leftCol,raw) -anchor e
        set sPo(leftValWidget) $pixfr.leftFr.ew
        pack $pixfr.leftFr.l $sPo(leftCol,hex) -anchor w -side left
        pack $pixfr.leftFr.er $pixfr.leftFr.eg $pixfr.leftFr.eb -anchor w -side left
        if { [poMisc HaveTcl87OrNewer] } {
            ttk::label $pixfr.leftFr.ea -textvariable ${ns}::sPo(leftCol,a) -width 3 -anchor e
            pack $pixfr.leftFr.ea -anchor w -side left
        }
        pack $pixfr.leftFr.ew -anchor w -side left

        set sPo(rightCol,hex) $pixfr.rightFr.c
        ttk::label $pixfr.rightFr.l -text "Right:"
        label $sPo(rightCol,hex) -width 3 -relief sunken
        ttk::label $pixfr.rightFr.er -textvariable ${ns}::sPo(rightCol,r)   -width 3 -anchor e
        ttk::label $pixfr.rightFr.eg -textvariable ${ns}::sPo(rightCol,g)   -width 3 -anchor e
        ttk::label $pixfr.rightFr.eb -textvariable ${ns}::sPo(rightCol,b)   -width 3 -anchor e
        ttk::label $pixfr.rightFr.ew -textvariable ${ns}::sPo(rightCol,raw) -anchor e
        set sPo(rightValWidget) $pixfr.rightFr.ew
        pack $pixfr.rightFr.l $sPo(rightCol,hex) -anchor w -side left
        pack $pixfr.rightFr.er $pixfr.rightFr.eg $pixfr.rightFr.eb -anchor w -side left
        if { [poMisc HaveTcl87OrNewer] } {
            ttk::label $pixfr.rightFr.ea -textvariable ${ns}::sPo(rightCol,a) -width 3 -anchor e
            pack $pixfr.rightFr.ea -anchor w -side left
        }
        pack $pixfr.rightFr.ew -anchor w -side left

        ConfigureRawValWidgets

        $sPo(left)  bind $sPo(left)  <Motion>   "${ns}::PrintPixelValue $sPo(left)  %x %y false"
        $sPo(right) bind $sPo(right) <Motion>   "${ns}::PrintPixelValue $sPo(right) %x %y false"
        $sPo(left)  bind $sPo(left)  <Button-1> "${ns}::PrintPixelValue $sPo(left)  %x %y true"
        $sPo(right) bind $sPo(right) <Button-1> "${ns}::PrintPixelValue $sPo(right) %x %y true"
        $sPo(left)  bind $sPo(left)  <Leave>    "${ns}::ClearPixelValue"
        $sPo(right) bind $sPo(right) <Leave>    "${ns}::ClearPixelValue"
        bind $sPo(left)  <Double-1> "${ns}::OpenLeftImgFile"
        bind $sPo(right) <Double-1> "${ns}::OpenRightImgFile"

        bind $sPo(tw) <Control-t> "${ns}::SwitchFiles"

        # Add new toolbar group and associated buttons.
        set toolfr $sPo(tw).fr.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::openleft] \
                  ${ns}::OpenLeftImgFile "Open left image file ... (Ctrl+L)"
        poToolbar AddButton $toolfr [::poBmpData::openright] \
                  ${ns}::OpenRightImgFile "Open right image file ... (Ctrl+R)"

        poToolbar AddButton $toolfr [::poBmpData::switch] \
                  "${ns}::SwitchFiles" "Switch files (Ctrl+T)"

        poToolbar AddButton $toolfr [::poBmpData::saveleft] \
                  ${ns}::SaveLeftImg "Save left image to file ... (Shift+L)"
        poToolbar AddButton $toolfr [::poBmpData::saveright] \
                  ${ns}::SaveRightImg "Save right image to file ... (Shift+R)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::clearleft] \
                  "${ns}::ClearLeft" "Clear left image"
        poToolbar AddButton $toolfr [::poBmpData::clearright] \
                  "${ns}::ClearRight" "Clear right image"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::autofit] \
                  ${ns}::Zoom2 "Toggle image autofit (Ctrl+M)" \
                  -variable ${ns}::sPo(zoom,autofit)

        poToolbar AddButton $toolfr [::poBmpData::histolog] \
                  "${ns}::ShowHistogram log" "Show logarithmic histogram (Ctrl+H)"
        poToolbar AddButton $toolfr [::poBmpData::histo] \
                  "${ns}::ShowHistogram lin" "Show linear histogram (Shift+H)"
        poToolbar AddButton $toolfr [::poBmpData::diff] ${ns}::ShowDiffImg \
                  "Show difference image (Ctrl+D)"
        poToolbar AddCheckButton $toolfr [::poBmpData::infofile] \
                  "${ns}::ToggleImageTab" "Show image tab (F9)" \
                  -variable ${ns}::sPo(showImageTab)

        # Create widget for status messages.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).fr.statfr]

        WriteInfoStr $sPo(initStr) $sPo(initType)

        poWinSelect SetValue $sPo(left,fileCombo)  $sPo(left,lastFile)
        poWinSelect SetValue $sPo(right,fileCombo) $sPo(right,lastFile)
        $sPo(left)  config -cursor crosshair
        $sPo(right) config -cursor crosshair

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        if { ! [poApps GetHideWindow] } {
            update
        }
        $sPo(paneWin) pane $imgfr  -weight 1
        $sPo(paneWin) pane $infofr -weight 0
        $sPo(paneWin) sashpos 0 $sPo(sashY)
        ConfigCanvas $sPo(left)
        ConfigCanvas $sPo(right)

        ToggleImageTab

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
    }

    proc SelectAdjustMarkColor { labelId } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(adjustColor)]
        if { $newColor ne "" } {
            set sPo(adjustColor) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc ShowCompareTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Mode:" \
                           "Difference mark color:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList {}
        # Generate right column with entries and buttons.
        # Part 1: Mode switches
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Show difference on startup" \
                                   -variable ${ns}::sPo(diffOnStartup)
        pack $tw.fr$row.cb1 -side top -anchor w

        set tmpList [list [list sPo(diffOnStartup)] [list $sPo(diffOnStartup)]]
        lappend varList $tmpList

        # Color of difference image adjust mark.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(adjustColor)
        ttk::button $tw.fr$row.b -text "Select ..." \
                            -command "${ns}::SelectAdjustMarkColor $tw.fr$row.l"
        poToolhelp AddBinding $tw.fr$row.b "Select new difference adjust color"
        pack {*}[winfo children $tw.fr$row] -side left -anchor w -expand 1 -fill both
        set tmpList [list [list sPo(adjustColor)] [list $sPo(adjustColor)]]
        lappend varList $tmpList

        return $varList
    }

    proc ShowSpecificSettWin { { selectTab "Compare" } } {
        variable sPo
        variable ns

        set tw .poImgdiff_specWin
        set sPo(specWin,name) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Image diff specific settings"
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

        ttk::frame $nb.compareFr
        set tmpList [ShowCompareTab $nb.compareFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.compareFr -text "Compare" -underline 0 -padding 2
        if { $selectTab eq "Compare" } {
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

        $sPo(left)  configure -background [poImgAppearance GetCanvasBackgroundColor]
        $sPo(right) configure -background [poImgAppearance GetCanvasBackgroundColor]
    }

    proc AddRecentFiles { menuId side } {
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentFileList $menuId ${ns}::ReadImg $side -extensions [GetSupportedExtensions]
    }

    proc ConfigCanvas { canvasId { photoId "" } } {
        variable sPo

        set sw [winfo width  $sPo(paneWin).imgfr]
        set sh [winfo height $sPo(paneWin).imgfr]
        set sw [expr {$sw / 2}]
        $canvasId configure -width $sw -height $sh
        if { $photoId ne "" } {
            set iw [image width  $photoId]
            set ih [image height $photoId]
            $canvasId configure -scrollregion "0 0 $iw $ih"
        }
    }

    proc GetAutofitZoomFactor { imgWidth imgHeight maxWidth maxHeight } {
        set xzoom [expr {double ($maxWidth) / $imgWidth}]
        set yzoom [expr {double ($maxHeight) / $imgHeight}]
        set zoomFactor [poMisc Min $xzoom $yzoom]
        if { $zoomFactor >= 1.0 } {
            set zoomValue [format "%.2f" [expr {int ($zoomFactor)}]]
        } else {
            set zoomFactor [expr {int (1.0 / $zoomFactor) + 1}]
            set zoomValue [format "%.2f" [expr {1.0 / $zoomFactor}]]
        }
        return $zoomValue
    }

    proc CalcAutofitZoomFactor { phImg widget } {
        set sw [winfo width  $widget]
        set sh [winfo height $widget]
        set sw [expr {$sw / 2}]
        set w [image width  $phImg]
        set h [image height $phImg]
        return [GetAutofitZoomFactor $w $h $sw $sh]
    }

    proc Zoom { phImg canvasId zoomValue } {
        variable sPo

        if { [info exists sPo($canvasId,autofit)] && $sPo($canvasId,autofit) } {
            set zoomValue [CalcAutofitZoomFactor $phImg $sPo(paneWin).imgfr]
        }

        set sPo($canvasId,zoomFactor) $zoomValue

        set zoomLeftStr  [format "%d%%" [expr {int ($sPo($sPo(left),zoomFactor) * 100.0)}]]
        set zoomRightStr [format "%d%%" [expr {int ($sPo($sPo(right),zoomFactor) * 100.0)}]]
        UpdateMainTitle " Zoom: $zoomLeftStr $zoomRightStr"

        if { $zoomValue == 1.0 } {
            $canvasId itemconfigure $canvasId -image $phImg
            ConfigCanvas $canvasId $phImg
        } else {
            set w [expr int ([image width  $phImg] * $zoomValue)]
            set h [expr int ([image height $phImg] * $zoomValue)]
            if { $zoomValue < 1.0 } {
                set sc [expr int (1.0 / $zoomValue)]
                set cmd "-subsample"
            } elseif { $zoomValue > 1.0 } {
                set sc [expr int($zoomValue)]
                set cmd "-zoom"
            }
            if { [info exists sPo($canvasId,zoom)] } {
                image delete $sPo($canvasId,zoom)
            }
            set newPhoto [image create photo -width $w -height $h]
            $newPhoto copy $phImg $cmd $sc $sc
            $canvasId itemconfigure $canvasId -image $newPhoto
            ConfigCanvas $canvasId $newPhoto
            set sPo($canvasId,zoom) $newPhoto
        }
        poZoomRect ChangeZoom $canvasId "ZoomRect2" $zoomValue
    }

    proc ZoomDiff { winType phImg canvasId { zoomValue 1.00 } } {
        variable sPo

        Zoom $phImg $canvasId $zoomValue
        set zoomStr [format "%d%%" [expr {int ($sPo($canvasId,zoomFactor) * 100.0)}]]
        wm title $sPo($winType,name) "$sPo($winType,title) Zoom: $zoomStr"
    }

    proc ChangeZoomDiff { winType phImg canvId dir } {
        variable sPo

        set zoomList $sPo(zoomList)
        set curZoomInd [lsearch -exact $zoomList $sPo($canvId,zoomFactor)]
        if { $curZoomInd < 0 } {
            set sPo($canvId,zoomFactor) 1.00
        } else {
            incr curZoomInd $dir
            if { $curZoomInd < 0 } {
                set curZoomInd 0
            } elseif { $curZoomInd >= [llength $zoomList] } {
                set curZoomInd  [expr [llength $zoomList] -1]
            }
            set sPo($canvId,zoomFactor) [lindex $zoomList $curZoomInd]
        }
        ZoomDiff $winType $phImg $canvId $sPo($canvId,zoomFactor)
    }

    proc ChangeZoom2 { dir } {
        variable sPo

        if { $sPo(zoom,autofit) } {
            return
        }
        set zoomList $sPo(zoomList)
        set curZoomInd [lsearch -exact $zoomList $sPo(zoomFactor)]
        if { $curZoomInd < 0 } {
            set sPo(zoomFactor) 1.00
        } else {
            incr curZoomInd $dir
            if { $curZoomInd < 0 } {
                set curZoomInd 0
            } elseif { $curZoomInd >= [llength $zoomList] } {
                set curZoomInd  [expr [llength $zoomList] -1]
            }
            set sPo(zoomFactor) [lindex $zoomList $curZoomInd]
        }
        Zoom2 $sPo(zoomFactor)
    }

    proc Zoom2 { { zoomValue 1.00 } } {
        variable sPo

        set sPo(zoomFactor) $zoomValue
        foreach side { "left" "right" } {
            if { [info exists sPo($side,photo)] } {
                set sPo($sPo($side),autofit) $sPo(zoom,autofit)
                Zoom $sPo($side,photo) $sPo($side) $zoomValue
            }
        }
    }

    proc GetFileName { title side { mode "open" } { initFile "" } } {
        variable ns
        variable sPo

        set imgFormat ""
        if { [poImgAppearance GetUseLastImgFmt] } {
            set imgFormat [poImgAppearance GetLastImgFmtUsed] } {
        }
        set fileTypes [poImgType GetSelBoxTypes $imgFormat]
        if { $mode eq "open" } {
            set fileName [tk_getOpenFile -filetypes $fileTypes \
                         -initialdir [file dirname $sPo($side,lastFile)] -title $title]
        } else {
            if { ! [info exists sPo(LastImgType)] } {
                set sPo(LastImgType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastImgType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }

            set fileName [tk_getSaveFile \
                         -filetypes $fileTypes \
                         -title $title \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastImgType) \
                         -initialfile [file tail $initFile] \
                         -initialdir [file dirname $sPo($side,lastFile)]]
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
            }
        }
        if { $fileName ne "" } {
            poImgAppearance StoreLastImgFmtUsed $fileName
        }
        return $fileName
    }

    proc ShowImg { phImg canvasId } {
        $canvasId itemconfigure $canvasId -image $phImg
        ConfigCanvas $canvasId $phImg
    }

    proc AddImg { phImg poImg imgName side } {
        variable sPo

        set canvasId $sPo($side)
        $canvasId config -cursor watch
        update

        # Remove old poImg or photo images.
        ClearImg $side

        poWatch Reset swatch
        if { [poImgAppearance GetShowRawCurValue] || [poImgAppearance GetShowRawImgInfo] } {
            if { [poImgAppearance GetShowRawCurValue] } {
                if { [poType IsImage $imgName "raw"] } {
                    set sPo($side,rawDict) [pawt::raw::ReadImageFile $imgName]
                } elseif { [poType IsImage $imgName "flir"] } {
                    set sPo($side,rawDict) [pawt::flir::ReadImageFile $imgName]
                } elseif { [poType IsImage $imgName "fits"] } {
                    set sPo($side,rawDict) [pawt::fits::ReadImageFile $imgName]
                } elseif { [poType IsImage $imgName "ppm"] } {
                    set sPo($side,rawDict) [pawt::ppm::ReadImageFile $imgName]
                }
            }
            if { [poImgAppearance GetShowRawImgInfo] } {
                catch { pawt GetImageMinMax     sPo($side,rawDict) }
                catch { pawt GetImageMeanStdDev sPo($side,rawDict) }
            }
        }

        ShowImg $phImg $canvasId

        set sPo($side,photo) $phImg
        if { $poImg ne "" } {
            set sPo($side,poImg) $poImg
        }

        if { [file exists $imgName] } {
            set sPo($canvasId,haveRealFile) true
        } else {
            set sPo($canvasId,haveRealFile) false
        }
        set sPo($side,name) $imgName
        poWinSelect SetValue $sPo($side,fileCombo) $sPo($side,name)

        Zoom2 $sPo(zoomFactor)

        if { $sPo($canvasId,haveRealFile) } {
            set curFile [poMisc FileSlashName $imgName]
            poAppearance AddToRecentFileList $curFile
            poImgAppearance StoreLastImgFmtUsed $imgName
            set sPo($side,lastFile) $curFile
        }

        UpdateInfoWidget $side

        poLog Info [format "%.2f sec: Display image" [poWatch Lookup swatch]]
        $canvasId config -cursor crosshair
        update
    }

    proc ReadImg { imgName side } {
        set retVal [catch {poImgMisc LoadImg $imgName} imgDict]
        if { $retVal == 0 } {
            # We suceeded in reading an image from file.
            set phImg [dict get $imgDict phImg]
            set poImg [dict get $imgDict poImg]
            AddImg $phImg $poImg $imgName $side
        } else {
            tk_messageBox -message "Could not read image from file $imgName ($imgDict)" \
                          -title "Warning" -type ok -icon warning
        }
        WriteInfoStr "Loaded image [poAppearance CutFilePath $imgName]" "Ok"
    }

    proc ReadImgByDrop { canvasId fileList } {
        variable sPo

        if { $canvasId eq $sPo(left) || $canvasId eq $sPo(infoPaneL) } {
            set side left
        } else {
            set side right
        }
        foreach f $fileList {
            if { [file isfile $f] } {
                ReadImg $f $side
                break
            }
        }
    }

    proc SaveLeftImg {} {
        variable sPo

        if { ! [info exists sPo(left,photo)] } {
            return
        }
        set defName [file tail $sPo(left,name)]
        set imgName [GetFileName "Save left image as" left "save" $defName]
        if { $imgName ne "" } {
            SaveImg . $sPo(left,photo) $imgName
        }
        focus $sPo(tw)
    }

    proc SaveRightImg {} {
        variable sPo

        if { ! [info exists sPo(right,photo)] } {
            return
        }
        set defName [file tail $sPo(right,name)]
        set imgName [GetFileName "Save right image as" right "save" $defName]
        if { $imgName ne "" } {
            SaveImg . $sPo(right,photo) $imgName
        }
        focus $sPo(tw)
    }

    proc SaveDiffImg { tw photoId } {
        variable sPo

        set defLeftName  [file tail $sPo(left,name)]
        set defRightName [file tail $sPo(right,name)]
        set defName [format "%s_%s" [file rootname $defLeftName] $defRightName]
        set imgName [GetFileName "Save difference image as" left "save" $defName]
        if { $imgName ne "" } {
            SaveImg $tw $photoId $imgName
        }
        focus $tw
    }

    proc OpenLeftImgFile {} {
        variable sPo

        set imgName [GetFileName "Open left image" left]
        if { $imgName ne "" } {
            ReadImg $imgName left
        }
        focus $sPo(tw)
    }

    proc OpenRightImgFile {} {
        variable sPo

        set imgName [GetFileName "Open right image" right]
        if { $imgName ne "" } {
            ReadImg $imgName right
        }
        focus $sPo(tw)
    }

    proc ClearImg { side } {
        variable sPo

        set canvId $sPo($side)
        if { [info exists sPo($side,photo)] } {
            poWinInfo Clear $sPo($side,ImgFrame)
            poWinInfo Clear $sPo($side,FileFrame)
            image delete $sPo($side,photo)
            unset sPo($side,photo)
        }
        if { [info exists sPo($canvId,zoom)] } {
            image delete $sPo($canvId,zoom)
            unset sPo($canvId,zoom)
        }
        if { [info exists sPo($side,poImg)] } {
            poImgUtil DeleteImg $sPo($side,poImg)
            unset sPo($side,poImg)
        }
        if { [info exists sPo($side,rawDict)] } {
            unset sPo($side,rawDict)
        }
        set sPo($side,name) ""
    }

    proc ClearLeft {} {
        ClearImg "left"
    }

    proc ClearRight {} {
        ClearImg "right"
    }

    proc SaveImg { tw photoId imgName } {
        variable sPo

        set ext [file extension $imgName]

        set fmtStr [poImgType GetFmtByExt $ext]
        if { $fmtStr eq "" } {
            tk_messageBox -message "Extension $ext not supported." \
                          -type ok -icon warning
            return
        }
        $sPo(left)  config -cursor watch
        $sPo(right) config -cursor watch
        update

        set optStr [poImgType GetOptByFmt $fmtStr "write"]
        $photoId write $imgName -format [list $fmtStr {*}$optStr]
        $sPo(left)  config -cursor crosshair
        $sPo(right) config -cursor crosshair
    }

    proc CleanUp { tw args } {
        variable sPo

        StopJob 1
        destroy $tw
        foreach ph $args {
            catch { image delete $ph }
        }
        foreach l [array names sPo "*,$tw.*,*"] {
            unset sPo($l)
        }
    }

    proc ShowHistogram { histoType } {
        variable sPo

        set sideList [list]
        foreach side { "left" "right" } {
            if { [info exists sPo($side,photo)] } {
                lappend sideList $side
                set img($side,width)  [image width  $sPo($side,photo)]
                set img($side,height) [image height $sPo($side,photo)]
                lappend phList $sPo($side,photo)
                lappend nameList [poAppearance CutFilePath $sPo($side,name)]
            }
        }

        if { [llength $sideList] == 0 } {
            tk_messageBox -message "You must load at least 1 image." \
                          -type ok -icon warning
            focus $sPo(tw)
            return
        }

        if { [llength $sideList] == 2 && \
             ($img(left,width)  != $img(right,width) || \
              $img(left,height) != $img(right,height)) } {
            tk_messageBox -type ok -icon warning \
                -message "Images differ in size."
            focus $sPo(tw)
        }

        poHistogram ShowHistoWin "Histogram display" $histoType $phList $nameList $sPo(appName)
    }

    proc StopJob { { closeWindow 0 } } {
        variable sPo

        set sPo(stopJob) 1
        if { $closeWindow } {
            set sPo(closeWindow) 1
        }
    }

    # This procedure is called after entering an adjust value in the entry fields
    # of the "Difference image" window. It checks, if the entered values are within
    # the bounds of the scale widget and clips thems, if necessary.
    proc CheckAdjustParam {} {
        variable sPo

        set adjustParam $sPo(curAdjustAlgo)
        set val $sPo($adjustParam)
        if { $adjustParam eq "adjustScale" } {
            set clipVal [poMisc Max 1 [poMisc Min 255 $val]]
        } elseif { $adjustParam eq "adjustThres" } {
            set clipVal [poMisc Max 0 [poMisc Min 255 $val]]
        }
        set sPo($adjustParam) $clipVal
    }

    proc UpdateHistoLines { histoNum } {
        variable sPo

        if { $sPo(curAdjustAlgo) eq "adjustThres" } {
            set numMarkLines $sPo(adjustThres)
        } elseif { $sPo(curAdjustAlgo) eq "adjustScale" } {
            set numMarkLines -1
        } else {
            return
        }
        poHistogram UpdateHistoLines $histoNum $numMarkLines $sPo(adjustColor)
    }

    proc UpdateAdjustParam { scaleValue } {
        variable sPo

        set fmtStr "%.0f"
        set adjustParam $sPo(curAdjustAlgo)
        set sPo($adjustParam) [format $fmtStr $scaleValue]
        UpdateHistoLines $sPo(diffHistoNum)
    }

    proc UpdateMixParam { scaleValue } {
        variable sPo

        set sPo(adjustPercent) [format "%.0f" $scaleValue]
    }

    proc ShowAdjustWidgets { fr canvId phSrc phDest } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Adjust:" \
                           "Mix:" } {
            ttk::label $fr.l$row -text $labelStr
            grid $fr.l$row -row $row -column 0 -sticky news
            incr row
        }

        # Generate right column with scale widgets.
        # Image adjustment
        set row 0
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky news

        # Note: -textvariable is configured in ConfigureAdjustWidgets
        ttk::entry $fr.fr$row.e -width 3
        # Note: -from, -to and -variable are configured in ConfigureAdjustWidgets
        ttk::scale $fr.fr$row.s -length 256 -orient horizontal \
                                -command "${ns}::UpdateAdjustParam"
        pack $fr.fr$row.e $fr.fr$row.s -side left -anchor w
        set sPo(entryWidget) $fr.fr$row.e
        set sPo(scaleWidget) $fr.fr$row.s
        ConfigureAdjustWidgets

        poToolhelp AddBinding $fr.fr$row.e \
            "Press Return after changing the value with this widget"
        bind $fr.fr$row.e <Key-Return>      "${ns}::AdjustImgFromEntry $canvId $phSrc $phDest"
        bind $fr.fr$row.s <ButtonRelease-1> "${ns}::AdjustImg $canvId $phSrc $phDest"
        bind $fr.fr$row.s <ButtonRelease-2> "${ns}::AdjustImg $canvId $phSrc $phDest"

        # Mix with original image
        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky news

        ttk::entry $fr.fr$row.e -textvariable ${ns}::sPo(adjustPercent) -width 3
        ttk::scale $fr.fr$row.s -from 0 -to 100 \
                                -length 256 -orient horizontal \
                                -variable ${ns}::sPo(adjustPercent) \
                                -command "${ns}::UpdateMixParam"
        pack $fr.fr$row.e $fr.fr$row.s -side left -anchor w

        poToolhelp AddBinding $fr.fr$row.e \
            "Press Return after changing the value with this widget"
        bind $fr.fr$row.e <Key-Return>      "${ns}::AdjustMixFromEntry $canvId $phSrc $phDest"
        bind $fr.fr$row.s <ButtonRelease-1> "${ns}::AdjustImg $canvId $phSrc $phDest"
        bind $fr.fr$row.s <ButtonRelease-2> "${ns}::AdjustImg $canvId $phSrc $phDest"

        # Use scaling or thresholding as image adjustment
        ttk::labelframe $fr.frAdj -text "Adjust algorithm"
        grid $fr.frAdj -row 0 -column 2 -sticky news

        ttk::radiobutton $fr.frAdj.rb1 \
                         -text "Scale" -value "adjustScale" \
                         -variable ${ns}::sPo(curAdjustAlgo) \
                         -command "${ns}::ConfigureAdjustWidgets ; ${ns}::AdjustImg $canvId $phSrc $phDest; ${ns}::UpdateHistoLines $sPo(diffHistoNum)"
        ttk::radiobutton $fr.frAdj.rb2 \
                         -text "Threshold" -value "adjustThres" \
                         -variable ${ns}::sPo(curAdjustAlgo) \
                         -command "${ns}::ConfigureAdjustWidgets ; ${ns}::AdjustImg $canvId $phSrc $phDest; ${ns}::UpdateHistoLines $sPo(diffHistoNum)"
        pack $fr.frAdj.rb1 $fr.frAdj.rb2 -side left -anchor w

        # Mix with left or right image
        ttk::labelframe $fr.frMix -text "Mix with image"
        grid $fr.frMix -row 1 -column 2 -sticky news

        ttk::radiobutton $fr.frMix.rb1 -text "Left" -value "left" \
                                   -variable ${ns}::sPo(curAdjustImg) \
                                   -command "${ns}::AdjustImg $canvId $phSrc $phDest"
        ttk::radiobutton $fr.frMix.rb2 -text "Right" -value "right" \
                                   -variable ${ns}::sPo(curAdjustImg) \
                                   -command "${ns}::AdjustImg $canvId $phSrc $phDest"
        pack $fr.frMix.rb1 $fr.frMix.rb2 -side left -anchor w

        # Display number of different pixels
        ttk::labelframe $fr.frNum -text "Different pixels"
        grid $fr.frNum -row 0 -column 3 -rowspan 2 -sticky news

        ttk::label $fr.frNum.l -textvariable ${ns}::sPo(numDiffPixels)
        pack $fr.frNum.l -side left -anchor e
    }

    proc ConfigureAdjustWidgets {} {
        variable sPo
        variable ns

        if { $sPo(curAdjustAlgo) eq "adjustScale" } {
            $sPo(entryWidget) configure -textvariable ${ns}::sPo(adjustScale)
            $sPo(scaleWidget) configure -from $sPo(adjustScale,min) -to $sPo(adjustScale,max) -variable ${ns}::sPo(adjustScale)
        } elseif { $sPo(curAdjustAlgo) eq "adjustThres" } {
            $sPo(entryWidget) configure -textvariable ${ns}::sPo(adjustThres)
            $sPo(scaleWidget) configure -from $sPo(adjustThres,min) -to $sPo(adjustThres,max) -variable ${ns}::sPo(adjustThres)
        }
    }

    proc SetDrawColor { color } {
        set rgb [poMisc RgbToDec $color]
        set r [expr [lindex $rgb 0] / 255.0]
        set g [expr [lindex $rgb 1] / 255.0]
        set b [expr [lindex $rgb 2] / 255.0]
        poImgUtil SetDrawColorRGB $r $g $b
    }

    proc AdjustImg { canvId phSrc phDest } {
        variable sPo

        if { [poImgAppearance UsePoImg] } {
            poImgUtil SetDrawModeRGB $::REPLACE $::REPLACE $::REPLACE
            set poImg [poImage NewImageFromPhoto $phSrc]
            if { $sPo(curAdjustAlgo) eq "adjustScale" } {
                set scl $sPo(adjustScale)
                $poImg ChangeGamma $::RED   1.0 $scl 0.0
                $poImg ChangeGamma $::GREEN 1.0 $scl 0.0
                $poImg ChangeGamma $::BLUE  1.0 $scl 0.0
                set sPo(numDiffPixels) "Use Threshold"
            } elseif { $sPo(curAdjustAlgo) eq "adjustThres" } {
                set thres $sPo(adjustThres)
                SetDrawColor $sPo(adjustColor)
                $poImg MarkNonZeroPixels $poImg $thres numMarked
                set sPo(numDiffPixels) $numMarked
            }
            # Scale original image by adjustPercent and add the difference image.
            if { $sPo(adjustPercent) != 0 } {
                set whichImg $sPo($sPo(curAdjustImg),poImg)
                set percent [expr $sPo(adjustPercent) / 100.0]

                $poImg GetImgInfo w h
                set origImg [poImage NewImage $w $h]
                $origImg CopyImage $whichImg

                $origImg ChangeGamma $::RED   1.0 $percent
                $origImg ChangeGamma $::GREEN 1.0 $percent
                $origImg ChangeGamma $::BLUE  1.0 $percent

                poImgUtil SetDrawModeRGB $::ADD $::ADD $::ADD
                $origImg CopyRect $poImg 0 0 $w $h 0 0
                poImgUtil SetDrawModeRGB $::REPLACE $::REPLACE $::REPLACE

                $origImg AsPhoto $phDest
                poImgUtil DeleteImg $origImg
            } else {
                set chanMap [list $::RED $::GREEN $::BLUE]
                $poImg AsPhoto $phDest $chanMap
            }
            poImgUtil DeleteImg $poImg
            ZoomDiff diffWin $phDest $canvId $sPo($canvId,zoomFactor)
        } else {
            # No poImg extension available.
            WriteInfoStr "The poImg extension is needed for image adjust." "Warning"
        }
    }

    proc AdjustImgFromEntry { canvId phSrc phDest } {
        variable sPo

        CheckAdjustParam
        UpdateHistoLines $sPo(diffHistoNum)
        AdjustImg $canvId $phSrc $phDest
    }

    proc AdjustMixFromEntry { canvId phSrc phDest } {
        set sPo(adjustPercent) [poMisc Max 0 [poMisc Min 100 $sPo(adjustPercent)]]
        AdjustImg $canvId $phSrc $phDest
    }

   proc ClearRawDiffPixelValue {} {
        variable sPo

        set sPo(curPos,x)          ""
        set sPo(curPos,y)          ""
        set sPo(diffCol,raw,left)  ""
        set sPo(diffCol,raw,right) ""
    }

    proc PrintRawDiffPixelValue { canvasId x y } {
        variable sPo

        set px [expr {int([$canvasId canvasx $x] / $sPo($canvasId,zoomFactor))}]
        set py [expr {int([$canvasId canvasy $y] / $sPo($canvasId,zoomFactor))}]

        set w [pawt GetImageWidth  sPo(left,rawDict)]
        set h [pawt GetImageHeight sPo(left,rawDict)]
        if { $px >= 0 && $py >= 0 && $px < $w && $py < $h } {
            set sPo(curPos,x) $px
            if { [poImgAppearance GetRowOrderCount] eq "TopDown" } {
                set sPo(curPos,y) $py
            } else {
                set sPo(curPos,y) [expr {$h - $py - 1}]
            }

            set sPo(diffCol,raw,left)  [pawt GetImagePixelAsString sPo(left,rawDict)  $px $py $sPo(diff,raw,precision)]
            set sPo(diffCol,raw,right) [pawt GetImagePixelAsString sPo(right,rawDict) $px $py $sPo(diff,raw,precision)]
        } else {
            ClearRawDiffPixelValue
        }
    }

    proc DiffRawImages { canvasId photoId phSave } {
        variable sPo
        variable ns

        if { [info commands CoroDiffImages] eq "CoroDiffImages" } {
            return false
        }
        $canvasId config -cursor watch
        set sPo(stopJob) 0
        WriteInfoStr "Comparing images ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) 100

        $photoId copy $sPo(left,photo)
        if { $sPo(diff,raw,mark) } {
            set photoIdParam $photoId
        } else {
            set photoIdParam ""
        }
        coroutine CoroDiffImages pawt::DiffImages ${ns}::sPo(left,rawDict) ${ns}::sPo(right,rawDict) \
                                 -threshold $sPo(diff,raw,threshold) -photo $photoIdParam -markcolor $sPo(adjustColor)
        while { true } {
            set retVal [catch {CoroDiffImages} yieldList]
            if { $retVal != 0 } {
                # Error occured in pawt::DiffImages.
                break
            }
            if { $sPo(stopJob) } {
                WriteInfoStr "Image processing stopped by user." "Cancel"
                poWin UpdateStatusProgress $sPo(StatusWidget) 0
                set sPo(stopJob) 0
                rename CoroDiffImages {}
                $canvasId config -cursor crosshair
                return false
            }
            if { [llength $yieldList] == 2 } {
                set sPo(diff,raw,numDiff) [lindex $yieldList 0]
                poWin UpdateStatusProgress $sPo(StatusWidget) [lindex $yieldList 1]
                update
            } else {
                break
            }
        }
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        $canvasId config -cursor crosshair
        if { $retVal == 0 } {
            $phSave copy $photoId
            ZoomDiff rawDiffWin $photoId $canvasId $sPo($canvasId,zoomFactor)
            WriteInfoStr "Comparison finished." "Ok"
            return true
        } else {
            WriteInfoStr $yieldList "Error"
            return false
        }
    }

    proc ConfigureRawValWidgets {} {
        variable sPo

        set w [expr { $sPo(diff,raw,precision) + 5 }]
        if { [info exists sPo(diff,raw,leftValWidget)] && [winfo exists $sPo(diff,raw,leftValWidget)] } {
            $sPo(diff,raw,leftValWidget)  configure -width $w
            $sPo(diff,raw,rightValWidget) configure -width $w
        }
        if { [info exists sPo(leftValWidget)] && [winfo exists $sPo(leftValWidget)] } {
            $sPo(leftValWidget)  configure -width $w
            $sPo(rightValWidget) configure -width $w
        }
    }

    proc ShowRawDiffImg {} {
        variable sPo
        variable ns

        if { ! [info exists sPo(left,rawDict)] || ! [info exists sPo(right,rawDict)] } {
            WriteInfoStr "Two RAW images must be loaded" "Error"
            return
        }

        if { [pawt GetImagePixelSize sPo(left,rawDict)] == 1 && \
             [pawt GetImagePixelSize sPo(right,rawDict)] == 1 } {
            ShowDiffImg
            return
        }

        foreach side { "left" "right" } {
            set img($side,width)  [image width  $sPo($side,photo)]
            set img($side,height) [image height $sPo($side,photo)]
        }
        set w [poMisc Max $img(left,width)  $img(right,width)]
        set h [poMisc Max $img(left,height) $img(right,height)]
        set wz [expr int ($w * $sPo(zoomFactor))]
        set hz [expr int ($h * $sPo(zoomFactor))]

        set tw .poImgdiff_DiffRawImg
        set sPo(rawDiffWin,name) $tw
        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }
        toplevel $tw
        set labelStr [format "%s vs. %s" [poAppearance CutFilePath $sPo(left,name)] \
                                         [poAppearance CutFilePath $sPo(right,name)]]
        set sPo(rawDiffWin,title) "Difference image ($labelStr)"
        wm title $tw $sPo(rawDiffWin,title)

        wm geometry $tw [format "%dx%d+%d+%d" \
                    $sPo(rawDiffWin,w) $sPo(rawDiffWin,h) \
                    $sPo(rawDiffWin,x) $sPo(rawDiffWin,y)]

        ttk::frame $tw.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.workfr
        ttk::frame $tw.statfr -relief sunken -borderwidth 1
        grid $tw.toolfr -row 0 -column 0 -sticky news 
        grid $tw.workfr -row 1 -column 0 -sticky news
        grid $tw.statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $tw 1 -weight 1
        grid columnconfigure $tw 0 -weight 1

        ttk::frame $tw.workfr.pixfr
        ttk::frame $tw.workfr.imgfr

        grid $tw.workfr.pixfr -row 0 -column 0 -sticky news
        grid $tw.workfr.imgfr -row 1 -column 0 -sticky news
        grid rowconfigure    $tw.workfr 1 -weight 1
        grid columnconfigure $tw.workfr 0 -weight 1

        set canvasId [poWin CreateScrolledCanvas $tw.workfr.imgfr true "" \
                      -width $wz -height $hz \
                      -borderwidth 0 -highlightthickness 0]
        set photoId [image create photo -width $w -height $h]
        $canvasId create image 0 0 -anchor nw -image $photoId -tags $canvasId
        set phSave [image create photo -width $w -height $h]

        # Create menus File, View
        set hMenu $tw.menufr
        menu $hMenu -borderwidth 2 -relief sunken
        $hMenu add cascade -menu $hMenu.file -label File -underline 0
        $hMenu add cascade -menu $hMenu.view -label View -underline 0

        set fileMenu $hMenu.file
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Save as ..." "Ctrl+S" "${ns}::SaveDiffImg $tw $photoId"
        poMenu AddCommand $fileMenu "Close"       "Ctrl+W" "${ns}::CleanUp $tw $photoId $phSave"

        bind $tw <Control-s> "${ns}::SaveDiffImg $tw $photoId"

        set viewMenu   $hMenu.view
        set zoomMenu   $viewMenu.zoom

        menu $viewMenu -tearoff 0

        set sPo($canvasId,autofit) $sPo(zoom,autofit)
        $viewMenu add cascade -label "Zoom" -menu $viewMenu.zoom
        poMenu AddCheck   $viewMenu "Autofit" "Ctrl+M" ${ns}::sPo($canvasId,autofit) \
                          "${ns}::ZoomDiff rawDiffWin $photoId $canvasId"
        poMenu AddCheck   $viewMenu "Mark pixels" "" ${ns}::sPo(diff,raw,mark) ""
        poMenu AddCommand $viewMenu "Difference image" "Ctrl+D" \
                          "${ns}::DiffRawImages $canvasId $photoId $phSave"

        menu $zoomMenu -tearoff 0
        poMenu AddRadio $zoomMenu "  5%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.05 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.05"
        poMenu AddRadio $zoomMenu " 10%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.10 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.10"
        poMenu AddRadio $zoomMenu " 20%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.20 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.20"
        poMenu AddRadio $zoomMenu " 25%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.25 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.25"
        poMenu AddRadio $zoomMenu " 33%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.33 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.33"
        poMenu AddRadio $zoomMenu " 50%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.50 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 0.50"
        poMenu AddRadio $zoomMenu "100%"  "" ${ns}::sPo($canvasId,zoomFactor) 1.00 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 1.00"
        poMenu AddRadio $zoomMenu "200%"  "" ${ns}::sPo($canvasId,zoomFactor) 2.00 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 2.00"
        poMenu AddRadio $zoomMenu "300%"  "" ${ns}::sPo($canvasId,zoomFactor) 3.00 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 3.00"
        poMenu AddRadio $zoomMenu "400%"  "" ${ns}::sPo($canvasId,zoomFactor) 4.00 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 4.00"
        poMenu AddRadio $zoomMenu "500%"  "" ${ns}::sPo($canvasId,zoomFactor) 5.00 \
                        "${ns}::ZoomDiff rawDiffWin $photoId $canvasId 5.00"

        bind $tw <Key-plus>  "${ns}::ChangeZoomDiff rawDiffWin $photoId $canvasId  1"
        bind $tw <Key-minus> "${ns}::ChangeZoomDiff rawDiffWin $photoId $canvasId -1"
        bind $tw <Control-m> "${ns}::SwitchDiffAutofit rawDiffWin $photoId $canvasId"
        bind $tw <Control-d> "${ns}::DiffRawImages $canvasId $photoId $phSave"
        $tw configure -menu $hMenu

        set toolfr $tw.toolfr

        # Add new toolbar group and associated buttons.
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::save] \
                  "${ns}::SaveDiffImg $tw $photoId" "Save difference image to file"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::autofit] \
                  "${ns}::ZoomDiff rawDiffWin $photoId $canvasId" "Toggle image autofit (Ctrl+M)" \
                  -variable ${ns}::sPo($canvasId,autofit)
        poToolbar AddCheckButton $toolfr [::poBmpData::sheet] \
                  "" "Mark pixels" -variable ${ns}::sPo(diff,raw,mark)
        poToolbar AddButton $toolfr [::poBmpData::halt "red"] \
                  ${ns}::StopJob "Stop current compare job (Esc)"
        poToolbar AddButton $toolfr [::poBmpData::diff] "${ns}::DiffRawImages $canvasId $photoId $phSave" \
                  "Show difference image (Ctrl+D)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddLabel $toolfr "Threshold:" ""
        set thresEntry [poToolbar AddEntry $toolfr ${ns}::sPo(diff,raw,threshold) "Threshold for comparison" -width 5]
        bind $thresEntry <Key-Return> "${ns}::DiffRawImages $canvasId $photoId $phSave"

        poToolbar AddLabel $toolfr "Precision:" ""
        set precEntry [poToolbar AddEntry $toolfr ${ns}::sPo(diff,raw,precision) "Precision of float display" -width 5]
        bind $precEntry <Key-Return> "${ns}::ConfigureRawValWidgets "

        # Add the color and pixel information frame to the toolbar.
        set pixelFr $tw.toolfr.pixfr
        ttk::frame $pixelFr
        pack $pixelFr -anchor w -side right -fill x -expand 1

        ttk::separator $pixelFr.sep1 -orient vertical
        ttk::frame $pixelFr.posFr
        ttk::separator $pixelFr.sep2 -orient vertical
        ttk::frame $pixelFr.valFr
        ttk::separator $pixelFr.sep3 -orient vertical
        ttk::frame $pixelFr.numFr
        pack $pixelFr.sep1 -side left -padx 2 -fill y
        pack $pixelFr.posFr -anchor w -side left
        pack $pixelFr.sep2 -side left -padx 2 -fill y
        pack $pixelFr.valFr -anchor w -side left
        pack $pixelFr.sep3 -side left -padx 2 -fill y
        pack $pixelFr.numFr -anchor w -side left

        ttk::label $pixelFr.posFr.l -text "Position:"
        ttk::label $pixelFr.posFr.x -textvariable ${ns}::sPo(curPos,x) -width 4 -anchor e
        ttk::label $pixelFr.posFr.y -textvariable ${ns}::sPo(curPos,y) -width 4 -anchor e
        pack $pixelFr.posFr.l -anchor w -side left
        pack $pixelFr.posFr.x $pixelFr.posFr.y -anchor e -side left

        ttk::label $pixelFr.valFr.l -text "Values:"
        ttk::label $pixelFr.valFr.el -textvariable ${ns}::sPo(diffCol,raw,left)  -anchor e
        ttk::label $pixelFr.valFr.er -textvariable ${ns}::sPo(diffCol,raw,right) -anchor e
        pack $pixelFr.valFr.l  -anchor w -side left
        pack $pixelFr.valFr.el $pixelFr.valFr.er -anchor w -side left
        set sPo(diff,raw,leftValWidget)  $pixelFr.valFr.el
        set sPo(diff,raw,rightValWidget) $pixelFr.valFr.er
        ConfigureRawValWidgets

        ttk::label $pixelFr.numFr.l -text "Different pixels:"
        ttk::label $pixelFr.numFr.n -textvariable ${ns}::sPo(diff,raw,numDiff) -anchor e
        pack $pixelFr.numFr.l -anchor w -side left
        pack $pixelFr.numFr.n -anchor w -side left

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget) [poWin CreateStatusWidget $tw.statfr true]

        set sPo(closeWindow) 0

        bind $tw <KeyPress-Escape> ${ns}::StopJob
        bind $tw <Control-w>             "${ns}::CleanUp $tw $photoId $phSave"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CleanUp $tw $photoId $phSave"
        focus $tw
        update

        set sPo($canvasId,zoomFactor) $sPo(zoomFactor)
        bind $tw <Configure> "${ns}::StoreDiffWinGeom rawDiffWin $tw"
        $canvasId bind $canvasId <Motion> "${ns}::PrintRawDiffPixelValue $canvasId %x %y"
        $canvasId bind $canvasId <Leave>  "${ns}::ClearRawDiffPixelValue"
        DiffRawImages $canvasId $photoId $phSave
    }

    proc StoreDiffWinGeom { winType w } {
        variable sPo

        scan [wm geometry $w] "%dx%d+%d+%d" w h x y
        set sPo($winType,w) $w
        set sPo($winType,h) $h
        set sPo($winType,x) $x
        set sPo($winType,y) $y
    }

    proc ShowDiffImg {} {
        variable sPo
        variable ns

        if { ! [info exists sPo(left,photo)] || \
             ! [info exists sPo(right,photo)] } {
            tk_messageBox -message "You must load 2 images first." \
                          -type ok -icon warning
            focus $sPo(tw)
            return
        }

        foreach side { "left" "right" } {
            set img($side,width)  [image width  $sPo($side,photo)]
            set img($side,height) [image height $sPo($side,photo)]
        }

        if { $img(left,width)  != $img(right,width) || \
             $img(left,height) != $img(right,height) } {
            if { [poMisc HavePkg "poImg"] } {
                tk_messageBox -type ok -icon warning -title "Warning" -message \
                    "Images differ in size. Images will be aligned at bottom-left to produce difference image."
            } else {
                tk_messageBox -type ok -icon warning -title "Warning" -message \
                    "Images differ in size. No difference image possible without the poImg extension."
                focus $sPo(tw)
                return
            }
        }

        set w [poMisc Max $img(left,width)  $img(right,width)]
        set h [poMisc Max $img(left,height) $img(right,height)]
        set wz [expr int ($w * $sPo(zoomFactor))]
        set hz [expr int ($h * $sPo(zoomFactor))]

        set tw .poImgdiff_DiffImg
        set sPo(diffWin,name) $tw
        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }
        toplevel $tw
        set labelStr [format "%s vs. %s" [poAppearance CutFilePath $sPo(left,name)] \
                                         [poAppearance CutFilePath $sPo(right,name)]]
        set sPo(diffWin,title) "Difference image ($labelStr)"
        wm title $tw $sPo(diffWin,title)

        wm geometry $tw [format "%dx%d+%d+%d" \
                    $sPo(diffWin,w) $sPo(diffWin,h) \
                    $sPo(diffWin,x) $sPo(diffWin,y)]
        focus $tw

        ttk::frame $tw.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.workfr
        pack $tw.toolfr -side top -fill x -anchor w
        pack $tw.workfr -side top -fill both -expand 1

        ttk::frame $tw.workfr.pixfr
        ttk::frame $tw.workfr.adjfr
        ttk::frame $tw.workfr.imgfr
        ttk::labelframe $tw.workfr.histfr -text "Histogram"

        grid $tw.workfr.pixfr  -row 0 -column 0 -sticky nwse
        grid $tw.workfr.adjfr  -row 1 -column 0 -sticky nwse
        grid $tw.workfr.imgfr  -row 2 -column 0 -sticky nwse
        grid $tw.workfr.histfr -row 0 -column 1 -sticky nwse -rowspan 3 -padx 2
        grid rowconfigure $tw.workfr 2 -weight 1
        grid columnconfigure $tw.workfr 0 -weight 1

        set canvasId [poWin CreateScrolledCanvas $tw.workfr.imgfr true "" \
                      -width $wz -height $hz \
                      -borderwidth 0 -highlightthickness 0]
        set photoId [image create photo -width $w -height $h]
        $canvasId create image 0 0 -anchor nw -image $photoId -tags $canvasId
        $canvasId create text [expr $wz /2] [expr $hz -20] -anchor w -tags percentage
        set phSave [image create photo -width $w -height $h]

        # Create menus File, View
        set hMenu $tw.menufr
        menu $hMenu -borderwidth 2 -relief sunken
        $hMenu add cascade -menu $hMenu.file -label File -underline 0
        $hMenu add cascade -menu $hMenu.view -label View -underline 0

        set fileMenu $hMenu.file
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Save as ..." "Ctrl+S" "${ns}::SaveDiffImg $tw $photoId"
        poMenu AddCommand $fileMenu "Close"       "Ctrl+W" "${ns}::CleanUp $tw $photoId $phSave"

        bind $tw <Control-s> "${ns}::SaveDiffImg $tw $photoId"

        set viewMenu   $hMenu.view
        set zoomMenu   $viewMenu.zoom

        menu $viewMenu -tearoff 0

        set sPo($canvasId,autofit) $sPo(zoom,autofit)
        $viewMenu add cascade -label "Zoom" -menu $viewMenu.zoom
        poMenu AddCheck $viewMenu "Autofit" "Ctrl+M" ${ns}::sPo($canvasId,autofit) \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId"

        menu $zoomMenu -tearoff 0
        poMenu AddRadio $zoomMenu "  5%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.05 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.05"
        poMenu AddRadio $zoomMenu " 10%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.10 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.10"
        poMenu AddRadio $zoomMenu " 20%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.20 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.20"
        poMenu AddRadio $zoomMenu " 25%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.25 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.25"
        poMenu AddRadio $zoomMenu " 33%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.33 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.33"
        poMenu AddRadio $zoomMenu " 50%"  "" ${ns}::sPo($canvasId,zoomFactor) 0.50 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 0.50"
        poMenu AddRadio $zoomMenu "100%"  "" ${ns}::sPo($canvasId,zoomFactor) 1.00 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 1.00"
        poMenu AddRadio $zoomMenu "200%"  "" ${ns}::sPo($canvasId,zoomFactor) 2.00 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 2.00"
        poMenu AddRadio $zoomMenu "300%"  "" ${ns}::sPo($canvasId,zoomFactor) 3.00 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 3.00"
        poMenu AddRadio $zoomMenu "400%"  "" ${ns}::sPo($canvasId,zoomFactor) 4.00 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 4.00"
        poMenu AddRadio $zoomMenu "500%"  "" ${ns}::sPo($canvasId,zoomFactor) 5.00 \
                        "${ns}::ZoomDiff diffWin $photoId $canvasId 5.00"

        bind $tw <Key-plus>  "${ns}::ChangeZoomDiff diffWin $photoId $canvasId  1"
        bind $tw <Key-minus> "${ns}::ChangeZoomDiff diffWin $photoId $canvasId -1"
        bind $tw <Control-m> "${ns}::SwitchDiffAutofit diffWin $photoId $canvasId"
        $tw configure -menu $hMenu

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::save] \
                  "${ns}::SaveDiffImg $tw $photoId" "Save difference image to file"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::autofit] \
                  "${ns}::ZoomDiff diffWin $photoId $canvasId" "Toggle image autofit (Ctrl+M)" \
                  -variable ${ns}::sPo($canvasId,autofit)

        # Add the color and pixel information frame to the toolbar.
        set pixelFr $tw.toolfr.pixfr
        ttk::frame $pixelFr
        pack $pixelFr -anchor w -side right -fill x -expand 1

        ttk::separator $pixelFr.sep1 -orient vertical
        ttk::frame $pixelFr.posFr
        ttk::separator $pixelFr.sep2 -orient vertical
        ttk::frame $pixelFr.diffFr
        pack $pixelFr.sep1 -side left -padx 2 -fill y
        pack $pixelFr.posFr -anchor w -side left
        pack $pixelFr.sep2 -side left -padx 2 -fill y
        pack $pixelFr.diffFr -anchor w -side left

        ttk::label $pixelFr.posFr.l -text "Position:"
        ttk::label $pixelFr.posFr.ex -textvariable ${ns}::sPo(curPos,x) -width 4 -anchor e
        ttk::label $pixelFr.posFr.ey -textvariable ${ns}::sPo(curPos,y) -width 4 -anchor e
        pack $pixelFr.posFr.l -anchor w -side left
        pack $pixelFr.posFr.ex $pixelFr.posFr.ey -anchor e -side left

        set sPo(diffCol,hex) $pixelFr.diffFr.c
        ttk::label $pixelFr.diffFr.l -text "Color:"
        label $sPo(diffCol,hex) -width 3 -relief sunken
        ttk::label $pixelFr.diffFr.er -textvariable ${ns}::sPo(diffCol,r) -width 3 -anchor e
        ttk::label $pixelFr.diffFr.eg -textvariable ${ns}::sPo(diffCol,g) -width 3 -anchor e
        ttk::label $pixelFr.diffFr.eb -textvariable ${ns}::sPo(diffCol,b) -width 3 -anchor e
        pack $pixelFr.diffFr.l $sPo(diffCol,hex) -anchor w -side left
        pack $pixelFr.diffFr.er $pixelFr.diffFr.eg $pixelFr.diffFr.eb -anchor w -side left

        set sPo(stopJob) 0
        set sPo(closeWindow) 0

        bind $tw <KeyPress-Escape> ${ns}::StopJob
        $canvasId config -cursor watch
        update

        set lCanv $sPo(left)
        set rCanv $sPo(right)
        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sPo(left,poImg)] } {
                poLog Debug "Copying left photo to poImage"
                set sPo(left,poImg) [poImage NewImageFromPhoto $sPo(left,photo)]
            }
            if { ! [info exists sPo(right,poImg)] } {
                poLog Debug "Copying right photo to poImage"
                set sPo(right,poImg) [poImage NewImageFromPhoto $sPo(right,photo)]
            }
            set diffImg [poImgUtil DifferenceImage $sPo(left,poImg) $sPo(right,poImg)]
            set chanMap [list $::RED $::GREEN $::BLUE]
            $diffImg AsPhoto $photoId $chanMap
            poImgUtil DeleteImg $diffImg
        } else {
            # No poImg extension available.
            # We have to do it with standard Tk commands, which can be very,
            # very slow for images greater than 200 by 200 pixels.
            set leftPhoto  $sPo(left,photo)
            set rightPhoto $sPo(right,photo)
            for { set y 0 } { $y < $h } { incr y } {
                set percentage [expr {int($y * 100.0 / $h)}]
                $canvasId itemconfigure percentage -text [format "%d%%" $percentage]
                set scanline [list]
                for { set x 0 } { $x < $w } { incr x } {
                    set left  [$leftPhoto  get $x $y]
                    set right [$rightPhoto get $x $y]

                    set dr [expr { [lindex $right 0] - [lindex $left 0] }]
                    if { $dr < 0 } { set dr [expr {-$dr}] }

                    set dg [expr { [lindex $right 1] - [lindex $left 1] }]
                    if { $dg < 0 } { set dg [expr {-$dg}] }

                    set db [expr { [lindex $right 2] - [lindex $left 2] }]
                    if { $db < 0 } { set db [expr {-$db}] }

                    lappend scanline [format "#%02X%02X%02X" $dr $dg $db]
                }
                $photoId put [list $scanline] -to 0 $y
                update
                if { $sPo(closeWindow) } {
                    WriteInfoStr "Window closed by user." "Cancel"
                    return
                }
                if { $sPo(stopJob) } {
                    WriteInfoStr "Image processing stopped by user." "Cancel"
                    break
                }
            }
            $canvasId delete percentage
        }
        $phSave copy $photoId

        set histoType [poImgAppearance GetHistogramType]
        set diffHisto [poHistogram ShowHistoWin $tw.workfr.histfr $histoType $phSave "DifferenceImage"]
        set sPo(diffHistoNum) $diffHisto

        ShowAdjustWidgets $tw.workfr.adjfr $canvasId $phSave $photoId

        set sPo($canvasId,zoomFactor) $sPo(zoomFactor)

        $canvasId config -cursor crosshair

        bind $tw <Configure> "${ns}::StoreDiffWinGeom diffWin $tw"
        bind $tw <Control-w> "${ns}::CleanUp $tw $photoId $phSave"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CleanUp $tw $photoId $phSave"
        bind $tw <KeyPress-Escape> "${ns}::CleanUp $tw $photoId $phSave"
        $canvasId bind $canvasId <Motion>   "${ns}::PrintDiffPixelValue $canvasId $photoId %x %y false"
        $canvasId bind $canvasId <Button-1> "${ns}::PrintDiffPixelValue $canvasId $photoId %x %y true"
        $canvasId bind $canvasId <Leave>    "${ns}::ClearDiffPixelValue"
        AdjustImg $canvasId $phSave $photoId
        UpdateHistoLines $diffHisto
    }

    proc ShowDiffImgOnStartup {} {
        variable sPo

        if { ( $sPo(diffOnStartup) || $sPo(optShowDiffOnStartup) ) && $sPo(optRawDiff) } {
            ShowRawDiffImg
        } elseif { ( $sPo(diffOnStartup) || $sPo(optShowDiffOnStartup) ) && \
             [info exists sPo(left,photo)] && \
             [info exists sPo(right,photo)] } {
            ShowDiffImg
        }
    }

    proc GetImgStats { phImg x1 y1 x2 y2 } {
        variable sPo

        if { [poImgAppearance UsePoImg] } {
            set poImg [poImage NewImageFromPhoto $phImg]
            set statDict [poImgUtil GetImgStats $poImg true $x1 $y1 $x2 $y2]
            poImgUtil DeleteImg $poImg
        } else {
            set statDict [poPhotoUtil GetImgStats $phImg true $x1 $y1 $x2 $y2]
        }
        return $statDict
    }

    proc GetSideStats { side x1 y1 x2 y2 } {
        variable sPo

        set canv $sPo($side)

        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sPo($side,poImg)] } {
                # puts "GetImgStats: Copying $side photo into a poImg"
                set sPo($side,poImg) [poImage NewImageFromPhoto $sPo($side,photo)]
            }
            set statDict [poImgUtil GetImgStats $sPo($side,poImg) true $x1 $y1 $x2 $y2]
        } else {
            set statDict [poPhotoUtil GetImgStats $sPo($side,photo) true $x1 $y1 $x2 $y2]
        }
        return $statDict
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[ImageFile1\] \[ImageFile2\]\n"
        append msg "\n"
        append msg "Load 2 images for comparison. If no option is specified, the images\n"
        append msg "are loaded in a graphical user interface for interactive comparison.\n"
        append msg "\n"
        append msg "Batch processing information:\n"
        append msg "  An exit status of 0 indicates identical images.\n"
        append msg "  An exit status of 1 indicates differing images.\n"
        append msg "  Any other exit status indicates an error when comparing.\n"
        append msg "  On Windows the exit status is stored in ERRORLEVEL.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--showdiff         : Show difference image after startup.\n"
        append msg "--rawdiff          : If using batch mode, compare 16-bit or 32-bit RAW images.\n"
        append msg "                     Note, that options \"--savediff\", \"--savehist\" and \"--poImg\"\n"
        append msg "                     are not effective with this option.\n"
        append msg "--threshold <int>  : If using batch mode, specify the threshold\n"
        append msg "                     for comparing images.\n"
        append msg "                     Default: 0.\n"
        append msg "--savediff <string>: If using batch mode, save the calculated\n"
        append msg "                     difference image in specified file.\n"
        append msg "                     Default: No.\n"
        append msg "--savehist <string>: If using batch mode, save the histograms of the\n"
        append msg "                     input and the difference images in specified CSV file.\n"
        append msg "                     Default: No.\n"
        append msg "--poimg            : If using batch mode, load the images with the\n"
        append msg "                     poImg extension. This is faster then using the TkImg\n"
        append msg "                     parsers and saves memory.\n"
        append msg "                     Available only for Targa and SGI images.\n"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        set sPo(zoomList) [list 0.05 0.10 0.20 0.25 0.33 0.50 1.00 2.00 3.00 4.00 5.00]

        set sPo(adjustScale,min) 1
        set sPo(adjustScale,max) 255
        set sPo(adjustThres,min) 0
        set sPo(adjustThres,max) 255

        set sPo(zoomRectExists) 0

        set sPo(left,name) ""
        set sPo(right,name) ""

        # Init all variables stored in the cfg file with default values.
        SetWindowPos mainWin     90 30 800 450
        SetWindowPos diffWin     50 50 800 450
        SetWindowPos rawDiffWin  50 50 800 450
        SetWindowPos specWin    100 50   0   0

        SetMainWindowSash 200

        SetZoomParams 1 1.00

        SetShowImageTab 1

        SetDiffOnStartup 0

        SetCurFiles "" ""

        SetAdjustParams 0 1 0 "left" "adjustScale"
        SetAdjustMarkColor "#FFFF00"
        SetRawAdjustParams 0 5 1

        # Now try to read the cfg file.
        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            set sPo(initType) "Ok"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file \"$cfgFile\" found. Using default values."
            set sPo(initType) "Warning"
        }
        set sPo(cfgDir) $cfgDir
    }

    proc PrintCmd { fp cmdName } {
        puts $fp "\n# Set${cmdName} [info args Set${cmdName}]"
        puts $fp "catch {Set${cmdName} [Get${cmdName}]}"
    }

    proc SaveSettings {} {
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetWindowPos [info args SetWindowPos]"

            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos diffWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos rawDiffWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos specWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetWindowPos [GetWindowPos diffWin]
            eval SetWindowPos [GetWindowPos rawDiffWin]
            eval SetWindowPos [GetWindowPos specWin]

            eval SetMainWindowSash [GetMainWindowSash]

            PrintCmd $fp "MainWindowSash"

            PrintCmd $fp "AdjustParams"
            PrintCmd $fp "AdjustMarkColor"
            PrintCmd $fp "RawAdjustParams"

            PrintCmd $fp "ZoomParams"

            PrintCmd $fp "ShowImageTab"

            PrintCmd $fp "DiffOnStartup"

            PrintCmd $fp "CurFiles"

            close $fp
        }
    }

    proc CancelSettingsWin { tw args } {
        variable sPo

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        destroy $tw
    }

    proc OKSettingsWin { tw args } {
        variable sPo

        destroy $tw
    }

    proc CloseSubWindows {} {
        variable sPo

        catch {destroy $sPo(histoWin,name)}
        catch {destroy $sPo(diffWin,name)}
        catch {destroy $sPo(rawDiffWin,name)}
        poHistogram CloseAllHistoWin $sPo(appName)
    }

    proc CloseAppWindow {} {
        variable sPo

        if { ! [info exists sPo(tw)] || ! [winfo exists $sPo(tw)] } {
            return
        }

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows

        # Delete left and right images.
        ClearLeft
        ClearRight

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        poApps ExitApp
    }

    proc BatchProcess { leftFileToOpen rightFileToOpen } {
        variable sPo
        variable ns

        # Do not save settings to file and do not autofit images.
        poApps SetAutosaveOnExit false
        SetZoomParams 0 1.00
        poLog SetShowConsole false
        poWatch Start batchTimer

        # First check, if two image filenames have been specified on the command
        # line and if the names are valid file names.
        if { $leftFileToOpen eq "" || $rightFileToOpen eq "" } {
            puts "Not enough image files specified."
            return 2
        }
        if { ! [file isfile $leftFileToOpen] } {
            puts "$leftFileToOpen is not a valid file"
            return 3
        }
        if { ! [file isfile $rightFileToOpen] } {
            puts "$rightFileToOpen is not a valid file"
            return 4
        }

        # Read in the two images for comparison. In batch mode we do not display the images.
        # This saves time and lots of memory for large images.
        # We delete the photo image immediately after converting it into a poImg.
        foreach side {"left" "right"} \
                imgFile [list $leftFileToOpen $rightFileToOpen] {
            if { [poApps GetVerbose] } {
                puts -nonewline "Reading image $imgFile ..." ; flush stdout
            }
            poWatch Reset batchTimer
            if { $sPo(optRawDiff) } {
                if { [poType IsImage $imgFile "raw"] } {
                    set img($side) [pawt::raw::ReadImageFile $imgFile]
                } elseif { [poType IsImage $imgFile "flir"] } {
                    set img($side) [pawt::flir::ReadImageFile $imgFile]
                } elseif { [poType IsImage $imgFile "fits"] } {
                    set img($side) [pawt::fits::ReadImageFile $imgFile]
                } elseif { [poType IsImage $imgFile "ppm"] } {
                    set img($side) [pawt::ppm::ReadImageFile $imgFile]
                } else {
                    puts "\nFile $imgFile is not a RAW, FLIR, FITS or PPM image file."
                    return 5
                }
            } elseif { $sPo(optUsePoImg) } {
                set retVal [catch {set img($side) [poImage NewImageFromFile $imgFile]} err]
                set readTime($side) [poWatch Lookup batchTimer]
                set copyTime($side) 0.0
                if { $retVal != 0 } {
                    puts "\nCan't read image $imgFile ($err)"
                    return 5
                }
            } else {
                set retVal [catch {poImgMisc LoadImg $imgFile} imgDict]
                set readTime($side) [poWatch Lookup batchTimer]
                if { $retVal != 0 } {
                    puts "\n$imgDict"
                    return 5
                }
                set phImg [dict get $imgDict phImg]
                set poImg [dict get $imgDict poImg]
                if { $poImg ne "" } {
                    set img($side) $poImg
                } else {
                    set img($side) [poImage NewImageFromPhoto $phImg]
                    set copyTime($side) [expr [poWatch Lookup batchTimer] - $readTime($side)]
                }
                image delete $phImg
            }
            if { [poApps GetVerbose] } {
                puts [format " (Time: %.2f seconds)" [poWatch Lookup batchTimer]]
            }
        }

        if { ! [info exists img(left)] } {
            puts "\nCould not read an image for left side."
            return 5
        }
        if { ! [info exists img(right)] } {
            puts "\nCould not read an image for right side."
            return 5
        }

        # Generate the difference image and calculate number of differing pixels.

        if { $sPo(optRawDiff) } {
            if { [poApps GetVerbose] } {
                puts -nonewline "Calculating RAW difference image with threshold $sPo(optThresh) ..." ; flush stdout
            }
            poWatch Reset batchTimer
            set retVal [catch {pawt DiffImages img(left) img(right) \
                               -threshold $sPo(optThresh)} numDiffPixels]
            if { $retVal != 0 } {
                puts "\n$numDiffPixels"
                return 6
            }
            if { [poApps GetVerbose] } {
                puts [format " (Time: %.2f seconds)" [poWatch Lookup batchTimer]]
            }
        } else {
            if { $sPo(optSaveHisto) ne "" } {
                set histoDict(left)  [poImgUtil Histogram $img(left)  [file tail $leftFileToOpen]]
                set histoDict(right) [poImgUtil Histogram $img(right) [file tail $rightFileToOpen]]
            }

            if { [poApps GetVerbose] } {
                puts -nonewline "Calculating difference image with threshold $sPo(optThresh) ..." ; flush stdout
            }

            poWatch Reset batchTimer
            SetDrawColor $sPo(adjustColor)

            $img(left) DifferenceImage $img(left) $img(right)
            set diffTime [poWatch Lookup batchTimer]

            if { $sPo(optSaveHisto) ne "" } {
                set histoDict(diff) [poImgUtil Histogram $img(left) "diff"]
            }

            $img(left) MarkNonZeroPixels $img(left) $sPo(optThresh) numDiffPixels
            set markTime [expr [poWatch Lookup batchTimer] - $diffTime]

            if { [poApps GetVerbose] } {
                puts [format " (Time: %.2f seconds)" [poWatch Lookup batchTimer]]
            }

            if { 0 } {
                # Enable for detailled timing information.
                puts [format "Read=%.2f Copy=%.2f Diff=%.2f Mark=%.2f NumDiffs=%d" \
                    [expr $readTime(left) + $readTime(right)] \
                    [expr $copyTime(left) + $copyTime(right)] \
                    $diffTime $markTime $numDiffPixels]
            }

            # Optionally write out the histogram values and/or the difference image.
            if { $sPo(optSaveHisto) ne "" } {
                if { [poApps GetVerbose] } {
                    puts "Writing histogram values into file $sPo(optSaveHisto) ..." ; flush stdout
                }
                set retVal [catch { poHistogram SaveHistogramValues $sPo(optSaveHisto) \
                               $histoDict(left) $histoDict(right) $histoDict(diff) } err]
                if { $retVal != 0 } {
                    puts $err
                    return 6
                }
            }

            if { $sPo(optSaveDiff) ne "" } {
                set ext [file extension $sPo(optSaveDiff)]
                set fmtStr [poImgType GetFmtByExt $ext]
                if { $fmtStr eq "" } {
                    puts "Error writing diff image: Extension $ext not supported."
                } else {
                    set optStr [poImgType GetOptByFmt $fmtStr "write"]
                    if { [poApps GetVerbose] } {
                        puts -nonewline "Writing difference image into file $sPo(optSaveDiff) ..." ; flush stdout
                    }
                    poWatch Reset batchTimer
                    if { $ext eq ".tga" || $ext eq ".rgb" || $ext eq ".rgba" } {
                        set vsn "ext"
                        set fmt "sgi"
                        if { $ext eq ".tga" } {
                            set fmt "targa"
                        }
                        poImgUtil compression_rgb $::RLE $::RLE $::RLE
                        poImgUtil SetFormatRGB $::UBYTE $::UBYTE $::UBYTE
                        set retVal [catch { $img(left) WriteImage $sPo(optSaveDiff) $fmt $vsn]} err]
                        if { $retVal != 0 } {
                            puts "\nCan't write image $imgFile ($err)"
                            return 7
                        }
                    } else {
                        # We do not need the right image anymore. Delete it, so we have more memory
                        # for the additional photo image to write out the difference image.
                        poImgUtil DeleteImg $img(right)
                        set phImg [image create photo]
                        $img(left) AsPhoto $phImg [list $::RED $::GREEN $::BLUE]
                        $phImg write $sPo(optSaveDiff) -format [list $fmtStr {*}$optStr]
                        image delete $phImg
                    }
                    if { [poApps GetVerbose] } {
                        puts [format " (Time: %.2f seconds)" [poWatch Lookup batchTimer]]
                    }
                }
            }
        }

        # Print out the status of the comparison, set the exit status and quit.
        if { [poApps GetVerbose] } {
            puts -nonewline "Images are equal: "
            if { $numDiffPixels != 0 } {
                puts "NO ($numDiffPixels pixels differ)"
            } else {
                puts "YES"
            }
        }

        if { $numDiffPixels != 0 } {
            return 1
        } else {
            return 0
        }
    }

    proc ParseCommandLine { argList } {
        variable sPo

        set leftFileToOpen  ""
        set rightFileToOpen ""
        set curArg 0
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "showdiff" } {
                    set sPo(optShowDiffOnStartup) true
                } elseif { $curOpt eq "rawdiff" } {
                    set sPo(optRawDiff) true
                } elseif { $curOpt eq "poimg" } {
                    set sPo(optUsePoImg) true
                } elseif { $curOpt eq "threshold" } {
                    incr curArg
                    set sPo(optThresh) [poMisc Max 0 [lindex $argList $curArg]]
                } elseif { $curOpt eq "savediff" } {
                    incr curArg
                    set sPo(optSaveDiff) [lindex $argList $curArg]
                } elseif { $curOpt eq "savehist" } {
                    incr curArg
                    set sPo(optSaveHisto) [lindex $argList $curArg]
                }
            } else {
                if { [poMisc IsReadableFile $curParam] } {
                    if { $leftFileToOpen eq "" } {
                        set leftFileToOpen [file normalize $curParam]
                    } else {
                        set rightFileToOpen [file normalize $curParam]
                    }
                }
            }
            incr curArg
        }
        if { [poApps UseBatchMode] } {
            set exitStatus [BatchProcess $leftFileToOpen $rightFileToOpen]
            exit $exitStatus
        }

        if { $leftFileToOpen ne "" } {
            if { [file isfile $leftFileToOpen] } {
                ReadImg $leftFileToOpen left
            } elseif { [file isdirectory $leftFileToOpen] } {
                poWinSelect SetValue $sPo(left,fileCombo) $leftFileToOpen
            }
        }
        if { $rightFileToOpen ne "" } {
            if { [file isfile $rightFileToOpen] } {
                ReadImg $rightFileToOpen right
            } elseif { [file isdirectory $rightFileToOpen] } {
                poWinSelect SetValue $sPo(right,fileCombo) $rightFileToOpen
            }
        }
        ShowDiffImgOnStartup

        WriteInfoStr $sPo(initStr) $sPo(initType)
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poImgdiff Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
