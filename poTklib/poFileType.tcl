# Module:         poFileType
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 05 / 01
#
# Distributed under BSD license.
#
# Module for handling and displaying file types.

namespace eval poFileType {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export GetTypeList GetTypeMatches
    namespace export GetDiffProg GetEditProg GetHexEditProg GetColor
    namespace export LoadSettings SaveSettings

    proc AddType { typeName guiDiff editor hexedit color matchList { overwrite true } } {
        variable sPo

        if { ! [info exists sPo(typeList)] } {
            set sPo(typeList) [list]
        }
        if { [lsearch -exact $sPo(typeList) $typeName] < 0 } {
            lappend sPo(typeList) $typeName
            set overwrite true
        }

        if { $overwrite } {
            set sPo($typeName,guiDiff) $guiDiff
            set sPo($typeName,editor)  $editor
            set sPo($typeName,hexedit) $hexedit
            set sPo($typeName,color)   $color
            set sPo($typeName,match)   [lsort $matchList]
        }
    }

    proc Init {} {
        variable winName
        variable sPo
        variable msgStr

        set winName ".poFileType:SettWin"

        set sPo(changed) false
        set sPo(saveFileMatch) true

        # Add the reserved types in reverse order, because new types
        # are inserted at the top of the list.
        set sPo(reservedName,all)  "Other files"
        set sPo(reservedName,img)  "Image files"
        set sPo(reservedName,cpp)  "C/C++ files"
        set sPo(reservedName,tcl)  "Tcl files"
        set sPo(reservedName,make) "Make files"
        set sPo(reservedName,xls)  "Excel files"
        set sPo(reservedName,doc)  "Word files"
        set sPo(reservedName,ppt)  "PowerPoint files"

        array set msgStr [list \
            NewType     "Create a new file type (Ctrl+N)" \
            DelType     "Delete current file type from list (Del)" \
            ShiftUp     "Shift current file type up" \
            ShiftDown   "Shift current file type down" \
            RenameType  "Rename current file type (F2)" \
            UpdImgType  "Update image matching from Image type settings" \
            FileTypes   "File types" \
            GuiDiff     "GUI Diff:" \
            Editor      "Editor:" \
            HexEdit     "Hex Editor:" \
            Color       "Text color:" \
            TestField   "Test field" \
            FileMatch   "File match:" \
            NewTypeName "New type" \
            SelHexEdit  "Select Hex Editor" \
            SelEditor   "Select editor" \
            SelGuiDiff  "Select graphical diff program" \
            MsgSelType  "Please select a file type first." \
            EnterType   "Enter file type name" \
            TypeExists  "Filetype \"%s\" already exists." \
            MsgDelType  "Delete file type \"%s\"?" \
            Confirm     "Confirmation" \
            WinTitle    "File type settings" \
        ]
    }

    proc CreateDefaultTypes { overwrite } {
        variable sPo

        AddType $sPo(reservedName,ppt) "" "" "" "black" \
                [list "*.ppt" "*.pptx"] $overwrite
        AddType $sPo(reservedName,doc) "" "" "" "black" \
                [list "*.doc" "*.docx"] $overwrite
        AddType $sPo(reservedName,xls) "" "" "" "black" \
                [list "*.xls" "*.xlsx"] $overwrite
        AddType $sPo(reservedName,make) "" "" "" "black" \
                [list "*.mk" "?akefile" "CMakeLists.txt"] $overwrite
        AddType $sPo(reservedName,tcl) "" "" "" "black" \
                [list "*.tcl" "*.tm"] $overwrite
        AddType $sPo(reservedName,cpp) "" "" "" "black" \
                [list "*.h" "*.hxx" "*.c" "*.cpp" "*.cxx"] $overwrite
        AddType $sPo(reservedName,img) "" "" "" "purple" \
                [list "*.bmp"  "*.dt0"  "*.dt1"  "*.dt2"  "*.gif"  \
                      "*.ico"  "*.jp2"  "*.jpg"  "*.jpeg" "*.jfif" \
                      "*.pcx"  "*.png"  "*.pgm"  "*.ppm"  "*.raw"  \
                      "*.rgb"  "*.rgba" "*.bw"   "*.int"  "*.inta" \
                      "*.ras"  "*.sun"  "*.svg"  "*.tga"  "*.tif"  \
                      "*.tiff" "*.xbm"  "*.xpm"] $overwrite
        AddType $sPo(reservedName,all) "" "" "" "black" \
                [list "*" ".??*"] $overwrite
    }

