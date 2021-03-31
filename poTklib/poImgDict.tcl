# Module:         poImgDict
# Copyright:      Paul Obermeier 2014-2020 / paul@poSoft.de
# First Version:  2014 / 02 / 04
#
# Distributed under BSD license.
#
# Module with utility procedures for handling image files 
# with short or float values stored in dictionaries with pure Tcl.

namespace eval poImgDict {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetImageDataAsList GetImageDataAsMatrix
    namespace export GetImageDataAsPhoto
    namespace export DiffImages
    namespace export CreatePseudoColorPhoto
    namespace export GetImageMinMax
    namespace export GetImageMeanStdDev
    namespace export GetPixelValue GetPixelValueAsString
    namespace export GetMinValueAsString GetMaxValueAsString
    namespace export GetMeanValueAsString GetStdDevAsString
    namespace export GetWidth GetHeight GetPixelSize GetNumChannels

    #
    # Utility procedures.
    #

    # PseudoColor lookup table procedures.
    # Code taken from http://dsp.stackexchange.com/questions/4677/how-to-generate-false-color-paletteI
    # Implements the following lookup, which is known as jet in Matlab.
    # 0.0  -> (  0,   0, 128)  dark blue
    # 0.25 -> (  0, 255,   0)  green
    # 0.5  -> (255, 255,   0)  yellow
    # 0.75 -> (255, 128,   0)  orange
    # 1.0  -> (255,   0,   0)  red

    proc _GetRedGradient { val } {
        if { $val <= 0.25 } {
            return 0
        } elseif { $val <= 0.5 } {
            return [expr { int ((1020.0 * $val - 255.0)) }]
        } else {
            return 255
        }
    }

    proc _GetGreenGradient { val } {
        if { $val <= 0.25 } {
            return [expr { int (1020.0 * $val) }]
        } elseif { $val <= 0.5 } {
            set retVal 255
        } else {
            return [expr { int (-510.0 * $val + 510.0) }] 
        }
    }

    proc _GetBlueGradient { val } {
        if { $val <= 0.25 } {
            return [expr { int (-512.0 * $val + 128.0) }]
        } else {
            return 0
        }
    }

    #
    # Image data procedures.
    #
    proc GetImageDataAsList { imgDict } {
        set headerDict [dict get $imgDict Header]

        set numPixels  [dict get $headerDict NumPixel]
        set scanFmt    [dict get $headerDict ScanFormat]
        set scanOrder  [dict get $headerDict ScanOrder]
        set fileName   [dict get $headerDict FileName]

        if { $scanOrder eq "TopDown" } {
            set retVal [binary scan [dict get $imgDict Data] "${scanFmt}${numPixels}" valList]
            if { $retVal != 1 } {
                error "Could not scan pixels of image $fileName"
            }
        } else {
            set pixelSize [dict get $headerDict PixelSize]
            set width     [dict get $headerDict Width]
            set height    [dict get $headerDict Height]

            set numBytesPerRow [expr { $width * $pixelSize }]
            set pos [expr { $width * ($height - 1) * $pixelSize } ]

            for { set row 0 } { $row < $height } { incr row } {
                set fmtStr "@${pos}${scanFmt}${width}"
                set retVal [binary scan [dict get $imgDict Data] $fmtStr rowList]
                if { $retVal != 1 } {
                    error "Could not scan pixels of image $fileName"
                }
                append valList $rowList
                append valList " "
                incr pos [expr { -$numBytesPerRow }]
            }
        }
        return $valList
    }

