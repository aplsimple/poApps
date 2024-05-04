# Module:         poImgType
# Copyright:      Paul Obermeier 2001-2023 / paul@poSoft.de
# First Version:  2001 / 03 / 01
#
# Distributed under BSD license.
#
# Module for handling and displaying image types.

namespace eval poImgType {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export HaveDpiSupport
    namespace export GetResolution SetResolution
    namespace export OpenWin OkWin CancelWin
    namespace export GetSelBoxTypes
    namespace export GetFmtList GetExtList GetLastFmt GetFmtByExt
    namespace export GetOptByExt GetOptByFmt GetOptAsString
    namespace export LoadSettings SaveSettings

    # Just a placeholder for a now obsolete function, which has been stored
    # in the configuration files.
    proc SetShroudOpt { val } {
    }

    proc HaveDpiSupport {} {
        variable sPo

        if { ! [info exists sPo(HaveDpiSupport)] } {
            set img [image create photo]
            if { [lsearch -index 0 [$img configure] "-metadata"] >= 0 } {
                set sPo(HaveDpiSupport) true
            } else {
                set sPo(HaveDpiSupport) false
            }
            image delete $img
        }
        return $sPo(HaveDpiSupport)
    }

    proc GetResolution { phImg } {
        set dpi    0.0
        set aspect 1.0
        if { [poImgType HaveDpiSupport] } {
            set imgDict [$phImg cget -metadata]
            if { [dict exists $imgDict DPI] } {
                set dpi [dict get $imgDict DPI]
            }
            if { [dict exists $imgDict aspect] } {
                set aspect [dict get $imgDict aspect]
            }
        }
        set xdpi $dpi
        set ydpi $dpi
        if { $aspect != 0 } {
            set ydpi [expr { $dpi / $aspect}]
        }
        return [list $xdpi $ydpi]
    }

    proc SetResolution { phImg xdpi ydpi } {
        if { [poImgType HaveDpiSupport] } {
            set dpi $xdpi
            set aspect 1.0
            if { $ydpi != 0.0 } {
                set aspect [expr {double ($xdpi) / double ($ydpi)}]
            }
            $phImg configure -metadata [dict create DPI $dpi aspect $aspect]
        }
    }

    proc GetFmtList {} {
        variable sPo

        return $sPo(imgFmtList)
    }

    proc GetExtList { { fmt "" } } {
        variable sPo

        set retList {}
        if { $fmt eq "" } {
            foreach fmt $sPo(imgFmtList) {
                set extList $sPo($fmt,extension)
                foreach ext $extList {
                    lappend retList $ext
                }
            }
            return [lsort -unique $retList]
        } else {
            if { [info exists sPo($fmt,extension)] } {
                return $sPo($fmt,extension)
            } else {
                return ""
            }
        }
    }

    proc GetOptAsString { fmt mode } {
        variable sPo

        set optStr ""
        set mode [_GetMode $mode]
        foreach opt $sPo($fmt,$mode) {
            if { $opt == {} } {
                return $optStr
            }
            set optName [lindex $opt 1]
            set optType [lindex $opt 2]
            set useOpt  $sPo($fmt,$mode,$optName,useOpt)
            if { $optType eq "enum" } {
                set type [format "{%s}" [lrange $opt 4 end]]
            } else {
                set type $optType
            }
            append optStr " $optName $type"
        }
        return $optStr
    }

    proc RestoreOptValues { fmt } {
        variable sPo

        set sPo($fmt,extension) $sPo($fmt,ext)
        foreach opt $sPo($fmt,read) {
            if { $opt == {} } {
                break
            }
            set useOpt  [lindex $opt 0]
            set optName [lindex $opt 1]
            set optVal  [lindex $opt 3]
            set sPo($fmt,read,$optName,useOpt) $useOpt
            set sPo($fmt,read,$optName,optVal) $optVal
        }
        foreach opt $sPo($fmt,write) {
            if { $opt == {} } {
                break
            }
            set useOpt  [lindex $opt 0]
            set optName [lindex $opt 1]
            set optVal  [lindex $opt 3]
            set sPo($fmt,write,$optName,useOpt) $useOpt
            set sPo($fmt,write,$optName,optVal) $optVal
        }
    }

