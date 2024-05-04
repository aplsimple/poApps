# Module:         poOffice
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office programs.

namespace eval poOffice {
    variable ns [namespace current]

    proc SelectHolidays { tableId what } {
        $tableId selection clear 0 end
        if { $what eq "all" } {
            $tableId selection set 0 end
        }
    }
 
    proc ShowHolidayInOutlook { tableId } {
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }
        set row [poTablelistUtil GetFirstSelectedRow $tableId]

        set appId [Outlook Open olFolderCalendar]

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

    proc CloseOutlook {} {
        variable sPo

        if { [info exists sPo(outlookId)] } {
            Outlook Quit $sPo(outlookId)
        }
    }
 
    proc InitOutlookHolidayRollUp { fr } {
        variable sPo
        variable ns

        poToolbar New $fr
        poToolbar AddGroup $fr
        poToolbar AddButton $fr [::poBmpData::selectall] \
            "${ns}::SelectHolidays $sPo(holidayTable) all" "Select all holiday entries"
        poToolbar AddButton $fr [::poBmpData::unselectall] \
            "${ns}::SelectHolidays $sPo(holidayTable) off" "Unselect all holiday entries"
        poToolbar AddGroup $fr
        poToolbar AddButton $fr [::poBmpData::renOut] \
            "${ns}::HolidaysToOutlook $sPo(holidayTable)" "Send selected entries to Outlook"
    }

    proc CreateOutlookOptionRollUp { rollUpFr } {
        variable sPo
        variable ns

        set toolFr  $rollUpFr.toolFr
        set innerFr $rollUpFr.innerFr
        ttk::frame $toolFr
        ttk::frame $innerFr
        pack $toolFr  -side top -anchor w
        pack $innerFr -side top -anchor w -expand true -fill both

        # Add new toolbar group and associated buttons.
        poToolbar New $toolFr
        poToolbar AddGroup $toolFr
        set newBtn [poToolbar AddButton $toolFr [::poBmpData::preview] \
                   ${ns}::OpenOutlook "Start Outlook application" -state $sPo(CawtState)]

        poToolbar AddGroup $toolFr
        set closeBtn [poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                     ${ns}::CloseOutlook "Close Outlook application"]

        poWin AddToSwitchableWidgets "Outlook" $closeBtn

        set innerRollUp [poWinRollUp Create $innerFr ""]

        set holidayRollUp [poWinRollUp Add $innerRollUp "Holidays" false]
        InitOutlookHolidayRollUp $holidayRollUp
        poWin AddToSwitchableWidgets "Outlook" $holidayRollUp
    }

    proc CreateOutlookTab { masterFr } {
        variable sPo
        variable ns

        set paneHori $masterFr.pane
        ttk::panedwindow $paneHori -orient horizontal
        pack $paneHori -side top -expand 1 -fill both
        SetHoriPaneWidget $paneHori "Outlook"

        set rollFr  $paneHori.rollfr
        set tableFr $paneHori.tablefr
        ttk::frame $rollFr
        ttk::frame $tableFr

        $paneHori add $rollFr
        $paneHori add $tableFr

        # Create a notebook for the Holiday frame containing the result tables.
        set nb $tableFr.nb
        ttk::notebook $nb
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        # Create the contents of the Holiday tab.
        set holiFr $nb.holifr
        ttk::frame $holiFr
        $nb add $holiFr -text "Holidays" -underline 0 -padding 2

        set paneVert $holiFr.pane
        ttk::panedwindow $paneVert -orient vertical
        pack $paneVert -side top -expand 1 -fill both
        SetVertPaneWidget $paneVert "Outlook"

        set calCatTableFr $paneVert.calcatfr
        set holiTableFr   $paneVert.holifr
        ttk::frame $calCatTableFr
        ttk::frame $holiTableFr

        $paneVert add $calCatTableFr
        $paneVert add $holiTableFr 

        set calFr $calCatTableFr.calfr
        set catFr $calCatTableFr.catfr
        ttk::frame $calFr
        ttk::frame $catFr
        pack $calFr $catFr -side left

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

        set sPo(holidayTable) [poWin CreateScrolledTablelist $holiTableFr true "" \
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

        # Create the rollups for the options.
        set rollUpFr [poWin CreateScrolledFrame $rollFr true ""]
        CreateOutlookOptionRollUp $rollUpFr

        poWin ToggleSwitchableWidgets "Outlook" false
    }

    proc OpenHolidayFile { fileName } {
        variable sPo

        OpenOutlook

        # Retrieve all calendars and insert into calendar table.
        $sPo(calendarTable) delete 0 end
        set appId [Outlook Open olFolderCalendar]
        set calNameList [Outlook GetCalendarNames $appId]
        foreach calName [lsort -dictionary $calNameList] {
            $sPo(calendarTable) insert end [list $calName]
        }
        $sPo(calendarTable) selection set 0 0

        # Retrieve all categories and insert into category table.
        $sPo(categoryTable) delete 0 end
        set catNameList [Outlook GetCategoryNames $appId]
        foreach catName [lsort -dictionary $catNameList] {
            set categoryId [Outlook GetCategoryId $appId $catName]
            set colorHex [Outlook GetCategoryColor [$categoryId Color]]
            set cellImg [poImgMisc CreateLabelImg $colorHex 15 15]

            $sPo(categoryTable) insert end [list $catName]
            $sPo(categoryTable) cellconfigure end,0 -image $cellImg
        }
        $sPo(categoryTable) selection set 0 0

        # Read holiday file and insert into holiday table.
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

    proc OpenOutlook {} {
        variable sPo

        SelectNotebookTab "Outlook"

        WriteInfoStr "Starting Outlook application ..." "Watch"

        set outlookId [Outlook Open]
        set sPo(outlookId) $outlookId

        UpdateMainTitle "Outlook"

        WriteInfoStr "Outlook started." "Ok"
        poWin ToggleSwitchableWidgets "Outlook" true
    }
}
