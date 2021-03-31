# Module:         poMenu
# Copyright:      Paul Obermeier 2019-2020 / paul@poSoft.de
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
        foreach { f exists } [poAppearance GetRecentFileList true] {
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

    proc AddRecentDirList { menuId cmd args } {
        foreach { f exists } [poAppearance GetRecentDirList true] {
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
