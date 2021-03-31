# Module:         poBitmap
# Copyright:      Paul Obermeier 2001-2020 / paul@poSoft.de
# First Version:  2001 / 05 / 21
#
# Distributed under BSD license.
#
# A simple editor for X-Windows bitmap files.
# Functionality is very similar to the standard bitmap application available on Unix systems,
# i.e. left mouse button sets pixel values, right mouse button clears pixel values.
# Additional features not available in "bitmap":
#   Generation of Tcl packages out of a series of bitmaps.
#   Save bitmaps in several formats (needs Img extension).


namespace eval poBitmap {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin ParseCommandLine IsOpen
    namespace export GetUsageMsg OpenBmp

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poBitmap"  ; # Name of toplevel window
        set sPo(appName) "poBitmap"   ; # Name of application
        set sPo(cfgDir)  ""           ; # Directory containing config files

        set sPo(startDir)  [pwd]        ; # Start directory

        set sPo(optConvert)   false
        set sPo(optScale)     1.0

        set sPo(conv,outFmtOpt) ""

        set sPo(clearWithLeft) 0

        set sPo(drawMode) 1
        set sPo(cursor,x) 0
        set sPo(cursor,y) 0

        poWatch Start swatch
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

    proc SetColors { onColor offColor gridColor cursorColor } {
        variable sPo

        set sPo(onColor)     $onColor
        set sPo(offColor)    $offColor
        set sPo(gridColor)   $gridColor
        set sPo(cursorColor) $cursorColor
    }

    proc GetColors {} {
        variable sPo

        return [list $sPo(onColor)     \
                     $sPo(offColor)    \
                     $sPo(gridColor)   \
                     $sPo(cursorColor)]
    }

    proc SetCurFile { curFile } {
        variable sPo

        set sPo(lastFile) $curFile
    }

    proc GetCurFile {} {
        variable sPo

        return [list $sPo(lastFile)]
    }

    proc SetPixelSize { pixsize } {
        variable sPo

        set sPo(bmp,pixsize) $pixsize
    }

    proc GetPixelSize {} {
        variable sPo

        return [list $sPo(bmp,pixsize)]
    }

    proc SetMiscModes { maxUndos maxBitmapSize } {
        variable sPo

        set sPo(maxUndo)       $maxUndos
        set sPo(maxBitmapSize) $maxBitmapSize
    }

    proc GetMiscModes {} {
        variable sPo

        return [list $sPo(maxUndo) \
                     $sPo(maxBitmapSize)]
    }

    proc SetConversionParams { outputFormat outputName useOutputDir outputDir { outputNum 1 } } {
        variable sPo

        set sPo(conv,outFmt)    $outputFormat
        set sPo(conv,name)      $outputName
        set sPo(conv,useOutDir) $useOutputDir
        set sPo(conv,outDir)    $outputDir
        set sPo(conv,num)       $outputNum
    }

    proc GetConversionParams {} {
        variable sPo

        return [list $sPo(conv,outFmt)    \
                     $sPo(conv,name)      \
                     $sPo(conv,useOutDir) \
                     $sPo(conv,outDir)    \
                     $sPo(conv,num)]
    }

    proc SetExportPackage { packageName namespaceName versionString } {
        variable sPo

        set sPo(packageName)   $packageName
        set sPo(namespaceName) $namespaceName
        set sPo(versionString) $versionString
    }

    proc GetExportPackage {} {
        variable sPo

        return [list $sPo(packageName)   \
                     $sPo(namespaceName) \
                     $sPo(versionString)]
    }

    proc GetComboValue { comboId } {
        variable ns
        variable sPo

        set curVal [poWinSelect GetValue $comboId]
        if { [file isdirectory $curVal] } {
            OpenBrowseWin $curVal
        } elseif { [file isfile $curVal] } {
            OpenBmp $curVal
        }
        focus $sPo(tw)
    }

    proc UpdateMainTitle { { bmpChanged 0 } } {
        variable sPo

        set sPo(bmp,changed) $bmpChanged
        if { $bmpChanged } {
            set star "*"
        } else {
            set star ""
        }
        set msg [format "%s - %s (%s %s)" "poApps" \
            [poApps GetAppDescription $sPo(appName)] \
            [poAppearance CutFilePath $sPo(bmp,defName)] $star]
        wm title $sPo(tw) $msg
    }

    proc StartAppImgview {} {
        variable sPo

        set argList [list]
        if { [poMisc IsReadableFile $sPo(bmp,defName)] } {
            lappend argList $sPo(bmp,defName)
        }
        poApps StartApp poImgview $argList
    }

    proc StartAppImgBrowse {} {
        variable sPo

        set argList [list]
        if { [poMisc IsReadableFile $sPo(bmp,defName)] } {
            lappend argList [file dirname $sPo(bmp,defName)]
        }
        poApps StartApp poImgBrowse $argList
    }

    proc SetItemId { x y itemId } {
        variable sPo

        set sPo(bmp,itemId,$x,$y) $itemId
    }

    proc GetItemId { x y } {
        variable sPo

        return $sPo(bmp,itemId,$x,$y)
    }

    proc GetItemTag { x y } {
        return [format "x_%d_y_%d" $x $y]
    }

    proc GetCanvasId {} {
        variable sPo

        return $sPo(bmp,canvasId)
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

        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create 5 frames: The menu frame on top, category and search frame inside
        # temporary frame and the search result frame.
        ttk::frame $sPo(tw).toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).workfr
        pack $sPo(tw).toolfr -side top -fill x -anchor w
        pack $sPo(tw).workfr -side top -fill both -expand 1

        ttk::frame $sPo(tw).workfr.pixfr -relief groove -borderwidth 1 -padding 1
        ttk::frame $sPo(tw).workfr.imgfr -relief groove -borderwidth 1
        ttk::frame $sPo(tw).workfr.prefr
        ttk::frame $sPo(tw).workfr.statfr -borderwidth 1

        grid $sPo(tw).workfr.pixfr  -row 0 -column 0 -sticky news -columnspan 2
        grid $sPo(tw).workfr.prefr  -row 1 -column 0 -sticky news
        grid $sPo(tw).workfr.imgfr  -row 1 -column 1 -sticky news
        grid $sPo(tw).workfr.statfr -row 2 -column 0 -sticky news -columnspan 2
        grid rowconfigure $sPo(tw).workfr 1 -weight 1
        grid columnconfigure $sPo(tw).workfr 1 -weight 1

        # Create file selecting widget and labels for position information.
        set pixelFr $sPo(tw).workfr.pixfr
        ttk::frame $pixelFr.selFr
        ttk::separator $pixelFr.sep1 -orient vertical
        ttk::frame $pixelFr.posFr
        pack $pixelFr.selFr -anchor w -side left -expand 1 -fill x
        pack $pixelFr.sep1 -side left -padx 2 -fill y
        pack $pixelFr.posFr -anchor w -side left

        set sPo(fileCombo) [poWinSelect CreateFileSelect $pixelFr.selFr \
                            $sPo(lastFile) "open" ""]
        poWinSelect SetFileTypes $sPo(fileCombo) [poImgType GetSelBoxTypes]
        bind $sPo(fileCombo) <Key-Return>     "${ns}::GetComboValue $sPo(fileCombo)"
        bind $sPo(fileCombo) <<FileSelected>> "${ns}::GetComboValue $sPo(fileCombo)"

        ttk::label $pixelFr.posFr.l -text "Position:"
        ttk::label $pixelFr.posFr.ex -textvariable ${ns}::sPo(cursor,x) -width 4 -anchor e
        ttk::label $pixelFr.posFr.ey -textvariable ${ns}::sPo(cursor,y) -width 4 -anchor e
        pack $pixelFr.posFr.l -anchor w -side left
        pack $pixelFr.posFr.ex $pixelFr.posFr.ey -anchor e -side left

        # Create the canvas for drawing the bitmap.
        set canvasId [poWin CreateScrolledCanvas $sPo(tw).workfr.imgfr true \
                      "" -borderwidth 0 -relief sunken -closeenough 0]
        set sPo(bmp,canvasId) $canvasId
        CreateGrid $canvasId [GetBmpWidth] [GetBmpHeight] $sPo(bmp,pixsize)

        # Create a Drag-And-Drop binding for the image canvas.
        poDragAndDrop AddCanvasBinding $canvasId ${ns}::ReadBmpByDrop

        $canvasId bind rect <ButtonPress-1>   "${ns}::SetPixelByMouse %W %x %y 1"
        $canvasId bind rect <B1-Motion>       "${ns}::SetPixelByMouse %W %x %y 1"
        $canvasId bind rect <ButtonRelease-1> "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        if { $::tcl_platform(os) eq "Darwin" } {
            $canvasId bind rect <Control-ButtonPress-1>   "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <ButtonPress-2>           "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <B2-Motion>               "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <Control-B1-Motion>       "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <ButtonRelease-2>         "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
            $canvasId bind rect <Control-ButtonRelease-1> "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        } else {
            $canvasId bind rect <ButtonPress-3>   "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <B3-Motion>       "${ns}::SetPixelByMouse %W %x %y 0"
            $canvasId bind rect <ButtonRelease-3> "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        }

        # Create menus
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
        set toolMenu $hMenu.tool
        set settMenu $hMenu.sett
        set winMenu  $hMenu.win
        set helpMenu $hMenu.help
        $hMenu add cascade -menu $fileMenu -label File     -underline 0
        $hMenu add cascade -menu $editMenu -label Edit     -underline 0
        $hMenu add cascade -menu $toolMenu -label Tools    -underline 0
        $hMenu add cascade -menu $settMenu -label Settings -underline 0
        $hMenu add cascade -menu $winMenu  -label Window   -underline 0
        $hMenu add cascade -menu $helpMenu -label Help     -underline 0

        # Menu File
        menu $fileMenu -tearoff 0
        set sPo(openMenu)   $fileMenu.open
        set sPo(browseMenu) $fileMenu.browse

        poMenu AddCommand $fileMenu "New ..."    "Ctrl+N" ${ns}::NewBmp
        $fileMenu add cascade -label "Open"   -menu $sPo(openMenu)
        $fileMenu add cascade -label "Browse" -menu $sPo(browseMenu)

        menu $sPo(openMenu) -tearoff 0 -postcommand "${ns}::AddRecentFiles $sPo(openMenu)"
        poMenu AddCommand $sPo(openMenu) "Select ..." "Ctrl+O" ${ns}::OpenBmpFile
        $sPo(openMenu) add separator

