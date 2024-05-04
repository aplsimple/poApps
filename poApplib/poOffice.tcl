# Module:         poOffice
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office programs.

namespace eval poOffice {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin CloseAppWindow
    namespace export ParseCommandLine IsOpen
    namespace export SetHoriPaneWidget SetVertPaneWidget
    namespace export SelectNotebookTab
    namespace export SetSashPos GetSashPos
    namespace export GetUsageMsg
    namespace export GetSupportedExtensions HasSupportedExtension

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poOffice"  ; # Name of toplevel window
        set sPo(appName) "poOffice"   ; # Name of tool
        set sPo(cfgDir)  ""           ; # Directory containing config files

        SetCurFrame ""

        set sPo(FileType,Excel) {
            { "Excel files"      ".xls .xlsx .xlsm" }
        }
        set sPo(FileType,Ppt) {
            { "PowerPoint files" ".ppt .pptx .pptm" }
        }
        set sPo(FileType,Word) {
            { "Word files"       ".doc .docx .docm" }
        }
        set sPo(FileType,Holiday) {
            { "Holiday files"    ".hol" }
        }
        set sPo(FileType,Office) [list        \
            [lindex $sPo(FileType,Excel) 0]   \
            [lindex $sPo(FileType,Ppt) 0]     \
            [lindex $sPo(FileType,Word) 0]    \
            [lindex $sPo(FileType,Holiday) 0] \
            [list "All files"  "*"]           \
        ]
    }

    proc GetSupportedExtensions { { officeType "Office" } } {
        variable sPo

        set extList [list]
        if { [info exists sPo(FileType,$officeType)] } {
            foreach entry $sPo(FileType,$officeType) {
                foreach ext [lindex $entry 1] {
                    if { $ext eq "*" || $ext eq "*.*" } {
                        continue
                    }
                    lappend extList $ext
                }
            }
        }
        return $extList
    }

    proc HasSupportedExtension { fileName { officeType "Office" } } {
        set ext [file extension $fileName]
        if { [lsearch -exact [GetSupportedExtensions $officeType] $ext] >= 0 } {
            return true
        }
        return false
    }

    # The following functions are used for loading/storing application
    # specific settings in a configuration file.

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

    proc SetHoriPaneWidget { w officeType } {
        variable sPo

        set sPo(paneHori,$officeType) $w
    }

    proc SetVertPaneWidget { w officeType } {
        variable sPo

        set sPo(paneVert,$officeType) $w
    }

    proc SetSashPos { sashX0 sashX1 sashY0 officeType } {
        variable sPo

        set sPo(sashX0,$officeType) $sashX0
        set sPo(sashX1,$officeType) $sashX1
        set sPo(sashY0,$officeType) $sashY0
    }

    proc GetSashPos { officeType } {
        variable sPo

        set sashX0 $sPo(sashX0,$officeType)
        set sashX1 $sPo(sashX1,$officeType)
        if { [info exists sPo(paneHori,$officeType)] && \
            [winfo exists $sPo(paneHori,$officeType)] } {
            set sashX0 [$sPo(paneHori,$officeType) sashpos 0]
            if { [llength [$sPo(paneHori,$officeType) panes]] > 2 } {
                set sashX1 [$sPo(paneHori,$officeType) sashpos 1]
            }
        }
        set sashY0 $sPo(sashY0,$officeType)
        if { [info exists sPo(paneVert,$officeType)] && \
            [winfo exists $sPo(paneVert,$officeType)] } {
            set sashY0 [$sPo(paneVert,$officeType) sashpos 0]
        }
        return [list $sashX0 $sashX1 $sashY0]
    }

    proc SetCurDirectory { curDir } {
        variable sPo

        set sPo(LastDir) $curDir
    }

    proc GetCurDirectory {} {
        variable sPo

        return [list $sPo(LastDir)]
    }

    proc SetCurFile { curFile } {
        variable sPo

        set sPo(CurFile) $curFile
    }

    proc GetCurFile {} {
        variable sPo

        return $sPo(CurFile)
    }

    proc SetReadOnlyMode { onOff } {
        variable sPo

        set sPo(ReadOnlyMode) $onOff
    }

    proc GetReadOnlyMode {} {
        variable sPo

        return [list $sPo(ReadOnlyMode) ]
    }

    proc SetVisibleMode { onOff } {
        variable sPo

        set sPo(VisibleMode) $onOff
    }

    proc GetVisibleMode {} {
        variable sPo

        return [list $sPo(VisibleMode) ]
    }

    proc SetEmbeddedMode { onOff } {
        variable sPo

        set sPo(EmbeddedMode) $onOff
    }

    proc GetEmbeddedMode {} {
        variable sPo

        return [list $sPo(EmbeddedMode) ]
    }

    proc SelectNotebookTab { { officeType "" } } {
        variable sPo
        variable sCallCount

        if { $officeType eq "" } {
             set tabId [$sPo(MainNotebook) select]
             set officeType [$sPo(MainNotebook) tab $tabId -text]
             if { $officeType eq "PowerPoint" } {
                 set officeType "Ppt"
             }
        }
        if { ! [info exists sCallCount($officeType) ] } {
            set sCallCount($officeType) 1
        }
        if { $sCallCount($officeType) < 3 } {
            set sashX0 $sPo(sashX0,$officeType)
            set sashX1 $sPo(sashX1,$officeType)
            set sashY0 $sPo(sashY0,$officeType)
        } else {
            lassign [GetSashPos $officeType] sashX0 sashX1 sashY0
        }
        incr sCallCount($officeType)

        $sPo(MainNotebook) select $sPo(TabNum,$officeType)
        $sPo(paneHori,$officeType) sashpos 0 $sashX0
        if { [llength [$sPo(paneHori,$officeType) panes]] > 2 } {
            $sPo(paneHori,$officeType) sashpos 1 $sashX1
        }
        $sPo(paneVert,$officeType) sashpos 0 $sashY0
        update
    }

    proc SetCurFrame { fr } {
        variable sPo

        set sPo(curFrame) $fr
    }

    proc GetCurFrame {} {
        variable sPo

        return $sPo(curFrame)
    }

    proc UpdateMainTitle { { selTool "None" } } {
        variable sPo

        set msg [format "%s - %s" $sPo(appName) $selTool] 
        wm title $sPo(tw) $msg
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc GetOfficeFileName { title officeType useLastDir { fileName "" } } {
        variable sPo
     
        if { $useLastDir } {
            set initDir [GetCurDirectory]
        } else {
            set initDir [pwd]
        }
        set fileName [tk_getOpenFile -filetypes $sPo(FileType,$officeType) \
                      -initialdir $initDir -title $title]
        if { $fileName ne "" && $useLastDir } {
            SetCurDirectory [file dirname $fileName]
        }
        return $fileName
    }

    proc ReadOfficeFile { fileName } {
        if { [HasSupportedExtension $fileName "Excel"] } {
            OpenExcelFile $fileName
        } elseif { [HasSupportedExtension $fileName "Ppt"] } {
            OpenPptFile $fileName
        } elseif { [HasSupportedExtension $fileName "Word"] } {
            OpenWordFile $fileName
        } elseif { [HasSupportedExtension $fileName "Holiday"] } {
            OpenHolidayFile $fileName
        } else {
            WriteInfoStr "File extension [file extension $fileName] not supported." "Error"
        }
    }

    proc AskOpenOfficeFile { officeType { useLastDir true } } {
        set fileName [GetOfficeFileName "Open file" $officeType $useLastDir [GetCurFile]]
        if { $fileName ne "" } {
            ReadOfficeFile $fileName
        }
    }

    proc OpenOfficeFileFromWinSelect {} {
        variable sPo

        set fileName [poWinSelect GetValue $sPo(fileCombo)]
        if { [file exists $fileName] } {
            ReadOfficeFile $fileName
        }
    }

    proc OpenOfficeFileFromDrop { fr fileList } {
        variable sPo

        # TODO: Currently only 1 file supported.
        if { [llength $fileList] > 0 } {
            set fileName [lindex $fileList 0]
            poWinSelect SetValue $sPo(fileCombo) $fileName
            ReadOfficeFile $fileName
        }
    }

    proc ReloadOfficeFile {} {
        ReadOfficeFile [GetCurFile]
    }

    proc GetMasterFrame {} {
        variable sPo

        return $sPo(workFr).fr
    }

    proc AddRecentFiles { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 5
        poMenu AddRecentFileList $menuId ${ns}::ReadOfficeFile -extensions [GetSupportedExtensions]
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo

        if { [poMisc HavePkg "cawt"] } {
            set retVal [catch { Word OpenNew } appId]
            if { $retVal != 0 } {
                set sPo(HaveCawt)  false
                set sPo(CawtState) "disabled"
                set sPo(initStr)   "No Office suite available"
                set sPo(initType)  "Error"
            } else {
                set sPo(HaveCawt)  true
                set sPo(CawtState) "normal"
                Word Quit $appId
            }
        } else {
            set sPo(HaveCawt)  false
            set sPo(CawtState) "disabled"
            set sPo(initStr)   "Office utilities not supported for this platform"
            set sPo(initType)  "Error"
        }

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

        # Create 3 main frames for tool buttons, work frame and status window.
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
     
        # Add new toolbar group and associated buttons.
        set toolfr $sPo(tw).fr.toolfr
        set btnfr  $toolfr.btnfr
        set filefr $toolfr.filefr

        ttk::frame $btnfr
        ttk::separator $toolfr.sep -orient vertical
        ttk::frame $filefr
        pack $btnfr      -side left -anchor w
        pack $toolfr.sep -side left -padx 2 -fill y
        pack $filefr     -side left -anchor w -expand 1 -fill x

        poToolbar New $btnfr
        poToolbar AddGroup $btnfr
        poToolbar AddButton $btnfr [::poBmpData::redo] ${ns}::ReloadOfficeFile "Reload current file" -state $sPo(CawtState)

        poToolbar AddGroup $btnfr
        poToolbar AddCheckButton $btnfr [::poBmpData::lock] \
                  "" "Open document in read-only mode" -variable ${ns}::sPo(ReadOnlyMode) -state $sPo(CawtState)
        poToolbar AddCheckButton $btnfr [::poBmpData::open] \
                  "" "Open Office application window" -variable ${ns}::sPo(VisibleMode) -state $sPo(CawtState)
        poToolbar AddCheckButton $btnfr [::poBmpData::slideShowMarked] \
                  "" "Embed Office application window" -variable ${ns}::sPo(EmbeddedMode) -state $sPo(CawtState)

        set sPo(fileCombo) [poWinSelect CreateFileSelect $filefr [GetCurFile] \
                            "open" [poBmpData::open] "Select Office file ..."]
        poWinSelect Enable $sPo(fileCombo) $sPo(HaveCawt)
        poWinSelect SetFileTypes $sPo(fileCombo) $sPo(FileType,Office)
        bind $sPo(fileCombo) <Key-Return>     "${ns}::OpenOfficeFileFromWinSelect"
        bind $sPo(fileCombo) <<FileSelected>> "${ns}::OpenOfficeFileFromWinSelect"

        set sPo(workFr) $sPo(tw).fr.workfr.fr
        ttk::frame $sPo(workFr)
        pack $sPo(workFr) -expand 1 -fill both

        if { $sPo(HaveCawt) } {
            # Create a Drag-And-Drop binding for the work frame.
            poDragAndDrop AddTtkBinding $sPo(workFr) "${ns}::OpenOfficeFileFromDrop"
        }

        # Create a notebook for the supported Office applications.
        set nb $sPo(workFr).nb
        ttk::notebook $nb
        pack $nb -fill both -expand 1
        ttk::notebook::enableTraversal $nb
        set sPo(MainNotebook) $nb

        # Create the frames for the notebook tabs and add to the notebook.
        set padding 3

        set excelFr $nb.excelfr
        ttk::frame $excelFr
        $nb add $excelFr -text "Excel" -underline 0 -padding $padding
        set sPo(Frame,Excel)  $excelFr
        set sPo(TabNum,Excel) 0
        CreateExcelTab $excelFr

        set pptFr $nb.pptfr
        ttk::frame $pptFr
        $nb add $pptFr -text "PowerPoint" -underline 0 -padding $padding
        set sPo(Frame,Ppt)  $pptFr
        set sPo(TabNum,Ppt) 1
        CreatePptTab $pptFr

        set wordFr $nb.wordfr
        ttk::frame $wordFr
        $nb add $wordFr -text "Word" -underline 0 -padding $padding
        set sPo(Frame,Word)  $wordFr
        set sPo(TabNum,Word) 2
        CreateWordTab $wordFr

        set oneNoteFr $nb.oneNotefr
        ttk::frame $oneNoteFr
        $nb add $oneNoteFr -text "OneNote" -underline 0 -padding $padding
        set sPo(Frame,OneNote)  $oneNoteFr
        set sPo(TabNum,OneNote) 3
        CreateOneNoteTab $oneNoteFr

        set outlookFr $nb.outlookfr
        ttk::frame $outlookFr
        $nb add $outlookFr -text "Outlook" -underline 1 -padding $padding
        set sPo(Frame,Outlook)  $outlookFr
        set sPo(TabNum,Outlook) 4
        CreateOutlookTab $outlookFr

        # Create menus File, Settings, Window and Help
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
        menu $fileMenu -tearoff 0
        set openMenu $fileMenu.open

        $fileMenu add cascade -label "Open" -menu $openMenu

        menu $openMenu -tearoff 0 -postcommand "${ns}::AddRecentFiles $openMenu"
        poMenu AddCommand $openMenu "Select Excel file ..."      "" "${ns}::AskOpenOfficeFile Excel"   -state $sPo(CawtState)
        poMenu AddCommand $openMenu "Select PowerPoint file ..." "" "${ns}::AskOpenOfficeFile Ppt"     -state $sPo(CawtState)
        poMenu AddCommand $openMenu "Select Word file ..."       "" "${ns}::AskOpenOfficeFile Word"    -state $sPo(CawtState)
        poMenu AddCommand $openMenu "Select holiday file ..."    "" "${ns}::AskOpenOfficeFile Holiday" -state $sPo(CawtState)
        $openMenu add separator

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

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        # TODO No application specific settings yet.
        # $settMenu add cascade -label "Application settings" -menu $appSettMenu
        # menu $appSettMenu -tearoff 0

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
        poMenu AddCommand $winMenu [poApps GetAppDescription poPresMgr]   "" "poApps StartApp poPresMgr"
        poMenu AddCommand $winMenu [poApps GetAppDescription poOffice]    "" "poApps StartApp poOffice" -state disabled

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

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).fr.statfr true]

        UpdateMainTitle
        WriteInfoStr $sPo(initStr) $sPo(initType)

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        if { ! [poApps GetHideWindow] } {
            update
        }

        foreach officeType { Outlook OneNote Word Ppt Excel } {
            SelectNotebookTab $officeType
        }
        bind $nb <<NotebookTabChanged>> "${ns}::SelectNotebookTab"
        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init all variables stored in the config file with default values.
        SetWindowPos mainWin 10 30 800 500

        SetCurDirectory [pwd]
        SetCurFile "Untitled"
        SetReadOnlyMode 1
        SetVisibleMode  1
        SetEmbeddedMode 1
        SetSashPos      200 500 150 "Excel"
        SetSashPos      200 500 150 "Ppt"
        SetSashPos      200 500 150 "Word"
        SetSashPos      200 500 150 "OneNote"
        SetSashPos      200 500 150 "Outlook"

        # Settings from poOfficeWord.
        SetMinLength      2
        SetMaxLength     -1
        SetShowNumbers   false
        SetAbbrTableRow  2 
        SetAbbrTableCol  1 
        SetShowLinkTypes true true true true

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr)  "Settings loaded from file $cfgFile"
            set sPo(initType) "Ok"
            source $cfgFile
        } else {
            set sPo(initStr)  "No settings file \"$cfgFile\" found. Using default values."
            set sPo(initType) "Warning"
        }
        set sPo(cfgDir) $cfgDir
    }

    proc PrintCmd { fp cmdName { ns "" } } {
        puts $fp "\n# Set${cmdName} [info args ${ns}::Set${cmdName}]"
        puts $fp "catch {${ns}::Set${cmdName} [${ns}::Get${cmdName}]}"
    }

    proc SaveSettings {} {
        variable sPo
        variable ns

        set cfgFile [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetWindowPos [info args SetWindowPos]"
            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]

            PrintCmd $fp "CurDirectory" "$ns"
            PrintCmd $fp "CurFile"      "$ns"
            PrintCmd $fp "ReadOnlyMode" "$ns"
            PrintCmd $fp "VisibleMode"  "$ns"
            PrintCmd $fp "EmbeddedMode" "$ns"

            SetSashPos {*}[GetSashPos Excel]   Excel
            SetSashPos {*}[GetSashPos Ppt]     Ppt
            SetSashPos {*}[GetSashPos Word]    Word
            SetSashPos {*}[GetSashPos OneNote] OneNote
            SetSashPos {*}[GetSashPos Outlook] Outlook
            puts $fp "\n# SetSashPos [info args SetSashPos]"
            puts $fp "catch {SetSashPos [GetSashPos Excel] Excel}"
            puts $fp "catch {SetSashPos [GetSashPos Ppt] Ppt}"
            puts $fp "catch {SetSashPos [GetSashPos Word] Word}"
            puts $fp "catch {SetSashPos [GetSashPos OneNote] OneNote}"
            puts $fp "catch {SetSashPos [GetSashPos Outlook] Outlook}"

            # Settings from poOfficeWord.
            PrintCmd $fp "MinLength"     "$ns"
            PrintCmd $fp "MaxLength"     "$ns"
            PrintCmd $fp "ShowNumbers"   "$ns"
            PrintCmd $fp "AbbrTableRow"  "$ns"
            PrintCmd $fp "AbbrTableCol"  "$ns"
            PrintCmd $fp "ShowLinkTypes" "$ns"

            close $fp
        }
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] OfficeFile\n"
        append msg "\n"
        append msg "Load specified Office file. If no option is specified, the file\n"
        append msg "is loaded in a graphical user interface for interactive handling.\n"
        append msg "\n"
        append msg "Batch processing information:\n"
        append msg "  An exit status of 0 indicates a successful check.\n"
        append msg "  An exit status of 1 indicates errors in checks.\n"
        append msg "  Any other exit status indicates an error when checking.\n"
        append msg "  On Windows the exit status is stored in ERRORLEVEL.\n"
        append msg "\n"
        append msg "Word specific options:\n"
        append msg "--checkabbr <string>: Enable the abbreviation check using specified\n"
        append msg "                      table name.\n"
        append msg "--checklink         : Enable the link check.\n"
        append msg "                      All link types are checked for validity.\n"
        append msg "\n"
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

        if { $sPo(HaveCawt) } {
            CloseExcel
            ClosePpt
            CloseWord
            CloseOneNote
            CloseOutlook
        }
    }

    proc CloseAppWindow {} {
        variable sPo


        if { ! [info exists sPo(tw)] || ! [winfo exists $sPo(tw)] } {
            return
        }

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        poWin RemoveSwitchableWidgets "Excel"
        poWin RemoveSwitchableWidgets "Ppt"
        poWin RemoveSwitchableWidgets "Word"
        poWin RemoveSwitchableWidgets "OneNote"
        poWin RemoveSwitchableWidgets "Outlook"

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows
        catch { Cawt Destroy }

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        poApps ExitApp
    }

    proc BatchProcess { fullBatch fileName optionDict } {
        if { $fullBatch } {
            # Do not save settings to file and do not show logging console.
            poApps SetAutosaveOnExit false
            poLog SetShowConsole false
        }

        set numFailedChecks 0

        if { [HasSupportedExtension $fileName "Word"] } {
            set numFailedChecks [BatchWord $fullBatch $fileName $optionDict]
        }

        # Print out the status of the checks, set the exit status and quit.
        if { [poApps GetVerbose] } {
            puts -nonewline "Checks succeeded: "
            if { $numFailedChecks != 0 } {
                puts "NO ($numFailedChecks checks failed)"
            } else {
                puts "YES"
            }
        }

        if { $numFailedChecks != 0 } {
            return 1
        } else {
            return 0
        }
    }

    proc ParseCommandLine { argList } {
        variable ns
        variable sPo

        set curArg 0
        set fileList [list]
        set officeFile ""

        set optionDict [dict create \
            checkabbr ""    \
            checklink false \
        ]

        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "checkabbr" } {
                    incr curArg
                    set tableName [lindex $argList $curArg]
                    dict set optionDict checkabbr $tableName
                } elseif { $curOpt eq "checklink" } {
                    dict set optionDict checklink true
                }
            } else {
                lappend fileList $curParam
            }
            incr curArg
        }
        foreach fileOrDirName $fileList {
            if { [HasSupportedExtension $fileOrDirName] } {
                set officeFile $fileOrDirName
            }
        }
        if { $sPo(HaveCawt) } {
            if { $officeFile ne "" } {
                if { [poApps GetVerbose] } {
                    puts "Reading file $officeFile ..."
                }
                if { [poApps GetHideWindow] } {
                    SetVisibleMode false
                }
                ReadOfficeFile $officeFile
            }
        }
        if { [poApps UseBatchMode] && $officeFile ne "" } {
            set exitStatus [BatchProcess true $officeFile $optionDict]
            exit $exitStatus
        }
        if { $officeFile ne "" } {
            BatchProcess false $officeFile $optionDict
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poOffice Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
