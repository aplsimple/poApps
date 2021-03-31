# Module:         poToolbar
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Module for building and handling a toolbar.

namespace eval poToolbar {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export New
    namespace export AddGroup
    namespace export AddLabel
    namespace export AddButton
    namespace export AddCheckButton
    namespace export AddRadioButton
    namespace export AddEntry
    namespace export AddCombobox
    namespace export AddSpinbox

    proc Init {} {
    }

    proc _AddRowOrColFrame { w } {
        variable sPo

        incr sPo($w,grp)
        set curGrp $sPo($w,grp)
        set sPo($w,fr,$curGrp) $w.fr.fr_$curGrp
        ttk::frame $sPo($w,fr,$curGrp)
        if { $sPo($w,ori) eq "horizontal" } {
            pack $sPo($w,fr,$curGrp) -side top -fill x -expand 1
        } else {
            pack $sPo($w,fr,$curGrp) -side left -fill y -expand 1
        }
    }

    proc _GenWidgetName { w } {
        variable sPo

        set curGrp $sPo($w,grp)
        set widgetName $sPo($w,fr,$curGrp).w_$sPo($w,num)
        incr sPo($w,num)
        return $widgetName
    }

    proc New { w { orient "horizontal" } } {
        variable sPo

        set sPo($w,ori) $orient
        set sPo($w,grp) 0
        set sPo($w,num) 1
        if { $sPo($w,ori) eq "horizontal" } {
            set sPo($w,side) left
        } else {
            set sPo($w,side) top
        }

        if { [info exists sPo($w,fr)] && [winfo exists $sPo($w,fr)] } {
            destroy $sPo($w,fr)
        }
        set sPo($w,fr) $w.fr
        ttk::frame $sPo($w,fr)
        pack $sPo($w,fr) -side top -fill both -expand 1

        _AddRowOrColFrame $w
    }

    proc AddGroup { w { newRowOrCol false } } {
        variable sPo

        if { $newRowOrCol } {
            _AddRowOrColFrame $w
        }

        set curGrp $sPo($w,grp)
        set t [_GenWidgetName $w]
        ttk::frame $t
        set sep $t.sep
        if { $sPo($w,ori) eq "horizontal" } {
            pack $t -side $sPo($w,side) -fill y
            ttk::separator $sep -orient vertical
            pack $sep -side left -fill y -padx 2
        } else {
            pack $t -side $sPo($w,side) -fill x
            ttk::separator $sep -orient horizontal
            pack $sep -side top -fill x -pady 2
        }
        return $t
    }

    proc AddLabel { w bmpImg str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        if { ! [poImgMisc IsPhoto $bmpImg] } {
            eval ttk::label $widgetName -text [list $bmpImg] $args
        } else {
            eval ttk::label $widgetName -image $bmpImg $args
        }
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddButton { w bmpImg cmd str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        if { ! [poImgMisc IsPhoto $bmpImg] } {
            eval ttk::button $widgetName -text [list $bmpImg] -style Toolbutton \
                                         -takefocus 0 -command [list $cmd] $args
        } else {
            eval ttk::button $widgetName -image $bmpImg -style Toolbutton \
                                         -takefocus 0 -command [list $cmd] $args
        }
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddCheckButton { w bmpImg cmd str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        if { ! [poImgMisc IsPhoto $bmpImg] } {
            eval ttk::checkbutton $widgetName -text [list $bmpImg] -style Toolbutton \
                                  -takefocus 0 -command [list $cmd] $args
        } else {
            eval ttk::checkbutton $widgetName -image $bmpImg -style Toolbutton \
                                  -takefocus 0 -command [list $cmd] $args
        }
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddRadioButton { w bmpImg cmd str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        if { ! [poImgMisc IsPhoto $bmpImg] } {
            eval ttk::radiobutton $widgetName -text [list $bmpImg] -style Toolbutton \
                                  -takefocus 0 -command [list $cmd] $args
        } else {
            eval ttk::radiobutton $widgetName -image $bmpImg -style Toolbutton \
                                  -takefocus 0 -command [list $cmd] $args
        }
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddEntry { w var str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        upvar $var ::txtvar_$widgetName

        eval ttk::entry $widgetName -takefocus 1 \
                        -textvariable ::txtvar_$widgetName $args
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddCombobox { w var str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        upvar $var ::combovar_$widgetName

        eval ttk::combobox $widgetName -textvariable ::combovar_$widgetName $args
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }

    proc AddSpinbox { w var str args } {
        variable sPo

        set widgetName [_GenWidgetName $w]

        upvar $var ::spinboxvar_$widgetName

        eval ttk::spinbox $widgetName -textvariable ::spinboxvar_$widgetName $args
        if { $str ne "" } {
            poToolhelp AddBinding $widgetName $str
        }
        pack $widgetName -side $sPo($w,side)
        return $widgetName
    }
}

poToolbar Init
