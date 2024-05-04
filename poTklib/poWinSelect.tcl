# Module:         poWinSelect
# Copyright:      Paul Obermeier 2009-2023 / paul@poSoft.de
# First Version:  2009 / 12 / 15
#
# Distributed under BSD license.
#
# Module with functions for creating megawidgets to select directories or files.
# The megawidget consists of a combobox used for selection and display of the
# directory or file name. Next to the combobox is a label displaying a green OK
# or red Bad bitmap indicating a valid resp. invalid directory or file name.
# If the directory or file name is valid (i.e. exists) the virtual event
# <<NameValid>> is generated. The last widget is a button to open the standard Tk
# directory or file chooser.

namespace eval poWinSelect {
    variable ns [namespace current]

    namespace ensemble create

    namespace export SetFileTypes
    namespace export GetValue SetValue
    namespace export GetSelectedValue
    namespace export Enable
    namespace export CreateDirSelect CreateFileSelect

    # Internal function storing the current value of a combobox
    # before opening the selection list.
    proc SaveComboEntry { comboId } {
        variable sett

        set sett($comboId,saveEntry) [$comboId get]
    }

    # Internal function adjusting the text of the combobox.
    # Note: The -width option of the combobox always returns the initial
    # width of the combobox. (TODO)
    proc AdjustText { comboId } {
        variable sett

        $comboId selection clear
        $comboId icursor end
        $comboId configure -justify right
        if { [$comboId cget -width] < [string length [$comboId get]] } {
            $comboId configure -justify right
            $comboId xview [$comboId index end]
        } else {
            $comboId configure -justify left
            $comboId xview 0
        }
    }

    # Internal function called by the ComboboxSelected virtual event.
    # It appends the new entry from the combobox selection list (which is a
    # relative path name) to the (absolute) path name contained in the
    # combobox entry widget.
    proc UpdateNewEntry { comboId { appendSlash true } } {
        variable sett

        set oldPath ""
        if { [info exists sett($comboId,saveEntry)] } {
            set oldPath $sett($comboId,saveEntry)
        }
        if { $oldPath ne "" && [string index $oldPath end] ne "/" } {
            set oldPath [file dirname $oldPath]
            set oldPath [format "%s/" [string trimright $oldPath "/"]]
        }
        set curPath [poMisc QuoteTilde [$comboId get]]
        if { [file pathtype $curPath] eq "absolute" } {
            set fullPath $curPath
        } else {
            set fullPath [format "%s%s" $oldPath $curPath]
        }
        if { $appendSlash && [file isdirectory $fullPath] } {
            set fullPath [format "%s/" [string trimright $fullPath "/"]]
        }
        $comboId set $fullPath
        poToolhelp AddBinding $comboId $fullPath
        AdjustText $comboId
        if { [file isfile $fullPath] } {
            event generate $comboId <<FileSelected>>
        } elseif { [file isdirectory $fullPath] } {
            event generate $comboId <<DirSelected>>
        }
    }

    # Internal function calling the standard Tk directory chooser.
    # It generates a <<NameValid>> virtual event, so that the caller
    # of the megawidget will be notified about the new entry.
    proc SelectDir { comboId labelId useTkChooser } {
        variable sett

        set initDir [string trimright [$comboId get] "/"]
        if { ! [file isdirectory $initDir] } {
            set initDir [pwd]
        }
        set tmpDir [poWin ChooseDir $sett($comboId,msg) $initDir $useTkChooser]
        if { $tmpDir ne "" && [file isdirectory $tmpDir] } {
            $comboId set $tmpDir
            UpdateNewEntry $comboId
            CheckDirEntry $comboId $labelId
            focus $comboId
            event generate $comboId <<NameValid>>
        }
    }

