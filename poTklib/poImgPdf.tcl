# Module:         poImgPdf
# Copyright:      Paul Obermeier 2001-2023 / paul@poSoft.de
# First Version:  2021 / 08 / 28
#
# Distributed under BSD license.
#
# Module for handling PDF files with tkMuPDF and interpreting as images.

namespace eval poImgPdf {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetNumPages
    namespace export GetPdfDpiOpt
    namespace export GetPdfPageOpt
    namespace export GetPageSize
    namespace export PhotoFromPdf

    proc GetPdfPageOpt {} {
        set page 0
        set pdfOpts [poImgType GetOptByFmt "PDF" "read"]
        set pageIndex [lsearch $pdfOpts "-index"]
        if { $pageIndex >= 0 } {
            set tmpPage [lindex $pdfOpts [expr {$pageIndex + 1}]]
            if { $tmpPage >= 0 } {
                set page $tmpPage
            }
        }
        return $page
    }

    proc GetPdfDpiOpt {} {
        set dpi 72.0
        set pdfOpts [poImgType GetOptByFmt "PDF" "read"]
        set pageIndex [lsearch $pdfOpts "-dpi"]
        if { $pageIndex >= 0 } {
            set tmpDpi [lindex $pdfOpts [expr {$pageIndex + 1}]]
            if { $tmpDpi > 0 } {
                set dpi $tmpDpi
            }
        }
        return $dpi
    }

    proc _CalcPdfZoom { pdfWidth pdfHeight { imgWidth -1 } { imgHeight -1 } } {
        set zoom 1.0
        if { $imgWidth > 0 && $imgHeight > 0 } {
            set xzoom [expr { $pdfWidth  / $imgWidth }]
            set yzoom [expr { $pdfHeight / $imgHeight }]
            set zoom [poMisc Max $xzoom $yzoom]
            set zoom [expr { 1.0 / $zoom }]
        }
        return $zoom
    }

    proc GetNumPages { fileName } {
        if { ! [poMisc HavePkg "tkMuPDF"] } {
            return -1
        }
        set retVal [catch { mupdf::open $fileName } pdfObj]
        if { $retVal != 0 } {
            return -1
        }
        set numPages [$pdfObj npages]
        return $numPages
    }

    proc GetPageSize { fileName args } {
        set opts [dict create \
            -unit   "pixel" \
            -dpi    -1 \
            -index  -1 \
        ]

        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                if { $value eq "" } {
                    error "GetPageSize: No value specified for key \"$key\""
                }
                dict set opts $key $value
            } else {
                error "GetPageSize: Unknown option \"$key\" specified"
            }
        }

        if { ! [poMisc HavePkg "tkMuPDF"] } {
            return [list 0 0]
        }

        set retVal [catch { mupdf::open $fileName } pdfObj]
        if { $retVal != 0 } {
            error "GetPageSize: Cannot open file $fileName"
        }

        set pageNum [dict get $opts "-index"]
        if { $pageNum < 0 } {
            set pageNum [GetPdfPageOpt]
            if { $pageNum >= [$pdfObj npages] } {
                set pageNum expr [{ [$pdfObj npages] - 1 }]
            }
        }
        set pageObj [$pdfObj getpage $pageNum]
        lassign [$pageObj size] pdfWidth pdfHeight
        $pdfObj quit

        set dpi [dict get $opts "-dpi"]
        if { $dpi < 0 } {
            set dpi [GetPdfDpiOpt]
        }

        set wcm [expr { $pdfWidth  * 2.54 / 72.0 } ]
        set hcm [expr { $pdfHeight * 2.54 / 72.0 } ]
        if { [dict get $opts "-unit"] eq "cm" } {
            return [list $wcm $hcm]
        }

        set imgWidth  [expr { round ($wcm * $dpi / 2.54) }]
        set imgHeight [expr { round ($hcm * $dpi / 2.54) }]
        return [list $imgWidth $imgHeight]
    }

    proc PhotoFromPdf { fileName args } {
        set opts [dict create \
            -width  -1 \
            -height -1 \
            -dpi    -1 \
            -index  -1 \
        ]

        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                if { $value eq "" } {
                    error "PhotoFromPdf: No value specified for key \"$key\""
                }
                dict set opts $key $value
            } else {
                error "PhotoFromPdf: Unknown option \"$key\" specified"
            }
        }

        set retVal [catch { mupdf::open $fileName } pdfObj]
        if { $retVal != 0 } {
            error "PhotoFromPdf: Cannot open file $fileName"
        }
        set phImg [image create photo]

        set pageNum [dict get $opts "-index"]
        if { $pageNum < 0 } {
            set pageNum [GetPdfPageOpt]
            if { $pageNum >= [$pdfObj npages] } {
                set pageNum expr [{ [$pdfObj npages] - 1 }]
            }
        }
        set pageObj [$pdfObj getpage $pageNum]
        lassign [$pageObj size] pdfWidth pdfHeight

        set pdfZoom 1.0

        set dpi [dict get $opts "-dpi"]
        if { $dpi < 0 } {
            set dpi [GetPdfDpiOpt]
        }

        set imgWidth  [dict get $opts "-width"]
        set imgHeight [dict get $opts "-height"]

        if { $imgWidth > 0 && $imgHeight > 0 } {
        } elseif { $dpi > 0 } {
            set wcm [expr { $pdfWidth  * 2.54 / 72.0 } ]
            set hcm [expr { $pdfHeight * 2.54 / 72.0 } ]
            set imgWidth  [expr { round ($wcm * $dpi / 2.54) }]
            set imgHeight [expr { round ($hcm * $dpi / 2.54) }]
        }
        set pdfZoom [_CalcPdfZoom $pdfWidth $pdfHeight $imgWidth $imgHeight]
        $pageObj saveImage $phImg -zoom $pdfZoom
        $pdfObj quit
        return $phImg
    }
}