        menu $sPo(browseMenu) -tearoff 0 -postcommand "${ns}::AddRecentDirs $sPo(browseMenu)"
        poMenu AddCommand $sPo(browseMenu) "Select ..." "Ctrl+B" ${ns}::AskBrowseDir
        $sPo(browseMenu) add separator

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Save ..." "Ctrl+S" ${ns}::SaveBmpFile

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }

        bind $sPo(tw) <Control-n> ${ns}::NewBmp
        bind $sPo(tw) <Control-o> ${ns}::OpenBmpFile
        bind $sPo(tw) <Control-b> ${ns}::AskBrowseDir
        bind $sPo(tw) <Control-s> ${ns}::SaveBmpFile

        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Edit
        menu $editMenu -tearoff 0
        poMenu AddCommand $editMenu "Undo"              "Ctrl+Z" "${ns}::Undo"
        poMenu AddCommand $editMenu "Redo"              "Ctrl+R" "${ns}::Redo"
        $editMenu add separator
        poMenu AddCommand $editMenu "Copy ..."          "Ctrl+C" "${ns}::AskCopyImg"
        poMenu AddCommand $editMenu "Cut ..."           "Ctrl+X" "${ns}::AskCutImg"
        poMenu AddCommand $editMenu "Paste ..."         "Ctrl+V" "${ns}::AskPasteImg"
        $editMenu add separator
        poMenu AddCommand $editMenu "Clear"             "Ctrl+-" "${ns}::ClearBmp"
        poMenu AddCommand $editMenu "Invert"            "Ctrl+," "${ns}::InvertBmp"
        $editMenu add separator
        poMenu AddCommand $editMenu "Flip horizontally" ""       "${ns}::FlipHori"
        poMenu AddCommand $editMenu "Flip vertically"   ""       "${ns}::FlipVert"
        $editMenu add separator
        poMenu AddCommand $editMenu "Rotate 90° left"   ""       "${ns}::Rot90Deg 0"
        poMenu AddCommand $editMenu "Rotate 90° right"  ""       "${ns}::Rot90Deg 1"
        $editMenu add separator
        poMenu AddCommand $editMenu "Shift left"        "Ctrl+H" "${ns}::ShiftBmp -1  0"
        poMenu AddCommand $editMenu "Shift right"       "Ctrl+L" "${ns}::ShiftBmp  1  0"
        poMenu AddCommand $editMenu "Shift up"          "Ctrl+K" "${ns}::ShiftBmp  0 -1"
        poMenu AddCommand $editMenu "Shift down"        "Ctrl+J" "${ns}::ShiftBmp  0  1"
        $editMenu add separator
        poMenu AddCommand $editMenu "Scale down by 2"   ""       "${ns}::ScaleBmp 0.5"
        poMenu AddCommand $editMenu "Scale up by 2"     ""       "${ns}::ScaleBmp 2.0"

        bind $sPo(tw) <Control-z>     "${ns}::Undo"
        bind $sPo(tw) <Control-r>     "${ns}::Redo"
        bind $sPo(tw) <Control-c>     "${ns}::AskCopyImg"
        bind $sPo(tw) <Control-x>     "${ns}::AskCutImg"
        bind $sPo(tw) <Control-v>     "${ns}::AskPasteImg"
        bind $sPo(tw) <Control-minus> "${ns}::ClearBmp"
        bind $sPo(tw) <Control-comma> "${ns}::InvertBmp"
        bind $sPo(tw) <Control-h>     "${ns}::ShiftBmp -1  0"
        bind $sPo(tw) <Control-l>     "${ns}::ShiftBmp  1  0"
        bind $sPo(tw) <Control-k>     "${ns}::ShiftBmp  0 -1"
        bind $sPo(tw) <Control-j>     "${ns}::ShiftBmp  0  1"
        bind $sPo(tw) <Left>          "${ns}::CursorLeft"
        bind $sPo(tw) <Right>         "${ns}::CursorRight"
        bind $sPo(tw) <Up>            "${ns}::CursorUp"
        bind $sPo(tw) <Down>          "${ns}::CursorDown"
        bind $sPo(tw) <Control-Left>  "${ns}::DrawPixel  0; ${ns}::CursorLeft"
        bind $sPo(tw) <Control-Right> "${ns}::DrawPixel  0; ${ns}::CursorRight"
        bind $sPo(tw) <Control-Up>    "${ns}::DrawPixel  0; ${ns}::CursorUp"
        bind $sPo(tw) <Control-Down>  "${ns}::DrawPixel  0; ${ns}::CursorDown"
        bind $sPo(tw) <Shift-Left>    "${ns}::ClearPixel 0; ${ns}::CursorLeft"
        bind $sPo(tw) <Shift-Right>   "${ns}::ClearPixel 0; ${ns}::CursorRight"
        bind $sPo(tw) <Shift-Up>      "${ns}::ClearPixel 0; ${ns}::CursorUp"
        bind $sPo(tw) <Shift-Down>    "${ns}::ClearPixel 0; ${ns}::CursorDown"
        bind $sPo(tw) <Control-KeyRelease-Left>  "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Control-KeyRelease-Right> "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Control-KeyRelease-Up>    "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Control-KeyRelease-Down>  "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Shift-KeyRelease-Left>    "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Shift-KeyRelease-Right>   "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Shift-KeyRelease-Up>      "${ns}::UpdatePreview; ${ns}::SaveUndoImg"
        bind $sPo(tw) <Shift-KeyRelease-Down>    "${ns}::UpdatePreview; ${ns}::SaveUndoImg"

        # Menu Tools
        menu $toolMenu -tearoff 0
        poMenu AddCommand $toolMenu "Circle ..."          "" ${ns}::ExecToolCircle
        poMenu AddCommand $toolMenu "Flood fill ..."      "" ${ns}::ExecToolFloodFill
        poMenu AddCommand $toolMenu "Rectangle ..."       "" ${ns}::ExecToolRectangle
        poMenu AddCommand $toolMenu "Horizontal line ..." "" ${ns}::ExecToolHorizontalLine
        poMenu AddCommand $toolMenu "Vertical line ..."   "" ${ns}::ExecToolVerticalLine

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        $settMenu add cascade -label "Application settings" -menu $appSettMenu
        menu $appSettMenu -tearoff 0
        poMenu AddCommand $appSettMenu "Miscellaneous" "" [list ${ns}::ShowSpecificSettWin "Miscellaneous"]
        poMenu AddCommand $appSettMenu "Color"         "" [list ${ns}::ShowSpecificSettWin "Color"]
        poMenu AddCommand $appSettMenu "Package"       "" [list ${ns}::ShowSpecificSettWin "Package"]

        $settMenu add cascade -label "Image settings" -menu $imgSettMenu
        menu $imgSettMenu -tearoff 0
        poMenu AddCommand $imgSettMenu "Appearance"          "" [list poSettings ShowImgSettWin "Appearance"]
        poMenu AddCommand $imgSettMenu "Image types"         "" [list poSettings ShowImgSettWin "Image types"]
        poMenu AddCommand $imgSettMenu "Image browser"       "" [list poSettings ShowImgSettWin "Image browser"]
        poMenu AddCommand $imgSettMenu "Slide show"          "" [list poSettings ShowImgSettWin "Slide show"]
        poMenu AddCommand $imgSettMenu "Zoom rectangle"      "" [list poSettings ShowImgSettWin "Zoom rectangle"]
        poMenu AddCommand $imgSettMenu "Selection rectangle" "" [list poSettings ShowImgSettWin "Selection rectangle"]
        poMenu AddCommand $imgSettMenu "Palette"             "" [list poSettings ShowImgSettWin "Palette"]

        $settMenu add cascade -label "General settings" -menu $genSettMenu
        menu $genSettMenu -tearoff 0
        poMenu AddCommand $genSettMenu "Appearance"   "" [list  poSettings ShowGeneralSettWin "Appearance"]
        poMenu AddCommand $genSettMenu "File types"   "" [list  poSettings ShowGeneralSettWin "File types"]
        poMenu AddCommand $genSettMenu "Edit/Preview" "" [list  poSettings ShowGeneralSettWin "Edit/Preview"]
        poMenu AddCommand $genSettMenu "Logging"      "" [list  poSettings ShowGeneralSettWin "Logging"]

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
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" "poApps StartApp poBitmap" -state disabled
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgdiff]   "" "poApps StartApp poImgdiff"
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

        poToolbar AddButton $toolfr [::poBmpData::newfile] \
                  ${ns}::NewBmp "New bitmap ... (Ctrl+N)"
        poToolbar AddButton $toolfr [::poBmpData::open] \
                  ${ns}::OpenBmpFile "Open bitmap file ... (Ctrl+O)"
        poToolbar AddButton $toolfr [::poBmpData::browse] \
                  ${ns}::AskBrowseDir "Browse directory for bitmaps ... (Ctrl+B)"
        poToolbar AddButton $toolfr [::poBmpData::save] \
                  ${ns}::SaveBmpFile "Save bitmap to file ...(Ctrl+S)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::undo] ${ns}::Undo "Undo (Ctrl+Z)"
        poToolbar AddButton $toolfr [::poBmpData::redo] ${ns}::Redo "Redo (Ctrl+R)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::copy] \
                  ${ns}::AskCopyImg "Copy bitmap ... (Ctrl+C)"
        poToolbar AddButton $toolfr [::poBmpData::cut] \
                  ${ns}::AskCutImg "Cut bitmap ... (Ctrl+X)"
        poToolbar AddButton $toolfr [::poBmpData::paste] \
                  ${ns}::AskPasteImg "Paste bitmap ... (Ctrl+V)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::circle] \
                  ${ns}::ExecToolCircle "Draw circle ..."
        poToolbar AddButton $toolfr [::poBmpData::center] \
                  ${ns}::ExecToolFloodFill "Flood fill ..."
        poToolbar AddButton $toolfr [::poBmpData::rectangle] \
                  ${ns}::ExecToolRectangle "Draw rectangle ..."
        poToolbar AddButton $toolfr [::poBmpData::horiline] \
                  ${ns}::ExecToolHorizontalLine "Draw horizontal line ..."
        poToolbar AddButton $toolfr [::poBmpData::vertline] \
                  ${ns}::ExecToolVerticalLine "Draw vertical line ..."

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr true

        poToolbar AddButton $toolfr [::poBmpData::clear] \
                  ${ns}::ClearBmp "Clear bitmap (Ctrl+-)"
        poToolbar AddButton $toolfr [::poBmpData::invert] \
                  ${ns}::InvertBmp "Invert bitmap (Ctrl+,)"
        poToolbar AddButton $toolfr [::poBmpData::fliphori] \
                  ${ns}::FlipHori "Flip bitmap horizontally"
        poToolbar AddButton $toolfr [::poBmpData::flipvert] \
                  ${ns}::FlipVert "Flip bitmap vertically"
        poToolbar AddButton $toolfr [::poBmpData::rotateleft] \
                  "${ns}::Rot90Deg 0" "Rotate bitmap left by 90 degrees"
        poToolbar AddButton $toolfr [::poBmpData::rotateright] \
                  "${ns}::Rot90Deg 1" "Rotate bitmap right by 90 degrees"
        poToolbar AddButton $toolfr [::poBmpData::left] \
                  "${ns}::ShiftBmp -1 0" "Shift bitmap left (Ctrl+H)"
        poToolbar AddButton $toolfr [::poBmpData::right] \
                  "${ns}::ShiftBmp 1 0" "Shift bitmap right (Ctrl+L)"
        poToolbar AddButton $toolfr [::poBmpData::up] \
                  "${ns}::ShiftBmp 0 -1" "Shift bitmap up (Ctrl+K)"
        poToolbar AddButton $toolfr [::poBmpData::down] \
                  "${ns}::ShiftBmp 0 1" "Shift bitmap down (Ctrl+J)"
        poToolbar AddButton $toolfr [::poBmpData::smaller] \
                  "${ns}::ScaleBmp 0.5" "Scale bitmap down by 2"
        poToolbar AddButton $toolfr [::poBmpData::larger] \
                  "${ns}::ScaleBmp 2.0" "Scale bitmap up by 2"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddCheckButton $toolfr [::poBmpData::clear] \
                  "" "Clear with left mouse" -variable ${ns}::sPo(clearWithLeft)

        # Create widget for status messages.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).workfr.statfr]

        set normalImg [image create photo -width [GetBmpWidth] -height [GetBmpHeight]]
        set invertImg [image create photo -width [GetBmpWidth] -height [GetBmpHeight]]
        $normalImg blank
        $invertImg blank

        set normalLabel $sPo(tw).workfr.prefr.normal
        set invertLabel $sPo(tw).workfr.prefr.invert
        label $normalLabel -image $normalImg -borderwidth 0 -background $sPo(offColor)
        label $invertLabel -image $invertImg -borderwidth 0 -background $sPo(onColor)
        pack $normalLabel $invertLabel -padx 4 -pady 2

        set sPo(bmp,imgNormal)   $normalImg
        set sPo(bmp,imgInvert)   $invertImg
        set sPo(bmp,labelNormal) $normalLabel
        set sPo(bmp,labelInvert) $invertLabel

        UpdateMainTitle
        WriteInfoStr $sPo(initStr)

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
    }

    proc AddRecentFiles { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentFileList $menuId ${ns}::OpenBmp
    }

    proc AddRecentDirs { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentDirList $menuId ${ns}::OpenBrowseWin 
    }

    proc OKToplevel { tw args } {
        variable sPo

        destroy $tw
        PreviewNewSize
        CreateBmpFromImg $sPo(bmp,imgNormal)
    }

    proc CancelToplevel { tw args } {
        variable sPo

        poToolhelp HideToolhelp
        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        destroy $tw
    }

    proc GetColor { labelId colorType } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo($colorType)]
        if { $newColor ne "" } {
            set sPo($colorType) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc ShowMiscTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Max Undos:" \
                           "Max number of pixels:" \
                           "Pixel size:" } {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList {}
        set row -1

        # Generate right column with entries and buttons.

        # Max Undo settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(maxUndo)
        pack $tw.fr$row.e -side top -fill both -expand 1 \
             -padx 3 -pady 3 -in $tw.fr$row

        set tmpList [list [list sPo(maxUndo)] [list $sPo(maxUndo)]]
        lappend varList $tmpList

        # Max bitmap size settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(maxBitmapSize)
        pack $tw.fr$row.e -side top -fill both -expand 1 \
             -padx 3 -pady 3 -in $tw.fr$row
        poToolhelp AddBinding $tw.fr$row.e "This value will be taken squared"

        set tmpList [list [list sPo(maxBitmapSize)] [list $sPo(maxBitmapSize)]]
        lappend varList $tmpList

        # Pixel size settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(bmp,pixsize)
        pack $tw.fr$row.e -side top -fill both -expand 1 \
             -padx 3 -pady 3 -in $tw.fr$row

        set tmpList [list [list sPo(bmp,pixsize)] [list $sPo(bmp,pixsize)]]
        lappend varList $tmpList

        return $varList
    }

    proc ShowColorTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Color for grid lines:" \
                           "Color for opaque pixel:" \
                           "Color for transparent pixel:" \
                           "Color for cursor outline:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Note: The next labels should not be ttk labels, because
        # the background color of ttk labels can not be set on Mac.

        set varList {}
        # Generate right column with entries and buttons.
        # Part 1: Grid Color settings
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l1 -width 10 -relief sunken -background $sPo(gridColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                                  -command "${ns}::GetColor $tw.fr$row.l1 gridColor"
        poToolhelp AddBinding $tw.fr$row.b1 "Click to select new color"
        pack $tw.fr$row.l1 $tw.fr$row.b1 \
             -side left -fill both -expand 1 -padx 2 -pady 2

        # Part 2: On Color settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l1 -width 10 -relief sunken -background $sPo(onColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                                  -command "${ns}::GetColor $tw.fr$row.l1 onColor"
        poToolhelp AddBinding $tw.fr$row.b1 "Click to select new color"
        pack $tw.fr$row.l1 $tw.fr$row.b1 \
             -side left -fill both -expand 1 -padx 2 -pady 2

        # Part 3: Off Color settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l1 -width 10 -relief sunken -background $sPo(offColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                                  -command "${ns}::GetColor $tw.fr$row.l1 offColor"
        poToolhelp AddBinding $tw.fr$row.b1 "Click to select new color"
        pack $tw.fr$row.l1 $tw.fr$row.b1 \
             -side left -fill both -expand 1 -padx 2 -pady 2

        # Part 4: Cursor Color settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label  $tw.fr$row.l1 -width 10 -relief sunken -background $sPo(cursorColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                                  -command "${ns}::GetColor $tw.fr$row.l1 cursorColor"
        poToolhelp AddBinding $tw.fr$row.b1 "Click to select new color"
        pack $tw.fr$row.l1 $tw.fr$row.b1 \
             -side left -fill both -expand 1 -padx 2 -pady 2

        set tmpList [list [list sPo(gridColor)] [list $sPo(gridColor)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(onColor)] [list $sPo(onColor)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(offColor)] [list $sPo(offColor)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(cursorColor)] [list $sPo(cursorColor)]]
        lappend varList $tmpList
        return $varList
    }

    proc ShowSpecificSettWin { { selectTab "Miscellaneous" } } {
        variable sPo
        variable ns

        set tw .poBitmap_specWin
        set sPo(specWin,name) $tw

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Bitmap editor specific settings"
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

        ttk::frame $nb.colorFr
        set tmpList [ShowColorTab $nb.colorFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.colorFr -text "Color" -underline 0 -padding 2
        if { $selectTab eq "Color" } {
            set selTabInd 1
        }
        $nb select $selTabInd

        ttk::frame $nb.packageFr
        set tmpList [ShowPackageTab $nb.packageFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.packageFr -text "Package" -underline 0 -padding 2
        if { $selectTab eq "Package" } {
            set selTabInd 2
        }
        $nb select $selTabInd

        # Create Cancel and OK buttons
        ttk::frame $tw.frOk
        pack $tw.frOk -side bottom -fill x

        ttk::button $tw.frOk.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                -compound left -command "${ns}::CancelToplevel $tw $varList"
        bind $tw <KeyPress-Escape> "${ns}::CancelToplevel $tw $varList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelToplevel $tw $varList"

        ttk::button $tw.frOk.b2 -text "OK" -image [poWin GetOkBitmap] \
                -compound left -command "${ns}::OKToplevel $tw" -default active
        pack $tw.frOk.b1 $tw.frOk.b2 -side left -fill x -padx 10 -pady 2 -expand 1
        focus $tw
    }

    proc CreateGrid { canvasId bmpWidth bmpHeight pixsize } {
        variable sPo

        $canvasId delete rect
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
            set sPo(bmp,$x,$y) 0
            set x1 [expr {$x  * $pixsize}]
            set x2 [expr {$x1 + $pixsize}]
            set y1 [expr {$y  * $pixsize}]
            set y2 [expr {$y1 + $pixsize}]
            SetItemId $x $y \
                [$canvasId create rectangle $x1 $y1 $x2 $y2 \
                           -outline $sPo(gridColor) -fill $sPo(offColor) \
                           -tags [list [GetItemTag $x $y] "rect"]]
            }
        }
        $canvasId configure -width [expr {$bmpWidth * $pixsize}] \
                            -height [expr {$bmpHeight * $pixsize}]
        $canvasId configure -scrollregion \
            "0 0 [expr {$bmpWidth * $pixsize}] [expr {$bmpHeight * $pixsize}]"
    }

    proc ScaleBmp { scaleFactor } {
        variable sPo

        set newWidth  [expr {int ([GetBmpWidth]  * $scaleFactor)}]
        set newHeight [expr {int ([GetBmpHeight] * $scaleFactor)}]
        if { $newWidth < 1 || $newHeight < 1 } {
            return
        }
        set newImg [image create photo -width $newWidth -height $newHeight]
        $newImg blank
        if { $scaleFactor > 1 } {
            $newImg copy $sPo(bmp,imgInvert) -zoom [expr {int ($scaleFactor)}]
        } else {
            set factor [expr { int (1.0 / $scaleFactor) }]
            $newImg copy $sPo(bmp,imgInvert) -subsample $factor $factor
        }
        SetBmpWidth  $newWidth
        SetBmpHeight $newHeight
        set retVal [catch { CreateBmpFromImg $newImg } err]
        if { $retVal == 0 } {
            PreviewNewSize
            MoveCursor 0 0
        } else {
            tk_messageBox -message "Can't scale bitmap $sPo(bmp,defName) ($err)." \
                                   -type ok -icon warning
        }
        image delete $newImg
    }

    proc ShiftBmp { sx sy } {
        variable sPo

        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        # Shift horizontally: sx > 0 is right, sx < 0 is left
        if { $sx > 0 } {
            set col 0
        } elseif { $sx < 0 } {
            set col [expr {$bmpWidth - 1}]
        }
        if { $sx != 0 } {
            if { $sx > 0 } {
                set xsize2 [expr {$bmpWidth - 2}]
                set xsize1 [expr {$bmpWidth - 1}]
                for { set y 0 } { $y < $bmpHeight } { incr y } {
                    set x1 $xsize2
                    for { set x $xsize1 } { $x > 0 } { incr x -1 } {
                        set sPo(bmp,$x,$y) $sPo(bmp,$x1,$y)
                        incr x1 -1
                    }
                }
            } else {
                set xsize1 [expr {$bmpWidth - 1}]
                for { set y 0 } { $y < $bmpHeight } { incr y } {
                    set x1 1
                    for { set x 0 } { $x < $xsize1 } { incr x 1 } {
                        set sPo(bmp,$x,$y) $sPo(bmp,$x1,$y)
                        incr x1 1
                    }
                }
            }
            for { set y 0 } { $y < $bmpHeight } { incr y } {
                set sPo(bmp,$col,$y) 0
            }
        }

        # Shift vertically: sy > 0 is down, sy < 0 is up
        if { $sy > 0 } {
            set row 0
        } elseif { $sy < 0 } {
            set row [expr {$bmpHeight - 1}]
        }

        if { $sy != 0 } {
            if { $sy > 0 } {
                set ysize1 [expr {$bmpHeight - 1}]
                set ysize2 [expr {$bmpHeight - 2}]
                for { set x 0 } { $x < $bmpWidth } { incr x } {
                    set y1 $ysize2
                    for { set y $ysize1 } { $y > 0 } { incr y -1 } {
                        set sPo(bmp,$x,$y) $sPo(bmp,$x,$y1)
                        incr y1 -1
                    }
                }
            } else {
                set ysize1 [expr {$bmpHeight - 1}]
                for { set x 0 } { $x < $bmpWidth } { incr x } {
                    set y1 1
                    for { set y 0 } { $y < $ysize1 } { incr y 1 } {
                        set sPo(bmp,$x,$y) $sPo(bmp,$x,$y1)
                        incr y1 1
                    }
                }
            }
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                set sPo(bmp,$x,$row) 0
            }
        }

        # Update the canvas rectangles.
        set canvasId [GetCanvasId]
        set onColor  $sPo(onColor)
        set offColor $sPo(offColor)

        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                SetRectOnOff $canvasId $x $y $sPo(bmp,$x,$y)
            }
        }
        UpdatePreview
        SaveUndoImg
    }

    proc SetPixelByMouse { w x y onOff } {
        variable sPo

        if { ! $sPo(drawMode) } {
            return
        }
        if { $onOff && $sPo(clearWithLeft) } {
            set onOff 0
        }
        set itemList [$w find closest [$w canvasx $x] [$w canvasy $y]]
        foreach item $itemList {
            set tagStr [lindex [$w gettags $item] 0]
            scan $tagStr "x_%d_y_%d" cx cy
            SetPixelOnOff $w $cx $cy $onOff
            GotoPixel $cx $cy
            MoveCursor 0 0
        }
    }

    proc Undo {} {
        variable sPo

        if { $sPo(undoNum) > 0 } {
            incr sPo(undoNum) -1
            CreateBmpFromImg $sPo(undo,$sPo(undoNum))
        } else {
            tk_messageBox -title "Information" -message "Nothing to Undo." \
                          -type ok -icon info
            focus $sPo(tw)
        }
        UpdatePreview
        MoveCursor 0 0
    }

    proc Redo {} {
        variable sPo

        if { $sPo(undoNum) < $sPo(maxUndo) && \
             [info exists sPo(undo,[expr {$sPo(undoNum) + 1}])] } {
            incr sPo(undoNum)
            CreateBmpFromImg $sPo(undo,$sPo(undoNum))
        } else {
            tk_messageBox -title "Information" -message "Nothing to Redo." \
                          -type ok -icon info
            focus $sPo(tw)
        }
        UpdatePreview
        MoveCursor 0 0
    }

    proc ShowUndoImgs {} {
        variable sPo

        catch { destroy .sui}
        toplevel .sui
        for { set i 0 } { $i <= $sPo(undoNum) } { incr i } {
            label .sui.n$i -text "$i: $sPo(undo,$i)"
            label .sui.l$i -image $sPo(undo,$i) -bg black
            grid .sui.n$i -row $i -column 0
            grid .sui.l$i -row $i -column 1
        }
    }

    proc CutImg { xtl ytl xbr ybr } {
        set canvasId [GetCanvasId]
        CopyImg $xtl $ytl $xbr $ybr
        for { set y $ytl } { $y <= $ybr } { incr y } {
            for { set x $xtl } { $x <= $xbr } { incr x } {
                SetPixelOnOff $canvasId $x $y 0
            }
        }
        UpdatePreview
        SaveUndoImg
        MoveCursor 0 0
    }

    proc CopyImg { xtl ytl xbr ybr } {
        variable sPo

        if { [info exists sPo(imgBuf)] } {
            image delete $sPo(imgBuf)
        }

        set sPo(imgBuf) [image create photo]
        $sPo(imgBuf) blank
        poLog Info "Copy image area ($xtl, $ytl) ($xbr, $ybr) into buffer."
        $sPo(imgBuf) copy $sPo(bmp,imgInvert) \
                    -from $xtl $ytl [expr {$xbr + 1}] [expr {$ybr + 1}]
    }

    proc AskCutImg {} {
        set topLeft [GetMousePos "Cut: Select top-left corner of area"]
        if { [llength $topLeft] != 0 } {
            set bottomRight [GetMousePos "Cut: Select bottom-right corner of area"]
            if { [llength $bottomRight] != 0 } {
                set x1 [lindex $topLeft 0]
                set y1 [lindex $topLeft 1]
                set x2 [lindex $bottomRight 0]
                set y2 [lindex $bottomRight 1]
                set xtl [poMisc Min $x1 $x2]
                set ytl [poMisc Min $y1 $y2]
                set xbr [poMisc Max $x1 $x2]
                set ybr [poMisc Max $y1 $y2]
                CutImg $xtl $ytl $xbr $ybr
            } else {
                WriteInfoStr "Cutting not possible: No bottom-right corner specified." "Error"
            }
        } else {
            WriteInfoStr "Cuting not possible: No top-left corner specified." "Error"
        }
    }

    proc AskCopyImg {} {
        set topLeft [GetMousePos "Copy: Select top-left corner of area"]
        if { [llength $topLeft] != 0 } {
            set bottomRight [GetMousePos "Copy: Select bottom-right corner of area"]
            if { [llength $bottomRight] != 0 } {
                set x1 [lindex $topLeft 0]
                set y1 [lindex $topLeft 1]
                set x2 [lindex $bottomRight 0]
                set y2 [lindex $bottomRight 1]
                set xtl [poMisc Min $x1 $x2]
                set ytl [poMisc Min $y1 $y2]
                set xbr [poMisc Max $x1 $x2]
                set ybr [poMisc Max $y1 $y2]
                CopyImg $xtl $ytl $xbr $ybr
            } else {
                WriteInfoStr "Copying not possible: No bottom-right corner specified." "Error"
            }
        } else {
            WriteInfoStr "Copying not possible: No top-left corner specified." "Error"
        }
    }

    proc PasteImg { xtl ytl } {
        variable sPo

        poLog Info "Pasting image area to ($xtl, $ytl) from buffer."
        if { ! [info exists sPo(imgBuf)] } {
            return
        }
        set canvasId  [GetCanvasId]
        set bmpWidth  [image width  $sPo(imgBuf)]
        set bmpHeight [image height $sPo(imgBuf)]
        for { set yd $ytl ; set ys 0 } \
            { $yd < [expr {$bmpHeight + $ytl}] } \
            { incr yd ; incr ys } {
            if { $yd >= [GetBmpHeight] } {
                break
            }
            for { set xd $xtl ; set xs 0 } \
                { $xd < [expr {$bmpWidth + $xtl}] } \
                { incr xd ; incr xs } {
                if { $xd >= [GetBmpWidth] } {
                    break
                }
                set alpha [$sPo(imgBuf) transparency get $xs $ys]
                set onOff [expr { $alpha == 0 }]
                SetPixelOnOff $canvasId $xd $yd $onOff
            }
        }
        UpdatePreview
        SaveUndoImg
        MoveCursor 0 0
    }

    proc AskPasteImg {} {
        set topLeft [GetMousePos "Paste: Select top-left corner of area"]
        if { [llength $topLeft] != 0 } {
            PasteImg [lindex $topLeft 0] [lindex $topLeft 1]
        } else {
            WriteInfoStr "Pasting not possible: No top-left corner specified." "Error"
        }
    }

    proc SaveUndoImg {} {
        variable sPo

        incr sPo(undoNum)
        if { $sPo(undoNum) >= $sPo(maxUndo) } {
            set sPo(undoNum) [expr {$sPo(maxUndo) - 1}]
            image delete $sPo(undo,0)
            for { set n 0 } { $n < $sPo(undoNum) } { incr n } {
                set n1 [expr {$n + 1}]
                set sPo(undo,$n) $sPo(undo,$n1)
            }
        }
        UpdateMainTitle 1

        set sPo(undo,$sPo(undoNum)) [image create photo]
        poLog Info "Saving image for undo no $sPo(undoNum) ($sPo(undo,$sPo(undoNum)))"
        $sPo(undo,$sPo(undoNum)) copy $sPo(bmp,imgInvert)
        # ShowUndoImgs
    }

    proc UpdatePreview {} {
        variable sPo

        $sPo(bmp,imgNormal) blank
        $sPo(bmp,imgInvert) blank
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                if { $sPo(bmp,$x,$y) } {
                    $sPo(bmp,imgNormal) put $sPo(onColor)  -to $x $y
                    $sPo(bmp,imgInvert) put $sPo(offColor) -to $x $y
                }
            }
        }
    }

    proc PreviewNewSize {} {
        variable sPo

        $sPo(bmp,labelNormal) configure -background $sPo(offColor)
        $sPo(bmp,labelInvert) configure -background $sPo(onColor)
        $sPo(bmp,imgNormal) configure -width [GetBmpWidth] -height [GetBmpHeight]
        $sPo(bmp,imgInvert) configure -width [GetBmpWidth] -height [GetBmpHeight]
        $sPo(bmp,imgNormal) blank
        $sPo(bmp,imgInvert) blank
        UpdatePreview
        SaveUndoImg
    }

    proc GetFileName { title { mode "open" } { initFile "" } } {
        variable ns
        variable sPo

        if { [poApps HavePkg "Img"] } {
            set fileTypes [poImgType GetSelBoxTypes]
        } else {
            set fileTypes {
                {"X Windows Bitmap" ".xbm"}
                {"All files"        "*"} 
            }
        }
        if { $mode eq "open" } {
            set fileName [tk_getOpenFile -filetypes $fileTypes \
                          -initialdir [file dirname $sPo(lastFile)] -title $title]
        } else {
            if { ! [info exists sPo(LastBitmapType)] } {
                set sPo(LastBitmapType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastBitmapType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }

            set fileName [tk_getSaveFile \
                         -filetypes $fileTypes \
                         -title $title \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastBitmapType) \
                         -initialfile [file tail $initFile] \
                         -initialdir [file dirname $sPo(lastFile)]]
            if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
                set ext [poMisc GetExtensionByType $fileTypes $sPo(LastBitmapType)]
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
        return $fileName
    }

    proc InvertBmp {} {
        set canvasId  [GetCanvasId]
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                SetPixelOnOff $canvasId $x $y [expr {[GetPixel $x $y] == 0}]
            }
        }
        UpdatePreview
        MoveCursor 0 0
        SaveUndoImg
    }

    proc FlipVert {} {
        variable sPo

        set canvasId  [GetCanvasId]
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        set yhalf [expr {$bmpHeight / 2}]
        for { set x 0 } { $x < $bmpWidth } { incr x } {
            set y2 [expr {$bmpHeight - 1}]
            for { set y1 0 } { $y1 < $yhalf } { incr y1 } {
                set tmp $sPo(bmp,$x,$y1)
                set sPo(bmp,$x,$y1) $sPo(bmp,$x,$y2)
                set sPo(bmp,$x,$y2) $tmp
                SetRectOnOff $canvasId $x $y1 [expr {[GetPixel $x $y1] != 0}]
                SetRectOnOff $canvasId $x $y2 [expr {[GetPixel $x $y2] != 0}]
                incr y2 -1
            }
        }
        UpdatePreview
        MoveCursor 0 0
        SaveUndoImg
    }

    proc FlipHori {} {
        variable sPo

        set canvasId  [GetCanvasId]
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        set xhalf [expr {$bmpWidth / 2}]
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            set x2 [expr {$bmpWidth - 1}]
            for { set x1 0 } { $x1 < $xhalf } { incr x1 } {
                set tmp $sPo(bmp,$x1,$y)
                set sPo(bmp,$x1,$y) $sPo(bmp,$x2,$y)
                set sPo(bmp,$x2,$y) $tmp
                SetRectOnOff $canvasId $x1 $y [expr {[GetPixel $x1 $y] != 0}]
                SetRectOnOff $canvasId $x2 $y [expr {[GetPixel $x2 $y] != 0}]
                incr x2 -1
            }
        }
        UpdatePreview
        MoveCursor 0 0
        SaveUndoImg
    }

    proc Rot90Deg { clockwise } {
        variable sPo

        set canvasId  [GetCanvasId]
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        if { $clockwise } {
            set x0 0
            set ynew [expr {$bmpHeight - 1}]
            set dx 1
            set dy -1
        } else {
            set x0 [expr {$bmpWidth - 1}]
            set ynew 0
            set dx -1
            set dy 1
        }
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            set xnew $x0
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                set new($ynew,$xnew) $sPo(bmp,$x,$y)
                # puts "($y,$x) --> ($ynew,$xnew)"
                incr xnew $dx
            }
            incr ynew $dy
        }

        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                set sPo(bmp,$x,$y) $new($x,$y)
                SetRectOnOff $canvasId $x $y [expr {[GetPixel $x $y] != 0}]
            }
        }
        UpdatePreview
        MoveCursor 0 0
        SaveUndoImg
    }

    proc ClearBmp {} {
        variable sPo

        CreateGrid [GetCanvasId] [GetBmpWidth] [GetBmpHeight] $sPo(bmp,pixsize)
        set sPo(bmp,defName) "untitled.xbm"
        UpdatePreview
        MoveCursor 0 0
        SaveUndoImg
    }

    proc CreateNewBitmap {} {
        variable sPo

        SetBmpWidth  $sPo(new,w)
        SetBmpHeight $sPo(new,h)
        set sPo(bmp,pixsize) $sPo(new,s)
        CreateGrid [GetCanvasId] [GetBmpWidth] [GetBmpHeight] $sPo(bmp,pixsize)
        set sPo(bmp,defName) "untitled.xbm"
        DestroyNewBitmapWin
        PreviewNewSize
        MoveCursor 0 0
        UpdateMainTitle
    }

    proc ShowNewBitmapWin { cmd title { noChars 20 } } {
        variable sPo
        variable ns

        set tw .poBitmap:newBitmapWin

        set x [winfo pointerx $sPo(tw)]
        set y [winfo pointery $sPo(tw)]
        set fmtStr [format "+%d+%d" [expr {$x - 40}] [expr {$y - 10}]]

        if { [winfo exists $tw] } {
            poWin Raise $tw
            wm geometry $tw $fmtStr
            return
        }

        toplevel $tw
        wm title $tw $title
        wm resizable $tw false false
        wm geometry $tw $fmtStr

        set row 0
        foreach labelStr { "Width:" \
                           "Height:" \
                           "Pixel size:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky news
            incr row
        }

        # Generate right column with entries.
        set row 0
        ttk::entry $tw.e$row -textvariable ${ns}::sPo(new,w)
        $tw.e$row configure -width $noChars
        $tw.e$row selection range 0 end
        bind  $tw.e$row <KeyPress-Return> "$cmd"
        bind  $tw.e$row <KeyPress-Escape> ${ns}::DestroyNewBitmapWin
        grid  $tw.e$row -row $row -column 1 -sticky news

        incr row
        ttk::entry $tw.e$row -textvariable ${ns}::sPo(new,h)
        $tw.e$row configure -width $noChars
        bind  $tw.e$row <KeyPress-Return> "$cmd"
        bind  $tw.e$row <KeyPress-Escape> ${ns}::DestroyNewBitmapWin
        grid  $tw.e$row -row $row -column 1 -sticky news

        incr row
        ttk::entry $tw.e$row -textvariable ${ns}::sPo(new,s)
        $tw.e$row configure -width $noChars
        bind  $tw.e$row <KeyPress-Return> "$cmd"
        bind  $tw.e$row <KeyPress-Escape> ${ns}::DestroyNewBitmapWin
        grid  $tw.e$row -row $row -column 1 -sticky news

        incr row
        ttk::frame $tw.fr$row
        grid  $tw.fr$row -row $row -column 0 -columnspan 2 -sticky news -pady 2
        ttk::button $tw.fr$row.b1 -text "Cancel" -command ${ns}::DestroyNewBitmapWin
        ttk::button $tw.fr$row.b2 -text "OK"     -command $cmd -default active
        pack $tw.fr$row.b1 $tw.fr$row.b2 -side left -expand 1 -fill x

        focus $tw.e0
    }

    proc DestroyNewBitmapWin {} {
        destroy .poBitmap:newBitmapWin
    }

    proc NewBmp {} {
        variable ns

        ShowNewBitmapWin ${ns}::CreateNewBitmap "New bitmap"
    }

    proc SaveBmpPackage { fileList outFile packageName namespaceName versionNum } {
        set retVal [catch {open $outFile w} fp]
        if { $retVal != 0 } {
            error "Could not open output file $outFile"
        }
        fconfigure $fp -translation lf

        # Write usage info about pkgIndex.tcl
        puts $fp "# Put the following line into a pkgIndex.tcl file:"
        puts $fp "# package ifneeded $packageName $versionNum \"source \[file join \$dir [file tail $outFile]\]\""
        puts $fp ""

        # Write package header.
        puts $fp "package provide $packageName $versionNum"
        puts $fp ""

        # Write namespace header.
        puts $fp "namespace eval $namespaceName {"
        puts $fp "    namespace ensemble create"
        puts $fp ""
        foreach fileName $fileList {
            set bmpName [file rootname [file tail $fileName]]
            if { [poMisc IsReadableFile $fileName] } {
                puts $fp "    namespace export _${bmpName}"
                puts $fp "    namespace export ${bmpName}"
            }
        }
        puts $fp "}"
        puts $fp ""

        # Generate namespace procedures.
        foreach fileName $fileList {
            set bmpName  [file rootname [file tail $fileName]]
            set dataProcName [format "%s::_%s" $namespaceName $bmpName]
            set imgProcName  [format "%s::%s"  $namespaceName $bmpName]

            set retVal [catch {open $fileName r} inFp]
            if { $retVal == 0 } {
                fconfigure $inFp -translation binary
                puts $fp "proc $dataProcName \{\} \{"
                puts $fp "return \{"
                puts -nonewline $fp [read $inFp]
                puts $fp "\}"
                puts $fp "\} \; \# End of proc $dataProcName"
                puts $fp ""
                puts $fp "proc $imgProcName \{ \{foreground \"black\"\} \{background \"\"\} \} \{"
                puts $fp "    return \[image create bitmap -data \[$dataProcName\] -background \$background -foreground \$foreground\]"
                puts $fp "\}"
                puts $fp ""
                close $inFp
            } else {
                poLog Warning "File $fileName does not exist."
            }
        }
        close $fp
    }

    proc GetBmpPackageFile { dir } {
        variable ns
        variable sPo

        set fileTypes {
            {"Tcl files" ".tcl"}
            {"All files" "*"}
        }
        if { [llength [GetSelBmps]] == 0 } {
            return
        }

        if { ! [info exists sPo(LastBmpPackageType)] } {
            set sPo(LastBmpPackageType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastBmpPackageType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save bitmap package as" \
                     -parent $sPo(tw) \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sPo(LastBmpPackageType) \
                     -initialfile [file tail $sPo(packageName)] \
                     -initialdir [file dirname $sPo(lastFile)]]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sPo(LastBmpPackageType)]
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
            SaveBmpPackage [GetSelBmps] $fileName $sPo(packageName) \
                           $sPo(namespaceName) $sPo(versionString)
        }
    }

    proc ShowPackageTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "Package name:" \
                           "Namespace name:" \
                           "Version string:" ] {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList {}
        set xpad 2
        set ypad 3

        # Row 0: Package name
        set row 0
        ttk::frame $tw.fr$row
        grid  $tw.fr$row -row $row -column 1 -sticky new
        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(packageName) -width 20
        pack  $tw.fr$row.e -anchor w -in $tw.fr$row -padx $xpad -pady $ypad

        set tmpList [list [list sPo(packageName)] [list $sPo(packageName)]]
        lappend varList $tmpList

        # Row 1: Namespace name
        incr row
        ttk::frame $tw.fr$row
        grid  $tw.fr$row -row $row -column 1 -sticky new
        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(namespaceName) -width 20
        pack  $tw.fr$row.e -anchor w -in $tw.fr$row -padx $xpad -pady $ypad

        set tmpList [list [list sPo(namespaceName)] [list $sPo(namespaceName)]]
        lappend varList $tmpList

        # Row 2: Version string
        incr row
        ttk::frame $tw.fr$row
        grid  $tw.fr$row -row $row -column 1 -sticky new
        ttk::entry $tw.fr$row.e -textvariable ${ns}::sPo(versionString) -width 20
        pack  $tw.fr$row.e -anchor w -in $tw.fr$row -padx $xpad -pady $ypad

        set tmpList [list [list sPo(versionString)] [list $sPo(versionString)]]
        lappend varList $tmpList
        return $varList
    }

    proc GetSelBmps {} {
        variable sBmpList

        set fileList {}
        foreach f [lsort [array names sBmpList]] {
            if { $sBmpList($f) } {
                lappend fileList $f
            }
        }
        return $fileList
    }

    proc OpenSelBmps {} {
        if { [llength [GetSelBmps]] != 0 } {
            OpenBmp [lindex [GetSelBmps] 0]
        }
    }

    proc DelSelBmps { tw fr dir } {
        variable sBmpList

        set noSel [llength [GetSelBmps]]
        if { $noSel == 0 } {
            return
        }
        set retVal [tk_messageBox \
          -title "Delete confirmation" \
          -message "Delete the $noSel selected bitmap files ?" \
          -type yesno -default no -icon question]
        if { $retVal eq "no" } {
            return
        }
        foreach f [GetSelBmps] {
            file delete $f
            unset sBmpList($f)
        }
        UpdateBmpDir $tw $fr $dir
        focus $tw
    }

    proc SelAllBmps {} {
        SelUnselAllBmps 1
    }

    proc UnselAllBmps {} {
        SelUnselAllBmps 0
    }

    proc SelUnselAllBmps { onOff } {
        variable sBmpList

        foreach f [array names sBmpList] {
            set sBmpList($f) $onOff
        }
    }

    proc UpdateBmpDir { tw fr dir } {
        variable ns
        variable sBmpList

        set i 0
        set r 0
        set c 0

        catch {destroy $fr}
        ttk::frame $fr -relief sunken
        pack  $fr -side top -fill both -expand 1 -pady 2
        set bmpfr [poWin CreateScrolledFrame $fr true "Bitmap listing"]

        set extStr ""
        foreach ext [poImgType GetExtList "XBM"] {
            append extStr [format "*%s " $ext]
        }

        set bmpFileList [lsort -dictionary [lindex \
                                [poMisc GetDirsAndFiles $dir \
                                        -showdirs false \
                                        -filepattern $extStr] 1] ]
        foreach shortName $bmpFileList {
            set f [file join $dir $shortName]
            set catchVal [catch {image create bitmap -file $f} bmp]
            if { $catchVal } {
                poLog Warning "Could not read $f as bitmap"
            } else {
                poLog Info "Reading $f as bitmap"
                checkbutton $bmpfr.b$i -selectcolor green -bg white \
                    -indicatoron false -image $bmp -variable ${ns}::sBmpList($f)
                poToolhelp AddBinding $bmpfr.b$i \
                    [format "%s (%dx%d pixels)" \
                    [file tail $f] [image width $bmp] [image height $bmp]]
                grid $bmpfr.b$i -row $r -column $c -ipadx 1 -ipady 1
                incr i
                incr c
                if { $c == 10 } {
                    set c 0
                    incr r
                }
            }
        }
        poWin SetScrolledTitle $bmpfr [format "%s: %d bitmaps" $dir $i]
    }

    proc DelBrowseWin { tw } {
        variable sBmpList

        destroy $tw
        catch { unset sBmpList }
    }

    proc AskBrowseDir {} {
        variable sPo

        set tmpDir [poWin ChooseDir "Select bitmap directory" [file dirname $sPo(lastFile)]]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            set curDir [poMisc FileSlashName $tmpDir]
            OpenBrowseWin $curDir
            poAppearance AddToRecentDirList $curDir
        }
    }

    proc OpenBrowseWin { dir } {
        variable sPo
        variable ns
        variable sBmpList

        set tw .poBitmap:browseDirWin
        set sPo(browseWin,name) $tw

        if { [winfo exists $tw] } {
            DelBrowseWin $tw
        }

        toplevel $tw
        wm title $tw "$sPo(appName) browser: [file tail $dir]"
        wm resizable $tw true true
        wm geometry $tw [format "%dx%d+%d+%d" \
           $sPo(browseWin,w) $sPo(browseWin,h) $sPo(browseWin,x) $sPo(browseWin,y)]

        ttk::frame $tw.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.workfr
        pack  $tw.toolfr -side top -fill x
        pack  $tw.workfr -side top -fill both -expand 1 -pady 2

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::open] \
                  "${ns}::OpenSelBmps" "Load selected bitmaps into editor ...(Ctrl+O)"
        bind $tw <Control-o> "${ns}::OpenSelBmps"
        poToolbar AddButton $toolfr [::poBmpData::save] \
                  "${ns}::GetBmpPackageFile [list $dir]" "Save selected bitmaps as package ...(Ctrl+S)"
        bind $tw <Control-s> "${ns}::GetBmpPackageFile [list $dir]"

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::selectall] \
                  "${ns}::SelAllBmps" "Select all bitmaps (Ctrl+A)"
        bind $tw <Control-a> "${ns}::SelAllBmps"
        poToolbar AddButton $toolfr [::poBmpData::unselectall] \
                  "${ns}::UnselAllBmps" "Unselect all bitmaps (Ctrl+U)"
        bind $tw <Control-u> "${ns}::UnselAllBmps"
        poToolbar AddButton $toolfr [::poBmpData::update] \
                  "${ns}::UpdateBmpDir $tw $tw.workfr [list $dir]" "Update bitmap listing (F5)"
        bind $tw <Key-F5> "${ns}::UpdateBmpDir $tw $tw.workfr [list $dir]"

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::delete "red"] \
                  "${ns}::DelSelBmps $tw $tw.workfr [list $dir]" "Delete selected bitmap files (Del)"
        bind $tw <Delete> "${ns}::DelSelBmps $tw $tw.workfr [list $dir]"

        UpdateBmpDir $tw $tw.workfr $dir

        bind $tw <Key-Escape> "${ns}::DelBrowseWin $tw"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::DelBrowseWin $tw"
        focus $tw
    }

    proc CreateBmpFromImg { phImg } {
        variable sPo

        set maxSize [expr {$sPo(maxBitmapSize) * $sPo(maxBitmapSize)} ]
        if { [image width $phImg] * [image height $phImg] > $maxSize } {
            error "Image exceeds maximum allowed number of pixels: $maxSize"
        }

        SetBmpWidth  [image width  $phImg]
        SetBmpHeight [image height $phImg]
        set canvasId  [GetCanvasId]
        set bmpHeight [GetBmpHeight]
        set bmpWidth  [GetBmpWidth]
        CreateGrid $canvasId $bmpWidth $bmpHeight $sPo(bmp,pixsize)
        for { set y 0 } { $y < $bmpHeight } { incr y } {
            for { set x 0 } { $x < $bmpWidth } { incr x } {
                set alpha [$phImg transparency get $x $y]
                set onOff [expr { $alpha == 0 }]
                SetPixelOnOff $canvasId $x $y $onOff
            }
        }
    }

    proc ReadBmpByDrop { canvasId fileList } {
        foreach f $fileList {
            if { [file isdirectory $f] } {
                OpenBrowseWin $f
            } elseif { [file isfile $f] } {
                OpenBmp $f
            }
        }
    }

    proc OpenBmp { imgName } {
        variable sPo

        set retVal [catch {set phImg [poImgMisc ReadBmp $imgName]} err]
        if { $retVal != 0 } {
            set ext [file extension $imgName]
            set fmtStr [poImgType GetFmtByExt $ext]
            if { $fmtStr eq "" } {
                tk_messageBox -message "Can't read bitmap $imgName (Extension \"$ext\" not supported)" \
                                       -type ok -icon warning
                focus $sPo(tw)
                return
            }
            set optStr [poImgType GetOptByFmt $fmtStr "read"]

            set retVal [catch {set phImg [image create photo -file $imgName \
                                          -format "[string tolower $fmtStr] $optStr"]} err1]
            if { $retVal != 0 } {
                tk_messageBox -message "Can't read bitmap $imgName ($err1)." \
                                       -type ok -icon warning
                focus $sPo(tw)
                return
            }
        }
        set retVal [catch { CreateBmpFromImg $phImg } err2]
        if { $retVal == 0 } {
            set sPo(bmp,defName) $imgName
            PreviewNewSize
            MoveCursor 0 0
            UpdateMainTitle
            set curFile [poMisc FileSlashName $imgName]
            poAppearance AddToRecentFileList $curFile
            set sPo(lastFile) $imgName
            poWinSelect SetValue $sPo(fileCombo) $imgName
        } else {
            tk_messageBox -message "Can't read bitmap $imgName ($err2)." \
                                   -type ok -icon warning
        }
        image delete $phImg
        focus $sPo(tw)
    }

    proc OpenBmpFile {} {
        variable sPo

        set imgName [GetFileName "Open bitmap" "open" [file tail $sPo(bmp,defName)]]
        if { $imgName ne "" } {
            OpenBmp $imgName
        }
    }

    proc SaveBmpFile {} {
        variable sPo

        set imgName [GetFileName "Save bitmap as" "save" [file tail $sPo(bmp,defName)]]
        if { $imgName ne "" } {
            if { [poApps HavePkg "Img"] } {
                SaveBmp $sPo(tw) $sPo(bmp,imgNormal) $imgName
            } else {
                poImgMisc WriteBmp $sPo(bmp,imgInvert) $imgName
            }
            set sPo(bmp,defName) $imgName
            set sPo(lastFile) $imgName
            UpdateMainTitle
        }
        return $imgName
    }

    proc SaveBmp { tw photoId imgName } {
        variable sPo

        poLog Info "Saving bitmap with Img extension"
        set ext [file extension $imgName]

        set fmtStr [poImgType GetFmtByExt $ext]
        if { $fmtStr eq "" } {
            tk_messageBox -message "Extension $ext not supported." \
                          -type ok -icon warning
            focus $sPo(tw)
            return
        }
        $tw config -cursor watch
        update

        if { $sPo(conv,outFmtOpt) eq "" } {
            set optStr [poImgType GetOptByFmt $fmtStr "write"]
        } else {
            set optStr $sPo(conv,outFmtOpt)
        }

        set retVal [catch { $photoId write $imgName -format "$fmtStr $optStr" } errMsg]
        if { $retVal != 0 } {
            tk_messageBox -title "Error" -icon error \
                          -message "Error saving image:\n$errMsg"
        }
        $tw config -cursor top_left_arrow
    }

    proc GetInitString {} {
        variable sPo

        return $sPo(initStr)
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init global variables not stored in the cfg file.
        set sPo(undoNum) -1
        set sPo(bmp,defName) "untitled.xbm"

        SetBmpWidth  16
        SetBmpHeight 16

        # Init all variables stored in the cfg file with default values.
        SetWindowPos mainWin   90  30 700 400
        SetWindowPos browseWin 20  40 300 300
        SetWindowPos specWin   20  50   0   0

        SetColors "black" "white" "grey" "red"
        SetPixelSize 10
        SetMiscModes 20 256
        SetExportPackage "myBitmap" "::myBitmap" "1.0"
        SetCurFile [pwd]

        SetConversionParams "SameAsInput" "Conv_%s" false [pwd] 1
        set sPo(conv,counter) $sPo(conv,num)

        # Now try to read the cfg file.
        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file found. Using default values."
        }
        set sPo(cfgDir) $cfgDir

        # Set the default size of new bitmaps to values read from settings file.
        set sPo(new,w) [GetBmpWidth]
        set sPo(new,h) [GetBmpHeight]
        set sPo(new,s) $sPo(bmp,pixsize)
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
            puts $fp "catch {SetWindowPos [GetWindowPos browseWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos specWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetWindowPos [GetWindowPos browseWin]
            eval SetWindowPos [GetWindowPos specWin]

            PrintCmd $fp "Colors"
            PrintCmd $fp "PixelSize"
            PrintCmd $fp "MiscModes"
            PrintCmd $fp "ExportPackage"
            PrintCmd $fp "CurFile"
            PrintCmd $fp "ConversionParams"

            close $fp
        }
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc GetUsageMsg {} {
        variable sPo

        if { $sPo(conv,useOutDir) } {
            set outDir $sPo(conv,outDir)
        } else {
            set outDir "SameAsInput"
        }
        if { $sPo(conv,outFmt) eq "SameAsInput" } {
            set optStr "Depending on input format"
        } else {
            set optStr [poImgType GetOptByFmt $sPo(conv,outFmt) "write"]
        }
        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[BitmapFile\|Directory\]\n"
        append msg "\n"
        append msg "Bitmap manipulation program similar to the classic Unix bitmap program.\n"
        append msg "If a valid bitmap file is specified, the image is loaded for manipulation.\n"
        append msg "If a valid directory name is specified, the bitmap browser window is opened.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--scale <float>     : Scale bitmap by specified factor.\n"
        append msg "                      Default: No scaling.\n"
        append msg "--convfmt <string>  : Use specified format for converted bitmaps.\n"
        append msg "                      Default: \"$sPo(conv,outFmt)\".\n"
        append msg "--convopt <string>  : Use specified format option for converted bitmaps.\n"
        append msg "                      Default: $optStr.\n"
        append msg "--convname <string> : Template for converted bitmap files.\n"
        append msg "                      Default: \"$sPo(conv,name)\".\n"
        append msg "                      Use \"%s\" to insert original name without file extension.\n"
        append msg "                      Use \"%d\" or a printf variation to insert a number.\n"
        append msg "--convnum <int>     : Start value for filename numbering while converting.\n"
        append msg "                      Default: $sPo(conv,num).\n"
        append msg "--convdir <dir>     : Directory for converted bitmap files.\n"
        append msg "                      Default: \"$outDir\".\n"
        append msg "\n"
        append msg "Available conversion output formats (use --helpimg for more info):\n"
        append msg "  [poImgType GetFmtList]\n"
        append msg "\n"
        append msg "Shortcuts:\n"
        append msg "Escape            : Cancel nearly everything.\n"
        append msg "Arrow keys        : Move drawing cursor.\n"
        append msg "Ctrl  + Arrow key : Set   pixel under cursor, then move cursor.\n"
        append msg "Shift + Arrow key : Clear pixel under cursor, then move cursor.\n"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
    }

    proc CloseSubWindows {} {
        variable sPo

        catch {destroy $sPo(browseWin,name)}
    }

    proc CloseAppWindow {} {
        variable sPo

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        if { $sPo(bmp,changed) } {
            set retVal [tk_messageBox \
              -title "Save bitmap" \
              -message "Bitmap has been changed. Save bitmap?" \
              -type yesnocancel -default yes -icon question]
            if { $retVal eq "yes" } {
                if { [SaveBmpFile] eq "" } {
                    focus $sPo(tw)
                    return false
                }
            } elseif { $retVal eq "cancel" } {
                focus $sPo(tw)
                return false
            }
        }

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify

        return true
    }

    proc ExitApp {} {
        if { [CloseAppWindow] == false } {
            return
        }
        poApps ExitApp
    }

    proc CancelMousePos {} {
        variable sPo

        set sPo(cursor,mouse) 0
    }

    proc SetMousePos { w x y } {
        variable sPo

        set sPo(cursor,mouse) 1
        set itemList [$w find closest [$w canvasx $x] [$w canvasy $y]]
        foreach item $itemList {
            set tagStr [lindex [$w gettags $item] 0]
            scan $tagStr "x_%d_y_%d" cx cy
            GotoPixel $cx $cy
        }
    }

    proc MoveCursor { dx dy } {
        variable sPo

        set canvasId [GetCanvasId]
        SetRectSelOnOff $canvasId $sPo(cursor,x) $sPo(cursor,y) 0

        incr sPo(cursor,x) $dx
        incr sPo(cursor,y) $dy
        if { $sPo(cursor,x) < 0 } {
            set sPo(cursor,x) 0
        }
        if { $sPo(cursor,y) < 0 } {
            set sPo(cursor,y) 0
        }
        if { $sPo(cursor,x) >= [GetBmpWidth] } {
            set sPo(cursor,x) [expr {[GetBmpWidth] - 1}]
        }
        if { $sPo(cursor,y) >= [GetBmpHeight] } {
            set sPo(cursor,y) [expr {[GetBmpHeight] - 1}]
        }

        SetRectSelOnOff $canvasId $sPo(cursor,x) $sPo(cursor,y) 1

        WriteInfoStr "Size: [GetBmpWidth] x [GetBmpHeight]"
    }

    proc SetRectSelOnOff { w x y onOff } {
        variable sPo

        set itemId [GetItemId $x $y]
        if { $onOff } {
            $w itemconfigure $itemId -outline $sPo(cursorColor)
            $w itemconfigure $itemId -width 2
        } else {
            $w itemconfigure $itemId -outline $sPo(gridColor)
            $w itemconfigure $itemId -width 1
        }
    }

    proc SetRectOnOff { w x y onOff } {
        variable sPo

        if { $onOff } {
            $w itemconfigure [GetItemId $x $y] -fill $sPo(onColor)
        } else {
            $w itemconfigure [GetItemId $x $y] -fill $sPo(offColor)
        }
    }

    proc SetPixelOnOff { w x y onOff } {
        variable sPo

        if { $onOff } {
            set sPo(bmp,$x,$y) 255
        } else {
            set sPo(bmp,$x,$y) 0
        }
        SetRectOnOff $w $x $y $onOff
    }

    proc SetPixel { onOff { updatePreview 1 } } {
        variable sPo

        SetPixelOnOff [GetCanvasId] $sPo(cursor,x) $sPo(cursor,y) $onOff
        if { $updatePreview } {
            UpdatePreview
        }
    }


    # Get cursor position by mouse.
    # Display "msg" in the status bar and wait for the user
    # to click onto a bitmap pixel.
    # Return the pixel the user has selected as a list of row and
    # column values. A empty list is returned, if the mouse
    # click was outside of the bitmap drawing window.
    proc GetMousePos { msg } {
        variable sPo
        variable ns

        set canvasId [GetCanvasId]
        set sPo(drawMode) 0

        $canvasId configure -cursor crosshair
        bind $canvasId <ButtonRelease-1> "${ns}::SetMousePos %W %x %y"
        bind $canvasId <KeyPress-Escape> "${ns}::CancelMousePos"

        WriteInfoStr $msg
        update

        set oldFocus [focus]
        set oldGrab [grab current $canvasId]
        if {$oldGrab ne ""} {
            set grabStatus [grab status $oldGrab]
        }
        grab  $canvasId
        focus $canvasId

        tkwait variable ${ns}::sPo(cursor,mouse)

        catch {focus $oldFocus}
        grab release $canvasId
        if {$oldGrab ne ""} {
            if {$grabStatus eq "global"} {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }
        $canvasId configure -cursor top_left_arrow
        set sPo(drawMode) 1
        WriteInfoStr ""
        if { $sPo(cursor,mouse) } {
            return [list $sPo(cursor,x) $sPo(cursor,y)]
        } else {
            return {}
        }
    }

    # Set the width of the current bitmap.
    proc SetBmpWidth { width } {
        variable sPo

        set sPo(bmp,xsize) $width
    }

    # Get the width of the current bitmap.
    proc GetBmpWidth {} {
        variable sPo

        return $sPo(bmp,xsize)
    }

    # Set the height of the current bitmap.
    proc SetBmpHeight { height } {
        variable sPo

        set sPo(bmp,ysize) $height
    }

    # Get the height of the current bitmap.
    proc GetBmpHeight {} {
        variable sPo

        return $sPo(bmp,ysize)
    }

    # Get the pixel value at specified position.
    proc GetPixel { x y } {
        variable sPo

        return $sPo(bmp,$x,$y)
    }

    # Get the pixel value at the current cursor position.
    proc GetCurPixel {} {
        variable sPo

        return $sPo(bmp,$sPo(cursor,x),$sPo(cursor,y))
    }

    proc GotoThenDraw { x y } {
        if { [GotoPixel $x $y] } {
            DrawPixel
        }
    }

    # Set pixel at current cursor position to opaque.
    # If withUpdate is set to 1, UpdatePreview is called after drawing.
    proc DrawPixel { { withUpdate 0 } } {
        SetPixel 1 $withUpdate
    }

    # Set pixel at current cursor position to transparent.
    # If withUpdate is set to 1, UpdatePreview is called after clearing.
    proc ClearPixel { { withUpdate 0 } } {
        SetPixel 0 $withUpdate
    }

    # Set cursor position to (row,col).
    # If only one parameter is given, it is interpreted as
    # a list of (row,column) values, as returned by GetMousePos.
    proc GotoPixel { row { col -1 } } {
        variable sPo

        set canvasId [GetCanvasId]

        if { [llength $row] == 2 } {
            set x [lindex $row 0]
            set y [lindex $row 1]
        } else {
            set x $row
            set y $col
        }
        if { $x < 0 || $y < 0 || $x >= [GetBmpWidth] || $y >= [GetBmpHeight] } {
            return false
        }

        SetRectSelOnOff $canvasId $sPo(cursor,x) $sPo(cursor,y) 0

        set sPo(cursor,x) $x
        set sPo(cursor,y) $y

        SetRectSelOnOff $canvasId $sPo(cursor,x) $sPo(cursor,y) 1

        return true
    }

    # Move the current cursor position noRows up.
    proc CursorUp { { noRows 1 } } {
        MoveCursor 0 [expr {-1 * $noRows}]
    }

    # Move the current cursor position noRows down.
    proc CursorDown { { noRows 1 } } {
        MoveCursor 0 $noRows
    }

    # Move the current cursor position noCols left.
    proc CursorLeft { { noCols 1 } } {
        MoveCursor [expr {-1 * $noCols}] 0
    }

    # Move the current cursor position noCols right.
    proc CursorRight { { noCols 1 } } {
        MoveCursor $noCols 0
    }

    # Create a circle.
    proc Circle { cx cy radius } {
        set r2  [expr {$radius * $radius}]
        set end [expr {$radius * sqrt(2)}]
        for { set i 0 } { $i < $end } { incr i } {
            set val [expr {$r2 - $i*$i}]
            if { $val < 0.0 } {
                break
            }
            set j [expr {round(sqrt($val))}]

            GotoThenDraw [expr { $i + $cx}] [expr { $j + $cy}]
            GotoThenDraw [expr { $j + $cx}] [expr { $i + $cy}]
            GotoThenDraw [expr { $i + $cx}] [expr {-$j + $cy}]
            GotoThenDraw [expr { $j + $cx}] [expr {-$i + $cy}]
            GotoThenDraw [expr {-$i + $cx}] [expr { $j + $cy}]
            GotoThenDraw [expr {-$j + $cx}] [expr { $i + $cy}]
            GotoThenDraw [expr {-$i + $cx}] [expr {-$j + $cy}]
            GotoThenDraw [expr {-$j + $cx}] [expr {-$i + $cy}]
        }
    }

    proc ExecToolCircle {} {
        set center [GetMousePos "Circle: Select center of circle"]
        if { [llength $center] != 0 } {
            set other [GetMousePos "Circle: Select radius"]
            if { [llength $other] != 0 } {
                set radius [expr {[lindex $other 0] - [lindex $center 0]}]
                if { $radius < 0 } {
                    set radius [expr {-1 * $radius}]
                }
                Circle [lindex $center 0] [lindex $center 1] $radius
                UpdatePreview
            }
        }
    }

    # Flood fill a region.
    proc Flood { x y onOff } {
        if { $x < 0 || $y < 0 || $x >= [GetBmpWidth] || $y >= [GetBmpHeight] } {
            return
        }
        GotoPixel $x $y
        if { $onOff != [GetCurPixel] } {
            return
        }
        if { ! $onOff } {
            DrawPixel
        } else {
            ClearPixel
        }
        update
        Flood [expr {$x + 1}] $y $onOff
        Flood [expr {$x - 1}] $y $onOff
        Flood $x [expr {$y + 1}] $onOff
        Flood $x [expr {$y - 1}] $onOff
    }

    proc ExecToolFloodFill {} {
        set p [GetMousePos "Flood fill: Select starting cell"]
        if { [llength $p] != 0 } {
            GotoPixel $p
            set pixVal [GetCurPixel]
            Flood [lindex $p 0] [lindex $p 1] $pixVal
            UpdatePreview
            SaveUndoImg
        }
    }

    # Create a rectangle, horizontal or vertical line.
    proc VertLine { y1 y2 } {
        if { $y1 > $y2 } {
            for { set i $y1 } { $i >= $y2 } { incr i -1 } {
                DrawPixel; CursorUp
            }
            CursorDown
        } else {
            for { set i $y1 } { $i <= $y2 } { incr i } {
                DrawPixel; CursorDown
            }
            CursorUp
        }
    }

    proc HoriLine { x1 x2 } {
        if { $x1 > $x2 } {
            for { set i $x1 } { $i >= $x2 } { incr i -1 } {
                DrawPixel; CursorLeft
            }
            CursorRight
        } else {
            for { set i $x1 } { $i <= $x2 } { incr i } {
                DrawPixel; CursorRight
            }
            CursorLeft
        }
    }

    proc ExecToolRectangle {} {
        set start [GetMousePos "Rectangle: Select first corner"]
        if { [llength $start] != 0 } {
            set end [GetMousePos "Rectangle: Select second corner"]
            if { [llength $end] != 0 } {
                GotoPixel $start
                HoriLine [lindex $start 0] [lindex $end 0]
                GotoPixel $start
                VertLine [lindex $start 1] [lindex $end 1]
                GotoPixel $end
                HoriLine [lindex $end 0] [lindex $start 0]
                GotoPixel $end
                VertLine [lindex $end 1] [lindex $start 1]
                GotoPixel $end
                UpdatePreview
                SaveUndoImg
            }
        }
    }

    proc ExecToolHorizontalLine {} {
        set start [GetMousePos "Horizontal line: Select first corner"]
        if { [llength $start] != 0 } {
            set end [GetMousePos "Horizontal line: Select second corner"]
            if { [llength $end] != 0 } {
                GotoPixel $start
                HoriLine [lindex $start 0] [lindex $end 0]
            }
        }
    }

    proc ExecToolVerticalLine {} {
        set start [GetMousePos "Vertical line: Select first corner"]
        if { [llength $start] != 0 } {
            set end [GetMousePos "Vertical line: Select second corner"]
            if { [llength $end] != 0 } {
                GotoPixel $start
                VertLine [lindex $start 1] [lindex $end 1]
            }
        }
    }

    proc BuildOutputFilename { inName } {
        variable sPo

        if { $sPo(conv,useOutDir) } {
            set dirName $sPo(conv,outDir)
        } else {
            set dirName [file dirname $inName]
        }
        set rootName [file rootname [file tail $inName]]
        set ext [file extension [file tail $inName]]
        if { $sPo(conv,outFmt) ne "SameAsInput" } {
            set ext [lindex [poImgType GetExtList $sPo(conv,outFmt)] 0]
        }
        set template $sPo(conv,name)
        if { [string match "*%s*%*d*" $template] } {
            set imgName [format $template $rootName $sPo(conv,counter)]
        } elseif { [string match "*%*d*%s*" $template] } {
            set imgName [format $template $sPo(conv,counter) $rootName]
        } elseif { [string match "*%s*" $template] } {
            set imgName [format $template $rootName]
        } elseif { [string match "*%*d*" $template] } {
            set imgName [format $template $sPo(conv,counter)]
        } else {
            set imgName [format "%s%s" $template $rootName]
        }
        set fullName [file join $dirName $imgName]
        append fullName $ext
        incr sPo(conv,counter)
        return $fullName
    }

    proc ConvertBmp { fileName } {
        variable sPo

        set bmpName [BuildOutputFilename $fileName]
        set dirName [file dirname $bmpName]
        if { ! [file isdirectory $dirName] } {
            set retVal [tk_messageBox \
                -message "Directory \"$dirName\" does not exist." \
                -title "Error" -type ok -icon error]
            return 0
        }
        if { [poApps GetVerbose] } {
            WriteInfoStr "Convert [file tail $fileName] to $bmpName"
            puts "Convert [file tail $fileName] to $bmpName"
        }
        if { $bmpName ne "" } {
            set retVal yes
            if { ! [poApps GetOverwrite] } {
                if { [file exists $bmpName] } {
                    set retVal [tk_messageBox \
                      -message "File \"$bmpName\" already exists.\n\
                                Do you want to overwrite it?" \
                      -title "Confirmation" -type yesnocancel -default no -icon info]
                }
            }
            if { $retVal eq "cancel" } {
                return 0
            }
            if { $retVal eq "yes" } {
                SaveBmp $sPo(tw) $sPo(bmp,imgNormal) $bmpName
            }
            focus $sPo(tw)
        }
        return 1
    }

    proc ConvertBmps { fileList } {
        variable sPo

        set sPo(conv,counter) $sPo(conv,num)
        foreach fileName $fileList {
            OpenBmp $fileName
            if { $sPo(optScale) != 1.0 } {
                if { [poApps GetVerbose] } {
                    WriteInfoStr "Scale [file tail $fileName] by factor $sPo(optScale)"
                    puts "Scale [file tail $fileName] by factor $sPo(optScale)"
                }
                ScaleBmp $sPo(optScale)
            }
            if { ! [ConvertBmp $fileName] } {
                break
            }
        }
    }

    proc PrintUsage {} {
        puts [GetUsageMsg]
    }

    proc PrintErrorAndExit { showMsgBox msg } {
        puts "\nError: $msg"
        PrintUsage
        if { $showMsgBox } {
            tk_messageBox -title "Error" -icon error -message "$msg"
        }
        exit 1
    }

    proc ParseCommandLine { argList } {
        variable sPo

        set curArg 0
        set fileOrDirList [list]
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "scale" } {
                    incr curArg
                    set sPo(optScale) [lindex $argList $curArg]
                    set sPo(optConvert) true
                } elseif { $curOpt eq "convfmt" } {
                    incr curArg
                    set sPo(conv,outFmt) [lindex $argList $curArg]
                    set sPo(optConvert) true
                } elseif { $curOpt eq "convopt" } {
                    incr curArg
                    set sPo(conv,outFmtOpt) [lindex $argList $curArg]
                    set sPo(optConvert) true
                } elseif { $curOpt eq "convname" } {
                    incr curArg
                    set sPo(conv,name) [lindex $argList $curArg]
                    set sPo(optConvert) true
                } elseif { $curOpt eq "convnum" } {
                    incr curArg
                    set sPo(conv,num) [lindex $argList $curArg]
                    set sPo(optConvert) true
                } elseif { $curOpt eq "convdir" } {
                    incr curArg
                    set sPo(conv,useOutDir) true
                    set sPo(conv,outDir) [lindex $argList $curArg]
                    set sPo(optConvert) true
                }
            } else {
                lappend fileOrDirList $curParam
            }
            incr curArg
        }

        # Check the specified command line parameters.
        if { $sPo(optConvert) } {
            # Do not save settings to file and do not autofit images.
            poApps SetAutosaveOnExit false
            if { [llength $fileOrDirList] == 0 } {
                PrintErrorAndExit false "No images specified for batch processing."
            }
            if { $sPo(conv,outFmt) ne "SameAsInput" } {
                if { [lindex [poImgType GetExtList $sPo(conv,outFmt)] 0] eq "" } {
                    PrintErrorAndExit false "Image format \"$sPo(conv,outFmt)\" not supported."
                }
            }
            ConvertBmps $fileOrDirList
            exit 0
        }

        foreach fileOrDir $fileOrDirList {
            if { [file isdirectory $fileOrDir] } {
                set curDir [poMisc FileSlashName $fileOrDir]
                OpenBrowseWin $curDir
                poAppearance AddToRecentDirList $curDir
            } elseif { [file isfile $fileOrDir] } {
                set curFile [poMisc FileSlashName $fileOrDir]
                OpenBmp $curFile
            }
        }
        if { [llength $fileOrDirList] == 0 } {
            PreviewNewSize
        }

        UpdateMainTitle
        MoveCursor 0 0

        if { [llength $fileOrDirList] == 0 } {
            WriteInfoStr [GetInitString]
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poBitmap Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
