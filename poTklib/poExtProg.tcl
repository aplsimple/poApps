# Module:         poExtProg
# Copyright:      Paul Obermeier 2001-2020 / paul@poSoft.de
# First Version:  2001 / 07 / 06
#
# Distributed under BSD license.
#
# Module for starting external programs in a portable way.

namespace eval poExtProg {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init 
    namespace export OpenWin OkWin CancelWin
    namespace export SupportsAsso
    namespace export StartAssoProg StartEditProg StartOneEditProg StartDiffProg StartHexEditProg
    namespace export DumpFileIntoTextWidget LoadFileIntoTextWidget SaveTextWidgetToFile
    namespace export StopDump
    namespace export ShowSimpleTextEdit ShowSimpleHexEdit
    namespace export ShowSimpleTextDiff ShowSimpleHexDiff ShowTkDiffHexDiff
    namespace export ShowTkDiff
    namespace export StartFileBrowser
    namespace export OpenUrl
    namespace export GetExecutable
    namespace export HasTextWidgetChanged CloseSimpleTextEdit
    namespace export GetTextWidgetSaveMode SetTextWidgetSaveMode
    namespace export GetTextWidgetTabStop SetTextWidgetTabStop
    namespace export GetTextWidgetFont SetTextWidgetFont
    namespace export GetTextWidgetLineNumMode SetTextWidgetLineNumMode
    namespace export GetTextWidgetWrapLines SetTextWidgetWrapLines
    namespace export ShowLineNumbers SetTitle SearchText
    namespace export SetTextWidgetSearchOpts SetTextWidgetSearchString

    variable sExt

    # Init is called at package load time.
    proc Init {} {
        variable sExt

        set sExt(maxShowWin)    4
        set sExt(diffCount)     0
        set sExt(editCount)     0
        set sExt(hexCount)      0
        set sExt(tkdiffSourced) 0

        set sExt(ShowLineNumbers,edit)    false
        set sExt(ShowLineNumbers,preview) false
        set sExt(WrapLines,edit)          none
        set sExt(WrapLines,preview)       none
        set sExt(TabStop,edit)            8
        set sExt(TabStop,preview)         8
        set sExt(Font,edit)               [poWin GetFixedFont]
        set sExt(Font,preview)            [poWin GetFixedFont]

        set sExt(SearchIgnCase)           false
        set sExt(SearchWord)              false
        set sExt(SaveMode)                "lf"
        set sExt(ResultColor)             "lightgreen"
        set sExt(CurrentColor)            "yellow"
    }

