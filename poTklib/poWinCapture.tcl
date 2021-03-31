# Module:         poWinCapture
# Copyright:      Paul Obermeier 2004-2020 / paul@poSoft.de
# First Version:  2004 / 10 / 19
#
# Distributed under BSD license.
#
# Module for capturing window contents into an image or file.

namespace eval poWin {
    variable ns [namespace current]

    namespace ensemble create

    namespace export InitCapture
    namespace export Windows2Img
    namespace export Windows2File
    namespace export Canvas2Img
    namespace export Canvas2File
    namespace export Clipboard2Img
    namespace export Clipboard2File
    namespace export Img2Clipboard

    proc InitCapture {} {
        variable poWinCapInt

        set retVal [catch {package require Img} poWinCapInt(Img,version)] 
        set poWinCapInt(Img,avail) [expr !$retVal]
        set retVal [catch {package require twapi} poWinCapInt(twapi,version)] 
        set poWinCapInt(twapi,avail) [expr !$retVal]
        set retVal [catch {package require base64} poWinCapInt(base64,version)] 
        set poWinCapInt(base64,avail) [expr !$retVal]
    }

    proc Windows2Img { win } {
        variable poWinCapInt

        regexp -- {([0-9]*)x([0-9]*)\+([0-9]*)\+([0-9]*)} \
                  [winfo geometry $win] - w h x y

        if { $poWinCapInt(twapi,avail) } {
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
        } elseif { $poWinCapInt(Img,avail) } {
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
            $img write $fileName -format "$fmtStr $optStr"
        }
        image delete $img
    }

    proc Canvas2Img { canv } {
        variable poWinCapInt

        set region [$canv cget -scrollregion]
        set xsize [lindex $region 2]
        set ysize [lindex $region 3]
        set img [image create photo -width $xsize -height $ysize]
        if { !$poWinCapInt(Img,avail) } {
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
            $img write $fileName -format "$fmtStr $optStr"
        }
        image delete $img
    }

    proc Clipboard2Img {} {
        # Copy the contents of the Windows clipboard into a photo image.
        # Return the photo image identifier.
        variable poWinCapInt

        if { !$poWinCapInt(twapi,avail) } {
            error "Twapi extension not available"
        }

        twapi::open_clipboard

        # Assume clipboard content is in format 8 (CF_DIB)
        set retVal [catch {twapi::read_clipboard 8} clipData]
        if { $retVal != 0 } {
            error "Invalid or no content in clipboard"
        }

        # First parse the bitmap data to collect header information
        binary scan $clipData "iiissiiiiii" \
               size width height planes bitcount compression sizeimage \
               xpelspermeter ypelspermeter clrused clrimportant

        # We only handle BITMAPINFOHEADER right now (size must be 40)
        if {$size != 40} {
            error "Unsupported bitmap format. Header size=$size"
        }

        # We need to figure out the offset to the actual bitmap data
        # from the start of the file header. For this we need to know the
        # size of the color table which directly follows the BITMAPINFOHEADER
        if {$bitcount == 0} {
            error "Unsupported format: implicit JPEG or PNG"
        } elseif {$bitcount == 1} {
            set color_table_size 2
        } elseif {$bitcount == 4} {
            # TBD - Not sure if this is the size or the max size
            set color_table_size 16
        } elseif {$bitcount == 8} {
            # TBD - Not sure if this is the size or the max size
            set color_table_size 256
        } elseif {$bitcount == 16 || $bitcount == 32} {
            if {$compression == 0} {
                # BI_RGB
                set color_table_size $clrused
            } elseif {$compression == 3} {
                # BI_BITFIELDS
                set color_table_size 3
            } else {
                error "Unsupported compression type '$compression' for bitcount value $bitcount"
            }
        } elseif {$bitcount == 24} {
            set color_table_size $clrused
        } else {
            error "Unsupported value '$bitcount' in bitmap bitcount field"
        }

        set phImg [image create photo]
        set filehdr_size 14                 ; # sizeof(BITMAPFILEHEADER)
        set bitmap_file_offset [expr {$filehdr_size+$size+($color_table_size*4)}]
        set filehdr [binary format "a2 i x2 x2 i" \
                     "BM" [expr {$filehdr_size + [string length $clipData]}] \
                     $bitmap_file_offset]

        append filehdr $clipData
        $phImg put $filehdr -format bmp

        twapi::close_clipboard
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
            $img write $fileName -format "$fmtStr $optStr"
        }
        image delete $img
    }

    proc Img2Clipboard { phImg } {
        # Copy photo image "phImg" into Windows clipboard.
        variable poWinCapInt

        if { !$poWinCapInt(base64,avail) } {
            error "Base64 extension not available"
        }
        if { !$poWinCapInt(twapi,avail) } {
            error "Twapi extension not available"
        }
        # First 14 bytes are bitmapfileheader - get rid of this
        set data [string range [base64::decode [$phImg data -format bmp]] 14 end]
        twapi::open_clipboard
        twapi::empty_clipboard
        twapi::write_clipboard 8 $data
        twapi::close_clipboard
    }
}

poWin InitCapture
