# Module:         poTree
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 03 / 14
#
# Distributed under BSD license.
#
# Module for displaying a tree widget.

namespace eval poTree {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export CreateDirTree Rescan Rescan2
    namespace export DeleteNode OpenBranch
    namespace export GetDir GetSelection
    namespace export UseSubScan

    proc UseSubScan { onOff } {
        variable pkgInt

        set pkgInt(useSubScan) $onOff
    }

    proc Rescan { w { dir "" } } {
        if { $dir eq "" } {
            set dir [GetSelection $w true]
        }

        set node [FindItemByPath $w {} $dir]
        PopulateTree $w $node
        set newNode [OpenBranch $w $dir]
        ShowFiles $w $newNode
    }

    proc Rescan2 { dir w } {
        Rescan $w $dir
    }

    proc NewFolder { val } {
        variable pkgInt

        set curTree $pkgInt(curTreeWidget)
        set curDir  $pkgInt(curDir)
        if { [file pathtype $val] eq "relative" } {
            set newFolder [file join $curDir $val]
        } else {
            set newFolder $val
        }
        catch { file mkdir $newFolder }
        DeleteNode $curTree $curDir
        set node [FindItemByPath $curTree {} [file dirname $curDir]]
        PopulateTree $curTree $node
        set newNode [OpenBranch $curTree $newFolder]
        ShowFiles $curTree $newNode
    }

    proc AskNewFolder { w } {
        variable ns
        variable pkgInt

        set curDir [GetSelection $w true]
        set pkgInt(curTreeWidget) $w
        set pkgInt(curDir) $curDir
        poWin ShowEntryBox ${ns}::NewFolder \
                           "New directory" "Create new directory" \
                           "Current directory: $curDir" 40
    }

    # Just a dummy procedure for the poToolbar::CheckButton function.
    proc ShowHiddenDirs { } {
    }

    # Just a dummy procedure for the poToolbar::CheckButton function.
    proc DoSubscan { } {
    }

    proc GetVolumeList { { forceRescan false } } {
        variable pkgInt

        if { [llength $pkgInt(volList)] == 0 || $forceRescan } {
            set pkgInt(volList) [poMisc GetDrives]
        }
        return $pkgInt(volList)
    }

    proc IsVolume { v } {
        variable pkgInt

        foreach volume [GetVolumeList] {
            if { [string compare $volume $v] == 0} {
                return 1
            }
        }
        return 0
    }

    proc Init {} {
        variable pkgInt
        global tcl_platform

        switch $tcl_platform(platform) {
            unix {
                set pkgInt(font) \
                  -adobe-helvetica-medium-r-normal-*-11-80-100-100-p-56-iso8859-1
            }
            windows {
                set pkgInt(font) \
                  -adobe-helvetica-medium-r-normal-*-14-100-100-100-p-76-iso8859-1
            }
            default {
                set pkgInt(font) "Courier"
            }
        }

        #
        # Bitmaps used to show which parts of the tree can be opened.
        #
        set maskdata "#define solid_width 9\n#define solid_height 9"
        append maskdata {
            static unsigned char solid_bits[] = {
                0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff,
                0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01
            };
        }
        set data "#define open_width 9\n#define open_height 9"
        append data {
            static unsigned char open_bits[] = {
                0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x7d,
                0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0xff, 0x01
            };
        }
        set pkgInt(openbm) [image create bitmap -data $data -maskdata $maskdata \
              -foreground black -background white]
        set data "#define closed_width 9\n#define closed_height 9"
        append data {
            static unsigned char closed_bits[] = {
                0xff, 0x01, 0x01, 0x01, 0x11, 0x01, 0x11, 0x01, 0x7d,
                0x01, 0x11, 0x01, 0x11, 0x01, 0x01, 0x01, 0xff, 0x01
            };
        }
        set pkgInt(closedbm) [image create bitmap -data $data -maskdata $maskdata \
              -foreground black -background white]

        #
        # Images used as folder and drive icons.
        #
        set pkgInt(closedfolder) [image create photo -data {
            R0lGODlhEAAQALMAAICAgAAAAMDAwP//AP///////////////wAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAACH5BAkIAAgALAAAAAAQABAAAAQ9EMlJKwUY2ytG
            F8CGAJ/nZZkEEGzrskAwEmZZxrNdn/K667iVzhakDU3F46f42wVRUJQMEaha
            r1eRdluJAAA7
        }]

        set pkgInt(openfolder) [image create photo -data {
            R0lGODlhEAAQALMAAMDAwP//AICAgAAAAP///////////////wAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAACH5BAkIAAgALAAAAAAQABAAAARFEMlJKxUY20t6
            FxsiEEBQAkSWSaPpol46iORrA8Kg7mqQj7FgDqernWy6HO3I/M1azJduRru5
            clQeb0BFcL9gcGhMrkQAADs=
        }]

        set pkgInt(floppydrive) [image create photo -data {
            R0lGODlhEAAQALMAAICAgP8AAMDAwAAAAP///////////////wAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAACH5BAkIAAgALAAAAAAQABAAAAQ2EMlJq704V8C7
            7xIgjGQ5AgNArGy7cqlpBgIskl5p1/Dgd7wYqaVDfY6dgcTHbDY10Kh0aokA
            ADs=
        }]

        set pkgInt(diskdrive) [image create photo -data {
            R0lGODlhEAAQALMAAACAAAAAAMDAwICAgP///////////////wAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAACH5BAkIAAgALAAAAAAQABAAAAQxEMlJq7046z26
            /540CGRpkkMwEGzrsp16noAQj/N52+DHy6/Xr0dMSQLIpDK5aTqfEQA7
        }]

        set pkgInt(plainfile) [image create photo -data {
            R0lGODdhEAAQAPIAAAAAAHh4eLi4uPj4+P///wAAAAAAAAAAACwAAAAAEAAQAAADPkixzPOD
            yADrWE8qC8WN0+BZAmBq1GMOqwigXFXCrGk/cxjjr27fLtout6n9eMIYMTXsFZsogXRKJf6u
            P0kCADv/
        }]

        InitVars
    }

