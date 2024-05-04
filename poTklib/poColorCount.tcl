# Module:         poColorCount
# Copyright:      Paul Obermeier 2014-2023 / paul@poSoft.de
# First Version:  2014 / 11 / 30
#
# Distributed under BSD license.
#
# Module for handling windows for color counting.

namespace eval poColorCount {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export GetMarkColor SetMarkColor
    namespace export ShowWin CloseWin CloseAllWin

    proc Init {} {
        variable ns
        variable sPo

        set sPo(winNum) 0
        set sPo(lastDir) [pwd]
        SetMarkColor "magenta"
    }

    proc GetMarkColor {} {
        variable sPo

        return $sPo(markColor)
    }

    proc SetMarkColor { markColor } {
        variable sPo

        set sPo(markColor) $markColor
    }

    proc AskMarkColor { labelId } {
        set newColor [tk_chooseColor -initialcolor [GetMarkColor]]
        if { $newColor ne "" } {
            SetMarkColor $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
        }
    }

    proc ShowMarkColor { winNum tableId phImg } {
        variable sPo

        if { ! [namespace exists ::poImgview] } {
            return
        }

        if { ! [poImgMisc IsPhoto $phImg] } {
            tk_messageBox -title "Error" -icon error \
                          -message "Image not available anymore. Close ColorCount window."
            return
        }

        set indList [$tableId curselection]
        if { [llength $indList] == 0 } {
            return
        }
        set ind [lindex $indList 0]
        set entry [$tableId get $ind]
        set r [lindex $entry 1]
        set g [lindex $entry 2]
        set b [lindex $entry 3]
        set markImg [poPhotoUtil MarkColors $phImg $r $g $b [GetMarkColor]]
        if { [info exists sPo($winNum,markImg)] } {
            # Delete previous mark image.
            set markImgNum [poImgview GetImgNumByPhoto $sPo($winNum,markImg)]
            if { $markImgNum >= 0 } {
                poImgview DelImg $sPo($winNum,markImg) false
            }
            unset sPo($winNum,markImg)
        }
        poImgview AddImg $markImg "" "MarkColor"
        set sPo($winNum,markImg) $markImg
    }

    proc CloseWin { winNum } {
        variable sPo

        if { ! [info exists sPo($winNum,toplevel)] } {
            # Already destroyed internally
            return
        }
        if { $sPo($winNum,toplevel) ne "" } {
            catch { destroy $sPo($winNum,toplevel) }
            unset sPo($winNum,toplevel)
        }
        catch { unset sPo($winNum,markImg) }
    }

    proc CloseAllWin { { groupName "" } } {
        variable sPo

        foreach key [array names sPo "*,toplevel"] {
            if { $sPo($key) ne "" } {
                # Only close toplevel windows, no embedded frames.
                set winNum [lindex [split $key ","] 0]
                if { $groupName eq "" || $sPo($winNum,groupName) eq $groupName } {
                    CloseWin $winNum
                }
            }
        }
    }

    proc ShowWin { fr imgList descrList { groupName "" } } {
        variable sPo
        variable ns

        set winNum $sPo(winNum)
        incr sPo(winNum)

        if { [winfo exists $fr] && [string match -nocase "*frame" [winfo class $fr]] } {
            set tw $fr
            set sPo($winNum,toplevel) ""
        } else {
            set tw .poColorCount_win_$winNum
            if { [winfo exists $tw] } {
                destroy $tw
            }
            toplevel $tw
            wm title $tw $fr
            focus $tw
            set sPo($winNum,toplevel) $tw
        }
        set sPo($winNum,tw) $tw
        set sPo($winNum,groupName) $groupName

        ttk::frame $tw.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.workfr
        pack $tw.toolfr -side top -fill x -anchor w
        pack $tw.workfr -side top -fill both -expand 1

        set tableFr $tw.workfr.tfr
        ttk::frame $tableFr
        pack $tableFr  -side left -fill both -expand true

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::save] \
                  "${ns}::AskSaveColorCountValues $winNum" "Save color count table to CSV file"
        if { [poMisc HavePkg "cawt"] } {
            poToolbar AddButton $toolfr [::poBmpData::sheetIn] \
                      "${ns}::ColorCountValuesToExcel $winNum" "Load color count table to Excel"
        }

        set fr [poToolbar AddGroup $toolfr]

        label $fr.lMarkColor -width 5 -relief sunken -background [GetMarkColor]
        ttk::button $fr.bMarkColor -text "Select ..." -command "${ns}::AskMarkColor $fr.lMarkColor"
        poToolhelp AddBinding $fr.bMarkColor "Select new mark color"
        pack {*}[winfo children $fr] -side left