    # Internal function calling the standard Tk file chooser.
    # It generates a <<NameValid>> virtual event, so that the caller
    # of the megawidget will be notified about the new entry.
    proc SelectFile { comboId labelId mode useTkChooser } {
        variable ns
        variable sett

        set initFile [string trimright [$comboId get] "/"]
        if { [file isdirectory $initFile] } {
            set initDir $initFile
        } else {
            set initDir [file dirname $initFile]
        }
        if { ! [file isfile $initFile] } {
            set initFile ""
        } else {
            set initFile [file tail $initFile]
        }
        if { $useTkChooser } {
            if { $mode eq "open" } {
                set fileName [tk_getOpenFile -filetypes $sett($comboId,fileTypes) \
                                             -initialdir $initDir \
                                             -initialfile $initFile \
                                             -parent $comboId \
                                             -title $sett($comboId,msg)]
            } else {
                if { ! [info exists sett($comboId,LastFileTypes)] } {
                    set sett($comboId,LastFileTypes) [lindex [lindex $sett($comboId,fileTypes) 0] 0]
                }
                set fileExt [file extension $initFile]
                set typeExt [poMisc GetExtensionByType $sett($comboId,fileTypes) $sett($comboId,LastFileTypes)]
                if { $typeExt ne $fileExt } {
                    set initFile [file rootname $initFile]
                }

                set fileName [tk_getSaveFile \
                             -filetypes $sett($comboId,fileTypes) \
                             -title $sett($comboId,msg) \
                             -parent $comboId \
                             -confirmoverwrite false \
                             -typevariable ${ns}::sett($comboId,LastFileTypes) \
                             -initialfile $initFile \
                             -initialdir $initDir]
                if { $fileName ne "" && ! [poMisc IsValidExtension $sett($comboId,fileTypes) [file extension $fileName]] } {
                    set ext [poMisc GetExtensionByType $sett($comboId,fileTypes) $sett($comboId,LastFileTypes)]
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
        } else {
            set fileName [poTree GetDir $initDir \
                                        -title $sett($comboId,msg)] \
                                        -showfiles 1]
        }
        if { $fileName ne "" } {
            $comboId set $fileName
            UpdateNewEntry $comboId false
            CheckFileEntry $comboId $labelId
            focus $comboId
            if { $mode eq "save" } {
                event generate $comboId <<FileChoosen>>
            }
            if { [file isfile $fileName] } {
                event generate $comboId <<NameValid>>
            }
        }
    }

    # Internal function checking if the current entry of the combobox
    # is an existing directory and setting the appropriate bitmap.
    proc CheckDirEntry { comboId labelId } {
        set curPath [$comboId get]
        if { ! [file isdirectory $curPath] } {
            $labelId configure -image [poWin GetWrongBitmap]
        } else {
            $labelId configure -image [poWin GetOkBitmap]
            poToolhelp AddBinding $comboId $curPath
            focus $comboId
            event generate $comboId <<NameValid>>
        }
    }

    # Internal function checking if the current entry of the combobox
    # is an existing file and setting the appropriate bitmap.
    proc CheckFileEntry { comboId labelId } {
        set curPath [$comboId get]
        if { ! [file isfile $curPath] } {
            $labelId configure -image [poWin GetWrongBitmap]
        } else {
            $labelId configure -image [poWin GetOkBitmap]
            poToolhelp AddBinding $comboId $curPath
            focus $comboId
            event generate $comboId <<NameValid>>
        }
    }

    # Internal function to convert directory names to Tcl normalized style.
    proc NormalizeName { fileOrDirName } {
        set fileOrDirName [file normalize [string trim $fileOrDirName "\{\}"]]
        if { [file isdirectory $fileOrDirName] } {
            set fileOrDirName [format "%s/" [string trimright $fileOrDirName "/"]]
        }
        return $fileOrDirName
    }

    # Internal function called by the Any-KeyRelease event.
    # It checks the combobox entry, if it is a valid directory and
    # fills up the combobox selection list with all possible directories.
    proc CheckDir { comboId labelId } {
        variable sett

        set curPath [$comboId get]
        if { [string first "\\" $curPath] >= 0 } {
            set curPath [NormalizeName $curPath]
            $comboId set $curPath
        }
        CheckDirEntry $comboId $labelId
        set lastSlash [string last "/" $curPath]
        set preFix  [string range $curPath 0 $lastSlash]
        set postFix [string range $curPath [expr $lastSlash +1] end]
        set tmpList [lindex [poMisc GetDirsAndFiles $preFix -showfiles false -dirpattern "${postFix}*"] 0]
        set dirList [list]
        foreach dir [lsort -dictionary $tmpList] {
            lappend dirList [file tail $dir]
        }
        $comboId configure -values $dirList
    }

    # Internal function called by the Any-KeyRelease event.
    # It checks the combobox entry, if it is a valid file name and
    # fills up the combobox selection list with all possible directories
    # and file names.
    proc CheckFile { comboId labelId } {
        variable sett

        CheckFileEntry $comboId $labelId
        set curPath [$comboId get]
        set lastSlash [string last "/" $curPath]
        set preFix  [string range $curPath 0 $lastSlash]
        set postFix [string range $curPath [expr $lastSlash +1] end]
        set contList [poMisc GetDirsAndFiles $preFix -filepattern "${postFix}*"]
        set tmpList  [lsort -dictionary [lindex $contList 0]]
        set dirList [list]
        foreach absDir $tmpList {
            set relDir [format "%s/" [string trimright [file tail $absDir] "/"]]
            lappend dirList $relDir
        }
        if { [llength $sett($comboId,fileTypes)] == 1 && [lindex [lindex $sett($comboId,fileTypes) 0] 1] eq "*" } {
            set fileList [lsort -dictionary [lindex $contList 1]]
        } else {
            set tmpList [lsort -dictionary [lindex $contList 1]]
            set fileList [list]
            foreach fileName $tmpList {
                set found false
                foreach fileType $sett($comboId,fileTypes) {
                    foreach fileExt [lindex $fileType 1] {
                        if { $fileExt eq "*" } {
                            continue
                        }
                        if { [string match -nocase "*$fileExt" $fileName] } {
                            lappend fileList $fileName 
                            set found true
                            break
                        }
                    }
                    if { $found } {
                        break
                    }
                }
            }
        }
        $comboId configure -values [concat $dirList $fileList]
    }

    # Set the list of file types used for the "Open file" dialogs.
    # Default list is: { {"All files" "*"} }
    proc SetFileTypes { comboId typeList } {
        variable sett

        set sett($comboId,fileTypes) $typeList
        CheckFile $comboId $sett($comboId,label)
    }

    # Return the current value of the combobox.
    # This function is typically used in a binding of the main program:
    # bind $comboId <<NameValid>> "poWinSelect GetValue $comboId"
    proc GetValue { comboId } {
        return [$comboId get]
    }

    # Return the current selected text of the combobox.
    proc GetSelectedValue { comboId } {
        if { [$comboId selection present] } {
            set startInd [$comboId index sel.first]
            set endInd   [$comboId index sel.last]
            return [string range [$comboId get] $startInd [expr {$endInd - 1 }]]
        } else {
            return ""
        }
    }

    # Set the current combobox value.
    proc SetValue { comboId fileOrDir } {
        variable sett

        set fileOrDir [NormalizeName $fileOrDir]
        $comboId set $fileOrDir
        if { [file isdirectory $fileOrDir] } {
            CheckDirEntry $comboId $sett($comboId,label)
        } else {
            CheckFileEntry $comboId $sett($comboId,label)
        }
        poToolhelp AddBinding $comboId $fileOrDir
    }

    proc Enable { comboId onOff } {
        set masterList [lrange [split $comboId "."] 0 end-1]
        set masterFr [join $masterList "."]
        if { $onOff } {
            set state normal
        } else {
            set state disabled
        }
        ${masterFr}.cb configure -state $state
        if { [winfo exists ${masterFr}.b] } {
            ${masterFr}.b configure -state $state
        }
    }

    proc UpdateFileSelectByDrop { comboId fileList } {
        variable sett

        foreach f $fileList {
            SetValue $comboId $f
            UpdateNewEntry $comboId false 
            CheckFile $comboId $sett($comboId,label)
        }
    }

    proc UpdateDirSelectByDrop { comboId dirList } {
        variable sett

        foreach f $dirList {
            if { [file isfile $f] } {
                set f [file dirname $f]
            }
            SetValue $comboId $f
            UpdateNewEntry $comboId false 
            CheckDir $comboId $sett($comboId,label)
        }
    }
    
    # Create a megawidget for directory selection.
    # "masterFr" is the frame, where the components of the megawidgets are placed.
    # "initDir" is the initial name of the directory to be displayed in the combobox.
    # "textOrImg" is an optional string or photo displayed on the select button.
    # If an empty string is supplied, the select button is not drawn.
    # "msg" is an optional string displayed in the Tk directory chooser.
    proc CreateDirSelect { masterFr initDir \
                           { textOrImg "Select ..." } \
                           { msg "Select directory" } } {
        variable ns
        variable sett

        set comboId ${masterFr}.cb
        set sett($comboId,msg) $msg
        set sett($comboId,label) $masterFr.l
        ttk::combobox $comboId -postcommand "${ns}::SaveComboEntry $comboId"
        bind $masterFr.cb <Key-Escape> "focus [focus -lastfor $comboId] ; break"
        bind $masterFr.cb <Any-KeyRelease> \
                          "${ns}::CheckDir $masterFr.cb $masterFr.l"
        bind $masterFr.cb <<ComboboxSelected>> \
                          "${ns}::UpdateNewEntry $masterFr.cb ; ${ns}::CheckDir $masterFr.cb $masterFr.l"
        bind $masterFr.cb <Configure> "${ns}::AdjustText $masterFr.cb"

        # Create a Drag-And-Drop binding for the file combobox.
        poDragAndDrop AddTtkBinding $comboId "${ns}::UpdateDirSelectByDrop"

        ttk::label $masterFr.l
        pack $masterFr.cb -side left -anchor w -fill x -expand 1 -padx 1
        pack $masterFr.l  -side left -anchor w

        if { $textOrImg ne "" } {
            if { [poImgMisc IsPhoto $textOrImg] } {
                ttk::button $masterFr.b -image $textOrImg \
                            -command "${ns}::SelectDir $masterFr.cb $masterFr.l 1"
            } else {
                ttk::button $masterFr.b -text $textOrImg \
                            -command "${ns}::SelectDir $masterFr.cb $masterFr.l 1"
            }
            bind $masterFr.b <Shift-ButtonPress-1> \
                             "${ns}::SelectDir $masterFr.cb $masterFr.l 0"
            pack $masterFr.b -side left -anchor w
            poToolhelp AddBinding $masterFr.b $msg
        }
        SetValue $comboId $initDir
        CheckDir $masterFr.cb $masterFr.l
        UpdateNewEntry $comboId true
        focus $comboId
        return $comboId
    }

    # Create a megawidget for file selection.
    # "masterFr" is the frame, where the components of the megawidgets are placed.
    # "initFile" is the initial file name to be displayed in the combobox.
    # "mode" must be either "open" for a file to open or "save" for saving a file.
    # "textOrImg" is an optional string or photo displayed on the select button.
    # If an empty string is supplied, the select button is not drawn.
    # "msg" is an optional string displayed in the Tk file chooser.
    proc CreateFileSelect { masterFr initFile mode \
                           { textOrImg "Select ..." } \
                           { msg "Select file" } } {
        variable ns
        variable sett

        set comboId ${masterFr}.cb
        set sett($comboId,msg) $msg
        set sett($comboId,label) $masterFr.l
        ttk::combobox $comboId -postcommand "${ns}::SaveComboEntry $comboId"
        bind $masterFr.cb <Key-Escape> "focus [focus -lastfor $comboId] ; break"
        bind $masterFr.cb <Any-KeyRelease> \
                          "${ns}::CheckFile $masterFr.cb $masterFr.l"
        bind $masterFr.cb <<ComboboxSelected>> \
                          "${ns}::UpdateNewEntry $masterFr.cb false ; ${ns}::CheckFile $masterFr.cb $masterFr.l"
        bind $masterFr.cb <Configure> "${ns}::AdjustText $masterFr.cb"
        
        # Create a Drag-And-Drop binding for the file combobox.
        poDragAndDrop AddTtkBinding $comboId "${ns}::UpdateFileSelectByDrop"

        ttk::label $masterFr.l
        pack $masterFr.cb -side left -anchor w -fill x -expand 1 -padx 1
        pack $masterFr.l -side left -anchor w

        if { $textOrImg ne "" } {
            if { [poImgMisc IsPhoto $textOrImg] } {
                ttk::button $masterFr.b -image $textOrImg \
                            -command "${ns}::SelectFile $masterFr.cb $masterFr.l $mode 1"
            } else {
                ttk::button $masterFr.b -text $textOrImg \
                            -command "${ns}::SelectFile $masterFr.cb $masterFr.l $mode 1"
            }
            bind $masterFr.b <Shift-ButtonPress-1> \
                             "${ns}::SelectFile $masterFr.cb $masterFr.l $mode 0"
            pack $masterFr.b -side left -anchor w
            poToolhelp AddBinding $masterFr.b $msg
        }
        SetValue $comboId $initFile
        SetFileTypes $comboId { {"All files" "*"} }
        UpdateNewEntry $comboId true
        focus $comboId
        return $comboId
    }
}
