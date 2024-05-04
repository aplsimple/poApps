# Module:         poWinClipboard
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2023 / 04 / 15
#
# Distributed under BSD license.
#
# Module for graphical user interface for the Windows clipboard.

namespace eval poWinClipboard {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export IsStandalone
    namespace export IsToplevel
    namespace export OpenClipboardWin
    namespace export CloseClipboardWin

    proc Init {} {
        variable ns
        variable sPo
        variable sPreviewTabs

        set sPo(appName) "poClipboardViewer"

        set sPo(LastDir)      [pwd]
        set sPo(LastSeqNum)   0
        set sPo(IsStandalone) [expr ! [namespace exists ::poApps]]

        set sPreviewTabs(ascii)  0
        set sPreviewTabs(binary) 1
        set sPreviewTabs(image)  2

        set sPo(UsedPkgs) "Tcl Tk Img scrollutil_tile tablelist_tile twapi"
    }

    proc IsStandalone {} {
        variable sPo

        return $sPo(IsStandalone)
    }

    proc IsToplevel {} {
        variable sPo

        return [expr { $sPo(toplevel) ne "" }]
    }

    proc GetVersionNumber {} {
        return "2.12.0"
    }

    proc GetVersion {} {
        variable sPo

        return "$sPo(appName) [GetVersionNumber] ([poMisc GetOSBitsStr])"
    }

    proc GetBuildInfo {} {
        set buildNumber "Developer"
        set buildDate   "N/A"
        if { [info procs GetBuildNumber] ne "" } {
            set buildNumber [GetBuildNumber]
        }
        if { [info procs GetBuildDate] ne "" } {
            set buildDate [GetBuildDate]
        }
        return [format "Build: %s (Date: %s)" $buildNumber $buildDate]
    }

    proc GetCopyright {} {
        return "Copyright 2023 Paul Obermeier"
    }

    proc HelpProg { { splashWin "" } } {
        variable sPo

        poSoftLogo ShowLogo [GetVersion] [GetBuildInfo] [GetCopyright] $splashWin
        if { $splashWin ne "" } {
            poSoftLogo DestroyLogo
        }
    }

    proc HelpTcl {} {
        set pkgs "Tcl Tk Img scrollutil_tile tablelist_tile twapi"
        if { ! [poMisc HaveTcl87OrNewer] } {
            append pkgs " tksvg"
        }
        poSoftLogo ShowTclLogo {*}$pkgs
    }

    proc ClearPreviews {} {
        variable sPo
        variable sPreviewTabs

        foreach type [array names sPreviewTabs] {
            $sPo(previewId,$type) configure -state normal
            $sPo(previewId,$type) delete 1.0 end
            $sPo(previewId,$type) configure -state disabled
            poExtProg SetTitle $sPo(previewId,$type) "No data available"
            $sPo(nbId) tab $sPreviewTabs($type) -state disabled
        }
    }

    proc ShowDirOrFile { lineNum } {
        variable sPo

        set dirOrFileName [$sPo(previewId,ascii) get $lineNum.0 $lineNum.end]
        if { [file isdirectory $dirOrFileName] } {
            poExtProg StartFileBrowser $dirOrFileName
        } elseif { [file exists $dirOrFileName] } {
            poWinInfo CreateInfoWin $dirOrFileName -tab "Preview"
        } else {
            WriteInfoStr "$dirOrFileName not existent" "Warning"
        }
    }

    proc ClipboardCallback {} {
        variable ns
        variable sPo
        variable sClipboard

        set retVal [catch { twapi::open_clipboard }]
        if { $retVal != 0 } {
            return
        }

        set seqNum [twapi::get_clipboard_sequence]
        if { $seqNum < $sPo(LastSeqNum) } {
            WriteInfoStr "No clipboard update occured." "Cancel"
            return
        }
        set sPo(LastSeqNum) $seqNum

        set updateTime [clock format [clock seconds] -format "%H:%M:%S"]
        poWin SetScrolledTitle $sPo(tableId) "Clipboard updated at $updateTime"

        set retVal [catch { twapi::get_clipboard_formats } clipboardFormats]
        if { $retVal != 0 } {
            return
        }

        $sPo(tableId) delete 0 end
        ClearPreviews
        catch { unset sClipboard }

        set hwin [twapi::get_clipboard_owner]
        set owner "unknown application"
        if { [lindex $hwin 0] != 0 } {
            set pid   [twapi::get_window_process $hwin]
            set owner [twapi::get_process_name $pid]
        }
        set count 0
        foreach fmtNum [lsort -integer $clipboardFormats] {
            set retVal [catch { twapi::get_registered_clipboard_format_name $fmtNum } name]
            if { $retVal != 0 } {
                set name [poWinCapture GetSystemFormatName $fmtNum]
            }
            set size -1
            if { $fmtNum == 2 } {
                # Format CF_BITMAP causes twapi::read_clipboard to crash very often.
                # Sometimes it works and produces: Invalid handle.
                set sClipboard(data,$fmtNum) "Invalid handle"
            } else {
                set retVal [catch {twapi::read_clipboard $fmtNum} sClipboard(data,$fmtNum)]
                if { $retVal == 0 } {
                    set size [string length $sClipboard(data,$fmtNum)]
                }
            }
            $sPo(tableId) insert end [list "" $name $size $fmtNum [format "%04X" $fmtNum]]
            incr count
        }
        twapi::close_clipboard
        if { $count == 1 } {
            WriteInfoStr "Clipboard contains $count entry inserted by $owner" "Ok"
        } else {
            WriteInfoStr "Clipboard contains $count entries inserted by $owner" "Ok"
        }
    }

