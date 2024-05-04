# Module:         poImgBrowse
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 10 / 22
#
# Distributed under BSD license.
#
# Module for browsing and previewing images.

namespace eval poImgBrowse {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export LoadSettings SaveSettings
    namespace export ShowMainWin CloseAppWindow
    namespace export ParseCommandLine IsOpen
    namespace export GetUsageMsg SetVerbose
    namespace export GetThumbSize
    namespace export GetSelectedFiles

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

    proc SetMainWindowSash { sashX sashY } {
        variable sPo

        set sPo(sashX) $sashX
        set sPo(sashY) $sashY
    }

    proc GetMainWindowSash {} {
        variable sPo

        if { [info exists sPo(paneHori)] && \
            [winfo exists $sPo(paneHori)] } {
            set sashX [$sPo(paneHori) sashpos 0]
            set sashY [$sPo(paneVert) sashpos 0]
        } else {
            set sashX $sPo(sashX)
            set sashY $sPo(sashY)
        }
        return [list $sashX $sashY]
    }

    proc SetThumbOptions { thumbSize saveThumbs useHiddenThumbDir } {
        variable sPo

        set sPo(thumbSize)      $thumbSize
        set sPo(saveThumb)      $saveThumbs
        set sPo(hiddenThumbDir) $useHiddenThumbDir
    }

    proc GetThumbOptions {} {
        variable sPo

        return [list $sPo(thumbSize) \
                     $sPo(saveThumb) \
                     $sPo(hiddenThumbDir)]
    }

    proc GetThumbSize {} {
        variable sPo

        return $sPo(thumbSize)
    }

    proc SetUpdateInterval { interval } {
        variable sPo

        set sPo(updateInterval) $interval
    }

    proc GetUpdateInterval {} {
        variable sPo

        return [list $sPo(updateInterval)]
    }

    proc SetViewOptions { showThumb showFileInfo } {
        variable sPo

        set sPo(showThumb)    $showThumb
        set sPo(showFileInfo) $showFileInfo
    }

    proc GetViewOptions {} {
        variable sPo

        return [list $sPo(showThumb) \
                     $sPo(showFileInfo)]
    }

    proc SetFilterOptions { prefixFilter suffixFilter } {
        variable sPo

        set sPo(prefixFilter) $prefixFilter
        set sPo(suffixFilter) $suffixFilter
    }

    proc GetFilterOptions {} {
        variable sPo

        return [list $sPo(prefixFilter) \
                     $sPo(suffixFilter)]
    }

    proc SetLastUsedDir { dir } {
        variable sPo

        set sPo(lastDir) $dir
    }

    proc GetLastUsedDir {} {
        variable sPo

        return [list $sPo(lastDir)]
    }

    # Init module specific variables to default values.
    proc Init {} {
        variable sPo
        variable pkgCol
        variable pkgInt
        variable msgStr
        variable detailWinNo

        set sPo(tw)      ".poImgBrowse" ; # Name of toplevel window
        set sPo(appName) "poImgBrowse"  ; # Name of tool
        set sPo(cfgDir)  ""             ; # Directory containing config files

        set detailWinNo 1

        SetStopBrowsing

        set sPo(KeyRepeatTime) 600      ; # ms

        set pkgInt(infoWinList) [list]
        set pkgInt(settWin) .poImgBrowse_SettWin

        set pkgInt(colNameList)  [list "Index" "Image" "Filename" "Type" \
                                       "Size" "Date" "Width" "Height" \
                                       "X-DPI" "Y-DPI" "Pages"]
        set pkgInt(colWidthList) [list 5 6 20 6 \
                                       8 15 7 7 \
                                       6 6 6]
        set pkgInt(colAlignList) [list right center left left \
                                       right left right right \
                                       right right right]
        set pkgInt(colSortList) [list integer ascii dictionary ascii \
                                      integer dictionary integer integer \
                                      integer integer integer]
        set pkgInt(numColumns)  [llength $pkgInt(colNameList)]

        set pkgCol(Ind)     0
        set pkgCol(Img)     1
        set pkgCol(Name)    2
        set pkgCol(Type)    3
        set pkgCol(Size)    4
        set pkgCol(Date)    5
        set pkgCol(Width)   6
        set pkgCol(Height)  7
        set pkgCol(X-DPI)   8
        set pkgCol(Y-DPI)   9
        set pkgCol(Pages)  10 

        set pkgInt(maxThumbSize) 100
        set pkgInt(selMode) "none"
        set pkgInt(allFiles) "All files"
        set pkgInt(allImgs)  "All images"

        array set msgStr [list \
            SaveOpts        "Save options: " \
            ViewOpts        "View options: " \
            ThumbSize       "Thumbnail size (Pixel): " \
            UpdateInterval  "Update interval (Image): " \
            SaveThumb       "Generate thumbnails" \
            HiddenThumbDir  "Hidden thumbnail directory" \
            ShowThumb       "Show thumbnail" \
            GenAllThumbs    "Generate all thumbnails" \
            DelAllThumbs    "Delete all thumbnails" \
            ShowImgInfo     "Show image info" \
            ShowFileInfo    "Show file info" \
            ShowFileType    "Show file type" \
            OpenFile        "Open selected files (Ctrl+O)" \
            DelFile         "Delete selected files (Del)" \
            RenameFile      "Rename selected file (F2)" \
            FileInfo        "View file info (Ctrl+I)" \
            UpdateList      "Update file list (F5)" \
            ClearImgCache   "Clear image cache" \
            StopImgLoad     "Stop image loading (Esc)" \
            Cancel          "Cancel" \
            OK              "OK" \
            Confirm         "Confirmation" \
            WinTitle        "Image browser options" \
            ProgressWinTitle "Thumbnail generation progress" \
        ]
    }

    proc Str { key args } {
        variable msgStr

        set str $msgStr($key)
        return [eval {format $str} $args]
    }

    # Functions for handling the settings window of this module.

    proc CloseWin { w } {
        if { [winfo exists $w] } {
            SetWindowPos settWin [winfo x $w] [winfo y $w] [winfo width $w] [winfo height $w]
        }
        destroy $w
    }

    proc CancelWin { w args } {
        variable sPo

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        CloseWin $w
    }

    proc OkWin { w } {
        CloseWin $w
    }

    proc ClearImgCache { tbl } {
        variable pkgInt
        variable pkgCol

        for { set row 0 } { $row < [$tbl size] } { incr row } {
            $tbl cellconfigure $row,$pkgCol(Img) -image $pkgInt(placeholderImg)
        }
        foreach key [array names pkgInt "*,photo"] {
            if { $pkgInt($key) ne "" } {
                image delete $pkgInt($key)
            }
            unset pkgInt($key)
        }
    }

