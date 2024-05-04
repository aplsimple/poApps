# Module:         poSettings
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2013 / 04 /12
#
# Distributed under BSD license.
#
# Module to handle and display settings notebook windows.
#
# Currently there are 2 types of settings windows:
#     General: Settings used by all poApps
#     Image  : Settings used by all image related poApps

namespace eval poAppearance {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init OpenWin OkWin CancelWin
    namespace export CutFilePath
    namespace export GetUseVertTabs      SetUseVertTabs GetTabStyle
    namespace export GetShowSplash       SetShowSplash
    namespace export GetUseMsgBox        SetUseMsgBox
    namespace export GetStripeColor      SetStripeColor
    namespace export GetNumPathItems     SetNumPathItems
    namespace export GetRecentFileList   GetRecentDirList
    namespace export GetRecentFiles      GetRecentDirs
    namespace export AddToRecentFileList AddToRecentDirList
    namespace export EditRecentList
    namespace export ClearRecentCaches   UpdateRecentCaches
    namespace export IsDirectory IsFile

    proc Init {} {
        variable ns
        variable sett

        SetUseVertTabs    0
        SetShowSplash     1
        SetStripeColor    "#F0F0F0"
        SetNumPathItems   1
        SetUseMsgBox "Exit"    1
        SetUseMsgBox "Error"   1
        SetUseMsgBox "Warning" 1
        SetUseMsgBox "Notify"  1

        ClearRecentList recentFileList
        ClearRecentList recentDirList

        ttk::style configure Vert.TNotebook -tabposition wn -tabplacement nwe
    }

    proc SetUseVertTabs { useVertTabs } {
        variable sett

        set sett(useVertTabs) $useVertTabs
    }

    proc GetUseVertTabs {} {
        variable sett

        return [list $sett(useVertTabs)]
    }

    proc GetTabStyle {} {
        variable sett

        if { $sett(useVertTabs) } {
            return Vert.TNotebook
        } else {
            return Hori.TNotebook
        }
    }

    proc SetShowSplash { showSplash } {
        variable sett

        set sett(showSplash) $showSplash
    }

    proc GetShowSplash {} {
        variable sett

        return [list $sett(showSplash)]
    }

    proc SetUseMsgBox { level onOff } {
        variable sett

        set sett(UseMsgBox,$level) $onOff
    }

    proc GetUseMsgBox { level } {
        variable sett

        if { [info exists sett(UseMsgBox,$level)] } {
            return $sett(UseMsgBox,$level)
        } else {
            return false
        }
    }

    proc SetStripeColor { stripeColor } {
        variable sett

        set sett(tablelistStripeColor) $stripeColor
    }

    proc GetStripeColor {} {
        variable sett

        return $sett(tablelistStripeColor)
    }