    proc RestoreAllOptValues {} {
        variable sPo

        foreach fmt $sPo(imgFmtList) {
            RestoreOptValues $fmt
        }
    }

    proc SetOptValues { fmt } {
        variable sPo

        set sPo($fmt,ext) $sPo($fmt,extension)
        set newOptList {}
        foreach opt $sPo($fmt,read) {
            if { $opt == {} } {
                lappend newOptList [list]
                break
            }
            set optName [lindex $opt 1]
            set optType [lindex $opt 2]
            set useOpt $sPo($fmt,read,$optName,useOpt)
            set optVal $sPo($fmt,read,$optName,optVal)

            set newOpt [lreplace $opt 0 3 $useOpt $optName $optType $optVal]
            lappend newOptList $newOpt
        }
        set sPo($fmt,read) $newOptList

        set newOptList {}
        foreach opt $sPo($fmt,write) {
            if { $opt == {} } {
                lappend newOptList [list]
                break
            }
            set optName [lindex $opt 1]
            set optType [lindex $opt 2]
            set useOpt $sPo($fmt,write,$optName,useOpt)
            set optVal $sPo($fmt,write,$optName,optVal)

            set newOpt [lreplace $opt 0 3 $useOpt $optName $optType $optVal]
            lappend newOptList $newOpt
        }
        set sPo($fmt,write) $newOptList
    }

    proc SetAllOptValues {} {
        variable sPo

        foreach fmt $sPo(imgFmtList) {
            SetOptValues $fmt
        }
    }

    proc ChangedOpts { } {
        variable sPo

        return $sPo(changed)
    }

    proc AddType { fmt fmtName extList readOptList writeOptList } {
        variable sPo

        if { ! [info exists sPo(imgFmtList)] } {
            set sPo(imgFmtList) {}
        }
        if { [lsearch -exact $sPo(imgFmtList) $fmt] < 0 } {
            lappend sPo(imgFmtList) $fmt
        }

        set sPo($fmt,tip)   $fmtName
        set sPo($fmt,ext)   $extList
        set sPo($fmt,read)  $readOptList
        set sPo($fmt,write) $writeOptList

        RestoreOptValues $fmt
    }

    proc Init {} {
        variable winName
        variable sPo
        variable msgStr
        variable curType

        set curType ""

        set sPo(changed) false
        set sPo(optToShow) "read"

        AddType BMP "Windows Bitmap" [list .bmp] \
                [list [list 0 -verbose     bool false true false]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -xresolution string 0] \
                      [list 0 -yresolution string 0]]

        AddType DTED "DTED elevation data" [list .dt0 .dt1 .dt2] \
                [list [list 0 -verbose   bool  false true false] \
                      [list 0 -gamma     float 1.0] \
                      [list 0 -min       int   0] \
                      [list 0 -max       int   32767]] \
                [list [list ]]

        AddType FITS "FITS Flexible Image Transport System" [list .fit .fits] \
                [list [list 0 -verbose bool false true false] \
                      [list 0 -blank      float  0] \
                      [list 0 -map        enum  minmax none minmax agc] \
                      [list 0 -gamma      float  1.0] \
                      [list 0 -min        float -1.0] \
                      [list 0 -max        float -1.0] \
                      [list 0 -cutoff     float  3.0] \
                      [list 0 -saturation float -1.0]] \
                [list [list ]]

        AddType FLIR "FLIR Public Image Format" [list .fpf] \
                [list [list 0 -verbose    bool  false true false] \
                      [list 0 -printagc   bool  false true false] \
                      [list 0 -map        enum  minmax none minmax agc] \
                      [list 0 -gamma      float  1.0] \
                      [list 0 -min        float -1.0] \
                      [list 0 -max        float -1.0] \
                      [list 0 -cutoff     float  3.0] \
                      [list 0 -saturation float -1.0]] \
                [list [list ]]

        AddType GIF "Graphics Interchange Format" [list .gif] \
                [list [list 0 -index int 0]] \
                [list [list ]]

        AddType ICO "Windows Icon Format" [list .ico] \
                [list [list 0 -verbose bool false true false] \
                      [list 0 -index   int  0]] \
                [list [list ]]

