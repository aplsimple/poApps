# Module:         poRawParse
# Copyright:      Paul Obermeier 2014-2020 / paul@poSoft.de
# First Version:  2014 / 02 / 04
#
# Distributed under BSD license.
#
# Module for reading and writing of RAW image files with pure Tcl.

namespace eval poRawParse {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetImageHeader PutImageHeader
    namespace export GetImageData PutImageData
    namespace export ReadImageHeader ReadImageFile WriteImageFile

    #
    # Utility procedures.
    #

    proc _GetNativeByteOrder {} {
        if { $::tcl_platform(byteOrder) eq "littleEndian" } {
            return "Intel"
        } else {
            return "Motorola"
        }
    }

    proc _GetPixelSize { pixelType } {
        if { $pixelType eq "float" } {
            return 4
        } elseif { $pixelType eq "short" } {
            return 2
        } elseif { $pixelType eq "byte" } {
            return 1
        } else {
            error "Invalid PixelType value: $pixelType (must be byte, short or float)"
        }
    }

    proc _GetScanFormat { pixelType byteOrder } {
        if { $pixelType eq "float" } {
            if { $byteOrder eq "Intel" } {
                set scanFmt "r"
            } else {
                set scanFmt "R"
            }
        } elseif { $pixelType eq "short" } {
            if { $byteOrder eq "Intel" } {
                set scanFmt "su"
            } else {
                set scanFmt "Su"
            }
        } elseif { $pixelType eq "byte" } {
            set scanFmt "cu"
        } else {
            error "Invalid PixelType value: $pixelType (must be byte, short or float)"
        }
        return $scanFmt
    }

    proc _FormatHeaderLine { fmt val } {
        set HEADLEN 20
        set headerLine [format $fmt $val]
        while { [string length $headerLine] < [expr { $HEADLEN -1 }] } {
            append headerLine " "
        }
        append headerLine "\n"
        return $headerLine
    }

    #
    # Image header read/write procedures.
    #

    proc GetImageHeader { fp { fileName "RawData" } } {
        # Get the header of a RAW image file.
        #
        # fp       - File pointer of the RAW image.
        # fileName - File name of the RAW image, if appropriate.
        #
        # Return the header information as a dictionary.
        #
        # See ReadImageHeader for a description of the dictionary elements.
        #
        # If the header contains invalid information, an error is thrown.
        #
        # See also: ReadImageHeader PutImageHeader

        if { [gets $fp line] >= 0 } {
            scan $line "Magic=%s" magic
            if { $magic ne "RAW" } {
                error "Invalid Magic value: $magic (must be RAW)"
            }
        } else {
            error "Error while trying to parse Magic keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "Width=%d" width
            if { $width <= 0 } {
                error "Invalid Width value: $width (must be greater than zero)"
            }
        } else {
            error "Error while trying to parse Width keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "Height=%d" height
            if { $height <= 0 } {
                error "Invalid Height value: $height (must be greater than zero)"
            }
        } else {
            error "Error while trying to parse Height keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "NumChan=%d" numChan
            if { $numChan <= 0 || $numChan > 4 } {
                error "Invalid NumChan value: $numChan (must be in 1..4)"
            }
        } else {
            error "Error while trying to parse NumChan keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "ByteOrder=%s" byteOrder
            if { $byteOrder ne "Intel" && $byteOrder ne "Motorola" } {
                error "Invalid ByteOrder value: $byteOrder (must be Intel or Motorola)"
            }
        } else {
            error "Error while trying to parse ByteOrder keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "ScanOrder=%s" scanOrder
            if { $scanOrder ne "TopDown" && $scanOrder ne "BottomUp" } {
                error "Invalid ScanOrder value: $scanOrder (must be TopDown or BottomUp)"
            }
        } else {
            error "Error while trying to parse ScanOrder keyword"
        }
        if { [gets $fp line] >= 0 } {
            scan $line "PixelType=%s" pixelType
            if { $pixelType ne "byte" && $pixelType ne "short" && $pixelType ne "float" } {
                error "Invalid PixelType value: $pixelType (must be byte, short or float)"
            }
        } else {
            error "Error while trying to parse PixelType keyword"
        }
        set headerDict [dict create]

        # Store the values contained in the header.
        dict set headerDict Magic     $magic
        dict set headerDict Width     $width
        dict set headerDict Height    $height
        dict set headerDict NumChan   $numChan
        dict set headerDict ByteOrder $byteOrder
        dict set headerDict ScanOrder $scanOrder
        dict set headerDict PixelType $pixelType

        # Calculate derived information from the header values.
        set pixelSize [_GetPixelSize $pixelType]
        set scanFmt   [_GetScanFormat $pixelType $byteOrder]
        dict set headerDict PixelSize  $pixelSize
        dict set headerDict ScanFormat $scanFmt
        dict set headerDict NumPixel   [expr { $width * $height }]
        dict set headerDict NumByte    [expr { $width * $height * $numChan * $pixelSize }]
        dict set headerDict FileName   $fileName

        return $headerDict
    }

