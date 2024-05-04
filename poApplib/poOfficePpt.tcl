# Module:         poOffice - PowerPoint
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2021 / 02 / 05
#
# Distributed under BSD license.

namespace eval poOffice {
    variable ns [namespace current]

    proc CheckPptAvailable {} {
        variable sPo

        if { [info exists sPo(pptId)] && [Cawt IsComObject $sPo(pptId)] } {
            return true
        }
        return false
    }

    proc CheckPptFileAvailable {} {
        variable sPo

        if { [CheckPptAvailable] } {
            return true
        }
        set curFile [file tail [GetCurFile]]
        set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "No PowerPoint presentation available.\nReopen $curFile?" \
                  -type yesno -default yes -icon question]
        if { $retVal eq "no" } {
            WriteInfoStr "PowerPoint presentation or instance not available." "Error"
            return false
        } else {
            OpenPptFile [GetCurFile]
            return true
        }
    }

    proc ClosePpt {} {
        variable sPo

        StopPptCheck
        if { [info exists sPo(presId)] && [Cawt IsComObject $sPo(presId)] } {
            catch { Ppt Close $sPo(presId) }
            catch { Cawt Destroy $sPo(presId) }
        }
        if { [info exists sPo(pptId)] && [Cawt IsComObject $sPo(pptId)] } {
            catch { Ppt Quit $sPo(pptId) false }
            catch { Cawt Destroy $sPo(pptId) }
        }
        catch { unset sPo(presId) }
        catch { unset sPo(pptId) }
        WriteInfoStr "PowerPoint instance has been closed." "Ok"
        poWin ToggleSwitchableWidgets "Ppt" false
    }

    proc ClearPptInfoTable {} {
        variable sPo

        $sPo(InfoPptTable) delete 0 end
        if { [$sPo(InfoPptTable) columncount] > 0 } {
            $sPo(InfoPptTable) deletecolumns 0 end
        }
        poWin SetScrolledTitle $sPo(InfoPptTable) "Select slide from above for preview"
    }

    proc ClearPptSlideTable {} {
        variable sPo

        $sPo(SlideTable) delete 0 end
        poWin SetScrolledTitle $sPo(SlideTable) "List of slides"
    }

    proc ShowSlide { tableId column } {
        variable sPo

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        if { ! [CheckPptFileAvailable] } {
            return
        }

        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set slideName [$tableId cellcget "$row,$column" -text]
        set slideId [Ppt GetSlideIdByName $sPo(presId) $slideName]

        ClearPptInfoTable

        set numImages [Ppt GetNumSlideImages $slideId]
        set numVideos [Ppt GetNumSlideVideos $slideId]
        set title [format "Slide %s: %d images. %d videos" \
                  $slideName $numImages $numVideos]
        poWin SetScrolledTitle $sPo(InfoPptTable) $title

        Ppt ShowSlide $sPo(presId) [Ppt GetSlideIndex $slideId]
    }

    proc ShowPresInfo {} {
        variable sPo
        variable ns

        if { ! [CheckPptFileAvailable] } {
            return
        }

        set sPo(StopPptCheck) false
        ClearPptInfoTable
        ClearPptSlideTable

        set numSlides [Ppt GetNumSlides $sPo(presId)]
        set title [format "%s contains %d slides" [file tail [GetCurFile]] $numSlides]
        poWin SetScrolledTitle $sPo(SlideTable) $title

        WriteInfoStr "Retrieving presentation information ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) $numSlides
        set count 1

        for { set i 1 } { $i <= $numSlides } { incr i } {
            set slideId [Ppt GetSlideId $sPo(presId) $i]
            set slideName [Ppt GetSlideName $slideId]
            set numImages [Ppt GetNumSlideImages $slideId]
            set numVideos [Ppt GetNumSlideVideos $slideId]
            $sPo(SlideTable) insert end [list "" $slideName $numImages $numVideos]
            Cawt Destroy $slideId
            if { $count % 10 == 1 } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $count
                if { $sPo(StopPptCheck) } {
                    WriteInfoStr "Information check cancelled" "Cancel"
                    poWin UpdateStatusProgress $sPo(StatusWidget) 0
                    return
                }
            }
            incr count
        }
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        WriteInfoStr "Presentation information has been retrieved." "Ok"
    }

    proc InitPptInfoRollUp { fr } {
        variable sPo
        variable ns

        set numEntries 20
        if { [llength $slideNames] < $numEntries } {
            set numEntries [llength $slideNames]
        }
        set sPo(SlideTable) [poWin CreateScrolledTablelist $fr true "" \
            -columns [list 0 "Slides" "left"] \
            -height $numEntries \
            -width 30 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 0 \
            -showseparators 1]
        bind $sPo(SlideTable) <<TablelistSelect>> "${ns}::ShowSlide $sPo(SlideTable)"
        foreach slide $slideNames {
            $sPo(SlideTable) insert end [list $slide]
        }
    }

    proc InitPptMyRollUp { rollUpFr } {
        variable sPo
        variable ns

        puts "InitPptMyRollUp"
    }

    proc StopPptCheck { { msg "Check stopped by user" } } {
        variable sPo

        WriteInfoStr $msg "Cancel"
        set sPo(StopPptCheck) true
    }

    proc CreatePptOptionRollUp { rollUpFr } {
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
                     ${ns}::ShowPresInfo "Show information about loaded file"]

        poToolbar AddGroup $toolFr
        set closeBtn [poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                     ${ns}::ClosePpt "Close PowerPoint presentation"]

        poToolbar AddGroup $toolFr
        poToolbar AddButton $toolFr [::poBmpData::halt "red"] \
                  ${ns}::StopPptCheck "Stop check (Esc)" -state $sPo(CawtState)
        bind $sPo(tw) <Escape> ${ns}::StopPptCheck

        poWin AddToSwitchableWidgets "Ppt" $infoBtn $closeBtn

        set innerRollUp [poWinRollUp Create $innerFr ""]
        
        # set myRollUp [poWinRollUp Add $innerRollUp "MyRollUp" false]
        # InitPptMyRollUp $myRollUp
        # poWin AddToSwitchableWidgets "Ppt" $myRollUp
    }

    proc CreatePptTab { masterFr } {
        variable sPo
        variable ns

        set paneHori $masterFr.pane
        ttk::panedwindow $paneHori -orient horizontal
        pack $paneHori -side top -expand 1 -fill both
        SetHoriPaneWidget $paneHori "Ppt"

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

        set sPo(Ppt,embedFr) $embedFr

        # Create the rollups for the options.
        set rollUpFr [poWin CreateScrolledFrame $rollFr true ""]
        CreatePptOptionRollUp $rollUpFr

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
        SetVertPaneWidget $paneVert "Ppt"
        
        set slideTableFr $paneVert.slidetablefr
        set infoTableFr  $paneVert.infotablefr
        ttk::frame $slideTableFr
        ttk::frame $infoTableFr

        $paneVert add $slideTableFr
        $paneVert add $infoTableFr

        set sPo(SlideTable) [poWin CreateScrolledTablelist $slideTableFr true "List of slides" \
            -columns [list 4 "#"          "right" \
                           0 "Slide name" "left" \
                           0 "# images"   "right" \
                           0 "# videos"   "right"] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(SlideTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(SlideTable) columnconfigure 1 -sortmode dictionary
        $sPo(SlideTable) columnconfigure 2 -sortmode integer
        $sPo(SlideTable) columnconfigure 3 -sortmode integer
        bind $sPo(SlideTable) <<TablelistSelect>> "${ns}::ShowSlide $sPo(SlideTable) 1"

        set title "Select slide from above for preview"
        set sPo(InfoPptTable) [poWin CreateScrolledTablelist $infoTableFr true $title \
            -height 20 \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch all \
            -showseparators 1]

        poWin ToggleSwitchableWidgets "Ppt" false
    }

    proc OpenPptFile { fileName } {
        variable sPo
        variable ns

        ClosePpt

        SelectNotebookTab "Ppt"

        WriteInfoStr "Loading PowerPoint file \"$fileName\" ..." "Watch"

        set nativeName [file nativename [file normalize $fileName]]

        ClearPptInfoTable
        ClearPptSlideTable

        set pptId [Ppt OpenNew]
        set embedArg ""
        if { [GetEmbeddedMode] } {
            set embedArg "-embed $sPo(Ppt,embedFr)"
        }
        set presId [Ppt OpenPres $pptId $nativeName \
                   -readonly [GetReadOnlyMode] {*}$embedArg]
        set sPo(pptId)  $pptId
        set sPo(presId) $presId

        poWinSelect SetValue $sPo(fileCombo) $fileName
        SetCurFile $fileName
        SetCurDirectory [file dirname $fileName]
        poAppearance AddToRecentFileList $fileName
        UpdateMainTitle [file tail $fileName]

        ShowPresInfo

        WriteInfoStr "PowerPoint file \"$fileName\" loaded." "Ok"
        poWin ToggleSwitchableWidgets "Ppt" true
    }
}
