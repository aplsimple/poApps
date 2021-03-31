# Module:         poFlirParse
# Copyright:      Paul Obermeier 2019-2020 / paul@poSoft.de
# First Version:  2019 / 02 / 01
#
# Distributed under BSD license.
#
# Module for reading and writing of FLIR image files with pure Tcl.
# Currently the FLIR Public Image Format (FPF) is supported.

namespace eval poFlirParse {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetImageHeader
    namespace export GetImageData
    namespace export ReadImageHeader ReadImageFile

    #
    # Utility procedures.
    #

    proc _GetImageTypeName { imgType } {
        switch -exact $imgType {
            0 { return "Temperature" }
            1 { return "TemperatureDifference" }
            2 { return "ObjectSignal" }
            3 { return "ObjectSignalDifference" }
        }
        return "UnknownImageType"
    }

    proc _GetPixelTypeName { pixelType } {
        switch -exact $pixelType {
            0 { return "short" }
            1 { return "int" }
            2 { return "float" }
            3 { return "double" }
        }
        return "UnknownPixelType"
    }

    proc _GetPixelSize { pixelType } {
        switch -exact $pixelType {
            0 { return 2 }
            1 { return 4 }
            2 { return 4 }
            3 { return 8 }
        }
        error "Invalid PixelType value: $pixelType (must be 0, 1, 2 or 3)"
    }

    proc _GetScanFormat { pixelType } {
        switch -exact $pixelType {
            0 { return "s" }
            1 { return "i" }
            2 { return "r" }
            3 { return "d" }
        }
        error "Invalid PixelType value: $pixelType (must be 0, 1, 2 or 3)"
    }

    proc _ReadShort { fp } {
        set rawVal [read $fp 2]
        if { $rawVal ne "" } {
            binary scan $rawVal s val
            return $val
        } else {
            error "Could not read short value at file position [tell $fp]"
        }
    }

    proc _ReadInt { fp } {
        set rawVal [read $fp 4]
        if { $rawVal ne "" } {
            binary scan $rawVal i val
            return $val
        } else {
            error "Could not read integer value at file position [tell $fp]"
        }
    }

    proc _ReadFloat { fp } {
        set rawVal [read $fp 4]
        if { $rawVal ne "" } {
            binary scan $rawVal f val
            return $val
        } else {
            error "Could not read float value at file position [tell $fp]"
        }
    }

    proc _ReadString { fp size } {
        set rawVal [read $fp $size]
        if { $rawVal ne "" } {
            binary scan $rawVal a$size val
            return $val
        } else {
            error "Could not read string value at file position [tell $fp]"
        }
    }

    #
    # Image header read/write procedures.
    #

