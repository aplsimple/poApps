# Module:         poDragAndDrop
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 01 / 29
#
# Distributed under BSD license.
#
# Module for using the tkdnd extension.

namespace eval poDragAndDrop {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export AddCanvasBinding
    namespace export AddTtkBinding

    proc Init {} {
        variable sHaveTkDnd

        set retVal [catch {package require tkdnd} version]
        set sHaveTkDnd [expr ! $retVal]
    }

    proc _SetCanvasState { w onOff } {
        if { [winfo class $w] eq "Tablelist" } {
            return
        }
        if { $onOff } {
            $w configure -highlightcolor yellow -highlightthickness 4
        } else {
            $w configure -highlightcolor red -highlightthickness 0
        }
    }

    proc _DropCanvasCmd { w dropContent callback action } {
        variable ns

        # puts "$action Dropped files: \"[join $dropContent {, }]\""
        ${ns}::_SetCanvasState $w false
        $callback $w $dropContent
        return $action
    }

    proc _DropTtkCmd { w dropContent callback action } {
        variable ns

        # puts "$action Dropped files: \"[join $dropContent {, }]\""
        $w state !active
        $callback $w $dropContent
        return $action
    }

    proc AddCanvasBinding { w callback } {
        variable ns
        variable sHaveTkDnd

        if { $sHaveTkDnd } {
            tkdnd::drop_target register $w DND_Files

            bind $w <<DropEnter>> "${ns}::_SetCanvasState $w true"
            bind $w <<DropLeave>> "${ns}::_SetCanvasState $w false"

            bind $w <<Drop:DND_Files>> "${ns}::_DropCanvasCmd %W %D $callback %A" 
        }
    }

    proc AddTtkBinding { w callback } {
        variable ns
        variable sHaveTkDnd

        if { $sHaveTkDnd } {
            tkdnd::drop_target register $w DND_Files

            bind $w <<DropEnter>> { %W state  active }
            bind $w <<DropLeave>> { %W state !active }

            bind $w <<Drop:DND_Files>> "${ns}::_DropTtkCmd %W %D $callback %A" 
        }
    }
}

poDragAndDrop Init
