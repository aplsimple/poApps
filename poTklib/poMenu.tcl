# Module:         poMenu
# Copyright:      Paul Obermeier 2019-2023 / paul@poSoft.de
# First Version:  2019 / 08 / 10
#
# Distributed under BSD license.

namespace eval poMenu {
    variable ns [namespace current]

    namespace ensemble create

    namespace export AddCommand
    namespace export AddRadio
    namespace export AddCheck
    namespace export AddRecentDirList
    namespace export AddRecentFileList
    namespace export DeleteMenuEntries

    proc AddCommand { menu label acc cmd args } {
        $menu add command -label $label -accelerator $acc -command $cmd {*}$args
    }

    proc AddRadio { menu label acc var val cmd args } {
        $menu add radiobutton -label $label -accelerator $acc \
                              -variable $var -value $val -command $cmd {*}$args
    }

    proc AddCheck { menu label acc var cmd args } {
        $menu add checkbutton -label $label -accelerator $acc \
                              -variable $var -command $cmd {*}$args
    }

    proc DeleteMenuEntries { menuId startInd } {
        set retVal [catch { $menuId index end } endInd]
        if { $retVal == 0 } {
            if { $endInd >= $startInd } {
                $menuId delete $startInd $endInd
            }
        }
    }

    proc AddRecentFileList { menuId cmd args } {
        set extList [list]
        set params  [list]
        set foundExt false
        foreach value $args {
            if { $value eq "-extensions" } {
                set foundExt true
            } elseif { $foundExt } {
                set extList $value
                set foundExt false
            } else {
               lappend params $value
           }
        }
        foreach { f exists } [poAppearance GetRecentFiles -check true -extensions $extList] {
            if { $exists } {
                set bmp [poWin GetOkBitmap]
            } else {
                set bmp [poWin GetCancelBitmap]
            }
            if { [llength $params] > 0 } {
                AddCommand $menuId $f "" [list $cmd $f $params] -image $bmp -compound left
            } else {
                AddCommand $menuId $f "" [list $cmd $f] -image $bmp -compound left
            }
        }
    }

    proc AddRecentDirList { menuId cmd args } {
        foreach { f exists } [poAppearance GetRecentDirs true] {
            if { $exists } {
                set bmp [poWin GetOkBitmap]
            } else {
                set bmp [poWin GetCancelBitmap]
            }
            if { [llength $args] > 0 } {
                AddCommand $menuId $f "" [list $cmd $f $args] -image $bmp -compound left
            } else {
                AddCommand $menuId $f "" [list $cmd $f] -image $bmp -compound left
            }
        }
    }

}
