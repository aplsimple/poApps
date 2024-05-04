# Module:         poOffice - OneNote
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2021 / 02 / 05
#
# Distributed under BSD license.

namespace eval poOffice {
    variable ns [namespace current]

    proc CheckOneNoteAvailable {} {
        variable sPo

        if { [info exists sPo(oneNoteId)] } {
            return true
        }
        return false
    }

    proc CloseOneNote {} {
        variable sPo

        if { [CheckOneNoteAvailable] } {
            catch { OneNote Quit $sPo(oneNoteId) }
            catch { Cawt Destroy $sPo(oneNoteId) }
        }
        catch { unset sPo(oneNoteId) }
        WriteInfoStr "OneNote instance has been closed." "Ok"
        poWin ToggleSwitchableWidgets "OneNote" false

        ClearOneNoteInfoTable
        ClearOneNoteNotebookTable
    }

    proc ClearOneNoteInfoTable {} {
        variable sPo

        $sPo(InfoOneNoteTable) delete 0 end
        poWin SetScrolledTitle $sPo(InfoOneNoteTable) "Select notebook from above for preview"
    }

    proc ClearOneNoteNotebookTable {} {
        variable sPo

        $sPo(NotebookTable) delete 0 end
        poWin SetScrolledTitle $sPo(NotebookTable) "List of notebooks"
    }

    proc ShowNotebook { tableId column } {
        variable sPo

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        if { ! [CheckOneNoteAvailable] } {
            return
        }

        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set notebookName [$tableId cellcget "$row,$column" -text]

        set domNotebook [OneNote FindNotebook $sPo(domRoot) $notebookName]
        set sectionDomList [OneNote GetSections $domNotebook]
        set sectionList [list]
        foreach sectionDom $sectionDomList {
            lappend sectionList [OneNote GetNodeName $sectionDom]
        }

        ClearOneNoteInfoTable
        set numSections 0
        set numPages    0
        foreach section $sectionList {
            set domSection [OneNote FindSection $domNotebook $section]
            set pageDomList [OneNote GetPages $domSection]
            if { [llength $pageDomList] > 0 } {
                incr numSections
            }
            foreach pageDom $pageDomList {
                # TODO Add node link
                set pageName [OneNote GetNodeName $pageDom]
                set pageDate [Cawt XmlDateToIsoDate [OneNote GetNodeAttribute $pageDom "lastModifiedTime"]]
                $sPo(InfoOneNoteTable) insert end [list "" $section $pageName $pageDate]
                incr numPages
            }
        }
        set titleMsg [format "Notebook %s contains %d sections and %d pages." \
                      $notebookName $numSections $numPages]
        poWin SetScrolledTitle $sPo(InfoOneNoteTable) $titleMsg
    }

    proc InitOneNoteMyRollUp { fr } {
        variable sPo
        variable ns

        puts "InitOneNoteMyRollUp"
    }

    proc ShowOneNoteInfo {} {
        variable sPo
        variable ns

        if { ! [CheckOneNoteAvailable] } {
            return
        }

        ClearOneNoteInfoTable
        ClearOneNoteNotebookTable

        set notebookDomList [OneNote GetNotebooks $sPo(domRoot)]
        set notebookList [list]
        foreach notebookDom $notebookDomList {
            lappend notebookList [OneNote GetNodeName $notebookDom]
        }
        foreach notebookName $notebookList {
            $sPo(NotebookTable) insert end [list "" $notebookName]
        }
        set title [format "OneNote contains %d notebooks" [llength $notebookList]]
        poWin SetScrolledTitle $sPo(NotebookTable) $title
    }

    proc CreateOneNoteOptionRollUp { rollUpFr } {
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
        set newBtn [poToolbar AddButton $toolFr [::poBmpData::edit] \
                   ${ns}::OpenOneNote "Start OneNote application" -state $sPo(CawtState)]

        poToolbar AddGroup $toolFr
        set infoBtn [poToolbar AddButton $toolFr [::poBmpData::info] \
                     ${ns}::ShowOneNoteInfo "Show information about notebooks"]

        poToolbar AddGroup $toolFr
        set closeBtn [poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                     ${ns}::CloseOneNote "Close OneNote application"]

        poWin AddToSwitchableWidgets "OneNote" $infoBtn $closeBtn

        set innerRollUp [poWinRollUp Create $innerFr ""]

        # set myRollUp [poWinRollUp Add $innerRollUp "MyRollup" false]
        # InitOneNotemyRollUp $myRollUp
        # poWin AddToSwitchableWidgets "OneNote" $myRollUp
    }

    proc CreateOneNoteTab { masterFr } {
        variable sPo
        variable ns

        set paneHori $masterFr.pane
        ttk::panedwindow $paneHori -orient horizontal
        pack $paneHori -side top -expand 1 -fill both
        SetHoriPaneWidget $paneHori "OneNote"

        set rollFr  $paneHori.rollfr
        set tableFr $paneHori.tablefr
        ttk::frame $rollFr
        ttk::frame $tableFr

        $paneHori add $rollFr
        $paneHori add $tableFr

        # Create the rollups for the options.
        set rollUpFr [poWin CreateScrolledFrame $rollFr true ""]
        CreateOneNoteOptionRollUp $rollUpFr

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
        SetVertPaneWidget $paneVert "OneNote"
        
        set notebookTableFr $paneVert.notebooktablefr
        set infoTableFr     $paneVert.infotablefr
        ttk::frame $notebookTableFr
        ttk::frame $infoTableFr

        $paneVert add $notebookTableFr
        $paneVert add $infoTableFr 

        set sPo(NotebookTable) [poWin CreateScrolledTablelist $notebookTableFr true "Notebooks" \
            -columns [list 4 "#"             "right" \
                           0 "Notebook name" "left"] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(NotebookTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(NotebookTable) columnconfigure 1 -sortmode dictionary
        bind $sPo(NotebookTable) <<TablelistSelect>> "${ns}::ShowNotebook $sPo(NotebookTable) 1"

        set sPo(InfoOneNoteTable) [poWin CreateScrolledTablelist $infoTableFr true "Sections and Pages" \
            -columns [list 4 "#"            "right"  \
                           0 "Section name" "left" \
                           0 "Page name"    "left" \
                           0 "Date"         "left" ] \
            -height 20 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(InfoOneNoteTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(InfoOneNoteTable) columnconfigure 1 -sortmode dictionary
        $sPo(InfoOneNoteTable) columnconfigure 2 -sortmode dictionary
        $sPo(InfoOneNoteTable) columnconfigure 3 -sortmode dictionary

        poWin ToggleSwitchableWidgets "OneNote" false
    }

    proc OpenOneNote {} {
        variable sPo

        CloseOneNote

        SelectNotebookTab "OneNote"

        WriteInfoStr "Starting OneNote application ..." "Watch"

        set oneNoteId [OneNote Open]
        set domRoot [OneNote GetDomRoot $oneNoteId]
        set sPo(oneNoteId) $oneNoteId
        set sPo(domRoot)   $domRoot

        UpdateMainTitle "OneNote"

        ShowOneNoteInfo

        WriteInfoStr "OneNote started." "Ok"
        poWin ToggleSwitchableWidgets "OneNote" true
    }
}
