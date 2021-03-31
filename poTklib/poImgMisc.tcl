# Module:         poImgMisc
# Copyright:      Paul Obermeier 2013-2020 / paul@poSoft.de
# First Version:  2013 / 07 / 31
#
# Distributed under BSD license.
#
# Module with miscellaneous image related utility procedures.

namespace eval poImgMisc {
    variable ns [namespace current]

    namespace ensemble create

    namespace export IsPhoto
    namespace export IsImageFile
    namespace export LoadImg LoadImgScaled
    namespace export CreateThumbImg
    namespace export CreateLabelImg
    namespace export ReadBmp WriteBmp

    # Check, if identifier "img" is a valid Tk photo image.
    proc IsPhoto { img } {
        if { [lsearch -exact [image names] $img] >= 0 } {
            return true
        }
        return false
    }

    proc IsImageFile { fileName { imgFmt "" } } {
        if { [poMisc HaveTcl87OrNewer] } {
            set metaDict [image metadata -file $fileName]
            if { ! [dict exists $metaDict "format"] } {
                return false
            }
            set fmt [dict get $metaDict "format"]
            if { $fmt ne "" && $imgFmt eq "" } {
                return true
            }
            if { [string equal -nocase $fmt $imgFmt] } {
                return true
            } else {
                return false
            }
        } else {
            return [poType IsImage $fileName $imgFmt]
        }
    }

    proc LoadImg { imgName { optionStr "" } } {
        poWatch Start _poImgMiscSwatch

        set phImg ""
        set poImg ""
        dict set imgDict phImg $phImg
        dict set imgDict poImg $poImg

        set ext [file extension $imgName]
        set imgName [file normalize $imgName]
        set fmtStr [poImgType GetFmtByExt $ext]
        if { $fmtStr eq "" } {
            poLog Error "Extension \"$ext\" not supported."
            error "Extension \"$ext\" not supported."
        }
        if { $optionStr eq "" } {
            set optStr [poImgType GetOptByFmt $fmtStr "read"]
        } else {
            set optStr $optionStr
        }

        # TODO What to do with animated GIF's??
        if { $fmtStr eq "GIF" } {
            if { [poImgDetail CheckAniGifIndex $imgName 1] } {
                # We suceeded in reading an image from the AniGif file.
                poLog Debug "This seems to be an animated GIF"
            }
        }

        # Try to read an image from file.
        # 1. Try to read it with standard Tk image procs or by using the
        #    Img extension.
        # 2. If this did not succeed, try using the poImg extension, if it exists.
        set retVal [catch {set phImg [image create photo -file $imgName \
                                      -format "[string tolower $fmtStr] $optStr"]} err1]
        if { $retVal != 0 } {
            # Case (2)
            if { [poImgAppearance UsePoImg] } {
                set retVal [catch {set poImg [poImage NewImageFromFile $imgName]} err2]
                if { $retVal != 0 } {
                    poLog Error "Can't read image $imgName ($err1 $err2)"
                    error "Can't read image \"$imgName\""
                } else {
                    set phImg [image create photo]
                    # Check stored channels in poImage.
                    $poImg GetImgFormat fmtList
                    set minVal 0
                    set maxVal 255
                    set chanMap [list $::RED $::GREEN $::BLUE]
                    if { [lindex $fmtList $::RED]   || \
                         [lindex $fmtList $::GREEN] || \
                         [lindex $fmtList $::BLUE] } {
                         if { [lindex $fmtList $::MATTE] } {
                            set chanMap [list $::RED $::GREEN $::BLUE $::MATTE]
                        } else {
                            set chanMap [list $::RED $::GREEN $::BLUE]
                        }
                    } elseif { [lindex $fmtList $::MATTE] && \
                               [lindex $fmtList $::BRIGHTNESS] } {
                        set chanMap [list $::BRIGHTNESS $::BRIGHTNESS $::BRIGHTNESS $::MATTE]
                    } elseif { [lindex $fmtList $::BRIGHTNESS] } {
                        set chanMap [list $::BRIGHTNESS $::BRIGHTNESS $::BRIGHTNESS]
                    } elseif { [lindex $fmtList $::DEPTH] } {
                        # Note: The following reverse order of minVal and maxVal is
                        # correct, as depth values are stored as reciprocal values.
                        $poImg GetDepthRange maxVal minVal
                        set minVal [expr 1.0 / $minVal]
                        set maxVal [expr 1.0 / $maxVal]
                        set chanMap [list $::DEPTH $::DEPTH $::DEPTH]
                    } elseif { [lindex $fmtList $::TEMPERATURE] } {
                        $poImg GetTemperatureRange minVal maxVal
                        set chanMap [list $::TEMPERATURE $::TEMPERATURE $::TEMPERATURE]
                    } elseif { [lindex $fmtList $::RADIANCE] } {
                        $poImg GetRadianceRange minVal maxVal
                        set chanMap [list $::RADIANCE $::RADIANCE $::RADIANCE]
                    } elseif { [lindex $fmtList $::MATTE] } {
                        set chanMap [list $::MATTE $::MATTE $::MATTE]
                    }
                    $poImg AsPhoto $phImg $chanMap 1.0 $minVal $maxVal
                }
            } else {
                poLog Error "Can't read image $imgName ($err1)"
                error "Can't read image \"$imgName\""
            }
        }
        dict set imgDict phImg $phImg
        dict set imgDict poImg $poImg

        set totalTime [poWatch Lookup _poImgMiscSwatch]
        poLog Info [format "%.2f sec: LoadImg %s" $totalTime $imgName]

        return $imgDict
    }