    proc _IsReservedType { type } {
        variable sPo

        foreach reservedType [array names sPo "reservedName,*"] {
            if { $type eq $sPo($reservedType) } {
                return true
            }
        }
        return false
    }

    proc GetTypeList {} {
        variable sPo

        if { ! [info exists sPo(typeList)] } {
            CreateDefaultTypes true
        }
        return $sPo(typeList)
    }

    proc GetTypeMatches { type } {
        variable sPo

        if { [info exists sPo($type,match)] } {
            return $sPo($type,match)
        } else {
            return [list]
        }
    }

    proc Str { key args } {
        variable msgStr

        set str $msgStr($key)
        return [format $str {*}$args]
    }

    proc UpdateTable { tableId typeList showInd } {
        $tableId delete 0 end
        foreach type $typeList {
            $tableId insert end [list $type]
            if { [_IsReservedType $type] } {
                $tableId rowconfigure end -background "#D0D000"
            }
        }
        $tableId selection set $showInd
        set curType [$tableId get $showInd]
        event generate $tableId <<TablelistSelect>>
    }

    proc CloseWin { w } {
        catch { destroy $w }
    }

    proc CancelWin { w args } {
        variable sPo

        poToolhelp HideToolhelp
        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        CloseWin $w
    }

    proc OkWin { w } {
        SaveFileMatch
        CloseWin $w
    }

    proc SaveFileMatch {} {
        variable sPo
        variable curType

        set fileType $curType
        set widgetCont [$sPo(fileMatchWidget) get 1.0 end]
        regsub -all -- {\n} $widgetCont " " matchStr
        set sPo($fileType,match) $matchStr
    }

    proc AskColor { w rootWin } {
        variable sPo
        variable curType

        set newColor [tk_chooseColor -initialcolor $sPo($curType,color)]
        if { $newColor ne "" } {
            set sPo($curType,color) $newColor
            # Settings window may have already been closed. So catch it.
            catch { $w configure -foreground $newColor }
        }
        if { [winfo exists $rootWin] && [poWin IsToplevel $rootWin] } {
            poWin Raise $rootWin
        }
    }

    proc GetEditor { w rootWin } {
        variable sPo
        variable curType

        set tmp [poExtProg GetExecutable [Str SelEditor]]
        if { $tmp ne "" } {
            set sPo($curType,editor) $tmp
            # Settings window may have already been closed.
            if { ! [winfo exists $rootWin] } {
                return
            }
            if { [string length $tmp] > [$w cget -width] } {
                $w xview moveto 1
            }
        }
        if { [winfo exists $rootWin] && [poWin IsToplevel $rootWin] } {
            poWin Raise $rootWin
        }
    }

    proc GetHexEditor { w rootWin } {
        variable sPo
        variable curType

        set tmp [poExtProg GetExecutable [Str SelHexEdit]]
        if { $tmp ne "" } {
            set sPo($curType,hexedit) $tmp
            # Settings window may have already been closed.
            if { ! [winfo exists $rootWin] } {
                return
            }
            if { [string length $tmp] > [$w cget -width] } {
                $w xview moveto 1
            }
        }
        if { [winfo exists $rootWin] && [poWin IsToplevel $rootWin] } {
            poWin Raise $rootWin
        }
    }

