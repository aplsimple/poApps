# Module:         poImgPalette
# Copyright:      Paul Obermeier 2014-2020 / paul@poSoft.de
# First Version:  2014 / 11 / 30
#
# Distributed under BSD license.
#
# Module for handling windows for color counting.

namespace eval poImgPalette {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetChannelNum    SetChannelNum
    namespace export GetUnusedColor   SetUnusedColor
    namespace export GetPaletteFile   SetPaletteFile
    namespace export GetPaletteParams SetPaletteParams

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export ReadPaletteFile
    namespace export GetPaletteColorList
    namespace export GetPaletteEntryIndex GetPaletteEntryName

    proc Init {} {
        # Set unused color to magenta
        SetChannelNum  0
        SetUnusedColor "#FF00FF"
        SetPaletteFile ""
    }

    proc GetChannelNum {} {
        variable sPo

        return $sPo(ChannelNum)
    }

    proc SetChannelNum { channelNum } {
        variable sPo

        set sPo(ChannelNum) $channelNum
    }

    proc GetUnusedColor {} {
        variable sPo

        return $sPo(UnusedColor)
    }

    proc GetUnusedColorAsRgb {} {
        variable sPo

        scan $sPo(UnusedColor) "#%2X%2X%2X" r g b
        return [list $r $g $b]
    }

    proc SetUnusedColor { colorHexString } {
        variable sPo

        set sPo(UnusedColor) $colorHexString
    }

    proc SetPaletteParams { channelNum unusedColor paletteFile } {
        SetChannelNum  $channelNum
        SetUnusedColor $unusedColor
        SetPaletteFile $paletteFile
        _UpdatePalette
    }

    proc GetPaletteParams {} {
        return [list [GetChannelNum]  \
                     [GetUnusedColor] \
                     [GetPaletteFile] ]
    }

    proc GetPaletteFile {} {
        variable sPo

        return $sPo(PaletteFile)
    }

    proc SetPaletteFile { fileName } {
        variable sPo

        set sPo(PaletteFile) $fileName
    }

    proc _ReadTextPaletteFile { fileName } {
        set paletteDict [dict create]
        set colorList   [lrepeat 256 [GetUnusedColorAsRgb]]
        for { set r 0 } { $r < 256 } { incr r } {
            lappend nameList [format "Unused-%d" $r]
        }
        set paletteName [file rootname [file tail $fileName]]

        poCsv SetCsvSeparatorChar ","
        set csvMatrix [poCsv ReadCsvFile $fileName false 1]

        foreach row $csvMatrix {
            set index [lindex $row 0]
            if { $index >= 0 && $index < 256 } {
                lset colorList $index [lrange $row 1 3]
                lset nameList  $index [lindex $row 4]
            } else {
                error "Invalid palette index $index"
            }
        }

        dict append paletteDict Palette $paletteName
        dict append paletteDict Colors  $colorList
        dict append paletteDict Names   $nameList
        return $paletteDict
    }

