# Module:         poWinCapture
# Copyright:      Paul Obermeier 2004-2023 / paul@poSoft.de
# First Version:  2004 / 10 / 19
#
# Distributed under BSD license.
#
# Module for capturing window contents into an image or file.

namespace eval poWinCapture {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export Windows2Img
    namespace export Windows2File
    namespace export Canvas2Img
    namespace export Canvas2File
    namespace export Clipboard2Img
    namespace export Clipboard2File
    namespace export Img2Clipboard
    namespace export IsFormatAvailable
    namespace export GetSystemFormatName
    namespace export GetSupportedFormatNames
    namespace export GetPathList
    namespace export WritePathList
    namespace export GetFormatName
    namespace export GetFormatNum

    proc Init {} {
        variable sSystemFormats
        variable sPo

        set retVal [catch { package require "twapi" } version]
        set retVal [catch { package require "Img" } version]
        if { ! [poMisc HaveTcl87OrNewer] } {
            set retVal [catch { package require "tksvg" } version]
        }

        array set sSystemFormats {
               1 CF_TEXT
               2 CF_BITMAP
               3 CF_METAFILEPICT
               4 CF_SYLK
               5 CF_DIF
               6 CF_TIFF
               7 CF_OEMTEXT
               8 CF_DIB
               9 CF_PALETTE
              10 CF_PENDATA
              11 CF_RIFF
              12 CF_WAVE
              13 CF_UNICODETEXT
              14 CF_ENHMETAFILE
              15 CF_HDROP
              16 CF_LOCALE
              17 CF_DIBV5
              18 CF_MAX
             128 CF_OWNERDISPLAY
             129 CF_DSPTEXT
             130 CF_DSPBITMAP
             131 CF_DSPMETAFILEPICT
             142 CF_DSPENHMETAFILE
             512 CF_PRIVATEFIRST
             767 CF_PRIVATELAST
             768 CF_GDIOBJFIRST
            1023 CF_GDIOBJLAST
        }

        _CollectRegisteredFormatNames

        set sPo(imgfmt,CF_DIB)        "bmp" 
        set sPo(imgfmt,CF_TIFF)       "tiff"
        set sPo(imgfmt,GIF)           "gif"
        set sPo(imgfmt,JFIF)          "jpeg"
        set sPo(imgfmt,PNG)           "png"
        set sPo(imgfmt,image/svg+xml) "svg"

        set sPo(paste,CF_DIB)        [GetFormatNum "CF_DIB"]
        set sPo(paste,CF_TIFF)       [GetFormatNum "CF_TIFF"]
        set sPo(paste,GIF)           [GetFormatNum "GIF"]
        set sPo(paste,JFIF)          [GetFormatNum "JFIF"]
        set sPo(paste,PNG)           [GetFormatNum "PNG"]
        set sPo(paste,image/svg+xml) [GetFormatNum "image/svg+xml"]

        set sPo(copy,CF_DIB)         [GetFormatNum "CF_DIB"]
        set sPo(copy,CF_TIFF)        [GetFormatNum "CF_TIFF"]
        set sPo(copy,GIF)            [GetFormatNum "GIF"]
        set sPo(copy,JFIF)           [GetFormatNum "JFIF"]
        set sPo(copy,PNG)            [GetFormatNum "PNG"]
    }

    proc IsFormatAvailable { fmtNumOrName } {
        if { ! [poMisc HavePkg "twapi"] } {
            return false
        }
        if { [string is integer -strict $fmtNumOrName] } {
            set fmtNum $fmtNumOrName
        } else {
            set fmtNum [GetFormatNum $fmtNumOrName]
        }
        return [twapi::clipboard_format_available $fmtNum]
    }

    proc GetImgFormat { fmtNumOrName } {
        variable sPo

        if { [string is integer -strict $fmtNumOrName] } {
            set fmtName [GetFormatName $fmtNumOrName]
        } else {
            set fmtName $fmtNumOrName
        }
        if { [info exists sPo(imgfmt,$fmtName)] } {
            return $sPo(imgfmt,$fmtName)
        }
        error "Unsupported clipboard format $fmtNumOrName"
    }