    proc ShowPreview { tableId } {
        variable ns
        variable sPo
        variable sPreviewTabs
        variable sClipboard

        set isRowSelected [poTablelistUtil IsRowSelected $tableId]
        poWin ToggleSwitchableWidgets "RowSelected" $isRowSelected

        if { ! $isRowSelected } {
            return
        }

        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set fmtNum  [poTablelistUtil GetCellValue $tableId $row 3]
        set fmtName [poTablelistUtil GetCellValue $tableId $row 1]

        ClearPreviews
        # Use 1024 bytes to check for binary data.
        # If the string is less than 1024 bytes, skip the last byte,
        # which may be the NULL terminator.
        set len [string length $sClipboard(data,$fmtNum)]
        set maxBytes 1024
        set endRange [expr {$maxBytes - 1}]
        if { $len <= $maxBytes } {
            set endRange [expr {$len - 2}]
        }

        # Fill either binary or ASCII widgets.
        if { [poType IsBinaryString [string range $sClipboard(data,$fmtNum) 0 $endRange]] } {
            set title [format "Binary data in format %s: Size %d bytes" $fmtName $len]
            poExtProg SetTitle $sPo(previewId,binary) $title
            poExtProg DumpStringIntoTextWidget $sPo(previewId,binary) $sClipboard(data,$fmtNum) -maxbytes [poWinPreview GetMaxBytes]
            set selTabInd $sPreviewTabs(binary)
            $sPo(nbId) tab $sPreviewTabs(binary) -state normal
        } else {
            set title [format "ASCII data in format %s: Size %d bytes" $fmtName $len]
            poExtProg SetTitle $sPo(previewId,ascii) $title
            poExtProg LoadStringIntoTextWidget $sPo(previewId,ascii) $sClipboard(data,$fmtNum) -maxbytes [poWinPreview GetMaxBytes]
            set selTabInd $sPreviewTabs(ascii)
            $sPo(nbId) tab $sPreviewTabs(ascii) -state normal
        }

        # Additionally ASCII widget, if clipboard data is Unicode.
        if { $fmtName eq "CF_UNICODETEXT" || $fmtName eq "FileNameW" } {
            set title [format "Unicode data in format %s: Size %d bytes" $fmtName $len]
            poExtProg SetTitle $sPo(previewId,ascii) $title
            poExtProg LoadStringIntoTextWidget $sPo(previewId,ascii) \
                      [encoding convertfrom unicode $sClipboard(data,$fmtNum)] -maxbytes [poWinPreview GetMaxBytes]
            set selTabInd $sPreviewTabs(ascii)
            $sPo(nbId) tab $sPreviewTabs(ascii) -state normal
        }

        if { $fmtName eq "CF_HDROP" } {
            set pathList [poWinCapture GetPathList]
            set numPaths [llength $pathList]
            set title [format "Path data in format %s: %d entries" $fmtName $numPaths]
            poExtProg SetTitle $sPo(previewId,ascii) $title
            set lineNum 1
            foreach path $pathList {
                poExtProg LoadStringIntoTextWidget $sPo(previewId,ascii) "${path}\n" -clear false
                
                $sPo(previewId,ascii) tag add $lineNum $lineNum.0 $lineNum.end
                $sPo(previewId,ascii) tag bind $lineNum <1> [list ${ns}::ShowDirOrFile $lineNum]
                $sPo(previewId,ascii) tag bind $lineNum <Enter> [list  $sPo(previewId,ascii) configure -cursor hand2]
                $sPo(previewId,ascii) tag bind $lineNum <Leave> [list  $sPo(previewId,ascii) configure -cursor arrow]
                $sPo(previewId,ascii) tag configure $lineNum -foreground "#0066CC" -underline true
                incr lineNum
            }
            set selTabInd $sPreviewTabs(ascii)
            $sPo(nbId) tab $sPreviewTabs(ascii) -state normal
        }

        # Additionally fill Image widget, if clipboard data can be interpreted by the Img extension.
        catch { image delete $sPo(phImg) }
        set retVal [catch { poWinCapture Clipboard2Img $fmtNum } sPo(phImg)]
        if { $retVal == 0 } {
            set title [format "Image in format %s: Size %dx%d pixel" \
                      [poTablelistUtil GetCellValue $tableId $row 1] \
                      [image width $sPo(phImg)] \
                      [image height $sPo(phImg)]]
            poExtProg SetTitle $sPo(previewId,image) $title
            $sPo(previewId,image) image create 1.0 -image $sPo(phImg) -align center
            set selTabInd $sPreviewTabs(image)
            $sPo(nbId) tab $sPreviewTabs(image) -state normal
        }
        $sPo(nbId) select $selTabInd
    }