    proc _ReadTrianPaletteFile { fileName } {
        set retVal [catch {open $fileName r} fp]
        if { $retVal != 0 } {
            error "Could not open Trian palette file $fileName for reading."
        }
        set xmlStr [read $fp]
        close $fp

        set paletteDict [dict create]
        set colorList   [lrepeat 256 [GetUnusedColorAsRgb]]
        for { set r 0 } { $r < 256 } { incr r } {
            lappend nameList [format "Unused-%d" $r]
        }
        set paletteName [file rootname [file tail $fileName]]

        set retVal [catch {dom parse $xmlStr} domDoc]
        if { $retVal != 0 } {
            error "Invalid XML document: [string map {"\n" " "} $domDoc]."
        }
        set domRoot [$domDoc documentElement]

        set topNode [$domDoc childNodes]
        if { [llength $topNode] > 1 } {
            error "Only one top level node expected in file $fileName"
        }

        foreach attr [$topNode attributes] {
            switch -exact -- $attr {
                "name" {
                    set paletteName [$topNode getAttribute $attr]
                }
                "length" {
                    # Not used.
                }
            }
        }
        foreach node [$topNode childNodes] {
            set nodeName [$node nodeName]
            switch -exact -- $nodeName {
                "Class" {
                    foreach attr [$node attributes] {
                        switch -exact -- $attr {
                            "id" {
                                set index [$node getAttribute $attr]
                            }
                            "name" {
                                set name [$node getAttribute $attr]
                            }
                            "color" {
                                set color [$node getAttribute $attr]
                            }
                            "brightness" {
                                # Not used.
                            }
                            "weighting" {
                                # Not used.
                            }
                        }
                    }
                    if { $index >= 0 && $index < 256 } {
                        lset colorList $index $color
                        lset nameList  $index $name
                    } else {
                        error "Invalid palette index $index"
                    }
                }
            }
        }
        dict append paletteDict Palette $paletteName
        dict append paletteDict Colors  $colorList
        dict append paletteDict Names   $nameList
        return $paletteDict
    }

    proc ReadPaletteFile { fileName } {
        if { [string equal -nocase [file extension $fileName] ".xml"] } {
            return [_ReadTrianPaletteFile $fileName]
        } else {
            return [_ReadTextPaletteFile $fileName]
        }
    }

    proc GetPaletteColorList {} {
        variable sPo

        if { [info exists sPo(PaletteDict)] } {
            return [dict get $sPo(PaletteDict) Colors]
        } else {
            return [list]
        }
    }

    proc _UpdateLookupHashes {} {
        variable sPo
        variable sPaletteNames
        variable sPaletteIndices

        if { ! [info exists sPaletteNames] } {
            set count 0
            foreach color [dict get $sPo(PaletteDict) Colors] {
                set name [lindex [dict get $sPo(PaletteDict) Names] $count]
                set colorKey [string map { " " "," } [string trim $color]]
                set sPaletteNames($colorKey)   $name
                set sPaletteIndices($colorKey) $count
                incr count
            }
        }
    }

    proc GetPaletteEntryIndex { r g b } {
        variable sPo
        variable sPaletteIndices

        set entryIndex -1

        if { ! [info exists sPo(PaletteDict)] } {
            return $entryIndex
        }

        _UpdateLookupHashes

        if { [info exists sPaletteIndices($r,$g,$b)] } {
            set entryIndex $sPaletteIndices($r,$g,$b)
        }
        return $entryIndex
    }

    proc GetPaletteEntryName { r g b } {
        variable sPo
        variable sPaletteNames

        set entryName ""

        if { ! [info exists sPo(PaletteDict)] } {
            return $entryName
        }

        _UpdateLookupHashes

        if { [info exists sPaletteNames($r,$g,$b)] } {
            set entryName $sPaletteNames($r,$g,$b)
        }
        return $entryName
    }

    proc CancelWin { w args } {
        variable ns
        variable sPo

        catch { unset sPo(tableId) }
        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        catch { destroy $w }
    }

    proc OkWin { w } {
        variable sPo

        set sPo(PaletteFile) [poWinSelect GetValue $sPo(comboId)]
        if { ! [file exists $sPo(PaletteFile)] } {
            catch { unset sPo(PaletteDict) }
        }
        catch { unset sPo(tableId) }
        destroy $w
    }

    proc _UpdatePaletteTable {} {
        variable sPo

        if { [info exists sPo(tableId)] && [info exists sPo(PaletteDict)] } {
            $sPo(tableId) delete 0 end
            set count 0
            foreach color [dict get $sPo(PaletteDict) Colors] {
                set name [lindex [dict get $sPo(PaletteDict) Names] $count]
                lassign $color r g b
                $sPo(tableId) insert end [list "" $count $name "" $r $g $b]
                $sPo(tableId) cellconfigure "end,3" -background [format "#%02X%02X%02X" $r $g $b]
                incr count
            }
            poWin SetScrolledTitle $sPo(tableId) [dict get $sPo(PaletteDict) Palette]
        }
    }