    proc InitVars {} {
        variable pkgInt

        set pkgInt(useSubScan)  1
        set pkgInt(showHidden)  0
        set pkgInt(showFiles)   0
        set pkgInt(volList)     [list] 
    }

    proc AddToListbox { dir lbox fileList } {
        $lbox delete 0 end
        foreach elem $fileList {
            $lbox insert end $elem
        }
        poWin SetScrolledTitle $lbox "[llength $fileList] files"
    }

    proc DriveIcon { dir } {
        global tcl_platform
        variable pkgInt

        switch $tcl_platform(platform) {
            windows {
                set dir [string trimright $dir "/"]
                set dir [string trimright $dir "\\"]
                if { $dir eq "A:" || $dir eq "B:" } {
                    return $pkgInt(floppydrive)
                }
                foreach drive \
                 [list C D E F G H I J K L M N O P Q R S T U V X Y Z] {
                     if { $dir eq [format "%s:" $drive] } {
                         return $pkgInt(diskdrive)
                     }
                }
                return {}
            }
            default {
                if { $dir eq "/" } {
                    return $pkgInt(diskdrive)
                }
                return {}
            }
        }
    }

    # Retrieve the current selection
    proc GetSelection { tree { firstEntryOnly false } } {
        set itemList [$tree selection]
        set pathList [list]
        foreach item $itemList {
            lappend pathList [$tree set $item fullpath]
        }
        if { $firstEntryOnly && [llength $pathList] > 0 } {
            return [lindex $pathList 0]
        } else {
            return $pathList
        }
    }

    proc SetSelection { tree item } {
        $tree selection set $item
        SetTreeTitle $tree [$tree set $item fullpath]
    }

    proc DeleteNode { tree dir } {
        set selList [$tree selection]
        if { [llength $selList] > 0 } {
            $tree delete [list [lindex $selList 0]]
        }
    }

    proc ShowFiles { tree node } {
        variable pkgInt

        set dir [$tree set $node fullpath]
        if { ! [file isdirectory $dir] } {
            return
        }
        SetTreeTitle $tree $dir
        poWin SetScrolledTitle $tree $dir

        if { $pkgInt(showFiles) } {
            AddToListbox $dir $pkgInt(listboxId) [lsort -dictionary \
                [lindex [poMisc GetDirsAndFiles $dir \
                                -showdirs false \
                                -showfiles $pkgInt(showFiles) \
                                -showhiddendirs $pkgInt(showHidden) \
                                -showhiddenfiles $pkgInt(showHidden)] 1]]
        }
    }

    # Code to populate the roots of the tree (can be more than one on Windows)
    proc PopulateRoots {tree} {
        variable pkgInt

        foreach volume [lsort -dictionary [GetVolumeList]] {
            if { $volume eq "A:/" } {
                # Don't try to read the diskette drive when initializing the window.
                continue
            }
            set newNode [$tree insert {} end -text $volume \
                         -values [list $volume "directory"] -tags $volume]
            PopulateTree $tree $newNode
        }
    }