    proc CancelWin { w args } {
        variable sExt

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

    proc OpenWin { fr } {
       variable ns
       variable sExt

       set tw $fr

        set row 0
        ttk::frame $tw.fr
        pack $tw.fr -fill both -expand 1 

        set editfr    $tw.fr.editfr
        set previewfr $tw.fr.previewfr
        ttk::labelframe $editfr    -text "Edit Widgets"
        ttk::labelframe $previewfr -text "Preview Widgets"
        grid $editfr    -row 0 -column 0 -sticky news
        grid $previewfr -row 1 -column 0 -sticky news

        set varList [list]
        foreach labelfr [list $editfr $previewfr] mode [list edit preview] {
            set row 0
            foreach labelStr { "Display:" \
                               "Tabstop width:" \
                               "Font:" } {
                ttk::label $labelfr.l$row -text $labelStr
                grid $labelfr.l$row -row $row -column 0 -sticky new
                incr row
            }

            # Show line numbers
            set row 0
            ttk::frame $labelfr.fr$row
            grid $labelfr.fr$row -row $row -column 1 -sticky new

            ttk::checkbutton $labelfr.fr$row.cb1 -text "Show line numbers" \
                         -variable ${ns}::sExt(ShowLineNumbers,$mode) \
                         -command "${ns}::UpdateLineNumbers $mode" \
                         -onvalue true -offvalue false
            ttk::checkbutton $labelfr.fr$row.cb2 -text "Wrap lines" \
                         -variable ${ns}::sExt(WrapLines,$mode) \
                         -command "${ns}::UpdateWrapLines $mode" \
                         -onvalue word -offvalue none
            pack {*}[winfo children $labelfr.fr$row] -side top -anchor w -pady 2

            set tmpList [list [list sExt(ShowLineNumbers,$mode)] [list $sExt(ShowLineNumbers,$mode)]]
            lappend varList $tmpList
            set tmpList [list [list sExt(WrapLines,$mode)] [list $sExt(WrapLines,$mode)]]
            lappend varList $tmpList

            # Tab stop
            incr row
            ttk::frame $labelfr.fr$row
            grid $labelfr.fr$row -row $row -column 1 -sticky new

            ttk::combobox $labelfr.fr$row.cb -textvariable ${ns}::sExt(TabStop,$mode) \
                          -values [list 1 2 3 4 8] -state readonly -width 2 -takefocus 0
            bind $labelfr.fr$row.cb <<ComboboxSelected>> "${ns}::UpdateTabStops $mode"
            pack {*}[winfo children $labelfr.fr$row] -side top -anchor w -pady 2

            set tmpList [list [list sExt(TabStop,$mode)] [list $sExt(TabStop,$mode)]]
            lappend varList $tmpList

            # Font
            incr row
            ttk::frame $labelfr.fr$row
            grid $labelfr.fr$row -row $row -column 1 -sticky new

            button $labelfr.fr$row.f -relief ridge -text "Select font" -command "${ns}::FontSettings $labelfr.fr$row.f $mode"
            button $labelfr.fr$row.r -relief ridge -text "Reset font"  -command "${ns}::ResetFont $labelfr.fr$row.f $mode"
            $labelfr.fr$row.f configure -font $sExt(Font,$mode)
            pack {*}[winfo children $labelfr.fr$row] -side left

            set tmpList [list [list sExt(Font,$mode)] [list $sExt(Font,$mode)]]
            lappend varList $tmpList
        }
        return $varList
    }

    proc SetTextWidgetSaveMode { mode } {
        variable sExt

        set sExt(SaveMode) $mode
    }

    proc GetTextWidgetSaveMode {} {
        variable sExt

        return $sExt(SaveMode)
    }

    proc SetTextWidgetTabStop { tabStopEdit tabStopPreview } {
        variable sExt

        set sExt(TabStop,edit)    $tabStopEdit
        set sExt(TabStop,preview) $tabStopPreview
    }

    proc GetTextWidgetTabStop {} {
        variable sExt

        return [list $sExt(TabStop,edit) $sExt(TabStop,preview)]
    }

    proc SetTextWidgetFont { fontEdit fontPreview } {
        variable sExt

        set sExt(Font,edit)    $fontEdit
        set sExt(Font,preview) $fontPreview
    }

    proc GetTextWidgetFont {} {
        variable sExt

        return [list $sExt(Font,edit) $sExt(Font,preview)]
    }

    proc SetTextWidgetLineNumMode { onOffEdit onOffPreview } {
        variable sExt

        set sExt(ShowLineNumbers,edit)    $onOffEdit
        set sExt(ShowLineNumbers,preview) $onOffPreview
    }

    proc GetTextWidgetLineNumMode {} {
        variable sExt

        return [list $sExt(ShowLineNumbers,edit) $sExt(ShowLineNumbers,preview)]
    }

    proc SetTextWidgetWrapLines { onOffEdit onOffPreview } {
        variable sExt

        set sExt(WrapLines,edit)    $onOffEdit
        set sExt(WrapLines,preview) $onOffPreview
    }

    proc GetTextWidgetWrapLines {} {
        variable sExt

        return [list $sExt(WrapLines,edit) $sExt(WrapLines,preview)]
    }

    proc SetTextWidgetSearchOpts { textId ignCase matchWord } {
        variable sExt

        set sExt($textId,SearchIgnCase) $ignCase
        set sExt($textId,SearchWord)    $matchWord
    }

    proc SetTextWidgetSearchString { textId searchStr } {
        variable sExt

        set sExt($textId,SearchPatt) $searchStr
        # Check, if the current search and replace patterns are contained in the
        # pattern list. If not, insert them at the list begin.
        set indSearch [lsearch -exact $sExt(SearchPattList) $searchStr]
        if { $indSearch < 0 } {
            set sExt(SearchPattList) [linsert $sExt(SearchPattList) 0 $searchStr]
        }
        # Now search again in the (possibly extended) list for the new positions
        # of the search pattern and update the corresponding combo box.
        set indSearch [lsearch -exact $sExt(SearchPattList) $sExt($textId,SearchPatt)]
        _UpdateCombo $sExt($textId,SearchCombo) $sExt(SearchPattList) $indSearch
    }

    proc HasTextWidgetChanged { w } {
        return [$w edit modified]
    }

    proc StopDump {} {
        variable sExt

        set sExt(stopDump) 1
    }

    proc GetTopLevel { widgetName } {
        regexp -- {\.[A-z,0-9]*} $widgetName topName
        return $topName
    }

    proc CloseSimpleTextEdit { w } {
        variable sExt

        if { [HasTextWidgetChanged $w] } {
            set retVal [tk_messageBox \
              -title "Confirmation" \
              -message "Save changed file before closing?" \
              -type yesnocancel -default yes -icon question]
            if { [string compare $retVal "yes"] == 0 } {
                SaveTextWidgetToFile $w
            } elseif { [string compare $retVal "cancel"] == 0 } {
                return
            }
        }
        if { $sExt($w,useToplevel) } {
            destroy [GetTopLevel $w]
        }
    }

    proc SetTitle { w title } {
        variable sExt

        poWin SetScrolledTitle $w $title
        if { $sExt($w,useToplevel) } {
            wm title [GetTopLevel $w] [format "%s" $title]
        }
    }

    proc TextContentChanged { w hasChanged } {
        variable sExt

        if { [$w edit modified] && $hasChanged } {
            set title [format "%s +" $sExt($w,fileName)]
            SetTitle $w $title
        } else {
            set title [format "%s" $sExt($w,fileName)]
            SetTitle $w $title
        }
    }

    proc UpdateTabs { w } {
        variable sExt

        if { ! [string is integer -strict $sExt($w,TabStop)] || \
             $sExt($w,TabStop) <= 0 } {
            return
        }
        set textFont [$w cget -font]
        set fontMeasure [expr {$sExt($w,TabStop) * [font measure $textFont 0] }]
        $w configure -tabs "$fontMeasure left" -tabstyle wordprocessor
    }

    proc ShowFontSelWin { w font } {
        set root [poWin GetRootWidget $w]
        lassign [winfo pointerxy $root] x y
        set selFont [poFontSel OpenWin $x $y $font]
        return $selFont
    }

    proc FontSettings { w mode } {
        variable sExt

        set selFont [ShowFontSelWin $w $sExt(Font,$mode)]
        if { $selFont ne "" } {
            set sExt(Font,$mode) $selFont
            UpdateFonts $mode
            $w configure -font $selFont
        }
    }

    proc ResetFont { w mode } {
        variable sExt

        set sExt(Font,$mode) [poWin GetFixedFont]
        UpdateFonts $mode
        $w configure -font [poWin GetFixedFont]
    }

    proc SelectFont { w } {
        variable sExt

        if { ! [winfo exists $w] } {
            return
        }
        set selFont [ShowFontSelWin $w $sExt($w,Font)]
        if { $selFont ne "" } {
            set sExt($w,Font) $selFont
            $w configure -font $selFont
        }
    }

    proc CutText { w } {
        tk_textCut $w
    }

    proc CopyText { w } {
        tk_textCopy $w
    }

    proc PasteText { w } {
        tk_textPaste $w
        $w see insert
    }

    proc _SetSearchButtonStates { textId state } {
        variable sExt

        $sExt($textId,btn,first) configure -state $state
        $sExt($textId,btn,last)  configure -state $state
        $sExt($textId,btn,prev)  configure -state $state
        $sExt($textId,btn,next)  configure -state $state
    }

    proc _ShowResult { textId ind } {
        variable sExt

        if { ! [info exists sExt(curIndex)] || \
             [llength $sExt(indices)] == 0 } {
            return
        }

        set curIndex $sExt(curIndex)
        $textId tag configure "found$curIndex" -background $sExt(CurrentColor)

        if { $ind == -1 || $ind == 1 } {
            set curIndex [expr $curIndex + $ind]
            set curIndex [poMisc Max $curIndex 0]
            set curIndex [poMisc Min $curIndex \
                                        [expr [llength $sExt(indices)] -1]]
        } elseif { $ind eq "end" } {
            set curIndex [expr [llength $sExt(indices)] -1]
        } else {
            set curIndex $ind
        }
        $textId tag configure "found$curIndex" -background "yellow"
        $textId see [lindex $sExt(indices) $curIndex]

        set sExt(curIndex) $curIndex
        $textId tag add sel [lindex $sExt(indices) $curIndex]
        $textId mark set insert [lindex $sExt(indices) $curIndex]

        _SetSearchButtonStates $textId "normal"
        if { $curIndex == 0 } {
            $sExt($textId,btn,first) configure -state disabled
            $sExt($textId,btn,prev)  configure -state disabled
        }
        if { $curIndex == [expr [llength $sExt(indices)] -1] } {
            $sExt($textId,btn,last) configure  -state disabled
            $sExt($textId,btn,next)  configure -state disabled
        }
    }

    proc SearchText { textId { searchStr "" } } {
        variable sExt

        if { $searchStr eq "" } {
            set searchStr [$sExt($textId,SearchCombo) get]
        }
        if { $searchStr eq "" } {
            return
        }

        # Check, if the current search pattern is contained in the
        # pattern list. If not, insert it at the list begin.
        set indSearch [lsearch -exact $sExt(SearchPattList) $searchStr]
        if { $indSearch < 0 } {
            set sExt(SearchPattList) [linsert $sExt(SearchPattList) 0 $searchStr]
        }
        # Now search again in the (possibly extended) list for the new position
        # of the search pattern and update the corresponding combo box.
        set indSearch [lsearch -exact $sExt(SearchPattList) $sExt($textId,SearchPatt)]
        _UpdateCombo $sExt($textId,SearchCombo) $sExt(SearchPattList) $indSearch

        set quotedSearch [poMisc QuoteSearchPattern $searchStr "exact" $sExt($textId,SearchWord)]

        set indexIn 1.0
        set countIn 0
        set i       0

        foreach tagName [$textId tag names] {
            $textId tag delete $tagName
        }

        set sExt(indices) [list]
        while { 1 } {
            if { $sExt($textId,SearchIgnCase) } {
                set indexOut [$textId search -count countOut -regexp -nocase -- \
                              $quotedSearch "$indexIn + $countIn chars" end]
            } else {
                set indexOut [$textId search -count countOut -regexp -- \
                              $quotedSearch "$indexIn + $countIn chars" end]
            }
            if { $indexOut eq "" } {
                break
            }

            lappend sExt(indices) $indexOut
            $textId tag add "result"  $indexOut "$indexOut + $countOut chars"
            $textId tag add "found$i" $indexOut "$indexOut + $countOut chars"

            set indexIn $indexOut
            set countIn $countOut
            incr i
        }
        $textId tag configure "result" -background $sExt(ResultColor)
        set sExt(curIndex) 0
        _ShowResult $textId 0
    }

    proc _SwitchLineNumbers { w } {
        variable sExt

        ShowLineNumbers $w $sExt($w,ShowLineNumbers)
    }

    proc ShowLineNumbers { w onOff } {
        variable sExt

        set rangeList [$w tag ranges linenum]
        if { $onOff && [llength $rangeList] > 0 } {
            return
        }

        set curState [$w cget -state]
        $w configure -state normal
        if { ! $onOff } {
            foreach { from to } $rangeList {
                $w delete $from $to
            }
        } else {
            set lastline [expr int([$w index "end - 1 c"])]
            for { set i 1 } { $i <= $lastline } { incr i } {
                $w insert $i.0 [format "%5d " $i] linenum
            }
        }
        $w edit reset
        $w edit modified false
        $w configure -state $curState
    }

    proc UpdateLineNumbers { mode } {
        variable sExt

        foreach key [array names sExt "*,ShowLineNumbers"] {
            set textId [lindex [split $key ","] 0]
            if { [winfo exists $textId] && $sExt($textId,DisplayMode) eq $mode } {
                set sExt($textId,ShowLineNumbers) $sExt(ShowLineNumbers,$mode)
                ShowLineNumbers $textId $sExt(ShowLineNumbers,$mode)
            }
        }
    }

    proc _SwitchWrapLines { w } {
        variable sExt

        $w configure -wrap $sExt($w,WrapLines)
    }

    proc UpdateWrapLines { mode } {
        variable sExt

        foreach key [array names sExt "*,WrapLines"] {
            set textId [lindex [split $key ","] 0]
            if { [winfo exists $textId] && $sExt($textId,DisplayMode) eq $mode } {
                set sExt($textId,WrapLines) $sExt(WrapLines,$mode)
                $textId configure -wrap $sExt(WrapLines,$mode)
            }
        }
    }

    proc UpdateTabStops { mode } {
        variable sExt

        foreach key [array names sExt "*,TabStop"] {
            set textId [lindex [split $key ","] 0]
            if { [winfo exists $textId] && $sExt($textId,DisplayMode) eq $mode } {
                set sExt($textId,TabStop) $sExt(TabStop,$mode)
                UpdateTabs $textId
            }
        }
    }

    proc UpdateFonts { mode } {
        variable sExt

        foreach key [array names sExt "*,Font"] {
            set textId [lindex [split $key ","] 0]
            if { [winfo exists $textId] && $sExt($textId,DisplayMode) eq $mode } {
                set sExt($textId,Font) $sExt(Font,$mode)
                $textId configure -font $sExt($textId,Font)
            }
        }
    }

    proc LoadFileIntoTextWidget { w fileName { maxBytes -1 } } {
        variable ns
        variable sExt

        set retVal [catch {open $fileName r} fp]
        if { $retVal != 0 } {
            error "Could not read file \"$fileName\"."
        }
        set numBytesFile [file size $fileName]
        if { $maxBytes < 0 } {
            set maxBytes $numBytesFile
        }
        set numBytesPerRead 2048
        if { $maxBytes < $numBytesPerRead } {
            set numBytesPerRead $maxBytes
        }

        set sExt($w,fileName) $fileName

        set curState [$w cget -state]
        $w configure -state normal
        $w delete 1.0 end
        set numBytesRead 0
        while { ! [eof $fp] && $numBytesRead <= $maxBytes } {
            $w insert end [read $fp $numBytesPerRead]
            incr numBytesRead $numBytesPerRead
        }
        if { ! [eof $fp] } {
            ttk::button $w.b -text "Load complete file" -command "${ns}::LoadFileIntoTextWidget $w \"$fileName\""
            $w insert end "\n"
            $w window create end -window $w.b
        }
        $w configure -state $curState
        close $fp
        $w edit reset
        $w edit modified false
        set sExt($w,changed) false
        $w configure -wrap $sExt($w,WrapLines)
        if { $sExt($w,ShowLineNumbers) } {
            ShowLineNumbers $w true
        }
    }

    proc SaveTextWidgetToFile { w { fileName "" } } {
        variable sExt

        if { $fileName eq "" } {
            if { [info exists sExt($w,fileName)] } {
                set fileName $sExt($w,fileName)
            }
        }

        # If line numbering is on, switch it off temporary
        # and switch it on back after writing.
        set haveLineNumbers false
        if { $sExt($w,ShowLineNumbers) } {
            set haveLineNumbers true
            ShowLineNumbers $w false
        }

        set retVal [catch {open $fileName w} fp]
        if { $retVal != 0 } {
            error "Could not write file \"$fileName\"."
        }
        fconfigure $fp -translation $sExt($w,SaveMode)
        puts -nonewline $fp [$w get 1.0 "end-1 chars"]
        close $fp

        if { $haveLineNumbers } {
            ShowLineNumbers $w true
        }
        $w edit modified false
        TextContentChanged $w false
        event generate $w <<SimpleTextEditSaved>> -data $fileName
    }

    proc AskSaveFile { w } {
        variable ns
        variable sExt

        set fileTypes {
            {"All files"        "*"}
            {"Ascii text files" ".txt"}
        }

        set initFile "SimpleTextEdit.txt"
        set haveFileName false
        if { [info exists sExt($w,fileName)] } {
            set initFile $sExt($w,fileName)
            set haveFileName true
        }

        if { ! [info exists sExt(LastTextType)] } {
            set sExt(LastTextType) [lindex [lindex $fileTypes 0] 0]
        }
        if { ! $haveFileName } {
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $fileTypes $sExt(LastTextType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save text file as" \
                     -parent $w \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sExt(LastTextType) \
                     -initialfile [file tail $initFile] \
                     -initialdir [file dirname $initFile]]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sExt(LastTextType)]
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

        if { $fileName != "" } {
            SaveTextWidgetToFile $w $fileName
        }
    }

    proc DumpFileIntoTextWidget { w fileName { updFlag false } { maxBytes -1 } } {
        variable ns
        variable sExt

        # Open the file, and set up to process it in binary mode.
        set catchVal [catch { open $fileName r } fp]
        if { $catchVal } {
            error "Could not read file \"$fileName\"."
        }
        fconfigure $fp -translation binary -encoding binary \
                       -buffering full -buffersize 16384

        set numBytesFile [file size $fileName]
        set bytesToRead $maxBytes
        if { $maxBytes < 0 } {
            set bytesToRead $numBytesFile
        }

        if { $updFlag } {
            set sExt(stopDump) 0
            bind $w <Escape> "${ns}::StopDump"
        }
        set curState [$w cget -state]
        $w configure -state normal
        $w delete 1.0 end
        set numBytesRead 0
        while { ! [eof $fp] } {
            # Record the seek address. Read 16 bytes from the file.
            set addr [tell $fp]
            set s [read $fp 16]
            incr numBytesRead 16

            # Convert the data to hex and to characters.
            binary scan $s H*@0a* hex ascii

            # Replace non-printing characters in the data.
            regsub -all -- {[^[:graph:] ]} $ascii {.} ascii

            # Split the 16 bytes into two 8-byte chunks
            set hex1 [string range $hex 0 15]
            set hex2 [string range $hex 16 31]

            # Convert the hex to pairs of hex digits
            regsub -all -- {..} $hex1 {& } hex1
            regsub -all -- {..} $hex2 {& } hex2

            # Put the hex and Latin-1 data to the channel
            set hexStr [format "%08X  %-24s %-24s %-16s\n" \
                                $addr $hex1 $hex2 $ascii]
            $w insert end $hexStr

            if { $numBytesRead >= $bytesToRead } {
                break
            }
            if { $updFlag } {
                $w see end
                if { $addr % 65536 == 0 } {
                    update
                }
                if { $sExt(stopDump) } {
                    break
                }
            }
        }

        if { $maxBytes >= 0 && $numBytesFile != $numBytesRead } {
            ttk::button $w.b -text "Load complete file" \
                             -command "${ns}::DumpFileIntoTextWidget $w \"$fileName\" $updFlag"
            $w insert end "\n"
            $w window create end -window $w.b
            if { $updFlag } {
                $w see end
            }
        }
        $w configure -state $curState
        close $fp
        $w edit reset
        $w edit modified false
        set sExt($w,changed) false
    }

    proc ShowSimpleTextDiff { fileName1 fileName2 } {
        variable sExt

        incr sExt(diffCount)

        set titleStr \
            "SimpleDiff: [file tail $fileName1] versus [file tail $fileName2]"
        set tw ".poExtProgSimpleTextDiff$sExt(diffCount)"

        toplevel $tw
        wm title $tw $titleStr
        ttk::frame $tw.workfr -relief sunken -borderwidth 1
        pack $tw.workfr -side top -fill both -expand 1

        set hMenu $tw.menufr
        menu $hMenu -borderwidth 2 -relief sunken

        $hMenu add cascade -menu $hMenu.file -label "File" -underline 0

        set fileMenu $hMenu.file
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Close" "Ctrl+W" "destroy $tw"

        bind $tw <Control-w> "destroy $tw"
        bind $tw <Escape>    "destroy $tw"
        wm protocol $tw WM_DELETE_WINDOW "destroy $tw"

        $tw configure -menu $hMenu

        set textList [poWin CreateSyncText $tw.workfr \
                      "$fileName1" "$fileName2" -wrap none]

        set textId1 [lindex $textList 0]
        set textId2 [lindex $textList 1]

        LoadFileIntoTextWidget $textId1 $fileName1
        LoadFileIntoTextWidget $textId2 $fileName2

        $textId1 configure -state disabled -cursor top_left_arrow
        $textId2 configure -state disabled -cursor top_left_arrow
        focus $tw
    }

    proc ShowSimpleHexDiff { fileName1 fileName2 } {
        variable sExt

        incr sExt(diffCount)

        set titleStr \
            "SimpleHexDiff: [file tail $fileName1] versus [file tail $fileName2]"
        set tw ".poExtProgSimpleHexDiff$sExt(diffCount)"

        toplevel $tw
        wm title $tw $titleStr
        ttk::frame $tw.workfr -relief sunken -borderwidth 1
        pack $tw.workfr -side top -fill both -expand 1

        set hMenu $tw.menufr
        menu $hMenu -borderwidth 2 -relief sunken

        $hMenu add cascade -menu $hMenu.file -label "File" -underline 0

        set fileMenu $hMenu.file
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Close" "Ctrl+W" "destroy $tw"

        bind $tw <Control-w> "destroy $tw"
        bind $tw <Escape>    "destroy $tw"
        wm protocol $tw WM_DELETE_WINDOW "destroy $tw"

        $tw configure -menu $hMenu

        set textList [poWin CreateSyncText $tw.workfr \
                      "$fileName1" "$fileName2" -wrap none]

        set textId1 [lindex $textList 0]
        set textId2 [lindex $textList 1]

        focus $tw
        $tw configure -cursor watch

        $textId1 configure -font [poWin GetFixedFont]
        $textId2 configure -font [poWin GetFixedFont]
        update

        DumpFileIntoTextWidget $textId1 $fileName1 true
        DumpFileIntoTextWidget $textId2 $fileName2 true

        $textId1 configure -state disabled
        $textId2 configure -state disabled
        $tw configure -cursor top_left_arrow
    }

    proc ShowTkDiffHexDiff { fileName1 fileName2 } {

        set tmpDir [poMisc GetTmpDir]
        set tmpFileName1 [format "Left_%s"  [file tail $fileName1]]
        set tmpFileName2 [format "Right_%s" [file tail $fileName2]]
        set tmpFileName1 [file join $tmpDir $tmpFileName1]
        set tmpFileName2 [file join $tmpDir $tmpFileName2]

        poMisc HexDumpToFile $fileName1 $tmpFileName1
        poMisc HexDumpToFile $fileName2 $tmpFileName2

        ShowTkDiff [list $tmpFileName1 $tmpFileName2]
    }

    proc _UpdateCombo { cb typeList showInd } {
        if { $showInd >= 0 } {
            $cb configure -values $typeList
            $cb current $showInd
        }
    }

    proc _UseMarkedText { comboName textId } {
        variable sExt

        tk_textCopy $textId
        $sExt($comboName) set [clipboard get]
    }

    proc _Undo { textId } {
        if { [$textId edit canundo] } {
            $textId edit undo
        }
    }

    proc _Redo { textId } {
        if { [$textId edit canredo] } {
            $textId edit redo
        }
    }

    proc _CheckUndoRedoButtons { textId } {
        variable sExt

        if { ! [winfo exists $textId] } {
            return
        }
        if { [info exists sExt($textId,UndoBtn)] && [winfo exists $sExt($textId,UndoBtn)] } {
            if { [$textId edit canundo] } {
                $sExt($textId,UndoBtn) configure -state normal
            } else {
                $sExt($textId,UndoBtn) configure -state disabled
            }
        }
        if { [info exists sExt($textId,RedoBtn)] && [winfo exists $sExt($textId,RedoBtn)] } {
            if { [$textId edit canredo] } {
                $sExt($textId,RedoBtn) configure -state normal
            } else {
                $sExt($textId,RedoBtn) configure -state disabled
            }
        }
    }

    proc ShowSimpleTextEdit { fileName { tw "" } { showButtons false } args } {
        variable ns
        variable sExt

        incr sExt(editCount)

        set useToplevel false

        set titleStr "SimpleEdit: [file tail $fileName]"

        if { $tw eq "" } {
            set useToplevel true

            set tw ".poExtProgSimpleTextEdit$sExt(editCount)"

            toplevel $tw
            wm title $tw $titleStr
        }
        if { $showButtons } {
            ttk::frame $tw.toolfr -relief groove -borderwidth 1
            pack $tw.toolfr -side top -fill x
        }
        ttk::frame $tw.workfr -relief ridge 
        pack $tw.workfr -side top -fill both -expand 1

        set textId [poWin CreateScrolledText $tw.workfr true "$fileName" {*}$args]
        set sExt($textId,fileName) $fileName
        $textId tag configure linenum -background yellow

        if { $useToplevel } {
            set hMenu $tw.menufr
            menu $hMenu -borderwidth 2 -relief sunken
            $hMenu add cascade -menu $hMenu.file -label "File"     -underline 0

            set fileMenu $hMenu.file
            menu $fileMenu -tearoff 0
            poMenu AddCommand $fileMenu "Close" "Ctrl+W" "${ns}::CloseSimpleTextEdit $textId"

            $tw configure -menu $hMenu
        }

        set sExt($textId,DisplayMode)     "preview"
        set sExt($textId,ShowLineNumbers) $sExt(ShowLineNumbers,preview)
        set sExt($textId,WrapLines)       $sExt(WrapLines,preview)
        set sExt($textId,TabStop)         $sExt(TabStop,preview)
        set sExt($textId,Font)            $sExt(Font,preview)

        set sExt($textId,SearchIgnCase)   $sExt(SearchIgnCase)
        set sExt($textId,SearchWord)      $sExt(SearchWord)
        set sExt($textId,SaveMode)        $sExt(SaveMode)

        if { $showButtons } {
            set sExt($textId,DisplayMode)     "edit"
            set sExt($textId,ShowLineNumbers) $sExt(ShowLineNumbers,edit)
            set sExt($textId,WrapLines)       $sExt(WrapLines,edit)
            set sExt($textId,TabStop)         $sExt(TabStop,edit)
            set sExt($textId,Font)            $sExt(Font,edit)

            # Add new toolbar group and associated buttons.
            set toolfr $tw.toolfr
            poToolbar New $toolfr
            poToolbar AddGroup $toolfr

            poToolbar AddButton $toolfr [::poBmpData::save] \
                      "${ns}::AskSaveFile $textId" "Save as ... (Ctrl+S)\nSave (Ctrl+Shift+S)"
            poToolbar AddRadioButton $toolfr "LF" "" "Set EOL to Unix" \
                      -value "lf" -variable ${ns}::sExt($textId,SaveMode)
            poToolbar AddRadioButton $toolfr "CRLF" "" "Set EOL to Dos" \
                      -value "crlf" -variable ${ns}::sExt($textId,SaveMode)
            poToolbar AddRadioButton $toolfr "CR" "" "Set EOL to Mac" \
                      -value "cr" -variable ${ns}::sExt($textId,SaveMode)

            # Add new toolbar group and associated buttons.
            poToolbar AddGroup $toolfr
            set sExt($textId,UndoBtn) [poToolbar AddButton $toolfr [::poBmpData::undo] \
                      "${ns}::_Undo $textId" "Undo (Ctrl+Z)"]
            set sExt($textId,RedoBtn) [poToolbar AddButton $toolfr [::poBmpData::redo] \
                      "${ns}::_Redo $textId" "Redo (Ctrl+Y)"]
            bind $textId <Control-z>   "${ns}::_Undo $textId"
            bind $textId <Control-y>   "${ns}::_Redo $textId"
            bind $textId <<UndoStack>> "${ns}::_CheckUndoRedoButtons $textId"

            # Add new toolbar group and associated buttons.
            poToolbar AddGroup $toolfr

            poToolbar AddButton $toolfr [::poBmpData::cut] \
                      "${ns}::CutText $textId" "Cut (Ctrl+X)"
            poToolbar AddButton $toolfr [::poBmpData::copy] \
                      "${ns}::CopyText $textId" "Copy (Ctrl+C)"
            poToolbar AddButton $toolfr [::poBmpData::paste] \
                      "${ns}::PasteText $textId" "Paste (Ctrl+V)"

            # Add new toolbar group and associated buttons.
            poToolbar AddGroup $tw.toolfr

            poToolbar AddCheckButton $tw.toolfr [::poBmpData::searchcase] \
                      "" "Search case insensitive" -variable ${ns}::sExt($textId,SearchIgnCase) \
                      -onvalue true -offvalue false
            poToolbar AddCheckButton $tw.toolfr [::poBmpData::searchword] \
                      "" "Match words only" -variable ${ns}::sExt($textId,SearchWord) \
                      -onvalue true -offvalue false

            if { ! [info exists sExt($textId,SearchPatt)] } {
                set sExt($textId,SearchPatt) ""
            }
            if { ! [info exists sExt(SearchPattList)] } {
                set sExt(SearchPattList) [list]
            }
            # Check, if the current search pattern is contained in the pattern list.
            # If not, insert them at the list begin.
            set indSearch [lsearch -exact $sExt(SearchPattList) $sExt($textId,SearchPatt)]
            if { $indSearch < 0 && $sExt($textId,SearchPatt) ne "" } {
                set sExt(SearchPattList) [linsert $sExt(SearchPattList) 0 $sExt($textId,SearchPatt)]
                set indSearch 0
            }

            set sExt($textId,SearchCombo) [poToolbar AddCombobox $tw.toolfr ${ns}::sExt($textId,SearchPatt) "" -width 15]
            ${ns}::_UpdateCombo $sExt($textId,SearchCombo) $sExt(SearchPattList) $indSearch
            poToolhelp AddBinding $sExt($textId,SearchCombo) "Use F4 to copy selected text"

            set sExt($textId,btn,first) [poToolbar AddButton $tw.toolfr [::poBmpData::top] \
                      "${ns}::_ShowResult $textId 0" "Go to first occurence"]
            set sExt($textId,btn,prev) [poToolbar AddButton $tw.toolfr [::poBmpData::up] \
                      "${ns}::_ShowResult $textId -1" "Go to previous occurence"]
            set sExt($textId,btn,next) [poToolbar AddButton $tw.toolfr [::poBmpData::down] \
                      "${ns}::_ShowResult $textId 1" "Go to next occurence"]
            set sExt($textId,btn,last) [poToolbar AddButton $tw.toolfr [::poBmpData::bottom] \
                      "${ns}::_ShowResult $textId end" "Go to last occurence"]

            _SetSearchButtonStates $textId "disabled"

            bind $sExt($textId,SearchCombo) <Key-F3>     "${ns}::SearchText $textId"
            bind $sExt($textId,SearchCombo) <Key-Return> "${ns}::SearchText $textId"
            bind $textId <Key-F3> "${ns}::SearchText $textId"
            bind $textId <Key-F4> "${ns}::_UseMarkedText $textId,SearchCombo $textId"

            # Add new toolbar group and associated buttons.
            poToolbar AddGroup $toolfr
            poToolbar AddCheckButton $toolfr [::poBmpData::linenum] \
                      "${ns}::_SwitchLineNumbers $textId" "Toggle line numbers" \
                      -variable ${ns}::sExt($textId,ShowLineNumbers) \
                      -onvalue true -offvalue false
            poToolbar AddCheckButton $toolfr [::poBmpData::wrapline] \
                      "${ns}::_SwitchWrapLines $textId" "Toggle line wrap" \
                      -variable ${ns}::sExt($textId,WrapLines) \
                      -onvalue word -offvalue none

            poToolbar AddGroup $toolfr
            poToolbar AddButton $toolfr [::poBmpData::halt "red"] \
                      ${ns}::StopDump "Stop file loading (Esc)"

            poToolbar AddGroup $toolfr
            poToolbar AddButton $toolfr [::poBmpData::clear] "${ns}::SelectFont $textId" "Select font"

            set comboId [poToolbar AddCombobox $toolfr ${ns}::sExt($textId,TabStop) "Tabstop width" \
                        -values [list 1 2 3 4 8] -state readonly -width 2 -takefocus 0]
            bind $comboId <<ComboboxSelected>> "${ns}::UpdateTabs $textId"

            bind $textId <Control-s> "${ns}::AskSaveFile $textId"
            bind $textId <Control-Shift-Key-S> "${ns}::SaveTextWidgetToFile $textId"
        }
        UpdateTabs $textId
        if { $showButtons } {
            $textId configure -font $sExt(Font,edit)
        } else {
            $textId configure -font $sExt(Font,preview)
        }

        if { $useToplevel } {
            bind $textId <Control-w> "${ns}::CloseSimpleTextEdit $textId"
            bind $textId <Escape>    "${ns}::CloseSimpleTextEdit $textId"
            wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseSimpleTextEdit $textId"
        }

        set retVal [catch { LoadFileIntoTextWidget $textId $fileName }]
        if { $retVal != 0 } {
            poWin SetScrolledTitle $textId "$fileName (Not existent)"
        }
        $textId configure -cursor top_left_arrow
        focus $tw

        set sExt($textId,useToplevel) $useToplevel

        # Add this binding after reading of content, as reading generates a
        # modified event.
        bind $textId <<Modified>> "${ns}::TextContentChanged $textId true"
        _CheckUndoRedoButtons $textId
        return $textId
    }

    proc SaveHexEdit { w initFile } {
        variable ns
        variable sExt

        set fileTypes {
                {"Ascii dump files" ".dump"}
                {"All files"        "*"} }

        set dumpDir  [file dirname $initFile]
        set dumpFile [format "%s.dump" [file tail $initFile]]

        if { ! [info exists sExt(LastDumpType)] } {
            set sExt(LastDumpType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sExt(LastDumpType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save hexdump as Asciii file" \
                     -parent $w \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sExt(LastDumpType) \
                     -initialfile $dumpFile \
                     -initialdir $dumpDir]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sExt(LastDumpType)]
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

        if { $fileName != "" } {
            set retVal [catch {open $fileName w} fp]
            if { $retVal != 0 } {
                error "Could not write file \"$fileName\"."
            }
            puts $fp [$w get 1.0 end]
            close $fp
        }
    }

    proc CloseHexEdit { w } {
        variable sExt

        set sExt(stopDump) 1
        update
        destroy $w
    }

    proc ShowSimpleHexEdit { fileName } {
        variable ns
        variable sExt

        incr sExt(hexCount)

        set titleStr "SimpleHexEdit: [file tail $fileName]"
        set tw ".poExtProgSimpleHexEdit$sExt(hexCount)"

        toplevel $tw
        wm title $tw $titleStr

        ttk::frame $tw.toolfr -relief groove -borderwidth 1
        pack $tw.toolfr -side top -fill x

        ttk::frame $tw.workfr -relief sunken -borderwidth 1
        pack $tw.workfr -side top -fill both -expand 1

        set hMenu $tw.menufr
        menu $hMenu -borderwidth 2 -relief sunken
        $hMenu add cascade -menu $hMenu.file -label File -underline 0

        set textId [poWin CreateScrolledText $tw.workfr true "$fileName" -wrap none]

        set fileMenu $hMenu.file
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Save as ..." "Ctrl+S" "${ns}::SaveHexEdit $textId [list $fileName]"
        poMenu AddCommand $fileMenu "Close"       "Ctrl+W" "${ns}::CloseHexEdit $tw"

        bind $tw <Control-s> "${ns}::SaveHexEdit $textId [list $fileName]"
        bind $tw <Control-w> "${ns}::CloseHexEdit $tw"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseHexEdit $tw"

        poToolbar New $tw.toolfr
        poToolbar AddGroup $tw.toolfr
        poToolbar AddButton $tw.toolfr [::poBmpData::save] \
                  "${ns}::SaveHexEdit $textId [list $fileName]" "Save as ... (Ctrl+S)"

        poToolbar AddGroup $tw.toolfr
        poToolbar AddButton $tw.toolfr [::poBmpData::halt "red"] \
                  ${ns}::StopDump "Stop file loading (Esc)"

        $tw configure -menu $hMenu

        focus $textId
        $textId configure -cursor watch
        $textId configure -font [poWin GetFixedFont]
        update

        DumpFileIntoTextWidget $textId $fileName true
        catch {$textId configure -state disabled -cursor top_left_arrow}
    }

    proc SupportsAsso { } {
        global tcl_platform

        if { $tcl_platform(platform) eq "windows" || \
	     $tcl_platform(os) eq "Darwin" || \
             $tcl_platform(os) eq "Linux" } {
            return true
        } else {
            return false
        }
    }

    proc StartAssoProg { fileList infoCB } {
        # Start program associated with a file.
        #
        # fileList  - List of files to open.
        # infoCB    - Callback function with one string parameter.
        #
        # This function is available only on operating systems,
        # which provide association rules with files.
        # Windows for example uses the file extension for association.
        #
        # No return value.
        #
        # See also: StartEditProg StartDiffProg

        StartEditProg $fileList $infoCB 1
    }

    proc StartEditProg { fileList { infoCB "" } { assoc 0 } } {
        global env tcl_platform
        variable sExt

        set count 0
        foreach fileName $fileList {
            # Convert native name back to Unix notation
            set name [file normalize $fileName]

            set prog [poFileType GetEditProg $name]
            if { $prog eq "poImgview" && ! $assoc } {
                poApps StartApp $prog $name
                continue
            }
            if { $prog ne "" } {
                set prog [GetSpecificProg $prog]
            }
            if { $prog eq "" } {
                if { [info exists env(EDITOR)] && [auto_execok $env(EDITOR)] ne "" } {
                    set prog $env(EDITOR)
                }
            }
            if { ($prog eq "" || [auto_execok $prog] eq "") && ! $assoc } {
                ShowSimpleTextEdit $name "" true \
                    -width 80 -height 20 -wrap none -exportselection true \
                    -undo true -font [poWin GetFixedFont]
                if { $infoCB ne "" } {
                    $infoCB "No editor rule found for: $name" "Warning"
                }
                continue
            }

            set fork "&"
            incr count
            if { $count > $sExt(maxShowWin) } {
                set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "Load next file $name ?" \
                  -type yesnocancel -default yes -icon question]
                if { $retVal eq "cancel" } {
                    return
                } elseif { $retVal eq "no" } {
                    continue
                }
            }
            if { $assoc && [SupportsAsso] } {
                if { $infoCB ne "" } {
                    $infoCB "Loading file $name with associated program" "Ok"
                }
                set nativeFileName [file nativename $name]
                if { $tcl_platform(platform) eq "windows" } {
                    if {[file exists $env(COMSPEC)]} {
                        eval exec [list $env(COMSPEC)] /c start \
                                  [list $nativeFileName] $fork
                    } else {
                        eval exec command /c start [list $nativeFileName] $fork
                    }
                } elseif { $tcl_platform(os) eq "Darwin" } {
                    eval exec open $nativeFileName $fork
                } elseif { $tcl_platform(os) eq "Linux" } {
                    eval exec xdg-open $nativeFileName $fork
                }
            } else {
                if { $prog eq "" } {
                    if { $infoCB ne "" } {
                        $infoCB "No editor rule found for: $name" "Warning"
                    }
                    ShowSimpleTextEdit $name "" true \
                        -width 80 -height 20 -wrap none -exportselection true \
                        -undo true -font [poWin GetFixedFont]
                } else {
                    if { $infoCB ne "" } {
                        $infoCB "Loading file $name with program $prog" "Ok"
                    }
                    eval exec $prog [list $name] $fork
                }
            }
        }
    }

    proc StartOneEditProg { fileList { infoCB "" } { assoc 0 } } {
        global env tcl_platform

        set firstFile [lindex $fileList 0]
        set prog [poFileType GetEditProg $firstFile]
        if { $prog eq "poImgview" && ! $assoc } {
            poApps StartApp $prog $fileList
            return
        }
        if { $prog ne "" } {
            set prog [GetSpecificProg $prog]
        }
        if { $prog eq "" } {
            if { [info exists env(EDITOR)] && [auto_execok $env(EDITOR)] ne "" } {
                set prog $env(EDITOR)
            }
        }
        if { $prog eq "" && ! $assoc } {
            ShowSimpleTextEdit $firstFile "" true \
                -width 80 -height 20 -wrap none -exportselection true \
                -undo true -font [poWin GetFixedFont]
            if { $infoCB ne "" } {
                $infoCB "No editor rule found for: $firstFile" "Warning"
            }
            return
        } else {
            if { $assoc && [SupportsAsso] } {
                if { $infoCB ne "" } {
                    $infoCB "Loading files with associated program" "Ok"
                }
                if { $tcl_platform(platform) eq "windows" } {
                    if {[file exists $env(COMSPEC)]} {
                        eval exec [list $env(COMSPEC)] /c start $fileList &
                    } else {
                        eval exec command /c start $fileList &
                    }
                } elseif { $tcl_platform(os) eq "Darwin" } {
                    eval exec open $fileList &
                } elseif { $tcl_platform(os) eq "Linux" } {
                    eval exec xdg-open $fileList &
                }
            } else {
                if { $infoCB ne "" } {
                    $infoCB "Loading files with program $prog" "Ok"
                }
                eval exec $prog $fileList &
            }
        }
    }

    proc GetSpecificProg { prog } {
        set specProg $prog
        if { [auto_execok $prog] eq "" } {
            if { $::tcl_platform(os) eq "Darwin" } {
                set specProg [format "open -a $prog " $prog]
            }
        }
        return $specProg
    }

    proc StartHexEditProg { fileList {infoCB ""} {serialize 1} } {
        global env tcl_platform
        variable sExt

        set count 0
        foreach fileName $fileList {
            # Convert native name back to Unix notation
            set name [file normalize $fileName]

            set prog [poFileType GetHexEditProg $name]
            if { $prog ne "" } {
                set prog [GetSpecificProg $prog]
            }
            if { $prog eq "" } {
                ShowSimpleHexEdit $name
                if { $infoCB ne "" } {
                    $infoCB "No hexdump rule found for: $name" "Warning"
                }
                continue
            }

            set fork "&"
            if { $serialize } {
                set fork ""
            }
            incr count
            if { $serialize || $count > $sExt(maxShowWin) } {
                set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "Load next file $name ?" \
                  -type yesnocancel -default yes -icon question]
                if { $retVal eq "cancel" } {
                    return
                } elseif { $retVal eq "no" } {
                    continue
                }
            }
            if { $infoCB ne "" } {
                $infoCB "Loading file $name with program $prog" "Ok"
            }
            eval exec $prog [list $name] $fork
        }
    }

    proc ShowTkDiff { argList } {
        variable sExt

        if { ! $sExt(tkdiffSourced) } {
            if { [info exists      starkit::topdir] && \
                 [file isdirectory $starkit::topdir] } {
                set libDir [file join $starkit::topdir "lib"]
            } else {
                set libDir [poApps GetScriptDir]
            }
            uplevel #0 source [list [file join $libDir "tkdiff.tcl"]]
            set sExt(tkdiffSourced) 1
        }

        set leftFile  ""
        set rightFile ""
        set curArg 0
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [poMisc IsReadableFile $curParam] } {
                if { $leftFile eq "" } {
                    set leftFile [file normalize $curParam]
                } else {
                    set rightFile [file normalize $curParam]
                }
            }
            incr curArg
        }
        tkdiff-main $leftFile $rightFile
    }

    proc StartDiffProg { leftFileList rightFileList infoCB { serialize 0 } } {
        variable sExt

        set count 0
        foreach fileName1 $leftFileList fileName2 $rightFileList {
            # Convert native name back to Unix notation
            set name1 [file normalize $fileName1]
            set name2 [file normalize $fileName2]

            set prog [poFileType GetDiffProg $name1]
            if { $prog eq "poImgdiff" } {
                poApps StartApp $prog [list $name1 $name2]
                continue
            } elseif { $prog eq "ExcelDiff" && [poApps HavePkg "cawt"] } {
                eval ::Excel::DiffExcelFiles [list $name1 $name2]
                continue
            } elseif { $prog eq "WordDiff" && [poApps HavePkg "cawt"] } {
                eval ::Word::DiffWordFiles [list $name1 $name2]
                continue
            }
            if { $prog ne "" } {
                set prog [GetSpecificProg $prog]
            }
            if { $prog eq "" } {
                $infoCB "No diff rule found for: $name1" "Warning"
                if { ! [poType IsBinary $name1] && ! [poType IsBinary $name2] } {
                    ShowTkDiff [list $name1 $name2]
                } else {
                    ShowTkDiffHexDiff $name1 $name2
                }
                continue
            }

            set fork "&"
            if { $serialize } {
                set fork ""
            }

            incr count
            if { $serialize || $count > $sExt(maxShowWin) } {
                set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "Load next diff: $name1 vs. $name2 ?" \
                  -type yesnocancel -default yes -icon question]
                if { $retVal eq "cancel" } {
                    return
                } elseif { $retVal eq "no" } {
                    continue
                }
            }
            $infoCB "Diff'ing $name1 and $name2 with program $prog" "Ok"
            eval exec $prog [list $name1] [list $name2] $fork
        }
    }

    proc StartFileBrowser { dir } {
        if { $::tcl_platform(platform) eq "windows" } {
            set browserProg "explorer"
        } elseif { $::tcl_platform(os) eq "Linux" } {
            foreach prog [list "dolphin" "konqueror" "nautilus"] {
                if { [auto_execok $prog] ne "" } {
                    set browserProg $prog
                    break
                }
            }
            if { $browserProg eq "" } {
                error "No file browser found. Looked for dolphin, konqueror and nautilus."
            }
        } elseif { $::tcl_platform(os) eq "Darwin" } {
            set browserProg "open"
        } elseif { $::tcl_platform(os) eq "SunOS" } {
            set browserProg "filemgr -d"
        } elseif { [string match "IRIX*" $::tcl_platform(os)] } {
            set browserProg "fm"
        } else {
            set browserProg "xterm -e ls"
        }
        if { [file isdirectory $dir] } {
            eval exec $browserProg [list [file nativename $dir]] &
        }
    }

    proc OpenUrl { url } {
        if { $::tcl_platform(platform) eq "windows" } {
            if { [file exists $::env(COMSPEC)] } {
                eval exec [list $::env(COMSPEC)] /c start [list $url] &
            } else {
                eval exec command /c start [list $url] &
            }
        } elseif { $::tcl_platform(os) eq "Darwin" } {
            eval exec open [list $url] &
        } elseif { $::tcl_platform(os) eq "Linux" } {
            eval exec xdg-open [list $url] &
        } else {
            eval exec [list $url] &
        }
    }

    proc GetExecutable { title } {
        global tcl_platform

        set progSuffix "*"
        if { $tcl_platform(platform) eq "windows" } {
            set progSuffix ".exe"
        }
        if { $tcl_platform(os) eq "Darwin" } {
            set progSuffix ".app"
        }
        set fileTypes [list \
            [list Programs  $progSuffix] \
            [list "All files" *]]

        set fileName [tk_getOpenFile -filetypes $fileTypes -title $title]
        if { $fileName ne "" } {
            set fileName [format "\"%s\"" $fileName]
        }
        return $fileName
    }
}

poExtProg Init