    proc GetImageDataAsMatrix { imgDict } {
        # The matrix data must be stored as a list of lists. Each sub-list contains
        # the values for the row values.
        # The main (outer) list contains the rows of the matrix.
        # Example:
        # { { R1_C1 R1_C2 R1_C3 } { R2_C1 R2_C2 R2_C3 } }

        set headerDict [dict get $imgDict Header]

        set scanFmt    [dict get $headerDict ScanFormat]
        set scanOrder  [dict get $headerDict ScanOrder]
        set fileName   [dict get $headerDict FileName]

        set pixelSize  [dict get $headerDict PixelSize]
        set width      [dict get $headerDict Width]
        set height     [dict get $headerDict Height]

        set numBytesPerRow [expr { $width * $pixelSize }]
        set pos 0

        for { set row 0 } { $row < $height } { incr row } {
            set fmtStr "@${pos}${scanFmt}${width}"
            set retVal [binary scan [dict get $imgDict Data] $fmtStr rowList]
            if { $retVal != 1 } {
                error "Could not scan pixels of image $fileName"
            }
            set rowLists($row) $rowList
            incr pos $numBytesPerRow
        }

        if { $scanOrder eq "TopDown" } {
            for { set row 0 } { $row < $height } { incr row } {
                lappend matrixList $rowLists($row)
            }
        } else {
            for { set row [expr $height-1] } { $row >= 0 } { incr row -1 } {
                lappend matrixList $rowLists($row)
            }
        }
        return $matrixList
    }

    proc GetImageDataAsPhoto { imgDict { minVal "" } { maxVal "" } { gamma "" } } {
        set headerDict [dict get $imgDict Header]

        set width     [dict get $headerDict Width]
        set height    [dict get $headerDict Height]
        set numChan   [dict get $headerDict NumChan]

        set byteOrder [dict get $headerDict ByteOrder]
        set pixelType [dict get $headerDict PixelType]
        set scanOrder [dict get $headerDict ScanOrder]

        set fmtStr "RAW -useheader 0 -uuencode 0 "
        append fmtStr "-width $width "
        append fmtStr "-height $height "
        append fmtStr "-nchan $numChan "
        append fmtStr "-byteorder $byteOrder "
        append fmtStr "-pixeltype $pixelType "
        append fmtStr "-scanorder $scanOrder "
        if { $minVal ne "" } {
            append fmtStr "-min $minVal "
        }
        if { $maxVal ne "" } {
            append fmtStr "-max $maxVal "
        }
        if { $gamma ne "" } {
            append fmtStr "-gamma $gamma "
        }
        return [image create photo -data [dict get $imgDict Data] -format $fmtStr]
    }

    proc DiffImages { imgDict1 imgDict2 { threshold 0 } { phImg "" } { markColor "#FF00FF" } } {
        set numDifferent 0

        if { [info coroutine] ne "" } {
            yield [list $numDifferent 0]
        }
        set headerDict1 [dict get $imgDict1 Header]
        set headerDict2 [dict get $imgDict2 Header]

        set width1     [dict get $headerDict1 Width]
        set height1    [dict get $headerDict1 Height]
        set pixelSize1 [dict get $headerDict1 PixelSize]
        set numChan1   [dict get $headerDict1 NumChan]

        set width2     [dict get $headerDict2 Width]
        set height2    [dict get $headerDict2 Height]
        set pixelSize2 [dict get $headerDict2 PixelSize]
        set numChan2   [dict get $headerDict2 NumChan]

        if { $width1 != $width2 || $height1 != $height2 } {
            error "Images differ in size. Difference image calculation not possible."
        }
        if { $pixelSize1 != $pixelSize2 } {
            error "Images differ in pixel size. Difference image calculation not possible."
        }
        if { $numChan1 != $numChan2 } {
            error "Images differ in number of channels. Difference image calculation not possible."
        }
        if { ! ($numChan1 == 1 || $numChan1 == 3) } {
            error "Difference image calculation only possible for 1 or 3-channel images."
        }

        set imgMatrix1 [GetImageDataAsMatrix $imgDict1]
        set imgMatrix2 [GetImageDataAsMatrix $imgDict2]

        for { set row 0 } { $row < $height1 } { incr row } {
            set rowList1 [lindex $imgMatrix1 $row]
            set rowList2 [lindex $imgMatrix2 $row]
            for { set col 0 } { $col < $width1 } { incr col } {
                set pixelVal1 [lindex $rowList1 $col]
                set pixelVal2 [lindex $rowList2 $col]
                #puts "pixelVal1 = $pixelVal1"
                if { [poMisc Abs [expr {$pixelVal1 - $pixelVal2}]] > $threshold } {
                    incr numDifferent
                    if { $phImg ne "" } {
                        $phImg put $markColor -to $col $row
                    }
                }
            }
            if { [info coroutine] ne "" } {
                yield [list $numDifferent [expr { int (100.0 * $row / $height1) }]]
            }
        }
        if { [info coroutine] ne "" } {
            yield [list $numDifferent 100]
        }
        return $numDifferent
    }