    proc _UpdatePalette {} {
        variable sPo
        variable sPaletteNames
        variable sPaletteIndices

        if { [file exists $sPo(PaletteFile)] } {
            set sPo(PaletteDict) [ReadPaletteFile $sPo(PaletteFile)]
            catch { unset sPaletteNames }
            catch { unset sPaletteIndices }
        }
        _UpdatePaletteTable
    }

    proc _GetColor { labelId } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(UnusedColor)]
        if { $newColor ne "" } {
            set sPo(UnusedColor) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $labelId configure -background $newColor }
            _UpdatePalette
        }
    }


    proc _GetFileFromWinSelect { comboId } {
        variable sPo

        set sPo(PaletteFile) [poWinSelect GetValue $comboId]
        _UpdatePalette
    }

    proc OpenWin { fr } {
        variable ns
        variable sPo

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
            "Mapped channel:" \
            "Unused color:" \
            "Palette file:" ] {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList [list]

        # Generate right column with entries and buttons.

        # Row 0: Channel to be mapped.
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::radiobutton $tw.fr$row.r -text "Red"   -value 0 -variable ${ns}::sPo(ChannelNum)
        ttk::radiobutton $tw.fr$row.g -text "Green" -value 1 -variable ${ns}::sPo(ChannelNum)
        ttk::radiobutton $tw.fr$row.b -text "Blue"  -value 2 -variable ${ns}::sPo(ChannelNum)
        pack {*}[winfo children $tw.fr$row] -side left

        set tmpList [list [list sPo(ChannelNum)] [list $sPo(ChannelNum)]]
        lappend varList $tmpList

        # Row 1: Color for unused palette entries.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(UnusedColor)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l"
        pack $tw.fr$row.l $tw.fr$row.b -side left

        set tmpList [list [list sPo(UnusedColor)] [list $sPo(UnusedColor)]]
        lappend varList $tmpList

        # Row 2: Palette file selection.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        set comboId [poWinSelect CreateFileSelect $tw.fr$row $sPo(PaletteFile) "open" \
                                 "Select ..." "Select palette file"]
        set fileTypes { \
            { "All files" "*" } \
            { "Trian material files" ".xml" } \
            { "Palette files" ".txt *.csv" } \
        }
        poWinSelect SetFileTypes $comboId $fileTypes
        bind $comboId <<NameValid>> "${ns}::_GetFileFromWinSelect $comboId"
        set sPo(comboId) $comboId

        set tmpList [list [list sPo(PaletteFile)] [list $sPo(PaletteFile)]]
        lappend varList $tmpList

        # Row 3: Table for palette display.
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 0 -columnspan 2 -sticky news
        grid rowconfigure    $tw $row -weight 1
        grid columnconfigure $tw 1    -weight 1

        set tableId [poWin CreateScrolledTablelist $tw.fr$row true "Palette table" \
                    -columns { 0 "#"     "right"
                               0 "Index" "right"
                               0 "Name"  "left"
                               0 "Color" "center"
                               0 "R"     "center"
                               0 "G"     "center"
                               0 "B"     "center" } \
                    -exportselection false \
                    -stretch all \
                    -width 50 \
                    -selectmode browse \
                    -stripebackground [poAppearance GetStripeColor] \
                    -labelcommand tablelist::sortByColumn \
                    -showseparators true]
        $tableId columnconfigure 0 -showlinenumbers true
        $tableId columnconfigure 0 -sortmode integer
        $tableId columnconfigure 1 -sortmode integer
        $tableId columnconfigure 2 -sortmode dictionary
        $tableId columnconfigure 4 -sortmode integer
        $tableId columnconfigure 5 -sortmode integer
        $tableId columnconfigure 6 -sortmode integer
        set sPo(tableId) $tableId

        _UpdatePalette

        return $varList
    }
}

poImgPalette Init
