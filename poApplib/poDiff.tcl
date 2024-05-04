# Module:         poDiff
# Copyright:      Paul Obermeier 1999-2023 / paul@poSoft.de
# First Version:  1999 / 08 / 12
#
# Distributed under BSD license.
#
# A portable graphical diff for directories.
# See http://www.poSoft.de for screenshots and examples.

namespace eval poDiff {
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

        set sPo(tw)      ".poDiff" ; # Name of toplevel window
        set sPo(appName) "poDiff"  ; # Name of tool
        set sPo(cfgDir)  ""        ; # Directory containing config files

        set sPo(stopScan)   0
        set sPo(stopSearch) 0

        set sPo(startDir) [pwd]
        set sPo(dir1)     $sPo(startDir)
        set sPo(dir2)     $sPo(startDir)

        set sPo(infoWinList) {}         ; # Start with empty file info window list
        set sPo(leftFile)    ""         ; # Left  file for selective diff
        set sPo(rightFile)   ""         ; # Right file for selective diff
        set sPo(curSession)  "Default"  ; # Default session name
        set sPo(sessionList) [list]
        set sPo(curListbox)  ""

        # Default values for command line options.
        set sPo(optSync)             false
        set sPo(optSyncDelete)       false
        set sPo(optCopyDate)         false
        set sPo(optCopyDays)         ""
        set sPo(optSearch)           false
        set sPo(optConvert)          false
        set sPo(optConvertFmt)       ""
        set sPo(optDiffOnStartup)    false
        set sPo(optSessionOnStartup) ""

