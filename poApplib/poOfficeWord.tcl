# Module:         poOffice -Word
# Copyright:      Paul Obermeier 2017-2023 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office Word documents.

namespace eval poOffice {
    variable ns [namespace current]

    #
    # Procedures for values stored in settings file.
    #

    # Settings for abbreviation and word count functionality.

    proc SetMinLength { minChars } {
        variable sPo

        set sPo(Abbr,MinLength) $minChars
    }

    proc GetMinLength {} {
        variable sPo

        return [list $sPo(Abbr,MinLength)]
    }

    proc SetMaxLength { maxChars } {
        variable sPo

        set sPo(Abbr,MaxLength) $maxChars
    }

    proc GetMaxLength {} {
        variable sPo

        return [list $sPo(Abbr,MaxLength)]
    }

    proc SetShowNumbers { showNumbers } {
        variable sPo

        set sPo(Abbr,ShowNumbers) $showNumbers
    }

    proc GetShowNumbers {} {
        variable sPo

        return [list $sPo(Abbr,ShowNumbers)]
    }

    proc SetAbbrTableRow { row } {
        variable sPo

        set sPo(Abbr,TableRow) $row
    }

    proc GetAbbrTableRow {} {
        variable sPo

        return [list $sPo(Abbr,TableRow)]
    }

    proc SetAbbrTableCol { column } {
        variable sPo

        set sPo(Abbr,TableCol) $column
    }

    proc GetAbbrTableCol {} {
        variable sPo

        return [list $sPo(Abbr,TableCol)]
    }

    # Settings for link check functionality.

    proc SetShowLinkTypes { checkValidity internal file url } {
        variable sPo

        set sPo(Link,check)    $checkValidity
        set sPo(Link,internal) $internal
        set sPo(Link,file)     $file
        set sPo(Link,url)      $url
    }

    proc GetShowLinkTypes {} {
        variable sPo

        return [list \
            $sPo(Link,check)    \
            $sPo(Link,internal) \
            $sPo(Link,file)     \
            $sPo(Link,url)      \
        ]
    }

    proc CheckWordEvents { args } {
        variable sPo

        if { $args eq "DocumentChange" } {
            catch { unset sPo(docId) }
            if { ! [poApps UseBatchMode] } {
                WriteInfoStr "Word document has been closed." "Error"
            }
            poWin ToggleSwitchableWidgets "Word" false
        }
        if { $args eq "Quit" } {
            catch { unset sPo(docId) }
            catch { unset sPo(wordId) }
            WriteInfoStr "Word instance has been closed." "Error"
            poWin ToggleSwitchableWidgets "Word" false
        }
    }

    proc CheckDocAvailable {} {
        variable sPo

        if { [info exists sPo(docId)] && [Cawt IsComObject $sPo(docId)] } {
            return true
        }
        return false
    }

    proc CheckWordFileAvailable {} {
        variable sPo

        if { [CheckDocAvailable] } {
            return true
        }

        set curFile [file tail [GetCurFile]]
        set retVal [tk_messageBox \
                  -title "Confirmation" \
                  -message "No Word document available.\nReopen $curFile?" \
                  -type yesno -default yes -icon question]
        if { $retVal eq "no" } {
            WriteInfoStr "Word document or instance not available." "Error"
            return false
        } else {
            OpenWordFile [GetCurFile]
            return true
        }
    }

    proc CloseWord {} {
        variable sPo
        variable sLastRange

        StopWordCheck
        if { [info exists sPo(docId)] && [Cawt IsComObject $sPo(docId)] } {
            catch { Word Close $sPo(docId) }
            catch { Cawt Destroy $sPo(docId) }
        }
        if { [info exists sPo(wordId)] && [Cawt IsComObject $sPo(wordId)] } {
            Cawt SetEventCallback $sPo(wordId) ""
            catch { Word Quit $sPo(wordId) false }
            catch { Cawt Destroy $sPo(wordId) }
        }
        catch { unset sPo(docId) }
        catch { unset sPo(wordId) }
        catch { unset sLastRange }
        WriteInfoStr "Word instance has been closed." "Ok"
        poWin ToggleSwitchableWidgets "Word" false
    }

    proc BringToFront { docId } {
        set winHandle [$docId -with { ActiveWindow } hWnd]
        set docName [file rootname [file tail [Word GetDocumentName $docId]]]
        foreach hndl [twapi::find_windows -text "*${docName}*" -match glob] {
            # A window handle is returned as {Integer HWND}
            if { [lindex $hndl 0] == $winHandle } {
                twapi::set_foreground_window $hndl
                return
            }
        }
    }

