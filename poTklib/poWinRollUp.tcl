# Module:         poWinRollUp
# Copyright:      Paul Obermeier 2015-2020 / paul@poSoft.de
# First Version:  2015 / 05 / 29
#
# Distributed under BSD license.

namespace eval poWinRollUp {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init

    namespace export Create
    namespace export Add Remove
    namespace export SetTitle
    namespace export Enable
    namespace export IsOpen Open
    namespace export IsToplevel
    namespace export SetActive
    namespace export IsElement EnableElement

    proc Init {} {
        variable sPo

        set sPo(curRollUpId) 0

        set sPo(closedBitmap) [poBmpData rollupclosed]
        set sPo(openedBitmap) [poBmpData rollupopened]
        set sPo(toplevelOn)   [poBmpData slideShowMarked]
        set sPo(toplevelOff)  [poBmpData slideShowAll]
    }

    proc _GenWidgetName { rollUpWidget row { col 0 } } {
        return [format "%s.w%d_%d" $rollUpWidget $row $col]
    }

    proc _SwitchGridRow { contentWidget row onOff } {
        variable sPo

        if { $onOff } {
            if { [info exists sPo(isToplevel,$contentWidget)] && \
                 ! $sPo(isToplevel,$contentWidget) } {
                grid $contentWidget -row $row -column 0 -columnspan 2 -sticky news
            }
        } else {
            grid forget $contentWidget
        }
    }

    proc _ToggleToplevel { rollUpWidget buttonRow contentRow } {
        variable ns
        variable sPo

        set stickyWidget  [_GenWidgetName $rollUpWidget $buttonRow 0]
        set buttonWidget  [_GenWidgetName $rollUpWidget $buttonRow 1]
        set contentWidget [_GenWidgetName $rollUpWidget $contentRow]
        # Store current setting of isToplevel flag in local variable and
        # change state immediately. Otherwise triggered events calling
        # IsOpen or IsToplevel will get incorrect results. 
        set isToplevel $sPo(isToplevel,$contentWidget)
        set sPo(isToplevel,$contentWidget) [expr ! $sPo(isToplevel,$contentWidget)]
        if { $isToplevel } {
            scan [wm geometry $contentWidget] "%dx%d+%d+%d" w h x y
            set sPo($contentWidget,x) $x
            set sPo($contentWidget,y) $y
            wm forget $contentWidget
            $stickyWidget configure -image $sPo(toplevelOn)
            if { $sPo(isOpen,$contentWidget) } {
                _SwitchGridRow $contentWidget $contentRow true
            } else {
                event generate $contentWidget <<RollUpClosed>>
            }
            event generate $contentWidget <<RollUpFromToplevel>>
        } else {
            if { ! [info exists sPo($contentWidget,x)] } {
                lassign [winfo pointerxy $contentWidget] x y
                set sPo($contentWidget,x) [expr $x + 20]
                set sPo($contentWidget,y) [expr $y - 20]
            }
            wm manage $contentWidget
            wm title $contentWidget [$buttonWidget cget -text]
            wm geometry $contentWidget [format "+%d+%d" $sPo($contentWidget,x) $sPo($contentWidget,y)]
            wm protocol $contentWidget WM_DELETE_WINDOW "${ns}::_ToggleToplevel $rollUpWidget $buttonRow $contentRow"
            $stickyWidget configure -image $sPo(toplevelOff)
            if { ! $sPo(isOpen,$contentWidget) } {
                event generate $contentWidget <<RollUpOpened>>
            }
            event generate $contentWidget <<RollUpToToplevel>>
        }
    }

    proc _ToggleRollUp { rollUpWidget buttonRow interactive } {
        variable ns
        variable sPo

        set contentRow [expr {$buttonRow + 1}]
        set buttonWidget  [_GenWidgetName $rollUpWidget $buttonRow 1]
        set contentWidget [_GenWidgetName $rollUpWidget $contentRow]

        if { $sPo(isOpen,$contentWidget) } {
            _SwitchGridRow $contentWidget $contentRow false
            $buttonWidget configure -image $sPo(closedBitmap)
        } else {
            _SwitchGridRow $contentWidget $contentRow true
            $buttonWidget configure -image $sPo(openedBitmap)
        }
        set sPo(isOpen,$contentWidget) [expr ! $sPo(isOpen,$contentWidget)]

        if { $interactive } {
            SetActive $contentWidget
            if { $sPo(isOpen,$contentWidget) } {
                event generate $contentWidget <<RollUpOpened>>
            } else {
                event generate $contentWidget <<RollUpClosed>>
            }
        }
    }

    proc SetActive { w } {
        variable sPo

        set parent    [lindex $sPo(parentWidget,$w) 0]
        set buttonRow [lindex $sPo(parentWidget,$w) 1]

        if { [info exists sPo(lastClicked,widget)] &&  [winfo exists $sPo(lastClicked,widget)] } {
            $sPo(lastClicked,widget) configure -bg $sPo($sPo(lastClicked,rollup),bg)
        }
        set buttonWidget [_GenWidgetName $parent $buttonRow 1]
        set sPo(lastClicked,widget) $buttonWidget
        set sPo(lastClicked,rollup) $parent
        $sPo(lastClicked,widget) configure -bg "lightgreen"
    }