    proc GetImageHeader { fp { fileName "FlirData" } } {
        # Get the header of a FLIR image file.
        #
        # fp       - File pointer of the FLIR image.
        # fileName - File name of the FLIR image, if appropriate.
        #
        # Return the header information as a dictionary.
        #
        # See ReadImageHeader for a description of the dictionary elements.
        #
        # If the header contains invalid information, an error is thrown.
        #
        # See also: ReadImageHeader

        set fpfId              [_ReadString $fp 32]
        set version            [_ReadInt $fp]
        set imageDataOffset    [_ReadInt $fp]
        set imageType          [_ReadShort $fp]
        set pixelType          [_ReadShort $fp]
        set width              [_ReadShort $fp]
        set height             [_ReadShort $fp]
        set triggerCount       [_ReadInt $fp]
        set frameCount         [_ReadInt $fp]
        set spare1             [_ReadString $fp 64]
        set cameraName         [_ReadString $fp 32]
        set cameraPartNum      [_ReadString $fp 32]
        set cameraSerialNum    [_ReadString $fp 32]
        set cameraTempRangeMin [_ReadFloat $fp]
        set cameraTempRangeMax [_ReadFloat $fp]
        set lensName           [_ReadString $fp 32]
        set lensPartNum        [_ReadString $fp 32]
        set lensSerialNum      [_ReadString $fp 32]
        set filterName         [_ReadString $fp 32]
        set filterPartNum      [_ReadString $fp 32]
        set filterSerialNum    [_ReadString $fp 32]
        set spare2             [_ReadString $fp 64]
        set emissivity         [_ReadFloat $fp]
        set objectDistance     [_ReadFloat $fp]
        set apparentTemp       [_ReadFloat $fp]
        set atmosphereTemp     [_ReadFloat $fp]
        set relativeHumidity   [_ReadFloat $fp]
        set computedAtmTrans   [_ReadFloat $fp]
        set estimatedAtmTrans  [_ReadFloat $fp]
        set referenceTemp      [_ReadFloat $fp]
        set extOpticsTemp      [_ReadFloat $fp]
        set extOpticsTrans     [_ReadFloat $fp]
        set spare3             [_ReadString $fp 64]
        set year               [_ReadInt $fp]
        set month              [_ReadInt $fp]
        set day                [_ReadInt $fp]
        set hour               [_ReadInt $fp]
        set minute             [_ReadInt $fp]
        set second             [_ReadInt $fp]
        set millisecond        [_ReadInt $fp]
        set spare4             [_ReadString $fp 64]
        set cameraScaleMin     [_ReadFloat $fp]
        set cameraScaleMax     [_ReadFloat $fp]
        set calculatedScaleMin [_ReadFloat $fp]
        set calculatedScaleMax [_ReadFloat $fp]
        set actualScaleMin     [_ReadFloat $fp]
        set actualScaleMax     [_ReadFloat $fp]
        set spare5             [_ReadString $fp 192]

        set headerDict [dict create]
        set numChan 1

        # Store the values contained in the header.
        dict set headerDict Magic     "FLIR"
        dict set headerDict Width     $width
        dict set headerDict Height    $height
        dict set headerDict NumChan   $numChan
        dict set headerDict ByteOrder "Intel"
        dict set headerDict ScanOrder "TopDown"
        dict set headerDict PixelType [_GetPixelTypeName $pixelType]

        # Calculate derived information from the header values.
        set pixelSize [_GetPixelSize $pixelType]
        set scanFmt   [_GetScanFormat $pixelType]
        dict set headerDict PixelSize  $pixelSize
        dict set headerDict ScanFormat $scanFmt
        dict set headerDict NumPixel   [expr { $width * $height }]
        dict set headerDict NumByte    [expr { $width * $height * $numChan * $pixelSize }]
        dict set headerDict FileName   $fileName

        return $headerDict
    }

    proc ReadImageHeader { flirImgFile } {
        # Read the header of a FLIR image file.
        #
        # flirImgFile - File name of the FLIR image.
        #
        # Return the header information as a dictionary containing the following keys:
        # Magic Width Height NumChan ByteOrder ScanOrder PixelType
        # PixelSize ScanFormat NumPixel NumByte
        #
        # The first seven keys have identical names and values as listed in the file header.
        # PixelSize and ScanFormat are derived information values computed from the other keys.
        #
        # Magic      Magic string "FLIR" for easy identification of file format.
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

        set retVal [catch {open $flirImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $flirImgFile"
        }
        fconfigure $fp -translation binary
        set headerDict [GetImageHeader $fp [file tail $flirImgFile]]
        close $fp
        return $headerDict
    }

    #
    # Image data read/write procedures.
    #

    proc GetImageData { fp headerDict dataDict } {
        upvar 1 $dataDict myDict

        set numBytes [dict get $headerDict NumByte]
        dict set myDict Data [read $fp $numBytes]
    }

    proc ReadImageFile { flirImgFile { optStr "" } } {
        # Read a FLIR image file into a dictionary.
        #
        # flirImgFile - File name of the FLIR image.
        # optStr     - Option string for reading the FLIR image.
        #              This is the value as returned by poImgType GetOptByFmt "flir" "read".
        #
        # Return the image data as a Tcl dictionary containing 2 keys: header and data.
        # Key "Data" contains the raw image data information as a binary string.
        # Key "Header" contains additional information about the image and is itself a dictionary.
        #
        # See GetImageHeader for the description of the header dictionary.
        #
        # See also: ReadImageHeader

        set retVal [catch {open $flirImgFile "r"} fp]
        if { $retVal != 0 } {
            error "Cannot open file $flirImgFile"
        }
        fconfigure $fp -translation binary

        set imgDict [dict create]
        if { [poType IsImage $flirImgFile "flir"] } {
            set headerDict [GetImageHeader $fp [file tail $flirImgFile]]
        }
        GetImageData $fp $headerDict imgDict
        dict append imgDict Header $headerDict

        close $fp
        return $imgDict
    }
}

