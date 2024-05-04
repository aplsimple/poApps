# Module:         poImgExif
# Copyright:      Paul Obermeier 2015-2023 / paul@poSoft.de
# First Version:  2015 / 04 / 09
#
# Distributed under BSD license.
#
# Module for handling EXIF information.

namespace eval poImgExif {
    variable ns [namespace current]

    namespace ensemble create

    namespace export FormatExifInfo
    namespace export GetExifInfo
    namespace export ShowExifDetail

    proc GetExifInfo { fileName } {
        return [::jpeg::getExif $fileName]
    }

    proc FormatExifInfo { exifInfo } {
        return [::jpeg::formatExif $exifInfo]
    }

    proc ShowExifDetail { masterFr fileName } {
        set exifTable [poWin CreateScrolledTablelist $masterFr true "" \
                      -width 80 -height 20 -exportselection false \
                      -columns { 0 "Key" "left"
                                 0 "Value" "left" } \
                      -stretch 1 \
                      -labelcommand tablelist::sortByColumn \
                      -stripebackground [poAppearance GetStripeColor] \
                      -showseparators yes]

        $exifTable columnconfigure 0 -sortmode dictionary
        $exifTable columnconfigure 1 -sortmode dictionary

        foreach { key value } [FormatExifInfo [GetExifInfo $fileName]] {
            if { $key ne "MakerNote" } {
                $exifTable insert end [list $key $value]
            }
        }
        $exifTable sortbycolumn 0 -increasing
    }
}