    proc Open { w { open true } } {
        variable sPo

        set parent    [lindex $sPo(parentWidget,$w) 0]
        set buttonRow [lindex $sPo(parentWidget,$w) 1]
        set sPo(isOpen,$w) [expr ! $open]
        _ToggleRollUp $parent $buttonRow false
    }

    proc IsOpen { w } {
        variable sPo

        return [expr { $sPo(isOpen,$w) || $sPo(isToplevel,$w) }]
    }

    proc IsToplevel { w } {
        variable sPo

        return [expr { $sPo(isToplevel,$w) }]
    }

    proc IsElement { w } {
        variable sPo

        return [info exists sPo(buttonWidget,$w)]
    }

    proc Enable { rollUpWidget onOff } {
        variable ns
        variable sPo

        foreach contentWidget $sPo($rollUpWidget,elems) {
            EnableElement $contentWidget $onOff
        }
    }

    proc EnableElement { w onOff } {
        variable ns
        variable sPo

        if { [info exists sPo(buttonWidget,$w)] } {
            if { $onOff } {
                $sPo(buttonWidget,$w) configure -state normal
                $sPo(stickyWidget,$w) configure -state normal
            } else {
                $sPo(buttonWidget,$w) configure -state disabled
                $sPo(stickyWidget,$w) configure -state disabled
            }
        }
    }

    proc Create { masterFr { title "" } { bg lightgrey } } {
        variable ns
        variable sPo

        set rollUpWidget $masterFr.rollUpWidget_$sPo(curRollUpId)
        set sPo($rollUpWidget,curRow) 0
        set sPo($rollUpWidget,bg) $bg
        incr sPo(curRollUpId)

        if { $title ne "" } {
            ttk::labelframe $rollUpWidget -text $title
        } else {
            ttk::frame $rollUpWidget
        }
	set sPo(FrameBackground) [ttk::style lookup TFrame -background]

        pack $rollUpWidget -side top -fill x
        grid columnconfigure $rollUpWidget 1 -weight 1
        return $rollUpWidget
    }

    proc Add { rollUpWidget title { isOpen false } } {
        variable ns
        variable sPo

        set buttonRow  $sPo($rollUpWidget,curRow)
        set contentRow [expr {$buttonRow + 1}]

        set stickyWidget [_GenWidgetName $rollUpWidget $buttonRow 0]
        button $stickyWidget -relief flat -bg $sPo($rollUpWidget,bg) -anchor w \
                  -image $sPo(toplevelOn) \
                  -command "${ns}::_ToggleToplevel $rollUpWidget $buttonRow $contentRow"
        set buttonWidget [_GenWidgetName $rollUpWidget $buttonRow 1]
        button $buttonWidget -text $title -relief flat -bg $sPo($rollUpWidget,bg) -anchor w \
                  -image $sPo(openedBitmap) -compound left \
                  -command "${ns}::_ToggleRollUp $rollUpWidget $buttonRow true"
        grid $stickyWidget -row $buttonRow -column 0 -sticky news
        grid $buttonWidget -row $buttonRow -column 1 -sticky news

        set contentWidget [_GenWidgetName $rollUpWidget $contentRow]

        # This must be a frame and not a ttk::frame, because it must be manageable by the
        # window manager to become a toplevel window.
        # To look good (under Linux) we determined the background color of a ttk::frame in the
        # Create procedure and set this color for the frame.
        frame $contentWidget -relief ridge -borderwidth 2 -bg $sPo(FrameBackground)
        _SwitchGridRow $contentWidget $contentRow true

        set sPo(isToplevel,$contentWidget) 0
        set sPo(isOpen,$contentWidget) [expr ! $isOpen]
        set sPo(parentWidget,$contentWidget) [list $rollUpWidget $buttonRow]
        set sPo(buttonWidget,$contentWidget) $buttonWidget
        set sPo(stickyWidget,$contentWidget) $stickyWidget
        lappend sPo($rollUpWidget,elems) $contentWidget
        _ToggleRollUp $rollUpWidget $buttonRow false

        incr sPo($rollUpWidget,curRow) 2
        return $contentWidget
    }

    proc SetTitle { contentWidget title } {
        variable sPo

        if { [info exists sPo(buttonWidget,$contentWidget)] } {
            $sPo(buttonWidget,$contentWidget) configure -text $title
        }
    }

    proc Remove { contentWidget } {
        variable sPo

        if { [info exists sPo(buttonWidget,$contentWidget)] } {
            destroy $sPo(buttonWidget,$contentWidget)
            destroy $sPo(stickyWidget,$contentWidget)
            unset sPo(buttonWidget,$contentWidget)
            unset sPo(stickyWidget,$contentWidget)
            destroy $contentWidget
        }
    }
}

poWinRollUp Init