    # Code to populate a node of the tree
    proc PopulateTree { tree node } {
        variable pkgInt

        set path [$tree set $node fullpath]

        if {[$tree set $node type] ne "directory"} {
            return
        }
        $tree delete [$tree children $node]
        lassign [poMisc GetDirsAndFiles $path \
                       -showfiles false \
                       -showhiddendirs $pkgInt(showHidden) \
                       -showhiddenfiles $pkgInt(showHidden)] dirList
        foreach dir [lsort -dictionary $dirList] {
            set id [$tree insert $node end -text [file tail $dir] \
                    -values [list $dir "directory"] -tags $dir]

            if { [file isdirectory $dir] } {
                if { $pkgInt(useSubScan) } {
                    lassign [poMisc GetDirsAndFiles $dir \
                                    -showfiles false \
                                    -showhiddendirs $pkgInt(showHidden) \
                                    -showhiddenfiles $pkgInt(showHidden)] subDirList
                    foreach subDirName [lsort -dictionary $subDirList] {
                        set subId [$tree insert $id end -text [file tail $subDirName] \
                            -values [list $subDirName "directory"] -tags $subDirName]
                    }
                }
            }
        }
    }

    proc FindItemByPath { tree item path } {
        set childList [$tree children $item]
        if { [llength $childList] == 0 } {
            return {}
        }
        set pathLen [llength [file split $path]]
        foreach node $childList {
            set dir [$tree set $node fullpath]
            if { [string first $dir $path] == 0 } {
                if { ($dir eq $path) } {
                    return $node
                } else {
                    if { $pathLen > [llength [file split $dir]] } {
                        return [FindItemByPath $tree $node $path]
                    }
                }
            }
        }
        return {}
    }

    proc OpenBranch { w dir { setSelection true } } {
        set path ""
        set lastNode {}
        foreach p [file split [file normalize $dir]] {
            set path [file join $path $p]
            set node [FindItemByPath $w $lastNode $path]
            if { $node ne {} } {
                set lastNode $node
                set newNode $node
            } else {
                if { [file isdirectory $path] } {
                    PopulateTree $w $lastNode
                    set node [FindItemByPath $w $lastNode $path]
                    if { $node ne {} } {
                        set lastNode $node
                        set newNode $node
                    }
                }
            }
        }

        if { $setSelection } {
            SetSelection $w $newNode
        }
        $w item $newNode -open true
        $w see $newNode

        return $newNode
    }

    proc OkCmd { w } {
        variable pkgInt
        set pkgInt(selectedDir) [GetSelection $w true]
    }

    proc CancelCmd { w } {
        variable pkgInt
        set pkgInt(selectedDir) ""
    }

    proc InitOpen { tree initialDir } {
        variable ns

        PopulateRoots $tree
        bind $tree <<TreeviewOpen>>   { poTree::PopulateTree %W [%W focus] }
        bind $tree <<TreeviewSelect>> { poTree::ShowFiles %W [%W focus] }

        if { $initialDir ne "" } {
            OpenBranch $tree [file normalize $initialDir]
        }
        ShowFiles $tree [$tree selection]
    }

    proc SetTreeTitle { tree title } {
        $tree heading \#0 -text $title
    }

    # Create the treeview and open it with directory initialDir.
    proc CreateDirTree { fr { initialDir "" } { title "" } } {
        set tree [poWin CreateScrolledTree $fr true "" \
                  -columns {fullpath type} -displaycolumns {}]
        SetTreeTitle $tree $title

        InitOpen $tree $initialDir
        return $tree
    }

    # Syntax as tk_getOpenFile.
    # Supports only two options: 
    # -title name            Default: Open
    # -initialdir name       Default: [pwd]
    # -rootdir name          Default: [poMisc GetDrives]
    # -subscan 1|0           Default: No subdirectory scanning (0)
    # -showhidden 1|0        Default: No hidden Directories and files are shown (0)

