# Module:         poConsole
# Copyright:      Paul Obermeier 2001-2023 / paul@poSoft.de
# First Version:  2001 / 07 / 06
#
# Distributed under BSD license.
#
# Module for creating a portable console window.

namespace eval poConsole {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Create

    proc Create {w prompt title} {
        variable ns

        upvar #0 $w.t v
        if {[winfo exists $w]} {destroy $w}
        if {[info exists v]} {unset v}
        toplevel $w
        wm title $w $title
        wm iconname $w $title

        set mnu $w.mb
        menu $mnu -borderwidth 2 -relief sunken
        $mnu add cascade -menu $mnu.file -label File -underline 0
        $mnu add cascade -menu $mnu.edit -label Edit -underline 0

        set fileMenu $mnu.file
        set editMenu $mnu.edit

        menu $fileMenu -tearoff 0
        poMenu AddCommand $fileMenu "Save as ..." "" "${ns}::SaveFile $w.t"
        poMenu AddCommand $fileMenu "Close"       "" "destroy $w"
        poMenu AddCommand $fileMenu "Quit"        "" "exit"

        createChild $w $prompt $editMenu
        $w configure -menu $mnu
    }

    proc createChild {w prompt editmenu} {
        variable ns

        upvar #0 $w.t v
        if {$editmenu!=""} {
            menu $editmenu -tearoff 0

            poMenu AddCommand $editmenu "Cut"   "" "${ns}::Cut $w.t"
            poMenu AddCommand $editmenu "Copy"  "" "${ns}::Copy $w.t"
            poMenu AddCommand $editmenu "Paste" "" "${ns}::Paste $w.t"
            poMenu AddCommand $editmenu "Clear" "" "${ns}::Clear $w.t"
            $editmenu add separator
            poMenu AddCommand $editmenu "Source ..." "" "${ns}::SourceFile $w.t"
            catch {$editmenu config -postcommand "::poConsole::EnableEditMenu $w"}
        }
        scrollbar $w.sb -orient vertical -command "$w.t yview"
        pack $w.sb -side right -fill y
        text $w.t -font fixed -yscrollcommand "$w.sb set"
        pack $w.t -side right -fill both -expand 1
        bindtags $w.t Console
        set v(editmenu) $editmenu
        set v(text) $w.t
        set v(history) 0
        set v(historycnt) 0
        set v(current) -1
        set v(prompt) $prompt
        set v(prior) {}
        set v(plength) [string length $v(prompt)]
        set v(x) 0
        set v(y) 0
        $w.t mark set insert end
        $w.t tag config ok -foreground blue
        $w.t tag config err -foreground red
        $w.t insert end $v(prompt)
        $w.t mark set out 1.0
        catch {rename ::puts ::poConsole::oldputs$w}
        proc ::puts args [format {
            if {![winfo exists %s]} {
                rename ::puts {}
                rename ::poConsole::oldputs%s puts
                return [uplevel #0 puts $args]
            }
            switch -glob -- "[llength $args] $args" {
                {1 *} {
                    set msg [lindex $args 0]\n
                    set tag ok
                }
                {2 stdout *} {
                    set msg [lindex $args 1]\n
                    set tag ok
                }
                {2 stderr *} {
                    set msg [lindex $args 1]\n
                    set tag err
                }
                {2 -nonewline *} {
                    set msg [lindex $args 1]
                    set tag ok
                }
                {3 -nonewline stdout *} {
                    set msg [lindex $args 2]
                    set tag ok
                }
                {3 -nonewline stderr *} {
                    set msg [lindex $args 2]
                    set tag err
                }
                default {
                    uplevel #0 ::poConsole::oldputs%s $args
                    return
                }
            }
            ::poConsole::Puts %s $msg $tag
        } $w $w $w $w.t]
        after idle "focus $w.t"
    }

    bind Console <1> {::poConsole::Button1 %W %x %y}
    bind Console <B1-Motion> {::poConsole::B1Motion %W %x %y}
    bind Console <B1-Leave> {::poConsole::B1Leave %W %x %y}
    bind Console <B1-Enter> {::poConsole::cancelMotor %W}
    bind Console <ButtonRelease-1> {::poConsole::cancelMotor %W}
    bind Console <KeyPress> {::poConsole::Insert %W %A}
    bind Console <Left> {::poConsole::Left %W}
    bind Console <Control-b> {::poConsole::Left %W}
    bind Console <Right> {::poConsole::Right %W}
    bind Console <Control-f> {::poConsole::Right %W}
    bind Console <BackSpace> {::poConsole::Backspace %W}
    bind Console <Control-h> {::poConsole::Backspace %W}
    bind Console <Delete> {::poConsole::Delete %W}
    bind Console <Control-d> {::poConsole::Delete %W}
    bind Console <Home> {::poConsole::Home %W}
    bind Console <Control-a> {::poConsole::Home %W}
    bind Console <End> {::poConsole::End %W}
    bind Console <Control-e> {::poConsole::End %W}
    bind Console <Return> {::poConsole::Enter %W}
    bind Console <KP_Enter> {::poConsole::Enter %W}
    bind Console <Up> {::poConsole::Prior %W}
    bind Console <Control-p> {::poConsole::Prior %W}
    bind Console <Down> {::poConsole::Next %W}
    bind Console <Control-n> {::poConsole::Next %W}
    bind Console <Control-k> {::poConsole::EraseEOL %W}
    bind Console <<Cut>> {::poConsole::Cut %W}
    bind Console <<Copy>> {::poConsole::Copy %W}
    bind Console <<Paste>> {::poConsole::Paste %W}
    bind Console <<Clear>> {::poConsole::Clear %W}

    proc Puts {w t tag} {
        set nc [string length $t]
        set endc [string index $t [expr $nc-1]]
        if {$endc=="\n"} {
            if {[$w index out]<[$w index {insert linestart}]} {
                $w insert out [string range $t 0 [expr $nc-2]] $tag
                $w mark set out {out linestart +1 lines}
            } else {
                $w insert out $t $tag
            }
        } else {
            if {[$w index out]<[$w index {insert linestart}]} {
                $w insert out $t $tag
            } else {
                $w insert out $t\n $tag
                $w mark set out {out -1 char}
            }
        }
        $w yview insert
    }

    proc Insert {w a} {
        $w insert insert $a
        $w yview insert
    }

    proc Left {w} {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        if {$col>$v(plength)} {
            $w mark set insert "insert -1c"
        }
    }

    proc Backspace {w} {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        if {$col>$v(plength)} {
            $w delete {insert -1c}
        }
    }

    proc EraseEOL {w} {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        if {$col>=$v(plength)} {
            $w delete insert {insert lineend}
        }
    }

    proc Right {w} {
        $w mark set insert "insert +1c"
    }

    proc Delete w {
        $w delete insert
    }

    proc Home w {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        $w mark set insert $row.$v(plength)
    }

    proc End w {
        $w mark set insert {insert lineend}
    }

    proc Enter w {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        set start $row.$v(plength)
        set line [$w get $start "$start lineend"]
        if {$v(historycnt)>0} {
            set last [lindex $v(history) [expr $v(historycnt)-1]]
            if {[string compare $last $line]} {
                lappend v(history) $line
                incr v(historycnt)
            }
        } else {
            set v(history) [list $line]
            set v(historycnt) 1
        }
        set v(current) $v(historycnt)
        $w insert end \n
        $w mark set out end
        if {$v(prior)==""} {
            set cmd $line
        } else {
            set cmd $v(prior)\n$line
        }
        if {[info complete $cmd]} {
            set rc [catch {uplevel #0 $cmd} res]
            if {![winfo exists $w]} return
            if {$rc} {
                $w insert end $res\n err
            } elseif {[string length $res]>0} {
                $w insert end $res\n ok
            }
            set v(prior) {}
            $w insert end $v(prompt)
        } else {
            set v(prior) $cmd
            regsub -all -- {[^ ]} $v(prompt) . x
            $w insert end $x
        }
        $w mark set insert end
        $w mark set out {insert linestart}
        $w yview insert
    }

    proc Prior w {
        upvar #0 $w v
        if {$v(current)<=0} return
        incr v(current) -1
        set line [lindex $v(history) $v(current)]
        SetLine $w $line
    }

    proc Next w {
        upvar #0 $w v
        if {$v(current)>=$v(historycnt)} return
        incr v(current) 1
        set line [lindex $v(history) $v(current)]
        SetLine $w $line
    }

    proc SetLine {w line} {
        upvar #0 $w v
        scan [$w index insert] %d.%d row col
        set start $row.$v(plength)
        $w delete $start end
        $w insert end $line
        $w mark set insert end
        $w yview insert
    }

    proc Button1 {w x y} {
        global tkPriv
        upvar #0 $w v
        set v(mouseMoved) 0
        set v(pressX) $x
        set p [nearestBoundry $w $x $y]
        scan [$w index insert] %d.%d ix iy
        scan $p %d.%d px py
        if {$px==$ix} {
            $w mark set insert $p
        }
        $w mark set anchor $p
        focus $w
    }

    proc nearestBoundry {w x y} {
        set p [$w index @$x,$y]
        set bb [$w bbox $p]
        if {![string compare $bb ""]} {return $p}
        if {($x-[lindex $bb 0])<([lindex $bb 2]/2)} {return $p}
        $w index "$p + 1 char"
    }

    proc SelectTo {w x y} {
        upvar #0 $w v
        set cur [nearestBoundry $w $x $y]
        if {[catch {$w index anchor}]} {
            $w mark set anchor $cur
        }
        set anchor [$w index anchor]
        if {[$w compare $cur != $anchor] || (abs($v(pressX) - $x) >= 3)} {
            if {$v(mouseMoved)==0} {
                $w tag remove sel 0.0 end
            }
            set v(mouseMoved) 1
        }
        if {[$w compare $cur < anchor]} {
            set first $cur
            set last anchor
        } else {
            set first anchor
            set last $cur
        }
        if {$v(mouseMoved)} {
            $w tag remove sel 0.0 $first
            $w tag add sel $first $last
            $w tag remove sel $last end
            update idletasks
        }
    }

    proc B1Motion {w x y} {
        upvar #0 $w v
        set v(y) $y
        set v(x) $x
        SelectTo $w $x $y
    }

    proc B1Leave {w x y} {
        upvar #0 $w v
        set v(y) $y
        set v(x) $x
        motor $w
    }

    proc motor w {
        upvar #0 $w v
        if {![winfo exists $w]} return
        if {$v(y)>=[winfo height $w]} {
            $w yview scroll 1 units
        } elseif {$v(y)<0} {
            $w yview scroll -1 units
        } else {
            return
        }
        SelectTo $w $v(x) $v(y)
        set v(timer) [after 50 ::poConsole::motor $w]
    }

    proc cancelMotor w {
        upvar #0 $w v
        catch {after cancel $v(timer)}
        catch {unset v(timer)}
    }

    proc Copy w {
        if {![catch {set text [$w get sel.first sel.last]}]} {
            clipboard clear -displayof $w
            clipboard append -displayof $w $text
        }
    }

    proc canCut w {
        set r [catch {
            scan [$w index sel.first] %d.%d s1x s1y
            scan [$w index sel.last] %d.%d s2x s2y
            scan [$w index insert] %d.%d ix iy
        }]
        if {$r==1} {return 0}
        if {$s1x==$ix && $s2x==$ix} {return 1}
        return 2
    }

    proc Cut w {
        if {[::poConsole::canCut $w]==1} {
            ::poConsole::Copy $w
            $w delete sel.first sel.last
        }
    }

    proc Paste w {
        if {[::poConsole::canCut $w]==1} {
            $w delete sel.first sel.last
        }
        if {[catch {selection get -displayof $w -selection CLIPBOARD} topaste]} {
            return
        }
        set prior 0
        foreach line [split $topaste \n] {
            if {$prior} {
                Enter $w
                update
            }
            set prior 1
            $w insert insert $line
        }
    }

    proc EnableEditMenu w {
        upvar #0 $w.t v
        set m $v(editmenu)
        if {$m=="" || ![winfo exists $m]} return
        switch [::poConsole::canCut $w.t] {
            0 {
                $m entryconf Copy -state disabled
                $m entryconf Cut -state disabled
            }
            1 {
                $m entryconf Copy -state normal
                $m entryconf Cut -state normal
            }
            2 {
                $m entryconf Copy -state normal
                $m entryconf Cut -state disabled
            }
        }
    }

    proc SourceFile w {
        set fileTypes {
            {"Tcl Scripts" ".tcl"}
            {"All Files"   "*"}
        }
        set fileName [tk_getOpenFile -filetypes $fileTypes -title "Select Tcl script to source"]
        if { $fileName ne "" } {
            uplevel #0 source $fileName
        }
    }

    proc SaveFile { w } {
        variable ns
        variable sPo

        set fileTypes {
            {"Text Files" ".txt"}
            {"All Files"  "*"}
        }

        set initFile "Console.txt"

        if { ! [info exists sPo(LastConsoleType)] } {
            set sPo(LastConsoleType) [lindex [lindex $fileTypes 0] 0]
        }
        set fileExt [file extension $initFile]
        set typeExt [poMisc GetExtensionByType $fileTypes $sPo(LastConsoleType)]
        if { $typeExt ne $fileExt } {
            set initFile [file rootname $initFile]
        }

        set fileName [tk_getSaveFile \
                     -filetypes $fileTypes \
                     -title "Save console content as" \
                     -parent $w \
                     -confirmoverwrite false \
                     -typevariable ${ns}::sPo(LastConsoleType) \
                     -initialfile [file tail $initFile] \
                     -initialdir [pwd]]
        if { $fileName ne "" && ! [poMisc IsValidExtension $fileTypes [file extension $fileName]] } {
            set ext [poMisc GetExtensionByType $fileTypes $sPo(LastConsoleType)]
            if { $ext ne "*" } {
                append fileName $ext
            }
        }
        if { [file exists $fileName] } {
            set retVal [tk_messageBox \
                -message "File \"[file tail $fileName]\" already exists.\n\
                         Do you want to overwrite it?" \
                -title "Save confirmation" -type yesno -default no -icon info]
            if { $retVal eq "no" } {
                set fileName ""
            }
        }

        if { $fileName ne "" } {
            if {[catch {open $fileName w} fp]} {
                tk_messageBox -type ok -icon error -message $fp
            } else {
                puts $fp [string trimright [$w get 1.0 end] \n]
                close $fp
            }
        }
    }

    proc Clear w {
        $w delete 1.0 {insert linestart}
    }
}
