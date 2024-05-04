# Module:         poPresMgr
# Copyright:      Paul Obermeier 2014-2023 / paul@poSoft.de
# First Version:  2014 / 02 / 26
#
# Distributed under BSD license.
#
# Tool for handling PowerPoint presentations.


namespace eval poPresMgr {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin CloseAppWindow
    namespace export ParseCommandLine IsOpen
    namespace export GetUsageMsg

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poPresMgr"  ; # Name of toplevel window
        set sPo(appName) "poPresMgr"   ; # Name of tool
        set sPo(cfgDir)  ""            ; # Directory containing config files

        set sPo(imgExportPrefix) "Slide"

        SetCurApp  ""
        SetCurPres ""

        # Determine machine dependent fixed font.
        set sPo(fixedFont) [poWin GetFixedFont]

        if { ! [poMisc HavePkg "cawt"] } {
            set sPo(CawtState) "disabled"
        } else {
            set sPo(CawtState) "normal"
        }
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


    proc SetMainWindowSash { sash } {
        variable sPo

        set sPo(sash) $sash
    }

    proc GetMainWindowSash {} {
        variable sPo

        set sash $sPo(sash)
        if { [info exists sPo(paneWin)] && [winfo exists $sPo(paneWin)] } {
            set sash [$sPo(paneWin) sashpos 0]
        }
        return [list $sash]
    }

    proc SetTablelistPos { pos } {
        variable sPo

        set sPo(tablelistPos) $pos
    }

    proc GetTablelistPos {} {
        variable sPo

        return [list $sPo(tablelistPos)]
    }

