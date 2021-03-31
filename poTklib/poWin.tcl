# Module:         poWin
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 10 / 22
#
# Distributed under BSD license.
#
# Module with miscellaneous window and widget related procedures.

namespace eval poWin {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init

    namespace export GetFixedFont

    namespace export Raise
    namespace export IsToplevel
    namespace export GetRootWidget GetParentWidget

    namespace export SupportsAppKey

    namespace export CreateHelpWin
    namespace export CreateListSelWin
    namespace export CreateListConfirmWin

    namespace export CreateOneFileInfoWin
    namespace export CreateTwoFileInfoWin

    namespace export SetScrolledTitle SetScrolledColor
    namespace export CreateScrolledWidget
    namespace export AddToScrolledFrame
    namespace export SetScrolledFrameFraction
    namespace export CreateScrolledFrame
    namespace export CreateScrolledListbox
    namespace export CreateScrolledTablelist
    namespace export CreateScrolledText
    namespace export CreateScrolledCanvas
    namespace export CreateScrolledTable
    namespace export CreateScrolledTree

    namespace export SetSyncTitle SetSyncColor
    namespace export CreateSyncWidget
    namespace export CreateSyncTablelist
    namespace export CreateSyncListbox
    namespace export CreateSyncText
    namespace export CreateSyncCanvas

    namespace export CreateStatusWidget
    namespace export WriteStatusMsg AppendStatusMsg
    namespace export InitStatusProgress UpdateStatusProgress

    namespace export CanvasSeeItem
    namespace export LockPane

    namespace export ToggleSwitchableWidgets
    namespace export AddToSwitchableWidgets
    namespace export RemoveSwitchableWidgets

    namespace export EntryBox
    namespace export ShowEntryBox
    namespace export ShowLoginBox

    namespace export GetOkBitmap GetWrongBitmap GetCancelBitmap 
    namespace export GetWatchBitmap GetQuestionBitmap GetEmptyBitmap
    namespace export CheckValidInt CheckValidReal
    namespace export CheckValidString CheckValidDateOrTime

    namespace export SetDateFormat GetDateFormat
    namespace export SetTimeFormat GetTimeFormat
    namespace export SetCheckedIntRange SetCheckedRealRange
    namespace export CreateCheckedIntEntry CreateCheckedRealEntry 
    namespace export CreateCheckedStringEntry
    namespace export CreateCheckedDateEntry CreateCheckedTimeEntry
    namespace export GetCheckedSavedValue GetCheckedEntryWidget
    namespace export ForceCheck

    namespace export ShowPkgInfo

    namespace export StartScreenSaver

    namespace export LoadFileToTextWidget

    namespace export ChooseDirectory

    proc Init {} {
        variable sPo
        variable sChecked
        variable infoWinNo
        variable xPosShowEntryBox
        variable yPosShowEntryBox

        set infoWinNo 1
        set xPosShowEntryBox -1
        set yPosShowEntryBox -1

        variable sMaxInt32   2147483647
        variable sMaxFloat64 1.7976931348623158e+308

        set sChecked(DefaultWidth)   20
        set sChecked(DefaultJustify) "right"
        SetDateFormat "%Y-%m-%d"
        SetTimeFormat "%H:%M:%S"

        set retVal [catch {package require scrollutil_tile} version]
        set sPo(HaveScrollUtil) [expr ! $retVal]
    }

    proc GetFixedFont {} {
        return TkFixedFont
    }

    proc IsToplevel { path } {
        string equal $path [winfo toplevel $path]
    }

    proc GetRootWidget { w } {
        set pathList [split $w "."]
        set rootList [lrange $pathList 0 1]
        return [join $rootList "."]
    }

    proc GetParentWidget { w } {
        set pathList [split $w "."]
        set parList  [lrange $pathList 0 [expr {[llength $pathList] - 2}]]
        return [join $parList "."]
    }

    proc SupportsAppKey {} {
        if { $::tcl_platform(platform) eq "windows" || \
             $::tcl_platform(os) eq "Darwin" } {
            return true
        } else {
            return false
        }
    }

    proc Raise { tw } {
        wm deiconify $tw
        update idletasks
        raise $tw
    }

    proc CreateHelpWin { helpStr { helpTitle "Help Window" } } {
        set tw .poWin_HelpWin
        set title $helpTitle

        if { [winfo exists $tw] } {
            destroy $tw
        }

        toplevel $tw
        wm title $tw $title

        ttk::frame $tw.fr

        set textWid [CreateScrolledText $tw.fr true "" -wrap word]
        bind $tw      <KeyPress-Escape> "destroy $tw"
        bind $textWid <KeyPress-Escape> "destroy $tw"
        pack $tw.fr -expand 1 -fill both

        $textWid insert end $helpStr
        $textWid configure -state disabled -cursor top_left_arrow
        focus $textWid
    }

    proc SelAllInList { listBox } {
        $listBox selection set 0 end
    }

    proc ListOkCmd {} {
        variable listBoxFlag

        set listBoxFlag 1
    }

    proc ListCancelCmd {} {
        variable listBoxFlag

        set listBoxFlag 0
    }

