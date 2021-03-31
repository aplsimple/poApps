# Module:         poOffice
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office programs.

namespace eval poOffice {
    variable ns [namespace current]

    set sPo(FileType,Holiday) {
        {"Holiday files" ".hol"}
        {"All files"     "*"}
    }

    proc SelectHolidays { tableId what } {
        $tableId selection clear 0 end
        if { $what eq "all" } {
            $tableId selection set 0 end
        }
    }
 
    proc ShowHolidayInOutlook { tableId } {
        set appId [Outlook Open olFolderCalendar]

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }
        set row [poTablelistUtil GetFirstSelectedRow $tableId]

        set appointId [$tableId rowattrib $row "appointId"]
        if { $appointId ne "" } {
            set retVal [catch { $appointId Display } errVal]
            if { $retVal != 0 } {
                WriteInfoStr "Appointment not available" "Error"
                $tableId rowattrib $row "appointId" ""
            }
        }
    }

    proc HolidaysToOutlook { tableId } {
        variable sPo

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            WriteInfoStr "No holiday entries selected" "Error"
            return
        }

        set appId [Outlook Open olFolderCalendar]

        # Get selected calendar and category.
        set calendar ""
        if { [poTablelistUtil IsRowSelected $sPo(calendarTable)] } {
            set calRow [poTablelistUtil GetFirstSelectedRow $sPo(calendarTable)]
            set calendar [lindex [$sPo(calendarTable) get $calRow] 0]
        }
        if { $calendar eq "" } {
            WriteInfoStr "No calendar selected" "Error"
            return
        }
        if { ! [Outlook HaveCalendar $appId $calendar] } {
            WriteInfoStr "Calendar \"$calendar\" does not exist" "Error"
            return
        }
        set calId [Outlook GetCalendarId $appId $calendar]

        set category ""
        if { [poTablelistUtil IsRowSelected $sPo(categoryTable)] } {
            set catRow [poTablelistUtil GetFirstSelectedRow $sPo(categoryTable)]
            set category [lindex [$sPo(categoryTable) get $catRow] 0]
        }

        set rowList [$tableId curselection]
        foreach row $rowList {
            set rowCont [$tableId get $row]
            lassign $rowCont dummy section subject date
            set appointId [Outlook AddHolidayAppointment $calId $subject \
                            -date $date \
                            -location $section \
                            -category $category]
            $tableId rowattrib $row "appointId" $appointId
        }
        WriteInfoStr "[llength $rowList] holiday entries imported" "Ok"
    }

    proc DeleteHolidayFrame {} {
        variable sPo

        set masterFr $sPo(workFr).fr
        if { [winfo exists $masterFr] } {
            destroy $masterFr
            set appId [Outlook Open olFolderCalendar]
            Outlook Quit $appId
        }
    }
 
    proc CreateHolidayFrame {} {
        variable sPo
        variable ns

        set masterFr $sPo(workFr).fr
        if { [winfo exists $masterFr] } {
            return $masterFr
        }

        ttk::frame $masterFr
        pack $masterFr -side top -expand 1 -fill both

        set btnFr $masterFr.btnfr
        set horiFr $masterFr.horifr

        ttk::frame $btnFr
        ttk::panedwindow $horiFr -orient horizontal

        grid $btnFr  -row 0 -column 0 -sticky news
        grid $horiFr -row 1 -column 0 -sticky news
        grid rowconfigure    $masterFr 1 -weight 1
        grid columnconfigure $masterFr 0 -weight 1

        set vertFr $horiFr.vertfr
        set holFr  $horiFr.holfr
        ttk::panedwindow $vertFr -orient vertical
        ttk::frame $holFr
        pack $vertFr -expand 1 -fill both
        pack $holFr  -expand 1 -fill both

        $horiFr add $vertFr
        $horiFr add $holFr

        set calFr $vertFr.calfr
        set catFr $vertFr.catfr
        ttk::frame $calFr
        ttk::frame $catFr
        pack $calFr -expand 1 -fill both
        pack $catFr -expand 1 -fill both
        $vertFr add $calFr
        $vertFr add $catFr

        set sPo(calendarTable) [poWin CreateScrolledTablelist $calFr true "" \
            -exportselection false \
            -columns { 0 "Calendars" "left" } \
            -stretch 0 \
            -stripebackground [poAppearance GetStripeColor] \
            -selectmode single]

        set sPo(categoryTable) [poWin CreateScrolledTablelist $catFr true "" \
            -exportselection false \
            -columns { 0 "Categories" "left" } \
            -stretch 0 \
            -stripebackground [poAppearance GetStripeColor] \
            -selectmode single]

        set appId [Outlook Open olFolderCalendar]
        set calNameList [Outlook GetCalendarNames $appId]
        foreach calName [lsort -dictionary $calNameList] {
            $sPo(calendarTable) insert end [list $calName]
        }
        $sPo(calendarTable) selection set 0 0

        set catNameList [Outlook GetCategoryNames $appId]
        foreach catName [lsort -dictionary $catNameList] {
            set categoryId [Outlook GetCategoryId $appId $catName]
            set colorHex [Outlook GetCategoryColor [$categoryId Color]]
            set cellImg [poImgMisc CreateLabelImg $colorHex 15 15]

            $sPo(categoryTable) insert end [list $catName]
            $sPo(categoryTable) cellconfigure end,0 -image $cellImg
        }
        $sPo(categoryTable) selection set 0 0

        set sPo(holidayTable) [poWin CreateScrolledTablelist $holFr true "" \
            -exportselection false \
            -columns {0 "#"       "right" \
                      0 "Section" "left" \
                      0 "Subject" "left" \
                      0 "Date"    "left" } \
            -stripebackground [poAppearance GetStripeColor] \
            -labelcommand tablelist::sortByColumn \
            -selectmode extended \
            -showseparators yes]
        $sPo(holidayTable) columnconfigure 0 -showlinenumbers true
        $sPo(holidayTable) columnconfigure 1 -sortmode dictionary
        $sPo(holidayTable) columnconfigure 2 -sortmode dictionary
        $sPo(holidayTable) columnconfigure 3 -sortmode dictionary
        bind $sPo(holidayTable) <<TablelistSelect>> "${ns}::ShowHolidayInOutlook $sPo(holidayTable)"

        poToolbar New $btnFr
        poToolbar AddGroup $btnFr
        poToolbar AddButton $btnFr [::poBmpData::selectall] \
            "${ns}::SelectHolidays $sPo(holidayTable) all" "Select all holiday entries"
        poToolbar AddButton $btnFr [::poBmpData::unselectall] \
            "${ns}::SelectHolidays $sPo(holidayTable) off" "Unselect all holiday entries"
        poToolbar AddGroup $btnFr
        poToolbar AddButton $btnFr [::poBmpData::renOut] \
            "${ns}::HolidaysToOutlook $sPo(holidayTable)" "Send selected entries to Outlook"

        return $masterFr
    }

    proc GetHolidayFileName { title useLastDir { mode "open" } { initFile "" } } {
        variable ns
        variable sPo

        if { $useLastDir } {
            set initDir [GetCurDirectory]
        } else {
            set initDir [pwd]
        }
        if { $mode eq "open" } {
            set fileName [tk_getOpenFile -filetypes $sPo(FileType,Holiday) \
                         -initialdir $initDir -title $title]
        } else {
            if { ! [info exists sPo(LastHolidayType)] } {
                set sPo(LastHolidayType) [lindex [lindex $fileTypes 0] 0]
            }
            set fileExt [file extension $initFile]
            set typeExt [poMisc GetExtensionByType $sPo(FileType,Holiday) $sPo(LastHolidayType)]
            if { $typeExt ne $fileExt } {
                set initFile [file rootname $initFile]
            }

            set fileName [tk_getSaveFile \
                         -filetypes $sPo(FileType,Holiday) \
                         -title $title \
                         -parent $sPo(tw) \
                         -confirmoverwrite false \
                         -typevariable ${ns}::sPo(LastHolidayType) \
                         -initialfile $initFile \
                         -initialdir $initDir]
            if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
                set ext [poMisc GetExtensionByType $fileTypes $sPo(LastHolidayType)]
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
            SetCurDirectory [file dirname $fileName]
        }
        return $fileName
    }

    proc AskOpenHolidayFile { { useLastDir true } } {
        variable sPo
     
        set fileName [GetHolidayFileName "Open file" $useLastDir "open" [GetCurFile]]
        if { $fileName ne "" } {
            CloseSubWindows
            OpenHolidayFile $fileName
        }
    }

    proc OpenHolidayFile { fileName } {
        variable sPo

        if { $sPo(curFrame) ne "" } {
            destroy $sPo(curFrame)
        }
        set sPo(curFrame) [CreateHolidayFrame]

        $sPo(holidayTable) delete 0 end
        set holidayDict [Outlook ReadHolidayFile $fileName]
        set sectionList [dict get $holidayDict SectionList]
        if { [llength $sectionList] == 0 } {
            UpdateMainTitle "None"
            WriteInfoStr "Could not read holiday file $fileName" "Error"
            return
        }
        foreach section $sectionList {
            set subjectList [dict get $holidayDict "SubjectList_$section"]
            set dateList    [dict get $holidayDict "DateList_$section"]
            foreach subject $subjectList date $dateList {
                $sPo(holidayTable) insert end [list "" $section $subject $date]
                $sPo(holidayTable) rowattrib end "appointId" ""
            }
        }
        SelectHolidays $sPo(holidayTable) all

        poWinSelect SetValue $sPo(fileCombo) $fileName
        SetCurFile $fileName
        SetCurDirectory [file dirname $fileName]
        poAppearance AddToRecentFileList $fileName
        UpdateMainTitle [file tail $fileName]
        WriteInfoStr "Parsed holiday file $fileName" "Ok"
    }
}

catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