    proc CreatePseudoColorPhoto { imgDict { mode "Pseudocolor" } } {
        set headerDict [dict get $imgDict Header]

        set numPixels  [dict get $headerDict NumPixel]
        set scanFmt    [dict get $headerDict ScanFormat]
        set pixelSize  [dict get $headerDict PixelSize]
        set fileName   [dict get $headerDict FileName]
        set width      [dict get $headerDict Width]
        set height     [dict get $headerDict Height]
        set scanOrder  [dict get $headerDict ScanOrder]
        set numChan    [dict get $headerDict NumChan]

        if { ! ($numChan == 1 && $pixelSize == 2) } {
            error "CreatePseudoColorPhoto only possible for 16-bit images with 1 channel."
        }
        set phImg [image create photo -width $width -height $height]
        set retVal [binary scan [dict get $imgDict Data] "${scanFmt}${numPixels}" valList]
        if { $retVal != 1 } {
            error "Could not scan pixels of image $fileName"
        }

        set index 0
        for { set y 0 } { $y < $height } { incr y } {
            if { $scanOrder eq "TopDown" } {
                set photoY $y
            } else {
                set photoY [expr {$height - $y - 1}]
            }
            set rowList [list]
            if { $mode eq "Pseudocolor" } {
                for { set x 0 } { $x < $width } { incr x } {
                    set pixelVal [expr { [lindex $valList $index] / 65535.0 }]
                    set r [_GetRedGradient   $pixelVal]
                    set g [_GetGreenGradient $pixelVal]
                    set b [_GetBlueGradient  $pixelVal]
                    lappend rowList $r $g $b
                    incr index
                }
            } else {
                for { set x 0 } { $x < $width } { incr x } {
                    set pixelVal [lindex $valList $index]
                    set r [expr {($pixelVal     ) & 0xFF}]
                    set g [expr {($pixelVal >> 8) & 0xFF}]
                    lappend rowList $r $g 0
                    incr index
                }
            }
            $phImg put [binary format "cu*" $rowList] -to 0 $photoY \
                   -format "RAW -useheader 0 -uuencode 0 -width $width -height 1 -nchan 3 -pixeltype byte -scanorder $scanOrder"
        }
        return $phImg
    }

    proc GetImageMinMax { imgDict } {
        upvar 1 $imgDict myDict

        set numPixels  [dict get $myDict Header NumPixel]
        set scanFmt    [dict get $myDict Header ScanFormat]
        set pixelType  [dict get $myDict Header PixelType]
        set fileName   [dict get $myDict Header FileName]
        set numChan    [dict get $myDict Header NumChan]

        set numValues  [expr {$numPixels * $numChan }]

        set retVal [binary scan [dict get $myDict Data] "${scanFmt}${numValues}" valList]
        if { $retVal != 1 } {
            error "Could not scan pixels of image $fileName"
        }
        if { $pixelType eq "float" } {
            set sortedList [lsort -increasing -real $valList]
        } else {
            set sortedList [lsort -increasing -integer $valList]
        }
        set minVal [lindex $sortedList 0]
        set maxVal [lindex $sortedList end]
        dict set myDict Header MinValue $minVal
        dict set myDict Header MaxValue $maxVal
        return [list $minVal $maxVal]
    }

    proc _Square { x } {
        return [expr {$x * $x}]
    }

    proc GetImageMeanStdDev { imgDict } {
        upvar 1 $imgDict myDict

        set numPixels  [dict get $myDict Header NumPixel]
        set scanFmt    [dict get $myDict Header ScanFormat]
        set pixelType  [dict get $myDict Header PixelType]
        set fileName   [dict get $myDict Header FileName]
        set numChan    [dict get $myDict Header NumChan]

        set numValues  [expr {$numPixels * $numChan }]
        set sum 0
        set std 0.0

        set retVal [binary scan [dict get $myDict Data] "${scanFmt}${numValues}" valList]
        if { $retVal != 1 } {
            error "Could not scan pixels of image $fileName"
        }
        # Calculate mean value.
        foreach val $valList {
            set sum [expr {$sum + $val}]
        }
        set meanVal [expr {double($sum) / double($numValues)}]

        # Calculate standard deviation.
        foreach val $valList {
            set diff [_Square [expr {$meanVal - $val}]]
            set std  [expr { $std + $diff}]
        }
        set stdDev [expr {sqrt (double($std) / double($numValues-1))}]

        dict set myDict Header MeanValue $meanVal
        dict set myDict Header StdDev    $stdDev
        return [list $meanVal $stdDev]
    }