    proc AskStripeColor { labelId } {
        variable sett

        set newColor [tk_chooseColor -initialcolor $sett(tablelistStripeColor)]
        if { $newColor ne "" } {
            set sett(tablelistStripeColor) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc SetNumPathItems { numPathItems } {
        variable sett

        set sett(numPathItems) $numPathItems
    }

    proc GetNumPathItems {} {
        variable sett

        return [list $sett(numPathItems)]
    }

    proc SetRecentFileList { fileList } {
        variable sett

        set sett(recentFileList) $fileList
    }

    proc GetRecentFileList { args } {
        variable sett

        return [list $sett(recentFileList)]
    }

    proc IsFile { fileName } {
        variable sFileCache

        if { ! [info exists sFileCache($fileName)] } {
            set sFileCache($fileName) [file isfile $fileName]
        }
        return $sFileCache($fileName)
    }

    proc GetRecentFiles { args } {
        variable sett

        set checkExistence false
        set extensionList  [list]
        foreach { key value } $args {
            switch -exact -nocase -- $key {
                "-check"      { set checkExistence $value }
                "-extensions" { set extensionList  $value }
                default       { error "GetRecentFileList: Unknown key \"$key\" specified" }
            }
        }

        set existList [list]
        foreach f $sett(recentFileList) {
            set fileExt [file extension $f]
            if { [llength $extensionList] == 0 } {
                set found true
            } else {
                set found false
                foreach ext $extensionList {
                    if { $ext eq $fileExt } {
                        set found true
                        break
                    }
                }
            }
            if { $found } {
                lappend existList $f
                if { $checkExistence } {
                    lappend existList [IsFile $f]
                } else {
                    lappend existList -1
                }
            }
        }
        return $existList
    }

    proc SetRecentDirList { dirList } {
        variable sett

        set sett(recentDirList) $dirList
    }

    proc GetRecentDirList {} {
        variable sett

        return [list $sett(recentDirList)]
    }

    proc IsDirectory { dirName } {
        variable sDirCache

        if { ! [info exists sDirCache($dirName)] } {
            set sDirCache($dirName) [file isdirectory $dirName]
        }
        return $sDirCache($dirName)
    }

    proc GetRecentDirs { { checkExistence false } } {
        variable sett

        if { $checkExistence } {
            set existList [list]
            foreach dir $sett(recentDirList) {
                lappend existList $dir
                lappend existList [IsDirectory $dir]
            }
            return $existList
        } else {
            return [list $sett(recentDirList)]
        }
    }

    proc ClearRecentList { listType } {
        variable sett

        set sett($listType) [list]
    }

    proc AddToRecentFileList { fileName } {
        variable sett

        set fileName [file normalize $fileName]
        if { $fileName ne "" && [lsearch -exact $sett(recentFileList) $fileName] < 0 } {
            set sett(recentFileList) [linsert $sett(recentFileList) 0 $fileName]
        }
    }

    proc AddToRecentDirList { dirName } {
        variable sett

        set dirName [file normalize $dirName]
        if { $dirName ne "" && [lsearch -exact $sett(recentDirList) $dirName] < 0 } {
            set sett(recentDirList) [linsert $sett(recentDirList) 0 $dirName]
        }
    }

    proc ClearRecentCaches {} {
        variable sFileCache
        variable sDirCache

        catch { unset sFileCache }
        catch { unset sDirCache }
    }

    proc UpdateRecentCaches {} {
        variable ns
        variable sett
        variable sFileCache
        variable sDirCache

        set foundUncached false
        foreach dir $sett(recentDirList) {
            if { ! [info exists sDirCache($dir)] } {
                set sDirCache($dir) [file isdirectory $dir]
                set foundUncached true
                break
            }
        }
        foreach f $sett(recentFileList) {
            if { ! [info exists sFileCache($f)] } {
                set sFileCache($f) [file isfile $f]
                set foundUncached true
                break
            }
        }

        if { $foundUncached } {
            after idle ${ns}::UpdateRecentCaches
        }
    }

    proc RemoveSelectedRows { tableId } {
        poTablelistUtil RemoveSelectedRows $tableId
    }

    proc RemoveNonExistingEntries { tableId } {
        set indList [list]
        set index 0
        foreach rowEntry [$tableId get 0 end] {
            set listEntry [lindex $rowEntry 1]
            if { ! [file exists $listEntry] } {
                lappend indList $index
            }
            incr index
        }
        $tableId delete $indList
    }

    proc SetRecentListFromTable { tw tableId listType } {
        variable sett

        set sett($listType) [list]
        foreach rowEntry [$tableId get 0 end] {
            lappend sett($listType) [lindex $rowEntry 1]
        }
        destroy $tw
    }

    proc EditRecentList { listType } {
        variable ns
        variable sett

        if { $listType eq "recentFileList" } {
            set winTitle "Edit recent file list"
        } else {
            set winTitle "Edit recent directory list"
        }

        set tw .poSettings_$listType

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw $winTitle

        set mainFr $tw.fr
        ttk::frame $mainFr
        pack $mainFr -expand 1 -fill both

        set toolFr  $mainFr.toolfr
        set tableFr $mainFr.tablefr
        set okFr    $mainFr.okfr
        ttk::frame $toolFr
        ttk::frame $tableFr
        ttk::frame $okFr
        grid $toolFr  -row 0 -column 0 -sticky ew
        grid $tableFr -row 1 -column 0 -sticky news
        grid $okFr    -row 2 -column 0 -sticky ew
        grid rowconfigure    $mainFr 1 -weight 1
        grid columnconfigure $mainFr 0 -weight 1

        set columnList { 0 "#"      "left"
                         0 "File"   "left" }
        if { $listType eq "recentFileList" } {
            lappend columnList 0 "Type" "left"
        }

        set tableId [poWin CreateScrolledTablelist $tableFr true "" \
                    -width 80 -height 10 -exportselection false \
                    -columns $columnList \
                    -stretch 1 \
                    -selectmode extended \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators 1]
        $tableId columnconfigure 0 -showlinenumbers true -editable false
        $tableId columnconfigure 1 -editable false -name fileName
        $tableId columnconfigure 1 -sortmode dictionary
        if { $listType eq "recentFileList" } {
            $tableId columnconfigure 2 -sortmode dictionary
        }

        foreach listEntry $sett($listType) {
            if { $listType eq "recentFileList" } {
                $tableId insert end [list "" $listEntry [string range [file extension $listEntry] 1 end]]
            } else {
                $tableId insert end [list "" $listEntry]
            }
            if { ! [file exists $listEntry] } {
                $tableId configrows end -bg red
            }
        }

        # Add a toolbar with buttons for list editing.
        poToolbar New $toolFr
        poToolbar AddGroup $toolFr

        poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                  "${ns}::RemoveNonExistingEntries $tableId" "Remove non-existing entries"
        poToolbar AddButton $toolFr [::poBmpData::delete] \
                  "${ns}::RemoveSelectedRows $tableId" "Remove selected entries"

        # Create Cancel and OK buttons
        ttk::button $okFr.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                    -compound left \
                    -command "destroy $tw"
        bind $tw <KeyPress-Escape> "destroy $tw"
        wm protocol $tw WM_DELETE_WINDOW "destroy $tw"

        ttk::button $okFr.b2 -text "OK" -image [poWin GetOkBitmap] \
                    -compound left -default active \
                    -command "${ns}::SetRecentListFromTable $tw $tableId $listType"
        pack $okFr.b1 $okFr.b2 -side left -fill x -padx 10 -pady 2 -expand 1
        focus $tw
    }

    proc CutFilePath { pathName } {
        variable sett

        return [poMisc FileCutPath $pathName $sett(numPathItems)]
    }

    proc CancelWin { w args } {
        variable sett

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

    proc UpdateCombo { cb appDescriptionList showInd } {
        $cb configure -values $appDescriptionList
        $cb current $showInd
    }

    proc ComboAppOnStartCB { cb } {
        set appDescription [$cb get]
        poApps SetDefaultAppOnStart [poApps GetAppName $appDescription]
    }

    proc ComboThemesCB { cb } {
        set theme [$cb get]
        poApps SetTheme $theme
    }

    proc OpenWin { fr } {
        variable ns
        variable sett

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Modes:" \
                           "Messages:" \
                           "Recent files:" \
                           "Recent directories:" \
                           "Recent entries cache:" \
                           "Table stripe color:" \
                           "Number of path items:" \
                           "Theme:" \
                           "Default app on startup:" } {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }
        poToolhelp AddBinding $tw.l5 "Number of directory path items displayed with file name"

        set varList [list]
        # Generate right column with entries and buttons.

        # Mode switches
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Use vertical tabs" \
                                        -variable ${ns}::sett(useVertTabs)
        ttk::checkbutton $tw.fr$row.cb2 -text "Show splash screen" \
                                        -variable ${ns}::sett(showSplash)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w -pady 2

        set tmpList [list [list sett(useVertTabs)] [list $sett(useVertTabs)]]
        lappend varList $tmpList
        set tmpList [list [list sett(showSplash)] [list $sett(showSplash)]]
        lappend varList $tmpList

        # Messages
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Use exit message box" \
                                        -variable ${ns}::sett(UseMsgBox,Exit)
        ttk::checkbutton $tw.fr$row.cb2 -text "Use error message box" \
                                        -variable ${ns}::sett(UseMsgBox,Error)
        ttk::checkbutton $tw.fr$row.cb3 -text "Use warning message box" \
                                        -variable ${ns}::sett(UseMsgBox,Warning)
        ttk::checkbutton $tw.fr$row.cb4 -text "Use system notifications" \
                                        -variable ${ns}::sett(UseMsgBox,Notify)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w -pady 2

        set tmpList [list [list sett(UseMsgBox,Exit)] [list $sett(UseMsgBox,Exit)]]
        lappend varList $tmpList
        set tmpList [list [list sett(UseMsgBox,Error)] [list $sett(UseMsgBox,Error)]]
        lappend varList $tmpList
        set tmpList [list [list sett(UseMsgBox,Warning)] [list $sett(UseMsgBox,Warning)]]
        lappend varList $tmpList
        set tmpList [list [list sett(UseMsgBox,Notify)] [list $sett(UseMsgBox,Notify)]]
        lappend varList $tmpList

        # Recent file list.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::button $tw.fr$row.b1 -text "Edit list ..."  -command "${ns}::EditRecentList  recentFileList"
        ttk::button $tw.fr$row.b2 -text "Clear list"     -command "${ns}::ClearRecentList recentFileList"
        poToolhelp AddBinding $tw.fr$row.b2 "This operation can not be undone"

        pack $tw.fr$row.b1 -side left -pady 2 -fill x -expand 1
        pack $tw.fr$row.b2 -side left -pady 2 -fill x -expand 1

        # Recent directory list.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::button $tw.fr$row.b1 -text "Edit list ..."  -command "${ns}::EditRecentList  recentDirList"
        ttk::button $tw.fr$row.b2 -text "Clear list"     -command "${ns}::ClearRecentList recentDirList"
        poToolhelp AddBinding $tw.fr$row.b2 "This operation can not be undone"

        pack $tw.fr$row.b1 -side left -pady 2 -fill x -expand 1
        pack $tw.fr$row.b2 -side left -pady 2 -fill x -expand 1

        # Clear recent cache.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::button $tw.fr$row.b -text "Clear cache" -command "${ns}::ClearRecentCaches"
        pack $tw.fr$row.b -side left -pady 2 -fill x -expand 1

        # Color of tablelist stripes.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sett(tablelistStripeColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                            -command "${ns}::AskStripeColor $tw.fr$row.l"
        poToolhelp AddBinding $tw.fr$row.b1 "Select new table stripe color. Default is: #F0F0F0"
        pack {*}[winfo children $tw.fr$row] -side left -anchor w -expand 1 -fill both

        set tmpList [list [list sett(tablelistStripeColor)] [list $sett(tablelistStripeColor)]]
        lappend varList $tmpList

        # Number of directory path items displayed with file name
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sett(numPathItems) -row $row -width 3 -min 0

        set tmpList [list [list sett(numPathItems)] [list $sett(numPathItems)]]
        lappend varList $tmpList

        # List of available themes.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        set comboThemes $tw.fr$row.comboThemes
        ttk::combobox $comboThemes -state readonly

        set curTheme [ttk::style theme use]
        set themeList [lsort -dictionary [ttk::style theme names]]
        set ind [poMisc Max 0 [lsearch $themeList $curTheme]]

        UpdateCombo $comboThemes $themeList $ind
        $comboThemes current $ind
        bind $comboThemes <<ComboboxSelected>> "${ns}::ComboThemesCB $comboThemes"
        pack $comboThemes -side left -pady 2 -padx 5

        # Default application on startup without command line parameters.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        set comboAppOnStart $tw.fr$row.comboOnStart
        ttk::combobox $comboAppOnStart -state readonly

        set appsList [poApps GetAppDescriptionList]
        set defaultAppName [poApps GetAppDescription [poApps GetDefaultAppOnStart]]
        set ind [poMisc Max 0 [lsearch $appsList $defaultAppName]]

        UpdateCombo $comboAppOnStart $appsList $ind
        $comboAppOnStart current $ind
        bind $comboAppOnStart <<ComboboxSelected>> "${ns}::ComboAppOnStartCB $comboAppOnStart"
        pack $comboAppOnStart -side left -pady 2 -padx 5

        return $varList
    }
}

poAppearance Init

namespace eval poImgAppearance {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init OpenWin OkWin CancelWin
    namespace export StoreLastImgFmtUsed 
    namespace export UsePoImg UseMuPdf UseFitsTcl
    namespace export GetRowOrderCountBitmap ToggleRowOrderCount

    namespace export GetShowColorInHex        SetShowColorInHex
    namespace export GetShowColorCountColumn  SetShowColorCountColumn
    namespace export GetUseLastImgFmt         SetUseLastImgFmt
    namespace export GetLastImgFmtUsed        SetLastImgFmtUsed
    namespace export GetRowOrderCount         SetRowOrderCount 
    namespace export GetHistogramType         SetHistogramType
    namespace export GetHistogramHeight       SetHistogramHeight
    namespace export GetCanvasBackgroundColor SetCanvasBackgroundColor
    namespace export GetCanvasResetColor      SetCanvasResetColor
    namespace export GetShowRawCurValue       SetShowRawCurValue
    namespace export GetShowRawImgInfo        SetShowRawImgInfo
    namespace export GetUsePoImg              SetUsePoImg
    namespace export GetUseMuPdf              SetUseMuPdf
    namespace export GetUseFitsTcl            SetUseFitsTcl

    proc Init {} {
        variable ns
        variable sett

        SetShowColorInHex       0
        SetShowColorCountColumn 0
        SetUseLastImgFmt        0
        SetLastImgFmtUsed       ""
        SetRowOrderCount        "TopDown"
        SetHistogramType        "log"
        SetHistogramHeight      140

        SetCanvasBackgroundColor "white"
        SetCanvasResetColor      "white"

        SetShowRawCurValue        1
        SetShowRawImgInfo         1
        set sett(raw,lastCurVal)  1
        set sett(raw,lastImgInfo) 1

        SetUsePoImg 1
        if { $::tcl_platform(platform) eq "windows" && [info exists ::starkit::topdir] } {
            SetUseMuPdf   0
            SetUseFitsTcl 0
        } else {
            SetUseMuPdf   1
            SetUseFitsTcl 1
        }
    }

    proc SetShowColorInHex { showColorInHex } {
        variable sett

        set sett(showColorInHex) $showColorInHex
    }

    proc GetShowColorInHex {} {
        variable sett

        return $sett(showColorInHex)
    }

    proc SetShowColorCountColumn { showColorCountColumn } {
        variable sett

        set sett(showColorCountColumn) $showColorCountColumn
    }

    proc GetShowColorCountColumn {} {
        variable sett

        return $sett(showColorCountColumn)
    }

    proc SetUseLastImgFmt { useLastImgFmt } {
        variable sett

        set sett(useLastImgFmt) $useLastImgFmt
    }

    proc GetUseLastImgFmt {} {
        variable sett

        return $sett(useLastImgFmt)
    }

    proc SetLastImgFmtUsed { lastImgFmtUsed } {
        variable sett

        set sett(lastImgFmtUsed) $lastImgFmtUsed
    }

    proc GetLastImgFmtUsed {} {
        variable sett

        return $sett(lastImgFmtUsed)
    }

    proc SetRowOrderCount { rowOrderCount } {
        variable sett

        set sett(rowOrderCount) $rowOrderCount
    }

    proc GetRowOrderCount {} {
        variable sett

        return $sett(rowOrderCount)
    }

    proc GetRowOrderCountBitmap {} {
        variable sett

        if { $sett(rowOrderCount) eq "TopDown" } {
            return [::poBmpData::topdown]
        } else {
            return [::poBmpData::bottomup]
        }
    }

    proc ToggleRowOrderCount {} {
        variable sett

        if { $sett(rowOrderCount) eq "TopDown" } {
            set sett(rowOrderCount) "BottomUp"
        } else {
            set sett(rowOrderCount) "TopDown"
        }
    }

    proc SetHistogramType { histoType } {
        variable sett

        set sett(histoType)   $histoType
    }

    proc GetHistogramType {} {
        variable sett

        return $sett(histoType)
    }

    proc SetHistogramHeight { histoHeight } {
        variable sett

        set sett(histoHeight) $histoHeight
    }

    proc GetHistogramHeight {} {
        variable sett

        return $sett(histoHeight)
    }

    proc SetCanvasBackgroundColor { color } {
        variable sett

        set sett(canvasBackColor) $color
    }

    proc GetCanvasBackgroundColor {} {
        variable sett

        return $sett(canvasBackColor)
    }

    proc SetCanvasResetColor { color } {
        variable sett

        set sett(canvasResetColor) $color
    }

    proc GetCanvasResetColor {} {
        variable sett

        return $sett(canvasResetColor)
    }

    proc SetShowRawCurValue { onOff } {
        variable sett

        set sett(raw,showCurVal) $onOff
    }

    proc GetShowRawCurValue {} {
        variable sett

        return $sett(raw,showCurVal)
    }

    proc SetShowRawImgInfo { onOff } {
        variable sett

        set sett(raw,showImgInfo) $onOff
    }

    proc GetShowRawImgInfo {} {
        variable sett

        return $sett(raw,showImgInfo)
    }

    proc SetUsePoImg { usePoImg } {
        variable sett

        set sett(usePoImg) $usePoImg
    }

    proc GetUsePoImg {} {
        variable sett

        return $sett(usePoImg)
    }

    proc UsePoImg {} {
        return [expr {[poMisc HavePkg "poImg"] && [GetUsePoImg]}]
    }

    proc SetUseMuPdf { useMuPdf } {
        variable sett

        set sett(useMuPdf) $useMuPdf
    }

    proc GetUseMuPdf {} {
        variable sett

        return $sett(useMuPdf)
    }

    proc UseMuPdf {} {
        return [expr {[poMisc HavePkg "tkMuPDF"] && [GetUseMuPdf]}]
    }

    proc SetUseFitsTcl { useFitsTcl } {
        variable sett

        set sett(useFitsTcl) $useFitsTcl
    }

    proc GetUseFitsTcl {} {
        variable sett

        return $sett(useFitsTcl)
    }

    proc UseFitsTcl {} {
        return [expr {[poMisc HavePkg "fitstcl"] && [GetUseFitsTcl]}]
    }

    proc StoreLastImgFmtUsed { imgName } {
        SetLastImgFmtUsed [poImgType GetFmtByExt [file extension $imgName]]
    }

    proc ResetCanvasBackColor { labelId } {
        variable sett

        set sett(canvasBackColor) $sett(canvasResetColor)
        $labelId configure -background $sett(canvasResetColor)
    }

    proc AskCanvasBackColor { labelId } {
        variable sett

        set newColor [tk_chooseColor -initialcolor $sett(canvasBackColor)]
        if { $newColor ne "" } {
            set sett(canvasBackColor) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc CancelWin { w args } {
        variable sett

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

    proc CheckRawSettings {} {
        variable sett

        if { $sett(raw,lastCurVal) == 1 && $sett(raw,showCurVal) == 0 } {
            set sett(raw,showImgInfo) 0
        } elseif { $sett(raw,lastImgInfo) == 0 && $sett(raw,showImgInfo) == 1 } {
            set sett(raw,showCurVal) 1
        }
        set sett(raw,lastCurVal)  $sett(raw,showCurVal)
        set sett(raw,lastImgInfo) $sett(raw,showImgInfo)
    }

    proc OpenWin { fr } {
        variable ns
        variable sett

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Modes:" \
                           "Histogram height (Pixel):" \
                           "Canvas background color:" \
                           "RAW images:" \
                           "Image libraries:" } {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList [list]
        # Generate right column with entries and buttons.

        # Mode switches
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Show color values in hex" \
                                        -variable ${ns}::sett(showColorInHex)
        ttk::checkbutton $tw.fr$row.cb2 -text "Use last image format" \
                                        -variable ${ns}::sett(useLastImgFmt)
        ttk::checkbutton $tw.fr$row.cb3 -text "Display image colors in ColorCount table" \
                                        -variable ${ns}::sett(showColorCountColumn)
        poToolhelp AddBinding $tw.fr$row.cb2 "Use last selected image format in open dialogs"
        poToolhelp AddBinding $tw.fr$row.cb3 "Needs lot of time for large images"
        pack {*}[winfo children $tw.fr$row] -side top -anchor w -pady 2

        set tmpList [list [list sett(showColorInHex)] [list $sett(showColorInHex)]]
        lappend varList $tmpList
        set tmpList [list [list sett(useLastImgFmt)] [list $sett(useLastImgFmt)]]
        lappend varList $tmpList
        set tmpList [list [list sett(showColorCountColumn)] [list $sett(showColorCountColumn)]]
        lappend varList $tmpList

        # Height of a histogram canvas
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sett(histoHeight) -row $row -width 3 -min 10 -max 500

        set tmpList [list [list sett(histoHeight)] [list $sett(histoHeight)]]
        lappend varList $tmpList

        # Color of canvas background.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sett(canvasBackColor)
        ttk::button $tw.fr$row.b1 -text "Select ..." \
                            -command "${ns}::AskCanvasBackColor $tw.fr$row.l"
        ttk::button $tw.fr$row.b2 -text "Reset" \
                             -command "${ns}::ResetCanvasBackColor $tw.fr$row.l"
        poToolhelp AddBinding $tw.fr$row.b1 "Select new canvas background color"
        poToolhelp AddBinding $tw.fr$row.b2 "Reset to default background color"
        pack {*}[winfo children $tw.fr$row] -side left -anchor w -expand 1 -fill both
        set tmpList [list [list sett(canvasBackColor)] [list $sett(canvasBackColor)]]
        lappend varList $tmpList

        # Switches for showing RAW image information
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Show image pixel information" \
                                        -variable ${ns}::sett(raw,showCurVal) \
                                        -command ${ns}::CheckRawSettings
        ttk::checkbutton $tw.fr$row.cb2 -text "Show image information" \
                                        -variable ${ns}::sett(raw,showImgInfo) \
                                        -command ${ns}::CheckRawSettings
        poToolhelp AddBinding $tw.fr$row.cb1 "Needs more time for large images"
        poToolhelp AddBinding $tw.fr$row.cb2 "Needs a lot more time for large images"
        pack {*}[winfo children $tw.fr$row] -side top -anchor w -pady 2

        set tmpList [list [list sett(raw,showCurVal)] [list $sett(raw,showCurVal)]]
        lappend varList $tmpList
        set tmpList [list [list sett(raw,showImgInfo)] [list $sett(raw,showImgInfo)]]
        lappend varList $tmpList

        # tkMuPdf and fitsTcl switches
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Load tkMuPDF package on startup" \
                                        -variable ${ns}::sett(useMuPdf)
        if { $::tcl_platform(platform) eq "windows" } {
            poToolhelp AddBinding $tw.fr$row.cb1 \
                       "The tkMuPDF package needs VisualStudio or gcc runtime libraries"
        }

        ttk::checkbutton $tw.fr$row.cb2 -text "Load fitsTcl package on startup" \
                                        -variable ${ns}::sett(useFitsTcl)
        if { $::tcl_platform(platform) eq "windows" } {
            poToolhelp AddBinding $tw.fr$row.cb2 \
                       "The fitsTcl package needs VisualStudio or gcc runtime libraries"
        }

        if { $::tcl_platform(platform) eq "windows" && [info exists ::starkit::topdir] } {
            ttk::button $tw.fr$row.b -text "Extract runtime libraries" \
                        -command "poApps::WriteRuntimeLibs"
        }
        pack {*}[winfo children $tw.fr$row] -side top -anchor w -pady 2

        set tmpList [list [list sett(useMuPdf)] [list $sett(useMuPdf)]]
        lappend varList $tmpList
        set tmpList [list [list sett(useFitsTcl)] [list $sett(useFitsTcl)]]
        lappend varList $tmpList

        return $varList
    }
}

poImgAppearance Init

namespace eval poSettings {
    variable ns [namespace current]

    namespace export ShowGeneralSettWin ShowImgSettWin

    namespace ensemble create

    proc CancelGeneralSettWins { w callback appVarList fileTypeVarList editVarList logVarList } {
        poAppearance CancelWin $w {*}$appVarList
        poFileType   CancelWin $w {*}$fileTypeVarList
        poExtProg    CancelWin $w {*}$editVarList
        poLogOpt     CancelWin $w {*}$logVarList
        $callback
    }

    proc OkGeneralSettWins { w callback appFr fileTypeFr editFr logFr } {
        poAppearance OkWin $appFr
        poFileType   OkWin $fileTypeFr
        poExtProg    OkWin $editFr
        poLogOpt     OkWin $logFr
        $callback
        destroy $w
    }

    proc ShowGeneralSettWin { { selectTab "Appearance" } { okCallback poSettings::DummyOkCallback } { cancelCallback poSettings::DummyCancelCallback } } {
        variable ns

        set tw .poSettings_generalSettWin

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "General settings"
        wm resizable $tw true true

        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1

        set nb $tw.fr.nb
        ttk::notebook $nb -style [poAppearance GetTabStyle]
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        set selTabInd 0 ; # Default is "Appearance"

        ttk::frame $nb.appFr
        set appVarList [list [poAppearance OpenWin $nb.appFr]]
        $nb add $nb.appFr -text "Appearance" -underline 0 -padding 2
        if { $selectTab eq "Appearance" } {
            set selTabInd 0
        }

        ttk::frame $nb.fileTypeFr
        set fileVarList [list [poFileType OpenWin $nb.fileTypeFr]]
        $nb add $nb.fileTypeFr -text "File types" -underline 0 -padding 2
        if { $selectTab eq "File types" } {
            set selTabInd 1
        }

        ttk::frame $nb.editFr
        set editVarList [list [poExtProg OpenWin $nb.editFr]]
        $nb add $nb.editFr -text "Edit/Preview" -underline 0 -padding 2
        if { $selectTab eq "Edit/Preview" } {
            set selTabInd 2
        }

        ttk::frame $nb.logFr
        set logVarList [list [poLogOpt OpenWin $nb.logFr]]
        $nb add $nb.logFr -text "Logging" -underline 0 -padding 2
        if { $selectTab eq "Logging" } {
            set selTabInd 3
        }

        $nb select $selTabInd

        # Create Cancel and OK buttons
        ttk::frame $tw.frOk
        pack $tw.frOk -side bottom -fill x

        ttk::button $tw.frOk.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                    -compound left \
                    -command "${ns}::CancelGeneralSettWins $tw $cancelCallback $appVarList $fileVarList $editVarList $logVarList"
        bind $tw <KeyPress-Escape> "${ns}::CancelGeneralSettWins $tw $cancelCallback $appVarList $fileVarList $editVarList $logVarList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelGeneralSettWins $tw $cancelCallback $appVarList $fileVarList $editVarList $logVarList"

        ttk::button $tw.frOk.b2 -text "OK" -image [poWin GetOkBitmap] \
                    -compound left -default active \
                    -command "${ns}::OkGeneralSettWins $tw $okCallback $nb.appFr $nb.fileTypeFr $nb.editFr $nb.logFr"
        pack $tw.frOk.b1 $tw.frOk.b2 -side left -fill x -padx 10 -pady 2 -expand 1
        focus $tw
    }

    proc CancelImgSettWins { w callback appVarList imgTypeVarList browseVarList slideShowVarList zoomRectVarList selRectVarList paletteVarList } {
        poImgAppearance CancelWin $w {*}$appVarList
        poImgType       CancelWin $w {*}$imgTypeVarList
        poImgBrowse     CancelWin $w {*}$browseVarList
        poSlideShow     CancelWin $w {*}$slideShowVarList
        poZoomRect      CancelWin $w {*}$zoomRectVarList
        poSelRect       CancelWin $w {*}$selRectVarList
        poImgPalette    CancelWin $w {*}$paletteVarList
        $callback
    }

    proc OkImgSettWins { w callback appFr imgTypeFr browseFr slideShowFr zoomRectFr selRectFr paletteFr } {
        poImgAppearance OkWin $appFr
        poImgType       OkWin $imgTypeFr
        poImgBrowse     OkWin $browseFr
        poSlideShow     OkWin $slideShowFr
        poZoomRect      OkWin $zoomRectFr
        poSelRect       OkWin $selRectFr
        poImgPalette    OkWin $paletteFr
        $callback
        destroy $w
    }

    proc DummyCancelCallback {} {
    }

    proc DummyOkCallback {} {
    }

    proc ShowImgSettWin { { selectTab "Appearance" } \
                          { okCallback poSettings::DummyOkCallback } \
                          { cancelCallback poSettings::DummyCancelCallback } } {
        variable ns

        set tw .poSettings_imgSettWin

        if { [winfo exists $tw] } {
            poWin Raise $tw
            return
        }

        toplevel $tw
        wm title $tw "Image specific settings"
        wm resizable $tw true true

        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1

        set nb $tw.fr.nb
        ttk::notebook $nb -style [poAppearance GetTabStyle]
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        set selTabInd 0 ; # Default is "Appearance"

        ttk::frame $nb.appFr
        set appVarList [list [poImgAppearance OpenWin $nb.appFr]]
        $nb add $nb.appFr -text "Appearance" -underline 0 -padding 2
        if { $selectTab eq "Appearance" } {
            set selTabInd 0
        }

        ttk::frame $nb.imgTypeFr
        set lastImgFmtUsed [poImgType GetLastFmt]
        set imgVarList [list [poImgType OpenWin $nb.imgTypeFr $lastImgFmtUsed]]
        $nb add $nb.imgTypeFr -text "Image types" -underline 0 -padding 2
        if { $selectTab eq "Image types" } {
            set selTabInd 1
        }

        ttk::frame $nb.imgBrowseFr
        set browseVarList [list [poImgBrowse OpenWin $nb.imgBrowseFr]]
        $nb add $nb.imgBrowseFr -text "Image browser" -underline 0 -padding 2
        if { $selectTab eq "Image browser" } {
            set selTabInd 2
        }

        ttk::frame $nb.slideShowFr
        set slideShowVarList [list [poSlideShow OpenWin $nb.slideShowFr]]
        $nb add $nb.slideShowFr -text "Slide show" -underline 0 -padding 2
        if { $selectTab eq "Slide show" } {
            set selTabInd 3
        }

        ttk::frame $nb.zoomRectFr
        set zoomRectVarList [list [poZoomRect OpenWin $nb.zoomRectFr]]
        $nb add $nb.zoomRectFr -text "Zoom rectangle" -underline 0 -padding 2
        if { $selectTab eq "Zoom rectangle" } {
            set selTabInd 4
        }

        ttk::frame $nb.selRectFr
        set selRectVarList [list [poSelRect OpenWin $nb.selRectFr]]
        $nb add $nb.selRectFr -text "Selection rectangle" -underline 0 -padding 2
        if { $selectTab eq "Selection rectangle" } {
            set selTabInd 5
        }

        ttk::frame $nb.paletteFr
        set paletteVarList [list [poImgPalette OpenWin $nb.paletteFr]]
        $nb add $nb.paletteFr -text "Palette" -underline 0 -padding 2
        if { $selectTab eq "Palette" } {
            set selTabInd 6
        }

        $nb select $selTabInd

        # Create Cancel and OK buttons
        ttk::frame $tw.frOk
        pack $tw.frOk -side bottom -fill x

        ttk::button $tw.frOk.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                    -compound left \
                    -command "${ns}::CancelImgSettWins $tw $cancelCallback $appVarList $imgVarList $browseVarList $slideShowVarList $zoomRectVarList $selRectVarList $paletteVarList"
        bind $tw <KeyPress-Escape> "${ns}::CancelImgSettWins $tw $cancelCallback $appVarList $imgVarList $browseVarList $slideShowVarList $zoomRectVarList $selRectVarList $paletteVarList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelImgSettWins $tw $cancelCallback $appVarList $imgVarList $browseVarList $slideShowVarList $zoomRectVarList $selRectVarList $paletteVarList"

        ttk::button $tw.frOk.b2 -text "OK" -image [poWin GetOkBitmap] \
            -compound left -default active \
            -command "${ns}::OkImgSettWins $tw $okCallback $nb.appFr $nb.imgTypeFr $nb.imgBrowseFr $nb.slideShowFr $nb.zoomRectFr $nb.selRectFr $nb.paletteFr"
        pack $tw.frOk.b1 $tw.frOk.b2 -side left -fill x -padx 10 -pady 2 -expand 1
        focus $tw
    }
}