    proc CreateListSelWin { selList title subTitle { onlyConfirm false } { backgroundColor "" } } {
        variable ns
        variable listBoxFlag

        set tw .poWin_ListWin

        if { [llength $selList] == 0 } {
            return {}
        }

        toplevel $tw
        wm title $tw "$title"
        wm resizable $tw true true

        ttk::frame $tw.listfr
        ttk::frame $tw.selfr
        ttk::frame $tw.okfr
        grid $tw.listfr -row 0 -column 0 -sticky news
        grid $tw.selfr  -row 1 -column 0 -sticky news
        grid $tw.okfr   -row 2 -column 0 -sticky news
        grid rowconfigure    $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1

        set listBox [CreateScrolledListbox $tw.listfr true \
                     $subTitle -width 60 -selectmode extended \
                     -exportselection false]
        if { $backgroundColor ne "" } {
            SetScrolledColor $listBox $backgroundColor
        }
        $listBox configure -disabledforeground [$listBox cget -foreground]

        if { ! $onlyConfirm } {
            ttk::button $tw.selfr.b1 -text "Select all" \
                                     -command "${ns}::SelAllInList $listBox"
            pack $tw.selfr.b1 -side left -fill x -expand 1 -padx 2 -pady 2
        }

        # Create Cancel and OK buttons
        ttk::button $tw.okfr.b1 -text "Cancel" -image [GetCancelBitmap] \
                                -compound left -command "${ns}::ListCancelCmd"
        ttk::button $tw.okfr.b2 -text "OK" -image [GetOkBitmap] \
                                -compound left -default active \
                                -command "${ns}::ListOkCmd"
        pack $tw.okfr.b1 $tw.okfr.b2 -side left -fill x -padx 2 -pady 2 -expand 1

        bind $tw <KeyPress-Return> "${ns}::ListOkCmd"
        bind $tw <KeyPress-Escape> "${ns}::ListCancelCmd"

        # Now fill the listbox with the file names and select all.
        foreach f $selList {
            $listBox insert end $f
        }
        $listBox selection set 0 end
        if { $onlyConfirm } {
            $listBox configure -state disabled
        }

        update

        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if { $oldGrab ne "" } {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $listBox

        tkwait variable ${ns}::listBoxFlag

        set retList [list]
        set indList [$listBox curselection]
        if { $listBoxFlag && [llength $indList] != 0 } {
            foreach ind $indList {
                lappend retList [$listBox get $ind]
            }
        }

        catch {focus $oldFocus}
        grab release $tw
        destroy $tw

        if { $oldGrab ne "" } {
            if { $grabStatus eq "global" } {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }

        return $retList
    }

    proc CreateListConfirmWin { selList title subTitle { backgroundColor "" } } {
        set retList [CreateListSelWin $selList $title $subTitle true $backgroundColor]
        if { [llength $retList] == 0 } {
            return 0
        } else {
            return 1
        }
    }

    proc DestroyOneFileInfoWin { w { phImg "" } } {
        catch {image delete $phImg}
        destroy $w
    }

    proc CreateOneFileInfoWin { fileOrDirName { phImg "" } } {
        variable ns
        variable infoWinNo

        set tw .poWin_InfoWin$infoWinNo
        incr infoWinNo
        catch { destroy $tw }

        toplevel $tw
        wm title $tw "[poAppearance CutFilePath $fileOrDirName]"
        wm resizable $tw true false

        if { [file isdirectory $fileOrDirName] } {
            set name [file tail $fileOrDirName]
            set dirInfo [poMisc CountDirsAndFiles $fileOrDirName]
            set msgStr "Directory $name: [lindex $dirInfo 0] subdirs, [lindex $dirInfo 1] files"
            ttk::label $tw.l -text $msgStr
            pack $tw.l -fill both -expand true
        } else {
            set attrList [poMisc FileInfo $fileOrDirName true]

            # If the file is an image, but no thumbnail photo has been supplied
            # as parameter, create a thumbnail image.
            if { $phImg eq "" && [poImgMisc IsImageFile $fileOrDirName] } {
                set thumbSize [poImgBrowse GetThumbSize]
                set phImg [poImgMisc LoadImgScaled $fileOrDirName $thumbSize $thumbSize]
            }

            # If a thumbnail photo image has been supplied in phImg, show it.
            # If a button procedure has been set (i.e. an image file with multiple images) show
            # the image in a button. When pressing the button, additional information can be shown.
            if { $phImg ne "" } {
                ttk::frame $tw.fr
                pack $tw.fr -fill both
                set typeDict [poType GetFileType $fileOrDirName]
                set viewCmd ""
                # Check, if we have an image with sub-images.
                if { [dict exists $typeDict subfmt] } {
                    set fmt [dict get $typeDict subfmt]
                    if { $fmt eq "gif" } {
                        # Check for animated GIF's
                        set numImgs [poImgDetail GetNumGifImgs $fileOrDirName]
                        lappend attrList [list "Images in file" $numImgs]
                        if { $numImgs > 1 } {
                            set viewCmd poImgDetail::ShowAniGifDetail
                        }
                    } elseif { $fmt eq "ico" } {
                        # Check for Windows Icons
                        set numImgs [dict get $typeDict subimgs]
                        lappend attrList [list "Images in file" $numImgs]
                        if { $numImgs > 1 } {
                            set viewCmd poImgDetail::ShowIcoDetail
                        }
                    } elseif { $fmt eq "jpeg" } {
                        if { [dict exists $typeDict imgsubfmt] && \
                             [dict get $typeDict imgsubfmt] eq "exif" } {
                            lappend attrList [list "File contains" "EXIF tags"]
                            set viewCmd poImgDetail::ShowExifDetail
                        }
                    }
                }
                if { $viewCmd ne "" } {
                    ttk::button $tw.fr.l -image $phImg -command [list $viewCmd $fileOrDirName]
                } else {
                    ttk::label $tw.fr.l -image $phImg
                }
                pack $tw.fr.l -pady 2
            }
            # Generate left column with text labels.
            set row 0
            ttk::labelframe $tw.fr0 -text "File attributes"
            pack $tw.fr0 -side top -expand 1 -fill both -padx 1
            foreach listEntry $attrList {
                ttk::label $tw.fr0.k$row -text [format "%s:" [lindex $listEntry 0]]
                ttk::label $tw.fr0.v$row -text [lindex $listEntry 1]
                grid  $tw.fr0.k$row -row $row -column 0 -sticky nw
                grid  $tw.fr0.v$row -row $row -column 1 -sticky nw
                incr row
            }
        }

        bind $tw <Escape> "${ns}::DestroyOneFileInfoWin $tw $phImg"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::DestroyOneFileInfoWin $tw $phImg"
        focus $tw
        return $tw
    }

    proc DestroyTwoFileInfoWin { w { leftPhoto "" } { rightPhoto "" } } {
        catch {image delete $leftPhoto}
        catch {image delete $rightPhoto}
        destroy $w
    }

    proc CreateTwoFileInfoWin { leftFile rightFile { leftPhoto "" } { rightPhoto "" } } {
        variable ns
        variable infoWinNo

        set tw .poWin_InfoWin$infoWinNo
        incr infoWinNo
        catch { destroy $tw }

        toplevel $tw
        wm title $tw "[poAppearance CutFilePath $leftFile] vs. [poAppearance CutFilePath $rightFile]"
        wm resizable $tw true false

        set leftAttr  [poMisc FileInfo $leftFile  true]
        set rightAttr [poMisc FileInfo $rightFile true]

        # If the files are images, but no thumbnail photos have been supplied
        # as parameter, create thumbnail images.
        set thumbSize [poImgBrowse GetThumbSize]
        if { $leftPhoto eq "" && [poImgMisc IsImageFile $leftFile] } {
            set leftPhoto [poImgMisc LoadImgScaled $leftFile $thumbSize $thumbSize]
        }
        if { $rightPhoto eq "" && [poImgMisc IsImageFile $rightFile] } {
            set rightPhoto [poImgMisc LoadImgScaled $rightFile $thumbSize $thumbSize]
        }

        # If thumbnail photo images have been supplied, show them.
        if { $leftPhoto ne "" || $rightPhoto ne "" } {
            ttk::frame $tw.fr
            pack $tw.fr -fill both -expand 1
            ttk::label $tw.fr.l -anchor center
            ttk::label $tw.fr.r -anchor center
            pack $tw.fr.l $tw.fr.r -pady 2 -side left -expand 1 -fill x
            if { $leftPhoto ne "" } {
                $tw.fr.l configure -image $leftPhoto
            }
            if { $rightPhoto ne "" } {
                $tw.fr.r configure -image $rightPhoto
            }
        }

        # Generate left column with text labels.
        set row 0
        ttk::labelframe $tw.fr0 -text "File attributes"
        pack $tw.fr0 -side top -expand 1 -fill both -padx 1
        foreach leftEntry $leftAttr rightEntry $rightAttr {
            ttk::label $tw.fr0.kl$row -text [format "%s:" [lindex $leftEntry 0]]
            ttk::label $tw.fr0.vl$row -text [lindex $leftEntry 1]
            ttk::label $tw.fr0.vr$row -text [lindex $rightEntry 1]
            grid  $tw.fr0.kl$row -row $row -column 0 -sticky nw
            grid  $tw.fr0.vl$row -row $row -column 1 -sticky nw
            grid  $tw.fr0.vr$row -row $row -column 2 -sticky nw
            incr row
        }

        bind $tw <Escape> "${ns}::DestroyTwoFileInfoWin $tw $leftPhoto $rightPhoto"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::DestroyTwoFileInfoWin $tw $leftPhoto $rightPhoto"
        focus $tw
        return $tw
    }

    proc SetScrolledColor { w bgColor { fgColor "" } } {
        variable sPo

        set pathList [split $w "."]
        # Index -3 is needed for CreateScrolledFrame.
        # Index -2 is needed for all other widget types.
        foreach ind { -2 -3 -4 } {
            set parList  [lrange $pathList 0 [expr [llength $pathList] $ind]]
            set parPath  [join $parList "."]

            set labelPath $parPath
            append labelPath ".label"
            if { [winfo exists $labelPath] } {
                if { $bgColor ne "" } {
                    $labelPath configure -background $bgColor
                } else {
                    $labelPath configure -background $sPo(bgDefaultColor)
                }
                if { $fgColor ne "" } {
                    $labelPath configure -foreground $fgColor
                } else {
                    $labelPath configure -foreground $sPo(fgDefaultColor)
                }
                break
            }
        }
    }

    proc SetScrolledTitle { w titleStr } {
        set pathList [split $w "."]
        # Index -3 is needed for CreateScrolledFrame.
        # Index -2 is needed for all other widget types.
        foreach ind { -2 -3 -4 } {
            set parList  [lrange $pathList 0 [expr [llength $pathList] $ind]]
            set parPath  [join $parList "."]

            set labelPath $parPath
            append labelPath ".label"
            if { [winfo exists $labelPath] } {
                $labelPath configure -text $titleStr
                break
            }
        }
    }

    proc MouseWheelCB { w delta dir } {
        # puts "[$w cget -xscrollincrement] [$w cget -yscrollincrement]"
        if {[tk windowingsystem] ne "aqua"} {
            # The following integer arithmetic cannot be
            # used on X11, where $delta is 150 or -150:
            # set delta [expr {($delta / 120) * 4}]     ;# X11: 4 or -8 -- NOK!
            set delta [expr {($delta * 4) / 120}]       ;# X11: 5 or -5 -- OK
        }
        if { $dir eq "y" } {
            $w yview scroll [expr {-$delta}] units
        } else {
            $w xview scroll [expr {-$delta}] units
        }

        # Prevent the double-handling in case the widget's
        # class already has mouse wheel event bindings
        return -code break
    }

    proc AddMouseWheelSupport { w } {
        variable ns

        bind $w <MouseWheel>       "${ns}::MouseWheelCB %W %D y"
        bind $w <Shift-MouseWheel> "${ns}::MouseWheelCB %W %D x"

        if {[tk windowingsystem] eq "x11"} {
            bind $w <4>            "${ns}::MouseWheelCB %W  150 y"
            bind $w <Shift-4>      "${ns}::MouseWheelCB %W  150 x"
            bind $w <5>            "${ns}::MouseWheelCB %W -150 y"
            bind $w <Shift-5>      "${ns}::MouseWheelCB %W -150 x"
        }
    }

    proc CreateScrolledWidget { wType w useAutoScroll titleStr args } {
        variable ns
        variable sPo

        if { [winfo exists $w.par] } {
            destroy $w.par
        }
        ttk::frame $w.par
        pack $w.par -side top -fill both -expand 1

        if { $useAutoScroll && $sPo(HaveScrollUtil) } {
            if { $titleStr ne "" } {
                ttk::label $w.par.label -text "$titleStr" -anchor center
                pack  $w.par.label -side top -fill x -expand 0
                set sPo(bgDefaultColor) [$w.par.label cget -background]
                set sPo(fgDefaultColor) [$w.par.label cget -foreground]
            }
            set sa [scrollutil::scrollarea $w.par.sa]
            if {$wType eq "text"} {
                # The -lockinterval 50 setting below guards
                # against shimmering with some text widgets
                $sa configure -lockinterval 50
            }
            $wType $w.par.sa.widget {*}$args
            $sa setwidget $w.par.sa.widget

            pack $w.par.sa -side top -fill both -expand 1

            AddMouseWheelSupport $w.par.sa.widget

            return $w.par.sa.widget
        } else {
            if { $titleStr ne "" } {
                ttk::label $w.par.label -text "$titleStr" -anchor center
                set sPo(bgDefaultColor) [$w.par.label cget -background]
                set sPo(fgDefaultColor) [$w.par.label cget -foreground]
            }
            $wType $w.par.widget \
                   -xscrollcommand "$w.par.xscroll set" \
                   -yscrollcommand "$w.par.yscroll set" {*}$args
            ttk::scrollbar $w.par.xscroll -command "$w.par.widget xview" -orient horizontal
            ttk::scrollbar $w.par.yscroll -command "$w.par.widget yview" -orient vertical
            set rowNo 0
            if { $titleStr ne "" } {
                set rowNo 1
                grid $w.par.label -sticky ew -columnspan 2
            }
            grid $w.par.widget $w.par.yscroll -sticky news
            grid $w.par.xscroll               -sticky ew

            grid rowconfigure    $w.par $rowNo -weight 1
            grid columnconfigure $w.par 0      -weight 1

            AddMouseWheelSupport $w.par.widget

            return $w.par.widget
        }
    }

    proc ScrolledFrameCfgCB { w width height } {
        set newSR [list 0 0 $width $height]
        if { [$w cget -scrollregion] ne $newSR } {
            $w configure -scrollregion $newSR
        }
    }

    proc SetScrolledFrameFraction { fr fraction } {
        set parWidget [GetParentWidget $fr]
        $parWidget yview moveto $fraction
    }

    proc AddToScrolledFrame { wType fr name args } {
        variable ns

        set parWidget [GetParentWidget $fr]
        $wType $fr.$name {*}$args
        pack $fr.$name -side top -fill x

        bind $fr.$name <MouseWheel>       "${ns}::MouseWheelCB $parWidget %D y"
        bind $fr.$name <Shift-MouseWheel> "${ns}::MouseWheelCB $parWidget %D x"

        if {[tk windowingsystem] eq "x11"} {
            bind $fr.$name <4>       "${ns}::MouseWheelCB $parWidget  150 y"
            bind $fr.$name <Shift-4> "${ns}::MouseWheelCB $parWidget  150 x"
            bind $fr.$name <5>       "${ns}::MouseWheelCB $parWidget -150 y"
            bind $fr.$name <Shift-5> "${ns}::MouseWheelCB $parWidget -150 x"
        }

        return $fr.$name
    }

    proc CreateScrolledFrame { w useAutoScroll titleStr args } {
        variable ns
        variable sPo

        ttk::frame $w.par
        pack $w.par -fill both -expand 1

        if { $useAutoScroll && $sPo(HaveScrollUtil) } {
            if { $titleStr ne "" } {
                ttk::label $w.par.label -text "$titleStr" -borderwidth 2 -anchor center
                pack  $w.par.label -side top -fill x -expand 0
            }
            set sa [scrollutil::scrollarea $w.par.sa]
            canvas $sa.canv -width 1 {*}$args
            set fr [ttk::frame $sa.canv.fr -borderwidth 0]
            $sa.canv create window 0 0 -anchor nw -window $fr
            $sa setwidget $sa.canv

            pack $sa -side top -fill both -expand 1

            # This binding makes the scroll-region of the canvas behave correctly as
            # you place more things in the content frame.
            bind $fr <Configure> [list ${ns}::ScrolledFrameCfgCB $sa.canv %w %h]
            $sa.canv configure -borderwidth 0 -highlightthickness 0

            AddMouseWheelSupport $sa.canv
        } else {
            if { $titleStr ne "" } {
                ttk::label $w.par.label -text "$titleStr" -borderwidth 2 -anchor center
            }
            canvas $w.par.canv -xscrollcommand [list $w.par.xscroll set] -width 1 \
                               -yscrollcommand [list $w.par.yscroll set] {*}$args
            ttk::scrollbar $w.par.xscroll -orient horizontal -command "$w.par.canv xview"
            ttk::scrollbar $w.par.yscroll -orient vertical   -command "$w.par.canv yview"
            set fr [ttk::frame $w.par.canv.fr -borderwidth 0]
            $w.par.canv create window 0 0 -anchor nw -window $fr

            set rowNo 0
            if { $titleStr ne "" } {
                set rowNo 1
                grid $w.par.label -sticky ew -columnspan 2
            }
            grid $w.par.canv $w.par.yscroll -sticky news
            grid $w.par.xscroll             -sticky ew
            grid rowconfigure    $w.par $rowNo -weight 1
            grid columnconfigure $w.par 0      -weight 1
            # This binding makes the scroll-region of the canvas behave correctly as
            # you place more things in the content frame.
            bind $fr <Configure> [list ${ns}::ScrolledFrameCfgCB $w.par.canv %w %h]
            $w.par.canv configure -borderwidth 0 -highlightthickness 0

            AddMouseWheelSupport $w.par.canv
        }

        return $fr
    }

    proc CreateScrolledListbox { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget listbox $w $useAutoScroll $titleStr {*}$args]
    }

    proc CreateScrolledTablelist { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget tablelist::tablelist $w $useAutoScroll $titleStr {*}$args]
    }

