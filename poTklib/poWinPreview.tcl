# Module:         poWinPreview
# Copyright:      Paul Obermeier 2014-2023 / paul@poSoft.de
# First Version:  2014 / 10 / 26
#
# Distributed under BSD license.

namespace eval poWinPreview {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export Create Clear
    namespace export SetTitle Update
    namespace export GetMaxBytes SetMaxBytes

    # Init is called at package load time.
    proc Init {} {
        SetMaxBytes 2048
    }

    proc GetMaxBytes {} {
        variable sett

        return $sett(maxBytes)
    }

    proc SetMaxBytes { maxBytes } {
        variable sett

        set sett(maxBytes) $maxBytes
    }

    # Create a megawidget for previewing file or image data.
    # "masterFr" is the frame, where the components of the megawidgets are placed.
    # "title" is an optional string displayed as title of the preview widget.
    # Return an identifier for the new preview widget.
 
    proc Create { masterFr { title "Preview" } } {
        variable sett

        set previewId $masterFr.fr
        ttk::frame $previewId
        pack $previewId -expand 1 -fill both

        set textId [poExtProg ShowSimpleTextEdit $title $previewId false \
                    -width 1 -height 1 -wrap none -exportselection false \
                    -undo false -font [poWin GetFixedFont]]
        set sett($previewId,previewTxt) $textId
        $textId configure -state disabled

        return $previewId
    }

    proc SetTitle { w title } {
        variable sett

        poExtProg SetTitle $sett($w,previewTxt) $title
    }

    proc Update { w fileName { forceUpdate false } } {
        variable sett

        set fileName [file normalize [poMisc QuoteTilde $fileName]]
        # If the preview information of fileName is already displayed, return immediately.
        if { [info exists sett($w,previewFile)] && $sett($w,previewFile) eq $fileName && ! $forceUpdate } {
            return
        }

        # Delete the content already stored in the preview label.
        Clear $w

        $sett($w,previewTxt) configure -state normal
        if { [poImgMisc IsImageFile $fileName] } {
            set sw [expr { [winfo width  $sett($w,previewTxt)] - 5 }]
            set sh [expr { [winfo height $sett($w,previewTxt)] - 5 }]
            if { $sw <= 0 } {
                set sw 1
            }
            if { $sh <= 0 } {
                set sh 1
            }
            set imgDict [poImgMisc LoadImgScaled $fileName $sw $sh]
            set phImg [dict get $imgDict phImg]
            if { $phImg ne "" } {
                $sett($w,previewTxt) image create 1.0 -image $phImg -align center
                set sett($w,phImg) $phImg
            } else {
                poExtProg DumpFileIntoTextWidget $sett($w,previewTxt) $fileName -maxbytes [GetMaxBytes]
            }
        } elseif { [poType IsBinary $fileName] } {
            poExtProg DumpFileIntoTextWidget $sett($w,previewTxt) $fileName -maxbytes [GetMaxBytes]
        } else {
            set catchVal [catch { poExtProg LoadFileIntoTextWidget $sett($w,previewTxt) $fileName -maxbytes [GetMaxBytes] }]
            if { $catchVal } {
                $sett($w,previewTxt) insert end [lindex [split "$::errorInfo" "\n"] 0]
            }
        }
        $sett($w,previewTxt) configure -state disabled
        set sett($w,previewFile) $fileName
        update
        SetTitle $w [file tail $fileName]
    }

    proc Clear { w } {
        variable sett

        $sett($w,previewTxt) configure -state normal
        $sett($w,previewTxt) delete 1.0 end
        $sett($w,previewTxt) configure -state disabled
        if { [info exists sett($w,phImg)] } {
            image delete $sett($w,phImg)
            unset sett($w,phImg)
        }
        catch { unset sett($w,previewFile) }
    }
}

poWinPreview Init