    proc AskSaveClipboardData { tableId } {
        variable sPo
        variable sClipboard

        set fileTypes {
            {"All files" "*"}
        }

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            WriteInfoStr "No row selected." "Warning"
            return
        }
        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set fmtNum  [poTablelistUtil GetCellValue $tableId $row 3]
        set fmtName [poTablelistUtil GetCellValue $tableId $row 1]
        set initFile "Clipboard.$fmtName"

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save clipboard entry to file" \
                     -initialfile [file tail $initFile] \
                     -initialdir $sPo(LastDir)]

        if { $fileName ne "" } {
            set sPo(LastDir) [file dirname $fileName]
            set retVal [catch {open $fileName w} fp]
            if { $retVal != 0 } {
                error "Can't write clipboard data to file $fileName ($fp)"
            }
            fconfigure $fp -translation binary
            puts -nonewline $fp $sClipboard(data,$fmtNum)
            close $fp
        }
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc OpenClipboardWin { fr } {
        variable sPo
        variable ns

       if { [winfo exists $fr] && [string match -nocase "*frame" [winfo class $fr]] } {
            set tw $fr
            set sPo(toplevel) ""
        } else {
            set tw .poClipboardWin
            if { [winfo exists $tw] } {
                poWin Raise $tw
                return
            }
            toplevel $tw
            wm title $tw $fr
            focus $tw
            set sPo(toplevel) $tw
        }
        set sPo(tw) $tw

        if { [IsStandalone] } {
            poAppearance SetUseMsgBox "Error"   0
            poAppearance SetUseMsgBox "Warning" 0
        }

        set toolfr $tw.toolfr
        set workfr $tw.workfr
        ttk::frame $toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $workfr
        pack $toolfr -side top -fill x -anchor w
        pack $workfr -side top -fill both -expand 1

        set datafr $workfr.datafr
        set statfr $workfr.statfr
        ttk::frame $datafr -relief groove -padding 1 -borderwidth 1
        ttk::frame $statfr -borderwidth 1

        grid $datafr -row 0 -column 0 -sticky news
        grid $statfr -row 1 -column 0 -sticky news
        grid rowconfigure    $workfr 0 -weight 1
        grid columnconfigure $workfr 0 -weight 1

        set paneWin $datafr.pane
        ttk::panedwindow $paneWin -orient horizontal
        pack $paneWin -side top -expand 1 -fill both

        set tablefr $paneWin.tablefr
        set previewfr $paneWin.previewfr
        ttk::frame $tablefr
        ttk::frame $previewfr
        pack $tablefr   -expand true -fill both
        pack $previewfr -expand true -fill both

        $paneWin add $tablefr
        $paneWin add $previewfr

        set tableId [poWin CreateScrolledTablelist $tablefr true "Clipboard Viewer" \
                    -height 20 -width 50 \
                    -exportselection false \
                    -columns { 3 "#"            "right"
                               0 "Name"         "left"
                               0 "Size (bytes)" "right"
                               0 "Dec."         "right"
                               0 "Hex."         "right" } \
                    -setfocus 1 \
                    -stretch 1 \
                    -stripebackground #e0e8f0 \
                    -selectmode single \
                    -showseparators yes]
        $tableId columnconfigure 0 -showlinenumbers true
        $tableId configure -labelcommand tablelist::sortByColumn
        $tableId columnconfigure  1 -sortmode dictionary
        $tableId columnconfigure  2 -sortmode integer
        $tableId columnconfigure  3 -sortmode integer
        $tableId columnconfigure  4 -sortmode dictionary
        bind $tableId <<TablelistSelect>> "${ns}::ShowPreview $tableId"
        set sPo(tableId) $tableId

        set nbId $previewfr.nb
        set sPo(nbId) $nbId

        ttk::notebook $nbId -style Hori.TNotebook
        pack $nbId -fill both -expand true -padx 2 -pady 3
        ttk::notebook::enableTraversal $nbId

        set asciifr $nbId.asciifr
        ttk::frame $asciifr
        pack $asciifr -expand true -fill both
        $nbId add $asciifr -text "Ascii data"

        set binaryfr $nbId.binaryfr
        ttk::frame $binaryfr
        pack $binaryfr -expand true -fill both
        $nbId add $binaryfr -text "Binary data"

        set imagefr $nbId.imagefr
        ttk::frame $imagefr
        pack $imagefr -expand true -fill both
        $nbId add $imagefr -text "Image data"
        
        set asciiId [poExtProg ShowSimpleTextEdit "ClipboardAsciiPreview" $asciifr false -wrap word]
        set sPo(previewId,ascii) $asciiId

        set binaryId [poExtProg ShowSimpleHexEdit "ClipboardBinaryPreview" $binaryfr true]
        set sPo(previewId,binary) $binaryId

        set imageId [poExtProg ShowSimpleHexEdit "ClipboardImagePreview" $imagefr false]
        set sPo(previewId,image) $imageId

        ClearPreviews

        if { [IsToplevel] } {
            # Add menu bar.
            set hMenu $tw.menufr
            menu $hMenu -borderwidth 2 -relief sunken

            set fileMenu $hMenu.file
            set helpMenu $hMenu.help

            $hMenu add cascade -menu $fileMenu -label "File" -underline 0
            menu $fileMenu -tearoff 0

            if { [IsStandalone] } {
                poMenu AddCommand $fileMenu "Quit"  "Ctrl+Q" ${ns}::CloseClipboardWin
                bind $tw <Control-q> ${ns}::CloseClipboardWin
                if { $::tcl_platform(platform) eq "windows" } {
                    bind $tw <Alt-F4> ${ns}::CloseClipboardWin
                }
                # Menu Help
                $hMenu add cascade -menu $helpMenu -label "Help" -underline 0
                menu $helpMenu -tearoff 0
                poMenu AddCommand $helpMenu "About $sPo(appName) ..." "" ${ns}::HelpProg
                poMenu AddCommand $helpMenu "About Tcl/Tk ..."        "" ${ns}::HelpTcl
            } else {
                poMenu AddCommand $fileMenu "Close" "Ctrl+W" ${ns}::CloseClipboardWin
                bind $tw <Control-w> ${ns}::CloseClipboardWin
            }
            wm protocol $tw WM_DELETE_WINDOW ${ns}::CloseClipboardWin
            $tw configure -menu $hMenu
        }

        # Add new toolbar group and associated buttons.
        poToolbar New $toolfr

        poToolbar AddGroup $toolfr
        set forceButton [poToolbar AddButton $toolfr [::poBmpData::sheetOut] \
                         ${ns}::ClipboardCallback "Force clipboard read"]

        poToolbar AddGroup $toolfr
        set saveButton [poToolbar AddButton $toolfr [::poBmpData::save] \
                        "${ns}::AskSaveClipboardData $tableId" "Save selected entry ..."]
        poWin AddToSwitchableWidgets "RowSelected" $saveButton
        poWin ToggleSwitchableWidgets "RowSelected" false

        # Create widget for status messages.
        set sPo(StatusWidget) [poWin CreateStatusWidget $statfr]
        update

        if { $::tcl_platform(platform) ne "windows" } {
            WriteInfoStr "Clipboard viewer only works on Windows." "Error"
        } elseif { ! [poMisc HavePkg "twapi"] } {
            WriteInfoStr "Clipboard viewer needs the Twapi extension." "Error"
        } else {
            set sPo(monitorHandle) [twapi::start_clipboard_monitor ${ns}::ClipboardCallback]
        }
    }

    proc CloseClipboardWin {} {
        variable sPo

        if { [info exists sPo(monitorHandle)] } {
            twapi::stop_clipboard_monitor $sPo(monitorHandle)
        }

        if { ! [info exists sPo(toplevel)] } {
            # Already destroyed internally
            return
        }
        if { [IsToplevel] } {
            destroy $sPo(toplevel)
            unset sPo(toplevel)
        }
        if { [IsStandalone] } {
            exit
        }
    }
}

poWinClipboard Init
