# Module:         poSoftLogo
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Module for displaying a poSoft and Tcl logo window.

namespace eval poSoftLogo {
    variable ns [namespace current]

    namespace ensemble create

    namespace export ShowLogo DestroyLogo
    namespace export ShowTclLogo DestroyTclLogo

    proc ShrinkWindow { tw dir } {
        set width  [winfo width $tw]
        set height [winfo height $tw]
        set x      [winfo x $tw]
        set y      [winfo y $tw]
        set inc -1

        if { $dir eq "x" } {
            for { set w $width } { $w >= 20 } { incr w $inc } {
                if { [winfo exists $tw] } {
                    wm geometry $tw [format "%dx%d+%d+%d" $w $height $x $y]
                    update idletasks
                }
                incr inc -1
            }
        } else {
            for { set h $height } { $h >= 20 } { incr h $inc } {
                if { [winfo exists $tw] } {
                    wm geometry $tw [format "%dx%d+%d+%d" $width $h $x $y]
                    update idletasks
                }
                incr inc -1
            }
        }
    }

    proc DestroyLogo {} {
        variable wackel
        variable logoWinId
        variable withdrawnWinId

        if { [info exists logoWinId] && [winfo exists $logoWinId] } {
            ShrinkWindow $logoWinId x
            set wackel(onoff) 0
            catch {image delete $wackel(0)}
            catch {image delete $wackel(1)}
            destroy $logoWinId
            if { [winfo exists $withdrawnWinId] } {
                wm deiconify $withdrawnWinId
            }
        }
    }

    proc ShowLogo { version buildInfo copyright {withdrawWin ""} } {
        variable ns
        variable wackel
        variable logoWinId
        variable withdrawnWinId

        set t ".poShowLogo"
        set logoWinId $t
        set withdrawnWinId $withdrawWin
        if { [winfo exists $t] } {
            poWin Raise $t
            return
        }

        set wackel(0) [::poImgData::poLogo]
        set wackel(1) [poPhotoUtil FlipHorizontal $wackel(0)]
        set wackel(onoff)  0
        set wackel(curImg) 0
        set wackel(wackelSpeed) 500

        toplevel $t
        ttk::frame $t.f
        pack $t.f
        wm resizable $t false false
        if { $withdrawWin eq "" } {
            wm title $t "poSoft Information"
        } else {
            if { $withdrawWin ne "." } {
                wm withdraw .
            }
            if { [winfo exists $withdrawWin] } {
                wm withdraw $withdrawWin
                set withdrawnWinId $withdrawWin
            }
            wm overrideredirect $t 1
            set xmax [winfo screenwidth $t]
            set ymax [winfo screenheight $t]
            set x0 [expr {($xmax - [image width  $wackel(0)])/2}]
            set y0 [expr {($ymax - [image height $wackel(0)])/2}]
            wm geometry $t "+$x0+$y0"
            $t.f configure -borderwidth 10
            raise $t
            update idletasks
        }

        ttk::label $t.f.l1 -anchor center -text "Paul Obermeier's Portable Software"
        pack $t.f.l1 -fill x
        ttk::button $t.f.b -image $wackel(0)
        set url "http://www.poSoft.de/"
        poToolhelp AddBinding $t.f.b $url
        bind $t.f.b <Motion>         "${ns}::SetWackelDelay %x %y"
        bind $t.f.b <Shift-Button-3> "${ns}::StartWackel $t.f.b"
        bind $t.f.b <Button-3>       "${ns}::SwitchLogo $t.f.b"
        bind $t.f.b <Button-1>       "poExtProg OpenUrl $url"
        pack $t.f.b
        ttk::label $t.f.l3 -anchor center -text $version
        pack $t.f.l3 -fill x
        ttk::label $t.f.l4 -anchor center -text $buildInfo
        pack $t.f.l4 -fill x
        ttk::label $t.f.l5 -anchor center -text $copyright
        pack $t.f.l5 -fill x
        if { $withdrawWin eq "" } {
            bind $t <KeyPress-Escape> "${ns}::DestroyLogo"
            bind $t <KeyPress-Return> "${ns}::DestroyLogo"
            wm protocol $t WM_DELETE_WINDOW "${ns}::DestroyLogo"
            focus $t
            update idletasks
        } else {
            focus $t
            update idletasks
            after 500
            SwitchLogo $t.f.b
            update idletasks
            after 300
        }
    }

    proc SetWackelDelay { mouseX mouseY } {
        variable wackel

        set wackel(wackelSpeed) [expr $mouseX + $mouseY]
    }