    proc SetTablelistColumnSizes { args } {
        variable sPo

        set colInd 0
        foreach colWidth $args {
            $sPo(tableWidget) columnconfigure $colInd -width [expr -$colWidth]]
            incr colInd
        }
    }

    proc GetTablelistColumnSizes {} {
        variable sPo

        set numCols [expr [$sPo(tableWidget) columnindex end] + 1]
        set colWidthList [list]
        for { set colInd 0 } { $colInd < $numCols } { incr colInd } {
            lappend colWidthList [$sPo(tableWidget) columnwidth $colInd -stretched]
        }
    }

    proc SetCurDirectory { curDir } {
        variable sPo

        set sPo(lastDir) $curDir
    }

    proc GetCurDirectory {} {
        variable sPo

        return [list $sPo(lastDir)]
    }

    proc SetCurFile { curFile } {
        variable sPo

        set sPo(curFile) $curFile
    }

    proc GetCurFile {} {
        variable sPo

        return [list $sPo(curFile)]
    }

    proc SetShowSlideOverview { onOff } {
        variable sPo

        set sPo(viewSlideSorter) $onOff
    }

    proc GetShowSlideOverview {} {
        variable sPo

        return [list $sPo(viewSlideSorter)]
    }

    proc SetImgExportFormat { imgFormat } {
        variable sPo

        set sPo(imgExportType) $imgFormat
    }

    proc GetImgExportFormat {} {
        variable sPo

        return [list $sPo(imgExportType)]
    }

    proc SetSlideModes { thumbSize slidesPerRow } {
        variable sPo

        set sPo(thumbSize)    $thumbSize
        set sPo(slidesPerRow) $slidesPerRow
    }

    proc GetSlideModes {} {
        variable sPo

        return [list $sPo(thumbSize) \
                     $sPo(slidesPerRow)]
    }

    proc SetSlideSize { width height } {
        variable sPo

        set sPo(SlideWidth)  $width
        set sPo(SlideHeight) $height
    }

    proc GetSlideSize {} {
        variable sPo

        return [list $sPo(SlideWidth) \
                     $sPo(SlideHeight)]
    }

    proc SetImageModes { embedImages fitToSlide } {
        variable sPo

        set sPo(EmbedImages) $embedImages
        set sPo(FitToSlide)  $fitToSlide
    }

    proc GetImageModes {} {
        variable sPo

        return [list $sPo(EmbedImages) \
                     $sPo(FitToSlide)]
    }

    proc SetVideoModes { vertResolution fps } {
        variable sPo

        set sPo(VideoResolution) $vertResolution
        set sPo(VideoFps)        $fps
    }

    proc GetVideoModes {} {
        variable sPo

        return [list $sPo(VideoResolution) \
                     $sPo(VideoFps)]
    }

    proc SetVideoEffects { useEffects duration advanceTime effectType } {
        variable sPo

        set sPo(UseEffects)        $useEffects
        set sPo(EffectDuration)    $duration
        set sPo(EffectAdvanceTime) $advanceTime
        set sPo(EffectType)        $effectType
    }

    proc GetVideoEffects {} {
        variable sPo

        return [list $sPo(UseEffects) \
                     $sPo(EffectDuration) \
                     $sPo(EffectAdvanceTime) \
                     $sPo(EffectType)]
    }

    proc SetCurSession { sessionName sourceDir destinationDir pptTemplate dropMaster } {
        variable sPo

        set sPo(curSession)  $sessionName
        set sPo(sourceDir)   $sourceDir
        set sPo(cacheDir)    $destinationDir
        set sPo(pptTemplate) $pptTemplate
        set sPo(dropMaster)  $dropMaster
    }

    proc GetCurSession {} {
        variable sPo

        return [list $sPo(curSession)  \
                     $sPo(sourceDir)   \
                     $sPo(cacheDir)    \
                     $sPo(pptTemplate) \
                     $sPo(dropMaster)]
    }

    proc AddSession { sessionName sourceDir destinationDir pptTemplate dropMaster } {
        variable sPo

        lappend sPo(sessionList) $sessionName
        set sPo(session,$sessionName,sourceDir)   $sourceDir
        set sPo(session,$sessionName,cacheDir)    $destinationDir
        set sPo(session,$sessionName,pptTemplate) $pptTemplate
        set sPo(session,$sessionName,dropMaster)  $dropMaster
    }

    proc UseSession { sessionName } {
        variable sPo
        variable ns
        variable sImgList

        if { [string is integer $sessionName] } {
            if { $sessionName > 0 && $sessionName <= [llength $sPo(sessionList)] } {
                set sessionName [lindex $sPo(sessionList) [expr {$sessionName -1}]]
            }
        }
        if { [lsearch -exact $sPo(sessionList) $sessionName] >= 0 } {
            SetCurSession $sessionName \
                          $sPo(session,$sessionName,sourceDir) \
                          $sPo(session,$sessionName,cacheDir) \
                          $sPo(session,$sessionName,pptTemplate) \
                          $sPo(session,$sessionName,dropMaster)
            UpdateMainTitle
            DestroySlideBtns
            UpdatePptFileList
            catch { unset sImgList }
            trace add variable ${ns}::sImgList write ${ns}::PrintSelSlides
        } else {
            WriteInfoStr "Session \"$sessionName\" not found. Using last session \"$sPo(curSession)\"." "Warning"
        }
    }

    proc GetSessionListAsString {} {
        variable sPo

        set count 1
        set msg   ""
        foreach listEntry $sPo(sessionList) {
            append msg [format "  %2d: %s\n" $count $listEntry]
            incr count
        }
        return $msg
    }

    proc UpdateMainTitle {} {
        variable sPo

        set msg [format "%s - Session %s (%s)" \
                 $sPo(appName) $sPo(curSession) $sPo(sourceDir)] 
        wm title $sPo(tw) $msg
    }

    proc SetNumSelectedSlides { row value } {
        variable sPo

        $sPo(tableWidget) cellconfigure "$row,3" -text $value
    }

    proc FindCacheDir { searchCacheDir } {
        variable sPo

        set numRows [$sPo(tableWidget) size]
        for { set row 0 } { $row < $numRows } { incr row } {
            set rowCont  [$sPo(tableWidget) get $row]
            set cacheDir [lindex $rowCont 6]
            if { $cacheDir eq $searchCacheDir } {
                return $row
            }
        }
        return -1
    }

    proc GetSelCacheDir {} {
        variable sPo

        set indList [$sPo(tableWidget) curselection]
        if { [llength $indList] == 0 } {
            return ""
        }
        set tableInd [lindex $indList 0]
        set rowCont  [$sPo(tableWidget) get $tableInd]
        set cacheDir [lindex $rowCont 6]
        return $cacheDir
    }

    proc GetSelSourceDir {} {
        variable sPo

        set indList [$sPo(tableWidget) curselection]
        if { [llength $indList] == 0 } {
            return ""
        }
        set tableInd  [lindex $indList 0]
        set rowCont   [$sPo(tableWidget) get $tableInd]
        set sourceDir [lindex $rowCont 5]
        return $sourceDir
    }

    proc GetSelSourceFile { tableInd } {
        variable sPo

        set rowCont   [$sPo(tableWidget) get $tableInd]
        set fileName  [lindex $rowCont 1]
        set sourceDir [lindex $rowCont 5]
        return [file join $sourceDir $fileName]
    }

    proc GetSelSourceFiles {} {
        variable sPo

        set indList [$sPo(tableWidget) curselection]
        set sourceFileList []
        foreach ind $indList {
            lappend sourceFileList [GetSelSourceFile $ind]
        }
        return $sourceFileList
    }

    proc CreateSlideFrame {} {
        variable sPo
        variable ns

        set masterFr $sPo(paneWin).imgfr.fr
        ttk::frame $masterFr
        pack $masterFr -side top -expand 1 -fill both

        set btnfr $masterFr.btnfr
        ttk::frame $btnfr
        pack $btnfr -side top -fill x

        set sPo(slideFrame) [poWin CreateScrolledFrame $masterFr true "Slides listing"]

        # Add new toolbar group and associated buttons.
        poToolbar New $btnfr
        poToolbar AddGroup $btnfr

        poToolbar AddButton $btnfr [::poBmpData::selectall] \
            "${ns}::SelAllSlides 1" "Select all slides of this presentation (s)"
        poToolbar AddButton $btnfr [::poBmpData::unselectall] \
            "${ns}::SelAllSlides 0" "Unselect all slides of this presentation (S)"

        poToolbar AddButton $btnfr [::poBmpData::slideShowAll] \
            "${ns}::ViewPresSlides 0" "View all slides of this presentation (v)"
        poToolbar AddButton $btnfr [::poBmpData::slideShowMarked] \
            "${ns}::ViewPresSlides 1" "View selected slides of this presentation (V)"

        poToolbar AddButton $btnfr [::poBmpData::appendToFile] \
            "${ns}::AppendSelSlides" "Append selected slides of this presentation (a)" -state $sPo(CawtState)

        bind $sPo(tw) <v> "${ns}::ViewPresSlides 0"
        bind $sPo(tw) <V> "${ns}::ViewPresSlides 1"
        bind $sPo(tw) <s> "${ns}::SelAllSlides 1"
        bind $sPo(tw) <S> "${ns}::SelAllSlides 0"
        bind $sPo(tw) <a> "${ns}::AppendSelSlides"
    }

    proc CreateTablelistFrame { dirToShow } {
        variable sPo
        variable ns

        set masterFr $sPo(paneWin).dirfr.fr
        ttk::frame $masterFr
        pack $masterFr -side top -expand 1 -fill both

        set btnfr $masterFr.btnfr
        ttk::frame $btnfr
        pack $btnfr -side top -fill x

        set sPo(tableWidget) [poWin CreateScrolledTablelist $masterFr true "Presentations" \
            -exportselection false \
            -columns {0 "#" "right"
                      0 "PowerPoint file" "left" \
                      0 "# slides" "right" \
                      0 "# sel" "right" \
                      0 "Mod. time" "left" \
                      0 "Location" "left" \
                      0 "Cache" "left" } \
            -stretch 1 \
            -setfocus 1 \
            -stripebackground [poAppearance GetStripeColor] \
            -labelcommand tablelist::sortByColumn \
            -selectmode extended \
            -showseparators yes]
        $sPo(tableWidget) columnconfigure 0 -showlinenumbers true
        $sPo(tableWidget) columnconfigure 2 -sortmode integer
        $sPo(tableWidget) columnconfigure 3 -sortmode integer

        bind $sPo(tableWidget) <<ListboxSelect>> ${ns}::ShowSlides

        poToolbar New $btnfr
        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::selectall "red"] \
            "${ns}::SelectForConversion $sPo(tableWidget) red" "Select non-cached presentations"
        poToolbar AddButton $btnfr [::poBmpData::selectall] \
            "${ns}::SelectForConversion $sPo(tableWidget) all" "Select all presentations"
        poToolbar AddButton $btnfr [::poBmpData::unselectall] \
            "${ns}::SelectForConversion $sPo(tableWidget) off" "Unselect all presentations"

        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::delete "red"] \
            "${ns}::DelPptByListBox $sPo(tableWidget)" "Delete selected presentations ..."

        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::open] \
            "${ns}::OpenPptByListBox $sPo(tableWidget)" "Open selected presentations" \
            -state $sPo(CawtState)
        poToolbar AddButton $btnfr [::poBmpData::openDir] \
            "${ns}::OpenPptSourceDir $sPo(tableWidget)" "Open presentation directory"
        poToolbar AddButton $btnfr [::poBmpData::openCache] \
            "${ns}::OpenPptCacheDir $sPo(tableWidget)" "Open cache directory"

        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::update] \
            "${ns}::UpdatePptFileList" "Update list of presentations"

        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::pptToIndex] \
            "${ns}::CreateSlideCache" "Create slide cache of selected presentations" \
            -state $sPo(CawtState)

        if { ! [poApps UseBatchMode] } {
            UpdatePptFileList
        }
        trace add variable ${ns}::sImgList write ${ns}::PrintSelSlides
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        wm minsize $sPo(tw) 300 200
        set sw [winfo screenwidth $sPo(tw)]
        set sh [winfo screenheight $sPo(tw)]
        wm maxsize $sPo(tw) [expr $sw -20] [expr $sh -40]
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create 5 frames: The menu frame on top, category and search frame inside
        # temporary frame and the search result frame.
        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both

        ttk::frame $sPo(tw).fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).fr.workfr
        ttk::frame $sPo(tw).fr.statfr -borderwidth 1
        grid $sPo(tw).fr.toolfr -row 0 -column 0 -sticky news
        grid $sPo(tw).fr.workfr -row 1 -column 0 -sticky news
        grid $sPo(tw).fr.statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).fr 1 -weight 1
        grid columnconfigure $sPo(tw).fr 0 -weight 1
     
        ttk::frame $sPo(tw).fr.workfr.fr
        pack $sPo(tw).fr.workfr.fr -expand 1 -fill both

        set sPo(paneWin) $sPo(tw).fr.workfr.fr.pane
        if { $sPo(tablelistPos) eq "Top" } {
            ttk::panedwindow $sPo(paneWin) -orient vertical
        } else {
            ttk::panedwindow $sPo(paneWin) -orient horizontal 
        }
        pack $sPo(paneWin) -side left -expand 1 -fill both

        ttk::frame $sPo(paneWin).dirfr -relief groove -borderwidth 1
        ttk::frame $sPo(paneWin).imgfr -relief groove -borderwidth 1
        pack $sPo(paneWin).dirfr -side left -fill y
        pack $sPo(paneWin).imgfr -side left -fill both -expand 1

        $sPo(paneWin) add $sPo(paneWin).dirfr
        $sPo(paneWin) add $sPo(paneWin).imgfr

        # Create menus File, Edit, Settings and Help
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
        set settMenu $hMenu.sett
        set winMenu  $hMenu.win
        set helpMenu $hMenu.help
        $hMenu add cascade -menu $fileMenu -label File     -underline 0
        $hMenu add cascade -menu $settMenu -label Settings -underline 0
        $hMenu add cascade -menu $winMenu  -label Window   -underline 0
        $hMenu add cascade -menu $helpMenu -label Help     -underline 0

        # Menu File
        set sessionMenu $fileMenu.session 
        set sPo(sessionMenu) $sessionMenu

        menu $fileMenu -tearoff 0

        poMenu AddCommand $fileMenu "New PPT..."            "Ctrl+N" ${ns}::NewBlankPpt \
                          -state $sPo(CawtState)
        poMenu AddCommand $fileMenu "Open PPT template ..." "Ctrl+T" ${ns}::OpenTmplPpt \
                          -state $sPo(CawtState)
        poMenu AddCommand $fileMenu "Open PPT ..."          "Ctrl+O" ${ns}::AskOpenPpt \
                          -state $sPo(CawtState)
        poMenu AddCommand $fileMenu "Save PPT as ..."       "Ctrl+S" ${ns}::AskSavePpt \
                          -state $sPo(CawtState)
        poMenu AddCommand $fileMenu "Save PPT as video ..." "Ctrl+E" ${ns}::AskSaveVideo \
                          -state $sPo(CawtState)

        $fileMenu add separator
        $fileMenu add cascade -label "Select session" -menu $sessionMenu
        menu $sessionMenu -tearoff 0 -postcommand "${ns}::AddRecentSessions $sessionMenu"

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }

        if { [poMisc HavePkg "cawt"] } {
            bind $sPo(tw) <Control-n>  ${ns}::NewBlankPpt
            bind $sPo(tw) <Control-t>  ${ns}::OpenTmplPpt
            bind $sPo(tw) <Control-o>  ${ns}::AskOpenPpt
            bind $sPo(tw) <Control-s>  ${ns}::AskSavePpt
            bind $sPo(tw) <Control-e>  ${ns}::AskSaveVideo
        }
        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        if { $sPo(CawtState) eq "normal" } {
            $settMenu add cascade -label "Application settings" -menu $appSettMenu
            menu $appSettMenu -tearoff 0
            poMenu AddCommand $appSettMenu "Miscellaneous" "" [list ${ns}::ShowSpecificSettWin "Miscellaneous"]
            poMenu AddCommand $appSettMenu "Sessions"      "" [list ${ns}::ShowSpecificSettWin "Sessions"]
            poMenu AddCommand $appSettMenu "Images/Videos" "" [list ${ns}::ShowSpecificSettWin "Images"]
        }

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
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgview]   "" "poApps StartApp poImgview"
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgBrowse] "" "poApps StartApp poImgBrowse"
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" "poApps StartApp poBitmap"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgdiff]   "" "poApps StartApp poImgdiff"
        poMenu AddCommand $winMenu [poApps GetAppDescription poDiff]      "" "poApps StartApp poDiff"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poPresMgr]   "" "poApps StartApp poPresMgr" -state disabled
        poMenu AddCommand $winMenu [poApps GetAppDescription poOffice]    "" "poApps StartApp poOffice"

        # Menu Help
        menu $helpMenu -tearoff 0
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $helpMenu "Help ..." "F1" ${ns}::HelpCont
            bind $sPo(tw) <Key-F1> ${ns}::HelpCont
            poMenu AddCommand $helpMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $helpMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $helpMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        $sPo(tw) configure -menu $hMenu

        # Add new toolbar group and associated buttons.
        set toolfr $sPo(tw).fr.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::newfile] \
            ${ns}::NewBlankPpt "New presentation (Ctrl+N)" -state $sPo(CawtState)

        poToolbar AddButton $toolfr [::poBmpData::openTemplate] \
            ${ns}::OpenTmplPpt "Open template ... (Ctrl+T)" -state $sPo(CawtState)

        poToolbar AddButton $toolfr [::poBmpData::open] \
            ${ns}::AskOpenPpt "Open presentation ... (Ctrl+O)" -state $sPo(CawtState)

        poToolbar AddButton $toolfr [::poBmpData::save] \
            ${ns}::AskSavePpt "Save presentation as ...(Ctrl+S)" -state $sPo(CawtState)

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::unselectall] \
            ${ns}::ClearAllSelMarks "Unselect all slides"
        poToolbar AddButton $toolfr [::poBmpData::slideShowAll] \
            ${ns}::ViewAllSelSlides "View all selected slides"
        poToolbar AddButton $toolfr [::poBmpData::appendToFile] \
            ${ns}::AppendAllSelSlides "Append all selected slides" -state $sPo(CawtState)

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::sheetIn] \
            ${ns}::AppendSelImages "Append all images selected in Image Browser" -state $sPo(CawtState)

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).fr.statfr true]

        UpdateMainTitle
        WriteInfoStr $sPo(initStr) $sPo(initType)

        CreateTablelistFrame $sPo(cacheDir)
        CreateSlideFrame

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        if { ! [poApps GetHideWindow] } {
            update
        }
        $sPo(paneWin) pane $sPo(paneWin).dirfr -weight 0
        $sPo(paneWin) pane $sPo(paneWin).imgfr -weight 1
        $sPo(paneWin) sashpos 0 $sPo(sash)

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }

        if { [info exists sPo(firstTime)] } {
            ShowSpecificSettWin "Sessions"
        }
    }

    proc AddRecentSessions { menuId } {
        variable sPo
        variable ns

        poMenu DeleteMenuEntries $menuId 0
        foreach sessionName $sPo(sessionList) {
            set dir $sPo(session,$sessionName,sourceDir)
            if { [file isdirectory $dir] } {
                set bmp [poWin GetOkBitmap]
            } else {
                set bmp [poWin GetCancelBitmap]
            }
            poMenu AddCommand $menuId $sessionName "" "${ns}::UseSession [list $sessionName]" -image $bmp -compound left
        }
    }

    proc SetCurApp { appId } {
        variable sPo

        set sPo(CurApp) $appId
    }

    proc GetCurApp {} {
        variable sPo

        if { ! [::Cawt::IsComObject $sPo(CurApp)] } {
            SetCurApp ""
        }
        return $sPo(CurApp)
    }

    proc SetCurPres { presId } {
        variable sPo

        set sPo(CurPres) $presId
    }

    proc GetCurPres {} {
        variable sPo

        if { ! [::Cawt::IsComObject $sPo(CurPres)] } {
            SetCurPres ""
        }
        return $sPo(CurPres)
    }

    proc CreateThumbImg { phImg phName maxThumbSize } {
        variable sPo

        set w [image width  $phImg]
        set h [image height $phImg]

        if { $w > $h } { 
            set ws [expr int ($maxThumbSize)]
            set hs [expr int ((double($h)/double($w)) * $maxThumbSize)]
        } else {
            set ws [expr int ((double($w)/double($h)) * $maxThumbSize)]
            set hs [expr int ($maxThumbSize)]
        }
        set thumbImg [image create photo $phName -width $ws -height $hs]
        set xsub [expr ($w / $ws) + 1]
        set ysub [expr ($h / $hs) + 1]
        $thumbImg copy $phImg -subsample $xsub $ysub -to 0 0
        return $thumbImg
    }

    proc DelSlideCache { slideDir } {
        file delete -force -- $slideDir
    }

    proc ClearAllSelMarks {} {
        variable sImgList

        foreach slidePath [array names sImgList] {
            set sImgList($slidePath) 0
        }
    }

    proc GetSlideFiles { slideDir } {
        variable sPo

        set pptFmt [Ppt GetPptImageFormat $sPo(imgExportType)]
        set imgPattern [format "%s.*.%s" $sPo(imgExportPrefix) $pptFmt]
        set dirCont [poMisc GetDirsAndFiles $slideDir \
                            -showdirs false \
                            -showhiddendirs false \
                            -showhiddenfiles false \
                            -filepattern $imgPattern]
        set fileList [list]
        foreach f [lsort -dictionary [lindex $dirCont 1]] {
            if { ! [string match "*thumb*" $f] } {
                lappend fileList $f
            }
        }
        return $fileList
    }

    proc SelAllSlides { onOff } {
        variable sPo
        variable sImgList

        set slideDir [GetSelCacheDir]
        foreach f [GetSlideFiles $slideDir] {
            set absFileName [file join $slideDir $f]
            set sImgList($absFileName) $onOff
        }
    }

    proc GetSlideList { slideDir getSelectedOnly } {
        variable sPo
        variable sImgList

        set absFileList [list]
        foreach f [GetSlideFiles $slideDir] {
            set absFileName [file join $slideDir $f]
            if { $getSelectedOnly && !$sImgList($absFileName) } {
                continue
            }
            lappend absFileList $absFileName
        }
        return $absFileList
    }

    proc ViewAllSelSlides {} {
        variable sPo
        variable sImgList

        if { ! [info exists sImgList] } {
            return
        }
        set selList [list]
        foreach slidePath [array names sImgList] {
            if { $sImgList($slidePath) } {
                lappend selList $slidePath
            }
        }
        if { [llength $selList] > 0 } {
            ViewSlides [lsort -dictionary $selList]
        }
    }

    proc ViewPresSlides { showSelectedOnly } {
        variable sPo

        set slideDir [GetSelCacheDir]
        set absFileList [GetSlideList $slideDir $showSelectedOnly]
        ViewSlides $absFileList
    }

    proc SlideShowFinished { cmdString code result op } {
        variable ns
        variable sImgList

        if { $result } {
            set markedImgs [poSlideShow::GetMarkedImgs]
            foreach slidePath [array names sImgList] {
                if { [lsearch -nocase -exact $markedImgs $slidePath] >= 0 } {
                    set sImgList($slidePath) 1
                } else {
                    set sImgList($slidePath) 0
                }
            }
        }
        trace remove execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
    }
 
    proc ViewSlides { fileList } {
        variable ns
        variable sImgList

        if { [llength $fileList] == 0 } {
            return
        }
        foreach fileName $fileList {
            if { $sImgList($fileName) } {
                lappend markList 1
            } else {
                lappend markList 0
            }
        }

        trace add execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
        poApps StartApp poSlideShow $fileList
        poSlideShow SetMarkList $markList
    }

    proc DestroySlideBtns {} {
        variable sPo

        foreach w [winfo children $sPo(slideFrame)] {
            destroy $w
        }
    }

    proc ShowSlides {} {
        variable ns 
        variable sPo 
        variable sImgList

        set curDir [GetSelCacheDir]
        if { $curDir eq "" } {
            return
        }
        set pptFile [AbsToRel $curDir $sPo(cacheDir)]
        set pptPath [file join $sPo(sourceDir) $pptFile]

        foreach imgName [image names] {
            if { [string match "slideImg*" $imgName] } {
                image delete $imgName
            }
        }

        set i 0
        set r 0
        set c 0

        set fileList [GetSlideFiles $curDir]
        set numSlides [llength $fileList]

        set orphanedPpt 0
        if { ! [file exists [file join $sPo(sourceDir) $pptFile]] } {
            if { $numSlides > 0 } {
                set orphanedPpt 1
            } else {
                poWin SetScrolledTitle $sPo(slideFrame) "Directory: No slides"
                return
            }
        }

        $sPo(tw) configure -cursor watch

        DestroySlideBtns

        foreach fileName [lsort -dictionary $fileList] {
            set foundThumb 0
            set extension [file extension $fileName]
            set pathName [file join $curDir $fileName]
            set thumbName [file join $curDir [format "%s.thumb%s" $fileName $extension]]
            set imgDict [poType GetImageInfo $pathName]
            set sizeStr [format "%d x %d" \
                         [dict get $imgDict width] \
                         [dict get $imgDict height]]
            if { [file exists $thumbName] } {
                set catchVal [catch {image create photo "slideImgTh$i" \
                                     -file $thumbName} thumbImg]
                if { $catchVal } {
                    poLog Warning "Could not read thumbnail $thumbName"
                } else {
                    set foundThumb 1
                }
            }
            if { ! $foundThumb } {
                set catchVal [catch {image create photo "slideImg$i" \
                                     -file $pathName} phImg]        
                if { $catchVal } {
                    poLog Warning "Could not read image $pathName"
                } else {
                    set thumbImg [CreateThumbImg $phImg "slideImgTh$i" $sPo(thumbSize)]
                }
            }
            set slideBtn $sPo(slideFrame).b_$i
            checkbutton $slideBtn \
                -selectcolor [poSlideShow GetEnabledColor] -bg [poSlideShow GetDisabledColor] \
                -indicatoron false -image $thumbImg -variable ${ns}::sImgList($pathName) 
            poToolhelp AddBinding $slideBtn [format "%s (%s)" $fileName $sizeStr]

            if { ! $foundThumb } {
                image delete $phImg
            }
            grid $slideBtn -row $r -column $c -padx 2 -pady 2 -sticky news
            incr i
            incr c
            if { $c == $sPo(slidesPerRow) } {
                set c 0
                incr r
                poWin SetScrolledTitle $sPo(slideFrame) \
                   [format "%s: Loaded %d out of %d slides" $pptFile $i $numSlides]
                update idletasks
            }
        }

        $sPo(tw) configure -cursor arrow

        if { $orphanedPpt } {
            poWin SetScrolledTitle $sPo(slideFrame) [format \
                "%s: This presentation file does not exist anymore" $pptFile]
                set retVal [tk_messageBox \
                      -title "$sPo(appName) - Warning" \
                      -message "$pptFile does not exist anymore.\n \
                               You should remove this slide cache." \
                      -icon warning -type ok]
        } else {
            poWin SetScrolledTitle $sPo(slideFrame) [format "%s: %d slides" $pptFile $i]
        }
    }

    proc GetDirName { entryWidget whichDir } {
        variable sPo

        set newDir [tk_chooseDirectory -initialdir $sPo($whichDir)]
        if { $newDir eq "" } {
            return
        }
        if { ! [file isdirectory $newDir] } {
            file mkdir $newDir
        }
        set sPo($whichDir) [file normalize $newDir]
    }

    proc GetFileName { title useLastDir { mode "open" } { initFile "" } } {
        variable ns
        variable sPo
 
        set fileTypes {
            {"PowerPoint files" ".pptx .ppt"}
            {"All files" "*"}
        }
            
        if { $useLastDir } {
            set initDir $sPo(lastDir)
        } else {
            set initDir [pwd]
        }

        if { $mode eq "open" } {
            set fileName [tk_getOpenFile -filetypes $fileTypes \
                         -initialdir $sPo(lastDir) -title $title]
        } else {
            if { ! [info exists sPo(LastPptType)] } {
                set sPo(LastPptType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastPptType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }

            set fileName [tk_getSaveFile \
                         -filetypes $fileTypes \
                         -title $title \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastPptType) \
                         -initialfile [file tail $initFile] \
                         -initialdir $initDir]
            if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
                set ext [poMisc GetExtensionByType $fileTypes $sPo(LastPptType)]
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
        if { $fileName ne "" && $useLastDir } {
            set sPo(lastDir) [file dirname $fileName]
        }
        return $fileName
    }

    proc AbsToRel { fileName rootDir } {
        set rootLen [string length [string trimright [file join $rootDir ""] "/"]]
        set name [string range [file join $fileName ""] $rootLen end]
        return [format "%s" [string trimleft $name "/"]]
    }

    proc BuildPptFileList { listBox rootDir } {
        variable sPo

        set dirCont  [poMisc GetDirsAndFiles $rootDir \
                             -showhiddendirs false \
                             -showhiddenfiles false \
                             -filepattern "*.ppt *.pptx"]
        set dirList  [lindex $dirCont 0]
        foreach f [lsort -dictionary [lindex $dirCont 1]] {
            set pptFile [file join $rootDir $f]
            set indDir [file join $sPo(cacheDir) \
                        [AbsToRel $pptFile $sPo(sourceDir)]]

            set isCacheOk 0
            set fileList [GetSlideFiles $indDir]
            set numSlides [llength $fileList]
            set fileTime [file mtime $pptFile]
            set fileTimeStr [clock format $fileTime -format "%Y-%m-%d %H:%M"]
            if { $numSlides > 0 } {
                set imgFile [file join $indDir [lindex $fileList 0]]
                if { $fileTime < [file mtime $imgFile] } {
                    set isCacheOk 1
                }
            }
            $listBox insert end [list "" [file tail $pptFile] $numSlides 0 $fileTimeStr [file dirname $pptFile] $indDir]
            if { $isCacheOk } {
                set color lightgreen
            } else {
                set color red
            }
            $listBox rowconfigure end -background $color
        }

        foreach dir $dirList {
            BuildPptFileList $listBox [file join $rootDir $dir]
        }
    }

    proc ExportPpt { pptFile imgType dropMaster } {
        variable sPo

        set outDir [file join $sPo(cacheDir) [AbsToRel $pptFile $sPo(sourceDir)]]
        DelSlideCache [list $outDir]

        set errMsg ""
        set pptFmt [Ppt GetPptImageFormat $sPo(imgExportType)]
        set retVal [catch { Ppt ExportPptFile \
            [file nativename $pptFile] $outDir \
            "$sPo(imgExportPrefix).%04d.$pptFmt" \
            1 end \
            $pptFmt \
            -1 -1 \
            [expr ! $dropMaster] \
            true \
            $sPo(slidesPerRow) $sPo(thumbSize) \
        } errMsg]
        return $errMsg
    }

    proc CreateSlideCache {} {
        variable sPo

        set listBox $sPo(tableWidget)

        set indList [$listBox curselection]
        if { [llength $indList] == 0 } {
            return
        }

        foreach ind $indList {
            $listBox see $ind
            set f [GetSelSourceFile $ind]
            set errMsg [ExportPpt $f $sPo(imgExportType) $sPo(dropMaster)]
            if { $errMsg eq "" } {
                $listBox rowconfigure $ind -background lightgreen
            } else {
                $listBox rowconfigure $ind -background red
                set retVal [tk_messageBox \
                      -title "$sPo(appName) - Confirmation" \
                      -message "Export of $f failed. ($errMsg)\n\
                               Continue with conversion of next file?" \
                      -type yesno -default yes -icon question]
                if { $retVal eq "no" } {
                    break
                }
            }
            $listBox selection clear $ind
            UpdatePptFileList
        }
    }

    proc SelectForConversion { listBox what } {
        $listBox selection clear 0 end
        if { $what eq "all" } {
            $listBox selection set 0 end
        } elseif { $what eq "red" } {
            set numEntries [$listBox index end]
            for { set i 0 } { $i < $numEntries } { incr i } {
                if { [$listBox rowcget $i -background] eq $what } {
                    $listBox selection set $i $i
                }
            }
        }
    }

    proc UpdatePptFileList {} {
        variable sPo

        set listBox $sPo(tableWidget)
        set rootDir $sPo(sourceDir)

        $sPo(tw) configure -cursor watch
        update

        $listBox delete 0 end
        BuildPptFileList $listBox $rootDir
        CountSelSlides
        set lastSortedColumn [$listBox sortcolumn]
        if { $lastSortedColumn < 0 } {
            $listBox sortbycolumn 1
        } else {
            set sortOrder [$listBox sortorder]
            $listBox sortbycolumn $lastSortedColumn -$sortOrder
        }

        set countGreens 0
        set numEntries [$listBox index end]
        for { set i 0 } { $i < $numEntries } { incr i } {
            if { [$listBox rowcget $i -background] eq "lightgreen" } {
                incr countGreens
            }
        }
        poWin SetScrolledTitle $listBox "Presentations (Total: $numEntries Cached: $countGreens)"
        $sPo(tw) configure -cursor arrow
    }

    proc GetTemplateFileName {} {
        variable sPo
     
        set fileName [GetFileName "Select PowerPoint Template" true "open"]
        if { $fileName ne "" } {
            set sPo(pptTemplate) $fileName
        }
    }

    proc GetColorFromButton { buttonId colName } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo($colName)]
        if { $newColor ne "" } {
            set sPo($colName) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $buttonId configure -bg $newColor }
        }
    }

   proc UpdateCombo { cb typeList showInd } {
        variable sPo

        $cb configure -values $typeList
        if { [llength $typeList] > 0 } {
            $cb current $showInd
            set sPo(curSession) [$cb get]
        } else {
            NewSession "Empty"
        }
    }

    proc ComboCB {} {
        variable ns
        variable sPo

        set sPo(curSession) [$sPo(combo) get]

        set sPo(sourceDir)   $sPo(session,$sPo(curSession),sourceDir)
        set sPo(cacheDir)    $sPo(session,$sPo(curSession),cacheDir)
        set sPo(pptTemplate) $sPo(session,$sPo(curSession),pptTemplate)
        set sPo(dropMaster)  $sPo(session,$sPo(curSession),dropMaster)
        set sPo(sessionChanged) true
    }

    proc AskNewSession {} {
        variable sPo
        variable winId

        set x [winfo pointerx $winId]
        set y [winfo pointery $winId]
        set sessionId 1
        set sessionName "Session$sessionId"
        while { [lsearch $sPo(sessionList) $sessionName] >= 0 } {
            incr sessionId
            set sessionName "Session$sessionId"
        }
        lassign [poWin EntryBox $sessionName $x $y 20] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName ne "" } {
            NewSession $retName
        }
    }

    proc NewSession { sessionName } {
        variable ns
        variable sPo

        if { [lsearch -exact $sPo(sessionList) $sessionName] >= 0 } {
            tk_messageBox -message "Session name $sessionName already exists." \
                          -title "Warning" -icon warning -type ok
            return
        }
        lappend sPo(sessionList) $sessionName
        set sPo(sessionList) [lsort -dictionary $sPo(sessionList)]
        set sessionInd [lsearch $sPo(sessionList) $sessionName]

        set cacheDir [file normalize [file join [poMisc GetTmpDir] $sessionName]]
        set sPo(session,$sessionName,sourceDir)   ""
        set sPo(session,$sessionName,cacheDir)    $cacheDir
        set sPo(session,$sessionName,pptTemplate) ""
        set sPo(session,$sessionName,dropMaster)  1

        UpdateCombo $sPo(combo) $sPo(sessionList) $sessionInd
        event generate $sPo(combo) <<ComboboxSelected>>
    }

    proc AskDelSession {} {
        variable sPo

        set curInd [$sPo(combo) current]
        set sessionName [lindex $sPo(sessionList) $curInd]

        set retVal [tk_messageBox -icon question -type yesno -default yes \
                -message "Delete session $sessionName ?" -title "Confirmation"]
        if { $retVal eq "yes" } {
            if { $curInd > 0 } {
                set tmpList [lrange $sPo(sessionList) 0 [expr $curInd -1]]
            } else {
                set tmpList [list]
            }
            foreach elem [lrange $sPo(sessionList) [expr $curInd +1] end] {
                lappend tmpList $elem
            }
            set sPo(sessionList) $tmpList
            unset sPo(session,$sessionName,sourceDir)
            unset sPo(session,$sessionName,cacheDir)
            unset sPo(session,$sessionName,pptTemplate)
            unset sPo(session,$sessionName,dropMaster)
            UpdateCombo $sPo(combo) $sPo(sessionList) 0
            event generate $sPo(combo) <<ComboboxSelected>>
        }
    }

    proc AskRenameSession {} {
        variable sPo
        variable winId

        set curInd [$sPo(combo) current]
        set sessionName [lindex $sPo(sessionList) $curInd]

        set x [winfo pointerx $winId]
        set y [winfo pointery $winId]
        lassign [poWin EntryBox $sessionName $x $y 20] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName ne "" } {
            RenameSession $sessionName $retName
        }
    }

    proc RenameSession { oldName newName } {
        variable ns
        variable sPo

        if { [lsearch -exact $sPo(sessionList) $newName] >= 0 } {
            tk_messageBox -message "Session name $newName already exists." \
                          -title "Warning" -icon warning -type ok
            return
        }

        set ind [lsearch -exact $sPo(sessionList) $oldName]
        set sPo(sessionList) [lreplace $sPo(sessionList) $ind $ind $newName]

        set sPo(session,$newName,sourceDir)   $sPo(session,$oldName,sourceDir)
        set sPo(session,$newName,cacheDir)    $sPo(session,$oldName,cacheDir)
        set sPo(session,$newName,pptTemplate) $sPo(session,$oldName,pptTemplate)
        set sPo(session,$newName,dropMaster)  $sPo(session,$oldName,dropMaster)
        unset sPo(session,$oldName,sourceDir)
        unset sPo(session,$oldName,cacheDir)
        unset sPo(session,$oldName,pptTemplate)
        unset sPo(session,$oldName,dropMaster)

        UpdateCombo $sPo(combo) $sPo(sessionList) $ind
        event generate $sPo(combo) <<ComboboxSelected>>
    }

    proc _UpdCacheImgFmtCB { comboId } {
        variable sPo

        set sPo(imgExportType) [$comboId get]
    }

    proc _UpdEffectTypeCB { comboId } {
        variable sPo

        set sPo(EffectType) [$comboId get]
    }
    
    proc OKToplevel { tw args } {
        variable sPo

        set sPo(session,$sPo(curSession),sourceDir)   $sPo(sourceDir)
        set sPo(session,$sPo(curSession),cacheDir)    [file normalize $sPo(cacheDir)]
        set sPo(session,$sPo(curSession),pptTemplate) $sPo(pptTemplate)
        set sPo(session,$sPo(curSession),dropMaster)  $sPo(dropMaster)
        if { $sPo(sessionChanged) } {
            UpdateMainTitle
            UpdatePptFileList
        }
        destroy $tw
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

    proc ShowSpecificSettWin { { selectTab "Miscellaneous" } } {
        variable sPo
        variable ns

        set tw .poPresMgr_specWin
        set sPo(specWin,name) $tw

        set x [winfo pointerx $sPo(tw)]
        set y [winfo pointery $sPo(tw)]
        set fmtStr [format "+%d+%d" [expr $x - 40] [expr $y - 10]]

        if { [winfo exists $tw] } {
            poWin Raise $tw
            wm geometry $tw $fmtStr
            return
        }
        toplevel $tw
        wm title $tw "Presentation manager specific settings"
        wm resizable $tw true true
        wm geometry $tw $fmtStr

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

        ttk::frame $nb.sessionsFr
        set tmpList [ShowSessionsTab $nb.sessionsFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.sessionsFr -text "Sessions" -underline 0 -padding 2
        if { $selectTab eq "Sessions" } {
            set selTabInd 1
        }

        ttk::frame $nb.imagesFr
        set tmpList [ShowImagesTab $nb.imagesFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.imagesFr -text "Images/Videos" -underline 0 -padding 2
        if { $selectTab eq "Images" } {
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

    proc ShowMiscTab { tw } {
        variable ns
        variable sPo

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "View type:" \
                           "Slide width (Points):" \
                           "Slide height (Points):" \
                           "Thumbnail size (Pixel):" \
                           "Slides per row:" \
                           "Cache image format:" \
                           "Table position:"] {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky nw -pady 2
            incr row
        }
        poToolhelp AddBinding $tw.l3 "Changes will not take effect until you recreate your slide cache"
        poToolhelp AddBinding $tw.l4 "Changes will not take effect until you redisplay a slide cache"
        poToolhelp AddBinding $tw.l5 "Changes will not take effect until you recreate your slide cache"
        poToolhelp AddBinding $tw.l6 "Changes will not take effect until you restart the application"

        set varList {}

        # Generate right column with entries and buttons.

        # Part 1: PowerPoint view type
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::checkbutton $tw.fr$row.cb1 -text "Show slide overview" \
                                   -variable ${ns}::sPo(viewSlideSorter)
        poToolhelp AddBinding $tw.fr$row.cb1 \
            "PowerPoint will show slides overview after appending slides"
        pack $tw.fr$row.cb1 -side top -anchor w -in $tw.fr$row
        set tmpList [list [list sPo(viewSlideSorter)] [list $sPo(viewSlideSorter)]]
        lappend varList $tmpList

        # Part 2: Slide width
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(SlideWidth) -row $row -width 4 -min 72 -max 4032
        
        set tmpList [list [list sPo(SlideWidth)] [list $sPo(SlideWidth)]]
        lappend varList $tmpList

        # Part 3: Slide height
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(SlideHeight) -row $row -width 4 -min 72 -max 4032
        
        set tmpList [list [list sPo(SlideHeight)] [list $sPo(SlideHeight)]]
        lappend varList $tmpList

        # Part 4: Thumbnail size
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(thumbSize) -row $row -width 3 -min 50 -max 999
        
        set tmpList [list [list sPo(thumbSize)] [list $sPo(thumbSize)]]
        lappend varList $tmpList

        # Part 5: Slides per row
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(slidesPerRow) -row $row -width 3 -min 1 -max 100

        set tmpList [list [list sPo(slidesPerRow)] [list $sPo(slidesPerRow)]]
        lappend varList $tmpList

        # Part 6: Cache image format
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::combobox $tw.fr$row.cb -state readonly

        set ind 0
        foreach fmt [Ppt GetSupportedImageFormats] {
            lappend strList $fmt
            if { $fmt eq $sPo(imgExportType) } {
                set showInd $ind
            }
            incr ind
        }
        $tw.fr$row.cb configure -values $strList
        $tw.fr$row.cb current $showInd
        bind $tw.fr$row.cb <<ComboboxSelected>> "${ns}::_UpdCacheImgFmtCB $tw.fr$row.cb"

        pack $tw.fr$row.cb -side top -anchor w -fill x -expand 1

        set tmpList [list [list sPo(imgExportType)] [list $sPo(imgExportType)]]
        lappend varList $tmpList

        # Part 7: Tablelist position
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::radiobutton $tw.fr$row.rb1 -text "Left" -value "Left" -variable ${ns}::sPo(tablelistPos)
        ttk::radiobutton $tw.fr$row.rb2 -text "Top"  -value "Top"  -variable ${ns}::sPo(tablelistPos)
        pack $tw.fr$row.rb1  $tw.fr$row.rb2 -side left -anchor w
        poToolhelp AddBinding $tw.fr$row.rb1 "Changes will not take effect until you restart the application"
        poToolhelp AddBinding $tw.fr$row.rb2 "Changes will not take effect until you restart the application"
        set tmpList [list [list sPo(tablelistPos)] [list $sPo(tablelistPos)]]
        lappend varList $tmpList

        return $varList
    }

    proc ShowImagesTab { tw } {
        variable ns
        variable sPo

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "Image modes:" \
                           "Video resolution:" \
                           "Video FPS:" \
                           "Enable effects:" \
                           "Effect duration (sec):" \
                           "Effect advance time (sec):" \
                           "Effect type:"] {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky nw -pady 2
            incr row
        }

        set varList {}

        # Generate right column with entries and buttons.

        # Part 1: Image modes
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky nw

        ttk::checkbutton $tw.fr$row.cb1 -text "Embed images" \
                         -variable ${ns}::sPo(EmbedImages)
        ttk::checkbutton $tw.fr$row.cb2 -text "Fit images to slide size" \
                         -variable ${ns}::sPo(FitToSlide)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w
        set tmpList [list [list sPo(EmbedImages)] [list $sPo(EmbedImages)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(FitToSlide)] [list $sPo(FitToSlide)]]
        lappend varList $tmpList

        # Part 2: Video resolution
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(VideoResolution) -row $row -width 4 -min 1
        
        set tmpList [list [list sPo(VideoResolution)] [list $sPo(VideoResolution)]]
        lappend varList $tmpList

        # Part 3: Video FPS
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(VideoFps) -row $row -width 3 -min 1
        
        set tmpList [list [list sPo(VideoFps)] [list $sPo(VideoFps)]]
        lappend varList $tmpList

        # Part 4: Use effects
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb -text "Enable effects" \
                         -variable ${ns}::sPo(UseEffects)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w
        set tmpList [list [list sPo(UseEffects)] [list $sPo(UseEffects)]]
        lappend varList $tmpList

        # Part 5: Effect duration
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedRealEntry $tw.fr$row ${ns}::sPo(EffectDuration) -row $row -width 10 -min 0.0
        set tmpList [list [list sPo(EffectDuration)] [list $sPo(EffectDuration)]]
        lappend varList $tmpList

        # Part 6: Effect advance time
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedRealEntry $tw.fr$row ${ns}::sPo(EffectAdvanceTime) -row $row -width 10 -min 0.0
        set tmpList [list [list sPo(EffectAdvanceTime)] [list $sPo(EffectAdvanceTime)]]
        lappend varList $tmpList

        # Part 7: Effect type
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::combobox $tw.fr$row.cb -state readonly
        set enumList [Ppt GetEnumNames PpEntryEffect]
        $tw.fr$row.cb configure -values $enumList
        set showInd [lsearch -exact $enumList $sPo(EffectType)]
        if { $showInd >= 0 } {
            $tw.fr$row.cb current $showInd
        }
        bind $tw.fr$row.cb <<ComboboxSelected>> "${ns}::_UpdEffectTypeCB $tw.fr$row.cb"
        pack $tw.fr$row.cb -side top -anchor w -fill x -expand 1
        set tmpList [list [list sPo(EffectType)] [list $sPo(EffectType)]]
        lappend varList $tmpList

        return $varList
    }

    proc ShowSessionsTab { tw } {
        variable sPo
        variable ns
        variable winId

        set winId $tw

        set sPo(sessionChanged) false

        ttk::frame $tw.toolfr -borderwidth 1
        ttk::frame $tw.workfr -borderwidth 1
        pack  $tw.toolfr -side top -fill x
        pack  $tw.workfr -side top -fill both -expand 1

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::newfile] \
                            ${ns}::AskNewSession "New session ..."
        poToolbar AddButton $toolfr [::poBmpData::delete "red"] \
                            ${ns}::AskDelSession "Delete session ..."
        poToolbar AddButton $toolfr [::poBmpData::rename] \
                            ${ns}::AskRenameSession "Rename session ..."

        set ww $tw.workfr
        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "Session:" \
                           "PowerPoint source dir:" \
                           "Slide cache dir:" \
                           "PowerPoint template:" \
                           "Export mode:"] {
            ttk::label $ww.l$row -text $labelStr
            grid $ww.l$row -row $row -column 0 -sticky new -pady 2
            incr row
        }

        set varList [list]

        # Generate right column with entries and buttons.
        # Part 1: Session selection
        set row 0
        ttk::frame $ww.fr$row
        grid $ww.fr$row -row $row -column 1 -sticky new -pady 2

        set sPo(combo) $ww.fr$row.cb
        ttk::combobox $sPo(combo) -state readonly

        if { [llength $sPo(sessionList)] == 0 } {
            NewSession "Empty"
        }

        set curInd [lsearch $sPo(sessionList) $sPo(curSession)]
        UpdateCombo $sPo(combo) $sPo(sessionList) $curInd

        pack $ww.fr$row.cb -side top -anchor w -expand 1 -fill x

        set tmpList [list [list sPo(curSession)] [list $sPo(curSession)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(sessionList)] [list $sPo(sessionList)]]
        lappend varList $tmpList

        # Part 2: PowerPoint Source dir
        incr row
        ttk::frame $ww.fr$row
        grid $ww.fr$row -row $row -column 1 -sticky new

        ttk::entry $ww.fr$row.e -textvariable ${ns}::sPo(sourceDir) -width 40
        $ww.fr$row.e xview moveto 1
        ttk::button $ww.fr$row.b -text "Select ..." \
                    -command "${ns}::GetDirName $ww.fr$row.e sourceDir"
        pack $ww.fr$row.e $ww.fr$row.b -side left -anchor w
        poToolhelp AddBinding $ww.fr$row.b \
            "Click to select parent directory to scan for presentations"
        foreach session $sPo(sessionList) {
            set tmpList [list [list  sPo(session,$session,sourceDir)] \
                              [list $sPo(session,$session,sourceDir)]]
            set varList [linsert $varList 0 $tmpList]
        }

        # Part 3: Slide cache dir
        incr row
        ttk::frame $ww.fr$row
        grid $ww.fr$row -row $row -column 1 -sticky new

        ttk::entry $ww.fr$row.e -textvariable ${ns}::sPo(cacheDir) -width 40
        $ww.fr$row.e xview moveto 1
        ttk::button $ww.fr$row.b -text "Select ..." \
                    -command "${ns}::GetDirName $ww.fr$row.e cacheDir"
        pack $ww.fr$row.e $ww.fr$row.b -side left -anchor w
        poToolhelp AddBinding $ww.fr$row.b \
            "Click to select parent directory for presentation cache"
        foreach session $sPo(sessionList) {
            set tmpList [list [list  sPo(session,$session,cacheDir)] \
                              [list $sPo(session,$session,cacheDir)]]
            set varList [linsert $varList 0 $tmpList]
        }

        # Part 4: PowerPoint Template
        incr row
        ttk::frame $ww.fr$row
        grid $ww.fr$row -row $row -column 1 -sticky new

        ttk::entry $ww.fr$row.e -textvariable ${ns}::sPo(pptTemplate) -width 40
        $ww.fr$row.e xview moveto 1
        ttk::button $ww.fr$row.b -text "Select ..." -command ${ns}::GetTemplateFileName
        pack $ww.fr$row.e $ww.fr$row.b -side left -anchor w
        poToolhelp AddBinding $ww.fr$row.b \
            "Click to select default presentation template for this session"
        foreach session $sPo(sessionList) {
            set tmpList [list [list  sPo(session,$session,pptTemplate)] \
                              [list $sPo(session,$session,pptTemplate)]]
            set varList [linsert $varList 0 $tmpList]
        }

        # Part 5: Drop Master on Export flag
        incr row
        ttk::frame $ww.fr$row
        grid $ww.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $ww.fr$row.cb -text "Drop master slide" -variable ${ns}::sPo(dropMaster)
        pack $ww.fr$row.cb -side left -anchor w
        foreach session $sPo(sessionList) {
            set tmpList [list [list  sPo(session,$session,dropMaster)] \
                              [list $sPo(session,$session,dropMaster)]]
            set varList [linsert $varList 0 $tmpList]
        }

        bind $sPo(combo) <<ComboboxSelected>> ${ns}::ComboCB

        return $varList
    }

    proc NewBlankPpt {} {
        variable sPo

        set appId [Ppt Open]
        Ppt CloseAll $appId
        set presId [Ppt AddPres $appId]
        Ppt SetPresPageSetup $presId -width $sPo(SlideWidth) -height $sPo(SlideHeight)
        if { $sPo(viewSlideSorter) } {
            Ppt SetViewType $presId ppViewSlideSorter
        }
        SetCurApp  $appId
        SetCurPres $presId
    }

    proc CountSelSlides {} {
        variable sPo
        variable sImgList

        set countTotal 0
        set numRows [$sPo(tableWidget) size]
        for { set row 0 } { $row < $numRows } { incr row } {
            set countSel($row) 0
        }
        foreach slidePath [array names sImgList] {
            if { $sImgList($slidePath) } {
                set cacheDir [file dirname $slidePath]
                set row [FindCacheDir $cacheDir]
                if { $row >= 0 } {
                    incr countSel($row)
                }
                incr countTotal
            }
        }
        for { set row 0 } { $row < $numRows } { incr row } {
            SetNumSelectedSlides $row $countSel($row)
        }
        return $countTotal
    }

    proc PrintSelSlides { name1 name2 op } {
        set numSel [CountSelSlides]
        WriteInfoStr "$numSel slide[poMisc Plural $numSel] selected" "Ok"
    }

    proc _AppendImages { fileList { infoProc WriteInfoStr } } {
        variable sPo

        # Switch view mode to slide, otherwise pasting images from the
        # clipboard is not possible.
        set viewType [Ppt GetViewType [GetCurPres]]
        Ppt SetViewType [GetCurPres] ppViewSlide
        set imgCount 1
        foreach fileName $fileList {
            $infoProc "Loading image [file tail $fileName] ($imgCount out of [llength $fileList]) ..." "Watch"
            if { [poApps GetVerbose] } {
                puts "Loading image [file tail $fileName] ($imgCount out of [llength $fileList]) ..."
            }
            set imgFmt [poImgType GetFmtByExt [file extension $fileName]]
            set isSupportedByPpt [Ppt IsImageFormatSupported $imgFmt]
            if { $isSupportedByPpt } {
                set slideId [Ppt AddSlide [GetCurPres]]
                set imgId [Ppt InsertImage $slideId $fileName -fit $sPo(FitToSlide) \
                          -link [expr ! $sPo(EmbedImages)] -embed $sPo(EmbedImages)]
                incr imgCount
            } else {
                set retVal [catch {poImgMisc LoadImg $fileName} imgDict]
                if { $retVal == 0 } {
                    set slideId [Ppt AddSlide [GetCurPres]]
                    set phImg [dict get $imgDict phImg]
                    set imgId [Ppt InsertImage $slideId $phImg -fit $sPo(FitToSlide) \
                              -link [expr ! $sPo(EmbedImages)] -embed $sPo(EmbedImages)]
                    incr imgCount
                }
            }

            if { $sPo(UseEffects) && [info exists slideId] } {
                Ppt SetSlideShowTransition $slideId \
                    -duration $sPo(EffectDuration) \
                    -advancetime $sPo(EffectAdvanceTime) \
                    -effect $sPo(EffectType)
            }
        }
        Ppt SetViewType [GetCurPres] $viewType
        $infoProc "Loaded [expr $imgCount -1] images out of [llength $fileList] files." "Ok"
        if { [poApps GetVerbose] } {
            puts "Loaded [expr $imgCount -1] images out of [llength $fileList] files."
        }
    }

    proc AppendSelImages { { infoProc WriteInfoStr } } {
        variable sPo

        set fileList [poImgBrowse GetSelectedFiles]
        if { [llength $fileList] == 0 } {
            $infoProc "No images selected in Image Browser." "Error"
            return
        }
        if { ! [Ppt IsValidPresId [GetCurPres]] } {
            $infoProc "No presentation specified for appending. Create or open a presentation first." "Error"
            return
        }
        _AppendImages $fileList $infoProc
    }

    proc AppendAllSelSlides {} {
        variable sImgList

        if { ! [info exists sImgList] } {
            return
        }
        set selList [list]
        foreach slidePath [array names sImgList] {
            if { $sImgList($slidePath) } {
                lappend selList $slidePath
            }
        }
        if { [llength $selList] > 0 } {
            AppendSlides [lsort -dictionary $selList]
        }
    }

    proc AppendSelSlides {} {
        variable sPo

        set slideDir [GetSelCacheDir]
        set absFileList [GetSlideList $slideDir true]
        AppendSlides $absFileList
    }

    proc AppendSlides { slidePathList } {
        variable sPo

        if { [llength $slidePathList] == 0 } {
            return
        }

        foreach slidePath $slidePathList {
            set shortName [file tail $slidePath]
            regexp -nocase -- {([A-z]*)([0-9]+)} $shortName total name slideNum

            set pptFile [file dirname $slidePath] 
            set pptFile [file join $sPo(sourceDir) [AbsToRel $pptFile $sPo(cacheDir)]]

            if { ! [Ppt IsValidPresId [GetCurPres]] } {
                tk_messageBox -message \
                    "No presentation specified for appending. \n\
                     Create or open a presentation first." \
                     -type ok -icon info -title "$sPo(appName) - Usage message"
                return
            }
            set srcPresId [Ppt OpenPres [GetCurApp] $pptFile true]
            set catchVal [catch { Ppt CopySlide $srcPresId [string trimleft $slideNum "0"] end [GetCurPres] } retVal]
            Ppt Close $srcPresId
            if { $catchVal } {
                tk_messageBox -message \
                    "No presentation specified for appending. \n\
                     Create or open a presentation first." \
                     -type ok -icon info -title "$sPo(appName) - Usage message"
            }
        }
    }

    proc DelPptByListBox { listBox } {
        variable sPo

        set sourceFileList [GetSelSourceFiles]
        set numFiles [llength $sourceFileList]
        if { $numFiles == 0 } {
            return
        }
        set retVal [tk_messageBox \
              -title "$sPo(appName) - Confirmation" \
              -message "Delete selected $numFiles presentation(s) ?" \
              -type yesno -default yes -icon question]
        if { $retVal eq "yes" } {
            foreach f [GetSelSourceFiles] {
                file delete $f
            }
            UpdatePptFileList
        }
    }

    proc OpenPptSourceDir { listBox } {
        set sourceDir [GetSelSourceDir]
        if { $sourceDir ne "" } {
            poExtProg StartFileBrowser $sourceDir
        } else {
            WriteInfoStr "No presentation selected." "Error"
        }
    }

    proc OpenPptCacheDir { listBox } {
        set cacheDir [GetSelCacheDir]
        if { [file isdirectory $cacheDir] } {
            poExtProg StartFileBrowser $cacheDir
        } else {
            WriteInfoStr "No presentation selected or not yet cached." "Error"
        }
    }

    proc OpenPptByListBox { listBox } {
        foreach f [GetSelSourceFiles] {
            OpenPpt $f 0 0
        }
    }

    proc AskOpenPpt { { useLastDir true } } {
        variable sPo
     
        set fileName [GetFileName "Open file" $useLastDir "open" $sPo(curFile)]
        if { $fileName ne "" } {
            OpenPpt $fileName 0 0
        }
    }

    proc OpenTmplPpt { } {
        variable sPo

        if { ! [file exists $sPo(pptTemplate)] } {
            tk_messageBox -message \
                "Sorry, no template file specified. \n\
                 Use application specific Session menu to set your default template." \
                 -type ok -icon info -title "$sPo(appName) - Usage message"
        } else {
            OpenPpt $sPo(pptTemplate)
        }
        focus $sPo(tw)
    }

    proc OpenPpt { fileName { closeOpenWindows 1 } { readOnly 1 } } {
        variable sPo

        set fileName [file nativename [file normalize $fileName]]
        set appId [Ppt Open]
        if { $closeOpenWindows } {
            Ppt CloseAll $appId
        }
        set presId [Ppt OpenPres $appId $fileName $readOnly]
        if { $sPo(viewSlideSorter) } {
            Ppt SetViewType $presId ppViewSlideSorter
        }
        SetCurApp  $appId
        SetCurPres $presId
        set sPo(curFile) $fileName
        UpdateMainTitle
    }

    proc AskSavePpt { { useLastDir true } } {
        variable sPo
     
        if { ! [Ppt IsValidPresId [GetCurPres]] } {
            tk_messageBox -message \
                "No presentation specified for saving.\n\
                 Create or open a presentation first." \
                 -type ok -icon info -title "$sPo(appName) - Usage message"
            return
        }
        set fileName [GetFileName "Save PowerPoint file as" $useLastDir "save" $sPo(curFile)]
        if { $fileName ne "" } {
            SavePpt $fileName
        }
    }

    proc SavePpt { fileName } {
        variable sPo

        Ppt SaveAs [GetCurPres] $fileName
        set sPo(curFile) $fileName
        UpdateMainTitle
    }

    proc CheckVideoCompletion {} {
        variable ns
        variable sPo

        incr sPo(NumVideoCompletionCalls)
        poWin UpdateStatusProgress $sPo(StatusWidget) $sPo(NumVideoCompletionCalls)
        if { ! [Ppt IsValidPresId [GetCurPres]] } {
            WriteInfoStr "Video creation of $sPo(VideoFile) failed." "Error"
        }
        set status [Ppt GetCreateVideoStatus [GetCurPres]]
        if { $status == $Ppt::ppMediaTaskStatusDone } {
            WriteInfoStr "Video creation of $sPo(VideoFile) finished." "Ok"
            poWin UpdateStatusProgress $sPo(StatusWidget) 0
        } elseif { $status == $Ppt::ppMediaTaskStatusFailed } {
            WriteInfoStr "Video creation of $sPo(VideoFile) failed." "Error"
            poWin UpdateStatusProgress $sPo(StatusWidget) 0
        } else {
            WriteInfoStr "Video creation of $sPo(VideoFile) in progress ..." "Watch"
            after 500 ${ns}::CheckVideoCompletion
        }
    }

    proc AskSaveVideo { { useLastDir true } } {
        variable sPo
     
        if { ! [Ppt IsValidPresId [GetCurPres]] } {
            tk_messageBox -message \
                "No presentation specified for saving as video.\n\
                 Create or open a presentation first." \
                 -type ok -icon info -title "$sPo(appName) - Usage message"
            return
        }
        set fileName [GetVideoFileName $sPo(curFile)]
        if { $fileName ne "" } {
            Ppt CreateVideo [GetCurPres] $fileName -resolution $sPo(VideoResolution) -fps $sPo(VideoFps) -wait false
            poWin InitStatusProgress $sPo(StatusWidget) 5 "indeterminate"
            set sPo(NumVideoCompletionCalls) 0
            CheckVideoCompletion
        }
    }

    proc GetVideoFileName { { initFile "" } } {
        variable ns
        variable sPo
     
        set fileTypes {
            {"MP4 files" ".mp4"}
            {"WMV files" ".wmv"}
            {"All files" "*"}
        }
        if { ! [info exists sPo(LastVideoType)] } {
            set sPo(LastVideoType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastVideoType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save Video as" \
                     -parent $sPo(tw) \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sPo(LastVideoType) \
                     -initialfile [file tail $initFile] \
                     -initialdir $sPo(lastDir)]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sPo(LastVideoType)]
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
            set sPo(VideoFile) $fileName
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init all variables stored in the config file with default values.
        SetWindowPos mainWin 10 30 800 500
        SetMainWindowSash 250
        SetCurDirectory [pwd]
        SetCurFile "Untitled"
        SetShowSlideOverview 1
        SetSlideSize 960 540
        SetSlideModes 150 4
        SetImageModes 1 1
        SetVideoModes 720 30
        SetVideoEffects 1 2.5 1.0 "ppEffectFadeSmoothly"
        SetImgExportFormat "PNG"
        SetTablelistPos "Top"

        set sPo(sessionList) [list]
        SetCurSession "" "" [poMisc GetTmpDir] "" 1

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            set sPo(initType) "Ok"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file \"$cfgFile\" found. Using default values."
            set sPo(initType) "Warning"
            set sPo(firstTime) true
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

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetMainWindowSash [GetMainWindowSash]

            PrintCmd $fp "MainWindowSash"
            PrintCmd $fp "CurDirectory"
            PrintCmd $fp "CurFile"
            PrintCmd $fp "ShowSlideOverview"
            PrintCmd $fp "SlideSize"
            PrintCmd $fp "SlideModes"
            PrintCmd $fp "ImageModes"
            PrintCmd $fp "VideoModes"
            PrintCmd $fp "VideoEffects"
            PrintCmd $fp "ImgExportFormat"
            PrintCmd $fp "CurSession"
            PrintCmd $fp "TablelistPos"

            puts $fp "\n# AddSession sessionName sourceDir destinationDir\
                      pptTemplate dropMaster"
            foreach session [lsort -dictionary [array names sPo "session,*,sourceDir"]] {
                set sessionName [lindex [split $session ","] 1]
                if { [lsearch -exact $sPo(sessionList) $sessionName] < 0 } {
                    continue
                }
                set sourceDir   $sPo(session,$sessionName,sourceDir)
                set cacheDir    $sPo(session,$sessionName,cacheDir)
                set pptTemplate $sPo(session,$sessionName,pptTemplate)
                set dropMaster  $sPo(session,$sessionName,dropMaster)
                puts $fp "catch {AddSession [list $sessionName] [list $sourceDir] \
                         [list $cacheDir] [list $pptTemplate] $dropMaster}"
            }
            close $fp
        }
    }

    proc GetUsageMsg {} {
        global tcl_platform
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[DirOrFile1]\ \[DirOrFileN\]\n"
        append msg "\n"
        append msg "Tool for handling PowerPoint presentations.\n"
        append msg "\n"
        append msg "If image files are supplied, these are loaded into a presentation\n"
        append msg "one image per slide. If a directory is specified all contained images\n"
        append msg "are loaded into the presentation.\n"
        append msg "This presentation may then be used to create a video.\n"
        append msg "\n"
        append msg "General options:\n"
        append msg "--session <string>  : Use specified session name or session index.\n"
        append msg "                      Session indices start at 1.\n"
        if { $tcl_platform(platform) eq "windows" } {
            append msg "--imgfmt <string>   : Use specified format for cache images.\n"
            append msg "                      Valid formats: [Ppt GetSupportedImageFormats].\n"
            append msg "                      Default: $sPo(imgExportType).\n"
            append msg "\n"
            append msg "Video options:\n"
            append msg "--pptfile <string>  : Save presentation as PowerPoint file.\n"
            append msg "--videofile <string>: Save presentation as video file.\n"
            append msg "                      Valid file extensions: \".mp4\" \".wmv\"\n"
            append msg "--embed <bool>      : Embed images into presentation. Default: $sPo(EmbedImages).\n"
            append msg "--fit <bool>        : Fit images to slide size. Default: $sPo(FitToSlide).\n"
            append msg "--resolution <int>  : Vertical resolution of video. Default: $sPo(VideoResolution).\n"
            append msg "--fps <int>         : Frames per seconds of video. Default: $sPo(VideoFps).\n"
            append msg "--useeffects <bool> : Enable or disable slide effects. Default: $sPo(UseEffects).\n"
            append msg "--duration <float>  : Duration of each slide in seconds. Default: $sPo(EffectDuration).\n"
            append msg "--advance <float>   : Advance time of each slide in seconds. Default: $sPo(EffectAdvanceTime).\n"
            append msg "--effect <string>   : Slide change effect. Default: $sPo(EffectType).\n"
            append msg "                      See http://www.cawt.tcl3d.org/download/CawtReference-Ppt-Enum.html#::Ppt::Enum::PpEntryEffect\n"
        }
        append msg "\n"
        append msg "Available sessions:\n"
        append msg "[GetSessionListAsString]"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
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

    proc CloseSubWindows {} {
        variable sPo

        # TODO Check sub-windows
        # catch {destroy $sPo(tileWin,name)}
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

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        poApps ExitApp
    }

    proc ParseCommandLine { argList } {
        global tcl_platform
        variable ns
        variable sPo

        set curArg 0
        set fileList  [list]
        set batchList [list]
        set videoFile ""
        set pptFile   ""
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "imgfmt" } {
                    incr curArg
                    set sPo(imgExportType) [lindex $argList $curArg]
                    if { $tcl_platform(platform) eq "windows" } {
                        if { ! [Ppt IsImageFormatSupported $sPo(imgExportType)] } {
                            PrintErrorAndExit false "Unknown image format \"$sPo(imgExportType)\" specified."
                        }
                    }
                } elseif { $curOpt eq "session" } {
                    incr curArg
                    ${ns}::UseSession [lindex $argList $curArg]
                } elseif { $curOpt eq "videofile" } {
                    incr curArg
                    set videoFile [lindex $argList $curArg]
                } elseif { $curOpt eq "pptfile" } {
                    incr curArg
                    set pptFile [lindex $argList $curArg]
                } elseif { $curOpt eq "embed" } {
                    incr curArg
                    set sPo(EmbedImages) [lindex $argList $curArg]
                } elseif { $curOpt eq "fit" } {
                    incr curArg
                    set sPo(FitToSlide) [lindex $argList $curArg]
                } elseif { $curOpt eq "resolution" } {
                    incr curArg
                    set sPo(VideoResolution) [lindex $argList $curArg]
                } elseif { $curOpt eq "fps" } {
                    incr curArg
                    set sPo(VideoFps) [lindex $argList $curArg]
                } elseif { $curOpt eq "useffects" } {
                    incr curArg
                    set sPo(UseEffects) [lindex $argList $curArg]
                } elseif { $curOpt eq "duration" } {
                    incr curArg
                    set sPo(EffectDuration) [lindex $argList $curArg]
                } elseif { $curOpt eq "advance" } {
                    incr curArg
                    set sPo(EffectAdvanceTime) [lindex $argList $curArg]
                } elseif { $curOpt eq "effect" } {
                    incr curArg
                    set sPo(EffectType) [lindex $argList $curArg]
                }
            } else {
                if { [file exists $curParam] } {
                    lappend fileList $curParam
                }
            }
            incr curArg
        }
        set imgList [list]
        foreach fileOrDirName $fileList {
            if { [file isdirectory $fileOrDirName] } {
                set dir [poMisc FileSlashName $fileOrDirName]
                foreach f [poMisc GetDirCont $dir "*"] {
                    lappend imgList [file join $dir $f]
                }
            } else {
                lappend imgList $fileOrDirName
            }
        }
        if { [llength $imgList] > 0 } {
            if { [poApps GetVerbose] } {
                puts "Creating new presentation"
            }
            NewBlankPpt
            _AppendImages $imgList

            if { $pptFile ne "" } {
                if { [poApps GetVerbose] } {
                    WriteInfoStr "Saving as PowerPoint file: $pptFile" "Watch"
                    puts "Saving as PowerPoint file: $pptFile"
                }
                SavePpt $pptFile
            }
            if { $videoFile ne "" } {
                if { [poApps GetVerbose] } {
                    WriteInfoStr "Saving as video file: $videoFile" "Watch"
                    puts "Saving as video file: $videoFile"
                }
                set waitFlag false
                if { [poApps UseBatchMode] } {
                    set waitFlag true
                }
                Ppt CreateVideo [GetCurPres] $videoFile \
                    -verbose [poApps GetVerbose] \
                    -wait $waitFlag \
                    -check 2.0 \
                    -resolution $sPo(VideoResolution) \
                    -fps $sPo(VideoFps)
            }
            if { [poApps UseBatchMode] } {
                # Do not save settings to file.
                poApps SetAutosaveOnExit false
                Ppt Close [GetCurPres]
                Ppt Quit [GetCurApp]
                Cawt Destroy
                exit 0
            }
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poPresMgr Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