    proc _CreateHeaderDictFromOptions { optStr fileName } {
        set headerDict [dict create]
        set useHeader  true

        foreach { key val } [poMisc SplitMultSpaces $optStr] {
            switch -exact -- $key {
                "-useheader" {
                    set useHeader $val
                }
                "-width" {
                    set width $val
                }
                "-height" {
                    set height $val
                }
                "-nchan" {
                    set numChan $val
                }
                "-scanorder" {
                    set scanOrder $val
                }
                "-byteorder" {
                    set byteOrder $val
                }
                "-pixeltype" {
                    set pixelType $val
                }
            }
        }

        if { ! $useHeader } {
            # Store the values contained in the header.
            dict set headerDict Magic     "RAW"
            dict set headerDict Width     $width
            dict set headerDict Height    $height
            dict set headerDict NumChan   $numChan
            dict set headerDict ByteOrder $byteOrder
            dict set headerDict ScanOrder $scanOrder
            dict set headerDict PixelType $pixelType

            # Calculate derived information from the header values.
            set pixelSize [_GetPixelSize $pixelType]
            set scanFmt   [_GetScanFormat $pixelType $byteOrder]
            dict set headerDict PixelSize  $pixelSize
            dict set headerDict ScanFormat $scanFmt
            dict set headerDict NumPixel   [expr { $width * $height }]
            dict set headerDict NumByte    [expr { $width * $height * $numChan * $pixelSize }]
            dict set headerDict FileName   $fileName
        }
        return $headerDict
    }

    proc ReadImageHeader { rawImgFile } {
        # Read the header of a RAW image file.
        #
        # rawImgFile - File name of the RAW image.
        #
        # Return the header information as a dictionary containing the following keys:
        # Magic Width Height NumChan ByteOrder ScanOrder PixelType
        # PixelSize ScanFormat NumPixel NumByte
        #
        # The first seven keys have identical names and values as listed in the file header.
        # PixelSize and ScanFormat are derived information values computed from the other keys.
        #
        # Magic      Magic string "RAW" for easy identification of file format.
        # Width      Width of the image in pixel (integer).
        # Height     Height of the image in pixel (integer).
        # NumChan    Number of channels contained in image (integer).
        # ByteOrder  "Motorola" for big-endian, "Intel" for little-endian architecture.
        # ScanOrder  "TopDown" or "BottomUp"
        # PixelType  "byte" for 1-byte unsigned integers, "short" for 2-byte unsigned integers,
        #            "float" for 4-byte single precision floating point values.
        # PixelSize  Pixel size in bytes: 1, 2 or 4.
        # ScanFormat Format string for Tcl "binary" command to read image data.
        # NumPixel   Number of pixels contained in image (integer).
        # NumByte    Number of bytes contained in image data (integer).
        #
        # If the header contains invalid information, an error is thrown.
        #
        # See also: GetImageHeader ReadImageFile

        set retVal [catch {open $rawImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $rawImgFile"
        }
        fconfigure $fp -translation binary
        set headerDict [GetImageHeader $fp [file tail $rawImgFile]]
        close $fp
        return $headerDict
    }

    proc PutImageHeader { fp headerDict } {
        set headerStr ""
        append headerStr [_FormatHeaderLine "Magic=%s"     [dict get $headerDict Magic]]
        append headerStr [_FormatHeaderLine "Width=%d"     [dict get $headerDict Width]]
        append headerStr [_FormatHeaderLine "Height=%d"    [dict get $headerDict Height]]
        append headerStr [_FormatHeaderLine "NumChan=%d"   [dict get $headerDict NumChan]]
        append headerStr [_FormatHeaderLine "ByteOrder=%s" [dict get $headerDict ByteOrder]]
        append headerStr [_FormatHeaderLine "ScanOrder=%s" [dict get $headerDict ScanOrder]]
        append headerStr [_FormatHeaderLine "PixelType=%s" [dict get $headerDict PixelType]]
        puts -nonewline $fp $headerStr
    }

    #
    # Image data read/write procedures.
    #

    proc GetImageData { fp headerDict dataDict } {
        upvar 1 $dataDict myDict

        set numBytes [dict get $headerDict NumByte]
        dict set myDict Data [read $fp $numBytes]
    }

    proc PutImageData { fp imgDict } {
        upvar 1 $imgDict myDict

        set numBytes [dict get $myDict Header NumByte]
        puts -nonewline $fp [dict get $myDict Data]
    }

    proc ReadImageFile { rawImgFile { optStr "" } } {
        # Read a RAW image file into a dictionary.
        #
        # rawImgFile - File name of the RAW image.
        # optStr     - Option string for reading the RAW image.
        #              This is the value as returned by poImgType GetOptByFmt "raw" "read".
        #
        # Return the image data as a Tcl dictionary containing 2 keys: header and data.
        # Key "Data" contains the raw image data information as a binary string.
        # Key "Header" contains additional information about the image and is itself a dictionary.
        #
        # See GetImageHeader for the description of the header dictionary.
        #
        # See also: ReadImageHeader WriteImageFile

        set retVal [catch {open $rawImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $rawImgFile"
        }
        fconfigure $fp -translation binary

        set imgDict [dict create]
        if { [poType IsImage $rawImgFile "raw"] } {
            set headerDict [GetImageHeader $fp [file tail $rawImgFile]]
        } else {
            set headerDict [_CreateHeaderDictFromOptions $optStr $rawImgFile]
            if { [dict size $headerDict] == 0 } {
                error "Cannot parse file $rawImgFile. Option -useheader is set to true, but file does not have RAW header"
            }
        }
        GetImageData $fp $headerDict imgDict
        dict append imgDict Header $headerDict

        close $fp
        return $imgDict
    }

    proc WriteImageFile { imgDict rawImgFile } {
        # Write the values of a matrix into a RAW image file.
        #
        # rawImgFile - File name of the image.
        #
        # No return value.
        #
        # See also: ReadImageFile

        set retVal [catch {open $rawImgFile "w"} fp]
        if { $retVal != 0 } {
            error "Cannot open output file $rawImgFile"
        }
        fconfigure $fp -translation binary

        PutImageHeader $fp [dict get $imgDict Header]
        PutImageData   $fp imgDict
    }
}