    proc GetGuiDiff { w rootWin } {
        variable sPo
        variable curType

        set tmp [poExtProg GetExecutable [Str SelGuiDiff]]
        if { $tmp ne "" } {
            set sPo($curType,guiDiff) $tmp
            # Settings window may have already been closed.
            if { ! [winfo exists $rootWin] } {
                return
            }
            if { [string length $tmp] > [$w cget -width] } {
                $w xview moveto 1
            }
        }
        if { [winfo exists $rootWin] && [poWin IsToplevel $rootWin] } {
            poWin Raise $rootWin
        }
    }

    proc UpdateType { guiDiffEntry editorEntry hexEditEntry colorList } {
        variable ns
        variable sPo
        variable curType

        set matchText $sPo(fileMatchWidget)

        # Restore the file match entries of the previous type.
        if { $sPo(saveFileMatch) } {
            SaveFileMatch
        }

        if { ! [poTablelistUtil IsRowSelected $sPo(tableId)] } {
            return
        }
        set curInd [poTablelistUtil GetFirstSelectedRow $sPo(tableId)]
        set curType [lindex [$sPo(tableId) get $curInd] 0]

        if { [_IsReservedType $curType] } {
            $sPo(delButton) configure -state disabled
            $sPo(renButton) configure -state disabled
        } else {
            $sPo(delButton) configure -state normal
            $sPo(renButton) configure -state normal
        }

        if { $curType eq $sPo(reservedName,img) } {
            $sPo(updImgButton) configure -state normal
        } else {
            $sPo(updImgButton) configure -state disabled
        }
        $guiDiffEntry configure -textvariable ${ns}::sPo($curType,guiDiff)
        $editorEntry  configure -textvariable ${ns}::sPo($curType,editor)
        $hexEditEntry configure -textvariable ${ns}::sPo($curType,hexedit)
        $colorList    configure -foreground $::poFileType::sPo($curType,color)
        $guiDiffEntry xview moveto 1
        $editorEntry  xview moveto 1
        $hexEditEntry xview moveto 1
        $matchText delete 1.0 end
        foreach match $sPo($curType,match) {
            $matchText insert end "$match\n"
        }
    }

