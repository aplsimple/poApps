# Module:         poImgPages
# Copyright:      Paul Obermeier 2015-2023 / paul@poSoft.de
# First Version:  2021 / 09 / 02
#
# Distributed under BSD license.
#
# Module for handling sub images, aka images with pages.

namespace eval poImgPages {
    variable ns [namespace current]

    namespace ensemble create

    namespace export GetNumPages
    namespace export Clear
    namespace export Create
    namespace export Update

    proc _CheckIndex { fileName fmt ind } {
        set retVal [catch {image create photo -file $fileName -format "$fmt -index $ind"} phImg]
        if { $retVal == 0 } {
            image delete $phImg
            return true
        }
        return false
    }

    proc _GetNumImgs { fileName fmt } {
        if { [_CheckIndex $fileName $fmt 1] } {
            set ind 5
            while { [_CheckIndex $fileName $fmt $ind] } {
                incr ind 5
            }
            incr ind -1
            while { ! [_CheckIndex $fileName $fmt $ind] } {
                incr ind -1
            }
            return [expr { $ind + 1 }]
        }
        return 1
    }

    proc GetNumPages { fileName } {
        if { ! [file exists $fileName] } {
            return -1
        }

        set fileName [poMisc QuoteTilde $fileName]
        set typeDict [poType GetFileType $fileName]
        if { [dict exists $typeDict fmt] } {
            set fmt [string tolower [dict get $typeDict fmt]]
            switch -exact -- $fmt {
                "pdf" {
                    return [poImgPdf GetNumPages $fileName]
                }
                "graphic" {
                    if { [poImgMisc HaveImageMetadata] } {
                        set imgDict [image metadata -file $fileName]
                        if { [dict exists $imgDict numpages] } {
                            return [dict get $imgDict numpages]
                        }
                    }
                    if { [dict exists $typeDict subfmt] } {
                        set subfmt [string tolower [dict get $typeDict subfmt]]
                        switch -exact -- $subfmt {
                            "gif"  -
                            "ico"  -
                            "tiff" {
                                return [_GetNumImgs $fileName $subfmt]
                            }
                        }
                    }
                    return 1
                }
            }
        }
        return 0
    }

    proc _ShowSelPage { tableId labelId } {
        variable sett

        set rowList [$tableId curselection]
        if { [llength $rowList] > 0 } {
            set row [lindex $rowList 0]
            set fileName [$tableId rowattrib $row "FileName"]
            set sw [expr { [winfo width  $labelId] - 5 }]
            set sh [expr { [winfo height $labelId] - 5 }]
            if { [info exists sett($tableId,phImg)] } {
                catch { image delete $sett($tableId,phImg) }
            }
            set imgDict [poImgMisc LoadImgScaled $fileName $sw $sh -index $row]
            set phImg [dict get $imgDict phImg]
            if { $phImg ne "" } {
                $labelId configure -image $phImg
                set sett($tableId,phImg) $phImg
            }
        }
    }

    proc Create { masterFr { title "Preview pages" } } {
        variable sett
        variable ns

        set tableFr   $masterFr.tableFr
        set previewFr $masterFr.previewFr
        frame $tableFr -bg yellow
        frame $previewFr -bg green
        grid $tableFr   -row 0 -column 0 -sticky ns
        grid $previewFr -row 0 -column 1 -sticky news
        grid rowconfigure    $masterFr 0 -weight 1
        grid columnconfigure $masterFr 0 -weight 0
        grid columnconfigure $masterFr 1 -weight 1

        set tableId [poWin CreateScrolledTablelist $tableFr true "" \
                    -exportselection false \
                    -columns { 0 "#"      "left"
                               0 "Image"  "center"
                               0 "Width"  "right"
                               0 "Height" "right" } \
                    -width 40 -height 10 \
                    -selectmode single \
                    -stripebackground [poAppearance GetStripeColor] \
                    -showseparators 1]

        ttk::label $previewFr.l
        pack $previewFr.l -expand true -fill both

        $tableId columnconfigure 0 -showlinenumbers true
        bind $tableId <<TablelistSelect>> "${ns}::_ShowSelPage $tableId $masterFr.previewFr.l"
        return $tableId
    }

    proc Update { w fileName } {
        variable sett

        # Delete the content already stored in the tablelist and the preview label.
        Clear $w

        set phImgList [list]
        if { [namespace exists ::poImgBrowse] } {
            set thumbSize [poImgBrowse GetThumbSize]
        } else {
            set thumbSize 80
        }
        set numPages [poImgPages GetNumPages $fileName]

        for { set row 0 } { $row < $numPages } { incr row } {
            set imgDict [poImgMisc LoadImgScaled $fileName $thumbSize $thumbSize -index $row]
            set phImg  [dict get $imgDict phImg]
            set width  [dict get $imgDict width]
            set height [dict get $imgDict height]
            $w insert end [list "" "" $width $height]
            $w cellconfigure $row,1 -image $phImg
            $w rowattrib $row "FileName" $fileName
            lappend phImgList $phImg
        }
        set sett($w,phImgList) $phImgList
    }

    proc Clear { w } {
        variable sett

        catch { image delete $sett($w,phImg) }
        if { [info exists sett($w,phImgList)] } {
            foreach phImg $sett($w,phImgList) {
                catch { image delete $phImg }
            }
        }
    }
}