    proc GetSupportedFormatNames { type } {
        variable sPo

        set fmtList [list]
        foreach key [array names sPo "$type,*"] {
            lappend fmtList [lindex [split $key ","] 1]
        }
        return [lsort -dictionary $fmtList]
    }

    proc GetSystemFormatName { fmtNum } {
        variable sSystemFormats

        if { [info exists sSystemFormats($fmtNum)] } {
            return $sSystemFormats($fmtNum)
        } else {
            return ""
        }
    }

    proc _CollectRegisteredFormatNames {} {
        variable sAllFormats

        catch { unset sAllFormats }
        if { ! [poMisc HavePkg "twapi"] } {
            return
        }

        for { set fmtNum 1 } { $fmtNum < 100000 } { incr fmtNum } {
            set retVal [catch { twapi::get_registered_clipboard_format_name $fmtNum } name]
            if { $retVal != 0 } {
                set name [GetSystemFormatName $fmtNum]
                if { $name ne "" } {
                    set sAllFormats($fmtNum) $name
                }
            } else {
                set sAllFormats($fmtNum) $name
            }
        }
    }

    proc GetFormatNum { fmtName } {
        variable sAllFormats

        if { ! [info exists sAllFormats] } {
            return -1
        }

        foreach num [array names sAllFormats] {
            if { $sAllFormats($num) eq $fmtName } {
                return $num
            }
        }
        return -1
    }

    proc GetFormatName { fmtNum } {
        variable sAllFormats

        if { ! [info exists sAllFormats] } {
            return ""
        }
        if { [info exists sAllFormats($fmtNum)] } {
            return $sAllFormats($fmtNum)
        }
        return ""
    }

    proc GetPathList {} {
        set pathList [list]
        if { ! [poMisc HavePkg "twapi"] } {
            return $pathList
        }
        if { [IsFormatAvailable "CF_HDROP"] } {
            set pathList [twapi::read_clipboard_paths]
        }
        return $pathList
    }

    proc WritePathList { pathList } {
        if { ! [poMisc HavePkg "twapi"] } {
            error "WritePathList: Twapi extension not available"
        }
        twapi::write_clipboard_paths $pathList
    }

    proc Windows2Img { win } {
        regexp -- {([0-9]*)x([0-9]*)\+([0-9]*)\+([0-9]*)} \
                  [winfo geometry $win] - w h x y

        if { [poMisc HavePkg "twapi"] } {
            # Clear clipboard before making a screenshot of the current window.
            set retVal [catch { twapi::open_clipboard }]
            if { $retVal != 0 } {
                error "Windows2Img: Clipboard cannot be opened"
            }
            twapi::empty_clipboard
            twapi::close_clipboard
            twapi::send_keys {%{PRTSC}{ALT}}
            update
            # If the clipboard is empty or the image is large, it may take some time
            # for the clipboard to have a valid content. So try it 5 times.
            set count 5
            while { $count > 0 } {
                set retVal [catch { Clipboard2Img } img]
                if { $retVal == 0 } {
                    break
                }
                after 200
                incr count -1
            }
        } elseif { [poMisc HavePkg "Img"] } {
            set img [image create photo -format window -data $win]
            foreach child [winfo children $win] {
                CaptureSubWindow $child $img 0 0
            }
        } else {
            set img [image create photo -width $h -height $h]
            $img blank
        }
        return $img
    }

    proc CaptureSubWindow { win img px py } {
        if { ![winfo ismapped $win] } {
            return
        }
        regexp -- {([0-9]*)x([0-9]*)\+([-]*[0-9]*)\+([-]*[0-9]*)} \
            [winfo geometry $win] - w h x y

        if { $x < 0 || $y < 0 } {
            return
        }
        incr px $x
        incr py $y

        set ximg [image width  $img]
        set yimg [image height $img]

        # Make an image from this widget
        set tmpImg [image create photo -format window -data $win]
        set xtmp [image width  $tmpImg]
        set ytmp [image height $tmpImg]
     
        # Take into account, that some widgets do not give correct size informations,
        # ex. ScrolledFrame. So we only copy the contents of the tmpImg that fit into
        # the original image.
        set xmax $xtmp
        set ymax $ytmp
        if { $px + $xtmp > $ximg } {
            set xmax [expr $ximg - $px]
        }
        if { $py + $ytmp > $yimg } {
            set ymax [expr $yimg - $py]
        }
        if { $xmax > 0 && $ymax > 0 } {
            # Copy this image into place on the main image
            $img copy $tmpImg -from 0 0 $xmax $ymax -to $px $py
        }
        image delete $tmpImg

        foreach child [winfo children $win] {
            CaptureSubWindow $child $img $px $py 
        }
    }