    proc GetPixelValue { imgDict x y } {
        upvar 1 $imgDict myDict

        set width     [dict get $myDict Header Width]
        set height    [dict get $myDict Header Height]
        set scanFmt   [dict get $myDict Header ScanFormat]
        set scanOrder [dict get $myDict Header ScanOrder]
        set pixelSize [dict get $myDict Header PixelSize]
        set numChan   [dict get $myDict Header NumChan]
        set fileName  [dict get $myDict Header FileName]

        set valList [list]
        if { $x >= 0 && $y >= 0 && $x < $width && $y < $height } {
            if { $scanOrder eq "BottomUp" } {
                set posxy [expr {$x + ($height - $y - 1) * $width}]
            } else {
                set posxy [expr {$x + $y * $width}]
            }
            set pos [expr {$posxy * $pixelSize * $numChan}]

            set fmtStr "@${pos}${scanFmt}${numChan}"
            set retVal [binary scan [dict get $myDict Data] $fmtStr valList]
            if { $retVal != 1 } {
                error "Could not read pixel value from byte position $pos"
            }
        }
        return $valList
    }

    proc _FormatValue { val pixelSize { precision 4 } } {
        set str ""
        if { $pixelSize == 4 } {
            append str [format "%.${precision}f" $val]
        } elseif { $pixelSize == 2 } {
            append str [format "%5d" $val]
        } else {
            append str [format "%3d" $val]
        }
        return [string trim $str]
    }

    proc GetPixelValueAsString { imgDict x y { precision 4 } } {
        upvar 1 $imgDict myDict

        set valList [GetPixelValue myDict $x $y]
        set str ""
        foreach val $valList {
            set retVal [catch { _FormatValue $val [dict get $myDict Header PixelSize] $precision } valStr ]
            if { $retVal != 0 } {
                return "N/A"
            }
            append str $valStr " "
        }
        return [string trim $str]
    }

    proc GetMinValueAsString { imgDict { precision 4 } } {
        upvar 1 $imgDict myDict

        if { ! [dict exists $myDict Header MinValue] } {
            return "N/A"
        }

        return [_FormatValue [dict get $myDict Header MinValue] [dict get $myDict Header PixelSize] $precision]
    }

    proc GetMaxValueAsString { imgDict { precision 4 } } {
        upvar 1 $imgDict myDict

        if { ! [dict exists $myDict Header MaxValue] } {
            return "N/A"
        }

        return [_FormatValue [dict get $myDict Header MaxValue] [dict get $myDict Header PixelSize] $precision]
    }

    proc GetMeanValueAsString { imgDict { precision 4 } } {
        upvar 1 $imgDict myDict

        if { ! [dict exists $myDict Header MeanValue] } {
            return "N/A"
        }

        return [format "%.${precision}f" [dict get $myDict Header MeanValue] $precision]
    }

    proc GetStdDevAsString { imgDict { precision 4 } } {
        upvar 1 $imgDict myDict

        if { ! [dict exists $myDict Header StdDev] } {
            return "N/A"
        }

        return [format "%.${precision}f" [dict get $myDict Header StdDev] $precision]
    }

    proc GetWidth { imgDict } {
        upvar 1 $imgDict myDict

        return [dict get $myDict Header Width]
    }

    proc GetHeight { imgDict } {
        upvar 1 $imgDict myDict

        return [dict get $myDict Header Height]
    }

    proc GetPixelSize { imgDict } {
        upvar 1 $imgDict myDict

        return [dict get $myDict Header PixelSize]
    }

    proc GetNumChannels { imgDict } {
        upvar 1 $imgDict myDict

        return [dict get $myDict Header NumChan]
    }
}