    proc OpenWin { fr } {
        variable ns
        variable sPo
        variable pkgInt

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           [Str ThumbSize] \
                           [Str UpdateInterval] \
                           [Str SaveOpts] \
                           [Str ViewOpts] ] {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList [list]

        # Generate right column with entries and buttons.
        # Row 0: Thumbnail size option
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(thumbSize) -row $row -width 3 -min 10

        set tmpList [list [list sPo(thumbSize)] [list $sPo(thumbSize)]]
        lappend varList $tmpList

        # Row 1: Thumbnail size option
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedIntEntry $tw.fr$row ${ns}::sPo(updateInterval) -row $row -width 3 -min 1 -max 50

        set tmpList [list [list sPo(updateInterval)] [list $sPo(updateInterval)]]
        lappend varList $tmpList

        # Row 2: Save options
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text [Str SaveThumb] \
                    -variable ${ns}::sPo(saveThumb) \
                    -onvalue 1 -offvalue 0
        ttk::checkbutton $tw.fr$row.cb2 -text [Str HiddenThumbDir] \
                    -variable ${ns}::sPo(hiddenThumbDir) \
                    -onvalue 1 -offvalue 0
        pack $tw.fr$row.cb1 $tw.fr$row.cb2 -side top -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(saveThumb)] [list $sPo(saveThumb)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(hiddenThumbDir)] [list $sPo(hiddenThumbDir)]]
        lappend varList $tmpList

        # Row 3: View options
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text [Str ShowThumb] \
                    -variable ${ns}::sPo(showThumb) \
                    -onvalue 1 -offvalue 0
        poToolhelp AddBinding $tw.fr$row.cb1 "Column: Image"
        ttk::checkbutton $tw.fr$row.cb2 -text [Str ShowFileInfo] \
                    -variable ${ns}::sPo(showFileInfo) \
                    -onvalue 1 -offvalue 0
        poToolhelp AddBinding $tw.fr$row.cb2 "Columns: Type, Size, Date, Width, Height, X-DPI, Y-DPI, Pages"
        pack $tw.fr$row.cb1 $tw.fr$row.cb2 -side top -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(showThumb)] [list $sPo(showThumb)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(showFileInfo)] [list $sPo(showFileInfo)]]
        lappend varList $tmpList

        return $varList
    }

    proc ReadThumbFile { thumbFile } {
        variable sPo

        set retVal [catch {image create photo -file $thumbFile} phImg]
        if { $retVal != 0 } {
            return ""
        } else {
            if { $sPo(thumbSize) != [image width $phImg] || \
                 $sPo(thumbSize) != [image height $phImg] } {
                WriteInfoStr "Stored thumbnails do not fit current settings. Delete and update thumbnails." "Error"
                SetStopBrowsing
                return ""
            }
            return $phImg
        }
    }

    proc GetFileList {dirName} {
        variable pkgInt
        variable sPo

        set fmt $sPo(suffixFilter)
        if { $sPo(suffixFilter) eq $pkgInt(allFiles) } {
            set matchList [format "%s*" $sPo(prefixFilter)]
        } else {
            if { $sPo(suffixFilter) eq $pkgInt(allImgs) } {
                set fmt ""
            }
            foreach ext [poImgType GetExtList $fmt] {
                lappend matchList [format "%s%s" $sPo(prefixFilter) $ext]
            }
        }

        set fileList [lsort -dictionary [lindex [poMisc GetDirsAndFiles $dirName -showdirs false] 1] ]

        set imgFileList [list]
        foreach f $fileList {
            foreach patt $matchList {
                if { [string match -nocase $patt $f] } {
                    lappend imgFileList $f
                    break
                }
            }
        }
        return $imgFileList
    }

    proc GetFullPath { tbl row col dirName } {
        set fileName [$tbl cellcget $row,$col -text]
        set fileName [poMisc QuoteTilde $fileName]
        return [file join $dirName $fileName]
    }

    proc GetSelRows { tbl } {
        return [$tbl curselection]
    }

    proc GetSelFiles { tbl } {
        variable pkgCol

        set fileList [list]
        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]

        foreach row [lsort -integer $rowList] {
            set fileName [GetFullPath $tbl $row $pkgCol(Name) $dirName]
            lappend fileList $fileName
        }
        return $fileList
    }

    proc OpenContextMenu { tbl tblBody x y selFunc } {
        global tcl_platform
        variable ns
        variable sPo
        variable pkgInt

        set w .poImgBrowse:contextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        foreach { ::tablelist::W ::tablelist::x ::tablelist::y } \
            [::tablelist::convEventFields $tblBody $x $y] {}

        set rowList [GetSelRows $tbl]
        set len [llength $rowList]
        set numRows [$tbl size]

        if { $numRows == 0 } {
            set menuTitle "No files in directory"
            $w add command -label "$menuTitle" -state disabled -background "#303030"
        } elseif { $len == 0 } {
            set menuTitle "Nothing selected"
            $w add command -label "$menuTitle" -state disabled -background "#303030"
        } elseif { [RowsSelected $tbl] } {
            set fileList [GetSelFiles $tbl]
            if { [llength $fileList] == 1 } {
                set menuTitle "[file tail [lindex $fileList 0]] selected"
                set imgStr "image"
            } else {
                set menuTitle "[llength $fileList] files selected"
                set imgStr "images"
            }
            $w add command -label "$menuTitle" -state disabled -background "#303030"
            $w add command -label "Info" -command "${ns}::ShowImgInfo $tbl"
            $w add command -label "HexDump" -command "poExtProg StartHexEditProg [list $fileList]"

            $w add separator
            $w add command -label "Slide show" -command "${ns}::SlideShowFile $tbl"
            if { $tcl_platform(platform) eq "windows" } {
                $w add command -label "Append to PowerPoint" -command "${ns}::AppendToPpt $tbl"
            }

            $w add separator
            $w add command -label "Open file" -command "${ns}::LoadImgs $selFunc $fileList"
            if { [llength $fileList] == 1 } {
                $w add separator
                $w add command -label "Rename file ..." -command "${ns}::AskRenameFile $tbl"
            } elseif { [llength $fileList] == 2 } {
                $w add separator
                $w add command -label "Diff ..." -command "${ns}::DiffFiles $tbl"
            }

            set shownDirName [poAppearance CutFilePath $sPo(lastDir)]
            $w add separator
            $w add command -label "Copy file to ..." -underline 0 \
                       -command "${ns}::AskCopyOrMoveTo $tbl copy"
            if { [file isdirectory $sPo(lastDir)] } {
                $w add command -label "Copy file to ${shownDirName}/" -underline 0 \
                       -command "${ns}::AskCopyOrMoveTo $tbl copy $sPo(lastDir)"
            }
            $w add command -label "Move file to ..." -underline 0 \
                       -command "${ns}::AskCopyOrMoveTo $tbl move"
            if { [file isdirectory $sPo(lastDir)] } {
                $w add command -label "Move file to ${shownDirName}/" -underline 0 \
                       -command "${ns}::AskCopyOrMoveTo $tbl move $sPo(lastDir)"
            }

            $w add separator
            $w add command -label "Delete file ..." -activebackground "#FC3030" \
                       -command "${ns}::AskDelFile $tbl"
        }
        tk_popup $w [expr {$x +5}] [expr {$y +5}]
    }

    proc ShowSelection { tbl dir } {
        if { $dir eq "Home" } {
            $tbl see 0
        } elseif { $dir eq "End" } {
           $tbl see [$tbl size]
        }
        UpdateVisImgs $tbl
    }

    proc CloseSubWindows {} {
        variable pkgInt

        foreach w $pkgInt(infoWinList) {
            if { [winfo exists $w] } {
                poWinInfo DeleteInfoWin $w
            }
        }
        unset pkgInt(infoWinList)
        set pkgInt(infoWinList) {}
    }

    proc CloseAppWindow {} {
        variable sPo
        variable pkgInt

        if { ! [info exists sPo(tw)] || ! [winfo exists $sPo(tw)] } {
            return
        }

        SetStopBrowsing
        if { [info exists sPo(imgLoadId)] } {
            after cancel $sPo(imgLoadId)
        }

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        # Clear preview photo image.
        poWinPreview Clear $pkgInt(previewWidget)

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

    proc SetStopBrowsing { { onOff true } } {
        variable pkgInt

        set pkgInt(stopBrowse) $onOff
    }

    proc StopBrowsing {} {
        variable pkgInt

        return $pkgInt(stopBrowse)
    }

    proc RemovePhotos { row1 row2 } {
        variable pkgCol
        variable pkgInt

        for { set row $row1 } { $row <= $row2 } { incr row } {
            $pkgInt(tableId) cellconfigure $row,$pkgCol(Img) -text ""
            $pkgInt(tableId) cellconfigure $row,$pkgCol(Img) -image $pkgInt(placeholderImg)
        }
    }

    proc DelAllThumbs { tbl } {
        variable pkgCol

        set dirName  [GetSelImgDir]
        set thumbDir [GetThumbDir $dirName]
        file delete -force $thumbDir
        WriteInfoStr "Deleted thumbnails of directory $dirName" "Ok"
    }

    proc CloseProgressWin {} {
        variable pkgInt

        set w .poImgBrowse_ProgressWin
        destroy $w
    }

    proc OpenProgressWin { dirName } {
        variable ns
        variable pkgInt
        variable sPo

        set w .poImgBrowse_ProgressWin

        if { [winfo exists $w] } {
            poWin Raise $w
            return
        }

        toplevel $w
        wm title $w [Str ProgressWinTitle]
        wm resizable $w false false

        ttk::label $w.dir1 -text "Directory:"
        ttk::label $w.dir2 -text "$dirName" -width 30 -anchor w

        ttk::label $w.todo1 -text "Still to do:"
        ttk::label $w.todo2 -textvariable ${ns}::pkgInt(progressTodo) -width 30 -anchor w

        ttk::label $w.name1 -text "Current image:"
        ttk::label $w.name2 -textvariable ${ns}::pkgInt(progressName) -width 30 -anchor w

        if { $sPo(showThumb) } {
            set size $sPo(thumbSize)
        } else {
            set size 1
        }
        ttk::label $w.img -anchor center
        set pkgInt(progressLabel) $w.img

        ttk::button $w.cancel -textvariable ${ns}::pkgInt(progressBtn) \
            -command "${ns}::SetStopBrowsing ; ${ns}::CloseProgressWin" \
            -default active
        bind $w <KeyPress-Escape> ${ns}::SetStopBrowsing

        grid $w.dir1   -row 0 -column 0 -sticky ew
        grid $w.dir2   -row 0 -column 1 -sticky ew
        grid $w.todo1  -row 1 -column 0 -sticky ew
        grid $w.todo2  -row 1 -column 1 -sticky ew
        grid $w.name1  -row 2 -column 0 -sticky ew
        grid $w.name2  -row 2 -column 1 -sticky ew
        grid $w.img    -row 3 -column 0 -columnspan 2 -sticky news
        grid $w.cancel -row 4 -column 0 -columnspan 2 -sticky news -pady 2
        focus $w
    }

    proc GenAllThumbs { tbl { withSubDirs 0 } } {
        variable pkgInt
        variable sPo
        variable pkgCol

        SetStopBrowsing false
        set numRows  [$tbl size]
        set dirName  [GetSelImgDir]
        set thumbDir [GetThumbDir $dirName]
        set pkgInt(progressTodo) "$numRows"
        set pkgInt(progressName) "Initializing ..."
        set pkgInt(progressBtn)  "Cancel"
        OpenProgressWin $dirName
        if { ! [CreateThumbDir $thumbDir] } {
            WriteInfoStr "Unable to create thumbs directory $thumbDir. Check permissions." "Error"
            return
        }
        for { set row 0 } { $row < $numRows } { incr row } {
            set imgName [$tbl cellcget $row,$pkgCol(Name) -text]
            set imgName [poMisc QuoteTilde $imgName]
            set imgFile [file join $dirName $imgName]
            set thumbFile [BuildThumbFileName $thumbDir $imgName]
            set thumbExists [expr [file exists $thumbFile]]
            set msgStr "Image: $imgName Thumb: "
            set pkgInt(progressTodo) [expr {$numRows - $row}]
            set pkgInt(progressName) $imgName
            if { ! $thumbExists } {
                set imgDict [poImgMisc LoadImgScaled $imgFile $sPo(thumbSize) $sPo(thumbSize)]
                set phImg [dict get $imgDict phImg]
                if { $phImg ne "" } {
                    if { $sPo(showThumb) } {
                        $pkgInt(progressLabel) configure -image $phImg
                        update
                    }
                    set retVal [catch {$phImg write $thumbFile -format PNG}]
                    if { $retVal != 0 } {
                        append msgStr "NOT generated"
                    }
                    image delete $phImg
                } else {
                    append msgStr "NOT generated"
                }
            } else {
                append msgStr "Already exists"
            }

            if { [StopBrowsing] } {
                CloseProgressWin
                return
            }
        }
        set pkgInt(progressTodo) 0
        set pkgInt(progressName) "Finished"
        set pkgInt(progressBtn)  "OK"
        WriteInfoStr "Updated thumbnails of directory $dirName" "Ok"
        update
        return
    }

    proc LoadThumbnails { tbl } {
        variable ns
        variable sPo
        variable pkgInt
        variable pkgCol

        if { [StopBrowsing] } {
            WriteInfoStr "Loading thumbnails cancelled." "Cancel"
            poWin UpdateStatusProgress $sPo(StatusWidget) 0
            return
        }
        foreach { row1 row2 } [GetVisibleRows $tbl] { break }
        set dirName  [GetSelImgDir]
        set thumbDir [GetThumbDir $dirName]
        if { $sPo(saveThumb) } {
            CreateThumbDir $thumbDir
        }
        set imgReplaced false
        set row $row1
        set count 0
        while { 1 } {
            if { $row >= [$tbl size] } {
                WriteInfoStr ""
                poWin UpdateStatusProgress $sPo(StatusWidget) 0
                return
            }
            set imgName [$tbl cellcget $row,$pkgCol(Name) -text]
            set imgName [poMisc QuoteTilde $imgName]
            set imgFile [file join $dirName $imgName]
            if { ! [info exists pkgInt($imgFile,photo)] } {
                if { [poImgMisc IsImageFile $imgFile] } {
                    set thumbFile [BuildThumbFileName $thumbDir $imgName]
                    set thumbExists [expr {[file exists $thumbFile]}]

                    if { $thumbExists } {
                        set phImg [ReadThumbFile $thumbFile]
                    } else {
                        set imgDict [poImgMisc LoadImgScaled $imgFile \
                                               $sPo(thumbSize) $sPo(thumbSize)]
                        set phImg [dict get $imgDict phImg]
                    }

                    if { $sPo(saveThumb) } {
                        if { ! $thumbExists } {
                            set retVal [catch {$phImg write $thumbFile -format PNG}]
                            if { $retVal != 0 } {
                                WriteInfoStr "Cannot write thumb file $thumbFile" "Error"
                            }
                        }
                    }
                } else {
                    set phImg ""
                }
                set imgReplaced true
                set pkgInt($imgFile,photo) $phImg
            }

            if { [$tbl cellcget $row,$pkgCol(Img) -image] eq $pkgInt(placeholderImg) } {
                set phImg $pkgInt($imgFile,photo)
                if { $phImg ne "" } {
                    $tbl cellconfigure $row,$pkgCol(Img) -image $phImg
                } else {
                    $tbl cellconfigure $row,$pkgCol(Img) -image $pkgInt(errorImg)
                }
            }
            set row [expr { ($row + 1) % [$tbl size] }]
            if { $imgReplaced } {
                if { $row <= $row2 || $count % $sPo(updateInterval) == 0 } {
                    poWin UpdateStatusProgress $sPo(StatusWidget) $count
                    break
                }
            }
            incr count
            if { $count == [$tbl size] } {
                set t [poWatch Lookup _poImgBrowseSwatch]
                set msg [format "Loaded %d files: %.2f sec (%.1f msec/img)" \
                        $count $t [expr 1000.0*$t/$count]]
                WriteInfoStr $msg
                poWin UpdateStatusProgress $sPo(StatusWidget) 0
                if { [poApps GetVerbose] } {
                    puts $msg
                }
                return
            }
        }
        set sPo(imgLoadId) [after 1 ${ns}::LoadThumbnails $tbl]
    }

    proc UpdateVisImgs { tbl { force false } } {
        variable sPo
        variable pkgInt

        if { [$tbl size] == 0 } {
            return
        }

        if { $force } {
            RemovePhotos 0 [expr {[$tbl size] -1}]
        }
        WriteInfoStr "Loading thumbnail images ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) [$tbl size]
        poWatch Reset _poImgBrowseSwatch
        poWatch Start _poImgBrowseSwatch
        LoadThumbnails $tbl
    }

    proc ShowImgInfo { tbl } {
        variable ns
        variable sPo
        variable pkgCol
        variable pkgInt

        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No files selected for info" "Error"
            return
        }
        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]
        set numImgs [llength $rowList]

        if { $numImgs == 0 } {
            WriteInfoStr "No files selected for info" "Error"
            return
        }

        $sPo(tw) configure -cursor watch
        update

        foreach row $rowList {
            set fileName [GetFullPath $tbl $row $pkgCol(Name) $dirName]
            set infoWin [poWinInfo CreateInfoWin $fileName -tab "Preview"]
            lappend pkgInt(infoWinList) $infoWin
        }
        $sPo(tw) configure -cursor arrow
    }

    proc RowsSelected { tbl } {
        return [llength [$tbl curselection]]
    }

    proc AskCopyOrMoveTo { tbl mode { dstDir "" } } {
        variable pkgCol
        variable pkgInt
        variable sPo

        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No files selected for copy or move" "Error"
            return
        }

        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]
        if { [llength $rowList] == 0 } {
            WriteInfoStr "No files selected for copy or move" "Error"
            return
        }

        if { $dstDir eq "" } {
            set dstDir [poTree GetDir -initialdir $sPo(lastDir) -showfiles 0 \
                                      -title "Select directory to copy files into"]
        }
        if { $dstDir ne "" && [file isdirectory $dstDir] } {
            set sPo(lastDir) $dstDir

            foreach row $rowList {
                set srcName [GetFullPath $tbl $row $pkgCol(Name) $dirName]
                set dstName [GetFullPath $tbl $row $pkgCol(Name) $dstDir]
                if { [file exists $dstName] } {
                    set retVal [tk_messageBox \
                      -title "Confirmation" \
                      -message "Overwrite existing file $dstName ?" \
                      -type yesnocancel -default yes -icon question]
                    if { $retVal eq "cancel" } {
                        return
                    } elseif { $retVal eq "no" } {
                        continue
                    }
                }
                if { $mode eq "copy" } {
                    WriteInfoStr "Copying file $srcName to $dstDir" "Watch"
                    update
                    file copy -force -- $srcName $dstDir
                } else {
                    WriteInfoStr "Moving file $srcName to $dstDir" "Watch"
                    update
                    file rename -force -- $srcName $dstDir
                }
            }
            set numFiles [llength $rowList]
            if { $mode eq "copy" } {
                WriteInfoStr "Copied $numFiles file[poMisc Plural $numFiles] to $dstDir" "Ok"
            } else {
                ShowFileList
                $tbl see $row
                WriteInfoStr "Moved $numFiles file[poMisc Plural $numFiles] to $dstDir" "Ok"
            }
        }
    }

    proc DiffFiles { tbl } {
        variable pkgCol
        variable pkgInt

        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No files selected for diffing" "Error"
            return
        }
        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]

        set numSel [llength $rowList]
        if { $numSel != 2 } {
            WriteInfoStr "Diffing only possible for 2 files" "Error"
            return
        }

        set row1 [lindex $rowList 0]
        set leftFile [GetFullPath $tbl $row1 $pkgCol(Name) $dirName]
        set row2 [lindex $rowList 1]
        set rightFile [GetFullPath $tbl $row2 $pkgCol(Name) $dirName]

        poApps StartApp poImgdiff [list $leftFile $rightFile]
    }

    proc AskRenameFile { tbl } {
        variable pkgCol
        variable pkgInt

        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No file selected for renaming" "Error"
            return
        }

        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]

        set numSel [llength $rowList]
        if { $numSel == 0 } {
            WriteInfoStr "No file selected for renaming" "Error"
            return
        } elseif { $numSel != 1 } {
            WriteInfoStr "Renaming only possible for one file" "Error"
            return
        }

        set row [lindex $rowList 0]
        set imgName [$tbl cellcget $row,$pkgCol(Name) -text]
        set imgName [poMisc QuoteTilde $imgName]
        set srcName [file join $dirName $imgName]

        lassign [poWin EntryBox $imgName $pkgInt(mouse,x) $pkgInt(mouse,y)] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName eq "" } {
            WriteInfoStr "No file name specified. No renaming." "Error"
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
        set catchVal [catch { file rename -force -- $srcName $newName } errorInfo]
        if { $catchVal } {
            WriteInfoStr [lindex [split "$errorInfo" "\n"] 0] "Error"
            return
        }
        poTablelistUtil SetCell $tbl $row $pkgCol(Name) [file tail $newName]
        WriteInfoStr "Renamed $imgName to [file tail $newName]" "Ok"
        focus $tbl
    }

    proc UpdateDirList { dirToShow } {
        variable pkgInt

        set treeId $pkgInt(treeId)
        poTree Rescan $treeId $dirToShow
    }

    proc UpdateDirListByDrop { w dirList } {
        foreach dir $dirList {
            if { [file isdirectory $dir] } {
                UpdateDirList $dir
                return
            }
        }
    }

    proc AskRenameDir { x y } {
        variable pkgInt

        set dirList [GetSelDirectories]
        set numSel [llength $dirList]
        if { $numSel == 1 } {
            set dirName [lindex $dirList 0]
        } else {
            WriteInfoStr "No directory or more than 1 selected." "Error"
            return
        }

        lassign [poWin EntryBox [file tail $dirName] $x $y] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }

        if { $retName eq "" } {
            WriteInfoStr "Empty directory name. Can not rename." "Error"
            return
        }

        set retName [poMisc QuoteTilde $retName]
        set newName [file join [file dirname $dirName] $retName]
        if { [file isdirectory $newName] } {
            WriteInfoStr "Directory $newName already exists. No overwrite possible." "Error"
            return
        }

        set catchVal [catch { file rename $dirName $newName } errorInfo]
        if { $catchVal } {
            WriteInfoStr [lindex [split "$errorInfo" "\n"] 0] "Error"
            return
        }
        poTree DeleteNode $pkgInt(treeId) $dirName
        UpdateDirList $newName
    }

    proc AskDelDir {} {
        variable pkgInt

        set dirList [GetSelDirectories]
        set numSel [llength $dirList]
        if { $numSel == 1 } {
            set dirName [lindex $dirList 0]
        } else {
            WriteInfoStr "No directory or more than 1 selected." "Error"
            return
        }

        set msgStr "Delete directory $dirName and all its contents ?"
        set retVal [tk_messageBox \
          -title "Confirmation" -message $msgStr \
          -type yesno -default yes -icon question]
        if { $retVal eq "no" } {
            focus $pkgInt(treeId)
            return
        }

        set catchVal [catch { file delete -force -- $dirName } errorInfo]
        if { $catchVal } {
            WriteInfoStr [lindex [split "$errorInfo" "\n"] 0] "Error"
            return
        }
        poTree DeleteNode $pkgInt(treeId) $dirName
        UpdateDirList [file dirname $dirName]
    }

    proc AskNewDir { x y } {
        variable pkgInt

        set dirList [GetSelDirectories]
        set numSel [llength $dirList]
        if { $numSel == 1 } {
            set dirName [lindex $dirList 0]
        } else {
            WriteInfoStr "No directory or more than 1 selected." "Error"
            return
        }

        lassign [poWin EntryBox "New directory" $x $y] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName eq "" } {
            WriteInfoStr "Empty directory name. Can not create." "Error"
            return
        }

        set retName [poMisc QuoteTilde $retName]
        set newName [file join $dirName $retName]
        if { [file isdirectory $newName] } {
            WriteInfoStr "Directory $newName exists. No creation possible." "Error"
            return
        }
        file mkdir "$newName"
        poTree DeleteNode $pkgInt(treeId) $dirName
        UpdateDirList $newName
    }

    proc AskCopyOrMoveDir { mode } {
        variable pkgInt
        variable sPo

        set dirList [GetSelDirectories]
        set numSel [llength $dirList]
        if { $numSel == 1 } {
            set dirName [lindex $dirList 0]
        } else {
            WriteInfoStr "No directory or more than 1 selected." "Error"
            return
        }

        set tmpDir [poTree GetDir -initialdir $sPo(lastDir) -showfiles 0 \
                                  -title "Select directory to copy to"]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            set sPo(lastDir) $tmpDir
            set newName [file join $tmpDir [file tail $dirName]]
            if { [file isdirectory $newName] } {
                WriteInfoStr "Directory $newName already exists. Use file copy instead."
                return
            }
            if { $mode eq "copy" } {
                # OPA TODO Check if directory with that name exists
                WriteInfoStr "Copying directory $dirName to $newName" "Watch"
                file copy -force -- $dirName $newName
                UpdateDirList [file join $dirName]
            } else {
                # OPA TODO Check if directory with that name exists
                WriteInfoStr "Moving directory $dirName to $newName" "Watch"
                file rename -force -- $dirName $newName
                poTree DeleteNode $pkgInt(treeId) $dirName
                UpdateDirList [file dirname $dirName]
            }
        } else {
            WriteInfoStr "Empty directory name. Can not create." "Error"
            return
        }
    }

    proc AskDelFile { tbl } {
        variable pkgCol
        variable pkgInt
        variable sPo

        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No files selected for deletion" "Error"
            return
        }

        set rowList [GetSelRows $tbl]
        set dirName [GetSelImgDir]

        set numSel [llength $rowList]
        if { $numSel == 0 } {
            WriteInfoStr "No files selected for deletion" "Error"
            return
        } elseif { $numSel == 1 } {
            set msgStr "Delete file [$tbl cellcget [lindex $rowList 0],$pkgCol(Name) -text] ?"
        } else {
            set msgStr "Delete selected $numSel files ?"
        }
        set retVal [tk_messageBox \
          -title "Confirmation" -message $msgStr \
          -type yesno -default yes -icon question]
        if { $retVal eq "no" } {
            focus $tbl
            return
        }

        set delError 0
        foreach row $rowList {
            set srcName [GetFullPath $tbl $row $pkgCol(Name) $dirName]
            WriteInfoStr "Deleting file $srcName" "Watch"
            update
            set catchVal [catch { file delete -force -- $srcName } errorInfo]
            if { $catchVal } {
                WriteInfoStr [lindex [split "$errorInfo" "\n"] 0] "Error"
                set delError 1
                break
            }
        }
        ShowFileList
        $tbl see $row

        if { $delError } {
            WriteInfoStr "Error trying to delete file $srcName" "Error"
        } elseif { $numSel == 1 } {
            WriteInfoStr "Deleted file $srcName" "Ok"
        } else {
            WriteInfoStr "Deleted $numSel files" "Ok"
        }
        focus $tbl
    }

    proc LoadImgs { selFunc args } {
        $selFunc $args
    }

    proc OpenFiles { tbl selFunc } {
        if { ! [RowsSelected $tbl] } {
            WriteInfoStr "No files selected for opening" "Error"
            return
        }

        set fileList [GetSelFiles $tbl]
        if { [llength $fileList] == 0 } {
            WriteInfoStr "No files selected for opening" "Error"
            return
        }
        LoadImgs $selFunc {*}$fileList
    }

    proc SlideShowFinished { cmdString code result op } {
        variable ns
        variable sPo
        variable pkgInt
        variable pkgCol

        #puts "SlideShowFinished <$cmdString> <$code> <$result> <$op>"
        if { $result } {
            set markedImgs [poSlideShow::GetMarkedImgs]
            set columnIndex $pkgCol(Name)
            $pkgInt(tableId) selection clear 0 end
            foreach markedImg $markedImgs {
                set rowIndex [$pkgInt(tableId) searchcolumn $columnIndex [file tail $markedImg] -exact]
                if { $rowIndex >= 0 } {
                    $pkgInt(tableId) selection set $rowIndex
                }
            }
        }
        trace remove execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
    }

    proc AppendToPpt { tbl } {
        global tcl_platform
        variable ns

        if { $tcl_platform(platform) eq "windows" } {
            if { ! [Ppt IsValidPresId [poPresMgr::GetCurPres]] } {
                poPresMgr::NewBlankPpt
            }
            poPresMgr::AppendSelImages ${ns}::WriteInfoStr
        } else {
            WriteInfoStr "Functionality available only on Windows." "Error"
        }
    }

    proc SlideShowFile { tbl { viewAllFiles false } } {
        variable ns
        variable pkgCol

        set dirName [GetSelImgDir]

        # If no rows are selected or we want to see all files, show all images in the slide show.
        # In the first case, set marking off for all images, otherwise use current markings.
        # If rows are selected, show these images in the slide show with marking on.

        set fileList [list]
        set markList [list]

        if { $viewAllFiles } {
            set rowList [list]
            for { set i 0 } { $i < [$tbl size] } { incr i } {
                lappend rowList $i
            }
        } else {
            set rowList [GetSelRows $tbl]
        }

        if { [llength $rowList] == 0 } {
            WriteInfoStr "No files selected for slide show" "Error"
            return
        }
        set selRowList [GetSelRows $tbl]
        foreach row $rowList {
            set fileName [GetFullPath $tbl $row $pkgCol(Name) $dirName]
            lappend fileList $fileName
            if { [lsearch -exact -integer $selRowList $row] >= 0 } {
                lappend markList $fileName
            }
        }
        trace add execution poSlideShow::CloseAppWindow leave ${ns}::SlideShowFinished
        poApps StartApp poSlideShow $fileList
        poSlideShow SetFileMarkList $markList
    }

    proc GetSelectedFiles {} {
        variable pkgCol
        variable pkgInt

        if { ! [info exists pkgInt(tableId)] || ! [winfo exists $pkgInt(tableId)] } {
            return [list]
        }
        set tableId $pkgInt(tableId)

        set dirName [GetSelImgDir]

        set rowList [GetSelRows $tableId]

        set fileList [list]
        foreach row $rowList {
            set fileName [GetFullPath $tableId $row $pkgCol(Name) $dirName]
            lappend fileList $fileName
        }
        return $fileList
    }

    proc SetCurImgDir { dirName } {
        variable pkgInt

        set pkgInt(curDir) $dirName
    }

    proc GetCurImgDir {} {
        variable pkgInt

        return $pkgInt(curDir)
    }

    proc GetSelImgDir {} {
        variable pkgInt

        return [lindex [poTree GetSelection $pkgInt(treeId)] 0]
    }

    proc GetThumbDir { dirName } {
        global tcl_platform
        variable sPo

        set name "poThumbs"
        if { $sPo(hiddenThumbDir) && $tcl_platform(platform) eq "unix" } {
            set name ".poThumbs"
        }
        return [file join $dirName $name]
    }

    proc BuildThumbFileName { thumbDir imgName } {
        return [format "%s%s" [file join $thumbDir $imgName] ".png"]
    }

    proc GetThumbFile { imgFileName } {
        set dirName [file dirname $imgFileName]
        set imgName [file tail $imgFileName]

        set thumbDir [GetThumbDir $dirName]
        return [file join $thumbDir $imgName]
    }

    proc CreateThumbDir { thumbDir } {
        global tcl_platform
        variable sPo

        if { ! [file isdirectory $thumbDir] } {
            if { [catch {file mkdir $thumbDir} ] } {
                WriteInfoStr "Unable to create thumbs directory $thumbDir. Check permissions." "Error"
                return 0
            }
            if { $sPo(hiddenThumbDir) && $tcl_platform(platform) eq "windows" } {
                file attributes $thumbDir -hidden 1
            }
        }
        return 1
    }

    proc CreatePlaceholderImage { width height type } {
        set phImg [image create photo -width $width -height $height]
        if { $type eq "blank" } {
            $phImg blank
        } else {
            set scanline [lrepeat $width "#A00000"]
            lset scanline [expr { $width/2 + 0 }] "#FFFF00"
            lset scanline [expr { $width/2 + 1 }] "#FFFF00"
            set data [list]
            lappend data $scanline
            for { set y 0 } { $y < $height } { incr y } {
                $phImg put $data -to 0 $y
            }
        }
        return $phImg
    }

    proc ShowFileList { { force true } } {
        variable pkgInt
        variable sPo
        variable pkgCol
        global tcl_platform

        if { ([GetCurImgDir] eq [GetSelImgDir]) && ($force == false) } {
            return
        }

        set tbl $pkgInt(tableId)
        set dirName [GetSelImgDir]
        if { $dirName eq "" } {
            return
        }
        WriteInfoStr "Getting file list ..." "Watch"
        $tbl delete 0 end
        $tbl resetsortinfo
        $sPo(tw) configure -cursor watch
        SetCurImgDir $dirName
        set imgFileList [GetFileList $dirName]

        wm title $sPo(tw) "poApps - [poApps GetAppDescription $sPo(appName)] ([llength $imgFileList] files match filter)"
        poWin InitStatusProgress $sPo(StatusWidget) [llength $imgFileList]

        if { [llength $imgFileList] == 0 } {
            $sPo(tw) configure -cursor arrow
            WriteInfoStr "Scanning finished. No files match filter in directory [file tail $dirName]." "Ok"
            return
        }

        set thumbDir [GetThumbDir $dirName]

        if { $sPo(saveThumb) } {
            if { ! [CreateThumbDir $thumbDir] } {
                set sPo(saveThumb) 0
            }
        }

        if { [info exists pkgInt(placeholderImg)] } {
            image delete $pkgInt(placeholderImg)
        }
        if { [info exists pkgInt(errorImg)] } {
            image delete $pkgInt(errorImg)
        }
        set pkgInt(placeholderImg) [CreatePlaceholderImage $sPo(thumbSize) $sPo(thumbSize) "blank"]
        set pkgInt(errorImg)       [CreatePlaceholderImage $sPo(thumbSize) $sPo(thumbSize) "error"]

        # Create a default list of row values.
        set defList [list]
        for { set c 0 } { $c < $pkgInt(numColumns) } { incr c } {
            if { [lindex $pkgInt(colSortList) $c] eq "real" ||  [lindex $pkgInt(colSortList) $c] eq "integer" } {
                lappend defList -1
            } else {
                lappend defList ""
            }
        }

        set row 0
        SetStopBrowsing false
        poWatch Reset _poImgScanSwatch
        poWatch Start _poImgScanSwatch
        foreach imgFile $imgFileList {
            if { [StopBrowsing] } {
                WriteInfoStr "Scanning cancelled." "Cancel"
                break
            }
            set rowList $defList

            lset rowList $pkgCol(Name) $imgFile
            set imgFile [poMisc QuoteTilde $imgFile]
            set pathName [file join $dirName $imgFile]
            if { $sPo(showFileInfo) } {
                lset rowList $pkgCol(Pages) [poImgPages GetNumPages $pathName]
                set foundImg false
                if { [poType IsPdf $pathName] } {
                    lassign [poImgPdf GetPageSize $pathName] w h
                    set dpi [poImgPdf GetPdfDpiOpt]
                    lset rowList $pkgCol(Type)   "pdf"
                    lset rowList $pkgCol(Width)  $w
                    lset rowList $pkgCol(Height) $h
                    lset rowList $pkgCol(X-DPI)  $dpi
                    lset rowList $pkgCol(Y-DPI)  $dpi
                    set foundImg true
                }
                if { ! $foundImg && [poImgMisc HaveImageMetadata] } {
                    set metaDict [image metadata -file $pathName]
                    if { [dict exists $metaDict "format"] } {
                        set foundImg true
                        lset rowList $pkgCol(Type)   [dict get $metaDict format]
                        lset rowList $pkgCol(Width)  [dict get $metaDict width]
                        lset rowList $pkgCol(Height) [dict get $metaDict height]
                        if { [dict exists $metaDict DPI] } {
                            set dpi    [dict get $metaDict DPI]
                            set aspect [dict get $metaDict aspect]
                            lset rowList $pkgCol(X-DPI) [expr {int($dpi)}]
                            lset rowList $pkgCol(Y-DPI) [expr {int($dpi / $aspect)}]
                        }
                    }
                }
                if { ! $foundImg } {
                    set retVal [catch {poType GetFileType $pathName} typeDict]
                    if { $retVal == 0 } {
                        set fmt "Unknown"
                        if { [dict exists $typeDict fmt] } {
                            set fmt [dict get $typeDict fmt]
                            if { $fmt eq "graphic" && [dict exists $typeDict subfmt] } {
                                set fmt [dict get $typeDict subfmt]
                                lset rowList $pkgCol(Width)  [dict get $typeDict width]
                                lset rowList $pkgCol(Height) [dict get $typeDict height]
                                lset rowList $pkgCol(X-DPI)  [dict get $typeDict xdpi]
                                lset rowList $pkgCol(Y-DPI)  [dict get $typeDict ydpi]
                            }
                        } elseif { [dict exists $typeDict style] } {
                            set fmt [dict get $typeDict style]
                        }
                        lset rowList $pkgCol(Type) $fmt
                    }
                }
                set date [clock format [file mtime $pathName] \
                               -format "%Y-%m-%d %H:%M"]
                set size [file size $pathName]
                lset rowList $pkgCol(Size) $size
                lset rowList $pkgCol(Date) $date
            }
            if { [winfo exists $tbl] } {
                if { $row > [$tbl size] } {
                    break
                }
                $tbl insert end $rowList
                if { $sPo(showThumb) } {
                   $tbl cellconfigure $row,$pkgCol(Img) -image $pkgInt(placeholderImg)
                }
            }

            incr row
            if { $row % 25 == 0 || $row == [llength $imgFileList] } {
                WriteInfoStr "Scanned $row files out of [llength $imgFileList] ..." "Watch"
                poWin UpdateStatusProgress $sPo(StatusWidget) $row
            }
        }

        if { [poApps GetVerbose] } {
            set n [llength $imgFileList]
            set t [poWatch Lookup _poImgScanSwatch]
            puts [format "Scanned %d files: %.2f sec (%.1f msec/img)" \
                  $n $t [expr 1000.0*$t/$n]]
        }
        if { ! [StopBrowsing] } {
            WriteInfoStr "Scanning finished." "Ok"
        } else {
            SetStopBrowsing false
        }
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        if { [winfo exists $sPo(tw)] } {
            $sPo(tw) configure -cursor arrow
        }

        if { $sPo(showThumb) && [winfo exists $tbl] } {
            poWin InitStatusProgress $sPo(StatusWidget) [$tbl size]
            WriteInfoStr "Loading thumbnail images ..." "Watch"
            poWatch Reset _poImgBrowseSwatch
            poWatch Start _poImgBrowseSwatch
            LoadThumbnails $tbl
            poWin UpdateStatusProgress $sPo(StatusWidget) 0
        }
    }

    proc CreateTree { par selDir } {
        variable ns

        set treeId [poTree CreateDirTree $par $selDir "Directory tree"]
        bind $treeId <<TreeviewSelect>>   "+ ${ns}::ShowFileList false"
        bind $treeId <<RightButtonPress>> "${ns}::DirectoryContextMenu %X %Y"
        return $treeId
    }

    proc GetSelDirectories {} {
        variable pkgInt

        set dirList [poTree GetSelection $pkgInt(treeId)]
        return $dirList
    }

    proc ShowDirInExplorer {} {
        set dirList [GetSelDirectories]
        foreach dir $dirList {
            poExtProg StartFileBrowser "$dir"
        }
    }

    proc SlideShowDir {} {
        set dirList [GetSelDirectories]
        poApps StartApp poSlideShow $dirList
    }

    proc InfoDir {} {
        variable sPo
        variable pkgInt

        $sPo(tw) configure -cursor watch
        update

        set dirList [GetSelDirectories]
        set numSelDir [llength $dirList]

        set w .poImgBrowse_InfoDirWin
        catch { destroy $w }

        toplevel $w
        wm title $w "Directory Information"
        wm resizable $w true true

        ttk::frame $w.fr0 -borderwidth 1
        grid  $w.fr0 -row 0 -column 0 -sticky nwse
        set textId [poWin CreateScrolledText $w.fr0 true "" -wrap word \
                             -height [poMisc Max 3 [poMisc Min 10 $numSelDir]]]

        foreach selDir $dirList {
            WriteInfoStr "Scanning directory $selDir ..." "Watch"
            update
            set name [file tail $selDir]
            set dirInfo [poMisc CountDirsAndFiles $selDir]
            set msgStr "Directory $name: [lindex $dirInfo 0] subdirs, [lindex $dirInfo 1] files\n"
            $textId insert end $msgStr
        }
        $textId configure -state disabled

        # Create OK button
        ttk::frame $w.fr1
        grid  $w.fr1 -row 1 -column 0 -sticky nwse
        ttk::button $w.fr1.b -text "OK" -command "destroy $w" -default active
        bind $w.fr1.b <KeyPress-Return> "destroy $w"
        pack $w.fr1.b -side left -fill x -padx 2 -pady 2 -expand 1

        grid columnconfigure $w 0 -weight 1
        grid rowconfigure    $w 0 -weight 1

        bind $w <Escape> "destroy $w"
        bind $w <Return> "destroy $w"
        $sPo(tw) configure -cursor arrow
        focus $w
    }

    proc DirectoryContextMenu { x y } {
        variable ns

        set w .poImgBrowse:directoryContextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        set selList [GetSelDirectories]
        set numSel [llength $selList]
        if { $numSel == 0 } {
            set menuTitle "Nothing selected"
        } else {
            set menuTitle "$numSel selected"
        }
        $w add command -label "$menuTitle" -state disabled -background "#303030"
        if { $numSel == 0 } {
            tk_popup $w $x $y
            return
        }

        $w add command -label "Open directory" -command "${ns}::ShowDirInExplorer"
        $w add command -label "Slide show"     -command "${ns}::SlideShowDir"
        $w add separator
        $w add command -label "Info" -command "${ns}::InfoDir"
        if { $numSel == 1 } {
            # All of these commands are currently supported only for 1 directory.
            $w add command -label "Update"      -command "${ns}::UpdateDirList $selList"
            $w add separator
            $w add command -label "New ..."     -command "${ns}::AskNewDir $x $y"
            $w add separator
            $w add command -label "Rename ..."  -command "${ns}::AskRenameDir $x $y"
            $w add separator
            $w add command -label "Copy to ..." -command "${ns}::AskCopyOrMoveDir copy"
            $w add command -label "Move to ..." -command "${ns}::AskCopyOrMoveDir move"
            $w add separator
            $w add command -label "Delete ..."  -command "${ns}::AskDelDir"
        }
        tk_popup $w $x $y
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Directory\]\n"
        append msg "\n"
        append msg "Start the image browser using specified directory as root.\n"
        append msg "If no directory is specified, the current directory is used.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "None.\n"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
    }

    proc UpdateCombo { cb fmtList showInd } {
        variable sPo
        $cb configure -values $fmtList
        $cb current $showInd
    }

    proc ComboCB { args } {
        variable sPo
        variable pkgInt

        set sPo(suffixFilter) [$pkgInt(combo) get]
        ShowFileList
    }

    proc StartAppImgview { fileList } {
        poApps StartApp poImgview $fileList
    }

    proc SetVerbose { verboseFlag } {
        variable sPo

        set sPo(optVerbose) $verboseFlag
    }

    proc AddRecentDirs { menuId } {
        variable pkgInt

        poMenu DeleteMenuEntries $menuId 0
        poMenu AddRecentDirList $menuId ::poTree::Rescan2 $pkgInt(treeId)
    }

    proc UpdateColumnHeaders { tableId } {
        variable sPo
        variable pkgCol

        $tableId columnconfigure $pkgCol(Img)    -hide [expr !$sPo(showThumb)]
        $tableId columnconfigure $pkgCol(Type)   -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Size)   -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Date)   -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Width)  -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Height) -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(X-DPI)  -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Y-DPI)  -hide [expr !$sPo(showFileInfo)]
        $tableId columnconfigure $pkgCol(Pages)  -hide [expr !$sPo(showFileInfo)]
    }

    proc CopyImg { tableId { fmtName "CF_DIB" }  } {
        variable sPo

        if { [RowsSelected $tableId] } {
            set fileList [GetSelFiles $tableId]
            set fileName [lindex $fileList 0]
            set retVal [catch { poImgMisc LoadImg $fileName } imgDict]
            if { $retVal == 0 } {
                set phImg [dict get $imgDict phImg]
                set retVal [catch { poWinCapture Img2Clipboard $phImg $fmtName } errMsg]
                if { $retVal == 0 } {
                    WriteInfoStr "Copied image to clipboard in format $fmtName" "OK"
                } else {
                    WriteInfoStr "$errMsg" "Error"
                }
            } else {
                WriteInfoStr "$imgDict" "Error"
            }
        } else {
            WriteInfoStr "No images selected" "Error"
        }
    }

    proc CopyPathList { tableId } {
        if { [RowsSelected $tableId] } {
            set fileList [GetSelFiles $tableId]
            set retVal [catch { poWinCapture WritePathList $fileList } errMsg]
            if { $retVal == 0 } {
                WriteInfoStr "Copied path list to clipboard" "OK"
            } else {
                WriteInfoStr "$errMsg" "Error"
            }
        } else {
            WriteInfoStr "No images selected" "Error"
        }
    }

    proc AddClipboardFormats { menuId tableId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 0
        if { [RowsSelected $tableId] } {
            foreach fmtName [poWinCapture GetSupportedFormatNames "copy"] {
                poMenu AddCommand $menuId $fmtName "" [list ${ns}::CopyImg $tableId $fmtName]
            }
            poMenu AddCommand $menuId "Path List" "" [list ${ns}::CopyPathList $tableId]
        }
    }

    proc ShowFileByKey { tableId key } {
        variable sPo
        variable pkgCol

        set key [string tolower $key]
        if { ! [info exists sPo(KeyPressTime)] } {
            # First call of this procedure.
            set sPo(KeyPressTime) [clock milliseconds]
            set sPo(SearchString) $key
        } else {
            set curTime [clock milliseconds]
            if { $curTime - $sPo(KeyPressTime) < $sPo(KeyRepeatTime) && \
                 $key ne [string index $sPo(SearchString) end] } {
                append sPo(SearchString) $key
            } else {
                set sPo(SearchString) $key
            }
            set sPo(KeyPressTime) $curTime
        }

        set numRows [$tableId size]
        set indList [$tableId curselection]
        if { [llength $indList] == 0 } {
            set row 0
        } else {
            set row [expr { ( [lindex $indList 0] + 1 ) % $numRows }]
        }
        for { set i 0 } { $i < $numRows } { incr i } {
            set fileName [$tableId cellcget $row,$pkgCol(Name) -text]
            if { ( [string first $sPo(SearchString) [string tolower $fileName 0]] == 0 ) || \
                 ( $sPo(CurFileName) ne "" && $key eq "return" && $fileName eq $sPo(CurFileName) ) } {
                $tableId selection clear 0 end
                $tableId selection set $row $row
                event generate $tableId <<TablelistSelect>>
                $tableId activate $row
                $tableId see $row
                break
            }
            set row [expr {( $row + 1 ) % $numRows }]
        }
    }

    proc OpenDir { dirName { selFunc ::poImgBrowse::StartAppImgview } } {
        variable ns
        variable sPo
        variable pkgInt
        variable pkgCol

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        focus $sPo(tw)
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both
        set fr $sPo(tw).fr

        ttk::frame $fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $fr.workfr
        ttk::frame $fr.statfr -borderwidth 1
        grid $fr.toolfr -row 0 -column 0 -sticky news
        grid $fr.workfr -row 1 -column 0 -sticky news
        grid $fr.statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $fr 1 -weight 1
        grid columnconfigure $fr 0 -weight 1

        ttk::frame $fr.workfr.fr
        pack $fr.workfr.fr -expand 1 -fill both

        set sPo(paneHori) $fr.workfr.fr.pane
        ttk::panedwindow $sPo(paneHori) -orient horizontal
        pack $sPo(paneHori) -side top -expand 1 -fill both

        set lf $sPo(paneHori).lfr
        set rf $sPo(paneHori).rfr
        ttk::frame $lf -relief sunken -borderwidth 1
        ttk::frame $rf -relief sunken -borderwidth 1
        pack $lf -expand 1 -fill both -side left
        pack $rf -expand 1 -fill both -side left
        $sPo(paneHori) add $lf
        $sPo(paneHori) add $rf

        set sPo(paneVert) $lf.pane
        ttk::panedwindow $sPo(paneVert) -orient vertical
        pack $sPo(paneVert) -side top -expand 1 -fill both

        ttk::frame $sPo(paneVert).dirfr -relief sunken -borderwidth 1
        ttk::frame $sPo(paneVert).icofr -relief sunken -borderwidth 1
        ttk::frame $rf.tblfr -relief raised
        grid $sPo(paneVert).dirfr -row 0 -column 0 -sticky news
        grid $sPo(paneVert).icofr -row 1 -column 0 -sticky news
        grid $rf.tblfr -row 0 -column 0 -sticky news
        $sPo(paneVert) add $sPo(paneVert).dirfr
        $sPo(paneVert) add $sPo(paneVert).icofr

        grid rowconfigure    $lf 0 -weight 1
        grid columnconfigure $lf 0 -weight 1
        grid rowconfigure    $rf 0 -weight 1
        grid columnconfigure $rf 0 -weight 1

        ttk::frame $rf.tblfr.tabfr
        pack $rf.tblfr.tabfr -fill both -expand 1

        set tableId [poWin CreateScrolledTablelist $rf.tblfr.tabfr true "" \
                    -width 100 -height 10 \
                    -exportselection false \
                    -setfocus 1 \
                    -columntitles $pkgInt(colNameList) \
                    -stripebackground [poAppearance GetStripeColor] \
                    -selectmode extended \
                    -labelcommand ::tablelist::sortByColumn \
                    -showseparators yes]

        $tableId columnconfigure 0 -showlinenumbers true
        # Adjust the image column to fit the thumb size.
        lset pkgInt(colWidthList) 1 [expr -1 * $sPo(thumbSize)]
        for { set colNum 0 } { $colNum < $pkgInt(numColumns) } { incr colNum } {
            $tableId columnconfigure $colNum -sortmode [lindex $pkgInt(colSortList) $colNum]
            $tableId columnconfigure $colNum -align    [lindex $pkgInt(colAlignList) $colNum]
            $tableId columnconfigure $colNum -width    [lindex $pkgInt(colWidthList) $colNum]
        }
        bind $tableId <<TablelistSelect>> "${ns}::PrintSelInfo $tableId"
        set bodyTag [$tableId bodytag]
        bind $bodyTag <Motion> "${ns}::StoreCurMousePos $tableId %W %x %y %X %Y"
        bind $bodyTag <<RightButtonPress>> \
                   "${ns}::OpenContextMenu $tableId %W %X %Y $selFunc"
        bind $bodyTag <Double-1> "${ns}::OpenFiles $tableId $selFunc"
        bind $bodyTag <Control-a> "$tableId selection set 0 end"
        bind $bodyTag <KeyRelease-Down>  "${ns}::ShowSelection $tableId Down"
        bind $bodyTag <KeyRelease-Up>    "${ns}::ShowSelection $tableId Up"
        bind $bodyTag <KeyRelease-Prior> "${ns}::ShowSelection $tableId Down"
        bind $bodyTag <KeyRelease-Next>  "${ns}::ShowSelection $tableId Up"
        bind $bodyTag <KeyRelease-Home>  "${ns}::ShowSelection $tableId Home"
        bind $bodyTag <KeyRelease-End>   "${ns}::ShowSelection $tableId End"
        bind $bodyTag <Any-KeyPress>     "${ns}::ShowFileByKey $tableId %K"

        set pkgInt(tableId) $tableId

        UpdateColumnHeaders $tableId

        # Create a Drag-And-Drop binding for the tablelist.
        poDragAndDrop AddCanvasBinding $tableId ${ns}::UpdateDirListByDrop

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
        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Open selected ..." "Ctrl+O" "${ns}::OpenFiles $tableId $selFunc"

        $fileMenu add separator
        $fileMenu add cascade -label "Rebrowse"  -menu $fileMenu.rebrowse
        set sPo(rebrowseMenu) $fileMenu.rebrowse
        menu $sPo(rebrowseMenu) -tearoff 0 -postcommand "${ns}::AddRecentDirs $sPo(rebrowseMenu)"

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }

        bind $sPo(tw) <Control-o> "${ns}::OpenFiles $tableId $selFunc"

        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Edit
        menu $editMenu -tearoff 0

        if { $::tcl_platform(platform) eq "windows" } {
            set copyMenu $editMenu.copy
            $editMenu add cascade -label "Copy as" -menu $copyMenu
            menu $copyMenu -tearoff 0 -postcommand "${ns}::AddClipboardFormats $copyMenu $tableId"

            $editMenu add separator
        }

        poMenu AddCommand $editMenu "Copy file to ..." ""    "${ns}::AskCopyOrMoveTo $tableId copy"
        poMenu AddCommand $editMenu "Move file to ..." ""    "${ns}::AskCopyOrMoveTo $tableId move"

        poMenu AddCommand $editMenu "Delete file"      "Del" "${ns}::AskDelFile $tableId"
        poMenu AddCommand $editMenu "Rename file"      "F2"  "${ns}::AskRenameFile $tableId"

        bind $sPo(tw) <Delete>    "${ns}::AskDelFile $tableId"
        bind $sPo(tw) <F2>        "${ns}::AskRenameFile $tableId"

        $editMenu add separator
        set thumbMenu $editMenu.thumb
        $editMenu add cascade -label "Thumbnails" -menu $thumbMenu

        menu $thumbMenu -tearoff 0
        poMenu AddCommand $thumbMenu "Update all" "" "${ns}::GenAllThumbs $tableId 0"
        # OPA TODO With subdirs not yet implemented
        # poMenu AddCommand $thumbMenu "Update all with subdirs" \
        #                       "" "${ns}::GenAllThumbs $tableId 1"
        poMenu AddCommand $thumbMenu "Delete all" "" "${ns}::DelAllThumbs $tableId"

        # Menu View
        menu $viewMenu -tearoff 0
        poMenu AddCommand $viewMenu "File info"           "Ctrl+I" "${ns}::ShowImgInfo $tableId"
        poMenu AddCommand $viewMenu "Slide show (all)"    "Ctrl+E" "${ns}::SlideShowFile $tableId true"
        poMenu AddCommand $viewMenu "Slide show (marked)" "Ctrl+M" "${ns}::SlideShowFile $tableId false"
        bind $sPo(tw) <Control-i> "${ns}::ShowImgInfo   $tableId"
        bind $sPo(tw) <Control-e> "${ns}::SlideShowFile $tableId true"
        bind $sPo(tw) <Control-m> "${ns}::SlideShowFile $tableId false"

        # Menu Settings
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

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
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgBrowse] "" "poApps StartApp poImgBrowse" -state disabled
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" "poApps StartApp poBitmap"
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

        # Make the menus available
        $sPo(tw) configure -menu $hMenu

        # Add new toolbar group and associated buttons.
        set toolfr $fr.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::open] \
                  "${ns}::OpenFiles $tableId $selFunc" [Str OpenFile]
        poToolbar AddButton $toolfr [::poBmpData::delete] \
                  "${ns}::AskDelFile $tableId" [Str DelFile]
        poToolbar AddButton $toolfr [::poBmpData::rename] \
                  "${ns}::AskRenameFile $tableId" [Str RenameFile]

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::infofile] \
                  "${ns}::ShowImgInfo $tableId" [Str FileInfo]

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::slideShowAll] \
                  "${ns}::SlideShowFile $tableId true" "Slide show of all images (Ctrl+E)"
        poToolbar AddButton $toolfr [::poBmpData::slideShowMarked] \
                  "${ns}::SlideShowFile $tableId false" "Slide show of marked images (Ctrl+M)"

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::sheetIn] \
                  "${ns}::AppendToPpt $tableId" "Append to PowerPoint"

        # Add new toolbar group and associated widgets.
        poToolbar AddGroup $toolfr

        poToolbar AddLabel $toolfr "Filter:" ""
        poToolbar AddEntry $toolfr ${ns}::sPo(prefixFilter) "File match" -width 10

        set pkgInt(combo) [poToolbar AddCombobox $toolfr ${ns}::sPo(formatFilter) "Image format" -state readonly]
        set fmtInd 0
        set curInd 2
        set fmtList [list $pkgInt(allFiles) $pkgInt(allImgs)]
        if { $pkgInt(allImgs) eq $sPo(suffixFilter) } {
            set fmtInd 1
        }
        foreach fmt [poImgType GetFmtList] {
            lappend fmtList $fmt
            if { $fmt eq $sPo(suffixFilter) } {
                set fmtInd $curInd
            }
            incr curInd
        }
        UpdateCombo $pkgInt(combo) $fmtList $fmtInd
        $pkgInt(combo) current $fmtInd
        bind $pkgInt(combo) <<ComboboxSelected>> "${ns}::ComboCB"

        poToolbar AddButton $toolfr [::poBmpData::update] \
                  "${ns}::ShowFileList" [Str UpdateList]
        poToolbar AddButton $toolfr [::poBmpData::clear] \
                  "${ns}::ClearImgCache $tableId ; ${ns}::UpdateVisImgs $tableId" \
                  [Str ClearImgCache]
        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::halt "red"] \
                  ${ns}::SetStopBrowsing [Str StopImgLoad]
        bind $sPo(tw) <Key-F5> "${ns}::ShowFileList"
        bind $sPo(tw) <KeyPress-Escape> ${ns}::SetStopBrowsing

        set pkgInt(previewWidget) [poWinPreview Create $sPo(paneVert).icofr] 

        if { $dirName ne "" } {
            set dirName [file normalize $dirName]
            if { ! [file isdirectory $dirName] } {
                WriteInfoStr "Directory $dirName does not exist." "Error"
                if { [file isdirectory $sPo(lastDir)] } {
                    set dirName $sPo(lastDir)
                } else {
                    set dirName [pwd]
                }
            }
        }
        set treeId [CreateTree $sPo(paneVert).dirfr $dirName]
        set pkgInt(treeId) $treeId
        SetCurImgDir ""
        if { $dirName ne "" } {
            set sPo(lastDir) $dirName
        }

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget) [poWin CreateStatusWidget $fr.statfr true]

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        update
        if { [winfo exists $sPo(paneVert)] } {
            $sPo(paneVert) pane $sPo(paneVert).dirfr -weight 1
            $sPo(paneVert) pane $sPo(paneVert).icofr -weight 0
            $sPo(paneVert) sashpos 0 $sPo(sashY)
            $sPo(paneHori) sashpos 0 $sPo(sashX)

            poWin Raise $sPo(tw)
        }
    }

    proc ShowMainWin { { dirName "" } { selFunc ::poImgBrowse::StartAppImgview } } {
        OpenDir $dirName $selFunc
    }

    proc PrintInfo { tbl row } {
        variable pkgInt
        variable pkgCol

        if { ! [winfo exists $tbl] } {
            return
        }
        if { $row >= [$tbl size] } {
            return
        }
        set dirName [GetSelImgDir]
        set fileName [GetFullPath $tbl $row $pkgCol(Name) $dirName]

        poWinPreview Update $pkgInt(previewWidget) $fileName

        catch { unset pkgInt(afterId) }
    }

    proc PrintSelInfo { tbl } {
        variable sPo
        variable pkgCol

        set rowList [$tbl curselection]
        if { [llength $rowList] > 0 } {
            set row [lindex $rowList 0]
            PrintInfo $tbl $row
            set sPo(CurFileName) [$tbl cellcget $row,$pkgCol(Name) -text]
        }
    }

    proc GetTopRow { tbl } {
        set tblBody [$tbl bodypath]
        foreach { ::tablelist::W ::tablelist::x ::tablelist::y } \
            [::tablelist::convEventFields $tblBody 0 0] {}
        set row [$tbl index @$::tablelist::x,$::tablelist::y]
        return $row
    }

    proc GetBottomRow { tbl } {
        set tblBody [$tbl bodypath]
        foreach { ::tablelist::W ::tablelist::x ::tablelist::y } \
            [::tablelist::convEventFields $tblBody 0 [winfo height $tblBody]] {}
        set row [$tbl index @$::tablelist::x,$::tablelist::y]
        return $row
    }

    proc GetVisibleRows { tbl } {
        set rowVis1 [expr {[GetTopRow $tbl]}]
        set rowVis2 [expr {[GetBottomRow $tbl]}]
        set rowVis1 [poMisc Max 0 $rowVis1]
        set rowVis2 [poMisc Max 0 [poMisc Min $rowVis2 [expr {[$tbl size] -1}]]]
        return [list $rowVis1 $rowVis2]
    }

    proc StoreCurMousePos { tbl tblBody x y X Y } {
        variable ns
        variable pkgInt

        set pkgInt(mouse,x) $X
        set pkgInt(mouse,y) $Y

        if { [$tbl size] == 0 } {
            return
        }

        if { [info exists pkgInt(afterId)] } {
            after cancel $pkgInt(afterId)
        }

        foreach { ::tablelist::W ::tablelist::x ::tablelist::y } \
            [::tablelist::convEventFields $tblBody $x $y] {}

        set row [$tbl index @$::tablelist::x,$::tablelist::y]
        if { $row < 0 } {
            return
        }

        set pkgInt(afterId) [after 500 ${ns}::PrintInfo $tbl $row]
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo
        variable pkgInt

        # Init all variables stored in the cfg file with default values.
        SetWindowPos mainWin  90  30 800 480
        SetWindowPos settWin 100 100   0   0

        SetMainWindowSash    220 260

        SetThumbOptions      60 0 1
        SetUpdateInterval    5
        SetViewOptions       1 1
        SetFilterOptions     "*" $pkgInt(allImgs)
        SetLastUsedDir       [pwd]

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
        variable pkgInt

        set cfgFile [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetWindowPos [info args SetWindowPos]"

            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"
            puts $fp "catch {SetWindowPos [GetWindowPos settWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]
            eval SetWindowPos [GetWindowPos settWin]

            eval SetMainWindowSash [GetMainWindowSash]

            PrintCmd $fp "MainWindowSash"

            PrintCmd $fp "LastUsedDir"
            PrintCmd $fp "ThumbOptions"
            PrintCmd $fp "UpdateInterval"
            PrintCmd $fp "ViewOptions"
            PrintCmd $fp "FilterOptions"

            close $fp
        }
    }

    proc ParseCommandLine { argList } {
        variable ns
        variable sPo
        variable pkgInt

        set curArg 0
        set dirList [list]
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
            } else {
                lappend dirList $curParam
            }
            incr curArg
        }

        if { [llength $dirList] == 0 } {
            lappend dirList [pwd]
        }

        # Loop through all arguments. The first valid directory name will be opened.
        foreach fileOrDirName $dirList {
            if { [file isdirectory $fileOrDirName] } {
                set curDir [poMisc FileSlashName $fileOrDirName]
                poTree Rescan $pkgInt(treeId) $curDir
                poAppearance AddToRecentDirList $curDir
                break
            }
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poImgBrowse Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