        # Column-#:   0           1           2           3           4
        set columnStr "0 # right  0 R center  0 G center  0 B center  0 Count right"
        if { [poImgAppearance GetShowColorCountColumn] } {
            # Column-#:        5
            append columnStr " 0 Color center"
        }
        foreach phImg $imgList descr $descrList {
            set tableId [poWin CreateScrolledTablelist $tableFr true "$descr" \
                    -columns $columnStr \
                    -exportselection false \
                    -stretch all \
                    -width 40 \
                    -selectmode browse \
                    -stripebackground [poAppearance GetStripeColor] \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators true]
            $tableId columnconfigure 0 -showlinenumbers true
            $tableId columnconfigure 0 -sortmode integer
            $tableId columnconfigure 1 -sortmode integer
            $tableId columnconfigure 2 -sortmode integer
            $tableId columnconfigure 3 -sortmode integer
            $tableId columnconfigure 4 -sortmode integer
            bind $tableId <<ListboxSelect>> "${ns}::ShowMarkColor $winNum %W $phImg"
            lappend sPo($winNum,tables)    $tableId
            lappend sPo($winNum,fileNames) $descr

            poPhotoUtil CountColors $phImg pixelArray

            set numColors [array size pixelArray]
            set titleStr [format "%s (%d colors)" $descr $numColors]
            poWin SetScrolledTitle $tableId $titleStr
            $tw configure -cursor watch
            update

            foreach key [lsort -integer -index 0 [array names pixelArray]] {
                lassign $key r g b
                set rowList [list "" $r $g $b $pixelArray($key)]
                $tableId insert end $rowList
                if { [poImgAppearance GetShowColorCountColumn] } {
                    $tableId cellconfigure "end,5" -background [format "#%02X%02X%02X" $r $g $b]
                }
            }
            $tw configure -cursor arrow
            update
        }

        if { $sPo($winNum,toplevel) ne "" } {
            bind $tw <KeyPress-Escape> "${ns}::CloseWin $winNum"
            wm protocol $tw WM_DELETE_WINDOW "${ns}::CloseWin $winNum"
        }
        return $winNum
    }

    proc AskSaveColorCountValues { winNum { initFile "colorcount.csv" } } {
        variable ns
        variable sPo

        set fileTypes {
                {"CSV files" ".csv"}
                {"All files" "*"} }

        if { ! [info exists sPo(LastColorCountType)] } {
            set sPo(LastColorCountType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastColorCountType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save color count as CSV file" \
                     -parent $sPo($winNum,toplevel) \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sPo(LastColorCountType) \
                     -initialfile [file tail $initFile] \
                     -initialdir $sPo(lastDir)]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sPo(LastColorCountType)]
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
        if { $fileName ne "" } {
            set sPo(lastDir) [file dirname $fileName]

            set tableId [lindex $sPo($winNum,tables) 0]

            set retVal [catch {open $fileName w} fp]
            if { $retVal != 0 } {
                error "Can't write color count values to CSV file $fileName ($fp)"
            }
            fconfigure $fp -translation binary

            set numCols [$tableId columncount]
            for { set col 0 } { $col < $numCols } { incr col } {
                lappend headerList [$tableId columncget $col -title]
            }
            puts -nonewline $fp [::Excel::ListToCsvRow $headerList]
            puts -nonewline $fp "\r\n"

            foreach row [$tableId get 0 end] {
                puts -nonewline $fp [::Excel::ListToCsvRow $row]
                puts -nonewline $fp "\r\n"
            }
            close $fp
        }
    }

    proc ColorCountValuesToExcel { winNum } {
        variable sPo

        set appId [::Excel::Open true]
        set workbookId [::Excel::AddWorkbook $appId]

        set i 0
        foreach tableId $sPo($winNum,tables) fileName $sPo($winNum,fileNames) {
            set worksheetId [::Excel::AddWorksheet $workbookId "ColorCount-$i"]
            ::Excel::SetCellValue $worksheetId 1 1 $fileName
            set rangeId [::Excel::SelectRangeByIndex $worksheetId 1 1  1 [$tableId columncount]]
            ::Excel::SetRangeFontBold $rangeId true
            ::Excel::SetRangeHorizontalAlignment $rangeId $::Excel::xlHAlignCenter
            ::Excel::SetRangeMergeCells $rangeId true
            ::Excel::TablelistToWorksheet $tableId $worksheetId true 2
            ::Excel::FreezePanes $worksheetId 1 0
            incr i
        }
    }
}

poColorCount Init