    proc CreateScrolledText { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget text $w $useAutoScroll $titleStr {*}$args]
    }

    proc CreateScrolledCanvas { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget canvas $w $useAutoScroll $titleStr {*}$args]
    }

    proc CreateScrolledTable { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget table $w $useAutoScroll $titleStr {*}$args]
    }

    proc CreateScrolledTree { w useAutoScroll titleStr args } {
        return [CreateScrolledWidget ttk::treeview $w $useAutoScroll $titleStr {*}$args]
    }

    proc SetSyncColor { w bgLeftColor bgRightColor { fgLeftColor "" } { fgRightColor "" } } {
        variable sPo

        set ss [GetParentWidget $w]        ; # a scrollutil::scrollsync widget
        set sa [GetParentWidget $ss]       ; # a scrollutil::scrollarea widget
        set parPath [GetParentWidget $sa]  ; # a ttk::frame widget
        set tf $parPath.tf                 ; # a ttk::frame widget

        set leftLabelPath $tf
        append leftLabelPath ".leftlabel"
        set rightLabelPath $tf
        append rightLabelPath ".rightlabel"

        if { [winfo exists $leftLabelPath] } {
            if { $bgLeftColor ne "" } {
                $leftLabelPath configure -background $bgLeftColor
            } else {
                $leftLabelPath configure -background $sPo(bgDefaultColor)
            }
            if { $fgLeftColor ne "" } {
                $leftLabelPath configure -foreground $fgLeftColor
            } else {
                $leftLabelPath configure -foreground $sPo(fgDefaultColor)
            }
        }
        if { [winfo exists $rightLabelPath] } {
            if { $bgRightColor ne "" } {
                $rightLabelPath configure -background $bgRightColor
            } else {
                $rightLabelPath configure -background $sPo(bgDefaultColor)
            }
            if { $fgLeftColor ne "" } {
                $rightLabelPath configure -foreground $fgRightColor
            } else {
                $rightLabelPath configure -foreground $sPo(fgDefaultColor)
            }
        }
    }

    proc SetSyncTitle { w leftTitle rightTitle } {
        variable sPo

        set ss [GetParentWidget $w]        ; # a scrollutil::scrollsync widget
        set sa [GetParentWidget $ss]       ; # a scrollutil::scrollarea widget
        set parPath [GetParentWidget $sa]  ; # a ttk::frame widget
        set tf $parPath.tf                 ; # a ttk::frame widget

        set leftLabelPath $tf
        append leftLabelPath ".leftlabel"
        set rightLabelPath $tf
        append rightLabelPath ".rightlabel"

        if { $leftTitle ne "" && [winfo exists $leftLabelPath] } {
            $leftLabelPath configure -text $leftTitle
        }
        if { $rightTitle ne "" && [winfo exists $rightLabelPath] } {
            $rightLabelPath configure -text $rightTitle
        }
    }

    # Sets the -padx pack option for $w, depending on the
    # mapped state of the vertical scrollbar $yscroll.
    proc UpdatePadx { w yscroll yscrollMapped } {
        set l [[GetParentWidget $yscroll] cget -borderwidth]
        set r $l
        if { $yscrollMapped } {
            incr r [winfo width $yscroll]
        }

        pack configure $w -padx [list $l $r]
    }

    proc CreateSyncWidget { wType w leftTitle rightTitle args } {
        variable ns
        variable sPo

        ttk::frame $w.par
        pack $w.par -side top -fill both -expand 1

        set tf [ttk::frame $w.par.tf]
        if { $leftTitle ne "" } {
            ttk::label $tf.leftlabel -text "$leftTitle" -anchor center
            set sPo(bgDefaultColor) [$tf.leftlabel cget -background]
            set sPo(fgDefaultColor) [$tf.leftlabel cget -foreground]
            grid $tf.leftlabel  -sticky ew -row 0 -column 0
        }
        if { $rightTitle ne "" } {
            ttk::label $tf.rightlabel -text "$rightTitle" -anchor center
            set sPo(bgDefaultColor) [$tf.rightlabel cget -background]
            set sPo(fgDefaultColor) [$tf.rightlabel cget -foreground]
            grid $tf.rightlabel -sticky ew -row 0 -column 1
        }
        grid columnconfigure $tf {0 1} -weight 1 -uniform TwoCols

        if { $leftTitle ne "" || $rightTitle ne "" } {
            pack $tf -side top -fill x
        }

        set sa [scrollutil::scrollarea $w.par.sa]
        if {$wType eq "text"} {
            # The -lockinterval 100 setting below guards
            # against shimmering with some text widgets
            $sa configure -lockinterval 100
        }
        set ss [scrollutil::scrollsync $sa.ss]
        $sa setwidget $ss

        $wType $ss.leftwidget  {*}$args
        $wType $ss.rightwidget {*}$args
        $ss setwidgets [list $ss.leftwidget $ss.rightwidget]

        grid $ss.leftwidget $ss.rightwidget -sticky news
        grid rowconfigure    $ss 0     -weight 1
        grid columnconfigure $ss {0 1} -weight 1 -uniform TwoCols

        pack $sa -side top -fill both -expand 1

        set yscroll     $sa.vsb
        set leftwidget  $ss.leftwidget
        set rightwidget $ss.rightwidget

        if { $leftTitle ne "" || $rightTitle ne "" } {
            # Set the -padx pack option for $tf, depending on the
            # current mapped state of the vertical scrollbar $yscroll
            UpdatePadx $tf $yscroll 0
            bind $yscroll <Map>   [list ${ns}::UpdatePadx $tf %W 1]
            bind $yscroll <Unmap> [list ${ns}::UpdatePadx $tf %W 0]
        }

        catch {$leftwidget  configure -highlightthickness 0}
        catch {$rightwidget configure -highlightthickness 0}
        AddMouseWheelSupport $leftwidget
        AddMouseWheelSupport $rightwidget

        return [list $leftwidget $rightwidget]
    }

    proc CreateSyncTablelist { w leftTitle rightTitle args } {
        return [CreateSyncWidget tablelist::tablelist $w $leftTitle $rightTitle {*}$args]
    }

    proc CreateSyncListbox { w leftTitle rightTitle args } {
        return [CreateSyncWidget listbox $w $leftTitle $rightTitle {*}$args]
    }

    proc CreateSyncText { w leftTitle rightTitle args } {
        return [CreateSyncWidget text $w $leftTitle $rightTitle {*}$args]
    }

    proc CreateSyncCanvas { w leftTitle rightTitle args } {
        return [CreateSyncWidget canvas $w $leftTitle $rightTitle {*}$args]
    }

    proc CanvasSeeItem { canv item } {
        set box [$canv bbox $item]

        if { [string match {} $box] } { return }

        if { [string match {} [$canv cget -scrollregion]] } {
            # People really should set -scrollregion you know...
            foreach {x y x1 y1} $box {
                set x [expr round(2.5 * ($x1+$x) / [winfo width  $canv])]
                set y [expr round(2.5 * ($y1+$y) / [winfo height $canv])]
            }
            $canv xview moveto 0
            $canv yview moveto 0
            $canv xview scroll $x units
            $canv yview scroll $y units
        } else {
            # If -scrollregion is set properly, use this
            foreach {x y x1 y1} \
                $box          {top btm} \
                [$canv yview] {left right} \
                [$canv xview] {p q xmax ymax} \
                [$canv cget -scrollregion] \
            {
                set xpos [expr (($x1+$x) / 2.0) / $xmax - ($right-$left) / 2.0]
                set ypos [expr (($y1+$y) / 2.0) / $ymax - ($btm-$top)    / 2.0]
            }
            $canv xview moveto $xpos
            $canv yview moveto $ypos
        }
    }

    proc LockPane { w onOff } {
        if { $onOff } {
            bindtags $w { $w . all }
        } else {
            bindtags $w { $w TPanedwindow . all }
        }
    }

    proc _EnableWidget { w onOff } {
        if { $onOff } {
            catch { $w configure -state normal }
        } else {
            catch { $w configure -state disabled }
        }
    }
 
    proc _RecursiveEnableWidget { w onOff } {
        if { [poWinRollUp IsElement $w] } {
            poWinRollUp EnableElement $w $onOff
        } elseif { [llength [winfo children $w]] > 0 } {
            foreach child [winfo children $w] {
                _RecursiveEnableWidget $child $onOff
            }
        } else {
            _EnableWidget $w $onOff
        }
    }

    proc ToggleSwitchableWidgets { groupName onOff } {
        variable sSwitchableWidgets

        if { [info exists sSwitchableWidgets($groupName)] } {
            foreach w $sSwitchableWidgets($groupName) {
                _RecursiveEnableWidget $w $onOff
            }
        }
    }

    proc AddToSwitchableWidgets { groupName args } {
        variable sSwitchableWidgets

        foreach w $args {
           lappend sSwitchableWidgets($groupName) $w
       }
    }

    proc RemoveSwitchableWidgets { groupName } {
        variable sSwitchableWidgets

        if { [info exists sSwitchableWidgets($groupName)] } {
           unset sSwitchableWidgets($groupName)
       }
    }

    proc EvalCommand { cmd } {
        variable entryBoxTemp

        eval [list $cmd $entryBoxTemp]
        DestroyEntryBox
    }

    proc DestroyEntryBox {} {
        variable xPosShowEntryBox
        variable yPosShowEntryBox

        set xPosShowEntryBox [winfo rootx .poWin_EntryBox]
        set yPosShowEntryBox [winfo rooty .poWin_EntryBox]
        destroy .poWin_EntryBox
    }

    proc ShowEntryBox { cmd var title { msg "" } { numChars 30 } { fontName "" } } {
        variable ns
        variable entryBoxTemp
        variable xPosShowEntryBox
        variable yPosShowEntryBox

        set tw ".poWin_EntryBox"
        if { [winfo exists $tw] } {
            Raise $tw
            return
        }

        toplevel $tw
        wm title $tw $title
        wm resizable $tw false false
        if { $xPosShowEntryBox < 0 || $yPosShowEntryBox < 0 } {
            set xPosShowEntryBox [expr [winfo screenwidth .]  / 2]
            set yPosShowEntryBox [expr [winfo screenheight .] / 2]
        }
        wm geometry $tw [format "+%d+%d" $xPosShowEntryBox $yPosShowEntryBox]

        ttk::frame $tw.fr1
        ttk::frame $tw.fr2
        set entryBoxTemp $var
        if { $msg ne "" } {
            ttk::label $tw.fr1.l -text $msg
        }
        ttk::entry $tw.fr1.e -textvariable ${ns}::entryBoxTemp
        $tw.fr1.e configure -width $numChars
        if { $fontName ne "" } {
            $tw.fr1.e configure -font $fontName
        }

        $tw.fr1.e selection range 0 end

        bind $tw <KeyPress-Return> "${ns}::EvalCommand $cmd"
        bind $tw <KeyPress-Escape> "${ns}::DestroyEntryBox"
        if { $msg ne "" } {
            pack $tw.fr1.l -fill x -expand 1 -side top
        }
        pack $tw.fr1.e -fill x -expand 1 -side top

        ttk::button $tw.fr2.b1 -text "Cancel" -image [GetCancelBitmap] \
                               -compound left -command "${ns}::DestroyEntryBox"
        ttk::button $tw.fr2.b2 -text "OK" -image [GetOkBitmap] \
                               -compound left -default active \
                               -command "${ns}::EvalCommand $cmd"
        pack $tw.fr2.b1 $tw.fr2.b2 -side left -fill x -padx 2 -pady 2 -expand 1
        pack $tw.fr1 -side top -expand 1 -fill x
        pack $tw.fr2 -side top -expand 1 -fill x
        focus $tw.fr1.e
        grab $tw
    }

    proc LoginOkCmd {} {
        variable login

        set login 1
    }

    proc LoginCancelCmd {} {
        variable login

        set login 0
    }

    proc ShowLoginBox { title { user guest } { fontName "" } } {
        variable ns
        variable login
        variable loginUser
        variable loginPassword

        set tw ".poWin_LoginBox"
        if { [winfo exists $tw] } {
            destroy $tw
            set loginPassword ""
        }

        toplevel $tw
        wm title $tw $title
        wm resizable $tw false false

        ttk::frame $tw.fr1
        ttk::frame $tw.fr2
        set loginUser $user
        ttk::label $tw.fr1.l1 -text "Username:"
        ttk::label $tw.fr1.l2 -text "Password:"
        ttk::entry $tw.fr1.e1 -textvariable ${ns}::loginUser
        ttk::entry $tw.fr1.e2 -textvariable ${ns}::loginPassword -show "*"
        grid $tw.fr1.l1 -row 0 -column 0 -sticky nw
        grid $tw.fr1.l2 -row 1 -column 0 -sticky nw
        grid $tw.fr1.e1 -row 0 -column 1 -sticky nw
        grid $tw.fr1.e2 -row 1 -column 1 -sticky nw
        $tw.fr1.e1 configure -width 15
        $tw.fr1.e2 configure -width 15
        if { $fontName ne "" } {
            $tw.fr1.e1 configure -font $fontName
            $tw.fr1.e2 configure -font $fontName
        }

        bind $tw <KeyPress-Return> "${ns}::LoginOkCmd"
        bind $tw <KeyPress-Escape> "${ns}::LoginCancelCmd"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::LoginCancelCmd"

        ttk::button $tw.fr2.b1 -text "Cancel" -image [GetCancelBitmap] \
                               -compound left -command "${ns}::LoginCancelCmd"
        ttk::button $tw.fr2.b2 -text "OK" -image [poWin GetOkBitmap] \
                               -compound left -default active \
                          -command "${ns}::LoginOkCmd"
        pack $tw.fr2.b1 $tw.fr2.b2 -side left -fill x -padx 2 -pady 2 -expand 1
        pack $tw.fr1 -side top -expand 1 -fill x
        pack $tw.fr2 -side top -expand 1 -fill x
        update

        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if { $oldGrab ne "" } {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $tw.fr1.e1

        tkwait variable ${ns}::login

        catch {focus $oldFocus}
        grab release $tw
        wm withdraw $tw
        if { $oldGrab ne "" } {
            if { $grabStatus eq "global" } {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }

        if { $login } {
            return [list $loginUser $loginPassword]
        } else {
            return {}
        }
    }

    proc EntryOkCmd {} {
        variable entryBoxFlag

        set entryBoxFlag 1
    }

    proc EntryCancelCmd {} {
        variable entryBoxFlag

        set entryBoxFlag 0
    }

    proc EntryBox { str x y { numChars 0 } { fontName "" } } {
        variable ns
        variable entryBoxText
        variable entryBoxFlag

        set tw ".poWin_EntryBox"
        if { [winfo exists $tw] } {
            destroy $tw
        }

        toplevel $tw
        wm overrideredirect $tw true
        if { [tk windowingsystem] eq "aqua" }  {
            ::tk::unsupported::MacWindowStyle style $tw help none
        }
        wm geometry $tw [format "+%d+%d" $x [expr $y +10]]
     
        set entryBoxText $str
        ttk::frame $tw.fr -borderwidth 3 -relief raised
        ttk::entry $tw.fr.e -textvariable ${ns}::entryBoxText

        if { $numChars <= 0 } {
            set numChars [expr [string length $str] +1]
        }
        $tw.fr.e configure -width $numChars
        if { $fontName ne "" } {
            $tw.fr.e configure -font $fontName
        }
        $tw.fr.e selection range 0 end

        pack $tw.fr
        pack $tw.fr.e

        bind $tw <KeyPress-Return> "${ns}::EntryOkCmd"
        bind $tw <KeyPress-Escape> "${ns}::EntryCancelCmd"

        update

        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if { $oldGrab ne "" } {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $tw.fr.e

        tkwait variable ${ns}::entryBoxFlag

        catch { focus $oldFocus }
        grab release $tw
        destroy $tw
        if { $oldGrab ne "" } {
            if { $grabStatus eq "global" } {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }

        if { $entryBoxFlag } {
            return $entryBoxText
        } else {
            return ""
        }
    }

    proc GetOkBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpOk)
    }

    proc GetCancelBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpCancel)
    }

    proc GetWrongBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpWrong)
    }

    proc GetWatchBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpWatch)
    }

    proc GetQuestionBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpQuestion)
    }

    proc GetEmptyBitmap {} {
        variable pkgInt

        CreateStandardBitmaps
        return $pkgInt(bmpEmpty)
    }

    proc CreateStandardBitmaps {} {
        variable pkgInt

        set usedBmpTypes [poBmpData GetBmpType]
        poBmpData SetBmpType bitmaps
        if { ! [info exists pkgInt(bmpOk)] } {
            set pkgInt(bmpOk) [::poBmpData::ok "darkgreen"]
        }
        if { ! [info exists pkgInt(bmpWrong)] } {
            set pkgInt(bmpWrong) [::poBmpData::halt "red"]
        }
        if { ! [info exists pkgInt(bmpCancel)] } {
            set pkgInt(bmpCancel) [::poBmpData::delete "red"]
        }
        if { ! [info exists pkgInt(bmpWatch)] } {
            set pkgInt(bmpWatch) [::poBmpData::watch "black"]
        }
        if { ! [info exists pkgInt(bmpQuestion)] } {
            set pkgInt(bmpQuestion) [::poBmpData::osgUnknown "magenta"]
        }
        if { ! [info exists pkgInt(bmpEmpty)] } {
            set pkgInt(bmpEmpty) [::poBmpData::none]
        }
        poBmpData SetBmpType $usedBmpTypes
    }

    proc CreateStatusWidget { w { addProgressBar false } } {
        variable ns
        variable pkgInt
        
        set par $w.par
        if { [winfo exists $par] } {
            destroy $par
        }
        ttk::frame $par
        pack $par -side top -fill both -expand 1

        ttk::label $par.icon -anchor w
        ttk::label $par.text -text "Status messages" -anchor w
        pack $par.icon -side left
        pack $par.text -side left -fill x -expand 1

        if { $addProgressBar } {
            set pkgInt(progress,$par) 0
            ttk::progressbar $par.progress -variable ${ns}::pkgInt(progress,$par)
            pack $par.progress -side right
        }
        return $par
    }

    proc WriteStatusMsg { par str icon } {
        set tkIcon "info"
        if { [winfo exists $par.icon] } {
            switch -nocase $icon {
                "Ok"      { set img [poWin GetOkBitmap] }
                "Error"   { set img [poWin GetWrongBitmap]    ; set tkIcon error }
                "Warning" { set img [poWin GetQuestionBitmap] ; set tkIcon warning }
                "Watch"   { set img [poWin GetWatchBitmap] }
                "Cancel"  { set img [poWin GetCancelBitmap] }
                default   { set img [poWin GetEmptyBitmap] }
            }
            if { $str eq "" } {
                set img [poWin GetEmptyBitmap]
            }
            $par.icon configure -image $img
        }
        if { [winfo exists $par.text] } {
            $par.text configure -text $str
        }
        update
    }

    proc AppendStatusMsg { par str } {
        if { [winfo exists $par.text] } {
            set labelStr [$par.text cget -text]
            append labelStr $str
            $par.text configure -text $labelStr
        }
    }

    proc InitStatusProgress { par maxValue { mode "determinate" } } {
        if { [winfo exists $par.progress] } {
            $par.progress configure -maximum $maxValue -mode $mode
            update
        }
    }

    proc UpdateStatusProgress { par curValue } {
        variable sPo
        variable pkgInt

        if { ! [winfo exists $par.progress] } {
            return
        }
        set pkgInt(progress,$par) $curValue
        if { [$par.progress cget -mode] eq "determinate" } {
            if { [poMisc HaveTcl87OrNewer] } {
                if { $curValue == 0 } {
                    $par.progress configure -text ""
                } else {
                    set maxValue [$par.progress cget -maximum]
                    set percent [format "%.0f%%" [expr {100.0 * $curValue / $maxValue}]]
                    $par.progress configure -text $percent
                }
            }
        }
        update
    }

    proc CheckValidInt { entryId labelId { minVal "" } { maxVal "" } } {
        set tmpVal [$entryId get]
        set success [poMath CheckIntRange $tmpVal $minVal $maxVal]
        if { $success } {
            $labelId configure -image [GetOkBitmap]
        } else {
            $labelId configure -image [GetWrongBitmap]
        }
        return $success
    }

    proc CheckValidReal { entryId labelId { minVal "" } { maxVal "" } } {
        set tmpVal [$entryId get]
        set success [poMath CheckRealRange $tmpVal $minVal $maxVal]
        if { $success } {
            $labelId configure -image [GetOkBitmap]
        } else {
            $labelId configure -image [GetWrongBitmap]
        }
        return $success
    }

    proc CheckValidString { entryId labelId { pattern "?*" } { format "" } } {
        set tmpVal [$entryId get]
        if { $format ne "" } {
            set success true
            set retList [scan $tmpVal $format]
            if { $retList eq "" } {
                set success false
            } else {
                foreach retVal $retList {
                    if { [llength $retVal] == 0 } {
                        set success false
                        break
                    }
                }
            }
        } else {
            set success [string match $pattern $tmpVal]
        }
        if { $success } {
            $labelId configure -image [GetOkBitmap]
        } else {
            $labelId configure -image [GetWrongBitmap]
        }
        return $success
    }

    proc CheckValidDateOrTime { entryId labelId dateOrTimeFmt } {
        set entryVal [$entryId get]
        set retVal [catch { clock scan $entryVal -format $dateOrTimeFmt } dateOrTimeVal]

        if { $retVal == 0 } {
            $labelId configure -image [GetOkBitmap]
        } else {
            $labelId configure -image [GetWrongBitmap]
        }
        return [expr { ! $retVal }]
    }

    proc SetDateFormat { fmt } {
        variable sChecked

        set sChecked(DateFmt) $fmt
    }

    proc GetDateFormat {} {
        variable sChecked

        return $sChecked(DateFmt)
    }

    proc SetTimeFormat { fmt } {
        variable sChecked

        set sChecked(TimeFmt) $fmt
    }

    proc GetTimeFormat {} {
        variable sChecked

        return $sChecked(TimeFmt)
    }

    proc _StoreVal { var w } {
        variable sChecked

        if { [info exists $var] } {
            set sChecked(StoredVal,$w) [set $var]
            set sChecked(SavedVal,$w)  [set $var]
        } else {
            set sChecked(StoredVal,$w) ""
            set sChecked(SavedVal,$w)  ""
        }
    }

    proc GetCheckedSavedValue { w } {
        variable sChecked

        if { [info exists sChecked(SavedVal,$w)] } {
            return $sChecked(SavedVal,$w)
        }
        return ""
    }

    proc GetCheckedEntryWidget { masterFr } {
        variable sChecked

        return $sChecked(EntryWidget,$masterFr)
    }

    proc _SetCheckedIntInterval { fr minVal maxVal } {
        if { $minVal eq "" && $maxVal eq "" } {
            poToolhelp AddBinding $fr.e "Allowed range: Any valid integer number"
        } elseif { $maxVal eq "" } {
            poToolhelp AddBinding $fr.e "Allowed range: $minVal to maximum integer"
        } else {
            poToolhelp AddBinding $fr.e "Allowed range: $minVal to $maxVal"
        }
        poWin CheckValidInt $fr.e $fr.l $minVal $maxVal
        bind $fr.e <Any-KeyRelease> "poWin CheckValidInt $fr.e $fr.l $minVal $maxVal"
    }

    proc _SetCheckedRealInterval { fr minVal maxVal } {
        if { $minVal eq "" && $maxVal eq "" } {
            poToolhelp AddBinding $fr.e "Allowed range: Any valid floating-point number"
        } elseif { $maxVal eq "" } {
            poToolhelp AddBinding $fr.e "Allowed range: $minVal to maximum float"
        } else {
            poToolhelp AddBinding $fr.e "Allowed range: $minVal to $maxVal"
        }
        poWin CheckValidReal $fr.e $fr.l $minVal $maxVal
        bind $fr.e <Any-KeyRelease> "poWin CheckValidReal $fr.e $fr.l $minVal $maxVal"
    }

    proc _SetCheckedIntFinal { fr var cmd minVal maxVal } {
        variable sChecked

        if { ! [poWin CheckValidInt $fr.e $fr.l $minVal $maxVal] } {
            set $var $sChecked(StoredVal,$fr.e)
            poWin CheckValidInt $fr.e $fr.l $minVal $maxVal
            return false
        }
        set sChecked(StoredVal,$fr.e) [set $var]
        if { $cmd ne "" } {
            {*}$cmd
        }
        return true
    }

    proc _SetCheckedRealFinal { fr var cmd minVal maxVal } {
        variable sChecked

        if { ! [poWin CheckValidReal $fr.e $fr.l $minVal $maxVal] } {
            set $var $sChecked(StoredVal,$fr.e)
            poWin CheckValidReal $fr.e $fr.l $minVal $maxVal
            return false
        }
        set sChecked(StoredVal,$fr.e) [set $var]
        if { $cmd ne "" } {
            {*}$cmd
        }
        return true
    }

    proc _SetCheckedStringFinal { fr var cmd pattern format } {
        variable sChecked

        if { ! [poWin CheckValidString $fr.e $fr.l $pattern $format] } {
            set $var $sChecked(StoredVal,$fr.e)
            poWin CheckValidString $fr.e $fr.l $pattern $format
            return false
        }
        set sChecked(StoredVal,$fr.e) [set $var]
        if { $cmd ne "" } {
            {*}$cmd
        }
        return true
    }

    proc _SetCheckedDateOrTimeFinal { fr var cmd pattern } {
        variable sChecked

        if { ! [poWin CheckValidDateOrTime $fr.e $fr.l $pattern] } {
            set $var $sChecked(StoredVal,$fr.e)
            poWin CheckValidDateOrTime $fr.e $fr.l $pattern
            return false
        }
        set sChecked(StoredVal,$fr.e) [set $var]
        if { $cmd ne "" } {
            {*}$cmd
        }
        return true
    }

    proc ForceCheck { w } {
        variable sChecked

        if { [info exists sChecked($w,ValidationCmd)] } {
            {*}$sChecked($w,ValidationCmd)
        }
    }

    proc SetCheckedIntRange { w { minVal "" } { maxVal "" } } {
        _SetCheckedIntInterval [poWin GetParentWidget $w] $minVal $maxVal
    }

    proc SetCheckedRealRange { w { minVal "" } { maxVal "" } } {
        _SetCheckedRealInterval [poWin GetParentWidget $w] $minVal $maxVal
    }

    proc _FindNextRowInGrid { fr } {
        set row 0
        while { [llength [grid slaves $fr -row $row]] != 0 } {
            incr row
        }
        return $row
    }

    proc CreateCheckedIntEntry { masterFr var args } {
        variable ns
        variable sChecked

        # Set default values for optional parameters.
        set opts [dict create \
            -min         "" \
            -max         "" \
            -width       $sChecked(DefaultWidth) \
            -justify     $sChecked(DefaultJustify) \
            -state       "normal"\
            -help        "" \
            -text        "" \
            -command     "" \
            -row         -1 \
            -labelcolumn 0 \
            -entrycolumn 1 \
        ]
        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                dict set opts $key $value
            } else {
                error "CreateCheckedIntEntry: Unknown option \"$key\" specified"
            }
        }

        set row [dict get $opts "-row"]
        if { $row < 0 } {
            set row [_FindNextRowInGrid $masterFr]
        }

        if { [dict get $opts "-text"] ne "" } {
            ttk::label $masterFr.l$row -text [dict get $opts "-text"]
            grid $masterFr.l$row -row $row -column [dict get $opts "-labelcolumn"] -sticky ew
            if { [dict get $opts "-help"] ne "" } {
                poToolhelp AddBinding $masterFr.l$row [dict get $opts "-help"]
            }
        }

        set fr [ttk::frame $masterFr.fr${row}_[dict get $opts "-entrycolumn"]]
        grid $fr -row $row -column [dict get $opts "-entrycolumn"] -sticky news
        ttk::entry $fr.e -textvariable $var \
            -justify [dict get $opts "-justify"] \
            -width   [dict get $opts "-width"] \
            -state   [dict get $opts "-state"]
        ttk::label $fr.l
        pack $fr.e -side left -padx 2 -fill x -expand 1
        pack $fr.l -side right
        set minVal [dict get $opts "-min"]
        set maxVal [dict get $opts "-max"]
        set cmd    [dict get $opts "-command"]
        _SetCheckedIntInterval $fr $minVal $maxVal
        bind $fr.e <FocusIn>    [list ${ns}::_StoreVal $var $fr.e]
        bind $fr.e <FocusOut>   [list ${ns}::_SetCheckedIntFinal $fr $var $cmd $minVal $maxVal]
        bind $fr.e <Key-Return> [list ${ns}::_SetCheckedIntFinal $fr $var $cmd $minVal $maxVal]
        set sChecked($fr.e,ValidationCmd) [list poWin::CheckValidInt $fr.e $fr.l $minVal $maxVal]
        set sChecked(EntryWidget,$masterFr) $fr.e
        return $fr.e
    }

    proc CreateCheckedRealEntry { masterFr var args } {
        variable ns
        variable sChecked

        # Set default values for optional parameters.
        set opts [dict create \
            -min         "" \
            -max         "" \
            -width       $sChecked(DefaultWidth) \
            -justify     $sChecked(DefaultJustify) \
            -state       "normal"\
            -help        "" \
            -text        "" \
            -command     "" \
            -row         -1 \
            -labelcolumn 0 \
            -entrycolumn 1 \
        ]
        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                dict set opts $key $value
            } else {
                error "CreateCheckedRealEntry: Unknown option \"$key\" specified"
            }
        }

        set row [dict get $opts "-row"]
        if { $row < 0 } {
            set row [_FindNextRowInGrid $masterFr]
        }

        if { [dict get $opts "-text"] ne "" } {
            ttk::label $masterFr.l$row -text [dict get $opts "-text"]
            grid $masterFr.l$row -row $row -column [dict get $opts "-labelcolumn"] -sticky ew
            if { [dict get $opts "-help"] ne "" } {
                poToolhelp AddBinding $masterFr.l$row [dict get $opts "-help"]
            }
        }

        set fr [ttk::frame $masterFr.fr${row}_[dict get $opts "-entrycolumn"]]
        grid $fr -row $row -column [dict get $opts "-entrycolumn"] -sticky news
        ttk::entry $fr.e -textvariable $var \
            -justify [dict get $opts "-justify"] \
            -width   [dict get $opts "-width"] \
            -state   [dict get $opts "-state"]
        ttk::label $fr.l
        pack $fr.e -side left -padx 2 -fill x -expand 1
        pack $fr.l -side right
        set minVal [dict get $opts "-min"]
        set maxVal [dict get $opts "-max"]
        set cmd    [dict get $opts "-command"]
        _SetCheckedRealInterval $fr $minVal $maxVal
        bind $fr.e <FocusIn>    [list ${ns}::_StoreVal $var $fr.e]
        bind $fr.e <FocusOut>   [list ${ns}::_SetCheckedRealFinal $fr $var $cmd $minVal $maxVal]
        bind $fr.e <Key-Return> [list ${ns}::_SetCheckedRealFinal $fr $var $cmd $minVal $maxVal]
        set sChecked($fr.e,ValidationCmd) [list poWin::CheckValidReal $fr.e $fr.l $minVal $maxVal]
        set sChecked(EntryWidget,$masterFr) $fr.e
        return $fr.e
    }

    proc CreateCheckedStringEntry { masterFr var args } {
        variable ns
        variable sChecked

        # Set default values for optional parameters.
        set opts [dict create \
            -pattern     "?*" \
            -format      "" \
            -width       $sChecked(DefaultWidth) \
            -justify     $sChecked(DefaultJustify) \
            -state       "normal"\
            -help        "" \
            -text        "" \
            -command     "" \
            -row         -1 \
            -labelcolumn 0 \
            -entrycolumn 1 \
        ]
        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                dict set opts $key $value
            } else {
                error "CreateCheckedStringEntry: Unknown option \"$key\" specified"
            }
        }

        set row [dict get $opts "-row"]
        if { $row < 0 } {
            set row [_FindNextRowInGrid $masterFr]
        }

        if { [dict get $opts "-text"] ne "" } {
            ttk::label $masterFr.l$row -text [dict get $opts "-text"]
            grid $masterFr.l$row -row $row -column [dict get $opts "-labelcolumn"] -sticky ew
            if { [dict get $opts "-help"] ne "" } {
                poToolhelp AddBinding $masterFr.l$row [dict get $opts "-help"]
            }
        }

        set fr [ttk::frame $masterFr.fr${row}_[dict get $opts "-entrycolumn"]]
        grid $fr -row $row -column [dict get $opts "-entrycolumn"] -sticky news
        ttk::entry $fr.e -textvariable $var \
            -justify [dict get $opts "-justify"] \
            -width   [dict get $opts "-width"] \
            -state   [dict get $opts "-state"]
        ttk::label $fr.l
        pack $fr.e -side left -padx 2 -fill x -expand 1
        pack $fr.l -side right
        set pattern [dict get $opts "-pattern"]
        set format  [dict get $opts "-format"]
        set cmd     [dict get $opts "-command"]
        # To use the pattern or format string (which might contains % signs),
        # we must replace each "%" with "%%" so they don't get substituted by the bind call.
        set patternSubst [regsub -all -- "%" $pattern "%%"]
        set formatSubst ""
        if { $format ne "" } {
            set formatSubst [regsub -all -- "%" $format "%%"]
            poToolhelp AddBinding $fr.e "Allowed string format: $format"
        } else {
            poToolhelp AddBinding $fr.e "Allowed string pattern: $pattern"
        }
        poWin CheckValidString $fr.e $fr.l $pattern $format
        bind $fr.e <Any-KeyRelease> [list ${ns}::CheckValidString $fr.e $fr.l $patternSubst $formatSubst]
        bind $fr.e <FocusIn>        [list ${ns}::_StoreVal $var $fr.e]
        bind $fr.e <FocusOut>       [list ${ns}::_SetCheckedStringFinal $fr $var $cmd $patternSubst $formatSubst]
        bind $fr.e <Key-Return>     [list ${ns}::_SetCheckedStringFinal $fr $var $cmd $patternSubst $formatSubst]
        set sChecked($fr.e,ValidationCmd) [list poWin::CheckValidString $fr.e $fr.l $pattern $format]
        set sChecked(EntryWidget,$masterFr) $fr.e
        return $fr.e
    }

    proc CreateCheckedDateEntry { masterFr var args } {
        variable ns
        variable sChecked

        # Set default values for optional parameters.
        set opts [dict create \
            -format      [GetDateFormat] \
            -width       $sChecked(DefaultWidth) \
            -justify     $sChecked(DefaultJustify) \
            -state       "normal"\
            -help        "" \
            -text        "" \
            -command     "" \
            -row         -1 \
            -labelcolumn 0 \
            -entrycolumn 1 \
        ]
        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                dict set opts $key $value
            } else {
                error "CreateCheckedDateEntry: Unknown option \"$key\" specified"
            }
        }

        set row [dict get $opts "-row"]
        if { $row < 0 } {
            set row [_FindNextRowInGrid $masterFr]
        }

        if { [dict get $opts "-text"] ne "" } {
            ttk::label $masterFr.l$row -text [dict get $opts "-text"]
            grid $masterFr.l$row -row $row -column [dict get $opts "-labelcolumn"] -sticky ew
            if { [dict get $opts "-help"] ne "" } {
                poToolhelp AddBinding $masterFr.l$row [dict get $opts "-help"]
            }
        }

        set fr [ttk::frame $masterFr.fr${row}_[dict get $opts "-entrycolumn"]]
        grid $fr -row $row -column [dict get $opts "-entrycolumn"] -sticky news
        ttk::entry $fr.e -textvariable $var \
            -justify [dict get $opts "-justify"] \
            -width   [dict get $opts "-width"] \
            -state   [dict get $opts "-state"]
        ttk::label $fr.l
        pack $fr.e -side left -padx 2 -fill x -expand 1
        pack $fr.l -side right

        set dateFmt [dict get $opts "-format"]
        poWin CheckValidDateOrTime $fr.e $fr.l $dateFmt
        set cmd [dict get $opts "-command"]
        # To use the date or time format (which contains % signs), we must replace each "%"
        # with "%%" so they don't get substituted by the bind call.
        set bindFmt [regsub -all -- "%" $dateFmt "%%"]
        poToolhelp AddBinding $fr.e "Date format: [regsub -all -- "%" $dateFmt ""]"
        bind $fr.e <Any-KeyRelease> [list poWin CheckValidDateOrTime $fr.e $fr.l $bindFmt]
        bind $fr.e <FocusIn>        [list ${ns}::_StoreVal $var $fr.e]
        bind $fr.e <FocusOut>       [list ${ns}::_SetCheckedDateOrTimeFinal $fr $var $cmd $bindFmt]
        bind $fr.e <Key-Return>     [list ${ns}::_SetCheckedDateOrTimeFinal $fr $var $cmd $bindFmt]
        set sChecked($fr.e,ValidationCmd) [list poWin::CheckValidDateOrTime $fr.e $fr.l $dateFmt]
        set sChecked(EntryWidget,$masterFr) $fr.e
        return $fr.e
    }

    proc CreateCheckedTimeEntry { masterFr var args } {
        variable ns
        variable sChecked

        set opts [dict create \
            -format      [GetTimeFormat] \
            -width       $sChecked(DefaultWidth) \
            -justify     $sChecked(DefaultJustify) \
            -state       "normal"\
            -help        "" \
            -text        "" \
            -command     "" \
            -row         -1 \
            -labelcolumn 0 \
            -entrycolumn 1 \
        ]
        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                dict set opts $key $value
            } else {
                error "CreateCheckedTimeEntry: Unknown option \"$key\" specified"
            }
        }

        set row [dict get $opts "-row"]
        if { $row < 0 } {
            set row [_FindNextRowInGrid $masterFr]
        }

        if { [dict get $opts "-text"] ne "" } {
            ttk::label $masterFr.l$row -text [dict get $opts "-text"]
            grid $masterFr.l$row -row $row -column [dict get $opts "-labelcolumn"] -sticky ew
            if { [dict get $opts "-help"] ne "" } {
                poToolhelp AddBinding $masterFr.l$row [dict get $opts "-help"]
            }
        }

        set fr [ttk::frame $masterFr.fr${row}_[dict get $opts "-entrycolumn"]]
        grid $fr -row $row -column [dict get $opts "-entrycolumn"] -sticky news
        ttk::entry $fr.e -textvariable $var \
            -justify [dict get $opts "-justify"] \
            -width   [dict get $opts "-width"] \
            -state   [dict get $opts "-state"]
        ttk::label $fr.l
        pack $fr.e -side left -padx 2 -fill x -expand 1
        pack $fr.l -side right

        set timeFmt [dict get $opts "-format"]

        poWin CheckValidDateOrTime $fr.e $fr.l $timeFmt
        set cmd [dict get $opts "-command"]
        # To use the date or time format (which contains % signs), we must replace each "%"
        # with "%%" so they don't get substituted by the bind call.
        set bindFmt [regsub -all -- "%" $timeFmt "%%"]
        poToolhelp AddBinding $fr.e "Time format: [regsub -all -- "%" $timeFmt ""]"
        bind $fr.e <Any-KeyRelease> [list poWin CheckValidDateOrTime $fr.e $fr.l $bindFmt]
        bind $fr.e <FocusIn>        [list ${ns}::_StoreVal $var $fr.e]
        bind $fr.e <FocusOut>       [list ${ns}::_SetCheckedDateOrTimeFinal $fr $var $cmd $bindFmt]
        bind $fr.e <Key-Return>     [list ${ns}::_SetCheckedDateOrTimeFinal $fr $var $cmd $bindFmt]
        set sChecked($fr.e,ValidationCmd) [list poWin::CheckValidDateOrTime $fr.e $fr.l $timeFmt]
        set sChecked(EntryWidget,$masterFr) $fr.e
        return $fr.e
    }

    proc ShowPkgInfo { pkgDict } {
        set tw .poWin_PkgInfoWin
        catch { destroy $tw }

        toplevel $tw
        wm title $tw "Package Information"
        wm resizable $tw true true

        ttk::frame $tw.fr0
        grid $tw.fr0 -row 0 -column 0 -sticky news
        set rows [dict size $pkgDict]
        set textId [CreateScrolledText $tw.fr0 true "" -wrap none \
                   -width 40 -height [expr $rows + 1]]
        set maxLen 0
        foreach pkg [dict keys $pkgDict] {
            if { [string length $pkg] > $maxLen } {
                set maxLen [string length $pkg]
            }
        }
        foreach pkg [dict keys $pkgDict] {
            set msgStr [format "%-${maxLen}s: %s\n" $pkg [dict get $pkgDict $pkg version]]
            if { [dict get $pkgDict $pkg loaded] } {
                set tag loaded
            } else {
                set tag notloaded
            }
            $textId insert end $msgStr $tag
        }
        $textId tag configure loaded    -background lightgreen
        $textId tag configure notloaded -background red
        $textId configure -state disabled

        grid columnconfigure $tw 0 -weight 1
        grid rowconfigure    $tw 0 -weight 1

        bind $tw <Escape> "destroy $tw"
        bind $tw <Return> "destroy $tw"
        focus $tw
    }

    proc StartScreenSaver { msg } {
        variable ns
        variable stopit

        set tw .poWin_ScreenSaverWin
        catch { destroy $tw}

        toplevel $tw
        canvas $tw.img -borderwidth 0 -bg blue
        pack $tw.img -fill both -expand 1 -side left

        set h [winfo screenheight .]
        set w [winfo screenwidth .]
        set fmtStr [format "%dx%d+0+0" $w $h]
        wm geometry $tw $fmtStr
        wm overrideredirect $tw 1
        wm attributes $tw -topmost 1

        bind $tw <KeyPress> "set ${ns}::stopit 1"
        bind $tw.img <KeyPress> "set ${ns}::stopit 1"
        bind $tw <Motion> "set ${ns}::stopit 1"
        focus -force $tw

        set xpos 0
        set ypos 0
        set ph2 [image create photo]
        $ph2 copy [::poImgData::poLogo] -subsample 2 2
        set ph1 [poPhotoUtil FlipHorizontal $ph2]
        set phWidth  [image width $ph1]
        set phHeight [image height $ph1]
        $tw.img create image -200 -200 -anchor nw -tag img1 -image $ph1
        $tw.img create image $xpos $ypos -anchor nw -tag img2 -image $ph2
        $tw.img create text -200 -200 -text $msg -tag msg
        $tw.img coords msg [expr $w/2] [expr $h/2]
        $tw.img raise img2
        update

        set xoff 2
        set yoff 2
        set i 2
        set updown 1

        set stopit 0
        while { $stopit == 0 } {
            incr xpos $xoff
            $tw.img coords img$i $xpos $ypos
            update
            if { $xpos >= [expr $w - $phWidth] || $xpos < 0 } {
                if { $xoff > 0 } {
                    incr xoff $updown
                    incr yoff
                }
                set xoff [expr -1 * $xoff]
                if { $ypos >= [expr $h - $phHeight] || $ypos < 0 } {
                    set updown [expr -1 * $updown]
                    set yoff [expr -1 * $yoff]
                }
                incr ypos $yoff
                set i [expr $i % 2 + 1]
                $tw.img raise img$i
            }
        }
        destroy $tw
    }

    proc LoadFileToTextWidget { w fileName { mode r } } {
        set retVal [catch {open $fileName r} fp]
        if { $retVal != 0 } {
            error "Could not open file $fileName for reading."
        }
        if { $mode eq "r" } {
            $w delete 1.0 end
        }
        while { ![eof $fp] } {
            $w insert end [read $fp 2048]
        }
        close $fp
    }

    proc ChooseDirectory { title initDir { useTkChooser 1 } } {
        if { $useTkChooser } {
            set selDir [tk_chooseDirectory -initialdir $initDir \
                                           -mustexist 1 \
                                           -title $title]
        } else {
            set selDir [poTree GetDir -initialdir $initDir \
                                      -title $title \
                                      -showfiles 1]
        }
        return $selDir
    }
}

poWin Init