    proc LoadImgScaled { imgName newWidth newHeight } {
        poWatch Start _poImgMiscSwatch

        set ext [file extension $imgName]
        set fmtStr [poImgType GetFmtByExt $ext]
        if { $fmtStr eq "" } {
            poLog Warning "Extension \"$ext\" not in image type list."
            set fmtCmd ""
        } else {
            set optStr [poImgType GetOptByFmt $fmtStr "read"]
            set fmtCmd [format "-format \"%s %s\"" [string tolower $fmtStr] $optStr]
        }

        # Try to read an image from file.
        # 1. Try to read it with standard Tk image procs or by using the Img extension.
        # 2. If this did not succeed, try using the poImg extension, if it exists.
        set poImg ""
        set retVal [catch {set phImg [eval {image create photo -file $imgName} \
                                      $fmtCmd]} err1]
        if { $retVal != 0 } {
            # Case (2)
            set retVal [catch {poImageMode GetFileInfo $imgName w h} err2]
            if { $retVal != 0 } {
                poLog Warning "Can't read image $imgName ($err1 $err2)"
                return ""
            } else {
                set xzoom [expr {($w / $newWidth)  + 1}]
                set yzoom [expr {($h / $newHeight) + 1}]
                set zoomFact [poMisc Max $xzoom $yzoom]

                set poImg [poImage NewImage [expr {$w / $zoomFact}] \
                                            [expr {$h / $zoomFact}]]
                $poImg ReadImageFromFile $imgName true

                set phThumb [image create photo]
                # Check stored channels in poImage.
                $poImg GetImgFormat fmtList
                set chanMap [list $::RED $::GREEN $::BLUE]
                if { [lindex $fmtList $::RED]   || \
                     [lindex $fmtList $::GREEN] || \
                     [lindex $fmtList $::BLUE] } {
                     if { [lindex $fmtList $::MATTE] } {
                        set chanMap [list $::RED $::GREEN $::BLUE $::MATTE]
                    } else {
                        set chanMap [list $::RED $::GREEN $::BLUE]
                    }
                } elseif { [lindex $fmtList $::MATTE] && \
                           [lindex $fmtList $::BRIGHTNESS] } {
                    set chanMap [list $::BRIGHTNESS $::BRIGHTNESS $::BRIGHTNESS $::MATTE]
                } elseif { [lindex $fmtList $::BRIGHTNESS] } {
                    set chanMap [list $::BRIGHTNESS $::BRIGHTNESS $::BRIGHTNESS]
                } elseif { [lindex $fmtList $::DEPTH] } {
                    set chanMap [list $::DEPTH $::DEPTH $::DEPTH]
                } elseif { [lindex $fmtList $::MATTE] } {
                    set chanMap [list $::MATTE $::MATTE $::MATTE]
                }
                $poImg AsPhoto $phThumb $chanMap
                poImgUtil DeleteImg $poImg
            }
        } else {
            set w [image width  $phImg]
            set h [image height $phImg]

            set xzoom [expr {($w / $newWidth)  + 1}]
            set yzoom [expr {($h / $newHeight) + 1}]
            set zoomFact [poMisc Max $xzoom $yzoom]

            if { $zoomFact > 1 } {
                set phThumb [image create photo \
                         -width  [expr {$w / $zoomFact}] \
                         -height [expr {$h / $zoomFact}]]
                $phThumb copy $phImg -subsample $zoomFact
            } else {
                set phThumb [image create photo]
                $phThumb copy $phImg
            }
            image delete $phImg
        }
        set ws [image width  $phThumb]
        set hs [image height $phThumb]
        set xoff [expr { ($newWidth  - $ws) / 2 }]
        set yoff [expr { ($newHeight - $hs) / 2 }]
        set phPlace [image create photo -width $newWidth -height $newHeight]
        $phPlace copy $phThumb -to $xoff $yoff
        image delete $phThumb

        set totalTime [poWatch Lookup _poImgMiscSwatch]
        poLog Info [format "%.2f sec: LoadImgScaled %s %d %d" $totalTime $imgName $newWidth $newHeight]
        return $phPlace
    }

