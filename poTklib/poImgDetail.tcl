# Module:         poImgDetail
# Copyright:      Paul Obermeier 2015-2020 / paul@poSoft.de
# First Version:  2015 / 04 / 09
#
# Distributed under BSD license.
#
# Module for handling image details.

namespace eval poImgDetail {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export CheckAniGifIndex GetNumGifImgs ShowAniGifDetail
    namespace export CheckIcoIndex ShowIcoDetail
    namespace export GetExifInfo FormatExifInfo ShowExifDetail

    proc Init {} {
        variable sPo

        set sPo(detailWinNum) 1
    }

    proc CheckAniGifIndex { fileName ind } {
        set retVal [catch {image create photo -file $fileName -format "GIF -index $ind"} phImg]
        if { $retVal == 0 } {
            image delete $phImg
            return 1
        }
        return 0
    }

    proc GetNumGifImgs { fileName } {
        if { [poImgDetail CheckAniGifIndex $fileName 1] } {
            set ind 10
            while { [poImgDetail CheckAniGifIndex $fileName $ind] } {
                incr ind 10
            }
            incr ind -1
            while { ! [poImgDetail CheckAniGifIndex $fileName $ind] } {
                incr ind -1
            }
            return [expr { $ind + 1 }]
        }
        return 1
    }

    proc _DestroyAniGifDetail { w args } {
        foreach phImg $args {
            image delete $phImg
        }
        destroy $w
    }

    proc ShowAniGifDetail { fileName } {
        variable ns
        variable sPo

        set tw .poImgDetail_AniGifDetail$sPo(detailWinNum)
        incr sPo(detailWinNum)

        toplevel $tw
        wm title $tw "Details of [file tail $fileName]"
        wm resizable $tw true true

        set retVal 0
        set ind    0
        set row    0

        ttk::frame $tw.fr
        grid $tw.fr -row 0 -column 0 -sticky news
        grid rowconfigure    $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1
        set icofr [poWin CreateScrolledFrame $tw.fr true "$fileName" \
                   -height 300 -width 300]

        set phImgList [list]
        while { $retVal == 0 } {
            set retVal [catch {image create photo -file $fileName -format "GIF -index $ind"} phImg]
            if { $retVal == 0 } {
                lappend phImgList $phImg
                set msg [format "Image %2d: %3d x %3d" $ind \
                        [image width $phImg] [image height $phImg]]
                ttk::label $icofr.l$row -text $msg
                grid $icofr.l$row -row $row -column 0 -sticky news

                ttk::frame $icofr.fr$row
                grid $icofr.fr$row -row $row -column 1 -sticky news

                ttk::label $icofr.fr$row.b -image $phImg
                pack $icofr.fr$row.b -anchor w -in $icofr.fr$row -pady 5 -padx 5
            }
            incr ind
            incr row
        }

        bind $tw <KeyPress-Escape> "${ns}::_DestroyAniGifDetail $tw $phImgList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::_DestroyAniGifDetail $tw $phImgList"
        focus $tw
    }

    proc CheckIcoIndex { fileName ind } {
        set retVal [catch {image create photo -file $fileName -format "ICO -index $ind"} phImg]
        if { $retVal == 0 } {
            image delete $phImg
            return 1
        }
        return 0
    }

    proc _DestroyIcoDetail { w args } {
        foreach phImg $args {
            image delete $phImg
        }
        destroy $w
    }

    proc ShowIcoDetail { fileName } {
        variable ns
        variable sPo

        set tw .poImgDetail_IcoDetail$sPo(detailWinNum)
        incr sPo(detailWinNum)

        toplevel $tw
        wm title $tw "Details of [file tail $fileName]"
        wm resizable $tw true true

        set retVal 0
        set ind    0
        set row    0

        ttk::frame $tw.fr
        grid  $tw.fr -row 0 -column 0 -sticky news
        grid rowconfigure    $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1
        set icofr [poWin CreateScrolledFrame $tw.fr true "$fileName" -height 300 -width 200]

        set phImgList [list]
        while { $retVal == 0 } {
            set retVal [catch {image create photo -file $fileName -format "ICO -index $ind"} phImg]
            if { $retVal == 0 } {
                lappend phImgList $phImg
                set msg [format "Icon %2d: %3d x %3d" $ind \
                        [image width $phImg] [image height $phImg]]
                ttk::label $icofr.l$row -text $msg
                grid $icofr.l$row -row $row -column 0 -sticky news

                ttk::frame $icofr.fr$row
                grid $icofr.fr$row -row $row -column 1 -sticky news

                ttk::label $icofr.fr$row.b -image $phImg
                pack $icofr.fr$row.b -anchor w -in $icofr.fr$row -pady 5 -padx 5
            }
            incr ind
            incr row
        }

        bind $tw <KeyPress-Escape> "${ns}::_DestroyIcoDetail $tw $phImgList"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::_DestroyIcoDetail $tw $phImgList"
        focus $tw
    }

    proc GetExifInfo { fileName } {
        return [::jpeg::getExif $fileName]
    }

    proc FormatExifInfo { exifInfo } {
        return [::jpeg::formatExif $exifInfo]
    }
    
    proc _DestroyExifDetail { w } {
        destroy $w
    }

    proc ShowExifDetail { fileName } {
        variable ns
        variable sPo

        set tw .poImgDetail_ExifDetail$sPo(detailWinNum)
        incr sPo(detailWinNum)

        toplevel $tw
        wm title $tw "Details of [file tail $fileName]"
        wm resizable $tw true true

        set retVal 0
        set ind    0
        set row    0

        ttk::frame $tw.fr
        grid  $tw.fr -row 0 -column 0 -sticky news
        grid rowconfigure    $tw 0 -weight 1
        grid columnconfigure $tw 0 -weight 1
        set exifTable [poWin CreateScrolledTablelist $tw.fr true "" \
                      -width 80 -height 20 -exportselection false \
                      -columns { 0 "Key" "left"
                                 0 "Value" "left" } \
                      -stretch 1 \
                      -stripebackground [poAppearance GetStripeColor] \
                      -showseparators yes]

        foreach { key value } [FormatExifInfo [GetExifInfo $fileName]] {
            if { $key ne "MakerNote" } {
                $exifTable insert end [list $key $value]
            }
        }
        bind $tw <KeyPress-Escape> "${ns}::_DestroyExifDetail $tw"
        wm protocol $tw WM_DELETE_WINDOW "${ns}::_DestroyExifDetail $tw"
        focus $tw
    }
}

poImgDetail Init
