# Module:         poPpmParse
# Copyright:      Paul Obermeier 2020 / paul@poSoft.de
# First Version:  2020 / 05 / 14
#
# Distributed under BSD license.
#
# Module for reading and writing of PPM image files with pure Tcl.

namespace eval poPpmParse {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetImageHeader
    namespace export GetImageData
    namespace export ReadImageHeader ReadImageFile

    #
    # Utility procedures.
    #

    proc _GetTypeList {} {
        return [list "P2" "P3" "P5" "P6"]
    }

    proc _GetAsciiList {} {
        return [list true true false false]
    }

    proc _GetChanList {} {
        return [list 1 3 1 3]
    }

    proc _IsAscii { ppmType } {
        set ind [lsearch -exact [_GetTypeList] $ppmType]
        return [lindex [_GetAsciiList] $ind]
    }

    proc _GetNumChans { ppmType } {
        set ind [lsearch -exact [_GetTypeList] $ppmType]
        return [lindex [_GetChanList] $ind]
    }

    proc _GetPixelTypeName { maxColors } {
        if { $maxColors < 256 } {
            return "byte"
        } else {
            return "short"
        }
    }

    proc _GetPixelSize { pixelType } {
        if { $pixelType eq "short" } {
            return 2
        } elseif { $pixelType eq "byte" } {
            return 1
        } else {
            error "Invalid PixelType value: $pixelType (must be byte or short)"
        }
    }

    proc _GetScanFormat { pixelType byteOrder } {
        if { $pixelType eq "short" } {
            if { $byteOrder eq "Intel" } {
                set scanFmt "su"
            } else {
                set scanFmt "Su"
            }
        } elseif { $pixelType eq "byte" } {
            set scanFmt "cu"
        } else {
            error "Invalid PixelType value: $pixelType (must be byte or short)"
        }
        return $scanFmt
    }

    #
    # Image header read/write procedures.
    #

    proc GetImageHeader { fp { fileName "RawData" } } {
        # Get the header of a PPM image.
        #
        # fp       - File pointer of the PPM image.
        # fileName - File name of the PPM image, if appropriate.
        #
        # Return the header information as a dictionary.
        #
        # See ReadImageHeader for a description of the dictionary elements.
        #
        # If the header contains invalid information, an error is thrown.
        #
        # See also: ReadImageHeader PutImageHeader

        # Read the header lines (ASCII): Type, width and height, maximum color value.
        while { ! [info exists maxColor] } {
            if { [gets $fp line] < 0 } {
                error "Error while parsing PPM header"
            }
            set value [string trim $line]
            if { [string index $value 0] eq "#" } {
                continue
            }
            if { ! [info exists type] } {
                set type $value
                if { [lsearch -exact [_GetTypeList] $type] < 0 } {
                    error "Unsupported PPM type $type. Must be \"P2\", \"P3\", \"P5\", \"P6\"."
                }
            } elseif { ! [info exists width] } {
                scan $value "%d %d" width height
                if { $width <= 0 } {
                    error "Invalid width value: $width (must be greater than zero)"
                }
                if { $height <= 0 } {
                    error "Invalid height value: $height (must be greater than zero)"
                }
            } elseif { ! [info exists maxColor] } {
                scan $value "%d" maxColor
                if { $maxColor < 0 } {
                    error "Invalid value for maximum color: $maxColor (must be greater or equal to zero)"
                }
                if { $maxColor >= 65536 } {
                    error "Invalid value for maximum color: $maxColor (must be less than 65536)"
                }
            }
        }

        set headerDict [dict create]

        set pixelType [_GetPixelTypeName $maxColor]
        set numChan   [_GetNumChans $type]
        set byteOrder "Motorola"

        # Store the values contained in the header.
        dict set headerDict Magic     "PPM"
        dict set headerDict Width     $width
        dict set headerDict Height    $height
        dict set headerDict NumChan   $numChan
        dict set headerDict ByteOrder $byteOrder
        dict set headerDict ScanOrder "TopDown"
        dict set headerDict PixelType $pixelType

        # Calculate derived information from the header values.
        set pixelSize [_GetPixelSize  $pixelType]
        set scanFmt   [_GetScanFormat $pixelType $byteOrder]
        dict set headerDict PixelSize  $pixelSize
        dict set headerDict ScanFormat $scanFmt
        dict set headerDict NumPixel   [expr { $width * $height }]
        dict set headerDict NumByte    [expr { $width * $height * $numChan * $pixelSize }]
        dict set headerDict FileName   $fileName

        # Store additional information for reading the image data.
        dict set headerDict IsAscii [_IsAscii $type]

        return $headerDict
    }

    proc ReadImageHeader { ppmImgFile } {
        # Read the header of a PPM image file.
        #
        # ppmImgFile - File name of the PPM image.
        #
        # Return the header information as a dictionary containing the following keys:
        # Magic Width Height NumChan ByteOrder ScanOrder PixelType
        # PixelSize ScanFormat NumPixel NumByte
        #
        # The first seven keys have identical names and values as listed in the file header.
        # PixelSize and ScanFormat are derived information values computed from the other keys.
        #
        # Magic      Magic string "PPM" for easy identification of file format.
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

        set retVal [catch {open $ppmImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $ppmImgFile"
        }
        fconfigure $fp -translation binary
        set headerDict [GetImageHeader $fp [file tail $ppmImgFile]]
        close $fp
        return $headerDict
    }

    #
    # Image data read/write procedures.
    #

    proc GetImageData { fp headerDict dataDict } {
        upvar 1 $dataDict myDict

        set numBytes [dict get $headerDict NumByte]
        if { [dict get $headerDict IsAscii] } {
            set fmt [dict get $headerDict ScanFormat]
            set valueList [read $fp]
            foreach value $valueList {
                append valueData [binary format $fmt $value]
            }
            dict set myDict Data $valueData
        } else {
            dict set myDict Data [read $fp $numBytes]
        }
    }

    proc ReadImageFile { ppmImgFile { optStr "" } } {
        # Read a PPM image file into a dictionary.
        #
        # ppmImgFile - File name of the PPM image.
        # optStr     - Option string for reading the PPM image.
        #              This is the value as returned by poImgType GetOptByFmt "ppm" "read".
        #
        # Return the image data as a Tcl dictionary containing 2 keys: header and data.
        # Key "Data" contains the raw image data information as a binary string.
        # Key "Header" contains additional information about the image and is itself a dictionary.
        #
        # See GetImageHeader for the description of the header dictionary.
        #
        # See also: ReadImageHeader WriteImageFile

        set retVal [catch {open $ppmImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $ppmImgFile"
        }
        fconfigure $fp -translation binary

        set imgDict [dict create]
        if { [poType IsImage $ppmImgFile "ppm"] } {
            set headerDict [GetImageHeader $fp [file tail $ppmImgFile]]
        }
        GetImageData $fp $headerDict imgDict
        dict append imgDict Header $headerDict

        close $fp
        return $imgDict
    }
}