    proc AskRename {} {
        variable sPo
        variable curType
        variable winId

        if { ! [poTablelistUtil IsRowSelected $sPo(tableId)] } {
            tk_messageBox -message [Str MsgSelType] -icon info -type ok
            return
        }
        set curInd [poTablelistUtil GetFirstSelectedRow $sPo(tableId)]
        
        set x [winfo pointerx $winId]
        set y [winfo pointery $winId]
        lassign [poWin EntryBox $curType $x $y 20] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName ne "" } {
            Rename $retName
        }
    }

    proc Rename { val } {
        variable sPo
        variable curType

        if { [lsearch -exact $sPo(typeList) $val] >= 0 } {
            tk_messageBox -message [Str TypeExists $val] \
                          -icon warning -type ok
            return
        }
        set oldTypeInd [lsearch -exact $sPo(typeList) $curType]
        set sPo(typeList) [lreplace $sPo(typeList) $oldTypeInd $oldTypeInd $val]

        set valInd [lsearch $sPo(typeList) $val]
        set sPo($val,editor)  $sPo($curType,editor)
        set sPo($val,guiDiff) $sPo($curType,guiDiff)
        set sPo($val,hexedit) $sPo($curType,hexedit)
        set sPo($val,color)   $sPo($curType,color)
        set sPo($val,match)   $sPo($curType,match)
        unset sPo($curType,editor)
        unset sPo($curType,guiDiff)
        unset sPo($curType,hexedit)
        unset sPo($curType,color)
        unset sPo($curType,match)
        UpdateTable $sPo(tableId) $sPo(typeList) $valInd
    }

    proc AskNew {} {
        variable winId

        set x [winfo pointerx $winId]
        set y [winfo pointery $winId]
        lassign [poWin EntryBox [Str NewTypeName] $x $y 20] retVal retName
        if { ! $retVal } {
            # User pressed Escape.
            return
        }
        if { $retName ne "" } {
            New $retName
        }
    }

    proc New { val } {
        variable sPo
        variable curType

        if { [lsearch -exact $sPo(typeList) $val] >= 0 } {
            tk_messageBox -message [Str TypeExists $val] \
                          -icon warning -type ok
            return
        }
        set sPo(typeList) [linsert $sPo(typeList) 0 $val]

        set valInd [lsearch $sPo(typeList) $val]
        set sPo($val,guiDiff) ""
        set sPo($val,editor)  ""
        set sPo($val,hexedit) ""
        set sPo($val,color)   "black"
        set sPo($val,match)   ""
        set sPo(saveFileMatch) false
        UpdateTable $sPo(tableId) $sPo(typeList) $valInd
        set sPo(saveFileMatch) true
    }

    proc AskDel { rootWin } {
        variable sPo

        if { ! [poTablelistUtil IsRowSelected $sPo(tableId)] } {
            tk_messageBox -message [Str MsgSelType] -icon info -type ok
            return
        }
        set curInd [poTablelistUtil GetFirstSelectedRow $sPo(tableId)]

        set type [lindex $sPo(typeList) $curInd]
        set retVal [tk_messageBox -icon question -type yesno -default yes \
                -message [Str MsgDelType $type] -title [Str Confirm]]
        if { $retVal eq "yes" } {
            if { $curInd > 0 } {
                set tmpList [lrange $sPo(typeList) 0 [expr $curInd -1]]
            } else {
                set tmpList {}
            }
            foreach elem [lrange $sPo(typeList) [expr $curInd +1] end] {
                lappend tmpList $elem
            }
            set sPo(typeList) $tmpList
            unset sPo($type,editor)
            unset sPo($type,guiDiff)
            unset sPo($type,hexedit)
            unset sPo($type,color)
            unset sPo($type,match)
            set sPo(saveFileMatch) false
            UpdateTable $sPo(tableId) $sPo(typeList) $curInd
            set sPo(saveFileMatch) true
        }
        if { [winfo exists $rootWin] && [poWin IsToplevel $rootWin] } {
            poWin Raise $rootWin
        }
    }

    proc ShiftType { dir } {
        variable sPo

        set shiftList [poTablelistUtil ShiftRow $sPo(tableId) $dir]
        set targetRow [lindex $shiftList]
        if { $targetRow >= 0 } {
            set sPo(typeList) [list]
            for { set i 0 } { $i < [$sPo(tableId) size] } { incr i } {
                lappend sPo(typeList) [lindex [$sPo(tableId) get $i] 0]
            }
            set curType [$sPo(tableId) get $targetRow]
        }
    }

    proc UpdImgType {} {
        variable sPo

        poImgType LoadSettings $sPo(cfgDir)
        $sPo(fileMatchWidget) delete 1.0 end
        foreach ext [lsort [poImgType GetExtList]] {
            $sPo(fileMatchWidget) insert end [format "*%s\n" $ext]
        }
    }

    proc _NormalizePath { w } {
        set path [string trim [$w get] "\""]
        if { [file pathtype $path] eq "absolute" } {
            set path [file normalize $path]
        }
        $w delete 0 end
        $w insert 0 [format "\"%s\"" $path]
    }

    proc _SetProgByDrop { progType fileList } {
        variable curType
        variable sPo

        foreach f $fileList {
            if { [file executable $f] } {
                set sPo($curType,$progType) [format "\"%s\"" $f]
                return
            }
        }
    }

    proc _SetEditorByDrop { w fileList } {
        _SetProgByDrop "editor" $fileList
    }

    proc _SetHexEditorByDrop { w fileList } {
        _SetProgByDrop "hexedit" $fileList
    }

    proc _SetGuiDiffByDrop { w fileList } {
        _SetProgByDrop "guiDiff" $fileList
    }

    proc OpenWin { fr } {
        variable ns
        variable winId
        variable sPo
        variable curType

        set tw $fr
        set winId $tw

        if { ! [info exists sPo(typeList)] } {
            CreateDefaultTypes true
        }

        ttk::frame $tw.toolfr -borderwidth 1
        ttk::frame $tw.typefr
        ttk::frame $tw.workfr
        grid $tw.toolfr -row 0 -column 0 -columnspan 2 -sticky w
        grid $tw.typefr -row 1 -column 0 -sticky news
        grid $tw.workfr -row 1 -column 1 -sticky news
        grid rowconfigure    $tw 1 -weight 1
        grid columnconfigure $tw 0 -weight 1
        grid columnconfigure $tw 1 -weight 1

        # Add new toolbar group and associated buttons.
        set toolfr $tw.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::newfile] \
                  ${ns}::AskNew [Str NewType]
        set sPo(delButton) [poToolbar AddButton $toolfr [::poBmpData::delete "red"] \
                  "${ns}::AskDel $tw" [Str DelType]]
        set sPo(renButton) [poToolbar AddButton $toolfr [::poBmpData::rename] \
                  ${ns}::AskRename [Str RenameType]]

        poToolbar AddGroup $toolfr
        poToolbar AddButton $toolfr [::poBmpData::up] \
                  "${ns}::ShiftType -1" [Str ShiftUp]
        poToolbar AddButton $toolfr [::poBmpData::down] \
                  "${ns}::ShiftType 1" [Str ShiftDown]

        poToolbar AddGroup $toolfr
        set sPo(updImgButton) [poToolbar AddButton $toolfr [::poBmpData::update] \
                  ${ns}::UpdImgType [Str UpdImgType]]

        bind $tw <Control-n> "${ns}::AskNew"
        bind $tw <Delete>    "${ns}::AskDel $tw"
        bind $tw <F2>        "${ns}::AskRename"

        set varList {}
        set curInd 0
        set curType [lindex $sPo(typeList) $curInd]

        set tf $tw.typefr
        set sPo(tableId) [poWin CreateScrolledTablelist $tf true ""  \
            -columns [list 0  [Str FileTypes] "left"] \
            -height 10 \
            -exportselection false \
            -stripebackground [poAppearance GetStripeColor] \
            -stretch all \
            -showseparators 1]
        UpdateTable $sPo(tableId) $sPo(typeList) 0

        set tmpList [list [list sPo(typeList)] [list $sPo(typeList)]]
        lappend varList $tmpList

        set wf $tw.workfr
        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           [Str GuiDiff] \
                           [Str Editor] \
                           [Str HexEdit] \
                           [Str Color] \
                           [Str FileMatch] ] {
            ttk::label $wf.l$row -text $labelStr
            grid  $wf.l$row -row $row -column 0 -sticky new -pady 2
            incr row
        }

        # Generate right column with entries and buttons.
        # Row 0: External GUI diff
        set row 0
        ttk::frame $wf.fr$row
        grid $wf.fr$row -row $row -column 1 -sticky new

        ttk::entry $wf.fr$row.e -textvariable ${ns}::sPo($curType,guiDiff)
        $wf.fr$row.e xview moveto 1
        poToolhelp AddBinding $wf.fr$row.e "If empty, use built-in diff"
        bind $wf.fr$row.e <Key-Return> "${ns}::_NormalizePath $wf.fr$row.e"
        ttk::button $wf.fr$row.b -text "Select ..." \
                    -command "${ns}::GetGuiDiff $wf.fr$row.e $tw"
        pack $wf.fr$row.e $wf.fr$row.b -side left -anchor w
        poDragAndDrop AddTtkBinding $wf.fr$row.e ${ns}::_SetGuiDiffByDrop
        foreach t $sPo(typeList) {
            set tmpList [list [list sPo($t,guiDiff)] [list $sPo($t,guiDiff)]]
            lappend varList $tmpList
        }

        # Row 1: External editor
        incr row
        ttk::frame $wf.fr$row
        grid $wf.fr$row -row $row -column 1 -sticky new

        ttk::entry $wf.fr$row.e -textvariable ${ns}::sPo($curType,editor)
        $wf.fr$row.e xview moveto 1
        poToolhelp AddBinding $wf.fr$row.e "If empty, use built-in editor"
        bind $wf.fr$row.e <Key-Return> "${ns}::_NormalizePath $wf.fr$row.e"
        ttk::button $wf.fr$row.b -text "Select ..." \
                    -command "${ns}::GetEditor $wf.fr$row.e $tw"
        pack $wf.fr$row.e $wf.fr$row.b -side left -anchor w
        poDragAndDrop AddTtkBinding $wf.fr$row.e ${ns}::_SetEditorByDrop
        foreach t $sPo(typeList) {
            set tmpList [list [list sPo($t,editor)] [list $sPo($t,editor)]]
            lappend varList $tmpList
        }

        # Row 2: Hexdump editor
        incr row
        ttk::frame $wf.fr$row
        grid $wf.fr$row -row $row -column 1 -sticky new

        ttk::entry $wf.fr$row.e -textvariable ${ns}::sPo($curType,hexedit)
        $wf.fr$row.e xview moveto 1
        poToolhelp AddBinding $wf.fr$row.e "If empty, use built-in hex editor"
        bind $wf.fr$row.e <Key-Return> "${ns}::_NormalizePath $wf.fr$row.e"
        ttk::button $wf.fr$row.b -text "Select ..." \
                    -command "${ns}::GetHexEditor $wf.fr$row.e $tw"
        pack $wf.fr$row.e $wf.fr$row.b -side left -anchor w
        poDragAndDrop AddTtkBinding $wf.fr$row.e ${ns}::_SetHexEditorByDrop
        foreach t $sPo(typeList) {
            set tmpList [list [list sPo($t,hexedit)] [list $sPo($t,hexedit)]]
            lappend varList $tmpList
        }

        # Row 3: Color coding for this type
        incr row
        ttk::frame $wf.fr$row
        grid $wf.fr$row -row $row -column 1 -sticky new

        # Don't use a ttk::label because of Mac
        label $wf.fr$row.l -background white -foreground $sPo($curType,color)
        $wf.fr$row.l configure -text [Str TestField]
        ttk::button $wf.fr$row.b -text "Select ..." \
                    -command "${ns}::AskColor $wf.fr$row.l $tw"
        pack $wf.fr$row.l -side left -anchor w -expand 1 -fill x
        pack $wf.fr$row.b -side left
        foreach t $sPo(typeList) {
            set tmpList [list [list sPo($t,color)] [list $sPo($t,color)]]
            lappend varList $tmpList
        }

        # Row 4: File matching rules (glob style)
        incr row
        ttk::frame $wf.fr$row
        grid $wf.fr$row -row $row -column 1 -sticky new
        set fileMatch [poWin CreateScrolledText $wf.fr$row true \
                       "" -background white -wrap none -width 20 -height 6]
        poToolhelp AddBinding $fileMatch "Specify glob-style pattern"
        set sPo(fileMatchWidget) $fileMatch

        # Fill the text widgets with the entries of the file match lists.
        foreach match [lsort $sPo($curType,match)] {
            $fileMatch insert end "$match\n"
        }
        foreach t $sPo(typeList) {
            set tmpList [list [list sPo($t,match)] [list $sPo($t,match)]]
            lappend varList $tmpList
        }

        bind $sPo(tableId) <<TablelistSelect>> "${ns}::UpdateType $wf.fr0.e $wf.fr1.e $wf.fr2.e $wf.fr3.l"
        UpdateType $wf.fr0.e $wf.fr1.e $wf.fr2.e $wf.fr3.l

        bind $fileMatch <Any-KeyRelease> "${ns}::SaveFileMatch"

        return $varList
    }

    proc GetProgByFile { fileName progType } {
        variable sPo

        if { ! [info exists sPo(typeList)] } {
            CreateDefaultTypes true
        }
        # Only use the pure filename (without path) for matching.
        set fileName [file tail $fileName]
        foreach type $sPo(typeList) {
            foreach match $sPo($type,match) {
                if { [string match -nocase $match $fileName] } {
                    set retVal $sPo($type,$progType)
                    if { $retVal eq "" } {
                        if { $type eq $sPo(reservedName,img) } {
                            if { $progType eq "editor" } {
                                set retVal "poImgview"
                            } elseif { $progType eq "guiDiff" } {
                                set retVal "poImgdiff"
                            }
                        } elseif { $type eq $sPo(reservedName,xls) } {
                            if { $progType eq "guiDiff" } {
                                set retVal "ExcelDiff"
                            }
                        } elseif { $type eq $sPo(reservedName,doc) } {
                            if { $progType eq "guiDiff" } {
                                set retVal "WordDiff"
                            }
                        } elseif { $sPo($sPo(reservedName,all),$progType) ne "" } {
                            set retVal $sPo($sPo(reservedName,all),$progType)
                        }
                    }
                    return $retVal
                }
            }
        }
        return ""
    }

    proc GetColorByFile { fileName } {
        variable sPo

        if { ! [info exists sPo(typeList)] } {
            CreateDefaultTypes true
        }
        # Only use the pure filename (without path) for matching.
        set fileName [file tail $fileName]
        foreach type $sPo(typeList) {
            foreach match $sPo($type,match) {
                if { [string match -nocase $match $fileName] } {
                    return $sPo($type,color)
                }
            }
        }
        return ""
    }

    proc GetDiffProg { fileName } {
        # Return the diff program associated with "fileName".
        # Association is not limited to an extension, but can be
        # any valid glob-style expression.
        return [GetProgByFile $fileName guiDiff]
    }

    proc GetEditProg { fileName } {
        # Return the edit/view program associated with "fileName".
        # Association is not limited to an extension, but can be
        # any valid glob-style expression.
        return [GetProgByFile $fileName editor]
    }

    proc GetHexEditProg { fileName } {
        # Return the hexdump program associated with "fileName".
        # Association is not limited to an extension, but can be
        # any valid glob-style expression.
        return [GetProgByFile $fileName hexedit]
    }

    proc GetColor { fileName } {
        # Return the color associated with "fileName".
        # Association is not limited to an extension, but can be
        # any valid glob-style expression.
        return [GetColorByFile $fileName]
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename poFileType $cfgDir]
        set sPo(cfgDir) $cfgDir
        if { [poMisc IsReadableFile $cfgFile] } {
            source $cfgFile
            CreateDefaultTypes false
            return 1
        } else {
            poLog Warning "Could not read cfg file $cfgFile"
            return 0
        }
    }

    proc SaveSettings {} {
        variable winName
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename poFileType $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal != 0 } {
            error "Cannot write to configuration file $cfgFile"
            return 0
        }

        if { ! [info exists sPo(typeList)] } {
            CreateDefaultTypes true
        }
        puts $fp "# AddType typeName guiDiff editor hexeditor color matchList"
        foreach type $sPo(typeList) {
            set quType  [list $type]
            set guiDiff [list $sPo($type,guiDiff)]
            set editor  [list $sPo($type,editor)]
            set hexedit [list $sPo($type,hexedit)]
            set color   [list $sPo($type,color)]
            set match   [list $sPo($type,match)]
            puts $fp "catch {AddType $quType $guiDiff $editor\
                     $hexedit $color $match}"
        }
        close $fp
        return 1
    }
}

poFileType Init