    proc GetDir { args } {
        variable ns
        variable pkgInt

        # Set default values for parameters.
        InitVars
        set initialDir [pwd]
        set title "Select directory"

        # Scan parameters.
        foreach { opt val } $args {
            switch -exact -- $opt {
                -subscan     { if { $val ne "" } { set pkgInt(useSubScan)  $val } }
                -showhidden  { if { $val ne "" } { set pkgInt(showHidden)  $val } }
                -showfiles   { if { $val ne "" } { set pkgInt(showFiles)   $val } }
                -rootdir     { if { $val ne "" && \
                                    [file isdirectory [file nativename $val]] } {
                                   set pkgInt(volList) [list [file normalize $val]] } }
                -initialdir  { if { $val ne "" && \
                                    [file isdirectory [file nativename $val]] } {
                                   set initialDir [file normalize $val]
                               }
                             }
                -title       { set title $val }
            }
        }

        # If rootdir is specified, initialdir must be a sub-directory of rootdir.
        if { [llength $pkgInt(volList)] > 0 } {
            if { [string first $initialDir $pkgInt(volList)] != 0 } {
                set initialDir $pkgInt(volList)
            }
        }

        # Create toplevel window.
        set tw .poTree_GetDir

        if { [winfo exists $tw] } {
            destroy $tw
        }
        toplevel $tw

        # Toplevel container.
        ttk::frame $tw.fr -width 300 -height 200
        pack $tw.fr -fill both -expand 1

        $tw config -cursor watch
        wm title $tw "Scanning directories, please wait ..."
        update

        # A container for the tree and one for the buttons.
        set span 1
        ttk::frame $tw.fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $tw.fr.dirfr
        ttk::frame $tw.fr.okfr
        if { $pkgInt(showFiles) } {
            ttk::frame $tw.fr.filefr
            set span 2
        }
        grid $tw.fr.toolfr -row 0 -column 0 -sticky news -ipady 2 -columnspan $span
        grid $tw.fr.dirfr  -row 1 -column 0 -sticky news -ipady 2
        grid $tw.fr.okfr   -row 2 -column 0 -sticky news -ipady 2 -columnspan $span
        grid rowconfigure $tw.fr 1 -weight 1
        grid columnconfigure $tw.fr 0 -weight 1

        if { $pkgInt(showFiles) } {
            grid $tw.fr.filefr -row 1 -column 1 -sticky news -ipady 2
            grid columnconfigure $tw.fr 1 -weight 2
            set pkgInt(listboxId) [poWin CreateScrolledListbox $tw.fr.filefr true \
                           "File list" \
                           -selectmode extended -exportselection false \
                           -width 30 -height 20]
        }

        # Create the tree and set it up
        set treeView [CreateDirTree $tw.fr.dirfr $initialDir \
                      "Select directory"]

        # Add toolbar group and associated buttons.
        set toolfr $tw.fr.toolfr
        poToolbar New $toolfr
        poToolbar AddGroup $toolfr

        poToolbar AddButton $toolfr [::poBmpData::createfolder] \
                  "${ns}::AskNewFolder $treeView" "Create new directory"
        poToolbar AddButton $toolfr [::poBmpData::rescan] \
                  "${ns}::Rescan $treeView" "Rescan current directory"

        # Add toolbar group and associated checkbuttons.
        poToolbar AddGroup $toolfr
        poToolbar AddCheckButton $toolfr [::poBmpData::hidden] \
                  ${ns}::ShowHiddenDirs "Show hidden directories and files" \
                  -variable ${ns}::pkgInt(showHidden)
        poToolbar AddCheckButton $toolfr [::poBmpData::subscan] \
                  ${ns}::DoSubscan "Do a subdirectory scan" \
                  -variable ${ns}::pkgInt(useSubScan)

        # Create Cancel and OK buttons
        ttk::button $tw.fr.okfr.b1 -text "Cancel" -image [poWin GetCancelBitmap] \
                                   -compound left -command "${ns}::CancelCmd $treeView"
        ttk::button $tw.fr.okfr.b2 -text "OK" -image [poWin GetOkBitmap] \
                                   -compound left -command "${ns}::OkCmd $treeView" \
                                   -default active
        wm protocol $tw WM_DELETE_WINDOW "${ns}::CancelCmd $treeView"
        bind  $tw <KeyPress-Escape> "${ns}::CancelCmd $treeView"
        bind  $tw <KeyPress-Return> "${ns}::OkCmd $treeView"
        pack $tw.fr.okfr.b1 $tw.fr.okfr.b2 -side left -fill x -expand 1

        wm title $tw $title
        $tw config -cursor top_left_arrow

        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if {$oldGrab != ""} {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $tw

        tkwait variable ${ns}::pkgInt(selectedDir)

        catch {focus $oldFocus}
        grab release $tw
        wm withdraw $tw
        if {$oldGrab != ""} {
            if {$grabStatus == "global"} {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }

        return $pkgInt(selectedDir)
    }
}

poTree Init
