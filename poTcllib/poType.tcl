# Module:         poType
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 07 / 01
#
# Distributed under BSD license.
#
# Module with some simple heuristics to determine file types.

namespace eval poType {
    variable ns [namespace current]

    namespace ensemble create
    
    namespace export Init
    namespace export GetImageInfo GetFileType
    namespace export IsText IsBinary IsImage

    proc Init {} {
    }

    proc GetImageInfo { fileName } {
        # Get type information about an image file.
        #
        # fileName - The name of the image file.
        #
        # The procedure detects all image formats supplied by the Img extension.
        # It returns a dictionary containing the image format, width and height, if the file
        # contains known image content. Optionally a subformat and the endianess of the image
        # is returned.
        # The following keys can be in the dictionary:
        # size:      File size in bytes.
        # subfmt:    Image format string. Supported formats are:
        #            bmp, dted, flir, gif, ico, jpeg, pcx, png,
        #            ppm, raw, sgi, sun, tiff, tga, xbm, xpm
        #            Note, that the subfmt string is the same as needed for the
        #            "-format" option of the Img extension.
        # imgsubfmt: An optional subformat string. Example: jfif or exif for jpeg images.
        # width:     Number of columns of the image.
        # height:    Number of rows of the image.
        # xdpi:      Horizontal number of dots per inch.
        # ydpi:      Vertical number of dots per inch.
        # subimgs:   Number of sub-images of the image.
        # endian:    Endianess of the image data. Possible values: bigendian, smallendian.
        # 
        # If the file format could not be identified, {"none" -1 -1} is returned.
        #
        # See also: GetFileType

        set imgDict [dict create]

        if { ! [file isfile $fileName] } {
            return $imgDict
        }
        set fileSize [file size $fileName]
        dict set imgDict size $fileSize
        if { $fileSize == 0 } {
            return $imgDict
        }

        if { [ catch {
            set fp [open $fileName "r"]
            fconfigure $fp -translation binary
        } errMsg ] } {
            catch { ::close $fp }
            return $imgDict
        }

        set test [read $fp 1024]

        if { [string match "GIF8?a*" $test] } {
            binary scan [string range $test 6 9] ss width height
            set imgFmt "gif"

        } elseif { [string equal -length 16 $test "\x89PNG\r\n\32\n\0\0\0\rIHDR"] } {
            binary scan [string range $test 16 23] II width height
            set xdpi 0
            set ydpi 0
            set dpiChunkIndex [string first "pHYs" $test]
            if { $dpiChunkIndex >= 0 } {
                set dpiChunk [string range $test [expr {$dpiChunkIndex + 4}] [expr {$dpiChunkIndex + 4 + 9}]]
                binary scan $dpiChunk IIc xdpi ydpi unit
                if { $unit == 1 } {
                    set xdpi [expr { int( $xdpi * 0.0254 + 0.5 )}]
                    set ydpi [expr { int( $ydpi * 0.0254 + 0.5 )}]
                }
            }
            set imgFmt "png"

        } elseif { [string match "\xFF\xD8\xFF*" $test] } {
            binary scan $test x3H2x2a5 marker txt
            if { $marker eq "e0" && $txt eq "JFIF\x00" } {
                set imgSubFmt "jfif"
            } elseif { $marker eq "e1" && $txt eq "Exif\x00" } {
                set imgSubFmt "exif"
            }
            if { [string length $test] > 18 } {
                binary scan [string range $test 13 18] cSS unit xdpi ydpi
                if { $unit == 1 } {
                    # Dots per inch.
                } elseif { $unit == 2 } {
                    # Dots per centimeter
                    set xdpi [expr {int ($xdpi * 2.54 + 0.5)}]
                    set ydpi [expr {int ($ydpi * 2.54 + 0.5)}]
                } else {
                    set xdpi 0
                    set ydpi 0
                }
            }
            
            seek $fp 0 start
            read $fp 2
            while { ! [eof $fp] } {
                # Search for the next marker, read the marker type byte, and throw out
                # any extra "ff"'s.
                while { [read $fp 1] ne "\xFF" } {
                    if [eof $fp] break; 
                }
                if [eof $fp] break; 
                while { [set byte [read $fp 1]] eq "\xFF"} {
                    if [eof $fp] break; 
                }
                if [eof $fp] break; 

                if { $byte in { \xc0 \xc1 \xc2 \xc3 \xc5 \xc6 \xc7
                                \xc9 \xca \xcb \xcd \xce \xcf }} {
                    # This is the SOF marker; read a chunk of data containing the dimensions.
                    binary scan [read $fp 7] x3SS height width
                    break
                } else {
                    # This is not the the SOF marker; read in the offset of the next marker.
                    binary scan [read $fp 2] S offset

                    # The offset includes itself own two bytes so subtract them, then move
                    # ahead to the next marker.
                    seek $fp [expr {($offset & 0xffff) - 2}] current
                }
            }
            set imgFmt "jpeg"

        } elseif { [string match "*jP*ftypjp*" $test] } {
            set imgFmt "jp2"

        } elseif { [string match "II\*\x00*" $test] || [string match "MM\x00\**" $test] } {
            if { [string match "MM\x00\**" $test] } {
                set endian bigendian
            } else {
                set endian smallendian
            }

            set byteFmt "c"
            if { $endian eq "smallendian" } {
                set longFmt   "i"
                set shortFmt  "s"
                set doubleFmt "q"
            } else {
                set longFmt   "I"
                set shortFmt  "S"
                set doubleFmt "Q"
            }
            set typesFmt(1) $byteFmt
            set typesFmt(3) $shortFmt
            set typesFmt(4) $longFmt
            set typesFmt(5) $doubleFmt

            seek $fp 4 start
            set tiff [read $fp 4]
            binary scan $tiff $longFmt offset

            seek $fp $offset start
            set tiff [read $fp 2]
            binary scan $tiff $shortFmt numDirs

            set xdpi 0
            set ydpi 0
            while { $numDirs > 0 } {
                set tiff [read $fp 12]
                binary scan [string range $tiff 0 1] $shortFmt tag
                if { $tag == 256 || $tag == 257 } {
                    # TIFFTAG_IMAGEWIDTH  256
                    # TIFFTAG_IMAGELENGTH 257
                    binary scan [string range $tiff 2 3] $shortFmt type
                    if { [info exists typesFmt($type)] } {
                        binary scan [string range $tiff 8 11] $typesFmt($type) val
                        if { $tag == 256 } {
                            set width $val
                        } else {
                            set height $val
                        }
                    }
                }
                if { $tag == 296 || $tag == 282 || $tag == 283 } {
                    # TIFFTAG_RESOLUTIONUNIT 296
                    # TIFFTAG_XRESOLUTION    282
                    # TIFFTAG_YRESOLUTION    283
                    binary scan [string range $tiff 2 3] $shortFmt type
                    if { $type == 3 } {
                        binary scan [string range $tiff 8 11] $shortFmt resUnit 
                        if { $resUnit == 3 } {
                            # Units are centimeters.
                            set xdpi [expr {$xdpi * 2.54 + 0.5}]
                            set ydpi [expr {$ydpi * 2.54 + 0.5}]
                        }
                    } elseif { $type == 5 } {
                        binary scan [string range $tiff 8 11] $longFmt valueOffset
                        set curPos [tell $fp]
                        seek $fp $valueOffset start
                        set tiff [read $fp 8]
                        binary scan [string range $tiff 0 3] $longFmt nominator
                        binary scan [string range $tiff 4 7] $longFmt denominator
                        set dpi [expr {double($nominator) / double($denominator)}]
                        if { $tag == 282 } {
                            set xdpi $dpi
                        } elseif { $tag == 283 } {
                            set ydpi $dpi
                        }
                        seek $fp $curPos start
                    }
                }
                if { [info exists width] && [info exists height] && \
                     [info exists xdpi] && [info exists ydpi] && [info exists resUnit] } {
                    break
                }
                incr numDirs -1
            }
            set xdpi [expr {int ($xdpi)}]
            set ydpi [expr {int ($ydpi)}]
            set imgFmt "tiff"

        } elseif { [string match "P\[12356\]\[\x0a\x0d\]*" $test] } {
            if [regexp -- {P[12356]\s*#} $test] {
                seek $fp 0 start
                gets $fp line
                while { [gets $fp line] >= 0 } {
                    if { ! [string match "#*" $line] } {
                        break
                    }
                }
                scan $line "%d %d" width height
            } else {
                regexp -- {(P[12356])\s*(\d+)\s+(\d+)} $test -> fmt width height
            }
            if { [string match "P1*" $test] } {
                set imgFmt "pbm"
            } else {
                set imgFmt "ppm"
            }

        } elseif { [string match "/\* XPM*" $test] } {
            regexp -- {(\/\* XPM.*\")(\d+)\s+(\d+)} $test -> dummy width height
            set imgFmt "xpm"

        } elseif { [string match "#define *" $test] } {
            regexp -line -- {(#define .*)\s+(\d+)\s+(#define .*)\s+(\d+)\s+} $test \
                   -> dummy1 width dummy2 height
            set imgFmt "xbm"

        } elseif { [string match "\x59\xa6\x6a\x95*" $test] } {
            binary scan [string range $test 4 12] II width height
            set imgFmt "sun"

        } elseif { [string match "\x01\xda*" $test] } {
            binary scan [string range $test 6 9] SS width height
            set imgFmt "sgi" 
            set endian "bigendian"

        } elseif { [string match "\xda\x01*" $test] } {
            binary scan [string range $test 6 9] ss width height
            set imgFmt "sgi" 
            set endian "smallendian"

        } elseif { [regexp -- {^[\x0a].+.+[\x01\x08]} $test] } {
            binary scan [string range $test 4 12] ssss x1 y1 x2 y2
            set width  [expr {$x2 - $x1 + 1}]
            set height [expr {$y2 - $y1 + 1}]
            binary scan [string range $test 12 16] ss xdpi ydpi
            set imgFmt "pcx"

        } elseif { [string match "BM*" $test] && ([string range $test 6 9] eq "\x00\x00\x00\x00") } {
            binary scan [string range $test 14 14] c bmpType
            if { $bmpType == 40 || $bmpType == 64 } {
                # BITMAPINFOHEADER has a size of 40 bytes
                binary scan [string range $test 18 25] ii width height
                binary scan [string range $test 38 45] ii xdpi ydpi
                set xdpi [expr { int( $xdpi * 0.0254 + 0.5 )}]
                set ydpi [expr { int( $ydpi * 0.0254 + 0.5 )}]
            } elseif { $bmpType == 12 } {
                # BITMAPCOREHEADER has a size of 12 bytes
                binary scan [string range $test 18 21] ss width height
            } elseif { $bmpType == 108 } {
                # BITMAPV4HEADER has a size of 108 bytes
                binary scan [string range $test 18 25] ii width height
            } elseif { $bmpType == 124 } {
                # BITMAPV5HEADER has a size of 124 bytes
                binary scan [string range $test 18 25] ii width height
            }
            set imgFmt "bmp"

        } elseif { [string match "\x00\x00\x01\x00*" $test] } {
            binary scan [string range $test 4 8] scc numImgs width height
            set imgFmt "ico"

        } elseif { [string equal -length 3 "UHL" $test] && \
                   [string equal -length 3 "DSI" [string range $test 80 83]] } {
            set offset1 [expr {80 + 281}]
            set offset2 [expr {$offset1 + 4}]
            scan [string range $test $offset1 [expr {$offset1+3}]] "%d" height
            scan [string range $test $offset2 [expr {$offset2+3}]] "%d" width
            set imgFmt "dted"

        } elseif { [string match "Magic=RAW*" $test] } {
            regexp -- {Magic=RAW\s+(Width=)(\d+)\s+(Height=)(\d+)\s+} $test \
                   -> dummy1 width dummy2 height
            set imgFmt "raw"

        } elseif { [string match "FPF Public Image Format*" $test] } {
            binary scan [string range $test 44 48] ss width height
            set imgFmt "flir"

        } elseif { [regexp -- {^.{1}[\x00\x01][\x01-\x03\x09-\x0b].{13}[\x08\x0f\x10\x18\x20]} $test] } {
            binary scan [string range $test 12 16] ss width height
            set imgFmt "tga"

        } elseif { [string match "*<svg*" $test] } {
            set imgFmt "svg"
        }
        close $fp
        if { ! [info exists imgFmt] } {
            return $imgDict
        } else {
            dict set imgDict subfmt $imgFmt
        }
        if { ! [info exists width] || $width <= 0 } {
            set width -1
        }
        if { ! [info exists height] || $height <= 0 } {
            set height -1
        }
        dict set imgDict width  $width
        dict set imgDict height $height
        if { ! [info exists xdpi] || $xdpi < 0 } {
            set xdpi 0
        }
        if { ! [info exists ydpi] || $ydpi < 0 } {
            set ydpi 0
        }
        dict set imgDict xdpi $xdpi
        dict set imgDict ydpi $ydpi
        if { [info exists imgSubFmt] } {
            dict set imgDict imgsubfmt $imgSubFmt
        }
        if { [info exists numImgs] } {
            dict set imgDict subimgs $numImgs
        }
        if { [info exists endian] } {
            dict set imgDict endian $endian
        }
        return $imgDict
    }

    proc GetFileType { fileName } {
        # Determine type of a file.
        #
        # fileName -  Name of the file to test.
        #
        # Note: This is an enhanced version of procedure ::fileutil::fileType from tcllib.
        #
        # Return the type of the file. 
        # May be a list if multiple tests are positive (eg, a file could be both a directory 
        # and a link).  In general, the list proceeds from most general (eg, binary) to most
        # specific (eg, gif), so the full type for a GIF file would be "binary graphic gif".
        #
        # type: file, directory
        # subtype: link, (optional)
        # style: binary, text
        # substyle: dos, unix (optional)
        # fmt: audio, compressed, crypt, executable, html, graphic,
        #      metakit, pdf, ps, script, tkdiagram, xml
        # subfmt: String (optional)
        #
        # At present, the following types can be detected:
        #    directory
        #    empty
        #    binary
        #    text
        #    script <interpreter>
        #    executable elf dos pe ne dos pe ne
        #    binary graphic [bmp, dted, flir, gif, ico, jpeg, pcx, png,
        #                    ppm, raw, sgi, sun, svg, tiff, tga, xbm, xpm]
        #   ps, eps, pdf
        #   html
        #   xml <doctype>
        #   message pgp
        #   bzip, gzip
        #   gravity_wave_data_frame
        #   link
        #
        # See also: GetImageInfo

        if { ! [file exists $fileName] } {
            set errMsg "File '$fileName' does not exists"
            return -code error $errMsg
        }
        if { [file isdirectory $fileName] } {
            dict set typeDict type "directory"
            if { ! [catch {file readlink $fileName}] } {
                dict set typeDict subtype "link"
            }
            return $typeDict
        } else {
            dict set typeDict type "file"
        }

        set fileSize [file size $fileName]
        dict set typeDict size $fileSize
        if { $fileSize == 0 } {
            if { ! [catch {file readlink $fileName}] } {
                dict set typeDict subtype "link"
            }
            return $typeDict
        }

        if { [ catch {
            set fp [open $fileName "r"]
            fconfigure $fp -translation binary
            fconfigure $fp -buffersize 1024
            fconfigure $fp -buffering full
            set test [read $fp 1024]
            ::close $fp
        } errMsg ] } {
            catch { ::close $fp }
            return $typeDict
        }

        set binaryRegExp {[\x00-\x08\x0b\x0e-\x1f]}
        if { [ regexp -- $binaryRegExp $test ] } {
            dict set typeDict style "binary"
            set isBinary 1
        } else {
            dict set typeDict style "text"
            set isBinary 0
            set dosEol "*\r\n*"
            if { [string match $dosEol $test] } {
                dict set typeDict substyle "dos"
            } else {
                dict set typeDict substyle "unix"
            }
        }

        if { [regexp -- {^\#\!\s*(\S+)} $test -> terp] } {
            lappend type script $terp
            dict set typeDict fmt    "script"
            dict set typeDict subfmt $terp

        } elseif { $isBinary && [ regexp -- {^[\x7F]ELF} $test ] } {
            dict set typeDict fmt    "executable"
            dict set typeDict subfmt "elf"

        } elseif { $isBinary && [string match "MZ*" $test] } {
            if { [scan [string index $test 24] %c] < 64 } {
                set subFmt "dos"
            } else {
                binary scan [string range $test 60 61] s next
                set sig [string range $test $next [expr {$next + 1}]]
                if { $sig eq "NE" || $sig eq "PE" } {
                    set subFmt [string tolower $sig]
                } else {
                    set subFmt "dos"
                }
            }
            dict set typeDict fmt    "executable"
            dict set typeDict subfmt $subFmt

        } elseif { $isBinary && [string match "BZh91AY\&SY*" $test] } {
            dict set typeDict fmt    "compressed"
            dict set typeDict subfmt "bzip"

        } elseif { $isBinary && [string match "\x1f\x8b*" $test] } {
            dict set typeDict fmt    "compressed"
            dict set typeDict subfmt "gzip"

        } elseif { $isBinary && [string range $test 257 262] eq "ustar\x00" } {
            dict set typeDict fmt    "compressed"
            dict set typeDict subfmt "tar"

        } elseif { $isBinary && [string match "\x50\x4b\x03\x04*opendocument*" $test] } {
            dict set typeDict fmt    "document"
            dict set typeDict subfmt "odt"

        } elseif { $isBinary && [string match "\x50\x4b\x03\x04*" $test] } {
            dict set typeDict fmt    "compressed"
            dict set typeDict subfmt "zip"

        } elseif { $isBinary && [string match "icns*" $test] } {
            dict set typeDict fmt    "graphic"
            dict set typeDict subfmt "icns"
            dict set typeDict endian "bigendian"

        } elseif { $isBinary && [string match "snci*" $test] } {
            dict set typeDict fmt    "graphic"
            dict set typeDict subfmt "icns"
            dict set typeDict endian "smallendian"

        } elseif { [string match "\%PDF\-*" $test] } {
            dict set typeDict fmt   "pdf"
            dict set typeDict style "binary"

        } elseif { ! $isBinary && [string match -nocase "*\<html*\>*" $test] } {
            dict set typeDict fmt "html"

        } elseif { [string match "\%\!PS\-*" $test] } {
            dict set typeDict fmt "ps"
            lappend type ps
            if { [string match "* EPSF\-*" $test] } {
                dict set typeDict subfmt "eps"
            }

        } elseif { [regexp -- "tcl\\.tk//DSL diagram//EN//" $test]} {
            dict set typeDict fmt "tkdiagram"

        } elseif { [string match -nocase "*\<\?xml*" $test] } {
            dict set typeDict fmt "xml"
            if { [ regexp -nocase -- {\<\!DOCTYPE\s+(\S+)} $test -> doctype ] } {
                dict set typeDict subfmt $doctype
            }

        } elseif { ([regexp "\\\[manpage_begin " $test] &&
                   !([regexp -- {--- !doctools ---} $test] || [regexp -- "!tcl\.tk//DSL doctools//EN//" $test])) ||
                    ([regexp -- {--- doctools ---} $test]  || [regexp -- "tcl\.tk//DSL doctools//EN//" $test])} {
            dict set typeDict fmt "doctools"

        } elseif { ([regexp -- "\\\[toc_begin " $test] &&
                   !([regexp -- {--- !doctoc ---} $test] || [regexp -- "!tcl\.tk//DSL doctoc//EN//" $test])) ||
                    ([regexp -- {--- doctoc ---} $test]  || [regexp -- "tcl\.tk//DSL doctoc//EN//" $test])} {
            dict set typeDict fmt "doctoc"

        } elseif { ([regexp -- "\\\[index_begin " $test] &&
                   !([regexp -- {--- !docidx ---} $test] || [regexp -- "!tcl\.tk//DSL docidx//EN//" $test])) ||
                  ([regexp -- {--- docidx ---} $test] || [regexp -- "tcl\.tk//DSL docidx//EN//" $test])} {
            dict set typeDict fmt "docidx"

        } elseif { [string match {*BEGIN PGP MESSAGE*} $test] } {
            dict set typeDict fmt    "crypt"
            dict set typeDict subfmt "pgp"

        } elseif { $isBinary && [string match {IGWD*} $test] } {
            dict set typeDict fmt "gravity_wave_data_frame" ; # OPA TODO Check

        } elseif { [string match "JL\x1a\x00*" $test] && ([file size $fileName] >= 27) } {
            dict set typeDict fmt    "metakit"
            dict set typeDict endian "smallendian"

        } elseif { [string match "LJ\x1a\x00*" $test] && ([file size $fileName] >= 27) } {
            dict set typeDict fmt    "metakit"
            dict set typeDict endian "bigendian"

        } elseif { $isBinary && [string match "RIFF*" $test] && [string range $test 8 11] eq "WAVE" } {
            dict set typeDict fmt    "audio"
            dict set typeDict endian "wave"

        } elseif { $isBinary && [string match "ID3*" $test] } {
            dict set typeDict fmt    "audio"
            dict set typeDict endian "mpeg"

        } elseif { $isBinary && [binary scan $test S tmp] && [expr {$tmp & 0xFFE0}] == 65504 } {
            dict set typeDict fmt    "audio"
            dict set typeDict endian "mpeg"
        }

        # Check for an image.
        set imgDict [GetImageInfo $fileName]
        if { [dict exists $imgDict subfmt] } {
            dict set typeDict fmt "graphic"
            dict set typeDict subfmt [dict get $imgDict subfmt]
            dict set typeDict width  [dict get $imgDict width]
            dict set typeDict height [dict get $imgDict height]
            dict set typeDict xdpi   [dict get $imgDict xdpi]
            dict set typeDict ydpi   [dict get $imgDict ydpi]
            if { [dict exists $imgDict imgsubfmt] } {
                dict set typeDict imgsubfmt [dict get $imgDict imgsubfmt]
            }
            if { [dict exists $imgDict endian] } {
                dict set typeDict endian [dict get $imgDict endian]
            }
            if { [dict exists $imgDict subimgs] } {
                dict set typeDict subimgs [dict get $imgDict subimgs]
            }
        }

        if { ! [ catch {file readlink $fileName} ] } {
            dict set typeDict subtype "link"
        }

        return $typeDict
    }

    proc IsText { fileName { textType "" } } {
        # textType: dos unix html script xml
        set catchVal [catch {GetFileType $fileName} typeDict]
        if { $catchVal } {
            return false 
        } else {
            if { [dict exists $typeDict style] && [dict get $typeDict style] eq "text" } {
                if { $textType eq "" } {
                    return true
                } elseif { [dict exists $typeDict substyle] && [dict get $typeDict substyle] eq $textType } {
                    return true
                } elseif { [dict exists $typeDict fmt] && [dict get $typeDict fmt] eq $textType } {
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
        }
    }

    proc IsBinary { fileName { binaryType "" } } {
        set catchVal [catch {GetFileType $fileName} typeDict]
        if { $catchVal } {
            return false 
        } else {
            if { [dict exists $typeDict style] && [dict get $typeDict style] eq "binary" } {
                return true
            } else {
                return false
            }
        }
    }

    proc IsImage { fileName { imgFmt "" } } {
        set catchVal [catch {GetFileType $fileName} typeDict]
        if { $catchVal } {
            return false
        } else {
            if { [dict exists $typeDict fmt] && [dict get $typeDict fmt] eq "graphic" } {
                if { $imgFmt eq "" } {
                    return true
                } else {
                    if { [string equal -nocase [dict get $typeDict subfmt] $imgFmt] } {
                        return true
                    } else {
                        return false
                    }
                }
            } else {
                return false
            }
        }
    }
}

poType Init
