# Module:         poImgFits
# Copyright:      Paul Obermeier 2022-2023 / paul@poSoft.de
# First Version:  2022 / 04 / 01
#
# Distributed under BSD license.
#
# Module for handling FITS files with fitsTcl and interpreting as images.

namespace eval poImgFits {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetImageSize
    namespace export PhotoFromFits

    proc _GetConversionParams { fitsObj } {
        set fmtString ""
        set pixelType ""

        # If the image has BZERO or BSCALE keywords in the header, fitsTcl will
        # do the appropriate thing with them automatically, but the datatype
        # returned will be floating point doubles (isn't FITS fun:)
        if { ( [catch { $fitsObj get keyword BZERO}]  == 0) ||
             ( [catch { $fitsObj get keyword BSCALE}] == 0) } {
            set fmtString "f*"
            set pixelType "float"
        } else {
            set imgType [$fitsObj info imgType]
            # Note, that 32 and 64 bit integer values are not handled by the RAW
            # image format, so the values are interpreted as shorts and may give
            # wrong results.
            switch -exact -- $imgType {
                  8 { set fmtString "c*" ; set pixelType "byte" }
                 16 { set fmtString "s*" ; set pixelType "short" }
                 32 { set fmtString "s*" ; set pixelType "short" }
                 64 { set fmtString "s*" ; set pixelType "short" }
                -32 { set fmtString "f*" ; set pixelType "float" }
                -64 { set fmtString "f*" ; set pixelType "float" }
            }
        }
        return [list $fmtString $pixelType]
    }

    proc GetImageSize { fileName } {
        if { ! [poMisc HavePkg "fitstcl"] } {
            return [list 0 0]
        }

        set retVal [catch { fits open $fileName } fitsObj]
        if { $retVal != 0 } {
            error "GetImageSize: Cannot open file $fileName"
        }

        lassign [$fitsObj imgdim] width height
        $fitsObj close

        return [list $width $height]
    }

    proc PhotoFromFits { fileName args } {
        set opts [dict create \
            -verbose     false \
            -blank       0 \
            -map         minmax \
            -gamma       1.0 \
            -min        -1.0 \
            -max        -1.0 \
            -cutoff      3.0 \
            -saturation -1.0 \
        ]

        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                if { $value eq "" } {
                    error "PhotoFromFits: No value specified for key \"$key\""
                }
                dict set opts $key $value
            } else {
                error "PhotoFromFits: Unknown option \"$key\" specified"
            }
        }

        set blankMap [dict get $opts "-blank"]

        set retVal [catch { fits open $fileName } fitsObj]
        if { $retVal != 0 } {
            error "PhotoFromFits: Cannot open file $fileName"
        }
        lassign [$fitsObj info imgdim] width height numChan
        if { $width <= 0 || $height <= 0 } {
            error "PhotoFromFits: Width or height are negative or zero."
        }
        if { ! [info exists numChan] || $numChan eq "" } {
            set numChan 1
        }

        set phImg [image create photo -width $width -height $height]

        # Get the format string for "binary format" command and the 
        # pixel type for the RAW image format.
        lassign [_GetConversionParams $fitsObj] fmtString pixelType

        # Retrieve the FITS image data as a Tcl list and convert into a byte array.
        set imgAsList [$fitsObj get image]

        # Check, if image has BLANK pixels, which are encoded as "NULL" in the Tcl list.
        # Replace those pixels with replacement value specified with option -blank.
        if { [lsearch -exact -ascii $imgAsList "NULL"] >= 0 } {
            set imgAsList [lmap a $imgAsList { expr { $a eq "NULL" ? $blankMap : $a }}]
        }

        if { $pixelType eq "short" } {
            # FITS uses signed short values, so map the pixel values to unsigned short for RAW images.
            set imgAsList [lmap p $imgAsList { expr { $p - 32768 }}]
        }

        if { $numChan == 3 || $numChan == 4 } {
            # FITS returns RGB images channel by channel, while RAW images need RGB.
            set chanSize [expr { $width * $height }]
            set sr 0
            set er [expr { 1 * $chanSize - 1 }]
            set sg [expr { $er + 1 }]
            set eg [expr { 2 * $chanSize - 1 }]
            set sb [expr { $eg + 1 }]
            set eb [expr { 3 * $chanSize - 1 }]
            foreach r [lrange $imgAsList $sr $er] \
                    g [lrange $imgAsList $sg $eg] \
                    b [lrange $imgAsList $sb $eb] {
                lappend rgbList $r $g $b
            }
            set imgAsList $rgbList
            set numChan 3
        }

        set imgAsByteArray [binary format $fmtString $imgAsList]
        # Fill the photo image using the byte array and the RAW image format.
        $phImg put $imgAsByteArray \
           -format "RAW \
           -useheader  false \
           -uuencode   false \
           -scanorder  BottomUp \
           -pixeltype  $pixelType \
           -width      $width \
           -height     $height \
           -nchan      $numChan \
           -verbose    [dict get $opts -verbose] \
           -map        [dict get $opts -map] \
           -gamma      [dict get $opts -gamma] \
           -min        [dict get $opts -min] \
           -max        [dict get $opts -max] \
           -cutoff     [dict get $opts -cutoff] \
           -saturation [dict get $opts -saturation]"

        $fitsObj close

        return $phImg
    }
}