    proc Windows2File { win fileName } {
        set img [Windows2Img $win]

        if { [string length $fileName] != 0 } {
            set fmtStr [poImgType GetFmtByExt [file extension $fileName]] 
            set optStr [poImgType GetOptByFmt $fmtStr "write"]
            $img write $fileName -format [list $fmtStr {*}$optStr]
        }
        image delete $img
    }

    proc Canvas2Img { canv } {
        set region [$canv cget -scrollregion]
        set xsize [lindex $region 2]
        set ysize [lindex $region 3]
        set img [image create photo -width $xsize -height $ysize]
        if { ! [poMisc HavePkg "Img"] } {
            $img blank
        } else {
            $canv xview moveto 0
            $canv yview moveto 0
            update
            set xr 0.0
            set yr 0.0
            set px 0
            set py 0
            while { $xr < 1.0 } {
                while { $yr < 1.0 } {
                    set tmpImg [image create photo -format window -data $canv]
                    $img copy $tmpImg -to $px $py
                    image delete $tmpImg
                    set yr [lindex [$canv yview] 1]
                    $canv yview moveto $yr
                    set py [expr round ($ysize * [lindex [$canv yview] 0])]
                    update
                }
                $canv yview moveto 0
                set yr 0.0
                set py 0

                set xr [lindex [$canv xview] 1]
                $canv xview moveto $xr
                set px [expr round ($xsize * [lindex [$canv xview] 0])]
                update
            }
        }
        return $img
    }

    proc Canvas2File { canv fileName } {
        set img [Canvas2Img $canv]

        if { [string length $fileName] != 0 } {
            set fmtStr [poImgType GetFmtByExt [file extension $fileName]] 
            set optStr [poImgType GetOptByFmt $fmtStr "write"]
            $img write $fileName -format [list $fmtStr {*}$optStr]
        }
        image delete $img
    }

    proc Clipboard2Img { { fmtNumOrName "" } } {
        # Copy the contents of the Windows clipboard into a photo image.
        # Return the photo image identifier.
        variable sPo

        if { ! [poMisc HavePkg "twapi"] } {
            error "Clipboard2Img: Twapi extension not available"
        }

        if { $fmtNumOrName eq "" } {
            set fmtNameList [GetSupportedFormatNames paste]
        } else {
            if { [string is integer -strict $fmtNumOrName] } {
                set name [GetFormatName $fmtNumOrName]
                set fmtNameList [list $name]
            } else {
                set fmtNameList [list $fmtNumOrName]
            }
        }
        if { ! [info exists fmtNameList] } {
            error "Clipboard2Img: Unsupported clipboard format $fmtNumOrName specified"
        }
        set retVal [catch { twapi::open_clipboard }]
        if { $retVal != 0 } {
            error "Clipboard2Img: Clipboard cannot be opened"
        }

        set foundFmt false
        set phImg [image create photo]

        foreach fmtName $fmtNameList {
            set retVal [catch {twapi::read_clipboard $sPo(paste,$fmtName)} clipData]
            if { $retVal != 0 } {
                continue
            }

            # CF_DIB needs special handling.
            if { $fmtName eq "CF_DIB" && [poMisc HavePkg "Img"] } {
                # First parse the bitmap data to collect header information
                binary scan $clipData "iiissiiiiii" \
                       size width height planes bitcount compression sizeimage \
                       xpelspermeter ypelspermeter clrused clrimportant

                # We only handle BITMAPINFOHEADER right now (size must be 40)
                if { $size != 40 } {
                    error "Clipboard2Img: Unsupported bitmap format. Header size=$size"
                }

                # We need to figure out the offset to the actual bitmap data
                # from the start of the file header. For this we need to know the
                # size of the color table which directly follows the BITMAPINFOHEADER
                if { $bitcount == 0 } {
                    error "Clipboard2Img: Unsupported format: implicit JPEG or PNG"
                } elseif { $bitcount == 1 } {
                    set colorTableSize 2
                } elseif { $bitcount == 4 } {
                    # TBD - Not sure if this is the size or the max size
                    set colorTableSize 16
                } elseif { $bitcount == 8 } {
                    # TBD - Not sure if this is the size or the max size
                    set colorTableSize 256
                } elseif { $bitcount == 16 || $bitcount == 32 } {
                    if { $compression == 0 } {
                        # BI_RGB
                        set colorTableSize $clrused
                    } elseif { $compression == 3 } {
                        # BI_BITFIELDS
                        set colorTableSize 3
                    } else {
                        error "Clipboard2Img: Unsupported compression type '$compression' for bitcount value $bitcount"
                    }
                } elseif { $bitcount == 24 } {
                    set colorTableSize $clrused
                } else {
                    error "Clipboard2Img: Unsupported value '$bitcount' in bitmap bitcount field"
                }

                set fileHdrSize 14                 ; # sizeof(BITMAPFILEHEADER)
                set bitmapFileOffset [expr {$fileHdrSize+$size+($colorTableSize*4)}]
                set data [binary format "a2 i x2 x2 i" \
                         "BM" [expr {$fileHdrSize + [string length $clipData]}] $bitmapFileOffset]
                append data $clipData

                set retVal [catch { $phImg put $data -format [GetImgFormat $fmtName] } errMsg]
                if { $retVal == 0 } {
                    set foundFmt true
                } else {
                    error "Clipboard2Img: $errMsg"
                }
            } else {
                set retVal [catch { $phImg put $clipData -format [GetImgFormat $fmtName] } errMsg]
                if { $retVal == 0 } {
                    set foundFmt true
                } else {
                    error "Clipboard2Img: $errMsg"
                }
            }
            if { $foundFmt == true } {
                break
            }
        }
        twapi::close_clipboard

        if { $foundFmt == false } {
            image delete $phImg
            error "Clipboard2Img: Invalid or no content in clipboard"
        }
        return $phImg
    }

