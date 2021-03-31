# Module:         poOffice
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office programs.

namespace eval poOffice {
    variable ns [namespace current]

    set sPo(FileType,Word) {
        {"Word files" ".doc .docx"}
        {"All files" "*"}
    }

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

    proc SetAbbrTableName { tableName } {
        variable sPo

        set sPo(Abbr,TableName) $tableName
    }

    proc GetAbbrTableName {} {
        variable sPo

        return [list $sPo(Abbr,TableName)]
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

    proc DeleteAbbreviationFrame {} {
        variable sPo

        set masterFr $sPo(workFr).fr
        if { [winfo exists $masterFr] } {
            destroy $masterFr
        }
        poWin RemoveSwitchableWidgets "AbbrFrames"

        if { [info exists sPo(docId)] && [Cawt IsComObject $sPo(docId)] } {
            catch { Word Close $sPo(docId) }
        }
        if { [info exists sPo(wordId)] && [Cawt IsComObject $sPo(wordId)] } {
            catch { Word Quit $sPo(wordId) false }
        }
        catch { unset sPo(docId) }
        catch { unset sPo(wordId) }
    }

    proc CreateAbbreviationFrame {} {
        variable sPo
        variable ns

        set masterFr $sPo(workFr).fr
        if { [winfo exists $masterFr] } {
            return $masterFr
        }

        ttk::frame $masterFr
        pack $masterFr -side top -expand 1 -fill both

        set btnFr  $masterFr.btnfr
        set optFr  $masterFr.optfr
        set abbrFr $masterFr.abbrfr
        set wordFr $masterFr.wordfr

        ttk::frame $btnFr
        ttk::frame $optFr
        ttk::frame $abbrFr
        ttk::frame $wordFr

        grid $btnFr  -row 0 -column 0 -sticky news -columnspan 2
        grid $optFr  -row 1 -column 0 -sticky news
        grid $abbrFr -row 1 -column 1 -sticky news
        grid $wordFr -row 2 -column 0 -sticky news -columnspan 2
        grid rowconfigure    $masterFr 2 -weight 1
        grid columnconfigure $masterFr 1 -weight 1

        # Generate left column with text labels.
        set row 0
        foreach labelStr { "Min. characters:" \
                           "Max. characters:" \
                           "Show numbers:" \
                           "Abbreviation table:" \
                           "Data start row:" \
                           "Data column:" } {
            ttk::label $optFr.l$row -text $labelStr
            grid $optFr.l$row -row $row -column 0 -sticky new
            incr row
        }

        set row 0
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        ttk::spinbox $optFr.fr$row.s -from -1 -to 30 -textvariable ${ns}::sPo(Abbr,MinLength)
        pack $optFr.fr$row.s -side top -fill x -expand 1

        incr row
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        ttk::spinbox $optFr.fr$row.s -from -1 -to 30 -textvariable ${ns}::sPo(Abbr,MaxLength)
        pack $optFr.fr$row.s -side top -fill x -expand 1

        incr row
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        ttk::checkbutton $optFr.fr$row.s -variable ${ns}::sPo(Abbr,ShowNumbers) -onvalue true -offvalue false
        pack $optFr.fr$row.s -side top -fill x -expand 1

        incr row
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        set sPo(TableCombo) $optFr.fr$row.s
        ttk::combobox $sPo(TableCombo) -state readonly
        bind $sPo(TableCombo) <<ComboboxSelected>> "${ns}::ShowTableInWord %W"
        pack $optFr.fr$row.s -side top -fill x -expand 1

        incr row
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        ttk::entry $optFr.fr$row.s -textvariable ${ns}::sPo(Abbr,TableRow)
        pack $optFr.fr$row.s -side top -fill x -expand 1

        incr row
        ttk::frame $optFr.fr$row
        grid $optFr.fr$row -row $row -column 1 -sticky new
        ttk::entry $optFr.fr$row.s -textvariable ${ns}::sPo(Abbr,TableCol)
        pack $optFr.fr$row.s -side top -fill x -expand 1

        set sPo(AbbrTable) [poWin CreateScrolledTablelist $abbrFr true "Abbreviations listed in Word table" \
            -columns [list 4 "#"            "right"  \
                           0 "Abbreviation" "left" ] \
            -height 6 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(AbbrTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(AbbrTable) columnconfigure 1 -sortmode dictionary
        bind $sPo(AbbrTable) <<TablelistSelect>> "${ns}::ShowAbbrInWord $sPo(AbbrTable)"

        set sPo(WordTable) [poWin CreateScrolledTablelist $wordFr true "Words in document" \
            -columns [list 4 "#"       "right"   \
                           0 "Word"    "left"    \
                           0 "Count"   "right"   \
                           0 "Length"  "right" ] \
            -height 15 \
            -labelcommand tablelist::sortByColumn \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch 1 \
            -showseparators 1]
        $sPo(WordTable) columnconfigure 0 -editable false -showlinenumbers true
        $sPo(WordTable) columnconfigure 1 -sortmode dictionary
        $sPo(WordTable) columnconfigure 2 -sortmode integer
        $sPo(WordTable) columnconfigure 3 -sortmode integer
        set bodyTag [$sPo(WordTable) bodytag]
        bind $sPo(WordTable) <<TablelistSelect>> "${ns}::ShowAbbrInWord $sPo(WordTable)"
        bind $bodyTag <Key-F3>                   "${ns}::ShowAbbrInWord $sPo(WordTable) false"

        poToolbar New $btnFr
        poToolbar AddGroup $btnFr

        poWin AddToSwitchableWidgets "AbbrFrames" $btnFr $optFr $abbrFr $wordFr

        return $masterFr
    }

    proc ShowTableInWord { comboId } {
        variable sPo
        variable sTableIndices

        if { [info exists sPo(docId)] && ! [Cawt IsComObject $sPo(docId)] } {
            WriteInfoStr "No Word document open" "Error"
            return
        }
        set tableTitle [$comboId get]
        set tableId [Word GetTableIdByIndex $sPo(docId) $sTableIndices($tableTitle)]
        $tableId Select
        set sPo(Abbr,TableName) $tableTitle
    }

    proc ShowAbbrInWord { tableId { startSearch true } } {
        variable sPo

        if { [info exists sPo(docId)] && ! [Cawt IsComObject $sPo(docId)] } {
            WriteInfoStr "No Word document open" "Error"
            return
        }
        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }

        set col 1
        set row [poTablelistUtil GetFirstSelectedRow $tableId]
        set abbr [$tableId cellcget "$row,$col" -text]

        if { $startSearch } {
            set sPo(SearchRange) [$sPo(docId) Content]
        } else {
            Word SetRangeStartIndex $sPo(SearchRange) [Word GetRangeEndIndex $sPo(SearchRange)]
            Word SetRangeEndIndex   $sPo(SearchRange) "end"
        }
        set numFound [Word Search $sPo(SearchRange) $abbr -matchcase true -matchwholeword true -forward true] 
        if { $numFound > 0 } {
            WriteInfoStr "$abbr found $numFound times" "Ok"
            Word SelectRange $sPo(SearchRange)
            Word SetRangeHighlightColorByEnum $sPo(SearchRange) wdYellow
        } else {
            WriteInfoStr "\"$abbr\" not found in Word-Document" "Warning"
        }
    }

    proc GetWordFileName { title useLastDir { fileName "" } } {
        variable sPo
     
        if { $useLastDir } {
            set initDir [GetCurDirectory]
        } else {
            set initDir [pwd]
        }
        set fileName [tk_getOpenFile -filetypes $sPo(FileType,Word) \
                      -initialdir $initDir -title $title]
        if { $fileName ne "" && $useLastDir } {
            SetCurDirectory [file dirname $fileName]
        }
        return $fileName
    }

    proc AskOpenWordFile { { useLastDir true } } {
        variable sPo
     
        set fileName [GetWordFileName "Open file" $useLastDir [GetCurFile]]
        if { $fileName ne "" } {
            CloseSubWindows
            OpenWordFile $fileName
        }
    }

    proc OpenWordFile { fileName } {
        variable sPo
        variable sTableIndices

        if { $sPo(curFrame) ne "" } {
            destroy $sPo(curFrame)
        }
        set sPo(curFrame) [CreateAbbreviationFrame]
        poWin ToggleSwitchableWidgets "AbbrFrames" false

        set nativeName [file nativename [file normalize $fileName]]

        $sPo(AbbrTable) delete 0 end
        $sPo(WordTable) delete 0 end
        WriteInfoStr "Counting words in file [file tail $fileName] ..." "Watch"
        poWin InitStatusProgress $sPo(StatusWidget) 100

        set wordId [Word Open true]
        set docId  [Word OpenDocument $wordId $nativeName true]
        set sPo(wordId) $wordId
        set sPo(docId)  $docId

        set rangeId [Word GetStartRange $docId]
        Word SetRangeStartIndex $rangeId "begin"
        Word SetRangeEndIndex   $rangeId "end"
        set docText [$rangeId Text]
        Cawt Destroy $rangeId

        coroutine CountWords Cawt::CountWords $docText \
                       -sortmode   "length" \
                       -minlength  $sPo(Abbr,MinLength) \
                       -maxlength  $sPo(Abbr,MaxLength) \
                       -shownumbers $sPo(Abbr,ShowNumbers)

        while { 1 } {
            set wordCountList [CountWords]
            if { [string is integer -strict $wordCountList] } {
                set percent [expr int (100.0 * double ($wordCountList) / [string length $docText])]
                poWin UpdateStatusProgress $sPo(StatusWidget) $percent
            } else {
                break
            }
        }

        foreach { word count } $wordCountList {
            $sPo(WordTable) insert end [list "" $word $count [string length $word]]
        }

        # Look for abbreviation table.
        set abbrList  [list]
        catch { unset sTableIndices }
        set numTables [Word GetNumTables $docId]
        for { set i 1 } { $i <= $numTables } { incr i } {
            set tableId [Word GetTableIdByIndex $docId $i]
            set tableTitle [$tableId Title]
            if { $sPo(Abbr,TableName) ne "" && $tableTitle eq $sPo(Abbr,TableName) } {
                set abbrList [Word GetColumnValues $tableId $sPo(Abbr,TableCol) $sPo(Abbr,TableRow)]
            }
            if { $tableTitle eq "" } {
                set tableTitle "Table-$i"
            }
            set sTableIndices($tableTitle) $i
        }
        set tableTitles [lsort -dictionary [array names sTableIndices]]
        $sPo(TableCombo) configure -values $tableTitles
        set ind [lsearch -exact $tableTitles $sPo(Abbr,TableName)]
        if { $ind >= 0 } {
            $sPo(TableCombo) current $ind
            ShowTableInWord $sPo(TableCombo)
        }

        if { $sPo(Abbr,TableName) ne "" } {
            if { [llength $abbrList] > 0 } {
                WriteInfoStr "Scanning abbreviation table $sPo(Abbr,TableName) ..." "Watch"
                foreach abbr $abbrList {
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
                    }
                }
            }
        }

        poWinSelect SetValue $sPo(fileCombo) $fileName
        SetCurFile $fileName
        SetCurDirectory [file dirname $fileName]
        poAppearance AddToRecentFileList $fileName
        UpdateMainTitle [file tail $fileName]
        WriteInfoStr "Parsed Word file $fileName" "Ok"
        if { [llength $abbrList] == 0 } {
            WriteInfoStr "Abbreviation table $sPo(Abbr,TableName) not found." "Error"
        }
        poWin UpdateStatusProgress $sPo(StatusWidget) 0
        poWin ToggleSwitchableWidgets "AbbrFrames" true
    }
}

catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