        AddType JPEG "JPEG" [list .jpg .jpeg .jfif] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -fast        "" ""] \
                      [list 0 -grayscale   "" ""]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -optimize    "" ""] \
                      [list 0 -grayscale   "" ""] \
                      [list 0 -progressive "" ""] \
                      [list 0 -quality     int 75] \
                      [list 0 -smooth      int 0] \
                      [list 0 -xresolution string 0] \
                      [list 0 -yresolution string 0]]

        AddType JP2 "JPEG 2000" [list .jp2 .jpf .jpx] \
                [list [list ]] \
                [list [list ]]

        AddType PCX "Paint Brush PCX" [list .pcx] \
                [list [list 0 -verbose     bool false true false]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -compression enum rle   none rle] \
                      [list 0 -xresolution string 0] \
                      [list 0 -yresolution string 0]]

        AddType PDF "Portable Document Format" [list .pdf] \
                [list [list 0 -index int    0] \
                      [list 0 -dpi   float 72]] \
                [list [list ]]

        AddType PNG "Portable Network Graphics" [list .png] \
                [list [list 0 -verbose bool false true false] \
                      [list 0 -matte   bool true  true false] \
                      [list 0 -alpha   float 0.5] \
                      [list 0 -gamma   float 1.0]] \
                [list [list 0 -verbose bool false true false] \
                      [list 0 -xresolution string 0] \
                      [list 0 -yresolution string 0]]

        AddType PPM "PPM and PGM" [list .ppm .pgm .pnm] \
                [list [list 0 -verbose   bool  false true false] \
                      [list 0 -gamma     float 1.0] \
                      [list 0 -min       float 0.0] \
                      [list 0 -max       float 255.0] \
                      [list 0 -scanorder enum  TopDown TopDown BottomUp]] \
                [list [list 0 -ascii     bool  false true false]]

        AddType PS "Postscript" [list .ps] \
                [list [list 0 -index int   0] \
                      [list 0 -zoom  float 1.0]] \
                [list [list ]]

        AddType RAW "Raw image data" [list .raw] \
                [list [list 1 -useheader  bool  true true false] \
                      [list 0 -verbose    bool  false true false] \
                      [list 0 -printagc   bool  false true false] \
                      [list 0 -scanorder  enum  TopDown TopDown BottomUp] \
                      [list 0 -byteorder  enum  Intel Intel Motorola] \
                      [list 0 -pixeltype  enum  byte byte short int float double] \
                      [list 0 -skipbytes  int   0] \
                      [list 0 -nchan      int   1] \
                      [list 0 -width      int   128] \
                      [list 0 -height     int   128] \
                      [list 0 -map        enum  minmax none minmax agc] \
                      [list 0 -gamma      float  1.0] \
                      [list 0 -min        float -1.0] \
                      [list 0 -max        float -1.0] \
                      [list 0 -cutoff     float  3.0] \
                      [list 0 -saturation float -1.0]] \
                [list [list 1 -useheader bool  true true false] \
                      [list 0 -verbose   bool  false true false] \
                      [list 1 -nchan     int   3] \
                      [list 0 -scanorder enum  TopDown TopDown BottomUp]]

        AddType SGI "SGI native format" [list .bw .int .inta .rgb .rgba] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false] \
                      [list 0 -compression enum rle   rle  none]]

        AddType SUN "SUN raster format" [list .ras .sun] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false] \
                      [list 0 -compression enum rle   rle  none]]

        AddType SVG "Scalable Vector Graphic" [list .svg] \
                [list [list 0 -dpi           float 96] \
                      [list 0 -scale         float 1.0] \
                      [list 0 -scaletowidth  int 0] \
                      [list 0 -scaletoheight int 0]] \
                [list [list ]]

        AddType TGA "Truevision format" [list .tga] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -matte       bool true  true false] \
                      [list 0 -compression enum rle   rle  none]]

        AddType TIFF "Tagged image format" [list .tif .tiff] \
                [list [list 0 -verbose bool false true false] \
                      [list 0 -index   int 0]] \
                [list [list 0 -verbose     bool false true false] \
                      [list 0 -xresolution string 0] \
                      [list 0 -yresolution string 0] \
                      [list 0 -compression enum none none deflate jpeg packbits] \
                      [list 0 -byteorder   enum none none bigendian littleendian]]

        AddType XBM "X Windows Bitmap" [list .xbm] \
                [list [list 0 -foreground string "#000000"] \
                      [list 0 -background string ""]] \
                [list [list ]]

        AddType XPM "X Windows Pixmap" [list .xpm] \
                [list [list ]] \
                [list [list ]]

        array set msgStr [list \
            ImgType     "Image types" \
            ViewSel     "Show options:" \
            FileExt     "File extensions:" \
            SelEditor   "Select editor" \
            SelGuiDiff  "Select graphical diff program" \
            MsgSelType  "Please select a file type first." \
            MsgNoRename "You can not rename \"Default type\"." \
            EnterType   "Enter file type name" \
            TypeExists  "Filetype %s already exists." \
            MsgDelType  "Delete file type \"%s\"?" \
            Confirm     "Confirmation" \
            WinTitle    "Image type settings" \
        ]
    }

    proc Str { key args } {
        variable msgStr

        set str $msgStr($key)
        return [eval {format $str} $args]
    }

    proc GetLastFmt {} {
        variable curType

        return $curType
    }

    proc OkWin { w } {
        SetAllOptValues
        destroy $w
    }

    proc CancelWin { w args } {
        variable sPo

        RestoreAllOptValues
        set sPo(changed) false
        destroy $w
    }

    proc LoadFileExt {} {
        variable sPo
        variable curType

        $sPo(fileExt) delete 1.0 end
        foreach ext $sPo($curType,extension) {
            $sPo(fileExt) insert end "$ext\n"
        }
    }

    proc SaveFileExt {} {
        variable sPo
        variable curType

        set fileType $curType
        set widgetCont [$sPo(fileExt) get 1.0 end]
        regsub -all -- {\n} $widgetCont " " extStr
        set extStr [string trim $extStr]
        set sPo($fileType,extension) $extStr
    }

    proc GetSelBoxTypes { { firstFmt "" } } {
        variable sPo

        set typeList {}
        if { $firstFmt ne "" && \
             [info exists sPo($firstFmt,tip)] } {
            lappend typeList [list $sPo($firstFmt,tip) $sPo($firstFmt,extension)]
        }
        lappend typeList [list "All files" *]
        foreach fmt $sPo(imgFmtList) {
            if { $firstFmt ne $fmt } {
                lappend typeList [list $sPo($fmt,tip) $sPo($fmt,extension)]
            }
        }
        return $typeList
    }

    proc GetFmtByExt { ext } {
        variable sPo

        set fmtFound 0
        set ext [string tolower $ext]
        foreach fmt $sPo(imgFmtList) {
            set extList $sPo($fmt,extension)
            if { [lsearch $extList $ext] >= 0 } {
                set fmtFound 1
                break
            }
        }
        if { $fmtFound == 0 } {
            poLog Warning "No format found for extension $ext"
            return ""
        }
        return $fmt
    }

    proc _GetMode { mode } {
        if { [string compare -nocase $mode "write"] == 0 } {
            return "write"
        } elseif { [string compare -nocase $mode "read"] == 0 } {
            return "read"
        } else {
            error "Invalid mode ($mode) specified. Must be read or write."
        }
    }

    proc GetOptByExt { ext mode } {
        variable sPo

        set fmt [GetFmtByExt $ext]
        return [GetOptByFmt $fmt $mode]
    }

    proc GetOptByFmt { fmt mode } {
        variable sPo

        set optStr ""
        set mode [_GetMode $mode]
        foreach opt $sPo($fmt,$mode) {
            if { $opt == {} } {
                return $optStr
            }
            set optName [lindex $opt 1]
            set useOpt  $sPo($fmt,$mode,$optName,useOpt)
            set optVal  $sPo($fmt,$mode,$optName,optVal)
            if { $optVal eq "" } {
                set optVal "\"\""
            }
            if { $useOpt } {
                append optStr " $optName $optVal"
            }
        }
        return $optStr
    }
  
    proc UpdateTable { tableId } {
        variable sPo
        variable curType

        # Restore the file extensions of the previous type.
        SaveFileExt

        if { ! [poTablelistUtil IsRowSelected $tableId] } {
            return
        }
        set curInd [poTablelistUtil GetFirstSelectedRow $tableId]
        set curType [lindex [$tableId get $curInd] 0]

        # Load the file extensions of the currently selected type.
        LoadFileExt
        GenOptWidgets
    }

    proc FillTable { tableId typeList showInd } {
        $tableId delete 0 end
        foreach type $typeList {
            $tableId insert end [list $type]
        }
        $tableId selection set $showInd
        set curType [$tableId get $showInd]
        event generate $tableId <<TablelistSelect>>
    }

    proc OpenWin { fr { fmtOrExt "" } } {
        variable ns
        variable sPo
        variable curType

        set tw $fr

        set curInd 0
        set curType [lindex $sPo(imgFmtList) $curInd]
        if { [string first "." $fmtOrExt] >= 0 } {
            set curType [GetFmtByExt $fmtOrExt]
            set curInd [lsearch -exact $sPo(imgFmtList) $curType]
            if { $curInd < 0 } {
                set curInd 0
                set curType [lindex $sPo(imgFmtList) $curInd]
                poLog Warning "No extension \"$fmtOrExt\" registered"
            }
        } elseif { $fmtOrExt ne "" } {
            set curType $fmtOrExt
            set curInd [lsearch -exact $sPo(imgFmtList) $curType]
            if { $curInd < 0 } {
                set curInd 0
                set curType [lindex $sPo(imgFmtList) $curInd]
                poLog Warning "No format \"$fmtOrExt\" registered"
            }
        }

        set typeFr $tw.typefr
        set workFr $tw.workfr
        set optFr  $tw.optfr

        ttk::frame $typeFr
        ttk::frame $workFr
        ttk::frame $optFr
        grid $typeFr -row 0 -column 0 -sticky news -rowspan 2
        grid $workFr -row 0 -column 1 -sticky news
        grid $optFr  -row 1 -column 1 -sticky news
        grid rowconfigure $tw 1 -weight 1
        grid columnconfigure $tw 1 -weight 1

        set sPo(changed) true

        set sPo(tableId) [poWin CreateScrolledTablelist $typeFr true ""  \
            -columns [list 0  [Str ImgType] "left"] \
            -height [llength $sPo(imgFmtList)] \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -showlabels false \
            -stretch all \
            -showseparators 1]
        FillTable $sPo(tableId) $sPo(imgFmtList) $curInd

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list [Str FileExt] [Str ViewSel] "Option values:" ] {
            ttk::label $workFr.l$row -text $labelStr
            grid $workFr.l$row -row $row -column 0 -sticky new
            incr row
        }

        # Generate right column with entries and buttons.
        # Row 0: File extension text widget
        set row 0
        ttk::frame $workFr.fr$row
        grid $workFr.fr$row -row $row -column 1 -sticky new
        set sPo(fileExt) [poWin CreateScrolledText $workFr.fr$row true \
                            "" -bg white -wrap none -width 10 -height 3]
        # Load the file extensions of the currently selected type.
        LoadFileExt

        # Row 1: Buttons to show either read or write format options.
        incr row
        ttk::frame $workFr.fr$row
        grid  $workFr.fr$row -row $row -column 1 -sticky new
        ttk::radiobutton $workFr.fr$row.ro -text "Read" \
                    -variable ${ns}::sPo(optToShow) -value "read" \
                    -command "${ns}::GenOptWidgets"
        ttk::radiobutton $workFr.fr$row.wo -text "Write" \
                    -variable ${ns}::sPo(optToShow) -value "write" \
                    -command "${ns}::GenOptWidgets"
        pack $workFr.fr$row.ro $workFr.fr$row.wo -side left -fill both -expand 1

        # Scrolled frame
        set sPo(midWid) [poWin CreateScrolledFrame $optFr true ""]

        GenOptWidgets

        bind $sPo(tableId) <<TablelistSelect>> "${ns}::UpdateTable $sPo(tableId)"
        bind $sPo(fileExt) <Any-KeyRelease>    "${ns}::SaveFileExt"

        return [list [list]]
    }

    proc GenOptWidgets {} {
        variable ns
        variable sPo
        variable curType

        # Destroy the middle frame before inserting new values.
        set mid $sPo(midWid).fr
        catch { destroy $mid }
        ttk::frame $mid
        pack $mid -in $sPo(midWid) -expand 1 -fill both

        if { $sPo(optToShow) eq "read" } {
            set strNone "No read format options"
            set mode "read"
            set optList $sPo($curType,read)
        } else {
            set strNone "No write format options"
            set mode "write"
            set optList $sPo($curType,write)
        }

        set row 0
        foreach opt $optList {
            if { $opt == {} } {
                ttk::label $mid.l$row -text $strNone
                grid $mid.l$row -row $row -column 0 -columnspan 2 -sticky news
                break
            }
            set useOpt  [lindex $opt 0]
            set optName [lindex $opt 1]
            set optType [lindex $opt 2]
            set optVal  [lindex $opt 3]

            ttk::checkbutton $mid.opt$row -text $optName \
                        -variable ${ns}::sPo($curType,$mode,$optName,useOpt)
            grid $mid.opt$row -row $row -column 0 -sticky news
            switch $optType {
                bool {
                    ttk::frame $mid.fr$row
                    ttk::radiobutton $mid.fr$row.t -text "true" -value true \
                        -variable ${ns}::sPo($curType,$mode,$optName,optVal)
                    ttk::radiobutton $mid.fr$row.f -text "false" -value false \
                        -variable ${ns}::sPo($curType,$mode,$optName,optVal)
                    grid $mid.fr$row -row $row -column 1 -sticky news
                    pack $mid.fr$row.t $mid.fr$row.f -side left -in $mid.fr$row
                }
                int -
                string -
                float {
                    ttk::entry $mid.e$row -width 10 \
                        -textvariable ${ns}::sPo($curType,$mode,$optName,optVal)
                    grid $mid.e$row -row $row -column 1 -sticky news
                }
                enum {
                    set curEnum 1
                    ttk::frame $mid.fr$row
                    grid $mid.fr$row -row $row -column 1 -sticky news
                    foreach vals [lrange $opt 4 end] {
                        ttk::radiobutton $mid.fr$row.cb$curEnum -text $vals -variable \
                            ${ns}::sPo($curType,$mode,$optName,optVal) \
                            -value $vals
                        pack $mid.fr$row.cb$curEnum -side left -in $mid.fr$row
                        incr curEnum
                    }
                }
                default {
                    poLog Error "Unknown option type $optType"
                }
            }
            incr row
        }
    }

    proc LoadSettings { { cfgDir "" } } {
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename poImgType $cfgDir]
        set sPo(cfgDir) $cfgDir
        if { [poMisc IsReadableFile $cfgFile] } {
            source $cfgFile
            return 1
        } else {
            poLog Warning "Could not read cfg file $cfgFile"
            return 0
        }
    }

    proc SaveSettings {} {
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename poImgType $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal != 0 } {
            error "Cannot write to configuration file $cfgFile"
            return 0
        }

        puts $fp "# AddType type typeName extensionList readOptList writeOptList"
        foreach fmt $sPo(imgFmtList) {
            set tip [list $sPo($fmt,tip)]
            set ext [list $sPo($fmt,ext)]
            set ro  [list $sPo($fmt,read)]
            set wo  [list $sPo($fmt,write)]

            puts $fp "catch {AddType $fmt $tip $ext $ro $wo}"
        }
        close $fp
        return 1
    }

    proc OpenImgFile { w } {
        set fileTypes [GetSelBoxTypes]
        set imgName [tk_getOpenFile -filetypes $fileTypes \
                     -title "Select an image file"]
        if { $imgName != "" } {
            set ext [file extension $imgName]
            set fmt [GetOptByExt $ext "read"]
            poLog Debug "Loading image with format: \"$fmt\""
            set ph [image create photo -file $imgName -format [string tolower $fmt]]
            $w configure -image $ph
        }
    }
}

poImgType Init