    proc CreateThumbImg { phImg thumbSize } {

        set w [image width  $phImg]
        set h [image height $phImg]

        if { $w > $h } {
            set ws [expr {int ($thumbSize)}]
            set hs [expr {int ((double($h)/double($w)) * $thumbSize)}]
        } else {
            set ws [expr {int ((double($w)/double($h)) * $thumbSize)}]
            set hs [expr {int ($thumbSize)}]
        }
        if { $ws == 0 } {
            set ws 1
        }
        if { $hs == 0 } {
            set hs 1
        }
        set thumbImg [image create photo -width $ws -height $hs]
        set xsub [expr {($w / $ws) + 1}]
        set ysub [expr {($h / $hs) + 1}]
        $thumbImg copy $phImg -subsample $xsub $ysub -to 0 0
        set placeImg [image create photo -width $thumbSize -height $thumbSize]
        set xoff [expr { ($thumbSize - $ws) / 2 }]
        set yoff [expr { ($thumbSize - $hs) / 2 }]
        $placeImg copy $thumbImg -to $xoff $yoff
        image delete $thumbImg
        return $placeImg
    }

    proc CreateLabelImg { color { width 13 } { height 13 } } {
        set img [image create photo -height $height -width $width]
        set width1  [expr { $width  - 1}]
        set height1 [expr { $height - 1}]
        $img put gray50 -to 0 0        $width 1           ; # top edge
        $img put gray50 -to 0 1        1 $height1         ; # left edge
        $img put gray75 -to 0 $height1 $width $height     ; # bottom edge
        $img put gray75 -to $width1    1 $width $height1  ; # right edge

        $img put $color -to 1 1 $width1 $height1
        return $img
    }

    proc ReadBmp { bmpFile } {
        poLog Info "Reading bitmap with built-in parser"
        set retVal [catch {open $bmpFile r} fp]
        if { $retVal != 0 } {
            error "Can't read bitmap file $bmpFile ($fp)"
        }
        gets $fp line
        scan $line "%s %s %d" dummy name width

        gets $fp line
        scan $line "%s %s %d" dummy name height

        gets $fp line
        if { ! [string match "static*" $line] } {
            # Read the hot spot definitions. We currently ignore these.
            scan $line "%s %s %d" dummy name hotx

            gets $fp line
            scan $line "%s %s %d" dummy name hoty

            gets $fp line
        }
        if { ! [string match "static*" $line] } {
            error "Can't parse bitmap file $bmpFile"
        }

        # Create an image of appropriate size.
        set phImg [image create photo -width $width -height $height]
        $phImg blank

        # Now read in the bitmap definition in one piece.
        set bmpStr [string trim [read $fp] "\n \}\;"]
        close $fp

        set curElem 0
        set elemList [split $bmpStr ","]
        for { set y 0 } { $y < $height } { incr y } {
            for { set x 0 } { $x < $width } { } {
                set elem [lindex $elemList $curElem]
                incr curElem
                set val  [string trim $elem]
                for { set i 0 } { $i < 8 } { incr i } {
                    set pixVal [expr {$val & 0x1}]
                    if { $pixVal } {
                        $phImg put "#FFFFFF" -to $x $y
                    }
                    incr x
                    set val [expr {$val >> 1}]
                }
            }
        }
        return $phImg
    }

    proc WriteBmp { phImg bmpFile } {
        poLog Info "Saving bitmap with built-in parser"

        set retVal [catch {open $bmpFile w} fp]
        if { $retVal != 0 } {
            error "Can't write bitmap data to file $bmpFile"
        }
        fconfigure $fp -translation lf

        set shortName [file rootname [file tail $bmpFile]]
        set width  [image width  $phImg]
        set height [image height $phImg]
        puts $fp [format "#define %s_width %d"  $shortName $width]
        puts $fp [format "#define %s_height %d" $shortName $height]
        puts $fp [format "static char %s_bits\[\] = \{" $shortName]

        set sep " "
        for { set y 0 } { $y < $height } { incr y } {
            set val  0
            set mask 1
            for { set x 0 } { $x < $width } { incr x } {
                set pix [$phImg get $x $y]
                set r [lindex $pix 0]
                set g [lindex $pix 1]
                set b [lindex $pix 2]
                if { $r == 255 && $g == 255 && $b == 255 } {
                    set val [expr {$val | $mask}]
                }
                set mask [expr {$mask << 1}]
                if { $mask >= 256 } {
                    puts -nonewline $fp [format "%s 0x%02x" $sep $val]
                    set val 0
                    set mask 1
                    set sep ","
                }
            }
            if { $mask != 1 } {
                puts -nonewline $fp [format "%s 0x%02x" $sep $val]
            }

            if { $y == $height -1 } {
                puts $fp "\}\;"
            } else {
                puts $fp ","
                set sep " "
            }
        }
        close $fp
    }
}