    proc ShowDocInfo {} {
        variable sPo
        variable ns
        variable sTableIds
        variable sImageIds

        set sPo(StopWordCheck) false
        $sPo(WordNotebook) select 0

        _SetAbbrType "wordcount"
        $sPo(WordSheetTable) delete 0 end
        $sPo(WordImageTable) delete 0 end
        foreach key [array names sImageIds] {
            Cawt Destroy $sImageIds($key)
        }
        foreach key [array names sTableIds] {
            Cawt Destroy $sTableIds($key)
        }
        catch { unset sImageIds }
        catch { unset sTableIds }
        set numTables [Word GetNumTables $sPo(docId)]
        set imageList [Word GetImageList $sPo(docId)]
        set numImages [llength $imageList]

        set title [format "Document contains %d tables" $numTables]
        poWin SetScrolledTitle $sPo(WordSheetTable) $title
        set title [format "Document contains %d images" $numImages]
        poWin SetScrolledTitle $sPo(WordImageTable) $title

        BringToFront $sPo(docId)

        # Set view mode to fit one page and display first page.
        $sPo(docId) -with { ActiveWindow ActivePane View Zoom } PageFit $Word::wdPageFitFullPage
        set selectionId [$sPo(docId) -with { ActiveWindow } Selection]
        # The Goto method does not work in read-only mode.
        catch { $selectionId -callnamedargs Goto What $Word::wdGoToPage Which $Word::wdGoToAbsolute Count 1 }

        WriteInfoStr "Retrieving document information ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) [expr $numTables + $numImages]
        set count 1

        # Get all tables.
        for { set i 1 } { $i <= $numTables } { incr i } {
            set tableId [Word GetTableIdByIndex $sPo(docId) $i]
            set tableRange [$tableId Range]
            set pageNum [$tableRange Information $Word::wdActiveEndPageNumber]
            Cawt Destroy $tableRange
            set tableTitle [$tableId Title]
            if { $tableTitle eq "" } {
                set tableTitle "Table-$i"
            }
            set sTableIds($tableTitle) $tableId
            set numRows [Word GetNumRows $tableId]
            set numCols [Word GetNumColumns $tableId]
            $sPo(WordSheetTable) insert end [list "" $pageNum $tableTitle $numRows $numCols]
            if { $count % 10 == 1 } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $count
                if { $sPo(StopWordCheck) } {
                    WriteInfoStr "Information check cancelled" "Cancel"
                    poWin UpdateStatusProgress $sPo(StatusWidget) 0
                    return
                }
            }
            incr count
        }