    proc SwitchLogo { b } {
        variable wackel

        if { $wackel(onoff) == 1 } {
            set wackel(onoff) 0
        }
        set wackel(curImg) [expr 1 - $wackel(curImg)]
        $b configure -image $wackel($wackel(curImg))
    }

    proc StartWackel { b } {
        variable wackel

        if { $wackel(onoff) == 0 } {
            set wackel(onoff) 1
            Wackel $b
        } else {
            StopWackel $b
        }
    }

    proc StopWackel { b } {
        variable ns
        variable wackel

        set wackel(onoff)  0
        set wackel(curImg) 1
        after $wackel(wackelSpeed) "${ns}::Wackel $b"
    }

    proc Wackel { b } {
        variable ns
        variable wackel

        if { $wackel(onoff) == 1 } {
            set wackel(curImg) [expr 1 - $wackel(curImg)]
            $b configure -image $wackel($wackel(curImg))
            update idletasks
            after $wackel(wackelSpeed) "${ns}::Wackel $b"
        }
    }

    proc Str { key args } {
        variable msgStr

        set str $msgStr($key)
        return [eval {format $str} $args]
    }

    proc DestroyTclLogo { w img } {
        ShrinkWindow $w y
        image delete $img
        destroy $w
    }

    proc ShowTclLogo { args } {
        variable ns
        variable msgStr
        variable url

        set t ".poShowTclLogo"
        if { [winfo exists $t] } {
            poWin Raise $t
            return
        }

        array set msgStr [list \
            WithHelp "With a little help from my Tcl friends ..." \
            Thanks   "Thanks to %s" \
        ]

        toplevel $t
        wm title $t "Tcl/Tk Information"
        wm resizable $t false false

        ttk::frame $t.fr
        pack $t.fr -fill both -expand 1

        set ph [::poImgData::pwrdLogo200]
        ttk::label $t.fr.img -image $ph
        pack $t.fr.img
        ttk::label $t.fr.l1 -anchor w -text [Str WithHelp]
        pack $t.fr.l1

        set row 0
        ttk::frame $t.f
        pack $t.f -fill both -expand 1
        foreach extension $args {
            set retVal [catch {package present $extension} versionStr]
            if { $retVal != 0 } {
                set versionStr "(not loaded)"
            }
            switch -exact -- $extension {
                Tk             {  set progName "Tcl/Tk [info patchlevel]"
                                  set url      "http://www.tcl-lang.org/"
                                  set author   "All Tcl/Tk core developers"
                                }
                Img             { set progName "Img $versionStr"
                                  set url      "http://sourceforge.net/projects/tkImg/"
                                  set author   "Jan Nijtmans, Andreas Kupries"
                                }
                scrollutil -
                scrollutil_tile { set progName "scrollutil $versionStr"
                                  set url      "http://www.nemethi.de/scrollutil/"
                                  set author   "Csaba Nemethi"
                                }
                Tktable         { set progName "Tktable $versionStr"
                                  set url      "http://sourceforge.net/projects/tktable/"
                                  set author   "Jeffrey Hobbs"
                                }
                tkdnd           { set progName "tkdnd $versionStr"
                                  set url      "https://github.com/petasis/tkdnd/"
                                  set author   "Georgios Petasis"
                                }
                tksvg           { set progName "tksvg $versionStr"
                                  set url      "https://github.com/auriocus/tksvg/"
                                  set author   "Christian Gollwitzer"
                                }
                twapi           { set progName "twapi $versionStr"
                                  set url      "http://twapi.magicsplat.com/"
                                  set author   "Ashok P. Nadkarni"
                                }
                tablelist -
                tablelist_tile  { set progName "tablelist $versionStr"
                                  set url      "http://www.nemethi.de/tablelist/"
                                  set author   "Csaba Nemethi"
                                }
            }
            ttk::button $t.f.lext$row -text $progName -command [list poExtProg::OpenUrl $url]
            ttk::label  $t.f.rext$row -text $author
            poToolhelp AddBinding $t.f.lext$row $url
            grid $t.f.lext$row -row $row -column 0 -sticky ew
            grid $t.f.rext$row -row $row -column 1 -sticky ew
            incr row
        }
        bind $t <KeyPress-Escape> "${ns}::DestroyTclLogo $t $ph"
        bind $t <KeyPress-Return> "${ns}::DestroyTclLogo $t $ph"
        focus $t
    }
}