    proc Clipboard2File { fileName } {
        # Copy the contents of the Windows clipboard into a photo image
        # and save the image to file "fileName". The extension of the filename
        # determines the image file format.
        set img [Clipboard2Img]

        if { [string length $fileName] != 0 } {
            set fmtStr [poImgType GetFmtByExt [file extension $fileName]] 
            set optStr [poImgType GetOptByFmt $fmtStr "write"]
            $img write $fileName -format [list $fmtStr {*}$optStr]
        }
        image delete $img
    }

    proc Img2Clipboard { phImg args } {
        # Copy photo image "phImg" into Windows clipboard.
        variable sPo

        if { ! [poMisc HavePkg "twapi"] } {
            error "Img2Clipboard: Twapi extension not available"
        }
        set fmtNameList [list]
        if { [llength $args] == 0 } {
            set fmtNameList [list "CF_DIB"]
        } else {
            foreach arg $args {
                set fmtName [string toupper $arg]
                if { [info exists sPo(copy,$fmtName)] } {
                    lappend fmtNameList $fmtName
                } else {
                    error "Img2Clipboard: Unknown clipboard format \"$arg\" specified."
                }
            }
        }
        set retVal [catch { twapi::open_clipboard }]
        if { $retVal != 0 } {
            error "Img2Clipboard: Clipboard cannot be opened"
        }
        twapi::empty_clipboard

        foreach fmtName $fmtNameList {
            set retVal [catch { $phImg data -format [GetImgFormat $fmtName] } imgData]
            if { $retVal == 0 } {
                # The Img extension returns image data as base64 encoded data. Pure Tk does not.
                if { [poMisc HavePkg "Img"] } {
                    if { $fmtName eq "CF_DIB" } {
                        # First 14 bytes are bitmapfileheader - get rid of this
                        twapi::write_clipboard $sPo(copy,$fmtName) [string range [binary decode base64 $imgData] 14 end]
                    } else {
                        twapi::write_clipboard $sPo(copy,$fmtName) [binary decode base64 $imgData]
                    }
                } else {
                    twapi::write_clipboard $sPo(copy,$fmtName) $imgData
                }
            } else {
                error "Img2Clipboard: $imgData"
            }
        }
        twapi::close_clipboard
    }
}

poWinCapture Init