        # Get all images.
        set i 1
        foreach imageId $imageList {
            set pageNum -1
            set imageName [Word GetImageName $imageId]
            if { $imageName eq "" } {
                set imageName "Image-$i"
            }
            set imageType [$imageId Type]
            if { [Word IsInlineShape $imageId] } {
                set typeEnumName [Word GetEnumName WdInlineShapeType $imageType]
                set imageRange [$imageId Range]
                set pageNum [$imageRange Information $Word::wdActiveEndPageNumber]
                Cawt Destroy $imageRange
            } else {
                set typeEnumName [Office GetEnumName MsoShapeType $imageType]
            }
            set sImageIds($imageName) $imageId
            $sPo(WordImageTable) insert end [list "" $pageNum $imageName $typeEnumName]
            if { $count % 10 == 1 } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $count
                if { $sPo(StopWordCheck) } {
                    WriteInfoStr "Information check cancelled" "Cancel"
                    poWin UpdateStatusProgress $sPo(StatusWidget) 0
                    return
                }
            }
            incr i
            incr count
        }

        set endRange [Word GetEndRange $sPo(docId)]
        set numPages [$endRange Information $Word::wdNumberOfPagesInDocument]
        Cawt Destroy $endRange

        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        WriteInfoStr "Document information has been retrieved." "Ok"
    }

    #
    # Procedures for handling the option rollups.
    #

    proc InitWordAbbrRollUp { fr } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Min. characters:" \
                           "Max. characters:" \
                           "Show numbers:" \
                           "Data start row:" \
                           "Data column:" } {
            ttk::label $fr.l$row -text $labelStr
            grid $fr.l$row -row $row -column 0 -sticky new
            incr row
        }

        set width 10 

        set row 0
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::spinbox $fr.fr$row.s -from -1 -to 30 -textvariable ${ns}::sPo(Abbr,MinLength) -width $width
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::spinbox $fr.fr$row.s -from -1 -to 30 -textvariable ${ns}::sPo(Abbr,MaxLength) -width $width
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $fr.fr$row.s -variable ${ns}::sPo(Abbr,ShowNumbers) \
                         -onvalue true -offvalue false -width $width
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::entry $fr.fr$row.s -textvariable ${ns}::sPo(Abbr,TableRow) -width $width
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::entry $fr.fr$row.s -textvariable ${ns}::sPo(Abbr,TableCol) -width $width
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 0 -columnspan 2 -sticky new
        ttk::button $fr.fr$row.cmd -text "Run word count" -command "${ns}::RunAbbrCheck"
        pack $fr.fr$row.cmd -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.cmd

        set sPo(AbbrButton) $fr.fr$row.cmd
    }

    proc InitWordLinkRollUp { fr } {
        variable sPo
        variable ns

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Check internal links:" \
                           "Check file links:" \
                           "Check URL links:" \
                           "Check link validity:" } {
            ttk::label $fr.l$row -text $labelStr
            grid $fr.l$row -row $row -column 0 -sticky new
            incr row
        }

        set row 0
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $fr.fr$row.s -variable ${ns}::sPo(Link,internal) \
                         -onvalue true -offvalue false
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $fr.fr$row.s -variable ${ns}::sPo(Link,file) \
                         -onvalue true -offvalue false
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $fr.fr$row.s -variable ${ns}::sPo(Link,url) \
                         -onvalue true -offvalue false
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $fr.fr$row.s -variable ${ns}::sPo(Link,check) \
                         -onvalue true -offvalue false
        pack $fr.fr$row.s -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.s

        incr row
        ttk::frame $fr.fr$row
        grid $fr.fr$row -row $row -column 0 -columnspan 2 -sticky new
        ttk::button $fr.fr$row.cmd -text "Run link check" -command "${ns}::RunLinkCheck false"
        pack $fr.fr$row.cmd -side top -fill x -expand 1
        poWin AddToSwitchableWidgets "Word" $fr.fr$row.cmd
    }

    proc StopWordCheck { { msg "Check stopped by user" } } {
        variable sPo

        WriteInfoStr $msg "Cancel"
        set sPo(StopWordCheck) true
    }

    proc CreateWordOptionRollUp { rollUpFr } {
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
                     ${ns}::ShowDocInfo "Show information about loaded file"]

        poToolbar AddGroup $toolFr
        set closeBtn [poToolbar AddButton $toolFr [::poBmpData::delete "red"] \
                     ${ns}::CloseWord "Close Word document"]

        poToolbar AddGroup $toolFr
        poToolbar AddButton $toolFr [::poBmpData::halt "red"] \
                  ${ns}::StopWordCheck "Stop check (Esc)" -state $sPo(CawtState)
        set exportBtn [poToolbar AddButton $toolFr [::poBmpData::sheetIn] \
                     ${ns}::ExportToExcel "Export results to Excel"]
        bind $sPo(tw) <Escape> ${ns}::StopWordCheck

        poWin AddToSwitchableWidgets "Word" $infoBtn $closeBtn

        set innerRollUp [poWinRollUp Create $innerFr ""]

        set abbrRollUp [poWinRollUp Add $innerRollUp "Word Count" false]
        InitWordAbbrRollUp $abbrRollUp

        set linkRollUp [poWinRollUp Add $innerRollUp "Links" false]
        InitWordLinkRollUp $linkRollUp

        poWin AddToSwitchableWidgets "Word" $abbrRollUp $linkRollUp
        set sPo(AbbrRollUp) $abbrRollUp
    }

    proc GetValidString { valid } {
        set validStr ""
        if { $valid == 1 } {
            set validStr "Yes"
        } elseif { $valid == 0 } {
            set validStr "No"
        }
        return $validStr
    }

    proc ExportToExcel {} {
        variable sPo

        set excelId [Excel OpenNew true]
        set workbookId [Excel AddWorkbook $excelId]
        set tableIds [list $sPo(WordSheetTable) $sPo(WordImageTable) $sPo(AbbrTable) $sPo(WordTable) $sPo(LinkTable)]
        set sheetNames [list "Tables" "Images" "Abbreviations" "WordCount" "Links"]
        foreach tableId $tableIds sheetName $sheetNames {
            set tableSize [$tableId size]
            if { $tableSize > 0 } {
                set worksheetId [Excel AddWorksheet $workbookId $sheetName]
                Excel TablelistToWorksheet $tableId $worksheetId
                Excel DeleteColumn $worksheetId 1
                Excel SetColumnsWidth $worksheetId 1 [Excel GetNumUsedColumns $worksheetId]
                if { $sheetName eq "Abbreviations" } {
                    for { set r 0 } { $r < $tableSize } { incr r } {
                        set color [$tableId rowcget $r -background]
                        if { $color ne "" } {
                            set rowExcel [expr { $r + 2 }]
                            set rangeId [Excel SelectRangeByIndex $worksheetId $rowExcel 1 $rowExcel 1]
                            Excel SetRangeFillColor $rangeId $color
                            Cawt Destroy $rangeId
                        }
                    }
                }
                Cawt Destroy $worksheetId
            }
        }
        Cawt Destroy $workbookId
    }

    proc Recheck { tableId rowList } {
        foreach row $rowList {
            set address [poTablelistUtil GetCellValue $tableId $row 5]
            set valid [Cawt IsValidUrlAddress $address]
            poTablelistUtil SetCellValue $tableId $row 2 [GetValidString $valid]
        }
    }

    proc OpenLinkContextMenu { tableId x y } {
        variable ns

        set w .poLinkMenu:contextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        set rowList [$tableId curselection]
        set numSel [llength $rowList]
        if { $numSel == 0 } {
            set menuTitle "Nothing selected"
        } else {
            set menuTitle "$numSel selected"
        }
        $w add command -label "$menuTitle" -state disabled -background "#303030"

        if { $numSel > 0 } {
            $w add command -label "Recheck" -command "${ns}::Recheck $tableId $rowList"
        }
        tk_popup $w $x $y
    }

    proc CreateWordTab { masterFr } {
        variable sPo
        variable ns

        set paneHori $masterFr.pane
        ttk::panedwindow $paneHori -orient horizontal
        pack $paneHori -side top -expand 1 -fill both
        SetHoriPaneWidget $paneHori "Word"

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

        set sPo(Word,embedFr) $embedFr

        # Create the rollups for the options.
        set rollUpFr [poWin CreateScrolledFrame $rollFr true ""]
        CreateWordOptionRollUp $rollUpFr

        # Create a notebook for the info, abbreviation and link frames
        # containing the result tables.
        set nb $tableFr.nb
        ttk::notebook $nb
        pack $nb -fill both -expand 1
        ttk::notebook::enableTraversal $nb
        set sPo(WordNotebook) $nb

        # Create the contents of the Info tab.
        set infoFr $nb.infofr
        ttk::frame $infoFr
        $nb add $infoFr -text "Information" -underline 0 -padding 2

        set paneVert $infoFr.pane
        ttk::panedwindow $paneVert -orient vertical
        pack $paneVert -side top -expand 1 -fill both
        SetVertPaneWidget $paneVert "Word"

        set sheetTableFr $paneVert.sheettablefr
        set imageTableFr $paneVert.imagetablefr
        ttk::frame $sheetTableFr
        ttk::frame $imageTableFr

        $paneVert add $sheetTableFr
        $paneVert add $imageTableFr

        set sPo(WordSheetTable) [poWin CreateScrolledTablelist $sheetTableFr true "List of tables" \
            -columns [list 4 "#"           "right" \
                           5 "Page"        "right" \
                           0 "Table name"  "left" \
                           0 "Rows"        "right" \
                           0 "Columns"     "right"] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 2 \
            -showseparators 1]
        $sPo(WordSheetTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(WordSheetTable) columnconfigure 1 -sortmode integer
        $sPo(WordSheetTable) columnconfigure 2 -sortmode dictionary
        $sPo(WordSheetTable) columnconfigure 3 -sortmode integer
        $sPo(WordSheetTable) columnconfigure 4 -sortmode integer
        bind $sPo(WordSheetTable) <<TablelistSelect>> "${ns}::ShowTableInDoc $sPo(WordSheetTable)"

        set sPo(WordImageTable) [poWin CreateScrolledTablelist $imageTableFr true "List of images" \
            -columns [list 4 "#"            "right"  \
                           5 "Page"         "right" \
                           0 "Image name"   "left"   \
                           0 "Image type"   "left" ] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 2 \
            -showseparators 1]
        $sPo(WordImageTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(WordImageTable) columnconfigure 1 -sortmode integer
        $sPo(WordImageTable) columnconfigure 2 -sortmode dictionary
        $sPo(WordImageTable) columnconfigure 3 -sortmode dictionary
        bind $sPo(WordImageTable) <<TablelistSelect>> "${ns}::ShowImgInDoc $sPo(WordImageTable)"

        # Create the contents of the Abbreviations tab.
        set abbrFr $nb.abbrfr
        ttk::frame $abbrFr
        $nb add $abbrFr -text "Abbreviations" -underline 0 -padding 2
        
        set paneVert $abbrFr.pane
        ttk::panedwindow $paneVert -orient vertical
        pack $paneVert -side top -expand 1 -fill both

        set abbrTableFr $abbrFr.abbrtablefr
        set wordTableFr $abbrFr.wordtablefr
        ttk::frame $abbrTableFr
        ttk::frame $wordTableFr

        $paneVert add $abbrTableFr
        $paneVert add $wordTableFr

        set sPo(AbbrTable) [poWin CreateScrolledTablelist $abbrTableFr true "Abbreviations" \
            -columns [list 4 "#"            "right"  \
                           0 "Abbreviation" "left" ] \
            -height 10 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        SetAbbrTableMsg
        $sPo(AbbrTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(AbbrTable) columnconfigure 1 -sortmode dictionary
        set bodyTag [$sPo(AbbrTable) bodytag]
        bind $sPo(AbbrTable) <<TablelistSelect>> \
             "${ns}::ShowWordInDoc $sPo(AbbrTable) ; ${ns}::ShowAbbrInWordTable"
        bind $bodyTag <Key-F3> "${ns}::ShowWordInDoc $sPo(AbbrTable) false"

        set sPo(WordTable) [poWin CreateScrolledTablelist $wordTableFr true "Word count" \
            -columns [list 4 "#"       "right"   \
                           0 "Word"    "left"    \
                           0 "Count"   "right"   \
                           0 "Length"  "right" ] \
            -height 20 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        SetWordTableMsg
        $sPo(WordTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(WordTable) columnconfigure 1 -sortmode dictionary
        $sPo(WordTable) columnconfigure 2 -sortmode integer
        $sPo(WordTable) columnconfigure 3 -sortmode integer
        set bodyTag [$sPo(WordTable) bodytag]
        bind $sPo(WordTable) <<TablelistSelect>> "${ns}::ShowWordInDoc $sPo(WordTable)"
        bind $bodyTag <Key-F3>                   "${ns}::ShowWordInDoc $sPo(WordTable) false"

        # Create the contents of the Links tab.
        set linkFr $nb.linkfr
        ttk::frame $linkFr
        $nb add $linkFr -text "Links" -underline 0 -padding 2

        # # text address type
        set sPo(LinkTable) [poWin CreateScrolledTablelist $linkFr true "Links" \
            -columns [list 4 "#"       "right"  \
                           5 "Page"    "right" \
                           0 "Valid"   "right"  \
                           0 "Type"    "left"   \
                           0 "Text"    "left"   \
                           0 "Address" "left"]  \
            -height 20 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 3 \
            -showseparators 1]
        SetLinkTableMsg
        $sPo(LinkTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(LinkTable) columnconfigure 1 -sortmode integer
        $sPo(LinkTable) columnconfigure 2 -sortmode dictionary
        $sPo(LinkTable) columnconfigure 3 -sortmode dictionary
        $sPo(LinkTable) columnconfigure 4 -sortmode dictionary
        $sPo(LinkTable) columnconfigure 5 -sortmode dictionary
        set bodyTag [$sPo(LinkTable) bodytag]
        bind $sPo(LinkTable) <<TablelistSelect>> "${ns}::ShowLinkInDoc $sPo(LinkTable)"
        bind $bodyTag <Key-F3>                   "${ns}::ShowLinkInDoc $sPo(LinkTable) false"
        bind $bodyTag <<RightButtonPress>>       "${ns}::OpenLinkContextMenu $sPo(LinkTable) %X %Y"

        poWin ToggleSwitchableWidgets "Word" false
        set sPo(Abbr,TableName) ""
    }

    proc SetAbbrTableMsg { { numEntries 0 } { numUnusedEntries 0 } } {
        variable sPo

        set titleMsg "Abbreviation table"
        if { $numEntries > 0 } {
            set titleMsg [format "%d abbreviations in table %s" \
                         $numEntries $sPo(Abbr,TableName)]

            if { $numUnusedEntries > 0 } {
                append titleMsg [format " %d unused." $numUnusedEntries]
            }
        }
        poWin SetScrolledTitle $sPo(AbbrTable) $titleMsg
    }

    proc SetWordTableMsg { { numEntries 0 } } {
        variable sPo

        set titleMsg "Word count table"
        if { $numEntries > 0 } {
            set titleMsg [format "%d words in document" $numEntries]
        }
        poWin SetScrolledTitle $sPo(WordTable) $titleMsg
    }

    proc SetLinkTableMsg { { numEntries 0 } { numInvalidEntries 0 } } {
        variable sPo

        set titleMsg "Link table"
        if { $numEntries > 0 } {
            set titleMsg [format "%d links in document." $numEntries]
            if { $numInvalidEntries > 0 } {
                append titleMsg [format " %d invalid." $numInvalidEntries]
            }
        }
        poWin SetScrolledTitle $sPo(LinkTable) $titleMsg
    }


    proc RunAbbrCheck { { tableName "" } } {
        variable sPo
        variable sTableIds

        if { ! [CheckDocAvailable] } {
            return
        }

        set sPo(StopWordCheck) false
        poWin ToggleSwitchableWidgets "Word" false

        $sPo(WordTable) delete 0 end
        $sPo(AbbrTable) delete 0 end
        $sPo(WordNotebook) select 1

        SetAbbrTableMsg
        SetWordTableMsg
        WriteInfoStr "Counting words in file \"[file tail [GetCurFile]]\" ..." "Watch"

        set rangeId [Word GetStartRange $sPo(docId)]
        Word SetRangeStartIndex $rangeId "begin"
        Word SetRangeEndIndex   $rangeId "end"
        set docText [$rangeId Text]
        Cawt Destroy $rangeId

        poWin InitStatusProgress $sPo(StatusWidget) [string length $docText]

        coroutine CountWords Cawt::CountWords $docText \
                       -sortmode   "length" \
                       -minlength  $sPo(Abbr,MinLength) \
                       -maxlength  $sPo(Abbr,MaxLength) \
                       -shownumbers $sPo(Abbr,ShowNumbers)

        while { 1 } {
            set wordCountList [CountWords]
            if { [string is integer -strict $wordCountList] } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $wordCountList
            } else {
                break
            }
            if { $sPo(StopWordCheck) } {
                WriteInfoStr "Abbreviation check cancelled" "Cancel"
                poWin UpdateStatusProgress $sPo(StatusWidget) 0
                poWin ToggleSwitchableWidgets "Word" true
                return
            }
        }

        foreach { word count } $wordCountList {
            $sPo(WordTable) insert end [list "" $word $count [string length $word]]
        }
        SetWordTableMsg [expr {[llength $wordCountList] / 2}]
        WriteInfoStr "Word count finished." "OK"

        set unusedAbbr 0
        if { $tableName eq "" } {
            set tableName $sPo(Abbr,TableName)
        } else {
            set sPo(Abbr,TableName) $tableName
            set row [$sPo(WordSheetTable) searchcolumn 2 $tableName -exact]
            if { $row >= 0 } {
                $sPo(WordSheetTable) selection set $row $row
                ShowTableInDoc $sPo(WordSheetTable)
            }
        }
        if { $tableName ne "" } {
            set sPo(abbrList) [list]
            if { [info exists sTableIds] } {
                if { [info exists sTableIds($tableName)] } {
                    set tableId $sTableIds($tableName)
                    set sPo(abbrList) [Word GetColumnValues $tableId $sPo(Abbr,TableCol) $sPo(Abbr,TableRow)]
                }
            }
            if { [llength $sPo(abbrList)] > 0 } {
                WriteInfoStr "Scanning abbreviation table \"$tableName\" ..." "Watch"
                foreach abbr $sPo(abbrList) {
                    set abbrHash($abbr) 0
                }
                foreach { word count } $wordCountList {
                    if { [info exists abbrHash($word)] } {
                        incr abbrHash($word)
                    }
                }
                foreach abbr [lsort -dictionary [array names abbrHash]] {
                    $sPo(AbbrTable) insert end [list "" $abbr]
                    if { $abbrHash($abbr) == 0  || [dict get $wordCountList $abbr] == 1 } {
                        $sPo(AbbrTable) rowconfigure end -background red
                        incr unusedAbbr
                    }
                }
                SetAbbrTableMsg [llength [array names abbrHash]] $unusedAbbr
            }
            WriteInfoStr "Abbreviation check finished." "OK"
            if { [llength $sPo(abbrList)] == 0 } {
                WriteInfoStr "Abbreviation table \"$tableName\" not found." "Error"
            }
        }

        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        poWin ToggleSwitchableWidgets "Word" true

        poApps ShowSysNotify "poOffice message" "Word count finished" $sPo(tw)

        return $unusedAbbr
    }

    proc RunLinkCheck { fullBatch } {
        variable sPo

        if { ! [CheckDocAvailable] } {
            return
        }

        set sPo(StopWordCheck) false
        $sPo(WordNotebook) select 2

        set optStr ""
        if { $sPo(Link,internal) } {
            append optStr " -type internal"
        }
        if { $sPo(Link,file) } {
            append optStr " -type file"
        }
        if { $sPo(Link,url) } {
            append optStr " -type url"
        }
        if { $optStr eq "" } {
            WriteInfoStr "No link type selected." "Warning"
            return
        }
        if { $sPo(Link,check) } {
            append optStr " -check true"
        }

        poWin ToggleSwitchableWidgets "Word" false

        $sPo(LinkTable) delete 0 end
        SetLinkTableMsg
        WriteInfoStr "Checking links in file \"[file tail [GetCurFile]]\" ..." "Watch"

        set numLinks [Word GetNumHyperlinks $sPo(docId)]
        poWin InitStatusProgress $sPo(StatusWidget) $numLinks
        coroutine GetHyperlinks ::Word::GetHyperlinksAsDict $sPo(docId) {*}$optStr

        while { 1 } {
            set hyperlinkDict [GetHyperlinks]
            if { [string is integer -strict $hyperlinkDict] } {
                poWin UpdateStatusProgress $sPo(StatusWidget) $hyperlinkDict
            } else {
                break
            }
            if { $sPo(StopWordCheck) } {
                WriteInfoStr "Link check cancelled" "Cancel"
                poWin UpdateStatusProgress $sPo(StatusWidget) 0
                poWin ToggleSwitchableWidgets "Word" true
                return
            }
        }

        poWin InitStatusProgress $sPo(StatusWidget) $numLinks
        WriteInfoStr "Updating page numbers of links ..." "Watch"

        set numInvalid 0
        set linkNum    0
        dict for { id info } $hyperlinkDict {
            dict with info {
                set validStr [GetValidString $valid]
                if { $valid == 0 } {
                    incr numInvalid
                }
                if { $fullBatch } {
                    continue
                }
                set linkRange [Word CreateRange $sPo(docId) $start $end]
                set pageNum [$linkRange Information $Word::wdActiveEndPageNumber]
                Cawt Destroy $linkRange
                set addr $address
                if { $type eq "url" && $subaddress ne "" } {
                    append addr "#$subaddress"
                }
                $sPo(LinkTable) insert end [list "" $pageNum $validStr $type $text $addr]
                $sPo(LinkTable) rowattrib end start $start end $end
                if { $valid == 0 } {
                    $sPo(LinkTable) rowconfigure end -background red
                }
                incr linkNum
                if { $linkNum % 50 == 0 } {
                    poWin UpdateStatusProgress $sPo(StatusWidget) $linkNum
                }
            }
        }
        SetLinkTableMsg [dict size $hyperlinkDict] $numInvalid

        WriteInfoStr "Link check finished." "OK"
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        poWin ToggleSwitchableWidgets "Word" true

        poApps ShowSysNotify "poOffice message" "Link check finished" $sPo(tw)

        return $numInvalid
    }

    proc _SetAbbrType { type } {
        variable sPo

        if { $type eq "wordcount" } {
            poWinRollUp SetTitle $sPo(AbbrRollUp) "Word Count"
            $sPo(AbbrButton) configure -text "Run word count"
        } else {
            poWinRollUp SetTitle $sPo(AbbrRollUp) "Abbreviations"
            $sPo(AbbrButton) configure -text "Run abbreviation check"
        }
    }

    proc ShowTableInDoc { tableId } {
        variable sPo
        variable sTableIds

        if { ! [CheckDocAvailable] } {
            return
        }
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            _SetAbbrType "wordcount"
            return
        }
        _SetAbbrType "abbr"

        set col 2
        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set wordTableTitle [$tableId cellcget "$row,$col" -text]

        set wordTableId $sTableIds($wordTableTitle)
        $wordTableId Select
        set sPo(Abbr,TableName) $wordTableTitle
        BringToFront $sPo(docId)
        focus $tableId
    }

    proc ShowImgInDoc { tableId } {
        variable sPo
        variable sImageIds

        if { ! [CheckDocAvailable] } {
            return
        }
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        set col 2
        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set imageName [$tableId cellcget "$row,$col" -text]

        set imageId $sImageIds($imageName)
        $imageId Select
    }

    proc ShowAbbrInWordTable {} {
        variable sPo

        set abbrTable $sPo(AbbrTable)
        set wordTable $sPo(WordTable)

        if { ! [poTablelistUtil IsRowSelected $abbrTable] } {
            return
        }
        set col 1
        set row [poTablelistUtil GetFirstSelectedRow $abbrTable]
        set abbr [$abbrTable cellcget "$row,$col" -text]
        set row [$wordTable searchcolumn 1 $abbr -exact]
        if { $row >= 0 } {
            $wordTable selection set $row $row
            $wordTable see $row
        }
    }

    proc ShowWordInDoc { tableId { startSearch true } } {
        variable sPo
        variable sLastRange

        if { ! [CheckDocAvailable] } {
            return
        }
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        set col 1
        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set abbr [$tableId cellcget "$row,$col" -text]

        if { $startSearch } {
            WriteInfoStr "Searching occurences of \"$abbr\" in document." "OK"
            if { [info exists sPo(SearchRange)] } {
                Cawt Destroy $sPo(SearchRange)
            }
            if { [info exists sPo(MyFind)] } {
                Cawt Destroy $sPo(MyFind)
            }
            set sPo(SearchRange) [$sPo(docId) Content]
            set sPo(MyFind) [$sPo(SearchRange) Find]
            $sPo(MyFind) ClearFormatting
        }
        set foundWord [$sPo(MyFind) -callnamedargs Execute \
                       FindText $abbr \
                       MatchWholeWord True \
                       MatchCase True \
                       Forward True]
        if { $foundWord } {
            if { [info exists sLastRange] } {
                set lastRange [Word CreateRange $sPo(docId) $sLastRange(Start) $sLastRange(End)]
                Word SetRangeHighlightColorByEnum $lastRange wdNoHighlight
                Cawt Destroy $lastRange
            }
            Word SelectRange $sPo(SearchRange)
            Word SetRangeHighlightColorByEnum $sPo(SearchRange) wdYellow
            set sLastRange(Start) [$sPo(SearchRange) Start]
            set sLastRange(End)   [$sPo(SearchRange) End]
        } else {
            WriteInfoStr "No more occurences of \"$abbr\" in document." "Warning"
        }
    }

    proc ShowLinkInDoc { tableId { startSearch true } } {
        variable sPo
        variable sLastRange

        if { ! [CheckDocAvailable] } {
            return
        }
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }
        set row [poTablelistUtil GetFirstSelectedRow $tableId]

        set startIndex [$tableId rowattrib $row "start"]
        set endIndex   [$tableId rowattrib $row "end"]
        set linkRange [Word CreateRange $sPo(docId) $startIndex $endIndex]

        if { [info exists sLastRange] } {
            set lastRange [Word CreateRange $sPo(docId) $sLastRange(Start) $sLastRange(End)]
            Word SetRangeHighlightColorByEnum $lastRange wdNoHighlight
            Cawt Destroy $lastRange
        }
        Word SelectRange $linkRange
        Word SetRangeHighlightColorByEnum $linkRange wdYellow
        Cawt Destroy $linkRange
        set sLastRange(Start) $startIndex
        set sLastRange(End)   $endIndex
    }

    proc OpenWordFile { fileName } {
        variable ns
        variable sPo

        CloseWord

        SelectNotebookTab "Word"

        WriteInfoStr "Loading Word file \"$fileName\" ..." "Watch"

        set nativeName [file nativename [file normalize $fileName]]

        $sPo(AbbrTable) delete 0 end
        $sPo(WordTable) delete 0 end
        $sPo(LinkTable) delete 0 end
        $sPo(WordSheetTable) delete 0 end
        $sPo(WordImageTable) delete 0 end

        poWinSelect SetValue $sPo(fileCombo) $fileName
        SetCurFile $fileName
        SetCurDirectory [file dirname $fileName]
        poAppearance AddToRecentFileList $fileName
        UpdateMainTitle [file tail $fileName]

        set wordId [Word OpenNew [GetVisibleMode]]
        set embedArg ""
        if { [GetEmbeddedMode] } {
            set embedArg "-embed $sPo(Word,embedFr)"
        }
        set docId [Word OpenDocument $wordId $nativeName \
                  -readonly [GetReadOnlyMode] {*}$embedArg]
        set sPo(wordId) $wordId
        set sPo(docId)  $docId

        ShowDocInfo

        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        WriteInfoStr "Word file \"$fileName\" loaded." "Ok"
        Cawt SetEventCallback $sPo(wordId) ${ns}::CheckWordEvents
        poWin ToggleSwitchableWidgets "Word" true
    }

    proc BatchWord { fullBatch fileName optionDict } {
        set numFailed 0

        poWatch Start officeBatchTimer
        set tableName [dict get $optionDict "checkabbr"]
        if { $tableName ne "" } {
            if { [poApps GetVerbose] } {
                puts -nonewline "Checking abbreviations ... " ; flush stdout
            }
            set numUnused [RunAbbrCheck $tableName]
            if { [poApps GetVerbose] } {
                puts [format "%3d unused.  (Time: %.2f seconds)" $numUnused [poWatch Lookup officeBatchTimer]]
            }
            incr numFailed $numUnused
        }

        poWatch Reset officeBatchTimer
        set checkLinks [dict get $optionDict "checklink"]
        if { $checkLinks } {
            if { [poApps GetVerbose] } {
                puts -nonewline "Checking links         ... " ; flush stdout
            }
            set numInvalid [RunLinkCheck true]
            if { [poApps GetVerbose] } {
                puts [format "%3d invalid. (Time: %.2f seconds)" $numInvalid [poWatch Lookup officeBatchTimer]]
            }
            incr numFailed $numInvalid
        }

        if { $fullBatch } {
            CloseWord
        }

        return $numFailed
    }
}
