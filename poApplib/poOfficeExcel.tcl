# Module:         poOffice - Excel
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2021 / 02 / 05
#
# Distributed under BSD license.

namespace eval poOffice {
    variable ns [namespace current]

    proc CheckExcelEvents { args } {
        variable sPo

        if { [lindex $args 0] eq "WorkbookBeforeClose" } {
            catch { unset sPo(xlsId) }
            poWin ToggleSwitchableWidgets "Excel" false
            ClearExcelInfoTable
            ClearExcelWorksheetTable
            if { ! $sPo(CleanExcelClose) } {
                WriteInfoStr "Excel instance not available anymore." "Error"
            }
        }
    }

    proc CheckExcelAvailable {} {
        variable sPo

        if { [info exists sPo(xlsId)] && [Cawt IsComObject $sPo(xlsId)] } {
            return true
        }
        return false
    }

    proc CheckExcelFileAvailable {} {
        variable sPo

        if { [CheckExcelAvailable] } {
            return true
        }
        set curFile [file tail [GetCurFile]]
        set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "No Excel document available.\nReopen $curFile?" \
                  -type yesno -default yes -icon question]
        if { $retVal eq "no" } {
            WriteInfoStr "Excel document or instance not available." "Error"
            return false
        } else {
            OpenExcelFile [GetCurFile]
            return true
        }
    }

    proc CloseExcel {} {
        variable sPo

        set sPo(CleanExcelClose) true
        StopExcelCheck
        if { [info exists sPo(xlsId)] && [Cawt IsComObject $sPo(xlsId)] } {
            catch { Excel Close $sPo(xlsId) }
            catch { Cawt Destroy $sPo(xlsId) }
        }
        if { [info exists sPo(excelId)] && [Cawt IsComObject $sPo(excelId)] } {
            Cawt SetEventCallback $sPo(excelId) ""
            catch { Excel Quit $sPo(excelId) false }
            catch { Cawt Destroy $sPo(excelId) }
        }
        catch { unset sPo(xlsId) }
        catch { unset sPo(excelId) }
        WriteInfoStr "Excel instance has been closed." "Ok"
        poWin ToggleSwitchableWidgets "Excel" false
    }

    proc ClearExcelInfoTable {} {
        variable sPo

        $sPo(InfoExcelTable) delete 0 end
        if { [$sPo(InfoExcelTable) columncount] > 0 } {
            $sPo(InfoExcelTable) deletecolumns 0 end
        }
        poWin SetScrolledTitle $sPo(InfoExcelTable) "Select worksheet from above for preview"
    }

    proc ClearExcelWorksheetTable {} {
        variable sPo

        $sPo(WorksheetTable) delete 0 end
        poWin SetScrolledTitle $sPo(WorksheetTable) "List of worksheets"
    }

    proc ShowWorksheet { tableId column } {
        variable sPo

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        if { ! [CheckExcelFileAvailable] } {
            return
        }

        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set worksheetName [$tableId cellcget "$row,$column" -text]
        set worksheetId [Excel GetWorksheetIdByName $sPo(xlsId) $worksheetName]

        ClearExcelInfoTable

        set numRows [Excel GetLastUsedRow $worksheetId]
        set numCols [Excel GetLastUsedColumn $worksheetId]
        set title [format "Worksheet %s: %d rows. %d columns (A-%s)" \
                  $worksheetName $numRows $numCols [Excel ColumnIntToChar $numCols]]
        set maxRows 1000
        set maxCols  500
        if { $numRows > $maxRows || $numCols > $maxCols } {
            append title " (not all displayed)"
        }
        poWin SetScrolledTitle $sPo(InfoExcelTable) $title
        Excel WorksheetToTablelist $worksheetId $sPo(InfoExcelTable) -rownumber true \
                                   -maxrows $maxRows -maxcols $maxCols
    }

    proc ShowWorkbookInfo {} {
        variable sPo
        variable ns

        if { ! [CheckExcelFileAvailable] } {
            return
        }

        set sPo(StopExcelCheck) false
        ClearExcelInfoTable
        ClearExcelWorksheetTable

        set numWorksheets [Excel GetNumWorksheets $sPo(xlsId)]
        set title [format "%s contains %d worksheets" [file tail [GetCurFile]] $numWorksheets]
        poWin SetScrolledTitle $sPo(WorksheetTable) $title

        WriteInfoStr "Retrieving workbook information ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) $numWorksheets
        set count 1
        
        for { set i 1 } { $i <= $numWorksheets } { incr i } {
            set worksheetId [Excel GetWorksheetIdByIndex $sPo(xlsId) $i false]
            set worksheetName [Excel GetWorksheetName $worksheetId]
            set numRows [Excel GetLastUsedRow $worksheetId]
            set numCols [Excel GetLastUsedColumn $worksheetId]
            $sPo(WorksheetTable) insert end [list "" $worksheetName $numRows $numCols]
            Cawt Destroy $worksheetId
            if { $count % 10 == 1 } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $count
                if { $sPo(StopExcelCheck) } {
                    WriteInfoStr "Information check cancelled" "Cancel"
                    poWin UpdateStatusProgress $sPo(StatusWidget) 0
                    return
                }
            }
            incr count
        }
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        WriteInfoStr "Workbook information has been retrieved." "Ok"
    }

    proc InitExcelMyRollUp { rollUpFr } {
        variable sPo
        variable ns

        puts "InitExcelMyRollUp"
    }

    proc StopExcelCheck { { msg "Check stopped by user" } } {
        variable sPo

        WriteInfoStr $msg "Cancel"
        set sPo(StopExcelCheck) true
    }

    proc CreateExcelOptionRollUp { rollUpFr } {
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
        set infoBtn [poToolbar AddButton $toolFr [::poBmpData::info] \
                     ${ns}::ShowWorkbookInfo "Show information about loaded file"]

        poToolbar AddGroup $toolFr
        set closeBtn [poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                     ${ns}::CloseExcel "Close Excel document"]

        poToolbar AddGroup $toolFr
        poToolbar AddButton $toolFr [::poBmpData::halt "red"] \
                  ${ns}::StopExcelCheck "Stop check (Esc)" -state $sPo(CawtState)
        bind $sPo(tw) <Escape> ${ns}::StopExcelCheck

        poWin AddToSwitchableWidgets "Excel" $infoBtn $closeBtn

        set innerRollUp [poWinRollUp Create $innerFr ""]
        
        # set myRollUp [poWinRollUp Add $innerRollUp "MyRollUp" false]
        # InitExcelMyRollUp $myRollUp
        # poWin AddToSwitchableWidgets "Excel" $myRollUp
    }

    proc CreateExcelTab { masterFr } {
        variable sPo
        variable ns

        set paneHori $masterFr.pane
        ttk::panedwindow $paneHori -orient horizontal
        pack $paneHori -side top -expand 1 -fill both
        SetHoriPaneWidget $paneHori "Excel"

        set rollFr  $paneHori.rollfr
        set tableFr $paneHori.tablefr
        set embedFr $paneHori.embedfr
        ttk::frame $rollFr
        ttk::frame $tableFr
        # Note: ttk::frame does not have container configuration option.
        frame $embedFr -container true -borderwidth 0

        $paneHori add $rollFr
        $paneHori add $tableFr
        $paneHori add $embedFr

        $paneHori pane $rollFr  -weight 0
        $paneHori pane $tableFr -weight 1
        $paneHori pane $embedFr -weight 1

        set sPo(Excel,embedFr) $embedFr

        # Create the rollups for the options.
        set rollUpFr [poWin CreateScrolledFrame $rollFr true ""]
        CreateExcelOptionRollUp $rollUpFr

        # Create a notebook for the Info frame containing the result tables.
        set nb $tableFr.nb
        ttk::notebook $nb
        pack $nb -fill both -expand 1 -padx 2 -pady 3
        ttk::notebook::enableTraversal $nb

        # Create the contents of the Info tab.
        set infoFr $nb.infofr
        ttk::frame $infoFr
        $nb add $infoFr -text "Information" -underline 0 -padding 2

        set paneVert $infoFr.pane
        ttk::panedwindow $paneVert -orient vertical
        pack $paneVert -side top -expand 1 -fill both
        SetVertPaneWidget $paneVert "Excel"
        
        set sheetTableFr $paneVert.sheettablefr
        set infoTableFr $paneVert.infotablefr
        ttk::frame $sheetTableFr
        ttk::frame $infoTableFr

        $paneVert add $sheetTableFr
        $paneVert add $infoTableFr

        set sPo(WorksheetTable) [poWin CreateScrolledTablelist $sheetTableFr true "List of worksheets" \
            -columns [list 4 "#"              "right" \
                           0 "Worksheet name" "left" \
                           0 "Used rows"      "right" \
                           0 "Used columns"   "right"] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(WorksheetTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(WorksheetTable) columnconfigure 1 -sortmode dictionary
        $sPo(WorksheetTable) columnconfigure 2 -sortmode integer
        $sPo(WorksheetTable) columnconfigure 3 -sortmode integer
        bind $sPo(WorksheetTable) <<TablelistSelect>> "${ns}::ShowWorksheet $sPo(WorksheetTable) 1"

        set title "Select worksheet from above for preview"
        set sPo(InfoExcelTable) [poWin CreateScrolledTablelist $infoTableFr true $title \
            -height 20 \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch all \
            -showseparators 1]

        poWin ToggleSwitchableWidgets "Excel" false
        set sPo(CleanExcelClose) false
    }

    proc OpenExcelFile { fileName } {
        variable sPo
        variable ns

        CloseExcel

        SelectNotebookTab "Excel"

        WriteInfoStr "Loading Excel file \"$fileName\" ..." "Watch"

        set nativeName [file nativename [file normalize $fileName]]

        set excelId [Excel OpenNew [GetVisibleMode]]
        set embedArg ""
        if { [GetEmbeddedMode] } {
            set embedArg "-embed $sPo(Excel,embedFr)"
        }
        set xlsId [Excel OpenWorkbook $excelId $nativeName \
                  -readonly [GetReadOnlyMode] {*}$embedArg] 
        set sPo(excelId) $excelId
        set sPo(xlsId)   $xlsId

        poWinSelect SetValue $sPo(fileCombo) $fileName
        SetCurFile $fileName
        SetCurDirectory [file dirname $fileName]
        poAppearance AddToRecentFileList $fileName
        UpdateMainTitle [file tail $fileName]

        ShowWorkbookInfo

        WriteInfoStr "Excel file \"$fileName\" loaded." "Ok"
        Cawt SetEventCallback $sPo(excelId) ${ns}::CheckExcelEvents
        poWin ToggleSwitchableWidgets "Excel" true
    }
}