        # Add command line options which should not be expanded by file matching.
        poApps AddFileMatchIgnoreOption "filematch" 
    }

    # The following functions are used for loading/storing poDiff specific
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

    proc SetConfirmationModes { deleteConfirm copyConfirm moveConfirm convConfirm } {
        variable sPo

        set sPo(deleteConfirm) $deleteConfirm
        set sPo(copyConfirm)   $copyConfirm
        set sPo(moveConfirm)   $moveConfirm
        set sPo(convConfirm)   $convConfirm
    }

    proc GetConfirmationModes {} {
        variable sPo

        return [list $sPo(deleteConfirm) \
                     $sPo(copyConfirm)   \
                     $sPo(moveConfirm)   \
                     $sPo(convConfirm)]
    }

    proc SetViewModes { relativePathnames immediateUpdate } {
        variable sPo

        set sPo(relPathes)       $relativePathnames
        set sPo(immediateUpdate) $immediateUpdate
    }

    proc GetViewModes {} {
        variable sPo

        return [list $sPo(relPathes)       \
                     $sPo(immediateUpdate)]
    }

    proc SetCurDirectories { curLeftDir curRightDir } {
        variable sPo

        set sPo(dir1) $curLeftDir
        set sPo(dir2) $curRightDir
    }

    proc GetCurDirectories {} {
        variable sPo

        return [list $sPo(dir1) \
                     $sPo(dir2)]
    }

    proc SetMarkModes { markNewer markByType fileMarkColor sideMarkColor listMarkColor } {
        variable sPo

        set sPo(markNewer)     $markNewer
        set sPo(markByType)    $markByType
        set sPo(fileMarkColor) $fileMarkColor
        set sPo(sideMarkColor) $sideMarkColor
        set sPo(listMarkColor) $listMarkColor
    }

    proc GetMarkModes {} {
        variable sPo

        return [list $sPo(markNewer)     \
                     $sPo(markByType)    \
                     $sPo(fileMarkColor) \
                     $sPo(sideMarkColor) \
                     $sPo(listMarkColor)]
    }

    proc SetPreviewModes { showPreview showFileInfo } {
        variable sPo

        set sPo(showPreview)  $showPreview
        set sPo(showFileInfo) $showFileInfo
    }

    proc GetPreviewModes {} {
        variable sPo

        return [list $sPo(showPreview) \
                     $sPo(showFileInfo)]
    }

    proc SetMainWindowSash { sashY0 sashY1 } {
        variable sPo

        set sPo(sashY0) $sashY0
        set sPo(sashY1) $sashY1
    }

    proc GetMainWindowSash {} {
        variable sPo

        set sashY0 $sPo(sashY0)
        set sashY1 $sPo(sashY1)
        if { [info exists sPo(paneWin)] && [winfo exists $sPo(paneWin)] } {
            set sashY0 [$sPo(paneWin) sashpos 0]
            set sashY1 [$sPo(paneWin) sashpos 1]
        }
        return [list $sashY0 $sashY1]
    }

    proc SetSearchWindowSash { sashY } {
        variable sPo

        set sPo(searchSashY) $sashY
    }

    proc GetSearchWindowSash {} {
        variable sPo

        set sashY $sPo(searchSashY)
        if { [info exists sPo(searchPaneWin)] && \
            [winfo exists $sPo(searchPaneWin)] } {
            set sashY [$sPo(searchPaneWin) sashpos 0]
        }
        return [list $sashY]
    }

    proc SetCurSearchPatterns { curSearchPatt curReplacePatt curFileMatchPatt { curFileType "" } } {
        variable sPo

        set sPo(searchPatt)  $curSearchPatt
        set sPo(replacePatt) $curReplacePatt
        set sPo(filePatt)    $curFileMatchPatt
        set sPo(fileType)    $curFileType
    }

    proc GetCurSearchPatterns {} {
        variable sPo

        return [list $sPo(searchPatt)  \
                     $sPo(replacePatt) \
                     $sPo(filePatt) \
                     $sPo(fileType)]
    }

    proc SetCurDatePatterns { dateMatch { dateRef "" } } {
        variable sPo

        set sPo(dateMatch) $dateMatch
        if { $dateRef eq "" } {
            set sPo(dateRef) [clock seconds]
        } else {
            set sPo(dateRef) $dateRef
        }
    }

    proc GetCurDatePatterns {} {
        variable sPo

        return [list $sPo(dateMatch) \
                     $sPo(dateRef)]
    }

    proc SetSearchPatternList { obsoleteListLen searchPattList } {
        variable sPo

        set sPo(searchPattList) $searchPattList
    }

    proc GetSearchPatternList {} {
        variable sPo

        return [list [llength $sPo(searchPattList)] $sPo(searchPattList)]
    }

    proc SetSearchModes { searchDir ignoreCaseSearch { searchWord false } { searchMode "exact" } } {
        variable sPo

        set sPo(searchDir)     $searchDir
        set sPo(searchIgnCase) $ignoreCaseSearch
        set sPo(searchWord)    $searchWord
        set sPo(searchMode)    $searchMode
    }

    proc GetSearchModes {} {
        variable sPo

        return [list $sPo(searchDir)    \
                     $sPo(searchIgnCase) \
                     $sPo(searchWord)    \
                     $sPo(searchMode)]
    }

    proc SetDiffModes { compareMode ignoreEolChar \
                        ignoreHiddenDirs ignoreHiddenFiles \
                        { ignoreOneHour 0 } \
                        { ignoreCase 1 }  } {
        variable sPo

        set sPo(cmpMode)        $compareMode
        set sPo(ignEolChar)     $ignoreEolChar
        set sPo(ignHiddenDirs)  $ignoreHiddenDirs
        set sPo(ignHiddenFiles) $ignoreHiddenFiles
        set sPo(ignOneHour)     $ignoreOneHour
        set sPo(ignCase)        $ignoreCase
    }

    proc GetDiffModes {} {
        variable sPo

        return [list $sPo(cmpMode)        \
                     $sPo(ignEolChar)     \
                     $sPo(ignHiddenDirs)  \
                     $sPo(ignHiddenFiles) \
                     $sPo(ignOneHour)     \
                     $sPo(ignCase)]
    }

    proc SetIgnoreLists { ignoreDirList ignoreFileList } {
        variable sPo

        set sPo(ignDirList)  $ignoreDirList
        set sPo(ignFileList) $ignoreFileList
    }

    proc GetIgnoreLists {} {
        variable sPo

        return [list $sPo(ignDirList)  \
                     $sPo(ignFileList)]
    }

    proc SetMaxShowWin { num } {
        variable sPo

        set sPo(maxShowWin) $num
    }

    proc GetMaxShowWin {} {
        variable sPo

        return [list $sPo(maxShowWin)]
    }

    proc SetShowPreviewTab { infoTabNum } {
        variable sPo

        set sPo(showPreviewTab) $infoTabNum
    }

    proc GetShowPreviewTab {} {
        variable sPo

        return [list $sPo(showPreviewTab)]
    }

    proc SetColumnAlignment { align } {
        variable sPo

        set sPo(columnAlign) $align
    }

    proc GetColumnAlignment {} {
        variable sPo

        return [list $sPo(columnAlign)]
    }

    proc AddSession { sessionName leftDir rightDir compareMode ignoreDirList \
                      ignoreFileList ignoreHiddenDirs ignoreHiddenFiles \
                      ignoreEolChar { ignoreOneHour 0 } { ignoreCase 1 } } {
        variable sPo

        if { [lsearch -exact $sPo(sessionList) $sessionName] < 0 } {
            lappend sPo(sessionList) $sessionName
        }
        set sPo(sessionList) [lsort -dictionary $sPo(sessionList)]

        # Directories to compare.
        set sPo(session,$sessionName,dir1) $leftDir
        set sPo(session,$sessionName,dir2) $rightDir
        # Settings from compare window.
        set sPo(session,$sessionName,cmpMode)        $compareMode
        set sPo(session,$sessionName,ignDirList)     $ignoreDirList
        set sPo(session,$sessionName,ignFileList)    $ignoreFileList
        set sPo(session,$sessionName,ignHiddenDirs)  $ignoreHiddenDirs
        set sPo(session,$sessionName,ignHiddenFiles) $ignoreHiddenFiles
        set sPo(session,$sessionName,ignEolChar)     $ignoreEolChar
        set sPo(session,$sessionName,ignOneHour)     $ignoreOneHour
        set sPo(session,$sessionName,ignCase)        $ignoreCase
    }

    proc GetRootDir { w } {
        variable sPo
        if { [IsOnlyListbox $w "l"] || \
             [IsDiffListbox $w "l"] || \
             ([IsSearchListbox $w] && [GetSearchSide] eq "l") || \
             [IsIgnoreListbox $w "l"] || \
             [IsIdentListbox  $w "l"] } {
            return $sPo(dir1)
        } else {
            return $sPo(dir2)
        }
    }

    proc GetSearchSide { { asWord false } } {
        variable sPo

        if { $sPo(searchDir) == 1 } {
            if { $asWord } {
                return "left"
            } else {
                return "l"
            }
        } else {
            if { $asWord } {
                return "right"
            } else {
                return "r"
            }
        }
    }

    proc GetSearchOtherSide { { asWord false } } {
        variable sPo

        if { $sPo(searchDir) == 1 } {
            if { $asWord } {
                return "right"
            } else {
                return "r"
            }
        } else {
            if { $asWord } {
                return "left"
            } else {
                return "l"
            }
        }
    }

    proc GetSearchDir {} {
        variable sPo

        return $sPo(dir$sPo(searchDir))
    }

    proc IsListWidget { widgetId } {
        if { [winfo exists $widgetId] && ([winfo class $widgetId] eq "Tablelist") } {
            return true
        }
        return false
    }

    proc IsSearchListbox { listboxId } {
        variable sPo

        return [expr { ([info exists sPo(searchList)] && $listboxId eq $sPo(searchList)) }]
    }

    proc IsSpecificListbox { listboxId leftName rightName { side "both" } } {
        variable sPo

        set isLeft  [expr { ([info exists sPo($leftName)]  && $listboxId eq $sPo($leftName)) }]
        set isRight [expr { ([info exists sPo($rightName)] && $listboxId eq $sPo($rightName)) }]
        switch -- $side {
            "l" { return $isLeft }
            "r" { return $isRight }
            default { return [expr { $isLeft || $isRight }] }
         }
    }

    proc IsOnlyListbox { listboxId { side "both" } } {
        return [IsSpecificListbox $listboxId onlyListL onlyListR $side]
    }

    proc IsDiffListbox { listboxId { side "both" } } {
        return [IsSpecificListbox $listboxId diffListL diffListR $side]
    }

    proc IsIdentListbox { listboxId { side "both" } } {
        return [IsSpecificListbox $listboxId identListL identListR $side]
    }

    proc IsIgnoreListbox { listboxId { side "both" } } {
        return [IsSpecificListbox $listboxId ignListL ignListR $side]
    }

    proc AbsPath { fileName rootName } {
        if { [string index $fileName 0] eq "." } {
            # Strip 2 characters of relative path (./)
            set fileName [string range $fileName 2 end]
            set fileName [poMisc QuoteTilde $fileName]
            # Join root pathname and relative filename.
            return [file normalize [file join $rootName $fileName]]
        } else {
            return [file normalize $fileName]
        }
    }

    proc StartHexEditor { serialize } {
        variable sPo
        variable ns

        set w $sPo(curListbox)
        if { ! [IsListWidget $w] } {
            return
        }

        set fileList [list]
        set selItemList [GetListSelection $w]
        if { [llength $selItemList] == 0 } {
            return
        }
        foreach item $selItemList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $item [GetRootDir $w]]
            lappend fileList $fileName
        }
        poExtProg StartHexEditProg $fileList ${ns}::WriteMainInfoStr $serialize
    }

    proc StartFileBrowser { w } {
        set dirList [list]
        set selItemList [GetListSelection $w]
        if { [llength $selItemList] == 0 } {
            return
        }
        foreach item $selItemList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $item [GetRootDir $w]]
            set dirName [file dirname $fileName]
            lappend dirList $dirName
        }
        foreach dir [lsort -unique $dirList] {
            poExtProg StartFileBrowser $dir
        }
    }

    proc StartAssoc { useSeparateProgs } {
        StartEditor $useSeparateProgs 1
    }

    proc StartEditor { useSeparateProgs { assoc 0 } } {
        variable sPo
        variable ns

        set w $sPo(curListbox)
        if { ! [IsListWidget $w] } {
            return
        }
        set fileList [list]
        set selItemList [GetListSelection $w]
        if { [llength $selItemList] == 0 } {
            return
        }
        foreach item $selItemList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $item [GetRootDir $w]]
            lappend fileList $fileName
        }
        if { $useSeparateProgs } {
            poExtProg StartEditProg $fileList ${ns}::WriteMainInfoStr $assoc
        } else {
            poExtProg StartOneEditProg $fileList ${ns}::WriteMainInfoStr $assoc
        }
    }

    proc StartGUIDiff { leftListbox rightListbox { useHexDumpDiff false } } {
        variable sPo
        variable ns

        if { ! [IsListWidget $leftListbox] } {
            return
        }

        set fileList1 [list]
        set fileList2 [list]
        set selList1 [GetListSelection $leftListbox]
        set selList2 [GetListSelection $rightListbox]
        if { [llength $selList1] == 0 || [llength $selList2] == 0 } {
            return
        }
        if { [llength $selList1] != 1 && [llength $selList2] != 1 } {
            tk_messageBox -icon info -type ok \
                          -message "More than one file selected for comparison."
            return
        }
        foreach file1 $selList1 file2 $selList2 {
            # Convert native name back to Unix notation
            set fileName1 [AbsPath $file1 $sPo(dir1)]
            set fileName2 [AbsPath $file2 $sPo(dir2)]
            lappend fileList1 $fileName1
            lappend fileList2 $fileName2
        }
        if { $useHexDumpDiff } {
            poExtProg ShowTkDiffHexDiff [lindex $fileList1 0] [lindex $fileList2 0]
        } else {
            poExtProg StartDiffProg $fileList1 $fileList2 ${ns}::WriteMainInfoStr
        }
    }

    proc DiffFiles {} {
        variable sPo
        variable ns

        set prog ""
        if { $sPo(leftFile) eq "" || $sPo(rightFile) eq "" } {
            set msg "No files marked for diff'ing.\nUse key 1 and 2 to select files."
            tk_messageBox -title "Info" -message $msg -type ok -icon warning
            return
        }

        poExtProg StartDiffProg [list $sPo(leftFile)] [list $sPo(rightFile)] \
                                   ${ns}::WriteMainInfoStr 0
    }

    proc SelectAll {} {
        variable sPo

        set listboxId $sPo(curListbox)
        if { ! [IsListWidget $listboxId] } {
            return
        }

        $listboxId selection set 0 end
        if { [IsDiffListbox $listboxId "l"] } {
            SynchSelections $listboxId $sPo(diffListR)
         } elseif { [IsDiffListbox $listboxId "r"] } {
            SynchSelections $listboxId $sPo(diffListL)
         } elseif { [IsIdentListbox $listboxId "l"] } {
            SynchSelections $listboxId $sPo(identListR)
         } elseif { [IsIdentListbox $listboxId "r"] } {
            SynchSelections $listboxId $sPo(identListL)
        }
    }

    proc SynchSelections { fromListbox toListbox } {
        variable sPo

        set indList [GetListSelectionIndices $fromListbox]
        $toListbox selection clear 0 end
        foreach ind $indList {
            $toListbox selection set $ind
        }
        if { [IsDiffListbox $fromListbox] } {
            DisplayTwoFileInfo $sPo(diffListL)     $sPo(diffListR) \
                               $sPo(infoFrameL)    $sPo(infoFrameR) \
                               $sPo(previewFrameL) $sPo(previewFrameR)
        }
    }

    proc RemoveSelectedRows { tableId } {
        set rowList [$tableId curselection]
        foreach row [lsort -decreasing -integer $rowList] {
            $tableId delete $row
        }
    }

    proc SetRecentListFromTable { tw tableId listType } {
        variable sPo

        set sPo($listType) [list]
        foreach rowEntry [$tableId get 0 end] {
            lappend sPo($listType) [lindex $rowEntry 1]
        }
        destroy $tw
    }

    proc ShowSessionFromTable { tableId } {
        variable sPo

        set selList [GetListSelection $tableId 1]
        if { [llength $selList] == 1 } {
            set sessionName [lindex $selList 0]
            SelectSession $sessionName
            ShowSpecificSettWin "Diff"
            poWin Raise $sPo(editList,name)
            focus $sPo(editList,name)
        }
    }

    proc SaveSessionFromTable { tableId } {
        set selList [GetListSelection $tableId 1]
        if { [llength $selList] == 1 } {
            set sessionName [lindex $selList 0]
            SaveSession $sessionName true
            WriteMainInfoStr "Saved $sessionName" "Ok"
        }
    }

    proc RenameSessionFromTable { tableId { x -1 } { y -1 } } {
        variable sPo

        if { $x <= 0 || $y <= 0 } {
            # Workaround for bug in Tcl 8.6.0 on Darwin, which returns zero or negative values
            # for cursor positions, when activated via a key event.
            set x [winfo pointerx $sPo(tw)]
            set y [winfo pointery $sPo(tw)]
        }
        set selList    [GetListSelection $tableId 1]
        set selListInd [GetListSelectionIndices $tableId]
        if { [llength $selList] == 1 } {
            set sessionName [lindex $selList 0]
            lassign [poWin EntryBox $sessionName $x $y] retVal newSessionName
            if { ! $retVal } {
                # User pressed Escape.
                return
            }
            if { $newSessionName ne "" } {
                set row [lindex $selListInd 0]
                $tableId cellconfigure "$row,1" -text "$newSessionName"
                # Copy all current session related values into appr. array.
                # We don't need to delete the old values, as only the sessions
                # contained in sPo(sessionList) are written out.
                foreach session [lsort [array names sPo "session,$sessionName,*"]] {
                    set varName [lindex [split $session ","] 2]
                    set sPo(session,$newSessionName,$varName) $sPo($varName)
                }
            }
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

    proc EditRecentList { listType } {
        variable ns
        variable sPo

        set winTitle "Edit list"
        if { $listType eq "searchPattList" } {
            set winTitle "Edit search pattern list"
        } elseif { $listType eq "sessionList" } {
            set winTitle "Edit session list"
        }

        set tw .poDiffEditList_$listType
        if { $listType eq "sessionList" } {
            set sPo(editList,name) $tw
        }

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

        set tableId [poWin CreateScrolledTablelist $tableFr true "" \
                    -width 80 -height 10 -exportselection false \
                    -columns { 0 "#"     "left"
                               0 "Entry" "left" } \
                    -stretch 1 \
                    -selectmode extended \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators 1]
        $tableId columnconfigure 0 -showlinenumbers true -editable false
        $tableId columnconfigure 1 -editable false -name fileName
        $tableId columnconfigure 1 -sortmode dictionary

        if { $listType eq "sessionList" } {
            set bodyTag [$tableId bodytag]
            bind $bodyTag <ButtonRelease-1> "${ns}::ShowSessionFromTable $tableId"
        }

        foreach listEntry $sPo($listType) {
            $tableId insert end [list "" $listEntry]
        }

        # Add a toolbar with buttons for list editing.
        poToolbar New $toolFr
        poToolbar AddGroup $toolFr

        poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                  "${ns}::RemoveSelectedRows $tableId" "Remove selected entries"

        if { $listType eq "sessionList" } {
            poToolbar AddGroup $toolFr
            poToolbar AddButton $toolFr [::poBmpData::rename] \
                  "${ns}::RenameSessionFromTable $tableId %X %Y" "Rename selected entry"
            poToolbar AddButton $toolFr [::poBmpData::save] \
                  "${ns}::SaveSessionFromTable $tableId" "Save selected entry"
        }

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

    proc ClearRecentSearchPattList {} {
        variable sPo

        set sPo(searchPattList) [list]
    }

    proc TimeSearchDir { searchPatt } {
        variable sPo

        # Check, if the current search and replace patterns are contained in the
        # pattern list. If not, insert them at the list begin.
        set indSearch [lsearch -exact $sPo(searchPattList) $sPo(searchPatt)]
        if { $indSearch < 0 } {
            set sPo(searchPattList) [linsert $sPo(searchPattList) 0 $sPo(searchPatt)]
        }
        set indReplace [lsearch -exact $sPo(searchPattList) $sPo(replacePatt)]
        if { $indReplace < 0 } {
            set sPo(searchPattList) [linsert $sPo(searchPattList) 0 $sPo(replacePatt)]
        }

        # Now search again in the (possibly extended) list for the new positions
        # of the search and replace patterns and update the corresponding combo boxes.
        set indSearch  [lsearch -exact $sPo(searchPattList) $sPo(searchPatt)]
        set indReplace [lsearch -exact $sPo(searchPattList) $sPo(replacePatt)]

        UpdateCombo $sPo(searchCombo)  $sPo(searchPattList) $indSearch
        UpdateCombo $sPo(replaceCombo) $sPo(searchPattList) $indReplace

        _SetTextWidgetOpts

        set sPo(curSearchPatt) $sPo($searchPatt)
        set timeStr [time "SearchDir [list $sPo($searchPatt)]"]
        scan $timeStr "%d" ms
        set sec [format "%4.1f" [expr $ms / 1000.0 / 1000.0]]
        AppendSearchInfoStr " (Elapsed time: $sec seconds)"

        poApps ShowSysNotify "poDiff message" "Search finished" $sPo(searchWin,name)
    }

    proc ReplaceDir {} {
        variable sPo
        variable sSearch

        set tableId $sPo(searchList)
        set selItemList [GetListSelection $tableId]
        set numSel [llength $selItemList]
        if { $numSel == 0 } {
            tk_messageBox -icon info -type ok \
                          -message "No files selected for replacement operation."
            return
        }

        set searchPatt  $sPo(searchPatt)
        set replacePatt $sPo(replacePatt)

        if { $searchPatt eq "" } {
            tk_messageBox -icon info -type ok \
                          -message "No search pattern specified for replacement operation."
            return
        }

        set retVal [tk_messageBox \
          -title "Replace confirmation" \
          -message "This operation cannot be undone. Replace in selected $numSel file[poMisc Plural $numSel]?" \
          -type yesno -default no -icon question]
        if { $retVal eq "no" } {
            return
        }

        foreach name $selItemList {
            # Convert native name back to Unix notation
            set searchDir [GetSearchDir]
            lappend fileList [AbsPath $name $searchDir]
        }

        ShowSearchWin true

        set sPo(stopSearch)  0
        set sPo(errorLog)    {}
        set sPo(readErrors)  0

        $sPo(tw) configure -cursor watch

        foreach name $fileList {
            WriteSearchInfoStr "Replacing \"$searchPatt\" in file $name ..." "Watch"

            set catchVal [catch {poMisc ReplaceInFile $name $searchPatt $replacePatt \
                          $sPo(searchIgnCase) $sPo(searchMode) $sPo(searchWord) } retVal]
            if { $catchVal } {
                lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
                incr sPo(readErrors)
            } else {
                if { $retVal > 0 } {
                    AddToSearchLog true $name $retVal
                }
            }
            if { $sPo(stopSearch) } {
                break
            }
        }

        $sPo(tw) configure -cursor arrow
        set infoStr "Replacement "
        if { $sPo(stopSearch) } {
            append infoStr "cancelled."
            WriteSearchInfoStr $infoStr "Cancel"
        } else {
            append infoStr "affected $sSearch(numFiles) files."
            WriteSearchInfoStr $infoStr "Ok"
        }
        if { $sPo(readErrors) } {
            set infoStr [format "%s (%d unreadable files or directories)." \
                         $infoStr $sPo(readErrors)]
            WriteSearchInfoStr $infoStr "Error"
        }
        if { $sPo(readErrors) > 0 } {
            ShowErrorLog
        }
    }

    proc _CreateDir { dir side } {
        file mkdir $dir
        if { $side == 1 || $side == 2 } {
            # Main windows.
            SetDirectory $dir $side
        } else {
            # Search window.
            SetSearchWinTitle
        }
    }

    proc TimeDiffDir {} {
        variable sPo

        if { $sPo(dir1) eq "" } {
            if { [poApps UseBatchMode] } {
                puts "Error: No left directory specified."
            } else {
                tk_messageBox -message "No left directory specified." -type ok -icon warning
            }
            return 2
        }
        if { $sPo(dir2) eq "" } {
            if { [poApps UseBatchMode] } {
                puts "Error: No right directory specified."
            } else {
                tk_messageBox -message "No right directory specified." -type ok -icon warning
            }
            return 3
        }
        if { ! [file isdirectory $sPo(dir1)] } {
            if { [poApps UseBatchMode] } {
                puts "Error: Directory $sPo(dir1) does not exist."
                return 4
            } else {
                set retVal [tk_messageBox -icon error -type yesno -default no \
                    -message "Directory $sPo(dir1) does not exist. Create directory?" \
                    -title "Directory not existent"]
                if { $retVal eq "no" } {
                    return 4
                }
                _CreateDir $sPo(dir1) 1
            }
        }
        if { ! [file isdirectory $sPo(dir2)] } {
            if { [poApps UseBatchMode] } {
                puts "Error: Directory $sPo(dir2) does not exist."
                return 5
            } else {
                set retVal [tk_messageBox -icon error -type yesno -default no \
                    -message "Directory $sPo(dir2) does not exist. Create directory?" \
                    -title "Directory not existent"]
                if { $retVal eq "no" } {
                    return 5
                }
                _CreateDir $sPo(dir2) 2
            }
        }
        poWin ToggleSwitchableWidgets "Diff" false
        poWinInfo Clear $sPo(infoFrameL)
        poWinInfo Clear $sPo(infoFrameR)
        set timeStr [time DiffDir]
        poWin ToggleSwitchableWidgets "Diff" true
        if { $sPo(appWindowClosed) } {
            return 2
        }
        scan $timeStr "%d" ms
        set sec [format "%.1f" [expr $ms / 1000.0 / 1000.0]]
        AppendMainInfoStr " (Elapsed time: $sec seconds)"
        if { [poApps GetVerbose] } {
            puts "Left directory     : $sPo(dir1)"
            puts "Right directory    : $sPo(dir2)"
            puts "Identical files    : [llength $sPo(identLog)]"
            puts "Differing files    : [$sPo(diffListL) index end]"
            puts "Files only left    : [$sPo(onlyListL) index end]"
            puts "Files only right   : [$sPo(onlyListR) index end]"
            puts "Ignored dirs left  : [llength $sPo(ignLogDirL)]"
            puts "Ignored files left : [llength $sPo(ignLogFileL)]"
            puts "Ignored dirs right : [llength $sPo(ignLogDirR)]"
            puts "Ignored files right: [llength $sPo(ignLogFileR)]"
            if { $sPo(optSync) } {
                puts "Copied files       : $sPo(numFilesCopied)"
                puts "Deleted files      : $sPo(numFilesDeleted)"
            }
            puts "Elapsed time       : $sec seconds"
        }
        poApps ShowSysNotify "poDiff message" "Directory diff finished" $sPo(tw)

        if { [$sPo(diffListL) index end] == 0 && \
             [$sPo(onlyListL) index end] == 0 && \
             [$sPo(onlyListR) index end] == 0 } {
            return 0
        } else {
            return 1
        }
    }

    proc AddRecentDirs { menuId side } {
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        poMenu AddRecentDirList $menuId ${ns}::SetDirectory $side
    }

    proc GetSessionName { sessionNameOrId } {
        variable sPo

        set sessionName ""
        if { [string is integer $sessionNameOrId] } {
            if { $sessionNameOrId > 0 && $sessionNameOrId <= [llength $sPo(sessionList)] } {
                set sessionName [lindex $sPo(sessionList) [expr {$sessionNameOrId -1}]]
            }
        } else {
            set index [lsearch -exact $sPo(sessionList) $sessionNameOrId]
            if { $index >= 0 } {
                set sessionName [lindex $sPo(sessionList) $index]
            }
        }
        return $sessionName
    }

    proc SelectSession { sessionNameOrId } {
        variable sPo

        set sessionName [GetSessionName $sessionNameOrId]

        foreach session [lsort [array names sPo "session,$sessionName,*"]] {
            set varName [lindex [split $session ","] 2]
            set sPo($varName) $sPo(session,$sessionName,$varName)
            if { [info exists sPo(${varName},combo)] } {
                poWinSelect SetValue $sPo(${varName},combo) $sPo($varName)
            }
        }
        UpdateMainTitle
        # Fill the text widgets of compare settings window from the ignore lists.
        if { [info exists sPo(ignDirText)] && [winfo exists $sPo(ignDirText)] } {
            $sPo(ignDirText) delete 0.1 end
            foreach d $sPo(ignDirList) {
                $sPo(ignDirText) insert end "$d\n"
            }
        }
        if { [info exists sPo(ignFileText)] && [winfo exists $sPo(ignFileText)] } {
            $sPo(ignFileText) delete 0.1 end
            foreach f $sPo(ignFileList) {
                $sPo(ignFileText) insert end "$f\n"
            }
        }
        set sPo(curSession) $sessionName
        ClearFileLists
        ClearTableContents
        poWin ToggleSwitchableWidgets "Diff"   true
        poWin ToggleSwitchableWidgets "Search" true
        UpdateSearchWin
    }

    proc ClearRecentSessionList { menuId } {
        variable sPo

        foreach session [array names sPo "session,*,*"] {
            unset sPo($session)
        }
        set sPo(sessionList) [list]
        poMenu DeleteMenuEntries $menuId 2
    }

    proc AddRecentSessions { menuId } {
        variable sPo
        variable ns

        poMenu DeleteMenuEntries $menuId 2
        foreach sessionName $sPo(sessionList) {
            set dir1 $sPo(session,$sessionName,dir1)
            set dir2 $sPo(session,$sessionName,dir2)
            if { [poAppearance IsDirectory $dir1] && [poAppearance IsDirectory $dir2] } {
                set bmp [poWin GetOkBitmap]
            } elseif { [poAppearance IsDirectory $dir1] } {
                set bmp [::poBmpData::rightleft "darkgreen"]
            } elseif { [poAppearance IsDirectory $dir2] } {
                set bmp [::poBmpData::leftright "darkgreen"]
            } else {
                set bmp [poWin GetCancelBitmap]
            }
            poMenu AddCommand $menuId $sessionName "" "${ns}::SelectSession [list $sessionName]" -image $bmp -compound left 
        }
    }

    proc AskSaveSession {} {
        variable sPo
        variable ns

        poWin ShowEntryBox ${ns}::SaveSession $sPo(curSession) \
                              "New Session" "Enter new session name"
    }

    proc SaveSession { sessionName { forceOverwrite false } } {
        variable sPo

        if { [lsearch -exact $sPo(sessionList) $sessionName] >= 0 } {
            if { ! $forceOverwrite } {
                set retVal [tk_messageBox -icon question -type yesno -default yes \
                    -message "Session $sessionName already exists. Overwrite?" \
                    -title "Confirmation"]
                if { $retVal eq "no" } {
                    return
                }
                focus $sPo(tw)
            }
        }

        set sPo(curSession) $sessionName

        AddSession $sessionName $sPo(dir1) $sPo(dir2) \
                   $sPo(cmpMode) $sPo(ignDirList) $sPo(ignFileList) \
                   $sPo(ignHiddenDirs) $sPo(ignHiddenFiles) $sPo(ignEolChar) $sPo(ignOneHour)  \
                   $sPo(ignCase)
    }

    proc GetComboValue { comboId num } {
        set curDir [poWinSelect GetValue $comboId]
        SetDir $curDir $num
    }

    proc SelectListbox { listboxId } {
        variable sPo

        set syncList [list diffListL diffListR identListL identListR]
        set scrolledList [list onlyListL onlyListR ignListL ignListR searchList]

        poWin SetSyncColor $sPo(diffListL)  "" ""
        if { [info exists sPo(identListL)] } {
            poWin SetSyncColor $sPo(identListL) "" ""
        }
        foreach w $scrolledList {
            if { [info exists sPo($w)] && [winfo exists $sPo($w)] } {
                poWin SetScrolledColor $sPo($w) ""
            }
        }
        if { [IsDiffListbox $listboxId "l"] } {
            poWin SetSyncColor $listboxId $sPo(listMarkColor) ""
        } elseif { [IsDiffListbox $listboxId "r"] } {
            poWin SetSyncColor $listboxId "" $sPo(listMarkColor)
        } elseif { [IsIdentListbox $listboxId "l"] } {
            poWin SetSyncColor $listboxId $sPo(listMarkColor) ""
        } elseif { [IsIdentListbox $listboxId "r"] } {
            poWin SetSyncColor $listboxId "" $sPo(listMarkColor)
        } elseif { [winfo exists $listboxId] } {
            poWin SetScrolledColor $listboxId $sPo(listMarkColor)
        }

        focus $listboxId
        set sPo(curListbox) $listboxId
    }

    proc CreateScrolledTablelist { fr title } {
        variable sPo

        set tableId [poWin CreateScrolledTablelist $fr true $title \
                    -columns {50 "File name"         "left"
                               0 "File size"         "center"
                               0 "Modification time" "center" } \
                    -exportselection false \
                    -stretch 0 \
                    -stripebackground [poAppearance GetStripeColor] \
                    -selectmode extended \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators true]
        $tableId columnconfigure 0 -sortmode dictionary
        $tableId columnconfigure 1 -sortmode integer
        $tableId columnconfigure 2 -sortmode dictionary
        $tableId columnconfigure 0 -align $sPo(columnAlign)
        return $tableId
    }

    proc CreateSyncTablelist { fr titleLeft titleRight } {
        variable sPo

        set ids [poWin CreateSyncTablelist $fr $titleLeft $titleRight \
                -columns {50 "File name"         "left"
                           0 "File size"         "center"
                           0 "Modification time" "center" } \
                -exportselection false \
                -stretch 0 \
                -stripebackground [poAppearance GetStripeColor] \
                -selectmode extended \
                -showseparators true]
        foreach tableId $ids {
            $tableId columnconfigure 0 -align $sPo(columnAlign)
        }
        return $ids
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
        UpdateMainTitle false
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create frame containing gridded frames for Tool, Work and Info area.
        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both

        ttk::frame $sPo(tw).fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).fr.filefr
        ttk::frame $sPo(tw).fr.workfr
        ttk::frame $sPo(tw).fr.statfr -relief sunken -borderwidth 1
        grid $sPo(tw).fr.toolfr -row 0 -column 0 -sticky news
        grid $sPo(tw).fr.filefr -row 1 -column 0 -sticky news
        grid $sPo(tw).fr.workfr -row 2 -column 0 -sticky news
        grid $sPo(tw).fr.statfr -row 3 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).fr 2 -weight 1
        grid columnconfigure $sPo(tw).fr 0 -weight 1

        ttk::frame $sPo(tw).fr.filefr.left
        ttk::frame $sPo(tw).fr.filefr.right
        pack $sPo(tw).fr.filefr.left $sPo(tw).fr.filefr.right -side left -expand 1 -fill x

        set sPo(dir1,combo) [poWinSelect CreateDirSelect $sPo(tw).fr.filefr.left $sPo(dir1) ""]
        bind $sPo(dir1,combo) <Key-Return>    "${ns}::GetComboValue $sPo(dir1,combo) 1"
        bind $sPo(dir1,combo) <<DirSelected>> "${ns}::GetComboValue $sPo(dir1,combo) 1"
        set sPo(dir2,combo) [poWinSelect CreateDirSelect $sPo(tw).fr.filefr.right $sPo(dir2) ""]
        bind $sPo(dir2,combo) <Key-Return>    "${ns}::GetComboValue $sPo(dir2,combo) 2"
        bind $sPo(dir2,combo) <<DirSelected>> "${ns}::GetComboValue $sPo(dir2,combo) 2"

        # Create 3 frames to hold the lists of files contained only in left or right
        # directory, and different files.
        ttk::frame $sPo(tw).fr.workfr.fr
        pack $sPo(tw).fr.workfr.fr -expand 1 -fill both

        set sPo(paneWin) $sPo(tw).fr.workfr.fr.pane
        ttk::panedwindow $sPo(paneWin) -orient vertical
        pack $sPo(paneWin) -side top -expand 1 -fill both

        set tf $sPo(paneWin).tfr
        set bf $sPo(paneWin).bfr
        set if $sPo(paneWin).ifr
        ttk::frame $tf -relief sunken -borderwidth 1
        ttk::frame $bf -relief sunken -borderwidth 1
        ttk::frame $if -relief sunken -borderwidth 1
        pack  $tf -expand 1 -fill both
        pack  $bf -expand 1 -fill both
        pack  $if -expand 1 -fill both

        $sPo(paneWin) add $tf
        $sPo(paneWin) add $bf
        $sPo(paneWin) add $if

        ttk::frame $tf.leftfr
        ttk::frame $tf.rightfr
        ttk::frame $bf.difffr
        ttk::frame $if.leftfr
        ttk::frame $if.rightfr
        grid $tf.leftfr  -row 0 -column 0 -sticky news -ipadx 2
        grid $tf.rightfr -row 0 -column 1 -sticky news -ipadx 2
        grid $bf.difffr  -row 0 -column 0 -sticky news -ipadx 2
        grid $if.leftfr  -row 0 -column 0 -sticky news -ipadx 2
        grid $if.rightfr -row 0 -column 1 -sticky news -ipadx 2
        grid rowconfigure    $tf 0 -weight 1
        grid columnconfigure $tf 0 -weight 1 -uniform TwoCols
        grid columnconfigure $tf 1 -weight 1 -uniform TwoCols

        grid rowconfigure    $bf 0 -weight 1
        grid columnconfigure $bf 0 -weight 1

        grid rowconfigure    $if 0 -weight 1
        grid columnconfigure $if 0 -weight 1
        grid columnconfigure $if 1 -weight 1

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
        set leftMenu         $fileMenu.left
        set rightMenu        $fileMenu.right
        set sessionMenu      $fileMenu.session
        set sPo(leftMenu)    $leftMenu
        set sPo(rightMenu)   $rightMenu
        set sPo(sessionMenu) $sessionMenu

        menu $fileMenu -tearoff 0
        $fileMenu add cascade -label "Select left dir"  -menu $leftMenu
        $fileMenu add cascade -label "Select right dir" -menu $rightMenu
        $fileMenu add cascade -label "Select session"   -menu $sessionMenu

        menu $leftMenu -tearoff 0 -postcommand "${ns}::AddRecentDirs $leftMenu 1"
        poMenu AddCommand $leftMenu "Browse ..."  "Ctrl+L" "${ns}::ChooseDirs 1"
        $leftMenu add separator
        bind $sPo(tw) <Control-l> "${ns}::ChooseDirs 1"

        menu $rightMenu -tearoff 0 -postcommand "${ns}::AddRecentDirs $rightMenu 2"
        poMenu AddCommand $rightMenu "Browse ..." "Ctrl+R" "${ns}::ChooseDirs 2"
        $rightMenu add separator
        bind $sPo(tw) <Control-r> "${ns}::ChooseDirs 2"

        bind $sPo(tw) <Control-t> "${ns}::SwitchDirs false"
        bind $sPo(tw) <Control-T> "${ns}::SwitchDirs true"

        menu $sessionMenu -tearoff 0 -postcommand "${ns}::AddRecentSessions $sessionMenu"
        poMenu AddCommand $sessionMenu "Edit ..." "" "${ns}::EditRecentList sessionList"
        $sessionMenu add separator

        poMenu AddCommand $fileMenu "Save as session ..." "Ctrl+S" ${ns}::AskSaveSession
        $fileMenu add separator
        poMenu AddCommand $fileMenu "Diff directories (Update)" "F5"     ${ns}::TimeDiffDir
        poMenu AddCommand $fileMenu "Diff selected files"       "Ctrl+D" ${ns}::DiffFiles
        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }
        bind $sPo(tw) <Control-s> ${ns}::AskSaveSession
        bind $sPo(tw) <Key-F5>    ${ns}::TimeDiffDir
        bind $sPo(tw) <Control-d> ${ns}::DiffFiles
        bind $sPo(tw) <Escape>    ${ns}::StopScan
        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Edit
        menu $editMenu -tearoff 0
        poMenu AddCommand $editMenu "Search/Replace" "F3" ${ns}::ShowSearchWin
        bind $sPo(tw) <Key-F3> ${ns}::ShowSearchWin

        # Menu View
        menu $viewMenu -tearoff 0
        poMenu AddCommand $viewMenu "Error log"        "F6" ${ns}::ShowErrorLog
        poMenu AddCommand $viewMenu "Ignored files"    "F7" ${ns}::ShowIgnoreLog
        poMenu AddCommand $viewMenu "Identical files"  "F8" ${ns}::ShowIdentLog
        $viewMenu add separator
        poMenu AddCheck $viewMenu "Show preview tab" "F9" ${ns}::sPo(showPreviewTab) ${ns}::TogglePreviewTab
        poMenu AddCheck $viewMenu "Right alignment"  ""   ${ns}::sPo(columnAlign)    ${ns}::ToggleColumnAlignment -onvalue "right" -offvalue "left"

        $viewMenu add separator
        poMenu AddCommand $viewMenu "Show selected diff files" "F10" "${ns}::SetDiffFile -1"
        bind $sPo(tw) <Key-F6>  ${ns}::ShowErrorLog
        bind $sPo(tw) <Key-F7>  ${ns}::ShowIgnoreLog
        bind $sPo(tw) <Key-F8>  ${ns}::ShowIdentLog
        bind $sPo(tw) <Key-F9>  ${ns}::SwitchPreviewTab
        bind $sPo(tw) <Key-F10> "${ns}::SetDiffFile -1"

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        $settMenu add cascade -label "Application settings" -menu $appSettMenu
        menu $appSettMenu -tearoff 0
        poMenu AddCommand $appSettMenu "Miscellaneous" "" [list ${ns}::ShowSpecificSettWin "Miscellaneous"]
        poMenu AddCommand $appSettMenu "Compare"       "" [list ${ns}::ShowSpecificSettWin "Diff"]

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
        poMenu AddCommand $winMenu [poApps GetAppDescription poDiff]      "" "poApps StartApp poDiff" -state disabled
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

        # Create tablelist and preview for left and right files.
        set sPo(infoPaneL) $if.leftfr.nb
        ttk::notebook $sPo(infoPaneL) -style Hori.TNotebook
        pack $sPo(infoPaneL) -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $sPo(infoPaneL)

        set prefrL $sPo(infoPaneL).prefr
        set tblfrL $sPo(infoPaneL).tblfr
        ttk::frame $prefrL
        ttk::frame $tblfrL
        pack  $prefrL -expand 0 -fill both
        pack  $tblfrL -expand 0 -fill both

        $sPo(infoPaneL) add $prefrL -text "Preview"
        $sPo(infoPaneL) add $tblfrL -text "File Info"

        set sPo(infoPaneR) $if.rightfr.nb
        ttk::notebook $sPo(infoPaneR) -style Hori.TNotebook
        pack $sPo(infoPaneR) -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $sPo(infoPaneR)

        set prefrR $sPo(infoPaneR).prefr
        set tblfrR $sPo(infoPaneR).tblfr
        ttk::frame $prefrR
        ttk::frame $tblfrR 
        pack  $prefrR -expand 0 -fill both
        pack  $tblfrR -expand 0 -fill both

        $sPo(infoPaneR) add $prefrR -text "Preview"
        $sPo(infoPaneR) add $tblfrR -text "File Info"

        set sPo(infoFrameL) [poWinInfo Create $tblfrL ""]
        set sPo(infoFrameR) [poWinInfo Create $tblfrR ""]

        set sPo(previewFrameL) [poWinPreview Create $prefrL ""]
        set sPo(previewFrameR) [poWinPreview Create $prefrR ""]

        # Create Drag-And-Drop bindings for the info panes.
        poDragAndDrop AddTtkBinding $sPo(infoPaneL) ${ns}::SetDirectoryByDrop
        poDragAndDrop AddTtkBinding $sPo(infoPaneR) ${ns}::SetDirectoryByDrop

        set frameList [list \
            [list onlyListL $tf.leftfr  "Only in left directory"  $sPo(infoFrameL) $sPo(previewFrameL) "l"] \
            [list onlyListR $tf.rightfr "Only in right directory" $sPo(infoFrameR) $sPo(previewFrameR) "r"]]
        foreach frameEntry $frameList {
            set sPo([lindex $frameEntry 0]) [CreateScrolledTablelist [lindex $frameEntry 1] [lindex $frameEntry 2]]

            set listboxId $sPo([lindex $frameEntry 0])
            set bodyTag [$listboxId bodytag]

            set infoFrame [lindex $frameEntry 3]
            set previewFrame [lindex $frameEntry 4]

            bind $bodyTag <Any-KeyRelease>  "${ns}::DisplayFileInfo $listboxId $infoFrame $previewFrame"
            bind $bodyTag <ButtonRelease-1> "${ns}::DisplayFileInfo $listboxId $infoFrame $previewFrame"
            bind $bodyTag <1> "+${ns}::SelectListbox $listboxId"
            bind $bodyTag <Double-1> "${ns}::StartAssoc 0"
            bind $bodyTag <<RightButtonPress>> \
                "${ns}::OpenMainContextMenu $listboxId \"\" %X %Y"
            if { $::tcl_platform(platform) eq "windows" } {
                bind $bodyTag <App> "${ns}::OpenMainContextMenu $listboxId \"\" %X %Y"
            }
            set side [lindex $frameEntry 5]
            bind $bodyTag <Delete> "${ns}::DeleteOnlyFromSide $side"
            bind $bodyTag <Key-f>  "${ns}::CopyFileNameToClipboard"
            bind $bodyTag <Key-c>  "${ns}::CopyOnlyFromSide $side"
            bind $bodyTag <Key-m>  "${ns}::MoveOnlyFromSide $side"

            # Create Drag-And-Drop bindings for the tablelists.
            poDragAndDrop AddCanvasBinding $listboxId ${ns}::SetDirectoryByDrop
        }

        set listboxList [CreateSyncTablelist $bf.difffr "Different left" "Different right"] 

        set leftListbox  [lindex $listboxList 0]
        set rightListbox [lindex $listboxList 1]
        set sPo(diffListL) $leftListbox
        set sPo(diffListR) $rightListbox

        ClearDelIndLists

        # Create Drag-And-Drop bindings for the tablelists.
        poDragAndDrop AddCanvasBinding $leftListbox  ${ns}::SetDirectoryByDrop
        poDragAndDrop AddCanvasBinding $rightListbox ${ns}::SetDirectoryByDrop

        set bodyTagLeft  [$leftListbox bodytag]
        set bodyTagRight [$rightListbox bodytag]

        bind $bodyTagLeft  <1> "+${ns}::SelectListbox $leftListbox"
        bind $bodyTagRight <1> "+${ns}::SelectListbox $rightListbox"
        bind $bodyTagLeft <Any-KeyRelease> \
            "${ns}::SynchSelections $leftListbox $rightListbox"
        bind $bodyTagRight <Any-KeyRelease> \
            "${ns}::SynchSelections $rightListbox $leftListbox"
        bind $bodyTagLeft <ButtonRelease-1> \
            "${ns}::SynchSelections $leftListbox $rightListbox"
        bind $bodyTagRight <ButtonRelease-1> \
            "${ns}::SynchSelections $rightListbox $leftListbox"
        bind $bodyTagLeft <Double-1> \
            "${ns}::StartGUIDiff $leftListbox $rightListbox"
        bind $bodyTagRight <Double-1> \
            "${ns}::StartGUIDiff $leftListbox $rightListbox"
        bind $bodyTagLeft <<RightButtonPress>> \
            "${ns}::OpenMainContextMenu $leftListbox $rightListbox %X %Y"
        bind $bodyTagRight <<RightButtonPress>> \
            "${ns}::OpenMainContextMenu $rightListbox $leftListbox %X %Y"

        foreach lbox [list $sPo(onlyListL) $sPo(onlyListR) $sPo(diffListL) $sPo(diffListR)] {
            set bodyTag [$lbox bodytag]
            bind $bodyTag <Control-a> ${ns}::SelectAll
            bind $bodyTag <Key-e>  "${ns}::StartEditor 0"
            bind $bodyTag <Key-E>  "${ns}::StartEditor 1"
            bind $bodyTag <Key-h>  "${ns}::StartHexEditor 0"
            bind $bodyTag <Key-H>  "${ns}::StartHexEditor 1"
            bind $bodyTag <Key-d>  "${ns}::StartGUIDiff $sPo(diffListL) $sPo(diffListR)"
            bind $bodyTag <Key-i>  "${ns}::ShowFileInfoWin"
            bind $bodyTag <Key-I>  "${ns}::ShowFileInfoWin"
            bind $bodyTag <Key-r>  "${ns}::AskRenameFile %X %Y"
            bind $bodyTag <Key-F2> "${ns}::AskRenameFile %X %Y"
            bind $bodyTag <Key-1>  "${ns}::SetDiffFile 1"
            bind $bodyTag <Key-2>  "${ns}::SetDiffFile 2"
            if { [poExtProg SupportsAsso] } {
                bind $bodyTag <Key-o> "${ns}::StartAssoc 0"
                bind $bodyTag <Key-O> "${ns}::StartAssoc 1"
            }
        }
        if { [poExtProg SupportsAsso] } {
            if { [poWin SupportsAppKey] } {
                bind $bodyTagLeft <App> \
                     "${ns}::OpenMainContextMenu $sPo(diffListL) $sPo(diffListR) %X %Y"
                bind $bodyTagRight <App> \
                     "${ns}::OpenMainContextMenu $sPo(diffListR) $sPo(diffListL) %X %Y"
            }
        }

        bind $bodyTagLeft  <Delete> ${ns}::DeleteLeftDiff
        bind $bodyTagRight <Delete> ${ns}::DeleteRightDiff
        bind $bodyTagLeft  <Shift-Delete> ${ns}::DeleteBothDiff
        bind $bodyTagRight <Shift-Delete> ${ns}::DeleteBothDiff

        bind $bodyTagLeft  <Key-f> ${ns}::CopyFileNameToClipboard
        bind $bodyTagRight <Key-f> ${ns}::CopyFileNameToClipboard

        bind $bodyTagLeft  <Key-c> ${ns}::CopyLeftDiffToRightDiff
        bind $bodyTagRight <Key-c> ${ns}::CopyRightDiffToLeftDiff

        bind $bodyTagLeft  <Key-m> ${ns}::MoveLeftDiffToRightDiff
        bind $bodyTagRight <Key-m> ${ns}::MoveRightDiffToLeftDiff

        # Add new toolbar group and associated buttons.
        set toolfr $sPo(tw).fr.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        set leftBtn [poToolbar AddButton $toolfr [::poBmpData::openleft] \
                    "${ns}::ChooseDirs 1" "Select left directory (Ctrl+L)"]
        set rightBtn [poToolbar AddButton $toolfr [::poBmpData::openright] \
                     "${ns}::ChooseDirs 2" "Select right directory (Ctrl+R)"]
        set switchBtn [poToolbar AddButton $toolfr [::poBmpData::switch] \
                      "${ns}::SwitchDirs false" \
                      "Switch directories (Ctrl+T)\nSwitch and diff (Ctrl+Shift+T)"]
        set diffBtn [poToolbar AddButton $toolfr [::poBmpData::diff] \
                    ${ns}::TimeDiffDir "Diff directories (F5)"]
        set settBtn [poToolbar AddButton $toolfr [::poBmpData::wheel] \
                    "${ns}::ShowSpecificSettWin Diff" "Show diff settings (Ctrl+F5)"]
        poToolbar AddButton $toolfr [::poBmpData::halt "red"] \
                  ${ns}::StopScan "Stop current compare job (Esc)"

        poWin AddToSwitchableWidgets "Diff" $leftBtn $rightBtn $switchBtn $diffBtn $settBtn

        bind $sPo(tw) <Control-Key-F5> [list ${ns}::ShowSpecificSettWin "Diff"]

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::search] \
                  ${ns}::ShowSearchWin "Show search/replace window (F3)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::logerror] \
                  ${ns}::ShowErrorLog "Show error log (F6)"
        poToolbar AddButton $toolfr [::poBmpData::logignore] \
                  ${ns}::ShowIgnoreLog "Show log of ignored files (F7)"
        poToolbar AddButton $toolfr [::poBmpData::logident] \
                  ${ns}::ShowIdentLog "Show log of identical files (F8)"

        # Add new toolbar group and associated buttons.
        poToolbar AddGroup $toolfr
        poToolbar AddCheckButton $toolfr [::poBmpData::infofile] \
                  ${ns}::TogglePreviewTab "Show preview tab (F9)" \
                  -variable ${ns}::sPo(showPreviewTab)
        poToolbar AddCheckButton $toolfr [::poBmpData::wrapline] \
                  ${ns}::ToggleColumnAlignment "Right column alignment" \
                  -variable ${ns}::sPo(columnAlign) -onvalue "right" -offvalue "left"

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget,diff) [poWin CreateStatusWidget $sPo(tw).fr.statfr true]

        UpdateFileCount
        WriteMainInfoStr $sPo(initStr) $sPo(initType)

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        TogglePreviewTab

        if { ! [poApps GetHideWindow] } {
            update
        }
        $sPo(paneWin) pane $tf -weight 1
        $sPo(paneWin) pane $bf -weight 1
        $sPo(paneWin) pane $if -weight 0
        $sPo(paneWin) sashpos 0 $sPo(sashY0)
        $sPo(paneWin) sashpos 1 $sPo(sashY1)

        # Enable the info and the preview tab, so that the window sizes are initialized.
        SwitchPreviewTab
        SwitchPreviewTab

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
        set sPo(appWindowClosed) false
    }

    proc SwitchPreviewTab {} {
        variable sPo

        set sPo(showPreviewTab) [expr ! $sPo(showPreviewTab)]
        TogglePreviewTab
    }

    proc TogglePreviewTab {} {
        variable sPo

        $sPo(infoPaneL) select [expr ! $sPo(showPreviewTab)]
        $sPo(infoPaneR) select [expr ! $sPo(showPreviewTab)]
    }

    proc ToggleColumnAlignment {} {
        variable sPo

        set tableList [list diffListL diffListR identListL identListR onlyListL onlyListR ignListL ignListR searchList]
        foreach tableName $tableList {
            if { [info exists sPo($tableName)] && [winfo exists $sPo($tableName)] } {
                $sPo($tableName) columnconfigure 0 -align  $sPo(columnAlign)
            }
        }
    }

    proc AskRenameFile { x y } {
        variable sPo

        set listboxId $sPo(curListbox)
        if { ! [IsListWidget $listboxId] } {
            return
        }

        set selItemList  [GetListSelection $listboxId]
        set selIndexList [GetListSelectionIndices $listboxId]
        if { [llength $selItemList] == 0 } {
            return
        }
        if { [llength $selItemList] != 1 } {
            tk_messageBox -icon info -type ok \
                          -message "More than one file selected for renaming."
            return
        }
        if { $x <= 0 || $y <= 0 } {
            # Workaround for bug in Tcl 8.6.0 on Darwin, which returns zero or negative values
            # for cursor positions, when activated via a key event.
            set x [winfo pointerx $sPo(tw)]
            set y [winfo pointery $sPo(tw)]
        }

        set curItem   [lindex $selItemList 0]
        set origName  [AbsPath $curItem [GetRootDir $listboxId]]
        set shortName [file tail $origName]
        set dirName   [file dirname $origName]

        lassign [poWin EntryBox $shortName $x $y] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName eq "" } {
            WriteMainInfoStr "No file name specified. Not renamed." "Error"
            return
        }

        set retName [poMisc QuoteTilde $retName]
        set newName [file join $dirName $retName]
        if { [file exists $newName] } {
            set retVal [tk_messageBox -icon question -type yesno -default yes \
                -message "File $newName already exists. Overwrite?" \
                -title "Confirmation"]
            if { $retVal eq "no" } {
                return
            }
        }

        set catchVal [catch { file rename -force $origName $newName } ]
        if { $catchVal } {
            lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
            incr sPo(readErrors)
            ShowErrorLog
            return
        }

        set curInd [lindex $selIndexList 0]
        $listboxId delete $curInd
        if { $sPo(relPathes) } {
            set newName [AbsToRel $newName [GetRootDir $listboxId]]
        }
        SetListEntry $listboxId $curInd $newName
        $listboxId selection set $curInd
        WriteMainInfoStr "Please rediff manually to update lists." "Warning"
    }

    proc DeleteOnlyFromSide { side } {
        variable sPo

        if { $side eq "l" } {
            ManipFiles $sPo(onlyListL) $sPo(onlyListR) $sPo(dir1) $sPo(dir2) 2 ""
        } else {
            ManipFiles $sPo(onlyListR) $sPo(onlyListL) $sPo(dir2) $sPo(dir1) 2 ""
        }
    }

    proc DeleteLeftIde {} {
        variable sPo

        ManipFiles $sPo(identListL) $sPo(identListR) $sPo(dir1) $sPo(dir2) 2 $sPo(onlyListR)
    }

    proc DeleteRightIde {} {
        variable sPo

        ManipFiles $sPo(identListR) $sPo(identListL) $sPo(dir2) $sPo(dir1) 2 $sPo(onlyListL)
    }

    proc DeleteBothIde {} {
        variable sPo

        ManipFiles $sPo(identListL) $sPo(identListR) $sPo(dir1) $sPo(dir2) 2 ""
        ManipFiles $sPo(identListR) $sPo(identListL) $sPo(dir2) $sPo(dir1) 2 ""
    }

    proc DeleteLeftIgn {} {
        variable sPo

        ManipFiles $sPo(ignListL) $sPo(ignListR) $sPo(dir1) $sPo(dir2) 2 ""
    }

    proc DeleteRightIgn {} {
        variable sPo

        ManipFiles $sPo(ignListR) $sPo(ignListL) $sPo(dir2) $sPo(dir1) 2 ""
    }

    proc DeleteLeftDiff {} {
        variable sPo

        ManipFiles $sPo(diffListL) $sPo(diffListR) $sPo(dir1) $sPo(dir2) 2 $sPo(onlyListR)
    }

    proc DeleteRightDiff {} {
        variable sPo

        ManipFiles $sPo(diffListR) $sPo(diffListL) $sPo(dir2) $sPo(dir1) 2 $sPo(onlyListL)
    }

    proc DeleteBothDiff {} {
        variable sPo

        ManipFiles $sPo(diffListL) $sPo(diffListR) $sPo(dir1) $sPo(dir2) 2 ""
        ManipFiles $sPo(diffListR) $sPo(diffListL) $sPo(dir2) $sPo(dir1) 2 ""
    }

    proc DeleteSearchFromSide { { side "" } } {
        variable sPo

        if { $side eq "" } {
            set side [GetSearchSide]
        }
        if { $side eq "l" } {
            ManipFiles $sPo(searchList) "" $sPo(dir1) $sPo(dir2) 2 ""
        } else {
            ManipFiles $sPo(searchList) "" $sPo(dir2) $sPo(dir1) 2 ""
        }
    }

    proc MoveOnlyFromSide { side } {
        variable sPo

        if { $side eq "l" } {
            ManipFiles $sPo(onlyListL) $sPo(onlyListR) $sPo(dir1) $sPo(dir2) 1 ""
        } else {
            ManipFiles $sPo(onlyListR) $sPo(onlyListL) $sPo(dir2) $sPo(dir1) 1 ""
        }
    }

    proc MoveLeftIgnToRightIgn {} {
        variable sPo

        ManipFiles $sPo(ignListL) $sPo(ignListR) $sPo(dir1) $sPo(dir2) 1 ""
    }

    proc MoveRightIgnToLeftIgn {} {
        variable sPo

        ManipFiles $sPo(ignListR) $sPo(ignListL) $sPo(dir2) $sPo(dir1) 1 ""
    }

    proc MoveLeftIdeToRightIde {} {
        variable sPo

        ManipFiles $sPo(identListL) $sPo(identListR) $sPo(dir1) $sPo(dir2) 1 $sPo(onlyListR)
    }

    proc MoveRightIdeToLeftIde {} {
        variable sPo

        ManipFiles $sPo(identListR) $sPo(identListL) $sPo(dir2) $sPo(dir1) 1 $sPo(onlyListL)
    }

    proc MoveLeftDiffToRightDiff {} {
        variable sPo

        ManipFiles $sPo(diffListL) $sPo(diffListR) $sPo(dir1) $sPo(dir2) 1 $sPo(onlyListR)
    }

    proc MoveRightDiffToLeftDiff {} {
        variable sPo

        ManipFiles $sPo(diffListR) $sPo(diffListL) $sPo(dir2) $sPo(dir1) 1 $sPo(onlyListL)
    }

    proc MoveSearchFromSide { { side "" } } {
        variable sPo

        if { $side eq "" } {
            set side [GetSearchSide]
        }
        if { $side eq "l" } {
            ManipFiles $sPo(searchList) "" $sPo(dir1) $sPo(dir2) 1 ""
        } else {
            ManipFiles $sPo(searchList) "" $sPo(dir2) $sPo(dir1) 1 ""
        }
    }

    proc CopyOnlyFromSide { side } {
        variable sPo

        if { $side eq "l" } {
            ManipFiles $sPo(onlyListL) $sPo(onlyListR) $sPo(dir1) $sPo(dir2) 0 ""
        } else {
            ManipFiles $sPo(onlyListR) $sPo(onlyListL) $sPo(dir2) $sPo(dir1) 0 ""
        }
    }

    proc CopyLeftIgnToRightIgn {} {
        variable sPo

        ManipFiles $sPo(ignListL) $sPo(ignListR) $sPo(dir1) $sPo(dir2) 0 ""
    }

    proc CopyRightIgnToLeftIgn {} {
        variable sPo

        ManipFiles $sPo(ignListR) $sPo(ignListL) $sPo(dir2) $sPo(dir1) 0 ""
    }

    proc CopyLeftIdeToRightIde {} {
        variable sPo

        ManipFiles $sPo(identListL) $sPo(identListR) $sPo(dir1) $sPo(dir2) 0 "something"
    }

    proc CopyRightIdeToLeftIde {} {
        variable sPo

        ManipFiles $sPo(identListR) $sPo(identListL) $sPo(dir2) $sPo(dir1) 0 "something"
    }

    proc CopyLeftDiffToRightDiff {} {
        variable sPo

        ManipFiles $sPo(diffListL) $sPo(diffListR) $sPo(dir1) $sPo(dir2) 0 "something"
    }

    proc CopyRightDiffToLeftDiff {} {
        variable sPo

        ManipFiles $sPo(diffListR) $sPo(diffListL) $sPo(dir2) $sPo(dir1) 0 "something"
    }

    proc CopySearchFromSide { { side "" } } {
        variable sPo

        if { $side eq "" } {
            set side [GetSearchSide]
        }
        if { $side eq "l" } {
            ManipFiles $sPo(searchList) "" $sPo(dir1) $sPo(dir2) 0 ""
        } else {
            ManipFiles $sPo(searchList) "" $sPo(dir2) $sPo(dir1) 0 ""
        }
    }

    proc ManipFiles { fromListbox toListbox fromRoot toRoot opCode diffListbox } {
        variable sPo
        variable sDelIndList

        set opCopy 0
        set opMove 1
        set opDel  2

        if { [IsSearchListbox $fromListbox] } {
            set widgetName "search"
        } else {
            set widgetName "diff"
        }
        set sPo(stopScan) 0
        set dirSep "/"
        set indList [lsort -integer -decreasing [GetListSelectionIndices $fromListbox]]
        set numSel [llength $indList]
        set selList [GetListSelection $fromListbox]
        if { $numSel == 0 } {
            return
        } elseif { $numSel == 1 } {
            set fileStr "this file"
        } else {
            set fileStr "these $numSel files"
        }
        if { $opCode == $opDel } {
            if { $sPo(deleteConfirm) } {
                set doIt [poWin CreateListConfirmWin $selList \
                            "Delete Confirmation" "Delete $fileStr from $fromRoot ?" "#FC3030"]
                if { ! $doIt } {
                    return
                }
            }
            WriteInfoStr $widgetName "Deleting $numSel file[poMisc Plural $numSel] from $fromRoot" "Watch"
        } elseif { $opCode == $opCopy } {
            if { $sPo(copyConfirm) } {
                set doIt [poWin CreateListConfirmWin $selList \
                          "Copy Confirmation" "Copy $fileStr to: $toRoot ?" "#30FC30"]
                if { ! $doIt } {
                    return
                }
            }
            WriteInfoStr $widgetName "Copying $numSel file[poMisc Plural $numSel] to $toRoot ..." "Watch"
        } elseif { $opCode == $opMove } {
            if { $sPo(moveConfirm) } {
                set doIt [poWin CreateListConfirmWin $selList \
                          "Move Confirmation" "Move $fileStr to: $toRoot ?" "#FCFC30"]
                if { ! $doIt } {
                    return
                }
            }
            WriteInfoStr $widgetName "Moving $numSel file[poMisc Plural $numSel] to $toRoot ..." "Watch"
        }

        set toDo $numSel
        set fileCount 0
        $sPo(tw) configure -cursor watch
        poWin InitStatusProgress $sPo(StatusWidget,diff) $numSel
        set firstEntry [lindex $indList end]

        poWatch Start swatch
        poWatch Reset swatch

        foreach ind $indList {
            incr fileCount
            set fromEntry [GetListEntry $fromListbox $ind]
            set fileName1 [AbsPath $fromEntry $fromRoot]
            set len [string length $fromRoot]
            set relPath [string trimleft [string range $fileName1 $len end] $dirSep]
            set relPath [poMisc QuoteTilde $relPath]            
            set fileName2 [file join $toRoot $relPath]
            set dirName2 [file dirname $fileName2]
            if { $sPo(immediateUpdate) } { 
                if { $opCode == $opMove } {
                    WriteInfoStr $widgetName "$toDo: Moving file $fileName1 to $fileName2 ..." "Watch"
                } elseif { $opCode == $opCopy } {
                    WriteInfoStr $widgetName "$toDo: Copying file $fileName1 to $fileName2 ..." "Watch"
                } elseif { $opCode == $opDel } {
                    WriteInfoStr $widgetName "$toDo: Deleting file $fileName1 ..." "Watch"
                }
            }

            if { $opCode != $opDel } {
                if { ! [file isdirectory $dirName2] } {
                    file mkdir $dirName2
                }
                file copy -force $fileName1 $fileName2
                # Do not delete the entry from the fromListbox, 
                # if it's the search window and we copy the file.
                if { $sPo(immediateUpdate) } {
                    if { ! ($toListbox eq "" && $opCode == $opCopy) } {
                        $fromListbox delete $ind
                    }
                    if { $diffListbox ne "" } {
                        $toListbox delete $ind
                    }
                } else {
                    if { ! ($toListbox eq "" && $opCode == $opCopy) } {
                        lappend sDelIndList($fromListbox) $ind
                    }
                    if { $diffListbox ne "" } {
                        lappend sDelIndList($toListbox) $ind
                    }
                }
            }

            if { $opCode == $opMove } {
                if { $diffListbox eq "" } {
                    if { $toListbox ne "" } {
                        if { $sPo(relPathes) } {
                            set fileName2 [AbsToRel $fileName2 [GetRootDir $toListbox]]
                        }
                        SetListEntry $toListbox end $fileName2
                        $toListbox see end
                    }
                } else {
                    if { $sPo(relPathes) } {
                        set fileName2 [AbsToRel $fileName2 [GetRootDir $diffListbox]]
                    }
                    SetListEntry $diffListbox end $fileName2
                    $diffListbox see end
                }
                file delete $fileName1
            } elseif { $opCode == $opCopy } {
                if { [IsIdentListbox $fromListbox] || [IsIdentListbox $toListbox] } { 
                } else {
                    AddToIdentLog $fileName1 $fileName2
                }
            } elseif { $opCode == $opDel } {
                file delete $fileName1
                if { $sPo(immediateUpdate) } {
                    $fromListbox delete $ind
                    if { $diffListbox ne "" } {
                        $toListbox delete $ind
                        if { $sPo(relPathes) } {
                            set fileName2 [AbsToRel $fileName2 [GetRootDir $diffListbox]]
                        }
                        SetListEntry $diffListbox end $fileName2
                        $diffListbox see end
                    }
                } else {
                    lappend sDelIndList($fromListbox) $ind
                    if { $diffListbox ne "" } {
                        lappend sDelIndList($toListbox) $ind
                        if { $sPo(relPathes) } {
                            set fileName2 [AbsToRel $fileName2 [GetRootDir $diffListbox]]
                        }
                        SetListEntry $diffListbox end $fileName2
                    }
                }
            }
            if { $sPo(immediateUpdate) || ( ( $toDo -1 ) % 100 == 0 ) } { 
                UpdateFileCount
                poWin UpdateStatusProgress $sPo(StatusWidget,diff) $fileCount
            }
            if { $sPo(stopScan) } {
                $sPo(tw) configure -cursor arrow
                break
            }
            incr toDo -1
        }

        $fromListbox delete $sDelIndList($fromListbox)
        $toListbox   delete $sDelIndList($toListbox)
        set sDelIndList($fromListbox) [list]
        set sDelIndList($toListbox)   [list]

        UpdateFileCount
        set newSize [$fromListbox size]
        if { $firstEntry >= $newSize } {
            set firstEntry [expr { $newSize - 1 }]
        }
        $fromListbox selection set $firstEntry

        set elapsedTimeStr [format " (Elapsed time: %.1f seconds)" [poWatch Lookup swatch]]
        if { $opCode == $opMove } {
            if { $numSel == 1 } {
                WriteInfoStr $widgetName "Moved file $fileName1 to $fileName2 $elapsedTimeStr" "Ok"
            } else {
                WriteInfoStr $widgetName "Moved $numSel files to $toRoot $elapsedTimeStr" "Ok"
            }
        } elseif { $opCode == $opCopy } {
            if { $numSel == 1 } {
                WriteInfoStr $widgetName "Copied file $fileName1 to $fileName2 $elapsedTimeStr" "Ok"
            } else {
                WriteInfoStr $widgetName "Copied $numSel files to $toRoot $elapsedTimeStr" "Ok"
            }
        } elseif { $opCode == $opDel } {
            if { $numSel == 1 } {
                WriteInfoStr $widgetName "Deleted file $fileName1 $elapsedTimeStr" "Ok"
            } else {
                WriteInfoStr $widgetName "Deleted $numSel files from $fromRoot $elapsedTimeStr" "Ok"
            }
        }
        poWin UpdateStatusProgress $sPo(StatusWidget,diff) 0
        $sPo(tw) configure -cursor arrow
    }

    proc CopyFileNameToClipboard {} {
        variable sPo

        set w $sPo(curListbox)
        if { ! [IsListWidget $w] } {
            return
        }

        if { [IsSearchListbox $w] } {
            set widgetName "search"
        } else {
            set widgetName "diff"
        }
        set indList [GetListSelectionIndices $w]
        set numSel [llength $indList]
        set selList [GetListSelection $w]
        if { $numSel == 0 } {
            return
        }
        if { $numSel == 1 } {
            set nameString [GetListEntry $w [lindex $indList 0]]
        } else {
            set nameString ""
            foreach ind $indList {
                set fromEntry [GetListEntry $w $ind]
                append nameString $fromEntry "\n"
            }
        }
        clipboard clear
        clipboard append $nameString
        if { $numSel == 1 } {
            WriteInfoStr $widgetName "Copied $nameString to clipboard" "Ok"
        } else {
            WriteInfoStr $widgetName "Copied $numSel files to clipboard" "Ok"
        }
    }

    proc SetDir { dir num } {
        variable sPo

        set sPo(dir$num) $dir
        if { $num == 1 } {
            WriteMainInfoStr "Directory $dir set as left directory" "Ok"
        } else {
            WriteMainInfoStr "Directory $dir set as right directory" "Ok"
        }
        InvalidateCache
        UpdateMainTitle
        UpdateSearchWin
    }

    proc SetDirectory { dir num } {
        variable sPo

        SetDir $dir $num
        poWinSelect SetValue $sPo(dir$num,combo) $dir
    }

    proc SetDirectoryByDrop { tableId dirList } {
        foreach dir $dirList {
            if { [file isfile $dir] } {
                set dir [file dirname $dir]
            }
            if { [file isdirectory $dir] } {
                if { [string match "*left*" $tableId] } {
                    set num 1
                } else {
                    set num 2
                }
                SetDirectory $dir $num
                return
            }
        }
    }

    proc ShowErrorLog {} {
        variable sPo

        set tw .poDiff_ErrorLog
        set sPo(errorLog,name) $tw

        catch { destroy $tw }

        toplevel $tw
        wm title $tw "Error log"
        wm resizable $tw true true

        ttk::frame $tw.fr0
        grid $tw.fr0 -row 0 -column 0 -sticky news
        set listboxId [poWin CreateScrolledListbox $tw.fr0 true "" \
                       -width 50 -selectmode extended \
                       -exportselection false]
        if { [llength $sPo(errorLog)] == 0 } {
            $listboxId insert end "No errors encountered"
        } else {
            foreach err $sPo(errorLog) {
                $listboxId insert end $err
            }
        }

        grid rowconfigure $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1

        bind $tw <Escape> "destroy $tw"
        bind $tw <Return> "destroy $tw"
        focus $tw
    }

    proc DestroyIgnoreLog { tw } {
        variable sPo

        eval SetWindowPos [GetWindowPos ignoreLog]
        catch { unset sPo(ignListL) }
        catch { unset sPo(ignListR) }
        destroy $tw
    }

    proc ShowIgnoreLog {} {
        variable sPo
        variable sDelIndList
        variable ns

        set tw .poDiff_IgnoreLog
        set sPo(ignoreLog,name) $tw

        catch { DestroyIgnoreLog $tw }

        toplevel $tw
        wm title $tw "Ignored directories and files"
        wm resizable $tw true true
        wm geometry $tw [format "%dx%d+%d+%d" \
                         $sPo(ignoreLog,w) $sPo(ignoreLog,h) \
                         $sPo(ignoreLog,x) $sPo(ignoreLog,y)]

        ttk::frame $tw.frL
        ttk::frame $tw.frR
        set numDirsLeft   [llength $sPo(ignLogDirL)]
        set numDirsRight  [llength $sPo(ignLogDirR)]
        set numFilesLeft  [llength $sPo(ignLogFileL)]
        set numFilesRight [llength $sPo(ignLogFileR)]
        set numLeft  [expr { $numDirsLeft  + $numFilesLeft }]
        set numRight [expr { $numDirsRight + $numFilesRight }]

        set leftListbox  [CreateScrolledTablelist $tw.frL "Ignored left ($numLeft files)"]
        set rightListbox [CreateScrolledTablelist $tw.frR "Ignored right ($numRight files)"]

        set sPo(ignListL) $leftListbox
        set sPo(ignListR) $rightListbox

        set sDelIndList($sPo(ignListL))   [list]
        set sDelIndList($sPo(ignListR))   [list]

        set bodyTagLeft [$leftListbox bodytag]
        bind $bodyTagLeft <<RightButtonPress>> \
            [list ${ns}::OpenMainContextMenu $leftListbox "" %X %Y]
        bind $bodyTagLeft <1> "+${ns}::SelectListbox $leftListbox"

        set bodyTagRight [$rightListbox bodytag]
        bind $bodyTagRight <<RightButtonPress>> \
            [list ${ns}::OpenMainContextMenu $rightListbox "" %X %Y]
        bind $bodyTagRight <1> "+${ns}::SelectListbox $rightListbox"

        bind $tw <Control-a> ${ns}::SelectAll
        bind $tw <Key-e> "${ns}::StartEditor 0"
        bind $tw <Key-E> "${ns}::StartEditor 1"
        bind $tw <Key-h> "${ns}::StartHexEditor 0"
        bind $tw <Key-H> "${ns}::StartHexEditor 1"
        if { [poExtProg SupportsAsso] } {
            bind $tw <Key-o> "${ns}::StartAssoc 0"
            bind $tw <Key-O> "${ns}::StartAssoc 1"
            if { [poWin SupportsAppKey] } {
                bind $tw <App> {poDiff::OpenMainContextMenu [winfo containing %X %Y] "" %X %Y}
            }
        }
        bind $tw <Key-i>     ${ns}::ShowFileInfoWin
        bind $tw <Key-I>     ${ns}::ShowFileInfoWin
        bind $tw <Key-r>    "${ns}::AskRenameFile %X %Y"
        bind $tw <Key-F2>   "${ns}::AskRenameFile %X %Y"
        bind $tw <Control-d> ${ns}::DiffFiles

        bind $bodyTagLeft  <Key-1>  "${ns}::SetDiffFile 1"
        bind $bodyTagRight <Key-1>  "${ns}::SetDiffFile 1"
        bind $bodyTagLeft  <Key-2>  "${ns}::SetDiffFile 2"
        bind $bodyTagRight <Key-2>  "${ns}::SetDiffFile 2"

        bind $bodyTagLeft  <Delete> ${ns}::DeleteLeftIgn
        bind $bodyTagRight <Delete> ${ns}::DeleteRightIgn

        bind $bodyTagLeft  <Key-f> ${ns}::CopyFileNameToClipboard
        bind $bodyTagRight <Key-f> ${ns}::CopyFileNameToClipboard

        bind $bodyTagLeft  <Key-c> ${ns}::CopyLeftIgnToRightIgn
        bind $bodyTagRight <Key-c> ${ns}::CopyRightIgnToLeftIgn

        bind $bodyTagLeft  <Key-m> ${ns}::MoveLeftIgnToRightIgn
        bind $bodyTagRight <Key-m> ${ns}::MoveRightIgnToLeftIgn

        foreach ign $sPo(ignLogDirL) {
            SetListEntry $leftListbox end $ign
        }
        foreach ign $sPo(ignLogFileL) {
            SetListEntry $leftListbox end $ign
        }
        foreach ign $sPo(ignLogDirR) {
            SetListEntry $rightListbox end $ign
        }
        foreach ign $sPo(ignLogFileR) {
            SetListEntry $rightListbox end $ign
        }

        grid $tw.frL -row 0 -column 0 -sticky nswe
        grid $tw.frR -row 0 -column 1 -sticky nswe
        grid rowconfigure $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1 -uniform TwoCols
        grid columnconfigure $tw 1 -weight 1 -uniform TwoCols

        bind $tw <Control-w> "${ns}::DestroyIgnoreLog $tw"
        bind $tw <Escape>    "${ns}::DestroyIgnoreLog $tw"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::DestroyIgnoreLog $tw"
        focus $tw
    }

    proc DestroyIdentLog { tw } {
        variable sPo

        eval SetWindowPos [GetWindowPos identLog]
        catch { unset sPo(identListL) }
        catch { unset sPo(identListR) }
        destroy $tw
    }

    proc ShowIdentLog {} {
        variable sPo
        variable sDelIndList
        variable ns

        set tw .poDiff_IdentLog
        set sPo(identLog,name) $tw

        catch { DestroyIdentLog $tw }

        toplevel $tw
        wm title $tw "Identical files"
        wm resizable $tw true true
        wm geometry $tw [format "%dx%d+%d+%d" \
                         $sPo(identLog,w) $sPo(identLog,h) \
                         $sPo(identLog,x) $sPo(identLog,y)]

        ttk::frame $tw.fr0
        set numFiles [llength $sPo(identLog)]
        set listboxList [CreateSyncTablelist $tw.fr0 "Identical left ($numFiles files)" "Identical right ($numFiles files)"] 

        set leftListbox  [lindex $listboxList 0]
        set rightListbox [lindex $listboxList 1]
        set sPo(identListL) $leftListbox
        set sPo(identListR) $rightListbox

        set sDelIndList($sPo(identListL)) [list]
        set sDelIndList($sPo(identListR)) [list]

        set bodyTagLeft  [$leftListbox bodytag]
        set bodyTagRight [$rightListbox bodytag]

        bind $bodyTagLeft  <1> "+${ns}::SelectListbox $leftListbox"
        bind $bodyTagRight <1> "+${ns}::SelectListbox $rightListbox"
        bind $bodyTagLeft <Any-KeyRelease> \
            "${ns}::SynchSelections $leftListbox $rightListbox"
        bind $bodyTagRight <Any-KeyRelease> \
            "${ns}::SynchSelections $rightListbox $leftListbox"
        bind $bodyTagLeft <ButtonRelease-1> \
            "${ns}::SynchSelections $leftListbox $rightListbox"
        bind $bodyTagRight <ButtonRelease-1> \
            "${ns}::SynchSelections $rightListbox $leftListbox"
        bind $bodyTagLeft <<RightButtonPress>> \
            "${ns}::OpenMainContextMenu $leftListbox $rightListbox %X %Y"
        bind $bodyTagRight <<RightButtonPress>> \
            "${ns}::OpenMainContextMenu $rightListbox $leftListbox %X %Y"

        bind $tw <Control-a> ${ns}::SelectAll
        bind $tw <Key-e> "${ns}::StartEditor 0"
        bind $tw <Key-E> "${ns}::StartEditor 1"
        bind $tw <Key-h> "${ns}::StartHexEditor 0"
        bind $tw <Key-H> "${ns}::StartHexEditor 1"
        if { [poExtProg SupportsAsso] } {
            bind $tw <Key-o> "${ns}::StartAssoc 0"
            bind $tw <Key-O> "${ns}::StartAssoc 1"
            if { [poWin SupportsAppKey] } {
                bind $tw <App> {poDiff::OpenMainContextMenu [winfo containing %X %Y] "" %X %Y}
            }
        }
        bind $tw <Key-i>     ${ns}::ShowFileInfoWin
        bind $tw <Key-I>     ${ns}::ShowFileInfoWin
        bind $tw <Key-r>    "${ns}::AskRenameFile %X %Y"
        bind $tw <Key-F2>   "${ns}::AskRenameFile %X %Y"
        bind $tw <Control-d> ${ns}::DiffFiles

        bind $bodyTagLeft  <Key-1>  "${ns}::SetDiffFile 1"
        bind $bodyTagRight <Key-1>  "${ns}::SetDiffFile 1"
        bind $bodyTagLeft  <Key-2>  "${ns}::SetDiffFile 2"
        bind $bodyTagRight <Key-2>  "${ns}::SetDiffFile 2"

        bind $bodyTagLeft  <Delete> ${ns}::DeleteLeftIde
        bind $bodyTagRight <Delete> ${ns}::DeleteRightIde

        bind $bodyTagLeft  <Key-f> ${ns}::CopyFileNameToClipboard
        bind $bodyTagRight <Key-f> ${ns}::CopyFileNameToClipboard

        bind $bodyTagLeft  <Key-c> ${ns}::CopyLeftIdeToRightIde
        bind $bodyTagRight <Key-c> ${ns}::CopyRightIdeToLeftIde

        bind $bodyTagLeft  <Key-m> ${ns}::MoveLeftIdeToRightIde
        bind $bodyTagRight <Key-m> ${ns}::MoveRightIdeToLeftIde

        update

        # identLog list: fileLeft fileRight markLeft markRight sizeLeft sizeRight timeLeft timeRight
        foreach ident $sPo(identLog) {
            SetListEntry $leftListbox  end [lindex $ident 0] [lindex $ident 4] [lindex $ident 6]
            SetListEntry $rightListbox end [lindex $ident 1] [lindex $ident 5] [lindex $ident 7]
            if { $sPo(markNewer) } {
                set markLeft  [lindex $ident 2]
                set markRight [lindex $ident 3]
                if { $markLeft } {
                    MarkNewerListEntry $leftListbox end
                }
                if { $markRight } {
                    MarkNewerListEntry $rightListbox end
                }
            }
        }

        grid $tw.fr0 -row 0 -column 0 -sticky nswe
        grid rowconfigure $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1

        bind $tw <Control-w> "${ns}::DestroyIdentLog $tw"
        bind $tw <Escape>    "${ns}::DestroyIdentLog $tw"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::DestroyIdentLog $tw"
        focus $tw
    }

    proc SetDiffFile { num } {
        variable sPo
        variable ns

        set listId $sPo(curListbox)

        if { $num > 0 } {
            if { [IsListWidget $listId] } {
                set selList [GetListSelection $listId]
                if { [llength $selList] > 0 } {
                    set fileName [lindex $selList 0]
                    if { $num == 1 } {
                        set sPo(leftFile)  [AbsPath $fileName [GetRootDir $listId]]
                    } else {
                        set sPo(rightFile) [AbsPath $fileName [GetRootDir $listId]]
                    }
                }
            }
        }
        if { [IsSearchListbox $listId] } {
            WriteSearchInfoStr "Diff set to: \"$sPo(leftFile)\" vs. \"$sPo(rightFile)\"" "Ok"
        }
        WriteMainInfoStr "Diff set to: \"$sPo(leftFile)\" vs. \"$sPo(rightFile)\"" "Ok"
    }

    proc ConvertFile { masterList mode } {
        variable sPo

        set selItemList [GetListSelection $masterList]
        set numSel [llength $selItemList]
        if { $numSel == 0 } {
            return
        }

        if { $numSel == 1 } {
            set fileStr "this file"
        } else {
            set fileStr "these $numSel files"
        }
        if { $sPo(convConfirm) } {
            set modeStr "Unknown"
            if { $mode eq "lf" } {
                set modeStr "Unix"
            } elseif { $mode eq "cr" } {
                set modeStr "Mac"
            } elseif { $mode eq "crlf" } {
                set modeStr "Dos"
            }
            set doIt [poWin CreateListConfirmWin $selItemList \
                      "Convert Confirmation" "Convert $fileStr to: $modeStr ?" "#30A0FC"]
            if { ! $doIt } {
                return
            }
        }

        foreach name $selItemList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $name [GetRootDir $masterList]]
            poMisc FileConvert $fileName $mode
        }
    }

    proc TouchFile { masterList slaveList { touchBoth false } } {
        variable sPo

        set selMasterItemList [GetListSelection $masterList]
        set numSel [llength $selMasterItemList]
        if { $numSel == 0 } {
            return
        }
        if { [llength $slaveList] != 0 } {
            set selSlaveItemList [GetListSelection $slaveList]
        }
        set selIndexList [GetListSelectionIndices $masterList]

        set touchTime [clock seconds]
        set listIndex 0
        foreach name $selMasterItemList listboxIndex $selIndexList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $name [GetRootDir $masterList]]
            set catchVal [catch { file mtime $fileName $touchTime } retVal]
            if { $catchVal } {
                lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
                incr sPo(readErrors)
                ShowErrorLog
            }
            if { $touchBoth && [llength $slaveList] != 0 } {
                set fileName [AbsPath [lindex $selSlaveItemList $listIndex] [GetRootDir $slaveList]]
                set catchVal [catch { file mtime $fileName $touchTime } retVal]
                if { $catchVal } {
                    lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
                    incr sPo(readErrors)
                    ShowErrorLog
                }
            }
            if { $sPo(markNewer) } {
                if { [llength $slaveList] != 0 } {
                    if { $touchBoth } {
                        MarkNewerListEntry $masterList $listboxIndex false
                    } else {
                        MarkNewerListEntry $masterList $listboxIndex true
                    }
                    MarkNewerListEntry $slaveList $listboxIndex false
                }
            }
            incr listIndex
        }
    }

    proc DisplayFileInfo { listId infoFr previewFr } {
        variable sPo

        set selList [GetListSelection $listId]
        if { [llength $selList] == 0 } {
            return
        }
        set entry [lindex $selList end]
        # Convert native name back to Unix notation
        set fileName [AbsPath $entry [GetRootDir $listId]]
        if { $sPo(showFileInfo) } {
            poWinInfo UpdateFileInfo $infoFr $fileName true
        } else {
            poWinInfo Clear $infoFr
        }
        if { $sPo(showPreview) } {
            poWinPreview Update $previewFr $fileName
        } else {
            poWinPreview Clear $previewFr
        }
    }

    proc DisplayTwoFileInfo { leftId rightId leftInfoFr rightInfoFr leftPreviewFr rightPreviewFr } {
        DisplayFileInfo $leftId  $leftInfoFr $leftPreviewFr
        DisplayFileInfo $rightId $rightInfoFr $rightPreviewFr
    }

    proc ShowFileInfoWin { { serialize 0 } } {
        variable sPo

        set masterList $sPo(curListbox)
        if { ! [IsListWidget $masterList] } {
            return
        }
        if { [IsDiffListbox $masterList] } {
            ShowTwoFileInfoWin $sPo(diffListL) $sPo(diffListR) $serialize
        } elseif { [IsIdentListbox $masterList] } {
            ShowTwoFileInfoWin $sPo(identListL) $sPo(identListR) $serialize
        } elseif { [IsListWidget $masterList] } {
            ShowOneFileInfoWin $masterList $serialize
        }
    }

    proc FormatListEntry { listId fileName fileSize fileTime } {
        set fullName $fileName
        if { $fileSize < 0 || $fileTime < 0 } {
            if { [file pathtype $fileName] eq "relative" } {
                set fullName [file join [GetRootDir $listId] $fileName]
            }
        }
        if { $fileSize < 0 } {
            set fileSize [file size $fullName]
        }
        if { $fileTime < 0 } {
            set fileTimeStr [clock format [file mtime $fullName] -format "%Y-%m-%d %H:%M:%S"]
        } else {
            set fileTimeStr [clock format $fileTime -format "%Y-%m-%d %H:%M:%S"]
        }
        return [list $fullName $fileSize $fileTimeStr]
    }

    proc SetListEntry { listId ind fileName { fileSize -1 } { fileTime -1 } } {
        variable sPo

        set fullName $fileName
        if { $fileSize < 0 || $fileTime < 0 } {
            if { [file pathtype $fileName] eq "relative" } {
                set fullName [file join [GetRootDir $listId] $fileName]
            }
        }
        if { $fileSize < 0 } {
            set fileSize [file size $fullName]
        }
        if { $fileTime < 0 } {
            set fileTimeStr [clock format [file mtime $fullName] -format "%Y-%m-%d %H:%M:%S"]
        } else {
            set fileTimeStr [clock format $fileTime -format "%Y-%m-%d %H:%M:%S"]
        }
        $listId insert $ind [FormatListEntry $listId $fileName $fileSize $fileTime]
        if { $sPo(markByType) } {
            $listId rowconfigure $ind -foreground [poFileType GetColor $fileName]
        }
    }

    proc GetListSelectionIndices { listId } {
        if { ! [IsListWidget $listId] } {
            return [list]
        }
        return [$listId curselection]
    }

    proc GetListSelection { listId { columnNum 0 } } {
        set indList [GetListSelectionIndices $listId]
        if { [llength $indList] == 0 } {
            return [list]
        }

        foreach ind $indList {
            if { $columnNum < 0 } {
                lappend selItemList [$listId get $ind]
            } else {
                lappend selItemList [lindex [$listId get $ind] $columnNum]
            }
        }
        return $selItemList
    }

    proc GetListEntry { listId index { columnNum 0 } } {
        if { $columnNum < 0 } {
            return [$listId get $index]
        } else {
            return [lindex [$listId get $index] $columnNum]
        }
    }

    proc ShowOneFileInfoWin { listId { serialize 0 } } {
        variable sPo

        set count 0
        set selItemList [GetListSelection $listId]
        foreach item $selItemList {
            # Convert native name back to Unix notation
            set fileName [AbsPath $item [GetRootDir $listId]]

            incr count
            if { $serialize || $count > $sPo(maxShowWin) } {
                set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "Load file info for $fileName ?" \
                  -type yesnocancel -default yes -icon question]
                if { $retVal eq "cancel" } {
                    return
                } elseif { $retVal eq "no" } {
                    continue
                }
            }
            set tw [poWinInfo CreateInfoWin $fileName]
            lappend sPo(infoWinList) $tw
        }
    }

    proc ShowTwoFileInfoWin { leftList rightList { serialize 0 } } {
        variable sPo

        set count 0
        set selItemList1 [GetListSelection $leftList]
        set selItemList2 [GetListSelection $rightList]
        foreach item1 $selItemList1 item2 $selItemList2 {
            set fileName1 [AbsPath $item1 [GetRootDir $leftList]]
            set fileName2 [AbsPath $item2 [GetRootDir $rightList]]

            incr count
            if { $serialize || $count > $sPo(maxShowWin) } {
                set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "Load file info for $fileName1 and $fileName2 ?" \
                  -type yesnocancel -default yes -icon question]
                if { $retVal eq "cancel" } {
                    return
                } elseif { $retVal eq "no" } {
                    continue
                }
            }
            set tw [poWinInfo CreateInfoWin $fileName1 -file $fileName2]
            lappend sPo(infoWinList) $tw
        }
    }

    proc OpenMainContextMenu { masterList slaveList x y } {
        variable sPo
        variable ns

        set w .poDiff:contextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        set numSel [llength [GetListSelectionIndices $masterList]]
        if { $numSel == 0 } {
            set menuTitle "Nothing selected"
        } else {
            set menuTitle "$numSel selected"
        }
        $w add command -label "$menuTitle" -state disabled -background "#303030"

        if { $numSel == 0 } {
            set dir ""
            set side ""
            if { [IsOnlyListbox   $masterList "l"] || \
                 [IsDiffListbox   $masterList "l"] || \
                 [IsIdentListbox  $masterList "l"] || \
                 [IsIgnoreListbox $masterList "l"] } {
                set dir $sPo(dir1)
                set side 1
            } elseif { [IsOnlyListbox   $masterList "r"] || \
                 [IsDiffListbox   $masterList "r"] || \
                 [IsIdentListbox  $masterList "r"] || \
                 [IsIgnoreListbox $masterList "r"] } {
                set dir $sPo(dir2)
                set side 2
            } elseif { [IsSearchListbox $masterList] } {
                 set dir  [GetSearchDir]
                 set side [GetSearchSide]
            }
            if { $dir ne "" && [file isdirectory $dir] } {
                $w add command -label "Open directory" -underline 1 \
                               -command "poExtProg StartFileBrowser $dir"
            } else {
                $w add command -label "Create directory" -underline 1 \
                               -command "${ns}::_CreateDir $dir $side"
            }
            tk_popup $w $x $y
            return
        }

        set convStr ""
        set cpStr   ""
        set mvStr   ""
        set delStr  ""
        if { $sPo(convConfirm) }   { set convStr " ..." }
        if { $sPo(copyConfirm) }   { set cpStr   " ..." }
        if { $sPo(moveConfirm) }   { set mvStr   " ..." }
        if { $sPo(deleteConfirm) } { set delStr  " ..." }

        $w add command -label "Open directory" -underline 1 \
                       -command "${ns}::StartFileBrowser $masterList"
        $w add command -label "File name to clipboard" -underline 0 -accelerator "f" \
                       -command "${ns}::CopyFileNameToClipboard"
        $w add separator

        $w add command -label "Info" -underline 0 -accelerator "i" -command "${ns}::ShowFileInfoWin"
        $w add command -label "Edit" -underline 0 -accelerator "e" -command "${ns}::StartEditor 0"
        if { [poExtProg SupportsAsso] } {
            $w add command -label "Open" -underline 0 -accelerator "o" -command "${ns}::StartAssoc 0"
        }
        $w add command -label "HexDump" -underline 0 -accelerator "h" -command "${ns}::StartHexEditor 0"

        $w add cascade -label "Convert to" -menu $w.conv
        menu $w.conv -tearoff 0
        $w.conv add command -label "Unix (LF) $convStr" \
                            -command "${ns}::ConvertFile $masterList lf"
        $w.conv add command -label "Dos (CRLF) $convStr" \
                            -command "${ns}::ConvertFile $masterList crlf"
        $w.conv add command -label "Mac (CR) $convStr" \
                            -command "${ns}::ConvertFile $masterList cr"

        if { [IsOnlyListbox   $masterList] || \
             [IsIgnoreListbox $masterList] || \
             [IsSearchListbox $masterList] } {
            $w add command -label "Touch" -underline 0 \
                           -command "${ns}::TouchFile $masterList \"\""
        } else {
            $w add cascade -label "Touch" -menu $w.touch
            menu $w.touch -tearoff 0
            $w.touch add command -label "this" \
                                 -command "${ns}::TouchFile $masterList $slaveList false"
            $w.touch add command -label "both" \
                                 -command "${ns}::TouchFile $masterList $slaveList true"
        }

        $w add separator
        $w add command -label "Rename ..." -underline 0 -accelerator "r" \
                       -command "${ns}::AskRenameFile $x $y"
        if { $numSel != 1 } {
            $w entryconfigure end -state disabled
        }

        # Copy and Move are list specific.
        if { [IsOnlyListbox $masterList "l"] } {
            $w add separator
            $w add command -label "Copy to right $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyOnlyFromSide l"
            $w add command -label "Move to right $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveOnlyFromSide l"
            $w add separator
            $w add command -label "Delete $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteOnlyFromSide l" -activebackground "#FC3030"
        } elseif { [IsOnlyListbox $masterList "r"] } {
            $w add separator
            $w add command -label "Copy to left $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyOnlyFromSide r"
            $w add command -label "Move to left $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveOnlyFromSide r"
            $w add separator
            $w add command -label "Delete $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteOnlyFromSide r" -activebackground "#FC3030"
        } elseif { [IsDiffListbox $masterList "l"] } {
            $w add separator
            $w add command -label "Copy to right $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyLeftDiffToRightDiff"
            $w add command -label "Move to right $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveLeftDiffToRightDiff"
            $w add separator
            $w add cascade -label "Delete" -menu $w.del
            menu $w.del  -tearoff 0
            $w.del add command -label "left $delStr" -accelerator "Del" \
                               -command "${ns}::DeleteLeftDiff" -activebackground "#FC3030"
            $w.del add command -label "both $delStr" -accelerator "Shift-Del" \
                               -command "${ns}::DeleteBothDiff" -activebackground "#FC3030"
        } elseif { [IsDiffListbox $masterList "r"] } {
            $w add separator
            $w add command -label "Copy to left $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyRightDiffToLeftDiff"
            $w add command -label "Move to left $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveRightDiffToLeftDiff"
            $w add separator
            $w add cascade -label "Delete" -menu $w.del
            menu $w.del  -tearoff 0
            $w.del add command -label "right $delStr" -accelerator "Del" \
                              -command "${ns}::DeleteRightDiff" -activebackground "#FC3030"
            $w.del add command -label "both $delStr" -accelerator "Shift-Del" \
                               -command "${ns}::DeleteBothDiff" -activebackground "#FC3030"
        } elseif { [IsIdentListbox $masterList "l"] } {
            $w add separator
            $w add command -label "Copy to right $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyLeftIdeToRightIde"
            $w add command -label "Move to right $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveLeftIdeToRightIde"
            $w add separator
            $w add cascade -label "Delete" -menu $w.del
            menu $w.del  -tearoff 0
            $w.del add command -label "left $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteLeftIde" -activebackground "#FC3030"
            $w.del add command -label "both $delStr" \
                               -command "${ns}::DeleteBothIde" -activebackground "#FC3030"
        } elseif { [IsIdentListbox $masterList "r"] } {
            $w add separator
            $w add command -label "Copy to left $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyRightIdeToLeftIde"
            $w add command -label "Move to left $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveRightIdeToLeftIde"
            $w add separator
            $w add cascade -label "Delete" -menu $w.del
            menu $w.del  -tearoff 0
            $w.del add command -label "right $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteRightIde" -activebackground "#FC3030"
            $w.del add command -label "both $delStr" \
                               -command "${ns}::DeleteBothIde" -activebackground "#FC3030"
        } elseif { [IsIgnoreListbox $masterList "l"] } {
            $w add separator
            $w add command -label "Copy to right $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyLeftIgnToRightIgn"
            $w add command -label "Move to right $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveLeftIgnToRightIgn"
            $w add separator
            $w add command -label "Delete $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteLeftIgn" -activebackground "#FC3030"
        } elseif { [IsIgnoreListbox $masterList "r"] } {
            $w add separator
            $w add command -label "Copy to left $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopyRightIgnToLeftIgn"
            $w add command -label "Move to left $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveRightIgnToLeftIgn"
            $w add separator
            $w add command -label "Delete $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteRightIgn" -activebackground "#FC3030"
        } elseif { [IsSearchListbox $masterList] } {
            set side      [GetSearchSide]
            set otherSide [GetSearchOtherSide true]
            $w add separator
            $w add command -label "Copy to $otherSide $cpStr" -underline 0 -accelerator "c" \
                           -command "${ns}::CopySearchFromSide $side"
            $w add command -label "Move to $otherSide $mvStr" -underline 0 -accelerator "m" \
                           -command "${ns}::MoveSearchFromSide $side"
            $w add separator
            $w add command -label "Delete $delStr" -accelerator "Del" \
                           -command "${ns}::DeleteSearchFromSide $side" -activebackground "#FC3030"
        }

        if { [IsIdentListbox $masterList] } {
            $w add separator
            $w add command -label "Diff" -accelerator "d" \
                    -command "${ns}::StartGUIDiff $sPo(identListL) $sPo(identListR)"
            $w add command -label "HexDump Diff" \
                   -command "${ns}::StartGUIDiff $sPo(identListL) $sPo(identListR) true"
            if { $numSel != 1 } {
                $w entryconfigure end -state disabled
            }
        }
        if { [IsDiffListbox $masterList] } {
            $w add separator
            $w add command -label "Diff" -accelerator "d" \
                   -command "${ns}::StartGUIDiff $sPo(diffListL) $sPo(diffListR)"
            $w add command -label "HexDump Diff" \
                   -command "${ns}::StartGUIDiff $sPo(diffListL) $sPo(diffListR) true"
            if { $numSel != 1 } {
                $w entryconfigure end -state disabled
            }
        }

        $w add separator
        $w add command -label "Mark as left diff file ..." -underline 0 -accelerator "1" \
                       -command "${ns}::SetDiffFile 1"
        $w add command -label "Mark as right diff file ..." -underline 0 -accelerator "2" \
                       -command "${ns}::SetDiffFile 2"
        tk_popup $w $x $y
    }

    proc ChooseDirs { { num 1 } } {
        variable sPo

        if { $num == 1 } {
            set str "left"
        } else {
            set str "right"
        }
        set dirStr "dir$num"
        set tmpDir [poWin ChooseDir "Select $str directory" $sPo($dirStr)]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            SetDirectory $tmpDir $num
        }
    }

    proc SwitchDirs { startDiff } {
        variable sPo

        set dir1 $sPo(dir1)
        set dir2 $sPo(dir2)
        SetDirectory $dir2 1
        SetDirectory $dir1 2
        if { $startDiff } {
            TimeDiffDir
        }
    }

    proc StopSearch { { msg "Action stopped by user" } } {
        variable sPo

        WriteSearchInfoStr $msg "Cancel"
        set sPo(stopSearch) 1
        poExtProg StopDump
        poWin ToggleSwitchableWidgets "Search" true
    }

    proc StopScan { { msg "Action stopped by user" } } {
        variable sPo

        WriteMainInfoStr $msg "Cancel"
        set sPo(stopScan) 1
        poExtProg StopDump
        poWin ToggleSwitchableWidgets "Diff" true
    }

    proc DiffDir {} {
        variable sPo

        set sPo(stopScan) 0
        ClearFileLists
        ClearDelIndLists

        # The following counter variables are needed only for optSync mode.
        set sPo(numFilesCopied)  0
        set sPo(numFilesDeleted) 0

        $sPo(tw) configure -cursor watch
        ClearTableContents
        poAppearance AddToRecentDirList $sPo(dir1)
        poAppearance AddToRecentDirList $sPo(dir2)

        InvalidateCache
        set sPo(numDirsScanned) 0
        UpdateFileCount
        if { $sPo(appWindowClosed) } {
            return
        }
        poWin InitStatusProgress $sPo(StatusWidget,diff) 50 "indeterminate"
        if { $sPo(appWindowClosed) } {
            return
        }
        ScanRecursive "diff" $sPo(dir1) $sPo(dir1) ignLogDirL ignLogFileL "l"
        if { $sPo(appWindowClosed) } {
            return
        }
        ScanRecursive "diff" $sPo(dir2) $sPo(dir2) ignLogDirR ignLogFileR "r"
        if { $sPo(appWindowClosed) } {
            return
        }
        DiffFileLists
        if { $sPo(appWindowClosed) } {
            return
        }

        $sPo(tw) configure -cursor arrow
        if { $sPo(stopScan) } {
            set infoStr "Diff cancelled"
            WriteMainInfoStr $infoStr "Cancel"
        } else {
            set infoStr "Diff finished"
            WriteMainInfoStr $infoStr "Ok"
        }
        if { $sPo(readErrors) } {
            set infoStr [format "%s (%d unreadable files or directories)." \
                         $infoStr $sPo(readErrors)]
            WriteMainInfoStr $infoStr "Error"
        }
        poWin UpdateStatusProgress $sPo(StatusWidget,diff) 0
        UpdateFileCount
        if { $sPo(readErrors) > 0 } {
            ShowErrorLog
        }
    }

    proc UpdateFileCount {} {
        variable sPo
        variable sDelIndList

        set strL [format "Left directory only (%d files)"  [expr { [$sPo(onlyListL) index end] - [llength $sDelIndList($sPo(onlyListL))] }]]
        set strR [format "Right directory only (%d files)" [expr { [$sPo(onlyListR) index end] - [llength $sDelIndList($sPo(onlyListR))] }]]
        poWin SetScrolledTitle $sPo(onlyListL) $strL
        poWin SetScrolledTitle $sPo(onlyListR) $strR

        set strL [format "Different left (%d files)"  [expr { [$sPo(diffListL) index end] - [llength $sDelIndList($sPo(diffListL))] }]]
        set strR [format "Different right (%d files)" [expr { [$sPo(diffListR) index end] - [llength $sDelIndList($sPo(diffListR))] }]]
        poWin SetSyncTitle $sPo(diffListR) $strL $strR

        if { [info exists sPo(ignListL)] && [IsListWidget $sPo(ignListL)] } {
            set strL [format "Ignored left (%d files)"  [expr { [$sPo(ignListL) index end]  - [llength $sDelIndList($sPo(ignListL))] }]]
            set strR [format "Ignored right (%d files)" [expr { [$sPo(ignListR) index end]  - [llength $sDelIndList($sPo(ignListR))] }]]
            poWin SetScrolledTitle $sPo(ignListL) $strL
            poWin SetScrolledTitle $sPo(ignListR) $strR
        }

        if { [info exists sPo(identListL)] && [IsListWidget $sPo(identListL)] } {
            set strL [format "Identical left (%d files)"  [expr { [$sPo(identListL) index end]  - [llength $sDelIndList($sPo(identListL))] }]]
            set strR [format "Identical right (%d files)" [expr { [$sPo(identListR) index end]  - [llength $sDelIndList($sPo(identListR))] }]]
            poWin SetScrolledTitle $sPo(identListL) $strL
            poWin SetScrolledTitle $sPo(identListR) $strR
        }
    }

    proc UpdateMainTitle { { execUpdate true } } {
        variable sPo

        set dir1 $sPo(dir1)
        set dir2 $sPo(dir2)
        if { $dir1 eq "" } {
            set dir1 "No left directory"
        }
        if { $dir2 eq "" } {
            set dir2 "No right directory"
        }
        wm title $sPo(tw) [format "%s - %s (%s <--> %s)" "poApps" [poApps GetAppDescription $sPo(appName)] $dir1 $dir2]
        if { $execUpdate } {
            update
        }
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[Directory1\] \[Directory2\]\n"
        append msg "\n"
        append msg "Load directories for comparison. If no option is specified, the directory\n"
        append msg "pathes are loaded in a graphical user interface for interactive manipulation.\n"
        append msg "\n"
        append msg "Batch processing information:\n"
        append msg "  An exit status of 0 indicates identical directories.\n"
        append msg "  An exit status of 1 indicates differing directories.\n"
        append msg "  Any other exit status indicates an error when comparing.\n"
        append msg "  On Windows the exit status is stored in ERRORLEVEL.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--diff              : Start comparison of directories after startup.\n"
        append msg "--session <string>  : Use specified session name or session index.\n"
        append msg "                      Session indices start at 1.\n"
        append msg "--search <string>   : Search for specified string in \"Directory1\".\n"
        append msg "--filematch <string>: Search in files matching given glob-style pattern.\n"
        append msg "--filetype <string> : Search in files matching given file type.\n"
        append msg "                      Valid types: binary image text dos unix html script xml\n"
        append msg "                      or any of the image formats (see option --helpimg).\n"
        append msg "--convert <string>  : Convert line-endings in found files.\n"
        append msg "                      Available conversion strings: lf, crlf, cr.\n"
        append msg "--sync              : Synchronize specified directories and exit.\n"
        append msg "                      \"Directory1\" acts as server, \"Directory2\" acts as client,\n"
        append msg "                      i.e. files newer or available only in \"Directory1\" are\n"
        append msg "                      copied to \"Directory2\".\n"
        append msg "--syncdelete        : Synchronize as with option \"--sync\", but additionally\n"
        append msg "                      delete files available only in \"Directory2\".\n"
        append msg "--copydate <int>    : Copy all files of left directory changed in the last\n"
        append msg "                      days into right directory.\n"
        append msg "--compare <string>  : Compare files using specified mode.\n"
        append msg "                      Possible modes are: \"exist\", \"size\", \"date\", \"content\".\n"
        append msg "                      Default: [poMisc GetCmpModeString $sPo(cmpMode)].\n"
        append msg "--immediate <bool>  : Update table contents immediately. Slow for large directories.\n"
        append msg "                      Default: $sPo(immediateUpdate).\n"
        append msg "--marknewer <bool>  : Mark newer files with color $sPo(fileMarkColor).\n"
        append msg "                      Default: $sPo(markNewer).\n"
        append msg "--marktypes <bool>  : Mark files by type.\n"
        append msg "                      Default: $sPo(markByType).\n"
        append msg "--ignoreeol <bool>  : Ignore EOL characters when comparing in \"content\" mode.\n"
        append msg "                      Default: $sPo(ignEolChar).\n"
        append msg "--ignorehour <bool> : Ignore 1 hour differences when comparing in \"date\" mode.\n"
        append msg "                      Default: $sPo(ignOneHour).\n"
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

    proc ClearSearchTabs {} {
        variable sSearch

        $sSearch(textId) delete 1.0 end
        $sSearch(textId) edit modified false
        poWinPreview Clear $sSearch(previewId)
        poWinInfo    Clear $sSearch(infoId)
    }

    proc HiliteSearchDir { { onOff 1 } } {
        variable sPo
        variable sSearch

        $sPo(onlyListL) configure -bg white
        $sPo(onlyListR) configure -bg white
        $sPo(diffListL) configure -bg white
        $sPo(diffListR) configure -bg white
        if { !$onOff } {
            return
        }
        SetSearchWinTitle
        # Clear search tablelist and preview windows
        $sPo(searchList) delete 0 end
        ClearSearchTabs

        if { [GetSearchSide] eq "l" } {
            $sPo(onlyListL) configure -bg $sPo(sideMarkColor)
            $sPo(diffListL) configure -bg $sPo(sideMarkColor)
        } else {
            $sPo(onlyListR) configure -bg $sPo(sideMarkColor)
            $sPo(diffListR) configure -bg $sPo(sideMarkColor)
        }
    }

    proc ShowFileCont { tableId notebookId textId previewId infoId forceLoad } {
        variable sPo
        variable sSearch
        variable sCurFile

        if { [poExtProg HasTextWidgetChanged $textId] } {
            poExtProg CloseSimpleTextEdit $textId
            focus $sSearch(tw)
        }

        set selList [GetListSelection $tableId]
        if { [llength $selList] == 0 } {
            return
        }
        set fileName [lindex $selList 0]
        set searchDir [GetSearchDir]
        set fileName [AbsPath $fileName $searchDir]

        set selTab [GetSelTabIndex $notebookId]
        # Tab order:
        # 0: Edit
        # 1: Preview
        # 2: FileInfo
        if { ! $forceLoad } {
            if { [info exists sCurFile($selTab)] && $sCurFile($selTab) eq $fileName } {
                return
            }
        }
        switch -exact -- $selTab {
            "0" {
                set isBinary [poType IsBinary $fileName]
                if { !$isBinary } {
                    poExtProg LoadFileIntoTextWidget $textId $fileName
                } else {
                    poExtProg DumpFileIntoTextWidget $textId $fileName -update true
                }

                set sSearch(indices) [list]

                set markColor $sPo(fileMarkColor)
                set indexIn 1.0
                set countIn 0
                set i       0
                if { $sPo(curSearchPatt) ne "" } {
                    set quotedSearch [poMisc QuoteSearchPattern $sPo(curSearchPatt) \
                                      $sPo(searchMode) $sPo(searchWord)]
                    while { 1 } {
                        if { $sPo(searchIgnCase) } {
                            set indexOut [$textId search -count countOut -regexp -nocase -- \
                                          $quotedSearch "$indexIn + $countIn chars" end]
                        } else {
                            set indexOut [$textId search -count countOut -regexp -- \
                                          $quotedSearch "$indexIn + $countIn chars" end]
                        }
                        if { $indexOut eq "" } {
                            break
                        }

                        lappend sSearch(indices)  $indexOut
                        $textId tag add "result"  $indexOut "$indexOut + $countOut chars"
                        $textId tag add "found$i" $indexOut "$indexOut + $countOut chars"

                        set indexIn $indexOut
                        set countIn $countOut
                        incr i
                    }
                }
                $textId tag configure "result" -background $markColor
                set sSearch(curIndex) 0
                ShowResult 0
            }
            "1" {
                poWinPreview Update $previewId $fileName
            }
            "2" {
                poWinInfo UpdateFileInfo $infoId $fileName true
            }
            default {
                error "Fatal error: Unknown tab index $selTab"
            }
        }
        set sCurFile($selTab) $fileName
    }

    proc SetSearchButtonStates { state } {
        variable sSearch

        $sSearch(btn,first) configure -state $state
        $sSearch(btn,last)  configure -state $state
        $sSearch(btn,prev)  configure -state $state
        $sSearch(btn,next)  configure -state $state
    }

    proc _UseMarkedText { comboName } {
        variable sPo
        variable sSearch

        tk_textCopy $sSearch(textId)
        $sPo($comboName) set [clipboard get]
    }

    proc ShowResult { ind } {
        variable sPo
        variable sSearch

        if { ! [info exists sSearch(curIndex)] || \
             [llength $sSearch(indices)] == 0 } {
            return
        }

        set curIndex $sSearch(curIndex)
        $sSearch(textId) tag configure "found$curIndex" \
                         -background $sPo(fileMarkColor)

        if { $ind == -1 || $ind == 1 } {
            set curIndex [expr $curIndex + $ind]
            set curIndex [poMisc Max $curIndex 0]
            set curIndex [poMisc Min $curIndex \
                                        [expr [llength $sSearch(indices)] -1]]
        } elseif { $ind eq "end" } {
            set curIndex [expr [llength $sSearch(indices)] -1]
        } else {
            set curIndex $ind
        }
        $sSearch(textId) tag configure "found$curIndex" -background "yellow"
        $sSearch(textId) see [lindex $sSearch(indices) $curIndex]

        set sSearch(curIndex) $curIndex
        $sSearch(textId) tag add sel [lindex $sSearch(indices) $curIndex]
        $sSearch(textId) mark set insert [lindex $sSearch(indices) $curIndex]

        SetSearchButtonStates "normal"
        if { $curIndex == 0 } {
            $sSearch(btn,first) configure -state disabled
            $sSearch(btn,prev)  configure -state disabled
        }
        if { $curIndex == [expr [llength $sSearch(indices)] -1] } {
            $sSearch(btn,last) configure -state disabled
            $sSearch(btn,next)  configure -state disabled
        }
    }

    proc UpdateCombo { cb typeList showInd } {
        $cb configure -values $typeList
        $cb current $showInd
    }

    proc ComboCB { comboId type } {
        variable sPo

        set match [$comboId get]
        if { $type eq "filePatt" } {
            set typeMatch [poFileType GetTypeMatches $match]
            if { [llength $typeMatch] != 0 } {
                set match $typeMatch
            }
        }
        set sPo($type) $match
    }

    proc GetSelTabIndex { notebookId } {
        set curTab [$notebookId select]
        set tabInd [lsearch -exact [$notebookId tabs] $curTab]
        return $tabInd
    }

    proc ToggleSearchTabs { notebookId dir } {
        set tabInd [GetSelTabIndex $notebookId]
        set numTabs [$notebookId index end]
        $notebookId select [expr { ($tabInd + $dir) % $numTabs }]
    }

    proc SetSearchWinTitle {} {
        variable sPo

        set searchDir $sPo(dir$sPo(searchDir))
        set title "Search window ($searchDir)"
        if { ! [file isdirectory $searchDir] } {
            append title " Not existent"
        }
        wm title $sPo(searchWin,name) $title
    }

    proc IsSearchWinOpen {} {
        variable sPo

        if { [info exists sPo(searchWin,name)] && [winfo exists $sPo(searchWin,name)] } {
            return true
        } else {
            return false
        }
    }

    proc UpdateSearchWin {} {
        if { [IsSearchWinOpen] } {
            ShowSearchWin
            SetSearchWinTitle
        }
    }

    proc _SetComboCaseSearch {} {
        variable sPo

        ttk::combobox::CaseSensitiveSearch [expr ! $sPo(searchIgnCase)]
        _SetTextWidgetOpts
    }

    proc _SetTextWidgetOpts {} {
        variable sPo
        variable sSearch

        poExtProg SetTextWidgetSearchOpts   $sSearch(textId) $sPo(searchIgnCase) $sPo(searchWord)
        poExtProg SetTextWidgetSearchString $sSearch(textId) $sPo(searchPatt)
    }

    proc _FileSaved { fileName } {
        WriteSearchInfoStr "Saved $fileName" "Ok"
    }

    proc ShowSearchWin { { doReplace false } } {
        variable sPo
        variable ns
        variable sSearch

        set tw .poDiff_searchWin
        set sPo(searchWin,name) $tw

        set sSearch(tw)       $tw
        set sSearch(numFiles) 0

        if { [winfo exists $tw] } {
            if { [poApps GetHideWindow] } {
                wm withdraw $tw
            } else {
                HiliteSearchDir
                poWin Raise $tw
            }
            set earlyReturn true
        } else {
            toplevel $tw
            wm resizable $tw true true
            set earlyReturn false
            wm geometry $tw [format "%dx%d+%d+%d" \
                             $sPo(searchWin,w) $sPo(searchWin,h) \
                             $sPo(searchWin,x) $sPo(searchWin,y)]
        }

        if { $earlyReturn } {
            return
        }

        ttk::frame $tw.toolfr1 -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.toolfr2
        ttk::frame $tw.infofr
        ttk::frame $tw.statusfr -relief sunken -borderwidth 1
        grid $tw.toolfr1  -row 0 -column 0 -sticky nswe
        grid $tw.toolfr2  -row 1 -column 0 -sticky nswe
        grid $tw.infofr   -row 2 -column 0 -sticky nswe
        grid $tw.statusfr -row 3 -column 0 -sticky nswe
        grid rowconfigure $tw 2 -weight 1
        grid columnconfigure $tw 0 -weight 1

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget,search) [poWin CreateStatusWidget $tw.statusfr true]

        ttk::frame $tw.infofr.fr
        pack $tw.infofr.fr -expand 1 -fill both

        # Create a pane with two frames:
        # The top frame holds the tablelist with search results.
        # The bottom frame holds a notebook with edit, FileInfo and preview tabs.
        set sPo(searchPaneWin) $tw.infofr.fr.pane
        ttk::panedwindow $sPo(searchPaneWin) -orient vertical
        pack $sPo(searchPaneWin) -side top -expand 1 -fill both

        set topFr $sPo(searchPaneWin).topFr
        set botFr $sPo(searchPaneWin).botFr

        ttk::frame $topFr
        ttk::frame $botFr
        pack $topFr -expand 1 -fill both
        pack $botFr -expand 1 -fill both

        set nbId $botFr.nb
        ttk::notebook $nbId -style Hori.TNotebook
        pack $nbId -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nbId

        set editFr    $nbId.editFr
        set previewFr $nbId.previewFr
        set infoFr    $nbId.infoFr
        ttk::frame $editFr
        ttk::frame $previewFr
        ttk::frame $infoFr
        pack $editFr    -expand 1 -fill both
        pack $previewFr -expand 1 -fill both
        pack $infoFr    -expand 1 -fill both

        # If changing order of tabs, also change switch statement in ShowFileCont.
        $nbId add $editFr    -text "Edit"
        $nbId add $previewFr -text "Preview"
        $nbId add $infoFr    -text "File Info"

        # Create and fill the first tool frame containing command buttons.
        set toolfr1 $tw.toolfr1
        poToolbar New $toolfr1
        poToolbar AddGroup $toolfr1

        set sSearch(btn,first) [poToolbar AddButton $toolfr1 [::poBmpData::top] \
                  "${ns}::ShowResult 0" "Go to first occurence"]
        set sSearch(btn,prev) [poToolbar AddButton $toolfr1 [::poBmpData::up] \
                  "${ns}::ShowResult -1" "Go to previous occurence (b)"]
        set sSearch(btn,next) [poToolbar AddButton $toolfr1 [::poBmpData::down] \
                  "${ns}::ShowResult 1" "Go to next occurence (n)"]
        set sSearch(btn,last) [poToolbar AddButton $toolfr1 [::poBmpData::bottom] \
                  "${ns}::ShowResult end" "Go to last occurence"]

        poToolbar AddGroup $toolfr1
        poToolbar AddRadioButton $toolfr1 [::poBmpData::left] \
                  ${ns}::HiliteSearchDir "Search in left directory" \
                  -variable ${ns}::sPo(searchDir) -value 1
        poToolbar AddRadioButton $toolfr1 [::poBmpData::right] \
                  ${ns}::HiliteSearchDir "Search in right directory" \
                  -variable ${ns}::sPo(searchDir) -value 2
        poToolbar AddCheckButton $toolfr1 [::poBmpData::searchcase] \
                  "${ns}::_SetComboCaseSearch" "Search case insensitive" \
                  -variable ${ns}::sPo(searchIgnCase)
        poToolbar AddCheckButton $toolfr1 [::poBmpData::searchword] \
                  "${ns}::_SetTextWidgetOpts" "Match words only" -variable ${ns}::sPo(searchWord)

        # OPA TODO Implement search modes match and regexp
        # set searchModes [list "exact" "match" "regexp"]
        set searchModes [list "exact"]
        poToolbar AddCombobox $toolfr1 sPo(searchMode) "Search mode" \
                  -values $searchModes -state readonly -width 7

        poToolbar AddGroup $toolfr1
        set leftBtn  [poToolbar AddButton $toolfr1 [::poBmpData::searchleft] \
                     "${ns}::TimeSearchDir searchPatt" "Find search pattern (F3)"]
        set rightBtn [poToolbar AddButton $toolfr1 [::poBmpData::searchright] \
                     "${ns}::TimeSearchDir replacePatt" "Find replace pattern (Shift-F3)"]

        poToolbar AddGroup $toolfr1
        set replaceBtn [poToolbar AddButton $toolfr1 [::poBmpData::rename] \
                       "${ns}::ReplaceDir" "Perform replacement. This operation cannot be undone."]

        poWin AddToSwitchableWidgets "Search" $leftBtn $rightBtn $replaceBtn

        poToolbar AddGroup $toolfr1
        poToolbar AddButton $toolfr1 [::poBmpData::halt "red"] \
                  ${ns}::StopSearch "Stop current search job (Esc)"

        SetSearchButtonStates "disabled"

        bind $tw <Control-Key-F5> [list ${ns}::ShowSpecificSettWin "Diff"]

        # Check, if the current search and replace patterns are contained in the
        # pattern list. If not, insert them at the list begin.
        set indReplace [lsearch -exact $sPo(searchPattList) $sPo(replacePatt)]
        if { $indReplace < 0 } {
            set sPo(searchPattList) [linsert $sPo(searchPattList) 0 $sPo(replacePatt)]
            set indReplace 0
        }
        set indSearch [lsearch -exact $sPo(searchPattList) $sPo(searchPatt)]
        if { $indSearch < 0 } {
            set sPo(searchPattList) [linsert $sPo(searchPattList) 0 $sPo(searchPatt)]
            set indSearch 0
        }

        # Create and fill the second tool frame containing search options.
        set toolfr2 $tw.toolfr2
        poToolbar New $toolfr2
        poToolbar AddGroup $toolfr2

        poToolbar AddLabel $toolfr2 "Search:" ""
        set sPo(searchCombo) [poToolbar AddCombobox $toolfr2 ${ns}::sPo(searchPatt) "" -width 15]
        UpdateCombo $sPo(searchCombo) $sPo(searchPattList) $indSearch
        poToolhelp AddBinding $sPo(searchCombo) "Use F4 to copy selected text"

        poToolbar AddLabel $toolfr2 "Replace:" ""
        set sPo(replaceCombo) [poToolbar AddCombobox $toolfr2 ${ns}::sPo(replacePatt) "" -width 15]
        UpdateCombo $sPo(replaceCombo) $sPo(searchPattList) $indReplace
        poToolhelp AddBinding $sPo(replaceCombo) "Use Shift-F4 to copy selected text"

        poToolbar AddLabel $toolfr2 "File match:" ""
        set fileMatchList [list $sPo(filePatt)]
        foreach patt [poFileType GetTypeList] {
            lappend fileMatchList $patt
        }
        set sPo(fileMatchCombo) [poToolbar AddCombobox $toolfr2 ${ns}::sPo(filePatt) "" -width 15]
        UpdateCombo $sPo(fileMatchCombo) $fileMatchList 0
        bind $sPo(fileMatchCombo) <<ComboboxSelected>> "${ns}::ComboCB %W filePatt"
        bind $sPo(fileMatchCombo) <Any-KeyRelease>     "${ns}::ComboCB %W filePatt"
        pack $sPo(fileMatchCombo) -side left

        set sPo(fileTypeList) [list "" binary image text dos unix html script xml]
        foreach imgFmt [poImgType GetFmtList] {
            lappend sPo(fileTypeList) $imgFmt
        }
        set indFileType [lsearch -exact -nocase $sPo(fileTypeList) $sPo(fileType)]
        if { $indFileType< 0 } {
            set indFileType 0
        }
        poToolbar AddLabel $toolfr2 "File type:" ""
        set sPo(fileTypeCombo) [poToolbar AddCombobox $toolfr2 ${ns}::sPo(fileType) "" \
                                -width 15 -state readonly]
        UpdateCombo $sPo(fileTypeCombo) $sPo(fileTypeList) $indFileType

        # Add group for selecting dates and comparison modes.
        set fr [poToolbar AddGroup $toolfr2]
        set sPo(dateCmpCombo) [poWinDateSelect CreateDateSelect $fr]
        poWinDateSelect SetCompareMode $sPo(dateCmpCombo) $sPo(dateMatch)
        poWinDateSelect SetDate        $sPo(dateCmpCombo) $sPo(dateRef)

        # Create and configure the tablelist for displaying search results.
        set tableId [poWin CreateScrolledTablelist $topFr true "Search results" \
                    -columns {50 "File name"         "left"
                               0 "File size"         "center"
                               0 "Modification time" "center"
                               0 "Occurences"        "center" } \
                    -exportselection false \
                    -stretch 0 \
                    -stripebackground [poAppearance GetStripeColor] \
                    -selectmode extended \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators true]
        $tableId columnconfigure 1 -sortmode integer
        $tableId columnconfigure 3 -sortmode integer
        $tableId columnconfigure 0 -align $sPo(columnAlign)
        set sPo(searchList) $tableId

        # Create the edit, preview and FileInfo widgets.
        set textId [poExtProg ShowSimpleTextEdit "" $editFr true \
                    -width 80 -height 20 -wrap none -exportselection true \
                    -undo true -font [poWin GetFixedFont]]
        set previewId [poWinPreview Create $previewFr ""]
        set infoId    [poWinInfo Create $infoFr ""]
        bind $textId <<SimpleTextEditSaved>> "${ns}::_FileSaved %d"

        set sSearch(textId)    $textId
        set sSearch(previewId) $previewId
        set sSearch(infoId)    $infoId

        # Now add the top and bottom frames to the pane.
        $sPo(searchPaneWin) add $topFr
        $sPo(searchPaneWin) add $botFr

        if { ! [poApps GetHideWindow] } {
            update
        }
        $sPo(searchPaneWin) sashpos 0 $sPo(searchSashY)

        # Add bindings to the search results tablelist.
        set bodyTag [$tableId bodytag]

        bind $bodyTag <ButtonRelease-1>  "${ns}::ShowFileCont $tableId $nbId $textId $previewId $infoId true"
        bind $bodyTag <KeyRelease-Up>    "${ns}::ShowFileCont $tableId $nbId $textId $previewId $infoId true"
        bind $bodyTag <KeyRelease-Down>  "${ns}::ShowFileCont $tableId $nbId $textId $previewId $infoId true"
        bind $bodyTag <KeyRelease-Left>  "${ns}::ToggleSearchTabs $nbId -1"
        bind $bodyTag <KeyRelease-Right> "${ns}::ToggleSearchTabs $nbId  1"
        
        bind $nbId <<NotebookTabChanged>> "${ns}::ShowFileCont $tableId $nbId $textId $previewId $infoId false"

        bind $bodyTag <<RightButtonPress>> \
            [list ${ns}::OpenMainContextMenu $tableId "" %X %Y]

        bind $bodyTag <1> "+${ns}::SelectListbox $tableId"
        bind $bodyTag <Control-a> ${ns}::SelectAll
        bind $bodyTag <Key-e> "${ns}::StartEditor 0"
        bind $bodyTag <Key-E> "${ns}::StartEditor 1"
        bind $bodyTag <Key-h> "${ns}::StartHexEditor 0"
        bind $bodyTag <Key-H> "${ns}::StartHexEditor 1"
        bind $bodyTag <Key-p> "${ns}::StartFileBrowser $tableId"
        if { [poExtProg SupportsAsso] } {
            bind $bodyTag <Key-o> "${ns}::StartAssoc 0"
            bind $bodyTag <Key-O> "${ns}::StartAssoc 1"
            if { [poWin SupportsAppKey] } {
                bind $bodyTag <App> [list ${ns}::OpenMainContextMenu $tableId "" %X %Y]
            }
        }
        bind $bodyTag <Key-i>  "${ns}::ShowFileInfoWin "
        bind $bodyTag <Key-I>  "${ns}::ShowFileInfoWin 1"
        bind $bodyTag <Key-r>  "${ns}::AskRenameFile %X %Y"
        bind $bodyTag <Key-F2> "${ns}::AskRenameFile %X %Y"

        bind $bodyTag <Delete> "${ns}::DeleteSearchFromSide"
        bind $bodyTag <Key-f>  "${ns}::CopyFileNameToClipboard"
        bind $bodyTag <Key-c>  "${ns}::CopySearchFromSide"
        bind $bodyTag <Key-m>  "${ns}::MoveSearchFromSide"

        bind $bodyTag <Key-b>  "${ns}::ShowResult -1"
        bind $bodyTag <Key-n>  "${ns}::ShowResult  1"

        bind $sPo(searchCombo) <Key-Return>   "${ns}::TimeSearchDir searchPatt"
        bind $tw               <Key-F3>       "${ns}::TimeSearchDir searchPatt"
        bind $tw               <Shift-Key-F3> "${ns}::TimeSearchDir replacePatt"

        bind $tw <Escape>       "${ns}::StopSearch"

        bind $tw <Key-F4>       "${ns}::_UseMarkedText searchCombo"
        bind $tw <Shift-Key-F4> "${ns}::_UseMarkedText replaceCombo"

        wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseSearchWin"
        bind $tw <Control-w> "${ns}::CloseSearchWin"

        bind $bodyTag <Key-1> "${ns}::SetDiffFile 1"
        bind $bodyTag <Key-2> "${ns}::SetDiffFile 2"
        bind $tw <Key-F10>    "${ns}::SetDiffFile -1"
        bind $tw <Control-d>   ${ns}::DiffFiles

        HiliteSearchDir

        # Workaround for preview tab to get correct size of preview text widget.
        $nbId select 1
        $nbId select 0

        _SetComboCaseSearch

        focus $tw
        if { [poApps GetHideWindow] } {
            wm withdraw $tw
        }
    }

    proc CloseSearchWin {} {
        variable sPo
        variable sSearch

        if { [info exists sSearch(tw)] && [winfo exists $sSearch(tw)] } {
            StopSearch
            set sPo(dateMatch) [poWinDateSelect GetCompareMode $sPo(dateCmpCombo)]
            set sPo(dateRef)   [poWinDateSelect GetDate        $sPo(dateCmpCombo)]
            OKSettingsWin $sSearch(tw)
        }
    }

    proc AddToSearchLog { doReplace fileName numHits } {
        variable sPo
        variable sSearch

        incr sSearch(numFiles)

        set fileSize [file size $fileName]
        set fileTime [clock format [file mtime $fileName] -format "%Y-%m-%d %H:%M:%S"]
        if { $sPo(relPathes) } {
            set searchDir [GetSearchDir]
            set fileName [AbsToRel $fileName $searchDir]
        }
        $sPo(searchList) insert end [list $fileName $fileSize $fileTime $numHits]
        if { $sPo(markByType) } {
            $sPo(searchList) rowconfigure end -foreground [poFileType GetColor $fileName]
        }
    }

    proc SearchDir { searchPatt } {
        variable sPo
        variable sSearch

        set searchDir [GetSearchDir]
        if { [string length $searchDir] == 0 } {
            tk_messageBox -message "No search directory specified." \
                          -type ok -icon warning
            return
        }
        if { ! [file isdirectory $searchDir] } {
            tk_messageBox -message "Search directory not existent." \
                          -type ok -icon warning
            return
        }

        ShowSearchWin false

        set sPo(stopSearch)  0
        set sPo(errorLog)    {}
        set sPo(readErrors)  0

        $sPo(tw) configure -cursor watch
        poWin ToggleSwitchableWidgets "Search" false

        InvalidateCache
        set sPo(numDirsScanned) 0
        poWin InitStatusProgress $sPo(StatusWidget,search) 50 "indeterminate"
        ScanRecursive "search" $searchDir $searchDir ignLogDirL ignLogFileL [GetSearchSide]
        SearchFileList [GetSearchSide] $searchDir $searchPatt
        $sPo(tw) configure -cursor arrow
        poWin ToggleSwitchableWidgets "Search" true
        set infoStr "Search "
        if { $sPo(stopSearch) } {
            append infoStr "cancelled."
            WriteSearchInfoStr $infoStr "Cancel"
        } else {
            append infoStr "found $sSearch(numFiles) files."
            WriteSearchInfoStr $infoStr "Ok"
            poWin SetScrolledTitle $sPo(searchList) "Search results (Found $sSearch(numFiles) files)"
        }
        if { $sPo(readErrors) } {
            set infoStr [format "%s (%d unreadable files or directories)." \
                         $infoStr $sPo(readErrors)]
            WriteSearchInfoStr $infoStr "Error"
        }
        poWin UpdateStatusProgress $sPo(StatusWidget,search) 0
        if { $sPo(readErrors) > 0 } {
            ShowErrorLog
        }
    }

    proc ScanRecursive { widgetName srcDir rootDir ignDirList ignFileList side } {
        variable sPo
        variable sCacheLeft
        variable sCacheRight
        variable sFileListLeft
        variable sFileListRight

        set showHiddenDirs  [expr ! $sPo(ignHiddenDirs)]
        set showHiddenFiles [expr ! $sPo(ignHiddenFiles)]
        if { $side eq "l" } {
            set numSide 0
        } else {
            set numSide 1
        }

        set retVal [catch { cd $srcDir } ]
        if { $retVal } {
            lappend sPo(errorLog) "Could not read directory \"$srcDir\""
            incr sPo(readErrors)
        }
        WriteInfoStr $widgetName "Scanning directory $srcDir ..." "Watch"
        poWin UpdateStatusProgress $sPo(StatusWidget,$widgetName) $sPo(numDirsScanned)
        if { $sPo(stopScan) && $widgetName eq "diff" } {
            return
        }
        if { $sPo(stopSearch) && $widgetName eq "search" } {
            return
        }
        set catchVal [catch {poMisc GetDirsAndFiles $srcDir \
                                    -nocomplain false \
                                    -showhiddendirs $showHiddenDirs \
                                    -showhiddenfiles $showHiddenFiles } dirCont]
        if { $catchVal } {
            lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
            incr sPo(readErrors)
        } else {
	    set dirList  [lsort -dictionary [lindex $dirCont 0]]
	    set fileList [lsort -dictionary [lindex $dirCont 1]]
	    foreach dir $dirList {
		incr sPo(numDirsScanned)
		set dirName [file tail $dir]
		set subDir [file join $srcDir $dirName]

		# Diff only the pure directory name, ignore the path part.
		if { [poMisc CheckMatchList $dirName $sPo(ignDirList) $sPo(ignCase)] } {
		    AddToIgnLog $ignDirList $rootDir "$subDir" true
		    continue
		}
		ScanRecursive $widgetName $subDir $rootDir $ignDirList $ignFileList $side
	    }
	    foreach fileName $fileList {
		set fileName [poMisc QuoteTilde $fileName]
		set fileAbs [file join $srcDir $fileName]
		# Diff only the pure filename, ignore the path part.
		if { [poMisc CheckMatchList [file tail $fileAbs] $sPo(ignFileList) $sPo(ignCase)] } {
		    AddToIgnLog $ignFileList $rootDir "$fileAbs" false
		    continue
		}
                set relName [AbsToRel $fileAbs $rootDir]
                if { $numSide == 0 } {
                    set sCacheLeft($relName) 0
                    lappend sFileListLeft $relName
                } else {
                    set sCacheRight($relName) 0
                    lappend sFileListRight $relName
                }
            }
        }
    }

    proc DiffFileLists {} {
        variable ns
        variable sPo
        variable sCacheLeft
        variable sCacheRight
        variable sFileListLeft
        variable sFileListRight
        variable sAddFileList
        variable sNewerFileList
        variable sMarkFileList

        set numFilesLeft  [llength $sFileListLeft]
        set numFilesRight [llength $sFileListRight]
        set fileCount 0
        catch { unset sAddFileList }
        catch { unset sNewerFileList }
        catch { unset sMarkFileList }
        WriteMainInfoStr "Comparing $numFilesLeft left files and $numFilesRight right files ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget,diff) [expr $numFilesLeft + $numFilesRight]
        foreach fileLeft $sFileListLeft {
            incr fileCount
            if { $fileCount % 100 == 0 } {
                poWin UpdateStatusProgress $sPo(StatusWidget,diff) $fileCount
            }
            if { $sPo(stopScan) } {
                return
            }
            set sCacheLeft($fileLeft) 1
            # Strip 2 characters of relative path (./)
            set fileName [string range $fileLeft 2 end]
            set fileName [poMisc QuoteTilde $fileName]
            set fileLeftAbs  [file join $sPo(dir1) $fileName]
            set fileRightAbs [file join $sPo(dir2) $fileName]
            if { [info exists sCacheRight($fileLeft)] } {
                # File exists in both lists. Do comparison according to settings.
                set sCacheRight($fileLeft) 1
                if { $sPo(cmpMode) == [poMisc GetCmpMode "exist"] } {
                    AddToIdentLog $fileLeftAbs $fileRightAbs
                    continue
                }
                set markLeft  0
                set markRight 0
                set leftSize [file size $fileLeftAbs]
                set leftDate [file mtime $fileLeftAbs]
                set rightSize [file size $fileRightAbs]
                set rightDate [file mtime $fileRightAbs]
                if { $sPo(markNewer) } {
                    if { $leftDate < $rightDate } {
                        set markRight 1
                    }
                    if { $leftDate > $rightDate } {
                        set markLeft 1
                    }
                }
                if { $sPo(optSync) } {
                    if { $leftDate == $rightDate } {
                        AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                    } elseif { $leftDate > $rightDate } {
                        if { [poApps GetVerbose] } {
                            puts "SyncNewer: $fileLeftAbs --> $fileRightAbs"
                        }
                        file copy -force $fileLeftAbs $fileRightAbs
                        incr sPo(numFilesCopied)
                        AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                    } else {
                        AddToFileList $sPo(diffListL) $fileLeftAbs  $markLeft  $leftSize  $leftDate  $fileCount
                        AddToFileList $sPo(diffListR) $fileRightAbs $markRight $rightSize $rightDate $fileCount
                    }
                    continue
                }

                if { $sPo(cmpMode) == [poMisc GetCmpMode "size"] } {
                    if { $leftSize != $rightSize } {
                        AddToFileList $sPo(diffListL) $fileLeftAbs  $markLeft  $leftSize  $leftDate  $fileCount
                        AddToFileList $sPo(diffListR) $fileRightAbs $markRight $rightSize $rightDate $fileCount
                    } else {
                        AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                    }
                    continue
                }

                if { $sPo(cmpMode) == [poMisc GetCmpMode "date"] } {
                    if { $leftDate == $rightDate } {
                        AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                        continue
                    } else {
                        if { $sPo(ignOneHour) } {
                            if { [poMisc Abs [expr {$leftDate - $rightDate}]] == 3600 } {
                                AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                                continue
                            }
                        }
                        AddToFileList $sPo(diffListL) $fileLeftAbs  $markLeft  $leftSize  $leftDate  $fileCount
                        AddToFileList $sPo(diffListR) $fileRightAbs $markRight $rightSize $rightDate $fileCount
                        continue
                    }
                }

                if { $sPo(cmpMode) == [poMisc GetCmpMode "content"] && $sPo(ignEolChar) == 0 } {
                    if { $leftSize != $rightSize } {
                        AddToFileList $sPo(diffListL) $fileLeftAbs  $markLeft  $leftSize  $leftDate  $fileCount
                        AddToFileList $sPo(diffListR) $fileRightAbs $markRight $rightSize $rightDate $fileCount
                        continue
                    }
                }

                if { ! [poMisc FileContentCompare $fileLeftAbs $fileRightAbs $sPo(ignEolChar)] } {
                    AddToFileList $sPo(diffListL) $fileLeftAbs  $markLeft  $leftSize  $leftDate  $fileCount
                    AddToFileList $sPo(diffListR) $fileRightAbs $markRight $rightSize $rightDate $fileCount
                } else {
                    AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                }
            } else {
                # File exists only in left list.
                if { $sPo(optSync) } {
                    if { [poApps GetVerbose] } {
                        puts "SyncLeft: $fileLeftAbs --> $fileRightAbs"
                    }
                    set dirRightAbs [file dirname $fileRightAbs]
                    if { ! [file isdirectory $dirRightAbs] } {
                        file mkdir $dirRightAbs
                    }
                    file copy -force $fileLeftAbs $fileRightAbs
                    incr sPo(numFilesCopied)
                    set markLeft  0
                    set markRight 0
                    set leftSize [file size $fileLeftAbs]
                    set leftDate [file mtime $fileLeftAbs]
                    set rightSize [file size $fileRightAbs]
                    set rightDate [file mtime $fileRightAbs]
                    AddToIdentLog $fileLeftAbs $fileRightAbs $markLeft $markRight $leftSize $rightSize $leftDate $rightDate
                    continue
                }
                set leftSize [file size $fileLeftAbs]
                set leftDate [file mtime $fileLeftAbs]
                AddToFileList $sPo(onlyListL) $fileLeftAbs 0 $leftSize $leftDate $fileCount
            }
        }
        foreach fileRight $sFileListRight {
            incr fileCount
            if { $fileCount % 100 == 0 } {
                poWin UpdateStatusProgress $sPo(StatusWidget,diff) $fileCount
            }
            if { $sPo(stopScan) } {
                return
            }
            if { $sCacheRight($fileRight) == 0 } {
                # File exists only in right list.
                # Strip 2 characters of relative path (./)
                set fileName [string range $fileRight 2 end]
                set fileName [poMisc QuoteTilde $fileName]
                set fileRightAbs [file join $sPo(dir2) $fileName]
                if { $sPo(optSyncDelete) } {
                    if { [poApps GetVerbose] } {
                        puts "SyncDelete: $fileRightAbs"
                    }
                    file delete $fileRightAbs
                    incr sPo(numFilesDeleted)
                    continue
                }
                set rightSize [file size $fileRightAbs]
                set rightDate [file mtime $fileRightAbs]
                AddToFileList $sPo(onlyListR) $fileRightAbs 0 $rightSize $rightDate $fileCount
            }
        }

        # sAddList exists, i.e. immediateMode is disabled and the lists have been filled
        # in proc AddToFileList.
        if { [info exists sAddFileList] } {
            WriteMainInfoStr "Inserting and marking ..." "Watch"
            foreach listId [array names sAddFileList] {
                foreach entry $sAddFileList($listId) {
                    $listId insert end $entry
                }
            }
            if { $sPo(markNewer) } {
                foreach listId [array names sNewerFileList] {
                    set ind 0
                    foreach isNewer $sNewerFileList($listId) {
                        if { $isNewer } {
                            MarkNewerListEntry $listId $ind
                        }
                        incr ind
                    }
                }
            }
            if { $sPo(markByType) } {
                foreach listId [array names sMarkFileList] {
                    set ind 0
                    foreach markColor $sMarkFileList($listId) {
                        $listId rowconfigure $ind -foreground $markColor
                        incr ind
                    }
                }
            }
        }

        $sPo(diffListL) see end
        $sPo(diffListR) see end
        $sPo(onlyListL) see end
        $sPo(onlyListR) see end
        poWin UpdateStatusProgress $sPo(StatusWidget,diff) 0
    }

    proc SearchFileList { side srcDir searchPatt } {
        variable sPo
        variable sFileListLeft
        variable sFileListRight

        if { $side eq "l" } {
            set fileList $sFileListLeft
        } else {
            set fileList $sFileListRight
        }
        set numFiles [llength $fileList]
        set fileCount 0
        WriteSearchInfoStr "Searching \"$searchPatt\" in $numFiles files ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget,search) $numFiles
        set filePattList [split $sPo(filePatt)]

        set fileTypeProc ""
        set fileTypeDesc ""
        if { $sPo(fileType) ne "" } {
            if { $sPo(fileType) eq "binary" } {
                set fileTypeProc IsBinary
                set fileTypeDesc ""
            } elseif { $sPo(fileType) eq "image" } {
                set fileTypeProc IsImage
                set fileTypeDesc ""
            } elseif { $sPo(fileType) eq "text" } {
                set fileTypeProc IsText
                set fileTypeDesc ""
            } elseif { [lsearch -exact -nocase [poImgType GetFmtList] $sPo(fileType)] >= 0 } {
                set fileTypeProc IsImage
                set fileTypeDesc [string tolower $sPo(fileType)]
            } else {
                set fileTypeProc IsText
                set fileTypeDesc $sPo(fileType)
            }
        }

        foreach key $fileList {
            incr fileCount
            # Strip 2 characters of relative path (./)
            set fileName [string range $key 2 end]
            set fileName [poMisc QuoteTilde $fileName]
            set fileAbs  [file join $srcDir $fileName]
            set fileNative [file nativename $fileAbs]

            if { ! [poWinDateSelect IsIgnore $sPo(dateCmpCombo)] } {
                set fileTime [file mtime $fileNative]
                if { ! [poWinDateSelect CompareDate $sPo(dateCmpCombo) $fileTime] } {
                    continue
                }
            }

            # Check if file matches the patterns given in search window.
            # Diff only the pure filename, ignore the path part.
            if { ! [poMisc CheckMatchList [file tail $fileName] $filePattList $sPo(ignCase)] } {
                continue
            }

            if { $fileTypeProc ne "" } {
                if { ! [poType $fileTypeProc $fileNative $fileTypeDesc] } {
                    continue
                }
            }

            if { $searchPatt eq "" } {
                AddToSearchLog false $fileAbs 0
            } else {
                set catchVal [catch {poMisc SearchInFile $fileNative $searchPatt \
                              $sPo(searchIgnCase) $sPo(searchMode) $sPo(searchWord) } retVal]
                if { $catchVal } {
                    lappend sPo(errorLog) [lindex [split "$::errorInfo" "\n"] 0]
                    incr sPo(readErrors)
                } else {
                    if { $retVal > 0 } {
                        AddToSearchLog false $fileAbs $retVal
                    }
                }
            }
            poWin UpdateStatusProgress $sPo(StatusWidget,search) $fileCount
            update
            if { $sPo(stopSearch) } {
                return
            }
        }
        poWin UpdateStatusProgress $sPo(StatusWidget,search) 0
    }

    proc ClearFileLists {} {
        variable sPo

        set sPo(readErrors)  0
        set sPo(ignLogDirL)  [list]
        set sPo(ignLogFileL) [list]
        set sPo(ignLogDirR)  [list]
        set sPo(ignLogFileR) [list]
        set sPo(identLog)    [list]
        set sPo(errorLog)    [list]
    }

    proc ClearDelIndLists {} {
        variable sPo
        variable sDelIndList

        set sDelIndList($sPo(onlyListL))  [list]
        set sDelIndList($sPo(onlyListR))  [list]
        set sDelIndList($sPo(diffListL))  [list]
        set sDelIndList($sPo(diffListR))  [list]
    }

    proc ClearTableContents {} {
        variable sPo

        set tableList [list diffListL diffListR identListL identListR onlyListL onlyListR ignListL ignListR searchList]
        foreach tableName $tableList {
            if { [info exists sPo($tableName)] && [winfo exists $sPo($tableName)] } {
                $sPo($tableName) delete 0 end
            }
        }
    }

    proc AbsToRel { fileName rootDir } {
        set rootLen [string length [string trimright $rootDir "/"]]
        set name [string range $fileName $rootLen end]
        return [format ".%s" $name]
    }

    proc AddToIdentLog { fileName1 fileName2 { mark1 0 } { mark2 0 } \
                        { fileSize1 -1 } { fileSize2 -1 } { fileDate1 -1 } { fileDate2 -1 } } {
        variable sPo

        if { $sPo(relPathes) } {
            set fileName1 [AbsToRel $fileName1 $sPo(dir1)]
            set fileName2 [AbsToRel $fileName2 $sPo(dir2)]
        }
        lappend sPo(identLog) "[list $fileName1 $fileName2 $mark1 $mark2 $fileSize1 $fileSize2 $fileDate1 $fileDate2]"
    }

    proc AddToIgnLog { listName rootName fileName isDir } {
        variable sPo

        if { $sPo(relPathes) } {
            set fileName [AbsToRel $fileName $rootName]
        }
        if { $isDir } {
            append fileName "/"
        }
        lappend sPo($listName) "$fileName"
    }

    proc MarkNewerListEntry { listId entryId { onOff true } } {
        variable sPo

        if { $onOff } {
            $listId rowconfigure $entryId -background       $sPo(fileMarkColor)
            $listId rowconfigure $entryId -selectforeground $sPo(fileMarkColor)
        } else {
            $listId rowconfigure $entryId -background       ""
            $listId rowconfigure $entryId -selectforeground ""
        }
    }

    proc AddToFileList { listId fileName { markNewEntry 0 } { fileSize -1 } { fileTime -1 } { fileCount 0 } } {
        variable sPo
        variable sAddFileList
        variable sNewerFileList
        variable sMarkFileList

        # fileName is always an absolute pathname.
        if { $sPo(relPathes) } {
            set fileName [AbsToRel $fileName [GetRootDir $listId]]
        }
        set fileName [string trimright $fileName "/"]
        if { $sPo(immediateUpdate) } {
            SetListEntry $listId end $fileName $fileSize $fileTime
            if { $markNewEntry } {
                MarkNewerListEntry $listId end
            }
            $listId see end
        } else {
            lappend sAddFileList($listId) [FormatListEntry $listId $fileName $fileSize $fileTime]
            if { $sPo(markNewer) } {
                lappend sNewerFileList($listId) $markNewEntry
            }
            if { $sPo(markByType) } {
                lappend sMarkFileList($listId) [poFileType GetColor $fileName]
            }
        }
        UpdateFileCount
    }

    proc CloseSubWindows {} {
        variable sPo

        foreach tw $sPo(infoWinList) {
            if { [winfo exists $tw] } {
                poWinInfo DeleteInfoWin $tw
            }
        }
        unset sPo(infoWinList)
        set sPo(infoWinList) {}

        CloseSearchWin

        catch {destroy $sPo(errorLog,name)}
        catch {DestroyIgnoreLog $sPo(ignoreLog,name)}
        catch {DestroyIdentLog  $sPo(identLog,name)}
    }

    proc CloseAppWindow {} {
        variable sPo

        if { ! [info exists sPo(tw)] || ! [winfo exists $sPo(tw)] } {
            return
        }

        StopScan
        StopSearch

        # Indicate to a potentially running DiffDir, that the app window has been closed.
        set sPo(appWindowClosed) true

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows

        # Clear preview photo images.
        poWinPreview Clear $sPo(previewFrameL)
        poWinPreview Clear $sPo(previewFrameR)

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        poApps ExitApp
    }

    proc WriteInfoStr { type str { icon "None" } } {
        if { $type eq "diff" } {
            WriteMainInfoStr $str $icon
        } elseif { $type eq "search" } {
            WriteSearchInfoStr $str $icon
        }
    }

    proc WriteMainInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget,diff)] } {
            poWin WriteStatusMsg $sPo(StatusWidget,diff) $str $icon
        }
    }

    proc AppendMainInfoStr { str } {
        variable sPo

        poWin AppendStatusMsg $sPo(StatusWidget,diff) $str
    }

    proc WriteSearchInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget,search)] } {
            poWin WriteStatusMsg $sPo(StatusWidget,search) $str $icon
        }
    }

    proc AppendSearchInfoStr { str } {
        variable sPo

        poWin AppendStatusMsg $sPo(StatusWidget,search) $str
    }

    proc RelToAbsPath { path prefix } {

        if { [file pathtype $path] eq "relative" } {
            set absPath [string trimright [file join $prefix $path] "/"]
        } else {
            set absPath [string trimright $path "/"]
        }
        if { $::tcl_platform(platform) eq "windows" } {
            if { [string index $absPath end] eq ":" } {
                append absPath "/"
            }
        }
        return [poMisc FileSlashName $absPath]
    }

    proc UpdateFromSett { tw removeWindow } {
        variable sPo

        UpdateMainTitle
        if { $removeWindow } {
            destroy $tw
        }
    }

    proc InvalidateCache {} {
        variable sCacheLeft
        variable sCacheRight
        variable sFileListLeft
        variable sFileListRight

        catch { unset sCacheLeft }
        catch { unset sCacheRight }
        catch { unset sFileListLeft }
        catch { unset sFileListRight }
        
        set sFileListLeft  [list]
        set sFileListRight [list]
    }

    proc GetMarkColor { labelId whichMark } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo($whichMark)]
        if { $newColor ne "" } {
            set sPo($whichMark) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc UpdateIgnoreVar { textWidget listType } {
        variable sPo

        set sPo($listType) {}
        scan [$textWidget index end] %d noLines
        for { set i 1 } { $i < $noLines } { incr i } {
            set tmp [$textWidget get $i.0 $i.end]
            if { [string length $tmp] > 0 } {
                lappend sPo($listType) $tmp
            }
        }
    }

    proc UpdateIgnoreList { tw } {
        variable sPo

        if { [info exists sPo(ignDirText)] && [winfo exists $sPo(ignDirText)] } {
            UpdateIgnoreVar $sPo(ignDirText)  ignDirList
        }
        if { [info exists sPo(ignFileText)] && [winfo exists $sPo(ignFileText)] } {
            UpdateIgnoreVar $sPo(ignFileText) ignFileList
        }
    }

    proc OKSettingsWin { tw } {
        variable sPo

        if { $tw eq ".poDiff_searchWin" } {
            HiliteSearchDir 0
        }
        UpdateIgnoreList $tw
        destroy $tw
    }

    proc CancelSettingsWin { tw args } {
        variable sPo

        poToolhelp HideToolhelp
        if { $tw eq ".poDiff_searchWin" } {
            HiliteSearchDir 0
        }
        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        destroy $tw
        UpdateMainTitle
    }

    proc ShowMiscTab { tw } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Confirmation:" \
                           "View:" \
                           "Colors:" \
                           "Search patterns:" \
                           "Sessions:" } {
            ttk::label $tw.l$row -text $labelStr
            grid  $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList {}
        # Generate right column with entries and buttons.
        # Part 1: Confirmation switches
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Ask before delete" \
                                   -variable ${ns}::sPo(deleteConfirm)
        ttk::checkbutton $tw.fr$row.cb2 -text "Ask before copy" \
                                   -variable ${ns}::sPo(copyConfirm)
        ttk::checkbutton $tw.fr$row.cb3 -text "Ask before move" \
                                   -variable ${ns}::sPo(moveConfirm)
        ttk::checkbutton $tw.fr$row.cb4 -text "Ask before conversion" \
                                   -variable ${ns}::sPo(convConfirm)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w

        # Part 2: Viewing switches
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Relative pathnames" -variable ${ns}::sPo(relPathes)
        ttk::checkbutton $tw.fr$row.cb2 -text "Immediate update"   -variable ${ns}::sPo(immediateUpdate)
        ttk::checkbutton $tw.fr$row.cb3 -text "Mark newer files"   -variable ${ns}::sPo(markNewer)
        ttk::checkbutton $tw.fr$row.cb4 -text "Mark files by type" -variable ${ns}::sPo(markByType)
        ttk::checkbutton $tw.fr$row.cb5 -text "Show preview"       -variable ${ns}::sPo(showPreview)
        ttk::checkbutton $tw.fr$row.cb6 -text "Show file info"     -variable ${ns}::sPo(showFileInfo)
        pack {*}[winfo children $tw.fr$row] -side top -anchor w
        poToolhelp AddBinding $tw.fr$row.cb2 "Switch off for faster display of compare results"
        poToolhelp AddBinding $tw.fr$row.cb5 "Display information in Preview tab"
        poToolhelp AddBinding $tw.fr$row.cb6 "Display information in File Info tab"

        # Part 3: Color settings
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::frame $tw.fr$row.fileFr
        ttk::frame $tw.fr$row.listFr
        ttk::frame $tw.fr$row.sideFr
        pack $tw.fr$row.fileFr $tw.fr$row.listFr $tw.fr$row.sideFr -side top -fill x -expand 1

        label $tw.fr$row.fileFr.l -width 10 -relief sunken -background $sPo(fileMarkColor)
        ttk::button $tw.fr$row.fileFr.b -text "Color for marking newer file ..." \
                    -command "${ns}::GetMarkColor $tw.fr$row.fileFr.l fileMarkColor"
        pack $tw.fr$row.fileFr.l -side left -anchor w
        pack $tw.fr$row.fileFr.b -side left -anchor w -padx 2 -expand 1 -fill x

        label $tw.fr$row.listFr.l -width 10 -relief sunken -background $sPo(listMarkColor)
        ttk::button $tw.fr$row.listFr.b  -text "Color for marking active table ..." \
                    -command "${ns}::GetMarkColor $tw.fr$row.listFr.l listMarkColor"
        pack $tw.fr$row.listFr.l -side left -anchor w
        pack $tw.fr$row.listFr.b -side left -anchor w -padx 2 -expand 1 -fill x

        label $tw.fr$row.sideFr.l -width 10 -relief sunken -background $sPo(sideMarkColor)
        ttk::button $tw.fr$row.sideFr.b  -text "Color for marking search directory ..." \
                    -command "${ns}::GetMarkColor $tw.fr$row.sideFr.l sideMarkColor"
        pack $tw.fr$row.sideFr.l -side left -anchor w
        pack $tw.fr$row.sideFr.b -side left -anchor w -padx 2 -expand 1 -fill x

        # Part 4: Search pattern entries
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::button $tw.fr$row.b1 -text "Edit list ..."  -command "${ns}::EditRecentList searchPattList"
        ttk::button $tw.fr$row.b2 -text "Clear list"     -command "${ns}::ClearRecentSearchPattList"
        poToolhelp AddBinding $tw.fr$row.b2 "This operation can not be undone"

        pack  $tw.fr$row.b1 -side left -pady 2 -fill x -expand 1
        pack  $tw.fr$row.b2 -side left -pady 2 -fill x -expand 1

        # Part 5: Session menu entries
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::button $tw.fr$row.b1 -text "Edit list ..."  -command "${ns}::EditRecentList sessionList"
        ttk::button $tw.fr$row.b2 -text "Clear list"     -command "${ns}::ClearRecentSessionList $sPo(sessionMenu)"
        poToolhelp AddBinding $tw.fr$row.b2 "This operation can not be undone"

        pack  $tw.fr$row.b1 -side left -pady 2 -fill x -expand 1
        pack  $tw.fr$row.b2 -side left -pady 2 -fill x -expand 1

        set tmpList [list [list sPo(deleteConfirm)] [list $sPo(deleteConfirm)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(copyConfirm)]   [list $sPo(copyConfirm)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(moveConfirm)]   [list $sPo(moveConfirm)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(convConfirm)]   [list $sPo(convConfirm)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(relPathes)] [list $sPo(relPathes)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(immediateUpdate)] [list $sPo(immediateUpdate)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(markNewer)] [list $sPo(markNewer)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(markByType)] [list $sPo(markByType)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(fileMarkColor)] [list $sPo(fileMarkColor)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(sideMarkColor)] [list $sPo(sideMarkColor)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(showPreview)] [list $sPo(showPreview)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(showFileInfo)] [list $sPo(showFileInfo)]]
        lappend varList $tmpList
        return $varList
    }

    proc ShowDiffTab { tw } {
        variable sPo
        variable ns

        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1

        ttk::labelframe $tw.fr.ignfr -text "Ignore mode"
        ttk::labelframe $tw.fr.cmpfr -text "Compare mode"
        ttk::frame $tw.fr.okfr
        grid $tw.fr.ignfr -row 0 -column 0 -sticky news
        grid $tw.fr.cmpfr -row 1 -column 0 -sticky news
        grid $tw.fr.okfr  -row 2 -column 0 -sticky news
        grid rowconfigure $tw.fr 0 -weight 1
        grid columnconfigure $tw.fr 0 -weight 1

        ttk::frame $tw.fr.ignfr.dirfr
        ttk::frame $tw.fr.ignfr.filefr
        ttk::frame $tw.fr.ignfr.ignfr
        grid $tw.fr.ignfr.dirfr  -row 0 -column 0 -sticky news
        grid $tw.fr.ignfr.filefr -row 1 -column 0 -sticky news
        grid $tw.fr.ignfr.ignfr  -row 2 -column 0 -sticky news
        grid rowconfigure $tw.fr.ignfr 0 -weight 1
        grid rowconfigure $tw.fr.ignfr 1 -weight 1
        grid columnconfigure $tw.fr.ignfr 0 -weight 1

        ttk::frame $tw.fr.cmpfr.cmpfr
        ttk::frame $tw.fr.cmpfr.optfr
        pack {*}[winfo children $tw.fr.cmpfr] -side top -fill both -expand 1

        set sPo(ignDirText)  [poWin CreateScrolledText $tw.fr.ignfr.dirfr true \
                              "Ignore these directories" -width 20 -wrap none -height 5]
        set sPo(ignFileText) [poWin CreateScrolledText $tw.fr.ignfr.filefr true \
                              "Ignore these files" -width 20 -wrap none -height 5]

        bind $sPo(ignDirText)  <Any-KeyRelease> "${ns}::UpdateIgnoreVar $sPo(ignDirText) ignDirList"
        bind $sPo(ignFileText) <Any-KeyRelease> "${ns}::UpdateIgnoreVar $sPo(ignFileText) ignFileList"

        set varList {}

        # Fill the text widgets with the entries of the ignore lists.
        foreach d $sPo(ignDirList) {
            $sPo(ignDirText) insert end "$d\n"
        }
        foreach f $sPo(ignFileList) {
            $sPo(ignFileText) insert end "$f\n"
        }
        set tmpList [list [list sPo(ignDirList)] [list $sPo(ignDirList)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(ignFileList)] [list $sPo(ignFileList)]]
        lappend varList $tmpList

        # Generate check buttons to ignore hidden directories and files.
        ttk::checkbutton $tw.fr.ignfr.ignfr.cbdir  -text "Ignore hidden directories" \
                                        -variable ${ns}::sPo(ignHiddenDirs)
        ttk::checkbutton $tw.fr.ignfr.ignfr.cbfile -text "Ignore hidden files" \
                                        -variable ${ns}::sPo(ignHiddenFiles)
        ttk::checkbutton $tw.fr.ignfr.ignfr.cbcase -text "Ignore case" \
                                        -variable ${ns}::sPo(ignCase)
        pack {*}[winfo children $tw.fr.ignfr.ignfr] -side left

        set tmpList [list [list sPo(ignHiddenDirs)] [list $sPo(ignHiddenDirs)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(ignHiddenFiles)] [list $sPo(ignHiddenFiles)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(ignCase)] [list $sPo(ignCase)]]
        lappend varList $tmpList

        # Generate radio buttons to select file compare mode.
        ttk::radiobutton $tw.fr.cmpfr.cmpfr.rb1 -text "Exist" -value [poMisc GetCmpMode "exist"] \
                                     -variable ${ns}::sPo(cmpMode) -command ${ns}::InvalidateCache
        ttk::radiobutton $tw.fr.cmpfr.cmpfr.rb2 -text "Size" -value [poMisc GetCmpMode "size"] \
                                     -variable ${ns}::sPo(cmpMode) -command ${ns}::InvalidateCache
        ttk::radiobutton $tw.fr.cmpfr.cmpfr.rb3 -text "Date" -value [poMisc GetCmpMode "date"] \
                                     -variable ${ns}::sPo(cmpMode) -command ${ns}::InvalidateCache
        ttk::radiobutton $tw.fr.cmpfr.cmpfr.rb4 -text "Content" -value [poMisc GetCmpMode "content"] \
                                     -variable ${ns}::sPo(cmpMode) -command ${ns}::InvalidateCache
        pack {*}[winfo children $tw.fr.cmpfr.cmpfr] -side left
        poToolhelp AddBinding $tw.fr.cmpfr.cmpfr.rb1 "Check existence of left/right files only"

        set tmpList [list [list sPo(cmpMode)] [list $sPo(cmpMode)]]
        lappend varList $tmpList

        # Generate check button to ignore platform specific EOL characters.
        ttk::checkbutton $tw.fr.cmpfr.optfr.eolcb -text "Ignore EOL character" \
                                    -variable ${ns}::sPo(ignEolChar)
        # Generate check button to ignore time differences between FAT and NTFS file systems.
        ttk::checkbutton $tw.fr.cmpfr.optfr.onecb -text "Ignore 1 hour differences" \
                                    -variable ${ns}::sPo(ignOneHour)
        pack {*}[winfo children $tw.fr.cmpfr.optfr] -side left

        set tmpList [list [list sPo(ignEolChar)] [list $sPo(ignEolChar)]]
        set tmpList [list [list sPo(ignOneHour)] [list $sPo(ignOneHour)]]
        lappend varList $tmpList
        return $varList
    }

    proc ShowSpecificSettWin { { selectTab "Diff" } } {
        variable sPo
        variable ns

        set tw .poDiff_specWin
        set sPo(specWin,name) $tw

        set nb $tw.fr.nb

        set selTabInd 0
        if { $selectTab eq "Miscellaneous" } {
            set selTabInd 0
        } elseif { $selectTab eq "Diff" } {
            set selTabInd 1
        }

        if { [winfo exists $tw] } {
            poWin Raise $tw
            $nb select $selTabInd
            return
        }

        toplevel $tw
        wm title $tw "Directory diff specific settings"
        wm resizable $tw true true
        wm geometry $tw [format "+%d+%d" $sPo(specWin,x) $sPo(specWin,y)]

        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1

        ttk::notebook $nb -style [poAppearance GetTabStyle]
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        set varList [list]

        ttk::frame $nb.miscFr
        set tmpList [ShowMiscTab $nb.miscFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.miscFr -text "Miscellaneous" -underline 0 -padding 2

        ttk::frame $nb.compareFr
        set tmpList [ShowDiffTab $nb.compareFr]
        set varList [concat $varList $tmpList]
        $nb add $nb.compareFr -text "Compare" -underline 0 -padding 2

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

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init global variables not stored in the cfg file.
        ClearFileLists

        # Init all variables stored in the cfg file with default values.
        SetWindowPos mainWin     90  30 800 550
        SetWindowPos specWin    100  50   0   0
        SetWindowPos searchWin   10  30 800 600
        SetWindowPos identLog    20  30 900 400
        SetWindowPos ignoreLog   30  40 900 400

        SetMainWindowSash   150 330
        SetSearchWindowSash 150

        SetConfirmationModes  1 1 1 1
        SetMarkModes          1 1 "LimeGreen" "lightyellow" "green"
        SetPreviewModes       1 1
        SetViewModes          0 1
        SetShowPreviewTab     1
        SetColumnAlignment    "left"

        SetCurDirectories "" ""

        SetCurSearchPatterns "SearchPattern" "ReplacePattern" "*"
        SetCurDatePatterns   "ignore"
        SetSearchPatternList 0 [list]
        SetSearchModes 1 0 0 "exact"

        SetDiffModes   2 0 0 0 0 [expr ! [poMisc IsCaseSensitiveFileSystem]]
        SetIgnoreLists [list CVS .svn] [list .DS_Store *.o *.obj *.so *.dll]

        SetMaxShowWin   5

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
            puts $fp "catch {SetWindowPos [GetWindowPos searchWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos specWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos identLog]}"
            puts $fp "catch {SetWindowPos [GetWindowPos ignoreLog]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetWindowPos [GetWindowPos searchWin]
            eval SetWindowPos [GetWindowPos specWin]
            eval SetWindowPos [GetWindowPos identLog]
            eval SetWindowPos [GetWindowPos ignoreLog]

            eval SetMainWindowSash   [GetMainWindowSash]
            eval SetSearchWindowSash [GetSearchWindowSash]

            PrintCmd $fp "MainWindowSash"
            PrintCmd $fp "SearchWindowSash"

            PrintCmd $fp "ConfirmationModes"
            PrintCmd $fp "ViewModes"
            PrintCmd $fp "MarkModes"
            PrintCmd $fp "PreviewModes"
            PrintCmd $fp "SearchModes"
            PrintCmd $fp "DiffModes"
            PrintCmd $fp "ShowPreviewTab"
            PrintCmd $fp "ColumnAlignment"

            PrintCmd $fp "CurDirectories"

            PrintCmd $fp "CurSearchPatterns"
            PrintCmd $fp "CurDatePatterns"
            PrintCmd $fp "SearchPatternList"
            PrintCmd $fp "IgnoreLists"

            PrintCmd $fp "MaxShowWin"

            puts $fp ""
            puts $fp "# AddSession sessionName leftDir rightDir compareMode\
                     ignoreDirList ignoreFileList ignoreHiddenDirs\
                     ignoreHiddenFiles ignoreEolChar ignoreOneHour ignoreCase"
            foreach sessionName $sPo(sessionList) {
                set dir1           $sPo(session,$sessionName,dir1)
                set dir2           $sPo(session,$sessionName,dir2)
                set cmpMode        $sPo(session,$sessionName,cmpMode)
                set ignDirList     $sPo(session,$sessionName,ignDirList)
                set ignFileList    $sPo(session,$sessionName,ignFileList)
                set ignHiddenDirs  $sPo(session,$sessionName,ignHiddenDirs)
                set ignHiddenFiles $sPo(session,$sessionName,ignHiddenFiles)
                set ignEolChar     $sPo(session,$sessionName,ignEolChar)
                set ignOneHour     $sPo(session,$sessionName,ignOneHour)
                set ignCase        $sPo(session,$sessionName,ignCase)
                puts $fp "catch {AddSession [list $sessionName] [list $dir1] [list $dir2] \
                          $cmpMode [list $ignDirList] [list $ignFileList] $ignHiddenDirs \
                          $ignHiddenFiles $ignEolChar $ignOneHour $ignCase}"
            }

            close $fp
        }
    }

    proc PrintUsage { progName } {
        puts [GetUsageMsg $progName]
    }


    proc BatchProcess { leftDirToOpen rightDirToOpen batchType } {
        variable sPo
        variable ns

        if { $leftDirToOpen eq "" } {
            puts "Error: No left directory specified."
            return 2
        }
        if { $rightDirToOpen eq "" } {
            puts "Error: No right directory specified."
            return 3
        }
        if { ! [file isdirectory $leftDirToOpen] } {
            puts "Error: $leftDirToOpen is not a valid directory."
            return 4
        }
        if { ! [file isdirectory $rightDirToOpen] } {
            puts "Error: $rightDirToOpen is not a valid directory."
            return 5
        }
        if { $batchType eq "Sync" } {
            return [TimeDiffDir]
        } elseif { $batchType eq "CopyDate" } {
            set sPo(searchPatt) ""
            ShowSearchWin
            set cmpDate [clock add [clock scan now] -$sPo(optCopyDays) days]
            poWinDateSelect SetDate $sPo(dateCmpCombo) $cmpDate
            poWinDateSelect SetCompareMode $sPo(dateCmpCombo) "newer"
            if { [poApps GetVerbose] } {
                puts "Searching files newer than [poWinDateSelect GetDate $sPo(dateCmpCombo)] ..."
            }
            TimeSearchDir searchPatt
            SelectListbox $sPo(searchList)
            SelectAll
            if { [poApps GetVerbose] } {
                set numFound [$sPo(searchList) size]
                puts "Copying $numFound files ..."
            }
            CopySearchFromSide "l"
        }
        return 0
    }

    proc ParseCommandLine { argList } {
        variable sPo
        variable sSearch

        set sPo(paramdir1) ""
        set sPo(paramdir2) ""
        set whatDir 1
        set curArg  0
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "syncdelete" } {
                    set sPo(optSync) true
                    set sPo(optSyncDelete) true
                } elseif { $curOpt eq "sync" } {
                    set sPo(optSync) true
                } elseif { $curOpt eq "copydate" } {
                    set sPo(optCopyDate) true
                    incr curArg
                    set sPo(optCopyDays) [lindex $argList $curArg]
                } elseif { $curOpt eq "search" } {
                    incr curArg
                    set sPo(searchPatt) [lindex $argList $curArg]
                    set sPo(searchDir)  1
                    set sPo(optSearch) true
                } elseif { $curOpt eq "filetype" } {
                    incr curArg
                    set sPo(fileType) [lindex $argList $curArg]
                    set sPo(optSearch) true
                } elseif { $curOpt eq "filematch" } {
                    incr curArg
                    set sPo(filePatt) [lindex $argList $curArg]
                    set sPo(optSearch) true
                } elseif { $curOpt eq "convert" } {
                    incr curArg
                    set sPo(optConvertFmt) [lindex $argList $curArg]
                    set sPo(optSearch) true
                    set sPo(optConvert) true
                } elseif { $curOpt eq "diff" } {
                    set sPo(optDiffOnStartup) true
                } elseif { $curOpt eq "session" } {
                    incr curArg
                    set sPo(optSessionOnStartup) [lindex $argList $curArg]
                } elseif { $curOpt eq "compare" } {
                    incr curArg
                    set sPo(cmpMode) [poMisc GetCmpMode [lindex $argList $curArg]]
                } elseif { $curOpt eq "immediate" } {
                    incr curArg
                    set sPo(immediateUpdate) [poMisc BoolAsInt [lindex $argList $curArg]]
                } elseif { $curOpt eq "marknewer" } {
                    incr curArg
                    set sPo(markNewer) [poMisc BoolAsInt [lindex $argList $curArg]]
                } elseif { $curOpt eq "marktypes" } {
                    incr curArg
                    set sPo(markByType) [poMisc BoolAsInt [lindex $argList $curArg]]
                } elseif { $curOpt eq "ignoreeol" } {
                    incr curArg
                    set sPo(ignEolChar) [poMisc BoolAsInt [lindex $argList $curArg]]
                } elseif { $curOpt eq "ignorehour" } {
                    incr curArg
                    set sPo(ignOneHour) [poMisc BoolAsInt [lindex $argList $curArg]]
                }
            } else {
                set dir [RelToAbsPath $curParam $sPo(startDir)]
                if { [file isdirectory $dir] } {
                    set sPo(paramdir$whatDir) $dir
                    incr whatDir
                }
            }
            incr curArg
        }
        if { $sPo(paramdir1) ne "" } {
            set sPo(dir1) $sPo(paramdir1)
        }
        if { $sPo(paramdir2) ne "" } {
            set sPo(dir2) $sPo(paramdir2)
        }

        poWinSelect SetValue $sPo(dir1,combo) $sPo(dir1)
        poWinSelect SetValue $sPo(dir2,combo) $sPo(dir2)
        poAppearance AddToRecentDirList $sPo(dir1)
        poAppearance AddToRecentDirList $sPo(dir2)
        UpdateMainTitle

        # If only 1 directory has been specified on the command line,
        # the user typically wants to search. So open the search window.
        if { $sPo(paramdir1) ne "" && $sPo(paramdir2) eq "" } {
            ShowSearchWin
        }

        if { $sPo(optSessionOnStartup) ne "" } {
            if { [GetSessionName $sPo(optSessionOnStartup)] ne "" } { 
                SelectSession $sPo(optSessionOnStartup)
            } else {
                if { [poApps UseBatchMode] } {
                    puts "Error: Invalid session \"$sPo(optSessionOnStartup)\" specified."
                    exit 3
                }
            }
        }

        # If 2 directories have been specified or a session was specified
        # and the user specified the --diff option, start diffing after startup of the GUI.
        if { $sPo(optDiffOnStartup) } {
            if { [poApps UseBatchMode] } {
                if { ($sPo(paramdir1) eq "" || $sPo(paramdir2) eq "") && $sPo(optSessionOnStartup) eq "" } {
                    puts "Error: Either a session or 2 directories have to be specified."
                    exit 2
                }
            }
            set exitStatus [TimeDiffDir]
            if { [poApps UseBatchMode] } {
                exit $exitStatus
            }
        }

        if { $sPo(optSearch) } {
            if { ! [file isdirectory $sPo(dir1)] } {
                if { [poApps UseBatchMode] } {
                    puts "Error: No valid search directory specified"
                    exit 1
                }
            }
            ShowSearchWin
            if { [poApps GetVerbose] } {
                puts "Search directory: $sPo(dir1)"
                puts "Search string   : \"$sPo(searchPatt)\""
                puts "File match      : \"$sPo(filePatt)\""
                puts "File type       : \"$sPo(fileType)\""
            }
            TimeSearchDir searchPatt
            if { [poApps GetVerbose] } {
                puts "Found $sSearch(numFiles) matching files."
            }
            SelectListbox $sPo(searchList)
            SelectAll
            if { $sPo(optConvert) && $sPo(optConvertFmt) ne "" } {
                if { [poApps GetVerbose] } {
                    set numFound [$sPo(searchList) size]
                    puts "Converting $numFound files to $sPo(optConvertFmt) ..."
                }
                set sPo(convConfirm) false
                ConvertFile $sPo(searchList) $sPo(optConvertFmt)
            }
            if { [poApps UseBatchMode] } {
                exit 0
            }
        }

        if { $sPo(optSync) } {
            set exitStatus [BatchProcess $sPo(paramdir1) $sPo(paramdir2) "Sync"]
            if { [poApps UseBatchMode] } {
                exit $exitStatus
            }
        }

        if { $sPo(optCopyDate) } {
            set exitStatus [BatchProcess $sPo(paramdir1) $sPo(paramdir2) "CopyDate"]
            if { [poApps UseBatchMode] } {
                exit $exitStatus
            }
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poDiff Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
