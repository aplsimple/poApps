#!/bin/sh
#-*-tcl-*-
# the next line restarts using wish \
exec wish "$0" -- ${1+"$@"}

###############################################################################
#
# TkDiff -- A graphical front-end to diff for Unix and Windows.
# Copyright (C) 1994-1998 by John M. Klassa.
# Copyright (C) 1999-2001 by AccuRev Inc.
# Copyright (C) 2002-2005 by John M. Klassa.
#
# TkDiff Home Page: http://tkdiff.sourceforge.net
#
# Usage:  see "tkdiff -h" or "tkdiff --help"
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.        See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
###############################################################################

# Chgd from 8.0 to 8.5 as of V4.3 to ensure support of "Text displaylines"
package require Tk 8.5

# Change to t for trace info on stderr
set g(debug) f

# get this out of the way -- we want to draw the whole user interface
# behind the scenes, then pop up in all of its well-laid-out glory
set screenWidth [winfo vrootwidth .]
set screenHeight [winfo vrootheight .]
wm withdraw .
# OPA >>>
set w(tw) .tkdiff
toplevel $w(tw)
# OPA <<<


# set a couple o' globals that we might need sooner than later
set g(name) "TkDiff"
set g(version) "4.3.5"

# Startup phases:
#   0  : Bare metal, looking for viable cmd args
#   1  : Transitioning to GUI mode and/or major datastruct upheavals
#   2  : Operational mode
set g(startPhase) 0

# FIXME - move to preferences
option add "*TearOff" false 100
option add "*BorderWidth" 1 100
option add "*ToolTip.background" LightGoldenrod1
option add "*ToolTip.foreground" black

# determine the windowing platform, since there are different ways to
# do this for different versions of tcl
if {[catch {tk windowingsystem} g(windowingSystem)]} {
    if {"$::tcl_platform(platform)" == "windows"} {
        set g(windowingSystem) "win32"
    } elseif {"$::tcl_platform(platform)" == "unix"} {
        set g(windowingSystem) "x11"
    } elseif {"$::tcl_platform(platform)" == "macintosh"} {
        set g(windowingSystem) "classic"
    } else {
        # this should never happen, but just to be sure...
        set g(windowingSystem) "x11"
    }
}

# determine the name of the temporary directory and the name of
# the rc file, both of which are dependent on the platform.
# This is overridden by the preference in .tkdiffrc except for the very first
# time you run
switch -- $::tcl_platform(platform) {
windows {
        if {[info exists ::env(TEMP)]} {
            set opts(tmpdir) [file nativename $::env(TEMP)]
        } else {
            set opts(tmpdir) C:/temp
        }
        set basercfile "_tkdiff.rc"
        # Native look for toolbar
        set opts(fancyButtons) 1
        set opts(relief) flat
    }
default {
        if {[info exists ::env(TMPDIR)] && $g(windowingSystem) != "aqua"} {
            # MacOS X sets TMPDIR to something like /var/folders/uC/uCFr1z6qESSEYkTuOsevX++++yw/-Tmp-/
            # don't let it do that
            set opts(tmpdir) $::env(TMPDIR)
        } else {
            set opts(tmpdir) /tmp
        }
        set basercfile ".tkdiffrc"
        # Native look for toolbar
        set opts(fancyButtons) 0
        set opts(relief) raised
    }
}

# compute preferences file location. Note that TKDIFFRC can hold either
# a directory or a file, though we document it as being a file name
if {[info exists ::env(TKDIFFRC)]} {
    set rcfile $::env(TKDIFFRC)
    if {[file isdirectory $rcfile]} {
        set rcfile [file join $rcfile $basercfile]
    }
} elseif {[info exists ::env(HOME)]} {
    set rcfile [file join $::env(HOME) $basercfile]
} else {
    set rcfile [file join "/" $basercfile]
}

# Where should we start?  MacOSX apps want to start in / which is obnoxious
if {[pwd] == "/"} {
    if {[info exists ::env(HOME)]} {
       catch {cd $::env(HOME)}
    }
}

# Try to find a pleasing native look for each platform.
# Fonts.
set sysfont [font actual system]
#debug-info "system font: $sysfont"

# See what the native menu font is
. configure -menu .native
menu .native
set menufont [lindex [.native configure -font] 3]
destroy .native

# Find out what the tk default is
label .testlbl -text "LABEL"
set w(background) [lindex [.testlbl cget -background] 0]
set w(foreground) [lindex [.testlbl cget -foreground] 0]
set labelfont [lindex [.testlbl configure -font] 3]
destroy .testlbl

text .testtext
set textfont [lindex [.testtext configure -font] 3]
destroy .testtext

entry .testent
set w(selcolor) [lindex [.testent configure -selectbackground] 4]
set entryfont [lindex [.testent configure -font] 3]
destroy .testent

#debug-info "menufont $menufont"
#debug-info "labelfont $labelfont"
#debug-info "textfont $textfont"
#debug-info "entryfont $entryfont"

set fs [lindex $textfont 1]
if {$fs == ""} {
  # This happens on Windows in tk8.5
  # You get {TkDefaultFont} instead of {fixed 12} or whatever
  # Then when you add "bold" to it you have a bad spec
  set fa [font actual $textfont]
  #puts " actual font: $fa"
  set fm [lindex $fa 1]
  set fs [lindex $fa 3]
  set textfont [list $fm $fs]
}
set font [list $textfont]
set bold [list [concat $textfont bold]]
#debug-info "font: $font"
#debug-info "bold: $bold\n"
option add *Label.font $labelfont userDefault
option add *Button.font $labelfont userDefault
option add *Menu.font $menufont userDefault
option add *Entry.font $entryfont userDefault

# This makes tk_messageBox use our font.  The default tends to be terrible
# no matter what platform
option add *Dialog.msg.font $labelfont userDefault

# Initialize arrays
#######################
# On-demand Asynchronous machinery
#    (existance of element 'trigger' activates it)
array set ASYNc {
    out             ""
    events          0
}

# general globals
# OPA >>> Added havePlainFiles
array set g {
    conflictset     0
    destroy         ""
    ignore_hevent,1 0
    ignore_hevent,2 0
    initOK          0
    is3way          0
    lnumDigits      4
    mapborder       0
    mapheight       0
    mapScrolling    0
    mergefile       ""
    mergefileset    0
    returnValue     0
    showmerge       0
    statusCurrent   "Standby...."
    statusInfo      ""
    tempfiles       ""
    thumbMinHeight  10
    thumbHeight     10
    thumbDeltaY     0
    havePlainFiles  0
}

# Be advised (regarding the following global array definition):
#   Only those elements that are gauranteed to exist are initialized here.
#
#   The remainder of the FINFO entries are dynamically added and (occasionally
#   removed) as the user interacts with the tool. There are 2 categories of
#   information:
#       1. entries that describe INPUT parameters:
#           f,*       filespec that describe files/dirs/URLs to be acted upon
#           rev,*     revision value (for a to-be-detected SCM system)
#           ulbl,*    user-label: when provided, overrides "lbl" (see below)
#
#       2. entries ACTUALLY used AFTER input has been processed
#           pth,*     the actual local (possibly temp) file to compare
#           tmp,*     optional flag denotes "pth" AS a tempfile (& other uses)
#           lbl,*     displayable label for "pth"
#           pproc,*   special post processing needed for "pth" (rare)
#
#       In each above case, '*' is a monotonic number beginning at 1. Zero
#       is a special case used exclusively for an "Ancestor File" entry.
#       The SAME value, WITHIN its category, describes attributes of a SINGLE
#       object --- However "ulbl" is an exception - its number is USED by
#       category 2, despite being SET by category 1 (reasons are mostly
#       historical, dating from a time when the only values WERE 1 & 2);
#       "ulbl" is NOT expected to see usage beyond that still valid case,
#       although it is NOT specifically prohibitted.
#
#   Items in category 1 represent data ENTERRED by the user; as such they
#   are tied somewhat to the GUI (thereby initialized here), and are
#   (mostly) fixed at being at MOST two each (except MAYBE ulbl).
#
#   Items in category 2 (NOT set here) are grouped as adjacently numbered
#   PAIRS, and are files intended, actually, or previously been compared,
#   DERIVED from the items of category 1.
#
#   "fCurpair" designates which monotonic PAIR is actively in use (1->fPairs)
#   with "fPairs" itself being the COUNT of how many "fCurpair"s exist.
#
#   Thus "f,1" DIRECTLY implying "pth,1" is true ONLY if "f,1" designates a
#   single file. Likewise for "f,2" -> "pth,2". Input fields designating
#   directories and/or SCM branches (or commits) can generate SEVERAL "pth,N"
#   (and other category 2) entries, each.
#
#   The "lbl,Left" and "lbl,Right" and "title" entries are simply the DISPLAYED
#   label values (set from whatever the ACTIVE pair of "lbl,*" entries are),
#   and are tied directly to the GUI, (providing a cheap update mechanism).
#
#   IMPORTANT:
#   Certain COMBINATIONS of category 2 entries (existance, emptiness) are used
#   to describe various situations (i.e. tmp files, real files, pairs needing
#   comparison but NOT yet fully extracted from a necessary SCM repository;
#   or files NOT editable because they were extracted by an SCM).
#     EXERCISE CARE Re: ADDING/RENAMING of NEW elements...
#         Category 2 values are essentially considered TRANSIENT and MAY BE
#         DELETED or reset at times using patterns such as '[ptl]*[0-9]'.
#
#   Be VERY CAUTIOUS when considering CHANGING ANY of these manipulations!
array set finfo {
    title        {}
    fPairs       0
    fCurpair     1
    lbl,Left     "label_of_file_1"
    lbl,Right    "label_of_file_2"

    f,0          ""
    rev,0        ""

    f,1          ""
    ulbl,1       ""
    rev,1        ""

    f,2          ""
    ulbl,2       ""
    rev,2        ""
}
set uniq 0

# These options are generally changed at runtime
# OPA >>> Added showcontextsave
array set opts {
    autocenter        1
    autoselect        0
    colorcbs          0
    customCode        {}
    diffcmd           "diff"
    ignoreblanksopt   "-b"
    ignoreblanks      0
    ignoreEmptyLn     0
    ignoreRegexLnopt  ""
    ignoreRegexLn     0
    editor            ""
    filetypes         {{{All Files} *} {{Text Files} .txt} {{TclFiles} .tcl}}
    geometry          "80x30"
    predomMrg         1
    showcbs           1
    showln            1
    showmap           1
    showlineview      0
    showinline1       0
    showinline2       1
    showcontextsave   1
    syncscroll        1
    toolbarIcons      1
    tagcbs            0
    tagln             0
    tagtext           1
    tabstops          8
}

# reporting options
array set report {
    doSideLeft                0
    doLineNumbersLeft         1
    doChangeMarkersLeft       1
    doTextLeft                "Full Text"
    doSideRight               1
    doLineNumbersRight        1
    doChangeMarkersRight      1
    doTextRight               "Full Text"
    filename                  "tkdiff.out"
}

if {[string first "color" [winfo visual $w(tw)]] >= 0} {
    # We have color
    # (but, let's not go crazy...)

    # Use these BRIEFLY to outline what colors go where ...
    set colordel Tomato
    set colorins PaleGreen
    set colorchg DodgerBlue
    set colorolp yellow

    array set opts [subst {
        textopt    "-background white -foreground black -font $font"
        currtag    "-background Khaki"
        difftag    "-background gray"
        deltag     "-background $colordel -font $bold"
        instag     "-background $colorins -font $bold"
        chgtag     "-background LightSteelBlue"
        overlaptag "-background $colorolp"
        bytetag    "-background blue -foreground white"
        inlinetag  "-background $colorchg -font $bold"
        mapins     "$colorins"
        mapdel     "$colordel"
        mapchg     "$colorchg"
        mapolp     "$colorolp"
        adjcdr     "magenta"
    }]
    unset colordel colorins colorchg colorolp ;# ... BRIEFLY is now over!

} else {
    # Assume only black and white (may not work too well, sorry).
    set bg "black"
    array set opts [subst {
        textopt    "-background white -foreground black -font $font"
        currtag    "-background black -foreground white"
        difftag    "-background white -foreground black -font $bold"
        deltag     "-background black -foreground white"
        instag     "-background black -foreground white"
        chgtag     "-background black -foreground white"
        overlaptag "-background black -foreground white"
        bytetag    "-underline 1"
        inlinetag  "-underline 1"
        mapins     "black"
        mapdel     "black"
        mapchg     "black"
        mapolp     "black"
        adjcdr     "white"
    }]
}

# make sure wrapping is turned off. This might piss off a few people,
# but it would screw up the display to have things wrap
set opts(textopt) "$opts(textopt) -wrap none"

# OPA >>>
proc tkdiff-CloseAppWindow {} {
    global w
    global g

    if { ! [info exists w(tw)] && ! [winfo exists $w(tw)] } {
        return
    }

    # we don't particularly care if del-tmp fails.
    catch {del-tmp}

    destroy $w(tw)
    set g(mergefileset) 0
    set g(showmerge) 0
    set g(mergefile) ""

    # Show the main app window, which might be iconified.
    poApps StartApp deiconify
}

proc IsReadableFile { name } {
    set retVal [catch { open $name "r" } fp]
    if { $retVal == 0 } {
        close $fp
        return true
    }
    return false
}

proc AddEvents {} {
    event add <<LeftButtonPress>> <ButtonPress-1>
    if { $::tcl_platform(os) eq "Darwin" } {
        event add <<MiddleButtonPress>> <ButtonPress-3>
        event add <<RightButtonPress>>  <ButtonPress-2>
        event add <<RightButtonPress>>  <Control-ButtonPress-1>
    } else {
        event add <<MiddleButtonPress>> <ButtonPress-2>
        event add <<RightButtonPress>>  <ButtonPress-3>
    }
}

AddEvents
# OPA <<<

# This proc is used in the rc file
proc define {name value} {
    global opts
    set opts($name) $value
}

# Source the rc file, which may override some of the defaults
# Any errors will be reported. Before doing so, we need to define the
# "define" proc, which lets the rc file have a slightly more human-friendly
# interface. Old-style .rc files should still load just fine for now, though
# it ought to be noted new .rc files won't be able to be processed by older
# versions of TkDiff. That shouldn't be a problem.
if {[file exists $rcfile]} {
    if {[catch {source $rcfile} error]} {
        set startupError [join [list "There was an error in processing your\
          startup file." "\n$g(name) will still run, but some of your\
          preferences" "\nmay not be in effect." "\n\nFile: $rcfile" \
          "\nError: $error"] " "]
    }
}

# a hack to handle older preferences files...
# if the user has a diffopt defined in their rc file, we'll magically
# convert that to diffcmd...
if {[info exists opts(diffopt)]} {
    set opts(diffcmd) "diff $opts(diffopt)"
}

# Work-around for bad font approximations,
# as suggested by Don Libes (libes@nist.gov).
catch {tk scaling [expr {100.0 / 72}]}

###############################################################################
#
# HERE BEGIN THE PROCS
###############################################################################


###############################################################################
# Exit with proper code
###############################################################################
proc do-exit {{returncode {}}} {
    global g w ASYNc
    debug-info "do-exit ($returncode)"

    # During pgm startup, we MAY have built the status window just to let the
    # user know we are talking to a SCM server that MIGHT experience network
    # latency - so if that window exists (but OTHER windows do not) and we are
    # here, something died and we want to RELEASE that window before we leave.
    if {[info exists w(status)] && ![info exists w(client)]} {
        debug-info "something died (or was killed) ... trying to shutdown"
        catch {wm forget $w(status)}
        # Release any extra event loop (if it is running) so we CAN leave
        set ASYNc(events) 0
        unset -nocomplain ASYNc(trigger) ;# not much point, but it IS correct
    }

    # we don't particularly care if del-tmp fails.
    catch {del-tmp}
    if {$returncode == {}} {
        set returncode $g(returnValue) ;# Value from latest external execution
    }

    # OPA >>>
    poApps ExitApp $returncode
    # OPA <<<
}

###############################################################################
# Modal error dialog.
###############################################################################
proc do-error {msg {title "Error"}} {
    global g
    debug-info "do-error ($msg)"

    tk_messageBox -message "$msg" -title "$g(name): $title" -icon error -type ok
}

###############################################################################
# INTERNAL stacktrace generator (helps pin down WHERE something got executed)
###############################################################################
proc trap-trace {{title "Trace"}} {
    set str ""
    for {set x [expr [info level]-1]} {$x > 0} {incr x -1} {
        append str "$x: [info level $x]\n"
    }
    do-error $str "$title" ;# pause until developer acknowledges
}

###############################################################################
# Throw up a modal error dialog or print a message to stderr.  For
# Unix we print to stderr and exit if the main window hasn't been
# created, otherwise put up a dialog and throw an exception.
###############################################################################
proc fatal-error {msg} {
    global g tcl_platform
    debug-info "fatal-error ($msg)"

    if {$g(startPhase)} {
        do-error $msg "Aborting..."
    } else {
        puts stderr $msg
    }
    do-exit 2
}

###############################################################################
# Return the name of a temporary file
# n         - a naming fragment (to help identify where/why it was created)
# forget!=0 - dont 'remember' the filename for the "destroy @ termination list"
###############################################################################
proc tmpfile {n {forget 0}} {
    global g opts uniq

    set uniq [expr ($uniq + 1) ]
    set tmpdir [file nativename $opts(tmpdir)]
    set tmpfile [file join $tmpdir "[pid]-$n-$uniq"]
    set access [list RDWR CREAT EXCL TRUNC]
    set perm 0600
    if {[catch {open $tmpfile $access $perm} fid ]} {
        # something went wrong
        error "Failed creating temporary file: $fid"
    }
    close $fid
    if {!$forget} {lappend g(tempfiles) $tmpfile}
    debug-info "temp file $tmpfile"
    return $tmpfile
}

###############################################################################
# Execute a command via poExec.
# Returns "$stdout $stderr $exitcode" if exit code != 0
###############################################################################
proc run-poExec {cmd} {
    global opts errorCode

    set stderr ""
    set exitcode 0
    set errfile [tmpfile "r"]
    debug-info "$cmd"
    set failed [catch "$cmd \"2>$errfile\"" stdout]
    # Read stderr output
    catch {
        set hndl [open "$errfile" r]
        set stderr [read $hndl]
        close $hndl
    }

    if {$failed} {
        switch -- [lindex $errorCode 0] {
        "CHILDSTATUS" {
                set exitcode [lindex $errorCode 2]
            }
        "POSIX" {
                if {$stderr == ""} {
                    set stderr $stdout
                }
                set exitcode -1
            }
        default {
                set exitcode -1
            }
        }
    }

    catch {file delete $errfile}
    return [list "$stdout" "$stderr" "$exitcode"]
}

###############################################################################
# Execute an external command, optionally storing STDOUT into a given filename
# Returns the 3-tuple list "$stdout $stderr $exitcode"
#
# Operation is sensitive to the EXISTANCE (not value) of flag "ASYNc(trigger)"
# to run in ASYNChronous .vs. BLOCKing mode. When running ASYNC, an event loop
# is provided for dispatching tasks encountered WHILE the command is processed 
###############################################################################
proc run-command {cmd {out {}}} {
    global ASYNc errorCode
    debug-info "run-command ($cmd $out)"

    # Arrange for requested output format (given execution constraints)
    #  N.B> 'fout' will become one of: a channel, a cmd indirection, or empty.
    if {[info exists ASYNc(trigger)]} {
        if {[set fout $out] != {}} {
            set fout [open $out wb]
            chan configure $fout -buffering none
        } {upvar #0 ASYNc(out) STDout}
    } elseif {[set fout $out] != {}} {set fout "\">$out\""}

    # Establish default answers
    set STDerr [set STDout ""]
    set exitcode 0
    set cmderr [tmpfile "cmderr" 1] ;# retain filename locally; WE will whack
    #   (N.B> stderr redirection prevents 'catch' from assuming msgs -> errors)

    # But the big difference in ASYNC .vs. BLOCKing is how to deal with STDOUT
    if {[info exists ASYNc(trigger)]} {
        debug-info  "Cmd running in ASYNC mode"

        # Startup the cmd (so we can attach its stdout to the event loop) ...
        # ..where an (anonymous) handler will snag any/all STDOUT produced, but
        # more importantly WATCHES for an EOF, telling us the cmd has completed
        set cmdout [open "|$cmd \"2>$cmderr\"" rb]
        chan configure $cmdout -blocking 0 -buffering none
        chan event $cmdout readable [list apply {{fin fptr} {
                    global ASYNc
                    if {$fptr != {}} {
                        puts -nonewline $fptr [chan read $fin]
                    } else {append ASYNc(out) [chan read $fin]}
                    if {[chan eof $fin]} {set ASYNc(events) 0}
                                                          }} $cmdout $fout]
        set ASYNc(events) 1
        ####
        vwait ASYNc(events) ;# wait here until we see EOF from handler above
        ####
        chan configure $cmdout -blocking 1 ;# (N.B> to get errorcodes)
        if {[set failed [catch "close $cmdout"]]} {set errCODE $errorCode}
        debug-info "Back from ASYNC cmd: rc($failed)"
        if {$fout != {}} {close $fout}

    } elseif {[set failed [catch "exec $cmd $fout \"2>$cmderr\"" STDout]]} {
        set errCODE $errorCode ;# Snag this before it can get overwritten
    }

    # Suck out any error messages that MAY have been produced (and whack file)
    catch {
        set hndl [open "$cmderr" r]
        set STDerr [read $hndl]
        close $hndl
        file delete $cmderr
    }

    if {$failed} {
        switch -- [lindex $errCODE 0] {
        "CHILDSTATUS" {
                set exitcode [lindex $errCODE 2]
            }
        "POSIX" {
                if {$STDerr == ""} {
                    set STDerr $STDout
                }
                set exitcode -1
            }
        default {
                set exitcode -1
            }
        }
    }

   #debug-info "runcmd RESULTS($exitcode): out([string length $STDout])\
                                err([string length $STDerr]) appropriate ?"
    return [list "$STDout" "$STDerr" "$exitcode"]
}

###############################################################################
# Populate the 'ndx'th finfo FILE via its accompanying finfo 'tmp' SCM command
# Returns descriptive msg(s) if something fails; a NUL string on Success
###############################################################################
proc scm-chkget {ndx} {
    global finfo

    if {![info exists finfo(pth,$ndx)]} {
        set finfo(pth,$ndx) "[tmpfile scm$ndx]"
    }
    debug-info "scm-chkget ($ndx) -> '$finfo(tmp,$ndx)': $finfo(pth,$ndx)"

    set result [run-command "$finfo(tmp,$ndx)" "$finfo(pth,$ndx)"]
    set stdout [lindex $result 0]
    set stderr [lindex $result 1]

    # Remember to postproccess (if needed) and ...
    if {![lindex $result 2]} {
        if {[info exists finfo(pproc,$ndx)]} {
            $finfo(pproc,$ndx) "$finfo(pth,$ndx)"
        }
        # ... return the erased cmd (DO NOT UNSET) to indicate Success
        return [set finfo(tmp,$ndx) ""]
    }

    # Send messages back to caller only on failure
    return "$stderr\n$stdout" ;# Failed!
}

###############################################################################
# Filter PVCS output files that have CR-CR-LF end-of-lines
###############################################################################
proc filterCRCRLF {file} {
    debug-info "filterCRCLF ($file)"
    set outfile [tmpfile CRCRLF]
    set inp [open $file r]
    set out [open $outfile w]
    fconfigure $inp -translation binary
    fconfigure $out -translation binary
    set CR [format %c 13]
    while {![eof $inp]} {
        set line [gets $inp]
        if {[string length $line] && ![eof $inp]} {
            regsub -all -- "$CR$CR" $line $CR line
            puts $out $line
        }
    }
    close $inp
    close $out
    file rename -force $outfile $file
}

###############################################################################
# Return the smallest of two values
###############################################################################
proc min {a b} {
    return [expr {$a < $b ? $a : $b}]
}

###############################################################################
# Return the largest of two values
###############################################################################
proc max {a b} {
    return [expr {$a > $b ? $a : $b}]
}

###############################################################################
# Force a recompute because of a changed interpretative semantic
###############################################################################
proc do-semantic-recompute {reason {onoff {}}} {
    global opts finfo
    debug-info "do-semantic-recompute $reason"

    # Optionally permits forcing a setting
    if {$onoff != {}} {
        set opts($reason) $onoff
    }

    set  ndx(1) [set ndx(2) [expr {$finfo(fCurpair) * 2}]]
    incr ndx(1) -1
    if {$finfo(pth,$ndx(1)) != {} && $finfo(pth,$ndx(2)) != {}} {
        recompute-diff
    }
}

###############################################################################
# Align (or force set on/off) Info window item visibility
###############################################################################
proc do-show-Info {{which {}}  {force {}}} {
    global g w opts

    if {$force != {}} {
        set opts($which) $force
    }

    # Detect if/when text Info windows should be mapped OR unmapped
    if {$opts(showln) || $opts(showcbs) || $g(is3way)} {
        if {! [winfo ismapped $w(LeftInfo)]} {
            grid $w(LeftInfo)  -row 0 -column 1 -sticky nsew
            grid $w(RightInfo) -row 0 -column 0 -sticky nsew
        }
    } elseif {[winfo ismapped $w(LeftInfo)]} {
        grid forget $w(LeftInfo)
        grid forget $w(RightInfo)
    }

    # The mergeInfo window (for now) is ALWAYS 'on' ...
    # However if we ever create an opt() for the "contrib markers"
    # then simply uncomment this to get it to turn on/off like above
#   if {$opts(showln) || $opts(XXX-contrib-XXX)} {
#       if {! [winfo ismapped $w(mergeInfo)]} {
#           grid $w(mergeInfo) -row 0 -column 0 -sticky nsew
#       }
#   } elseif {[winfo ismapped $w(mergeInfo)]} {
#       grid forget $w(mergeInfo)
#   }

    # In any event SOMETHING changed - ensure we utilize canvas properly
    cfg-line-info
}

###############################################################################
# Transliterate "text-tagging" precedences for Font/Bg/Fg canvas plotting
###############################################################################
proc translit-plot-txtags {twdg} {
    global g opts

    # The neccessity of this routine stems from the USER view being one of
    # setting 'text-tags' for highlighting various meta-data pgm elements,
    # because THAT was the former implementation. Internally we have shifted
    # to a Canvas based technique (to reduce textline aligment issues since
    # version TK8.5), but must NOW cope with the reality of canvas-text NOT
    # providing a 'tag-precedence-stack' mechanism. Emulating a "what-would-
    # have-happened" approach is better than redefining the USER view of the
    # preferences (or auto-magically MAPPING the existing user base).
    #
    #   Technique is to pre-compute how the tagging-specified user input would
    # be precedence-stacked by the pgm so we can setup direct access to "N"
    # composite sets of values as needed when canvas-rendering the meta-data.
    #   Note that TkDiff uses MORE than simple precedence and thus SOME sets
    # might only be UTILIZED by the Left or Right view, or under values of
    # OTHER related option settings -- thus the NAMING of each set is an
    # encoding that 'plot-line-info' intends to access randomly as needed.

    # First establish a BASE precedence layer (just the Text widget settings)
    #   (what you get if NO user tagging was explicitly supplied [unlikely]).
    # For the 3 key display values we support:        Font Fg Bg
    # plus 2 font-derivative metrics we NEED later:   Ascent Ascent+Descent
    #   (PLUS a running MAX of certain key-character widths across ALL fonts)
    set  Fg  [$twdg cget -foreground]              ;# foreground
    set  Bg  [$twdg cget -background]              ;# background

    set  Fnt "[$twdg cget -font]"                  ;# font
    set  Aft [set Hft [font metrics $Fnt -ascent]] ;# ascent of font
    incr Hft [font metrics $Fnt -descent]          ;# height of font

    set Dw [font measure $Fnt "8"]                 ;# Digit  width
    set Cw [font measure $Fnt "+"]                 ;# ChgBar width
    set Sw [font measure $Fnt " "]                 ;# Space  width
    set Mw [font measure $Fnt "M"]                 ;#  Em    width

    # Begin the database with a snapshot of the "settings" for what is
    # (effectively) the "textopt" tag layer (plain old file lines)
    lappend DB [set nam t] "{$Fnt} $Aft $Hft $Fg $Bg"

    # Now, OVERLAY in PRECEDENCE ORDER, successive basic tags, recording each
    foreach t {difftag currtag} {

        # Turn each tagging definition into a "look up table"(lut) of its
        # contents, then look for any option names of interest, and process
        # whichever ones are found (similar to above BASE setting derivation)
        append nam [string index $t 0]
        array set lut $opts($t)
        foreach op [array names lut -regexp {\-((f|b)g|(fo[rn]|ba))}] {
            # (allow for abbreviations of the V8.5 option keywords)
            switch -glob -- $op {
            "-for*" -
            "-fg"   { set Fg $lut($op) }                           ;# fg
            "-b*"   { set Bg $lut($op) }                           ;# bg
            "-fon*" { set Fnt $lut($op)                            ;# font
                    set  Aft [set Hft [font metrics $Fnt -ascent]] ;# ascent
                    incr Hft [font metrics $Fnt -descent]          ;# height
                    set Dw [max $Dw [font measure $Fnt "8"]] ;# maximal Dw
                    set Cw [max $Cw [font measure $Fnt "+"]] ;# maximal Cw
                    set Sw [max $Sw [font measure $Fnt " "]] ;# maximal Sw
                    set Mw [max $Mw [font measure $Fnt "M"]] ;# maximal Mw
                    }
            }
        }

        # Append this snapshot of values to the overall database
        lappend DB $nam "{$Fnt} $Aft $Hft $Fg $Bg"
        array unset lut
    }

    # DB entries 't'(text) 'td'(diff) and 'tdc'(curr) now exist IN THAT ORDER
    #
    # Next construct the mutually exclusive variations that are specifically
    # composited by the pgm when adds/chgs/dels are detected in the input files
    # onto EACH of the LAST TWO CATEGORIES. Note that specific Info-only
    # situations (eg. opts(colorcbs), highlighting) are NOT addressed here and
    # is handled during 'plot-line-info' rendering directly.
    foreach t {instag chgtag deltag overlaptag} {

        # Re-establish base settings prior to overlay of EACH mutual tag
        foreach {nam base} [lrange $DB 2 5] {
            lassign $base Fnt Aft Hft Fg Bg

            # Derive new name, then turn each tagging definition into a
            # "look up table"(lut) of its contents, looking for the option
            # names of interest, overlaying values found (same as before)
            #   Note that each new name is a MAPPING into its Chgbar mark
            append nam [string map {i + c ! d - o ?} [string index $t 0]]
            array set lut $opts($t)
            foreach op [array names lut -regexp {\-((f|b)g|(fo[rn]|ba))}] {
                # (again, allow for abbreviations of the V8.5 option keywords)
                switch -glob -- $op {
                "-for*" -
                "-fg"   { set Fg $lut($op) }                           ;# fg
                "-b*"   { set Bg $lut($op) }                           ;# bg
                "-fon*" { set Fnt $lut($op)                            ;# font
                        set  Aft [set Hft [font metrics $Fnt -ascent]] ;# ascent
                        incr Hft [font metrics $Fnt -descent]          ;# height
                        set Dw [max $Dw [font measure $Fnt "8"]] ;# maximal Dw
                        set Cw [max $Cw [font measure $Fnt "+"]] ;# maximal Cw
                        set Sw [max $Sw [font measure $Fnt " "]] ;# maximal Sw
                        set Mw [max $Mw [font measure $Fnt "M"]] ;# maximal Mw
                        }
                }
            }

            # Append this snapshot of value to the overall database
            lappend DB $nam "{$Fnt} $Aft $Hft $Fg $Bg"
            array unset lut ;# throw away all lut tuples for next pass
        }
    }

    # Historical Note (Re: TKDIFF 4.2 and earlier)
    #   The highest precedence tag, "inlinetag", is only designed for (thus
    # overrides) 'chgtag' defined values. However, it is ONLY ever APPLIED to
    # char-ranges within the main L/R-Text widgets. Thus its color/font opts
    # NEVER applied to the actual RENDERING of Info data, despite them having
    # been (in the past) CONFIGURED into the Lnum and CB *Text widgets*. Thus
    # it AFFECTS nothing and as such, this emulation ignores it.

    # Finally, post the data needed by 'cfg-line-info' to compute canvas width
    # AND the complete database of precomputed attrs for 'plot-line-info' with
    # its 11 values: "t, td, td+, td!, td-, td?, tdc, tdc+, tdc!, tdc-, tdc?"
    set g(scrInf,cfg) "$Dw $Cw $Sw $Mw"
    set g(scrInf,tags) $DB
}

###############################################################################
# Resolve present Info window plotting configuration (AFTER any chngd settings)
###############################################################################
proc cfg-line-info {} {
    global g w opts

    # First obtain the maximal Text widget font measurements
    lassign $g(scrInf,cfg) wDig wChg wSpc wEm

    # Then establish an X position for plotting the PRIMARY Info elements such
    # that the maximal line number (if visible) will FIT to its left
    #   Values (mX, tX) for windows (Merge .vs. Text) WILL need to be distinct
    set g(scrInf,mX) [set g(scrInf,tX) \
                             [expr {$opts(showln) ? $wDig*$g(lnumDigits) : 0}]]

    # In a 3way Diff situation, make room for a Textwin "ancestral indicator"
    if {$g(is3way)} { incr g(scrInf,tX) $wEm }

    # MergeInfo always (for now) adds space for ITS (left/right) markers
    #   (but it COULD be done as a pref, by replacing 'true' with some var)
    if {[set sz [expr {( true ? $wChg+$wSpc : 0) + $g(scrInf,mX)}]]} {
        $w(mergeInfo) configure -width [incr sz 3]
        incr g(scrInf,mX) ;# 'slides' padding to 1pxl on left and 2pxl right
    }

    # Add to 'tX' any space needed for Changebars (if visible) which will
    # left-justify to that position defined above. Then INCREASE that amount
    # (+5pxl for padding) and apply it to BOTH Text Info canvases, calling it
    # "scrInf,XX" (for plotting), making the canvas EXACTLY wide enough
    #   (does NOTHING if meta-data visibility options are ALL turned off)
    if {[set sz [expr {($opts(showcbs) ? $wChg+$wSpc : 0) + $g(scrInf,tX)}]]} {
        $w(LeftInfo)  configure -width [incr sz 5]
        $w(RightInfo) configure -width [set g(scrInf,XX) $sz]
        incr g(scrInf,tX) 3;# 'slides' padding to 3pxl on left and 2pxl right
    }
}

###############################################################################
# Plot text widget line numbers and/or contrib markers in adjoining info canvas
###############################################################################
proc plot-merge-info {args} {
    global g w opts

    # Ignore this routine if not needed, havent gotten far enough in processing
    # -OR- its trigger will have zero effect on the displayed content
    if {!$g(showmerge) || $g(startPhase) < 2  \
    ||    ([llength $args] > 0 && [lindex $args 0 1] in $g(benign))} return

    # Initialize:   Empty the canvas
    #      Identify the line range of the CDR
    #      Import the 'tag' attr table and make it random access
    #      Begin with NO current attr group
    $w(mergeInfo) delete all
    lassign [$w(mergeText) tag ranges currtag] sCDR eCDR
    array set attr $g(scrInf,tags)
    set aGRP {}

    # Begin at 1st VISIBLE screen text line, converting its indice->integer
    set Lnum [expr {int([$w(mergeText) index @0,0])}]

    # Map/plot Lnums
    # Line numbers here are identical to widget indices. Markers derive
    # from the TAGNAMES used for each line of a given diff REGION.
    #   (PRESUMES the canvas & text widgets are physically aligned!!)
    # Stops when we walk beyond the visible range of the Text widget lines,
    # -OR- we discover the EXTRA "last line" at the bottom of the widget
    set LastLnum [expr {int([$w(mergeText) index end-1lines])}]
    while {[llength [set dline [$w(mergeText) dlineinfo $Lnum.0]]] > 0} {
        if {$Lnum == $LastLnum} {break} ;# ignore extra last line

        # Detect/decode any diff(R/L) tag on the line (if it even exists)
        #   (the tag NAME encodes what SIDE the merge contribution came from)
        # N.B. tags report in priority order, thus ZERO should be where to find
        #   EITHER 'diff(R/L)' (each being of lowest prio & mutually exclusive)
        switch [lindex [$w(mergeText) tag names $Lnum.0] 0] {
        diffR { set aNewGRP [expr {$Lnum<$sCDR || $Lnum>=$eCDR ? "td" : "tdc"}]
                set side " >" }
        diffL { set aNewGRP [expr {$Lnum<$sCDR || $Lnum>=$eCDR ? "td" : "tdc"}]
                set side " <" }
        default { set side {} ; set aNewGRP "t"}
        }

        # Instantiate correct 'tag' attribute group (if it changed)
        if {"$aNewGRP" != "$aGRP"} {
            lassign $attr([set aGRP $aNewGRP]) Fnt Asc Hgt Fg Bg
        }

        # We want to plot on the same BASELINE as the text widget, but it
        # must be EMULATED as canvas '-anchor' provides NO SUCH setting.
        lassign $dline na y na na bl ;# extract TxT y and baseline
        incr y $bl     ;# move y to its baseline then UP by the
        incr y -$Asc   ;# "plot font" ascent (=eff. NE/NW edge)

        # Plot the contributory-side marker (if any)
        if { "$side" != {}} {
            $w(mergeInfo) create text $g(scrInf,mX) $y -anchor nw  \
                    -fill $Fg -font $Fnt -text "$side"
        }

        # Plot LineNum if requested
        if {$opts(showln)} {
            $w(mergeInfo) create text $g(scrInf,mX) $y -anchor ne  \
                    -fill $Fg -font $Fnt -text "$Lnum"
        }
        incr Lnum
    }
}

###############################################################################
# Plot text widget line numbers and/or change bars in adjoining info canvas
###############################################################################
proc plot-line-info {side args} {
    global g w opts

    # Ignore this routine if we havent gotten far enough into the processing
    #   -OR- everything that might have displayed is turned OFF anyway
    if {$g(startPhase) < 2 \
    ||   ((!$g(is3way)) && (!$opts(showln)) && (!$opts(showcbs)))} return

    # Create session-persistent constants for NOW and FUTURE use
    if {! [info exists g(LR,Left)]} {
        set g(LR,Left)  [list Snum Enum Pad Ofst Cbar]
        set g(LR,Right) [list Snum Enum na na na Pad Ofst Cbar]
    }

    # Only redraw when args are null (meaning we were called by a binding)
    # or when called by the trace and the widget action might potentially
    # change the height of a displayed line.
    if {[llength $args] == 0 || [lindex $args 0 1] ni $g(benign)} {

        # Initialize:   Empty the canvas
        #      Import the 'tag' attr table and make it random access
        #      Begin with NO current attr group
        #      Map the index of the 'current diff' to refer to g(DIFF)
        #      Presume default first attr-group is a NON hunk-line
        $w(${side}Info) delete all
        array set attr $g(scrInf,tags)
        set aGRP {}
        set gPos [hunk-ndx [hunk-id $g(pos)] DIFF]
        set aNewGRP "t"

        # Begin at 1st VISIBLE screen text line, converting its indice->integer
        set Lnum [expr {int([$w(${side}Text) index @0,0])}]

        # Now, (if >1 exists) binary-search for an APPROPRIATE start "scrInf,*"
        # entry to allow mapping 'Lnum' BACK to its ORIGINAL linenumber. We
        # want the CLOSEST item (preferrably ABOVE) the target Lnum value, but
        # BELOW is used when Lnum > last line of the final hunk. When NONE
        # exist (files are identical), the screen numbers ARE the real numbers,
        # so a dummy entry allows the remaining code to function properly.
        if {[set i $g(COUNT)]} {
            # N.B> 'rngeSrch' (unlike hunk-id, et.al) uses ZERO-based indices
            #   so increment the index UNLESS it comes back as the last entry
            if {[set i [rngeSrch DIFF $Lnum "scrInf,"]] != $g(COUNT)} {incr i}
            lassign $g(scrInf,[set hID [hunk-id $i DIFF]]) {*}$g(LR,$side)
        } else {lassign       { 0 0 0 0 "" 0 0 "" }        {*}$g(LR,$side) }

        # When a 3way is active, it REQUIRES a per-line 'ancestral' mapping
        #   (so figure out where to START that mapping as well)
        if {$g(is3way)} {
            set anc(max) [llength $g(d3$side)]
            set anc(ndx) [rngeSrch d3$side [expr {$Lnum - $Ofst}]]
            if {$anc(ndx) < $anc(max)} {lassign \
                    [lindex $g(d3$side) $anc(ndx)] anc(fst) anc(lst) anc(mrk)
            } else { lassign       {0 0 " "}       anc(fst) anc(lst) anc(mrk) }
        }

        # Map/plot Lnums, advancing as needed through any mapping entries.
        # Line number translation consists of USING variables already set but
        # WATCHING for when to ADVANCE to the next sequential mapping entry.
        #   (PRESUMES the canvas & text widgets are physically aligned!!)
        # Stops when we walk beyond the visible range of the Text widget lines,
        # -OR- we discover the EXTRA "last line" at the bottom of the widget
        set LastLnum [expr {int([$w(${side}Text) index end-1lines])}]
        while {[llength [set dline [$w(${side}Text) dlineinfo $Lnum.0]]] > 0} {
            if {$Lnum == $LastLnum} {break} ;# ignore extra last line

            # Waterfall test detects phase of WHAT plots WITHIN a hunk boundary
            # and establishes which tag-derived display attribute group to use
            #   (NB. purely Pad'ded lines always skip plotting altogether)
            if {$i > 0 && $Lnum >= $Snum} {
                if {$Lnum > ($Enum - $Pad)} {
                    if {$Lnum > $Enum} {
                        if {$i < $g(count)} {
                            # Step forward to the next hunk mapping
                            #   loading the NEXT scrInf,* entry settings
                            set hID [hunk-id [incr i] DIFF]
                            lassign $g(scrInf,$hID) {*}$g(LR,$side)
                            if {[info exists g(overlap$hID)]} {set Cbar "?"}
                            # Restart loop if 'Lnum' is NOW INSIDE the params
                            # of the newly read-in hunk (to support abutted
                            # hunks created by the Split/Combine feature)
                            if {$Lnum >= $Snum}  continue
                        }
                        set CB false ; set aNewGRP "t" ;# Is beyond entry
                    } else { incr Lnum ; continue }    ;# A  PADDING line
                } else { set CB $opts(showcbs)         ;# A  DIFFed  line
                         set aNewGRP [expr {$i==$gPos ? "tdc$Cbar":"td$Cbar"}]}
            } else {set CB false ; set aNewGRP "t" }   ;# Is before entry

            # Instantiate correct 'tag' attribute group (if it changed)
            if {"$aNewGRP" != "$aGRP"} {
                lassign $attr([set aGRP $aNewGRP]) Fnt Asc Hgt Fg Bg
            }

            # We want to plot on the same BASELINE as the text widget, but it
            # must be EMULATED as canvas '-anchor' provides NO SUCH setting.
            lassign $dline na y na na bl ;# extract TxT y and baseline
            incr y $bl     ;# move y to its baseline then UP by the
            incr y -$Asc   ;# "plot font" ascent (=eff. NE/NW edge)

            # FINALLY plot THIS Lnum and/or ChgBar per the CURRENT options
            # Do ChgBars 1st (more often skipped), with NW-corner as locpt.
            # Subsequent Linenumber will uses NE-corner at the SAME locpt.
            #   (Annoyingly, canvas text has NO "Bg"-cell - must emulate!)
            # Weird flipping of colors just mimics the way tags were APPLIED
            # when this was all done in a Text widget (as of TkDiff 4.2)
            if {$CB} {
                # Highlight Chgbars ? (i.e. colored Bg or Fg)
                if {$opts(tagcbs)} {
                    if {$opts(colorcbs)} { switch -- $Cbar {
                        "!" -
                        "?" { set Cfg [set Cbg $opts(mapchg)] }
                        "+" { set Cfg $opts(mapdel) ; set Cbg $opts(mapins) }
                        "-" { set Cfg $opts(mapins) ; set Cbg $opts(mapdel) }
                        }
                    } else { lassign "$Fg $Bg" Cfg Cbg }

                    # Make/plot a fontsized ChangeBar "background rect"
                    set yy $Hgt
                    set Dims [list $g(scrInf,tX) $y $g(scrInf,XX) [incr yy $y]]
                    $w(${side}Info) create rect $Dims -fill $Cbg -outline $Cbg
                } else  { set Cfg $Fg }

                $w(${side}Info) create text $g(scrInf,tX) $y -anchor nw \
                    -fill $Cfg -font $Fnt -text " $Cbar"
            }

            if {$opts(showln)} {
                # Highlight LineNum ?
                if {$opts(tagln)} {
                    # Make/plot a fontsized Lnum "background rect"
                    #   (also underlays the ancestral marker - if active)
                    set yy $Hgt
                    set Dims [list $g(scrInf,tX) $y 1 [incr yy $y]]
                    $w(${side}Info) create rect $Dims -fill $Bg -outline $Bg
                }

                $w(${side}Info) create text $g(scrInf,tX) $y -anchor ne  \
                    -fill $Fg -font $Fnt -text "[expr {$Lnum - $Ofst}]"
            }

            # Insert the 'ancestral' marker if a 3way is in progress
            #   (and we haven't walked off the list of markers altogether)
            if {$g(is3way) && $anc(ndx) < $anc(max) \
            &&  ($Lnum - $Ofst) >= $anc(fst) && ($Lnum - $Ofst) <= $anc(lst)} {

                $w(${side}Info) create text 1 $y -anchor nw  \
                                          -fill $Fg -font $Fnt -text $anc(mrk)

                # Step map forward to next triplet (when 'last' has been used)
                if {$anc(lst) == $Lnum - $Ofst} {
                    lassign [lindex $g(d3$side) [incr anc(ndx)]] \
                            anc(fst) anc(lst) anc(mrk)
                }
            }

            incr Lnum
        }
    }
}

###############################################################################
# Split a file containing CVS conflict markers into two temporary files
#    name        Name of file containing conflict markers
# Returns the names of the two temporary files and the names of the
# files that were merged
###############################################################################
proc split-conflictfile {name} {
    global g opts
    debug-info "conflicts ($name)"

    if {[catch {set input [open $name r]}]} {
        fatal-error "Couldn't open file '$name'"
    }
    set temp1 [tmpfile cf1]
    set temp2 [tmpfile cf2]

    set first [open $temp1 w]
    set second [open $temp2 w]

    set firstname ""
    set secondname ""
    set output 3

    set firstMatch ""
    set secondMatch ""
    set thirdMatch ""

    while {[gets $input line] >= 0} {
        if {$firstMatch == ""} {
            if {[regexp {^<<<<<<<* +(.*)} $line]} {
                set firstMatch {^<<<<<<<* +(.*)}
                set secondMatch {^=======*}
                set thirdMatch {^>>>>>>>* +(.*)}
            } elseif {[regexp {^>>>>>>>* +(.*)} $line]} {
                set firstMatch {^>>>>>>>* +(.*)}
                set secondMatch {^<<<<<<<* +(.*)}
                set thirdMatch {^=======*}
            }
        }
        if {$firstMatch != ""} {
            if {[regexp $firstMatch $line]} {
                set output 2
                if {$secondname == ""} {
                    regexp $firstMatch $line all secondname
                }
            } elseif {[regexp $secondMatch $line]} {
                set output 1
                if {$firstname == ""} {
                    regexp $secondMatch $line all firstname
                }
            } elseif {[regexp $thirdMatch $line]} {
                set output 3
                if {$firstname == ""} {
                    regexp $thirdMatch $line all firstname
                }
            } else {
                if {$output & 1} {
                    puts $first $line
                }
                if {$output & 2} {
                    puts $second $line
                }
            }
        } else {
            puts $first $line
            puts $second $line
        }
    }
    close $input
    close $first
    close $second

    if {$firstname == ""} {
        set firstname "old"
    }
    if {$secondname == ""} {
        set secondname "new"
    }

    return "{$temp1} {$temp2} {$firstname} {$secondname}"
}

###############################################################################
# Detect which Src Code Managment system is expected to obtain this filename
###############################################################################
proc scm-detect {fn} {

    regsub -all -- {\$} $fn {\$} fn   ;# (Backslash any '$' ciphers as literal)
    # Use dirname OF argument if it is not a directory already
    if {[file isdirectory $fn]} {set dnam $fn} {set dnam [file dirname $fn]}

    # There are basically FOUR 'possibilities' for detection:
    # 1     those determined by the naming of the file itself
    # 2     those that require some ADJOINING file structure naming
    # 3     those requiring external-executables to be invoked
    # 4     those that depend on existance of certain ENV variables
    #
    ### (unknown if a better order exists: one below is purely historical)
    ### *My* gut feeling is the precedence described above should be followed
    ### (which is NOT completely the case as it exists here) however, as some
    ### cases are combo/subsets of others there is plenty of room for debate.
    if {[file isdirectory [file join $dnam CVS]]}          { return CVS
    } elseif {[is-repo-dir ".svn" $dnam]}                  { return SVN
    } elseif {[is-git-repository]}                         { return GIT
    } elseif {[regexp {://} $fn]}                          { return SVN
    } elseif {[sccs-is-bk]}                                { return BK
    } elseif {[file isdirectory [file join $dnam SCCS]]}   { return SCCS
    } elseif {[file isdirectory [file join $dnam RCS]]}    { return RCS
    } elseif {[file isfile $fn,v]}                         { return RCS
    } elseif {[file exists [file join $dnam vcs.cfg]] || \
              [info exists ::env(VCSCFG)]}                 { return PVCS
    } elseif {[info exists ::env(P4CLIENT)] || \
              [info exists ::env(P4CONFIG)]}               { return Perforce
    } elseif {[info exists ::env(ACCUREV_BIN)]}            { return Accurev
    } elseif {[info exists ::env(CLEARCASE_ROOT)]}         { return ClearCase
    } elseif {[is-repo-dir ".hg" $dnam]}                   { return HG
    }

    return "" ;# Unrecognized
}
###############################################################################
# Obtain a revision of a file:
#   fn      requested file name
#   ndx     index in finfo array to place data
#   r       revision ("" for HEAD [ie. latest] revision)
#   Scm     if !Null, which SCM to use (avoids lookup)
# Returns 0 (Success) or 1 (Failed + diagnostic messages produced)
###############################################################################
proc get-file-rev {fn ndx {r ""} {Scm {}}} {
    global g opts finfo tcl_platform
    debug-info "get-file-rev ($fn $ndx \"$r\" $Scm)"

    # Establish SYNTAX of how a revision is specified per the SCM system
    if {"$r" == ""} {
        set rev "HEAD"
        set acopt ""
        set cvsopt ""
        set svnopt ""
        set gitopt ""
        set rcsopt ""
        set sccsopt ""
        set bkopt ""
        set pvcsopt ""
        set p4file "$fn"
        set hgopt ""
    } else {
        set rev "r$r"
        set acopt "-v \"$r\""
        set cvsopt "-r $r"
        set svnopt "-r $r"
        set gitopt "$r:"
        set rcsopt "$r"
        set sccsopt "-r$r"
        set bkopt "-r$r"
        set pvcsopt "-r$r"
        set p4file "$fn#$r"
        set hgopt "-r$r"
    }

    regsub -all -- {\$} $fn {\$} fn   ;# (Ensure any '$' ciphers remain literal)
    set cmdsfx ""       ;# Prevent 'exec'-spoofing on Windows platform(?)
    if {$tcl_platform(platform) == "windows"} { set cmdsfx ".exe" }

    # Presume eventual success ... then
    set msg {}

    # DETECT and then FORMULATE an appropriate SCM command to request the file
    if {"" == $Scm} {set Scm [scm-detect $fn]}
    switch -- $Scm {
    CVS {
        append cmd "cvs" $cmdsfx
        # For CVS, if it isn't checked out there is neither a CVS nor RCS
        # directory.  It will however have a ,v suffix just like rcs.
        #   (There is not necessarily a RCS directory for RCS, either...)
        #   (however, if not, then the file will ALWAYS have a ,v suffix.)
        set finfo(lbl,$ndx) "$fn (CVS $rev)"
        set finfo(tmp,$ndx) "$cmd update -p $cvsopt \"$fn\""

        }
    SVN {
        append cmd "svn" $cmdsfx
        # Subversion command MAY have the form
        # svn diff OLD-URL[@OLDREV] NEW-URL[@NEWREV]
        if {[regexp {://} $fn]} {
            if {![regsub -- {^.*@} $fn {} rev]} { set rev "HEAD" }
            regsub -- {@\d+$} $fn {} path
            if {"$rev" == ""} {
                set finfo(tmp,$ndx) "$cmd cat $path"
                set finfo(lbl,$ndx) "$fn (SVN)"
            } else {
                set finfo(tmp,$ndx) "$cmd cat -r $rev $path"
                set finfo(lbl,$ndx) "$fn (SVN $rev)"
            }
        } else {
            if {"$r" == "" || "$rev" == "rBASE"} {
                set finfo(lbl,$ndx) "$fn (SVN BASE)"
            } else {
                set finfo(lbl,$ndx) "$fn (SVN $rev)"
            }
            set finfo(tmp,$ndx) "$cmd cat $svnopt \"$fn\""
        }

        }
    GIT {
        append cmd "git" $cmdsfx
        # Won't work if you aren't actually INSIDE the work tree
        if {[is-git-repository]} {
            debug-info "exec $cmd rev-parse --show-prefix"
            set prefix [exec $cmd rev-parse --show-prefix]
            if {"$r" == "" || " " == [string index "$r" 0]} {
                set finfo(lbl,$ndx) "$fn (GIT--staged)" ;# STAGEd vrsn
                set finfo(tmp,$ndx) "$cmd show \":$prefix$fn\""
            } else {
                set finfo(lbl,$ndx) "$fn (GIT $rev)" ;# REQSTd vrsn
                set finfo(tmp,$ndx) "$cmd show \"$gitopt$prefix$fn\""
            }
        } {set msg "Please re-start from within a Git work tree."}
        }
    BK {
        append cmd "bk" $cmdsfx
        set finfo(lbl,$ndx) "$fn (Bitkeeper $rev)"
        set finfo(tmp,$ndx) "$cmd get -p $bkopt \"$fn\""

        }
    SCCS {
        append cmd "sccs" $cmdsfx
        set finfo(lbl,$ndx) "$fn (SCCS $rev)"
        set finfo(tmp,$ndx) "$cmd get -p $sccsopt \"$fn\""
        }
    RCS {
        append cmd "co" $cmdsfx
        set finfo(lbl,$ndx) "$fn (RCS $rev)"
        set finfo(tmp,$ndx) "$cmd -p$rcsopt \"$fn\""
        }
    PVCS {
        append cmd "get" $cmdsfx
        set finfo(lbl,$ndx) "$fn (PVCS $rev)"
        set finfo(tmp,$ndx) "$cmd -p $pvcsopt \"$fn\""
        set finfo(pproc,$ndx) "filterCRCRLF"
        }
    Perforce {
        append cmd "p4" $cmdsfx
        set finfo(lbl,$ndx) "$fn (Perforce $rev)"
        set finfo(tmp,$ndx) "$cmd print -q \"$p4file\""
        }
    Accurev {
        append cmd "accurev" $cmdsfx
        set finfo(lbl,$ndx) "$fn (Accurev $rev)"
        set finfo(tmp,$ndx) "$cmd cat $acopt \"$fn\""
        }
    ClearCase {
        # is this NOT a Windows tool (why no append of .exe?)
        set cmd "cleartool"
        set finfo(lbl,$ndx) "$fn (ClearCase $rev)"

        # list given file
        debug-info "exec $cmd ls -s $fn"
        catch {exec $cmd ls -s $fn} ctls
        # get the path name to file AND the (present?) revision info
        #   (either CHECKEDOUT or a number)
        if {![regexp {(\S+)/([^/]+)$} $ctls dummy path checkedout]} {
            set msg "Couldn't parse ct ls output '$ctls'"
            break
        }

        # Compute the designated previous version
        if {$checkedout == "CHECKEDOUT" || $checkedout == 0} {
            if {$checkedout == 0} {
                set path [file dirname $path]
            }
            set pattern "create version \"($path/\[^/\]+)\""
        } else {
            incr checkedout -1
            set pattern "create version \"($path/$checkedout)\""
        }

        # Search history of the file for the designated version on our branch
        debug-info "exec $cmd lshistory -last 50 $fn"
        catch {exec $cmd lshistory -last 50 $fn} ctlshistory
        set lines [split $ctlshistory "\n"]
        set predecessor ""
        foreach l $lines {
            if {[regexp $pattern $l dummy predecessor]} {
                # Point DIRECTLY at the requested file
                # However, make it APPEAR like it IS a tmpfile
                #   (so we can deny invoking an editor later)
                set finfo(pth,$ndx) $predecessor
                set finfo(tmp,$ndx) ""
                break
            }
        }
        if {$predecessor == ""} {set msg "Couldn't deal with $fn, gave up..."}

        }
    HG {
        # mercurial support
        append cmd "hg" $cmdsfx
        if {"$r" == "" || "$rev" == "PARENT"} {
            # in hg, the revision for cat defaults to the parent revision
            # of the working directory
            set finfo(lbl,$ndx) "$fn (HG PARENT)"
            set finfo(tmp,$ndx) "$cmd cat $fn"
        } else {
            set finfo(lbl,$ndx) "$fn (HG $rev)"
            set finfo(tmp,$ndx) "$cmd cat $hgopt $fn"
        }

        }
    default { set msg "File '$fn' is not part of a revision control system" }
    }

    # If NO errs (and in 1st pairing) NOW is the time to actually GET the file
    if {$msg == ""} {
        if {$ndx <= 2 && [string length $finfo(tmp,$ndx)]} {
            watch-cursor "Accessing $finfo(lbl,$ndx)"
            set msg [scm-chkget $ndx]
            restore-cursor
        }
    }

    # Note label for this file COULD be overridden (just NOT here)
    if {[info exists finfo(ulbl,$ndx)] && $finfo(ulbl,$ndx) != {}} {
        debug-info "  User label: $finfo(ulbl,$ndx) OVERRIDES finfo(lbl,$ndx)"
    }

    # Report errors, but only abort if tool is NOT up and running
    if {"$msg" != ""} {
        if {$g(startPhase)} {do-error "$msg"} {fatal-error "$msg"}
        return 1
    }
    return 0
}

proc is-repo-dir {trgnam dirname} {
    debug-info "is-repo-dir ($trgnam $dirname)"
    # check for trgnam directory in all parent directories
    set dirname [file normalize $dirname]
    set prevdir {}
    while {$dirname != $prevdir} {
        set chkDnam [file join $dirname $trgnam]
        if {[file isdirectory $chkDnam]} { return true }
        set prevdir $dirname
        set dirname [file dirname $dirname]
    }
    return false
}

proc is-git-repository {} {
    debug-info "is-git-repository(): exec git rev-parse --is-inside-work-tree"
    return [expr [catch {eval "exec git rev-parse --is-inside-work-tree"} err] == 0]
}

proc sccs-is-bk {} {
    debug-info "sccs-is-bk ()"
    set cmd [auto_execok "bk"]
    set result 0
    if {[string length $cmd] > 0} {
        debug-info "exec bk root"
        if {![catch {exec bk root} error]} {
            set result 1
        }
    }
    return $result
}

###############################################################################
# Obtain an ordinary file
# Returns:  0  Success
#           1  Failed
###############################################################################
proc get-file {fn ndx} {
    global g finfo
    debug-info "get-file ($fn $ndx)"

    set msg ""
    if {[file isfile $fn]} {
        set finfo(lbl,$ndx) [set finfo(pth,$ndx) "$fn"]
    } elseif {![file exist $fn]} {
             set msg "File '$fn' does not exist"
    } else { set msg "'$fn' exists, but is not a file" }

    # Report errors, but only abort if tool is NOT up and running
    if {"$msg" != ""} {
        if {$g(startPhase)} {do-error "$msg"} {fatal-error "$msg"}
        return 1
    }
    return 0
}

###############################################################################
# Read the commandline (errors result in usage + termination)
# Returns: =0 incomplete (requires interactive assistance)
#          >0 success (enough info SUPPLIED for at least 1 pairing to exist)
###############################################################################
proc commandline {} {
    global g opts finfo argv argc

    set g(initOK) 0
    set argindex 0
    set pths [set revs 0] ;# Note: an Ancestor file is NEVER 'counted'
    set lbls 0
    set ignores [llength $opts(ignoreRegexLnopt)]

    # Loop through argv, storing revision args in rev and file args in
    # finfo. revs and pths are counters.
    while {$argindex < $argc} {
        set arg [lindex $argv $argindex]
        switch -regexp -- $arg {
        "^-h" -
        "^--help" {
                do-usage cline
                exit 0
            }
        "^-a$" {
                incr argindex
                set finfo(f,0) [lindex $argv $argindex]
            }
        "^-a.*" {
                set finfo(f,0) [string range $arg 2 end]
            }
        "^-@$" {
                incr argindex
                set finfo(rev,0) [lindex $argv $argindex]
            }
        "^-@.*" {
                set finfo(rev,0) [string range $arg 2 end]
            }
        "^-v$" -
        "^-r$" {
                incr argindex
                incr revs
                set finfo(rev,$revs) [lindex $argv $argindex]
            }
        "^-v.*" -
        "^-r.*" {
                incr revs
                set finfo(rev,$revs) [string range $arg 2 end]
            }
        "^-L$" {
                incr argindex
                incr lbls
                set finfo(ulbl,$lbls) [lindex $argv $argindex]
            }
        "^-L.*" {
                incr lbls
                set finfo(ulbl,$lbls) [string range $arg 2 end]
            }
        "^-conflict$" {
                set g(conflictset) 1
            }
        "^-o$" {
                incr argindex
                set g(mergefile) [lindex $argv $argindex]
            }
        "^-o.*" {
                set g(mergefile) [string range $arg 2 end]
            }
        "^-u$"  {
                # Ignore flag from "svn diff --diff-cmd=tkdiff"
            }
        "^-B$"  {
                set opts(ignoreEmptyLn) 1
            }
        "^-I$"  {
                incr argindex
                lappend opts(ignoreRegexLnopt) [lindex $argv $argindex]
            }
        "^-I.*"  {
                lappend opts(ignoreRegexLnopt) [string range $arg 2 end]
            }
        {^-[12]$} {
                set opts(predomMrg) [string range $arg end end]
            }
        "^-d$"  {
                set g(debug) t ;# Now that it is ON, report where we are
                debug-info "commandline  argv: $argv"
            }
        "^-psn" {
                # Ignore the Carbon Process Serial Number
                set argv [lreplace $argv $argindex $argindex]
                incr argc -1
                incr argindex
            }
        "^-" {
                append opts(diffcmd) " " [concat "$arg"]
            }
        default {
                incr pths
                set finfo(f,$pths) $arg
            }
        }
        incr argindex
    }

    # Check for an overflow of revision and/or file args given.
    #   (Command line syntax bounds checks)
    debug-info " $pths filespecs, $revs revisions"
    if {$revs > 2 || $pths > 2} {
        if {$pths > 2} {
            puts stderr "Error: specify at most 2 filespecs"
        }
        if {$revs > 2} {
            puts stderr "Error: specify at most 2 revisions"
        }
        do-usage cline
        exit 1
    }

    # Underflow is trickier - ZERO *may* be legal given certain SCM abilities
    if {$revs + $pths == 0} {
        # Basically this is a simple hack to AVOID invoking "newDiffDialog"
        #   Just prepend each SCM name here that knows how to GENERATE its
        # own list of difference candidates when NO ARGS have been provided
        # Generally this results in HEAD .vs. 'sandbox' (aka 'working copy')
        switch -- [scm-detect "."] {
            SVN -
            GIT { incr revs }
        }
    }
    # NB: it MIGHT be a Good Thing to place the choice of the specific SCM
    # into the preferences dialog (would need some thought to do properly;
    # with maybe a DEFAULT of "auto-detect" which is what we do NOW...)

    # Imply certain settings:
    #   - indicate the merge file is SUPPOSEDLY known (but may not survive)
    #   - turn on Regex line skipping *if* if was added here (else its a pref)
    if {$g(mergefile) != ""} {set g(mergefileset) 1}
    if {$ignores < [llength $opts(ignoreRegexLnopt)]} {set ignoreRegexLn 1}

    return [expr {$revs + $pths}]
}

###############################################################################
# Process the arguments, whether from the command line or from the dialog
# Returns: >0 success (= number of file pairings that apparently exist)
#             (only the first of which has generally been already obtained)
#          =0 failure (can not continue)
###############################################################################
proc assemble-args {} {
    global g opts finfo
    debug-info "assemble-args ()"

    #debug-info " conflict: $g(conflictset)"
    #debug-info " mergefile set: $g(mergefileset) $g(mergefile)"
    #debug-info " diff command: $opts(diffcmd) "

    # Recount how many files and revs we got from the GUI or commandline
    #   (An AncestorFile - slot ZERO - is never part of the count)
    set pths 0
    foreach p [array names finfo f,*] {
        if {$finfo($p) != "" && $p != "f,0"} {
            incr pths
        }
    }
    set revs 0
    foreach r [array names finfo rev,*] {
        if {$finfo($r) != "" && $r != "rev,0"} {
            incr revs
        }
    }
    # Save the CURRENT derived values (in case NEWLY derived values fail)
    # and establish a catchall failure msg (should NEVER actually see it)
    set priorVals [array get finfo {[ptl]*[0-9]}]
    array unset finfo {[ptl]*[0-9]}
    set msg "Unexpected failure (internal error)"

    debug-info " Recovered $pths filespecs, $revs revisions"

#   The task here is to deal with trying to expand all GIVEN args into PAIRS
#   of things to compare, thus validating *syntactically* what should happen.
#   Note that SEMANTIC correctness (can we actually OBTAIN what is described)
#   will occur later.
#       CURRENT ASSUMPTIONs -
#       - when an SCM is needed, we PRESUME any FILESPEC refers to the SCM
#       sandbox (either as a REAL dir or file); when only a single (or default)
#       revision is provided, then the FILES of the sandbox will participate.
#       - when TWO revs are given, NO FILES from the sandbox are used (except
#       possibly for name generation); BOTH revisions create temp files FROM
#       the SCM, even if either revision were to MATCH that of the sandbox.
#       - finally, if NO ARGS are provided, CERTAIN SCM systems may generate
#       their OWN list of files AND the revision pockets each should come from

    set cnt 0 ;# Track how many IMPLIED files ultimately are derived

    if {$g(conflictset)} {
        if {$revs == 0 && $pths == 1} {
            #################################################################
            # tkdiff -conflict FILE
            #################################################################
            set files [split-conflictfile "$finfo(f,1)"]
            if {![get-file [lindex "$files" 0] 1]} {incr ndx}
            if {![get-file [lindex "$files" 1] 2]} {incr ndx}
            # A conflict file may come from merge, cvs, or vmrg.  The
            # names of the files/revisions depend on how it was made and
            # are taken from the <<<<<<< and >>>>>>> lines inside it.
            set finfo(lbl,1) [lindex "$files" 2]
            set finfo(lbl,2) [lindex "$files" 3]
            set cnt 2
        } else {
            set msg "a -conflict run should have ONLY 1 filespec (we saw $pths)"
        }
    } else {
        set msg "you specified $pths filespec(s) and $revs revision(s)"
        if {$revs <= 2 && $pths == 0} {
            #################################################################
            #  tkdiff                                 (simply NO input given)
            #                        -OR-
            #  tkdiff -rREV                            ($CWD is)  SCM sandbox
            #  tkdiff -rREV1 -rREV2                   (with 1 or 2 revisions)
            #################################################################

            #   Some SCMs can produce their OWN list of files 'known' to be
            # different; POSSIBLY with no input whatsoever. So detect the SCM
            # first, THEN (if it is one) let *it* try. All other cases lead
            # to error msgs (if revs were given).
            # Note that DETECTING the SCM is based on the current PROCESS dir
            switch -- [set Scm [scm-detect "."]] {
            GIT {
                # N.B: An input syntax of '-r ' (or '-r " "') is the Git Index
                # If (cnt < 2), "msg" will be overwritten with reason why
                set cnt [inquire-git $revs msg]
            }

            SVN {
                set cnt [inquire-svn $revs msg]
            }

            default {
              if {$revs} {
                if {"$Scm" != "" } {
                  set msg "the $Scm SCM system needs at least 1 filespec given"
                } else {
                  set msg "no SCM could be detected for the current directory"
                }
              }
            }
            }
        } elseif {$revs < 2 && $pths == 1} {
            #################################################################
            #  tkdiff       FILESPEC            (file in, dir at) SCM sandbox
            #  tkdiff -rREV FILESPEC             (with or without a revision)
            #################################################################
            if {$revs} {set r1 $finfo(rev,1)} {set r1 ""}
            if {[file isdirectory [set f $finfo(f,1)]]} {
                foreach f2 [glob -nocomplain -directory $f -types f -- *] {
                    set f1 "[file join $f [file tail $f2]]"
                    if {[get-file-rev "$f1" [incr cnt] "$r1"]} {
                        array unset finfo "\[ptl]*,$cnt" ; incr cnt -1
                    } elseif {[get-file "$f2" [incr cnt]]} {
                        array unset finfo "\[ptl]*,$cnt"
                        array unset finfo "\[ptl]*,[incr cnt -1]"
                        incr cnt -1
                    }
                }
            } else {
                if {[get-file-rev "$f" [incr cnt] "$r1"]} {
                    array unset finfo "\[ptl]*,1" ; incr cnt -1
                } elseif {[get-file "$f" [incr cnt]]} {
                    array unset finfo "\[ptl]*,[12]"
                }
            }

        } elseif {$revs == 2 && $pths == 1} {
            #################################################################
            #  tkdiff -rREV1 -rREV2 FILESPEC    (file in, dir at) SCM sandbox
            #################################################################
            set r1 "$finfo(rev,1)"
            set r2 "$finfo(rev,2)"
            if {[file isdirectory [set f $finfo(f,1)]]} {
                foreach f2 [glob -nocomplain -directory $f -types f -- *] {
                    set f1 "[file join $f [file tail $f2]]"
                    if {[get-file-rev "$f1" [incr cnt] "$r1"]} {
                        array unset finfo "\[ptl]*,$cnt" ; incr cnt -1
                    } elseif {[get-file-rev "$f2" [incr cnt] "$r2"]} {
                        array unset finfo "\[ptl]*,$cnt"
                        array unset finfo "\[ptl]*,[incr cnt -1]"
                        incr cnt -1
                    }
                }
            } else {
                if {[get-file-rev "$f" [incr cnt] "$r1"]} {
                    array unset finfo "\[ptl]*,1" ; incr cnt -1
                } elseif {[get-file-rev "$f" [incr cnt] "$r2"]} {
                    array unset finfo "\[ptl]*,[12]"
                }
            }

        } elseif {$revs > 0 && $pths == 2} {
            #################################################################
            #  tkdiff -rREV1 FILESPEC1          (file in, dir at) SCM sandbox
            #   (+)   -rREV2 FILESPEC2         (same or distinct) SCM sandbox
            #      (permits comparisons that CROSS a branch/WC boundary)
            #################################################################
            set f1 $finfo(f,1) ; set r1 "$finfo(rev,1)"
            set f2 $finfo(f,2) ; set r2 "$finfo(rev,2)"
            if {[file isdirectory $f1] && [file isdirectory $f2]} {
                foreach f [glob -nocomplain -directory $f1 -types f -- *] {
                    # (Generates names USING the WC content)
                    if {![file isfile [set fn2 [file join $f2 $f]]]} {
                            continue} {set fn1 [file join $f1 $f]}
                    if {[get-file-rev "$fn1" [incr cnt] "$r1"]} {
                        array unset finfo "\[ptl]*,$cnt" ; incr cnt -1
                    } elseif {[get-file-rev "$fn2" [incr cnt] "$r2"]} {
                        array unset finfo "\[ptl]*,$cnt"
                        array unset finfo "\[ptl]*,[incr cnt -1]"
                        incr cnt -1
                    }
                }
                if {$cnt < 2} {
                    set msg "Neither WC has ANY filename in common"
                }
            } elseif {[file isdirectory $f1]} {
                set f "[file join $f1 [file tail $f2]]"
                if {[get-file-rev "$f" [incr cnt] "$r1"]} {
                    array unset finfo "\[ptl]*,$cnt" ; incr cnt -1
                } elseif {[get-file-rev "$f2" [incr cnt] "$r2"]} {
                    array unset finfo "\[ptl]*,$cnt"
                    array unset finfo "\[ptl]*,[incr cnt -1]"
                    incr cnt -1
                }
            } elseif {[file isdirectory $f2]} {
                set f "[file join $f2 [file tail $f1]]"
                if {[get-file-rev "$f" [incr cnt] "$r2"]} {
                    array unset finfo "\[ptl]*,$cnt" ; incr cnt -1
                } elseif {[get-file-rev "$f1" [incr cnt] "$r1"]} {
                    array unset finfo "\[ptl]*,$cnt"
                    array unset finfo "\[ptl]*,[incr cnt -1]"
                    incr cnt -1
                }
            } else {
                if {[get-file-rev "$f1" [incr cnt] "$r1"]} {
                    array unset finfo "\[ptl]*,1" ; incr cnt -1
                } elseif {[get-file-rev "$f2" [incr cnt] "$r2"]} {
                    array unset finfo "\[ptl]*,[12]"
                }
            }

        } elseif {$revs == 0 && $pths == 2} {
            ############################################################
            #  tkdiff FILESPEC1 FILESPEC2     (files, dirs, or BOTH url)
            ############################################################
            set f1 $finfo(f,1)
            set f2 $finfo(f,2)

            # One, the other, or both may be directories
            # Regardless, the same FILE name must exist in EACH to be paired
            # (Implies that only FILES can be used with DIRS -- NOT URLs!!)
            if {[file isdirectory $f1] && [file isdirectory $f2]} {
                foreach fn [glob -nocomplain -directory $f1 -types -- f *] {
                    #N.B. "file isfile xx" thankfully DOES honor OS softlinks
                    if {[file isfile [set f [file join $f2 [file tail $fn]]]]} {
                        set finfo(lbl,[incr cnt]) [set finfo(pth,$cnt) $fn]
                        set finfo(lbl,[incr cnt]) [set finfo(pth,$cnt) $f]
                    }
                }
                if {$cnt < 2} {
                    set msg "Both directories have NO filenames in common"
                }
            } elseif {[file isdirectory $f1]} {
                if {![get-file [file join $f1 [file tail $f2]] 1]} {incr cnt} {
                    set msg "Searched file $f2 non-existant in: $f1"
                }
                if {![get-file "$f2" 2]} {incr cnt}
            } elseif {[file isdirectory $f2]} {
                if {![get-file "$f1" 1]} {incr cnt}
                if {![get-file [file join $f2 [file tail $f1]] 2]} {incr cnt} {
                    set msg "Searched file $f1 non-existant in: $f2"
                }
            } else {
                # Otherwise they MIGHT be Subversion URL paths, or local files
                if {[regexp {://} $f1]} {
                    if {![get-file-rev "$f1" 1]} {incr cnt}
                } else {
                    if {![get-file "$f1" 1]} {incr cnt}
                }
                if {[regexp {://} $f2]} {
                    if {![get-file-rev "$f2" 2]} {incr cnt}
                } else {
                    if {![get-file "$f2" 2]} {incr cnt}
                }
                # OPA >>>
                set g(havePlainFiles) 1
                # OPA <<<
            }
        }
    }

    debug-info "Final: $revs revs  $pths filespecs -> $cnt/2 pairings"
    if {$cnt < 2} {
        if {[info exists w(tw)] && [winfo exists $w(tw).toolbar]} {
            do-error "Error: $msg"
            do-usage gui
            tkwait window .usage
        } else {
            puts stderr "Error: $msg"
            do-usage cline
        }
        # Restore PRIOR values to finfo 
        array unset finfo {[ptl]*[0-9]}
        array set finfo $priorVals
    } else {
        set finfo(fCurpair) 1
        set finfo(fPairs) [expr {$cnt / 2}]

        # Unlike other files, an Ancestor file can ONLY come from an SCM when
        # a revision has been given (because DEFAULTING it to the most recent
        # check-in defeats its purpose)
        if {[set f $finfo(f,0)] != {}} {
            if {[set r0 $finfo(rev,0)] != ""} {
                if {[get-file-rev "$f" 0 "$r0"]} {
                    array unset finfo "\[ptl]*,0"
                }
            } elseif {[get-file "$f" 0]} {
                array unset finfo "\[ptl]*,0"
            }
        }
    }
    # Establish if 3way mode is NOW active or not
    set g(is3way) [info exists finfo(lbl,0)]
    return $finfo(fPairs)
}

###############################################################################
# Align window label decorations to the CURRENT input file pairing
###############################################################################
proc alignDecor {pairnum} {
    global g w finfo

    set  ndx(1) [set ndx(2) [expr {$pairnum * 2}]]
    incr ndx(1) -1

    set finfo(title) \
        "[file tail $finfo(lbl,$ndx(1))] .vs. [file tail $finfo(lbl,$ndx(2))]"

    # Set file labels (possibly overridden) and a Tooltip for REAL files
    foreach {LR n} {Left 1 Right 2} {
        if {[info exists finfo(ulbl,$ndx($n))] && $finfo(ulbl,$ndx($n)) !={}} {
            set finfo(lbl,$LR) $finfo(ulbl,$ndx($n))    ;# Override lbl display
        } else {set finfo(lbl,$LR) $finfo(lbl,$ndx($n))}

        if {![info exists finfo(tmp,$ndx($n))]} {
            set    tipdata "{$finfo(pth,$ndx($n))\n"
            append tipdata "[clock format [file mtime $finfo(pth,$ndx($n))]]}"
        } { set    tipdata {}}
        set_tooltips $w(${LR}Label) "$tipdata"
    }

    # Add/Remove the Ancestor indicator (and its tooltip) as needed
    if {$g(is3way)} {
        grid $w(AncfLabel) -row 0 -column 1
        if {![info exists finfo(tmp,0)]} {
            set    tipdata "{$finfo(pth,0)\n"
            append tipdata "[clock format [file mtime $finfo(pth,0)]]}"
        } { set    tipdata "{$finfo(lbl,0)}"}
        set_tooltips $w(AncfLabel) "$tipdata"
    } else {
        set_tooltips $w(AncfLabel) {}
        grid forget $w(AncfLabel)
    }

    # Unlock a preset mergefile name if the CURRENT pairing COULD be arbitrary
    if {$finfo(fPairs) > 1} {set g(mergefileset) 0}

    # Guess the best 'mergefile' name for the CURRENT pairing (if not preset)
    if {! $g(mergefileset)} {
        # If BOTH are tmpfiles, lets go with just the file itself in the CWD...
        if {[info exist finfo(tmp,$ndx(1))]&&[info exist finfo(tmp,$ndx(2))]} {
            set rootname [file rootname [file tail $finfo(pth,$ndx(1))]]
            set suffix [file extension $finfo(pth,$ndx(1))]
        } else {
            # ...or lets pair it to the NON-tempfile location (Left preferred)
            if {[info exists finfo(tmp,$ndx(1))]} {set i 2} {set i 1}
            set rootname [file rootname $finfo(pth,$ndx($i))]
            set suffix [file extension $finfo(pth,$ndx($i))]
        }
        set g(mergefile) [file join [pwd] "${rootname}-merge$suffix"]
    }
    set g(initOK) 1
    debug-info "MergeFileSet($g(mergefileset)): $g(mergefile)"

    wm title . "$finfo(title) - $g(name) $g(version)"
    return 0
}

###############################################################################
# Request git to supply relevant target argument(s)
###############################################################################
proc inquire-git {revs msgRet} {
    global finfo
    upvar $msgRet MSG
    debug-info "inquire-git ($revs)"

    # Git diff requires 0-2 commit-ish "somethings" (hash, HEAD, etc...)
    #
    # As such, we expect those args to come thru as 'revs'; 'pths' would
    # only be useful to LIMIT the list being constructed.
    #   Git differs from most SCMs in that it has an intermediate "pocket"
    # (called the 'index', or 'stage') BETWEEN the working copy (WC) and a
    # bona-fide "commit" (aka revision). Therefore while the nominal mapping
    # is:
    #     'revs':
    #       0   = HEAD -> WC
    #       1   = rev -> WC
    #       2   = revA -> revB
    # use of a BLANK rev ("  ") denotes the Index. Everything else should be
    # handled by "git rev-parse" (tags/hashes/branches/expressions/etc.)
    # Actual filesys entities are handled via "get-file-rev" (NOT in this proc)
    #
    #   HOWEVER, we are responsible for mapping the BLANK rev to the --staged
    # keyword required to make "git diff" actually access the Index.
    set cmit(2) [set rev(2) ""]
    if {$revs == 0} {
        # Sets up       HEAD     ->   WC
        set cmit(1) [set rev(1) "HEAD"]
    } elseif {$revs <= 2} {
        # Sets up    (R1 or Index)  ->  (WC or Index or R2)
        if {"" == [string trim [set cmit(1) [set rev(1) $finfo(rev,1)]]]} {
            set cmit(1) "--staged"
        }
        if {$revs == 2} {
            # Sets up    R1   ->   R2      (but just NOT Index -> Index)!!!
            if {"" == [string trim [set cmit(2) [set rev(2) $finfo(rev,2)]]]} {
                if {"--staged" != $cmit(1)} {set cmit(2) "--staged"} {
                    set MSG "BOTH revisions cannot specify the Git Index"
                    return 0 ;# (Would've resulted in Index -> WC)
                }
            }
        }
    }

    # Ask Git which files ACTUALLY differ between the given endpoint(s)
    set result [run-command "git diff --name-only $cmit(1) $cmit(2)"]
    set gitOUT [lindex $result 0]
    set gitERR [lindex $result 1]
    set gitRC [lindex $result 2]
    if {$gitRC != 0 || $gitOUT == ""} {
        if {$gitRC == 0} {
            set MSG "Git Diff shows NO output using args: $cmit(1) $cmit(2)"
        } else {set MSG "Git Diff FAILED:\n$gitERR"}
        return 0
    }

    set git_root [exec git rev-parse --show-toplevel]
    set ndx 0
    foreach file [split $gitOUT "\n"] {
        foreach i {1 2} {
            incr ndx
            if {$rev($i) != ""} {
                if {" " == [string index "$rev($i)" 0]} {
                    set finfo(lbl,$ndx) "$file (Git$cmit($i))"
                } { set finfo(lbl,$ndx) "$file (Git $rev($i))"}

                # NORMALLY we would only extract the first pairing and
                # simply RECORD the others for later processing...BUT - Git
                # is a "local-machine" access method (no latency) so doing
                # them ALL right now should not be a burden.
                #   If that proves wrong, THIS is where to fix it.
                set finfo(pth,$ndx) [tmpfile "tkd__[file tail $file]"]
                set finfo(tmp,$ndx) ""
                set cmd "git show $rev($i):$file"

                set result [run-command $cmd $finfo(pth,$ndx)]
                if {[lindex $result 2]} {
                    set gitERR [lindex $result 1]
                    if [string match "*exists on disk*" $gitERR] {
                        #   (the file simply is not *from* the requested 'rev')
                        # Maybe it is an uncommitted (yet staged) file ?
                        #   Action: do nothing, let the tmp file remain empty.
                        # This will end up as looking like an 'add' or 'del'
                        # depending on which rev (1 or 2) could not find it.

                    #} elseif [string match "*Invalid object name*" $gitERR] {
                    # This used to just 'return 0'...but why single it out ?

                    } else {
                        # Instead, we just let it fall into this catchall,
                        # and ensure that the PAIR OF FILES gets skipped...
                        # NOT just the one that failed. Note that MSG is only
                        # seen when NO pairs remain & TkDiff subsequently bails
                        set MSG "FAILED: 'git show $rev($i):$file':\n$gitERR"
                        if {$i == 1} {incr ndx -1; break} {incr ndx -2}
                    }
                }
            } else {
                # Just point at the REAL 'working copy' file (allows editting)
                set finfo(lbl,$ndx) "$file (Git--WC)"
                set finfo(pth,$ndx) $git_root/$file
            }
        }
    }
    return $ndx
}

###############################################################################
# Request svn to supply relevant target argument(s)
###############################################################################
proc inquire-svn {revs msgRet} {
    global finfo
    upvar $msgRet MSG
    debug-info "inquire-svn ($revs)"

    # 'svn diff --summarize' tells us WHAT changed across a range of revisions
    #
    # rev is what we will tell svn cat to access
    # cmit is how we express the range to 'svn diff'
    set cmit(2) [set rev(2) ""]

    # This could take some time, so let user know we are busy
    watch-cursor "Inquiring of SVN for files..."

    if {$revs == 0} {
        # Sets up       BASE     ->   WC
        set cmit(1) [set rev(1) "BASE"]
    } elseif {$revs <= 2} {
        # Sets up    R1   ->   (WC or R2)
        set cmit(1) [set rev(1) $finfo(rev,1)]
        if {$revs == 2} {
            # Finish seting up    R1   ->   R2
            set cmit(2) ":[set rev(2) $finfo(rev,2)]"
        }
    }

    # Ask Svn which items got committed between the given endpoint(s)
    #   do we need/want "--depth files" ???
    # N.B> this might get messy with URL/PEG/date notations!!!
    set result [run-command "svn diff --summarize -r $cmit(1)$cmit(2)"]
    set svnOUT [lindex $result 0]
    if {[set svnRC [lindex $result 2]] || $svnOUT == ""} {
        set svnERR [lindex $result 1]
        if {$svnRC == 0} {
            set MSG "Svn diff shows NO output using rev: $cmit(1)$cmit(2)"
        } else {set MSG "Svn diff FAILED:\n$svnERR"}
        return 0
    }

    # Expected output form should look like lines of:
    #           "flgs     filename"
    # (indices)  0-------78--------->
    #
    #  where flgs can be:
    #      D    -deleted
    #      A    -added
    #      M    -modified
    #      xM   -(2nd M) properties modified
    # Do we need to pass an EMPTY file if the flag shows up as 'D' or 'A' ??
    set ndx 0
    foreach ln [split $svnOUT "\n"] {
        if {"" == [string trim [set file [string range $ln 8 end]]]} {continue}
        foreach i {1 2} {
            incr ndx
            if {"" != $rev($i)} {
                if {[get-file-rev $file $ndx $rev($i) SVN]} {
                    if {$i == 1} {incr ndx -1; break} {incr ndx -2}
                }
            } else {
                # Just point at the REAL 'working copy' file (allows editting)
                set finfo(lbl,$ndx) "$file (SVN--WC)"
                set finfo(pth,$ndx) $file
            }
        }
    }
    restore-cursor
    return $ndx
}

###############################################################################
# Set up the display
###############################################################################
proc create-display {} {
    global g w opts tmpopts tk_version
    debug-info "create-display ()"

    # these are the four major areas of the GUI:
    # menubar - the menubar (duh)
    # toolbar - the toolbar (duh, again)
    # client  - the area with the text widgets and the graphical map
    # status us         - a bottom status line

    # this block of destroys is MOSTLY for stand-alone testing of the GUI code,
    # and could be blown away (except for .status), or not, if we want to
    # be able to call this routine to recreate the display...
    catch {
        destroy $w(tw).status ;# Keep this as first (it MIGHT exist when others dont)
        destroy $w(tw).menubar
        destroy $w(tw).toolbar
        destroy $w(tw).client
        destroy $w(tw).map
        destroy $w(tw).merge
    }

    # 'identify' the top level frames/windows and store them in a global array
    set w(client)    $w(tw).client
    set w(menubar)   $w(tw).menubar
    set w(toolbar)   $w(tw).toolbar
    set w(status)    $w(tw).status
    set w(popupMenu) $w(tw).popupMenu
    set w(merge)     $w(tw).merge

    # 'identify' other windows that possibly MAY exist later...
    set w(preferences) $w(tw).pref
    set w(findDialog)  $w(tw).findDialog
    set w(scDialog)    $w(tw).scDialog

    # now, simply build all the REQUIRED pieces
    build-menubar
    build-toolbar
    build-client
    build-status
    build-popupMenu
    build-merge-preview

    frame $w(tw).separator1 -height 2 -borderwidth 2 -relief groove
    frame $w(tw).separator2 -height 2 -borderwidth 2 -relief groove

    # ... and fit it all together...
    $w(tw) configure -menu $w(menubar)
    pack $w(toolbar) -side top -fill x -expand n
    pack $w(tw).separator1 -side top -fill x -expand n

    pack $w(client) -side top -fill both -expand y
    pack $w(tw).separator2 -side top -fill x -expand n

    pack $w(status) -side bottom -fill x -expand n

    # apply user preferences by calling the proc that gets
    # called when the user presses "Apply" from the preferences
    # window. That proc uses a global variable named "tmpopts"
    # which should have the values from the dialog. Since we
    # aren't using the dialog, we need to populate this array
    # manually
    foreach key [array names opts] {
        set ::tmpopts($key) $opts($key)
    }
    applypref

    # Make sure temporary files get deleted
    #bind . <Destroy> {del-tmp}

    # Create static list of Text widget actions that, when configure'ing,
    # will NOT alter the display height of any text line (a plot speedup)
    set g(benign) { mark bbox cget compare count debug dlineinfo \
                    dump get index peer search }
    # Then arrange for line numbers to be redrawn when just about anything
    # happens to EITHER text widget programatically.
    #      This runs much faster than you might think.
    trace add execution $w(LeftText)  leave [list plot-line-info Left]
    trace add execution $w(RightText) leave [list plot-line-info Right]
    trace add execution $w(mergeText) leave [list plot-merge-info]
    bind $w(LeftText)  <Configure> [list plot-line-info Left]
    bind $w(RightText) <Configure> [list plot-line-info Right]
    bind $w(mergeText) <Configure> [list plot-merge-info]

    # Lastly, all wheel scrolling over the Info windows SHOULD work
    #   (even though they themselves dont ACTUALLY scroll - they repaint)
    # 'eval' simply eliminates vars from within the quoted bind-scripts
    #   (???- found no way to just FORWARD the event to the Text widget)
    foreach side {Left Right merge} {
        foreach evt {Button-4 Button-5 Shift-Button-4 Shift-Button-5} {
            eval bind $w(${side}Info) <$evt> \
               "{event generate $w(${side}Text) <$evt> -when head}"
        }
        foreach evt {MouseWheel Shift-MouseWheel} {
            eval bind $w(${side}Info) <$evt> \
               "{event generate $w(${side}Text) <$evt> -delta %D -when head}"
        }
    }

    # other misc. bindings
    common-navigation $w(LeftText) $w(RightText) $w(LeftInfo) $w(RightInfo)

    # normally, keyboard traversal using tab and shift-tab isn't
    # enabled for text widgets, since the default binding for these
    # keys is to actually insert the tab character. Because all of
    # our text widgets are for display only, let's redefine the
    # default binding so the global <Tab> and <Shift-Tab> bindings
    # are used.
    bind Text <Tab> {continue}
    bind Text <Shift-Tab> {continue}

    # if the user toggles scrollbar syncing, we want to make sure
    # they sync up immediately
    trace variable opts(syncscroll) w toggleSyncScroll
    # OPA >>>
    # wm deiconify .
    # OPA <<<
    focus -force $w(RightText)
    update idletasks
    # Need this to make the pane-resizing behave
    grid propagate $w(client) f
}

###############################################################################
# when the user changes the "sync scrollbars" option, we want to
# sync up the left scrollbar with the right if they turn the option on
###############################################################################
proc toggleSyncScroll {args} {
    global w opts

    if {$opts(syncscroll) == 1} {
        set yview [$w(RightText) yview]
        vscroll-sync 2 [lindex $yview 0] [lindex $yview 1]
    }
}

###############################################################################
# show the popup menu, reconfiguring some entries based on where user clicked
#  (notably - over the MAP window becomes somewhat Left/Right ambiguous)
###############################################################################
proc show-popupMenu {x y} {
    global g w

    set window [winfo containing $x $y]
    if {$window == $w(LeftText)  || $window == $w(LeftInfo)  \
    ||  $window == $w(RightText) || $window == $w(RightInfo)} {

        # Turn these back ON (as they MAY have been turned off below)
        if {$g(count)} {
            $w(popupMenu) entryconfigure "Find Nearest*" -state normal }
        $w(popupMenu) entryconfigure "Edit*" -state normal

        # Ensure g(activeWindow) is correct for use by above two entries
        if {$window == $w(LeftText) || $window == $w(LeftInfo)} {
            $w(popupMenu) configure -title "File 1" ;# why, when NOT a tearoff?
            set g(activeWindow) $w(LeftText)
        } else {
            $w(popupMenu) configure -title "File 2" ;# why, when NOT a tearoff?
            set g(activeWindow) $w(RightText)
        }

    } else {
        # Turn these OFF in case we are NOT over the Text (or its Info) window
        #   (no way to know which SIDE they should apply to)
        $w(popupMenu) entryconfigure "Find Nearest*" -state disabled
        $w(popupMenu) entryconfigure "Edit*" -state disabled
    }

    # Only allow clipboard copy if the primary selection is ours to begin with
    # AND is still PRESENTLY selected (as opposed to being FORMERLY selected)
    if {[selection own] == "$window" && ![catch "$window index sel.first"]} {
        set selstatus "normal"} {set selstatus "disabled"}
    $w(popupMenu) entryconfigure "Copy Selection" -state $selstatus

    tk_popup $w(popupMenu) $x $y
}

###############################################################################
# build the right-click popup menu
###############################################################################
proc build-popupMenu {} {
    global g w
    # OPA >>>
    global opts
    # OPA <<<
    debug-info "build-popupMenu ()"

    # this routine assumes the other windows already exist...
    menu $w(popupMenu)
    foreach win [list LeftText RightText RightInfo LeftInfo mapCanvas] {
        # OPA >>>
        bind $w($win) <<RightButtonPress>> {show-popupMenu %X %Y}
        bind $w($win) <Escape> { StopDiff 1 }
        # OPA <<<
    }

    set m $w(popupMenu)
    $m add command -label "First Diff" -underline 0 -command [list popupMenu \
      first] -accelerator "f"
    $m add command -label "Previous Diff" -underline 0 -command \
      [list popupMenu previous] -accelerator "p"
    $m add command -label "Center Current Diff" -underline 0 -command \
      [list popupMenu center] -accelerator "c"
    $m add command -label "Next Diff" -underline 0 -command [list popupMenu \
      next] -accelerator "n"
    $m add command -label "Last Diff" -underline 0 -command [list popupMenu \
      last] -accelerator "l"
    $m add separator
    $m add command -label "Find Nearest Diff" -underline 0 -command \
      [list popupMenu nearest] -accelerator "Double-Click"
    $m add separator
    $m add command -label "Find..." -underline 0 -command [list popupMenu find]
    $m add command -label "Edit" -underline 0 -command [list popupMenu edit]
    $m add separator
    $m add command -label "Copy Selection" -underline 5 -command [list do-copy]
    # OPA >>>
    # Add separator + Save as left + Save as right.
    if {$opts(showcontextsave)} {
        $m add separator
        $m add command -label "Save as left" -underline 8 \
                -command write-as-left
        $m add command -label "Save as right" -underline 8 \
                -command write-as-right
    }
    # OPA <<<
}

###############################################################################
# Load a different file of a multi-file diff
###############################################################################
proc multiFileMenu {command index} {
    global w opts finfo
    debug-info "multiFileMenu ($command $index) -> $finfo(fCurpair)"

    if {$finfo(fPairs) <= 1} {return}

    set OK 1
    switch -- $command {
    prev {
        if {$finfo(fCurpair) > 1} {
            incr finfo(fCurpair) -1
        } else {set OK 0}
    }
    next {
        if {$finfo(fCurpair) < $finfo(fPairs)} {
            incr finfo(fCurpair)
        } else {set OK 0}
    }
    jump {
        set finfo(fCurpair) $index
    }
    }

    if {$OK} {
        set g(startPhase) 1
        do-diff
    }
}

###############################################################################
# handle popup menu commands
###############################################################################
proc popupMenu {command args} {
    global g w
    debug-info "popupMenu ($command $args)"

    switch -- $command {
    center {
            center
        }
    edit {
            do-edit
        }
    find {
            do-find
        }
    first {
            move first
        }
    last {
            move last
        }
    next {
            move 1
        }
    previous {
            move -1
        }
    nearest {
            moveNearest $g(activeWindow) xy [winfo pointerx $g(activeWindow)] \
              [winfo pointery $g(activeWindow)]
        }
    }
}

# Resize the text windows relative to each other.  The 8.4 method works
# much better.
proc pane_drag {win x} {
    global w finfo tk_version

    set relX [expr $x - [winfo rootx $win]]
    set maxX [winfo width $win]
    set frac [expr int((double($relX) / $maxX) * 100)]
    if {$tk_version < 8.4} {
      if {$frac < 15} { set frac 15 }
      if {$frac > 85} { set frac 85 }
      #debug-info "frac $frac"
      set L $frac
      set R [expr 100 - $frac]
      $w(tw).client.leftlabel configure -width [expr $L * 2]
      $w(tw).client.rightlabel configure -width [expr $R * 2]
    } else {
      if {$frac < 5} { set frac 5 }
      if {$frac > 95} { set frac 95 }
      #debug-info "frac $frac"
      set L $frac
      set R [expr 100 - $frac]
      grid columnconfigure $win 0 -weight $L
      grid columnconfigure $win 2 -weight $R
    }
    #debug-info " new: $L $R"
}

###############################################################################
# build the main client display (the text widgets, scrollbars, that
# sort of fluff)
###############################################################################
proc build-client {} {
    global g w opts map tk_version
    debug-info "build-client ()"

    frame $w(client) -bd 2 -relief flat

    # set up global variables to reference the widgets, so
    # we don't have to use hardcoded widget paths elsewhere
    # in the code
    #
    # Text  - holds the text of the file
    # Info  - holds meta-data ABOUT 'Text': LineNums, Changebars, etc
    # VSB   - vertical scrollbar
    # HSB   - horizontal scrollbar
    # Label - label to hold the name of the file
    set w(LeftText) $w(client).left.text
    set w(LeftInfo) $w(client).left.info
    set w(LeftVSB) $w(client).left.vsb
    set w(LeftHSB) $w(client).left.hsb
    set w(LeftLabel) $w(client).leftlabel

    set w(AncfLabel) $w(client).ancFile

    set w(RightText) $w(client).right.text
    set w(RightInfo) $w(client).right.info
    set w(RightVSB) $w(client).right.vsb
    set w(RightHSB) $w(client).right.hsb
    set w(RightLabel) $w(client).rightlabel

    set w(BottomText) $w(client).bottomtext

    set w(map) $w(client).map
    set w(mapCanvas) $w(map).canvas

    # these don't need to be global...
    set leftFrame $w(client).left
    set rightFrame $w(client).right

    # we'll create each widget twice; once for the left side
    # and once for the right, but first the Labels.
    debug-info " Assigning labels to headers"
    scan $opts(geometry) "%dx%d" width height
    label $w(LeftLabel)  -bd 1 -relief flat -width $width \
                               -textvariable finfo(lbl,Left)
    label $w(RightLabel) -bd 1 -relief flat -width $width \
                               -textvariable finfo(lbl,Right)

    # Might need this for a 3way diff (see 'alignDecor' for details)
    button $w(AncfLabel) -bd 0 -image ancfImg -command {
      simpleEd open $finfo(pth,0) title "$finfo(lbl,0) - Ancestor" \
        ro fg [$w(mergeText) cget -fg] bg [$w(mergeText) cget -bg] }

    # These hold the text widgets and the scrollbars. The reason
    # for the frame is purely for aesthetics. It just looks
    # nicer, IMHO, to "embed" the scrollbars within the text widget

    frame $leftFrame  -bd 1 -relief sunken
    frame $rightFrame -bd 1 -relief sunken

    scrollbar $w(LeftHSB) -borderwidth 1 -orient horizontal -command \
      [list $w(LeftText) xview]

    scrollbar $w(RightHSB) -borderwidth 1 -orient horizontal -command \
      [list $w(RightText) xview]

    scrollbar $w(LeftVSB) -borderwidth 1 -orient vertical -command \
      [list $w(LeftText) yview]

    scrollbar $w(RightVSB) -borderwidth 1 -orient vertical -command \
      [list $w(RightText) yview]

    text $w(LeftText) -padx 0 -wrap none -width $width -height $height \
      -borderwidth 0 -setgrid 1 -yscrollcommand [list vscroll-sync 1] \
      -xscrollcommand [list hscroll-sync 1]

    text $w(RightText) -padx 0 -wrap none -width $width -height $height \
      -borderwidth 0 -setgrid 1 -yscrollcommand [list vscroll-sync 2] \
      -xscrollcommand [list hscroll-sync 2]

    # Technically, we lack the data to configure this properly until both
    # primary files have been loaded into the above text widgets. But we
    # need them right NOW for constructing the overall window layout.
    # Remaining options happen later via "applypref" and "cfg-line-info"
    canvas $w(LeftInfo)  -highlightthickness 0
    canvas $w(RightInfo) -highlightthickness 0

    # this widget is the two line display showing the current line, so
    # one can compare character by character if necessary.
    text $w(BottomText) -wrap none -borderwidth 1 -height 2 -width 0

    # this is how we highlight bytes that are different...
    # the bottom window (lineview) uses reverse video to highlight
    # diffs, so we need to figure out what reverse video is, and
    # define the tag appropriately
    $w(BottomText) tag configure diff {*}$opts(bytetag)

    # Set up text tags for the 'current diff' (the one chosen by the 'next'
    # and 'prev' buttons) .vs. any ol' diff region.  All diff regions are
    # given the 'diff' tag initially...
    #   As 'next' and 'prev' are  pressed, to scroll through the differences,
    # one particular diff region is always chosen as the 'current diff', and
    # is set off from the others via the 'curr' tag -- in particular, so that
    # it's obvious which diffs in the left and right-hand text widgets match.

    foreach widget [list $w(LeftText) $w(RightText)] {
        $widget configure {*}$opts(textopt)
        foreach t {diff curr del ins chg overlap inline} {
            $widget tag configure ${t}tag {*}$opts(${t}tag)
        }
        $widget tag raise sel ;# Keep this on top
    }

    # build the map...
    # we want the map to be the same width as a scrollbar, so we'll
    # steal some information from one of the scrollbars we just
    # created...
    set cwidth [winfo reqwidth $w(LeftVSB)]
    set ht [$w(LeftVSB) cget -highlightthickness]
    set cwidth [expr {$cwidth -($ht*2)}]
    set color [$w(LeftVSB) cget -troughcolor]

    set map [frame $w(client).map -bd 1 -relief sunken -takefocus 0 \
      -highlightthickness 0]

    # now for the real map...
    image create photo map

    canvas $w(mapCanvas) -width [expr {$cwidth + 1}] \
      -yscrollcommand map-resize -background $color -borderwidth 0 \
      -relief sunken -highlightthickness 0
    $w(mapCanvas) create image 1 1 -image map -anchor nw
    pack $w(mapCanvas) -side top -fill both -expand y

    # I'm not too pleased with these bindings -- it results in a rather
    # jerky, cpu-intensive maneuver since with each move of the mouse
    # we are finding and tagging the nearest diff. But, what *should*
    # it do?
    #
    # I think what I *want* it to do is update the combobox and status
    # bar so the user can see where in the scheme of things they are,
    # but not actually select anything until they release the mouse.
    bind $w(mapCanvas) <ButtonPress-1> [list handleMapEvent B1-Press %y]
    bind $w(mapCanvas) <Button1-Motion> [list handleMapEvent B1-Motion %y]
    bind $w(mapCanvas) <ButtonRelease-1> [list handleMapEvent B1-Release %y]
    bind $w(mapCanvas) <ButtonPress-2> [list handleMapEvent B2-Press %y]
    bind $w(mapCanvas) <ButtonRelease-2> [list handleMapEvent B2-Release %y]

    # Again, wheel scrolling over the MAP window SHOULD also work
    # - but can only target the THEN g(activeWindow) text widget
    foreach evt {Button-4 Button-5 Shift-Button-4 Shift-Button-5} {
        eval bind $w(mapCanvas) <$evt> \
           "{event generate \$g(activeWindow) <$evt> -when head}"
    }
    foreach evt {MouseWheel Shift-MouseWheel} {
        eval bind $w(mapCanvas) <$evt> \
           "{event generate \$g(activeWindow) <$evt> -delta %D -when head}"
    }

    # this is a grip for resizing the sides relative to each other.
    button $w(client).grip -borderwidth 3 -relief raised \
      -cursor sb_h_double_arrow -image resize
    bind $w(client).grip <B1-Motion> {pane_drag $w(client) %X}

    # use grid to manage the widgets in the left side frame
    grid $w(LeftVSB) -row 0 -column 0 -sticky ns
    grid $w(LeftInfo) -row 0 -column 1 -sticky nsew
    grid $w(LeftText) -row 0 -column 2 -sticky nsew
    grid $w(LeftHSB) -row 1 -column 1 -sticky ew -columnspan 2

    grid rowconfigure $leftFrame 0 -weight 1
    grid rowconfigure $leftFrame 1 -weight 0

    grid columnconfigure $leftFrame 0 -weight 0
    grid columnconfigure $leftFrame 1 -weight 0
    grid columnconfigure $leftFrame 2 -weight 1

    # likewise for the right...
    grid $w(RightVSB) -row 0 -column 4 -sticky ns
    grid $w(RightInfo) -row 0 -column 0 -sticky nsew
    grid $w(RightText) -row 0 -column 1 -sticky nsew
    grid $w(RightHSB) -row 1 -column 0 -sticky ew -columnspan 2

    grid rowconfigure $rightFrame 0 -weight 1
    grid rowconfigure $rightFrame 1 -weight 0

    grid columnconfigure $rightFrame 0 -weight 0
    grid columnconfigure $rightFrame 1 -weight 1

    # use grid to manage the labels, frames and map. We're going to
    # toss in an extra row just for the benefit of our dummy frame.
    # the intent is that the dummy frame will match the height of
    # the horizontal scrollbars so the map stops at the right place...
    grid $w(LeftLabel) -row 0 -column 0 -sticky ew
    grid $w(RightLabel) -row 0 -column 2 -sticky ew
    grid $leftFrame -row 1 -column 0 -sticky nsew -rowspan 2
    grid $map -row 1 -column 1 -stick ns
    grid $w(client).grip -row 2 -column 1
    grid $rightFrame -row 1 -column 2 -sticky nsew -rowspan 2

    grid rowconfigure $w(client) 0 -weight 0
    grid rowconfigure $w(client) 1 -weight 1
    grid rowconfigure $w(client) 2 -weight 0
    grid rowconfigure $w(client) 3 -weight 0

    if {$tk_version < 8.4} {
      grid columnconfigure $w(client) 0 -weight 1
      grid columnconfigure $w(client) 2 -weight 1
    } else {
      grid columnconfigure $w(client) 0 -weight 100 -uniform a
      grid columnconfigure $w(client) 2 -weight 100 -uniform a
    }
    grid columnconfigure $w(client) 1 -weight 0

    # this adjusts the variable g(activeWindow) to be whatever text
    # widget has the focus...
    bind $w(LeftText) <1> {set g(activeWindow) $w(LeftText)}
    bind $w(RightText) <1> {set g(activeWindow) $w(RightText)}

    set g(activeWindow) $w(LeftText) ;# establish a default

    rename $w(RightText) $w(RightText)_
    rename $w(LeftText) $w(LeftText)_

    proc $w(RightText) {command args} $::text_widget_proc
    proc $w(LeftText) {command args} $::text_widget_proc
}

###############################################################################
# Perform inline data re-computation and/or re-tagging across ALL hunks
###############################################################################
proc compute-inlines {optNam {retag 0}} {
    global g w
    debug-info "compute-inlines ($optNam $retag)"

    # Translate from TkDiff optionName to algorithm style name
    set style(showinline1) "byte"
    set style(showinline2) "ratcliff"

    # Optionally remove ALL inline tags/data (so new ones MAY be added)
    # N.B. If neither arg is TRUE, then CALLER must do "array unset ..."
    if {$retag || $optNam == {}} {
        $w(LeftText)  tag remove inlinetag 1.0 end
        $w(RightText) tag remove inlinetag 1.0 end
        array unset g "inline,*"
        set retag true ;# ensure UNtagged are RE-evaluated by "de-skew-hunk"
    }

    # Compute inline data per requested algorithm style
    #   PRIOR data (inline,*) is expected to be deleted BEFORE invocation
    foreach hID $g(diff) {
        # Remember: only chg-type hunks can EVER have inline diffs
        if {[string match "*c*" "$hID"]} {
            if {$optNam != {}} {
                lassign $g(scrInf,$hID) Ls Le P(1) na na P(2)

                # Determine last UN-padded Lnum, then process L/R line pairs
                set first $Ls
                set last [expr {$P(1) ? $Le-$P(1) : $Le-$P(2)}]
                while {$Ls <= $last} {
                    set s1 "[$w(LeftText)  get $Ls.0 $Ls.end]"
                    set s2 "[$w(RightText) get $Ls.0 $Ls.end]"

                    find-inline-diff-$style($optNam) $hID \
                                             [expr {$Ls - $first}] "$s1" "$s2"
                    incr Ls ;# increment line number and iterate
                }

                # Put these tags back in place
                if {$retag} {remark-inline $hID}
            } elseif {$retag} {de-skew-hunk $hID}
        }
    }
}

###############################################################################
# Functionality: Inline diffs
# Athr: Michael D. Beynon : mdb - beynon@yahoo.com
# Date: 04/08/2003 : mdb - Added inline character diffs.
#       04/16/2003 : mdb - Rewrote longest-common-substring to be faster.
#                        - Added byte-by-byte algorithm.
#       08Oct2017  : mpm - Simplified byte-by-byte alg.
#                        - Revised generated output data format (both alg.)
#       12Jun2018  : mpm - Rewrote lcs-string (again) to be even faster.
#
# the recursive version is derived from the Ratcliff/Obershelp pattern
# recognition algorithm (Dr Dobbs July 1988), where we search for a
# longest common substring between two strings.  This match is used as
# an archor, around which we recursively do the same for the two left
# and two right remaining pieces (omitting the anchor).  This
# precisely determines the location of the intraline tags.
#################################################################################
proc lcs-string {s1 off1 len1 s2 off2 len2 lcsoff1_ref lcsoff2_ref} {
    upvar $lcsoff1_ref lcsoff1
    upvar $lcsoff2_ref lcsoff2
    set snippet ""

    set snippetlen 0
    set longestlen 0

    # extract just the search regions for efficiency in string searching
    set s1 [string range $s1 $off1 [expr $off1+$len1-1]]
    set s2 [string range $s2 $off2 [expr $off2+$len2-1]]

    set snpBgn 0

    for {set tmpoff -1} {$snippetlen < $len2-$snpBgn} {incr snpBgn} {
        # increase size of matching snippet
        while {$snippetlen < $len2-$snpBgn} {
            set tmp "$snippet[string index $s2 [expr $snpBgn+$snippetlen]]"
            if {[set i [string first $tmp $s1]] == -1} {
                break
            }
            set tmpoff $i
            set snippet $tmp
            incr snippetlen
        }
        if {$snippetlen > 0} {
            # new longest?
            if {$tmpoff != -1 && $snippetlen > $longestlen} {
                set longestlen $snippetlen
                set lcsoff1 [expr $off1+$tmpoff]
                set lcsoff2 [expr $off2+$snpBgn]
            }
            # drop 1st char of prefix, but keep size the same as longest
            if {$snippetlen < $len2-$snpBgn} {
                set snippet "[string range $snippet 1 end][string index $s2 \
                                                  [expr $snpBgn+$snippetlen]]"
            }
        }
    }
    return $longestlen
}

proc fid-ratcliff-aux {hID pairID s1 off1 len1 s2 off2 len2} {
    global g

    if {$len1 <= 0 || $len2 <= 0} {
        if {$len1 == 0} {
            lappend g(inline,$hID)  r $pairID $off2 [expr $off2+$len2]
        } elseif {$len2 == 0} {
            lappend g(inline,$hID)  l $pairID $off1 [expr $off1+$len1]
        }
        return 0
    }
    set cnt 0
    set lcsoff1 -1
    set lcsoff2 -1

    # Non-obvious speedup: Best if argsets passed in (longer, shorter) order
    #      (operation is commutative and performs fewer internal iterations)
    if {$len2 < $len1} {
        set ret [lcs-string $s1 $off1 $len1 $s2 $off2 $len2 lcsoff1 lcsoff2]
    } else {
        set ret [lcs-string $s2 $off2 $len2 $s1 $off1 $len1 lcsoff2 lcsoff1]
    }

    if {$ret > 0} {
        set rightoff1 [expr $lcsoff1+$ret]
        set rightoff2 [expr $lcsoff2+$ret]

        incr cnt [expr 2*$ret]
        if {$lcsoff1 > $off1 || $lcsoff2 > $off2} {
            # left
            incr cnt [fid-ratcliff-aux $hID $pairID \
                        $s1 $off1 [expr $lcsoff1-$off1] \
                        $s2 $off2 [expr $lcsoff2-$off2]]

        }
        if {$rightoff1<$off1+$len1 || $rightoff2<$off2+$len2} {
            # right
            incr cnt [fid-ratcliff-aux $hID $pairID \
                        $s1 $rightoff1 [expr $off1+$len1-$rightoff1] \
                        $s2 $rightoff2 [expr $off2+$len2-$rightoff2]]
        }
    } else {
        lappend g(inline,$hID)  r $pairID $off2 [expr $off2+$len2]
        lappend g(inline,$hID)  l $pairID $off1 [expr $off1+$len1]
        incr cnt
    }
    return $cnt
}

proc find-inline-diff-ratcliff {hID pairID s1 s2} {
    global g

    if {![set len1 [string length $s1]] || ![set len2 [string length $s2]] } {
        return 0
    }
    return [fid-ratcliff-aux $hID $pairID $s1 0 $len1 $s2 0 $len2]
}

proc find-inline-diff-byte {hID pairID s1 s2} {
    global g

    if {![set len1 [string length $s1]] || ![set len2 [string length $s2]] } {
        return 0
    }

    set lenmin [min $len1 $len2]
    set cnt 0
    set size 0
    for {set i 0} {$i <= $lenmin} {incr i} {
        if {[string index $s1 $i] == [string index $s2 $i]} {
            # start/continue a NON-diff region
            if {$size} {
                # which ENDS a diff region
                lappend g(inline,$hID)  r $pairID [expr $i-$size] $i
                lappend g(inline,$hID)  l $pairID [expr $i-$size] $i
                set size 0
                incr cnt
            }
        } else { incr size }
    }
    if {$size} {
        # ended in a diff region
        lappend g(inline,$hID)  r $pairID [expr $i-$size] $len2
        lappend g(inline,$hID)  l $pairID [expr $i-$size] $len1
        incr cnt
    }
    return $cnt
}

###############################################################################
# the following code is used as the replacement body for the left and
# right widget procs. The purpose is to catch when the insertion point
# changes so we can update the line comparison window
###############################################################################

set text_widget_proc {
    global w

    set real "[lindex [info level [info level]] 0]_"
    set result [eval $real $command $args]
    if {$command == "mark"} {
        if {[lindex $args 0] == "set" && [lindex $args 1] == "insert"} {
            set i [lindex $args 2]
            set i0 "$i linestart"
            set i1 "$i lineend"
            set left [$w(LeftText)_ get $i0 $i1]
            set right [$w(RightText)_ get $i0 $i1]
            $w(BottomText) delete 1.0 end
            $w(BottomText) insert end "< $left\n> $right"
            # find characters that are different, and underline them
            if {$left != $right} {
                set left [split $left {}]
                set right [split $right {}]
                # n.b. we set c to an offset equal to whatever we have
                # prepended to the data...
                set c 2
                foreach l $left r $right {
                    if {[string compare $l $r] != 0} {
                        $w(BottomText) tag add diff 1.$c "1.$c+1c"
                        $w(BottomText) tag add diff 2.$c "2.$c+1c"
                    }
                    incr c
                }
                $w(BottomText) tag remove diff "1.0 lineend"
                $w(BottomText) tag remove diff "2.0 lineend"
            }
        }
    }
    return $result
}

###############################################################################
# create (if necessary) and show the find dialog
###############################################################################
proc show-find {} {
    global g w tcl_platform
    debug-info "show-find ()"

    if {![winfo exists $w(findDialog)]} {
        toplevel $w(findDialog)
        wm group $w(findDialog) $w(tw)
        wm transient $w(findDialog) $w(tw)
        wm title $w(findDialog) "$g(name) Find"

        if {$g(windowingSystem) == "aqua"} {
            setAquaDialogStyle $w(findDialog)
        }

        # we don't want the window to be deleted, just hidden from view
        wm protocol $w(findDialog) WM_DELETE_WINDOW [list wm withdraw \
          $w(findDialog)]

        wm withdraw $w(findDialog)
        update idletasks

        frame $w(findDialog).content -bd 2 -relief groove
        pack $w(findDialog).content -side top -fill both -expand y -padx 0 \
          -pady 5

        frame $w(findDialog).buttons
        pack $w(findDialog).buttons -side bottom -fill x -expand n

        button $w(findDialog).buttons.doit -text "Find Next" -command do-find
        button $w(findDialog).buttons.dismiss -text "Dismiss" -command \
          "wm withdraw $w(findDialog)"
        pack $w(findDialog).buttons.dismiss -side right -pady 5 -padx 0
        pack $w(findDialog).buttons.doit -side right -pady 5 -padx 1

        set ff $w(findDialog).content.findFrame
        frame $ff -height 100 -bd 2 -relief flat
        pack $ff -side top -fill x -expand n -padx 0 -pady 5

        label $ff.label -text "Find what:" -underline 2

        entry $ff.entry -textvariable g(findString)

        checkbutton $ff.searchCase -text "Ignore Case" -offvalue 0 -onvalue 1 \
          -indicatoron true -variable g(findIgnoreCase)

        grid $ff.label -row 0 -column 0 -sticky e
        grid $ff.entry -row 0 -column 1 -sticky ew
        grid $ff.searchCase -row 0 -column 2 -sticky w
        grid columnconfigure $ff 0 -weight 0
        grid columnconfigure $ff 1 -weight 1
        grid columnconfigure $ff 2 -weight 0

        # we need this in other places...
        set w(findEntry) $ff.entry

        bind $ff.entry <Return> do-find

        set of $w(findDialog).content.optionsFrame
        frame $of -bd 2 -relief flat
        pack $of -side top -fill y -expand y -padx 10 -pady 10

        label $of.directionLabel -text "Search Direction:" -anchor e
        radiobutton $of.directionForward -indicatoron true -text "Down" \
          -value "-forward" -variable g(findDirection)
        radiobutton $of.directionBackward -text "Up" -value "-backward" \
          -indicatoron true -variable g(findDirection)


        label $of.windowLabel -text "Window:" -anchor e
        radiobutton $of.windowLeft -indicatoron true -text "Left" \
          -value $w(LeftText) -variable g(activeWindow)
        radiobutton $of.windowRight -indicatoron true -text "Right" \
          -value $w(RightText) -variable g(activeWindow)


        label $of.searchLabel -text "Search Type:" -anchor e
        radiobutton $of.searchExact -indicatoron true -text "Exact" \
          -value "-exact" -variable g(findType)
        radiobutton $of.searchRegexp -text "Regexp" -value "-regexp" \
          -indicatoron true -variable g(findType)

        grid $of.directionLabel -row 1 -column 0 -sticky w
        grid $of.directionForward -row 1 -column 1 -sticky w
        grid $of.directionBackward -row 1 -column 2 -sticky w

        grid $of.windowLabel -row 0 -column 0 -sticky w
        grid $of.windowLeft -row 0 -column 1 -sticky w
        grid $of.windowRight -row 0 -column 2 -sticky w

        grid $of.searchLabel -row 2 -column 0 -sticky w
        grid $of.searchExact -row 2 -column 1 -sticky w
        grid $of.searchRegexp -row 2 -column 2 -sticky w

        grid columnconfigure $of 0 -weight 0
        grid columnconfigure $of 1 -weight 0
        grid columnconfigure $of 2 -weight 1

        set g(findDirection) "-forward"
        set g(findType) "-exact"
        set g(findIgnoreCase) 1
        set g(lastSearch) ""
        if {$g(activeWindow) == ""} {
            set g(activeWindow) [focus]
            if {$g(activeWindow) != $w(LeftText) && $g(activeWindow) != \
              $w(RightText)} {
                set g(activeWindow) $w(LeftText)
            }
        }
    }

    # OPA >>>
    set win $g(activeWindow)
    if { $win eq "" } {
        set win $w(LeftText)
    }
    set g(findString) ""
    if { ! [catch { set data [$win get sel.first sel.last] } ] } {
        set g(findString) $data
    }
    # OPA <<<

    centerWindow $w(findDialog)
    wm deiconify $w(findDialog)
    raise $w(findDialog)
    after idle focus $w(findEntry)
}


###############################################################################
# do the "Edit->Copy" functionality, by copying the current selection
# to the clipboard
###############################################################################
proc do-copy {} {
    clipboard clear -displayof .
    # figure out which window has the selection...
    catch {
        clipboard append [selection get -displayof .]
    }
}

###############################################################################
# search for the text in the find dialog
###############################################################################
proc do-find {} {
    global g w
    debug-info "do-find ()"

    if {![winfo exists $w(findDialog)] || ![winfo ismapped $w(findDialog)]} {
        show-find
        return
    }

    set win $g(activeWindow)
    if {$win == ""} {
        set win $w(LeftText)
    }
    if {$g(lastSearch) != ""} {
        if {$g(findDirection) == "-forward"} {
            set start [$win index "insert +1c"]
        } else {
            set start insert
        }
    } else {
        set start 1.0
    }

    if {$g(findIgnoreCase)} {
        set result [$win search $g(findDirection) $g(findType) -nocase \
          -- $g(findString) $start]
    } else {
        set result [$win search $g(findDirection) $g(findType) \
          -- $g(findString) $start]
    }
    if {[string length $result] > 0} {
        # if this is a regular expression search, get the whole line and try
        # to figure out exactly what matched; otherwise we know we must
        # have matched the whole string...
        if {$g(findType) == "-regexp"} {
            set line [$win get $result "$result lineend"]
            regexp $g(findString) $line matchVar
            set length [string length $matchVar]
        } else {
            set length [string length $g(findString)]
        }
        set g(lastSearch) $result
        $win mark set insert $result
        $win tag remove sel 1.0 end
        $win tag add sel $result "$result + ${length}c"
        $win see $result
        focus $win
        # should I somehow snap to the nearest diff? Probably not...
    } else {
        bell

    }
}

###############################################################################
# Build the menu bar
###############################################################################
proc build-menubar {} {
    global g w opts finfo
    debug-info "build-menubar ()"

    menu $w(menubar)

    # these are just local shorthand ...
    set fileMenu $w(menubar).file
    set multiFileMenu $fileMenu.multi
    set viewMenu $w(menubar).view
    set helpMenu $w(menubar).help
    set editMenu $w(menubar).edit
    set mergeMenu $w(menubar).window
    set markMenu $w(menubar).marks

    $w(menubar) add cascade -label "File" -menu $fileMenu -underline 0
    $w(menubar) add cascade -label "Edit" -menu $editMenu -underline 0
    $w(menubar) add cascade -label "View" -menu $viewMenu -underline 0
    $w(menubar) add cascade -label "Mark" -menu $markMenu -underline 3
    $w(menubar) add cascade -label "Merge" -menu $mergeMenu -underline 0
    $w(menubar) add cascade -label "Help" -menu $helpMenu -underline 0

    # these, however, will be used in other places..
    set w(fileMenu) $fileMenu
    set w(multiFileMenu) $multiFileMenu
    set w(viewMenu) $viewMenu
    set w(helpMenu) $helpMenu
    set w(editMenu) $editMenu
    set w(mergeMenu) $mergeMenu
    set w(markMenu) $markMenu

    # Now, the menus...

    # Mark menu...
    menu $markMenu
    $markMenu add command -label "Mark Current Diff" -command [list diffmark \
      mark] -underline 0
    $markMenu add command -label "Clear Current Diff Mark" -command \
      [list diffmark clear] -underline 0

    set "g(tooltip,Mark Current Diff)" "Create a marker for the current\
      difference record"
    set "g(tooltip,Clear Current Diff Mark)" "Clear the marker for the\
      current difference record"

    # File menu...
    menu $fileMenu
    $fileMenu add command -label "New..." -underline 0 -command {do-new-diff}
    $fileMenu add cascade -label "File List" -state disabled\
            -menu $multiFileMenu -underline 5
    $fileMenu add command -label "Recompute Diffs" -underline 0 \
      -accelerator r -command recompute-diff
    $fileMenu add separator
    $fileMenu add command -label "Write Report..." -command \
      [list write-report popup] -underline 0
    $fileMenu add separator

    # OPA >>>
    $fileMenu add command -label "Close window" -underline 1 -accelerator "Ctrl+W" \
      -command tkdiff-CloseAppWindow
    $fileMenu add command -label "Quit" -underline 1 -accelerator "Ctrl+Q" \
      -command do-exit
    # OPA <<<

    # cascaded Multiple file list menu.
    menu $multiFileMenu -selectcolor {orange}
    $multiFileMenu add command -label "Previous File" -underline 1 \
        -accelerator "k" -command [list multiFileMenu prev 0]
    $multiFileMenu add command -label "Next File" -underline 1 \
        -accelerator "j" -command [list multiFileMenu next 0]
    $multiFileMenu add separator ;# this MUST be there to add further entries

    reload-multifile $finfo(fPairs) ;# finish with list of CURRENT files

    set "g(tooltip,New...)" "Pop up a dialog to select new input parameters\
      and compute a new Diff"
    set "g(tooltip,File List)" "Recompute by choosing another file among those\
      derived from the present input parameters"
    set "g(tooltip,Recompute Diffs)" "Recompute all difference records for the\
      current file"
    set "g(tooltip,Write Report...)" "Configure and produce a file depicting\
      information about the present Diff state"

    # Edit menu...
    # If you change, add or remove labels, be sure and update the tooltips.
    menu $editMenu
    $editMenu add command -label "Copy" -underline 0 -command do-copy
    $editMenu add separator
    $editMenu add command -label "Find..." -underline 0 -command show-find
    $editMenu add separator
    $editMenu add command -label "Split..."   -underline 0 \
      -command {splcmb-Dialog 0}
    $editMenu add command -label "Combine..." -underline 2 \
      -command {splcmb-Dialog 1}
    $editMenu add separator
    $editMenu add command -label "Edit File 1" -command {
        set g(activeWindow) $w(LeftText)
        do-edit
    } -underline 10
    $editMenu add command -label "Edit File 2" -command {
        set g(activeWindow) $w(RightText)
        do-edit
    } -underline 10
    $editMenu add separator
    $editMenu add command -label "Preferences..." -underline 0 \
      -command customize

    set "g(tooltip,Copy)" "Copy the currently selected text to the clipboard"
    set "g(tooltip,Find...)" \
        "Pop up a dialog to search for a string within either file"
    set "g(tooltip,Split...)" "Pop up a dialog\
                                to Split the current diff at specified bounds"
    set "g(tooltip,Combine...)" "Pop up a dialog\
                 to Combine the current diff record with ADJACENT neighbor(s)"
    set "g(tooltip,Edit File 1)" \
        "Launch an editor on the file on the left side of the window"
    set "g(tooltip,Edit File 2)"  \
        "Launch an editor on the file on the right side of the window"
    set "g(tooltip,Preferences...)" "Pop up a window to customize $g(name)"

    # View menu...  If you change, add or remove labels, be sure and
    # update the tooltips.
    menu $viewMenu
    $viewMenu add checkbutton -label "Ignore White Spaces" -underline 7 \
      -variable opts(ignoreblanks) \
      -command {do-semantic-recompute ignoreblanks}

    $viewMenu add checkbutton -label "Ignore Blank Lines" -underline 7 \
      -variable opts(ignoreEmptyLn) \
      -command {do-semantic-recompute ignoreEmptyLn}

    $viewMenu add checkbutton -label "Ignore RE-matched Lines" -underline 7 \
      -variable opts(ignoreRegexLn) \
      -command {do-semantic-recompute ignoreRegexLn}

    $viewMenu add separator

    $viewMenu add checkbutton -label "Show Line Numbers" -underline 12 \
      -variable opts(showln) \
      -command [list do-show-Info showln]

    $viewMenu add checkbutton -label "Show Change Bars" -underline 12 \
      -variable opts(showcbs) \
      -command [list do-show-Info showcbs]

    $viewMenu add checkbutton -label "Show Diff Map" -underline 5 \
      -variable opts(showmap) -command do-show-map

    $viewMenu add checkbutton -label "Show Line Comparison Window" \
      -underline 11 -variable opts(showlineview) \
      -command do-show-lineview

    $viewMenu add checkbutton -label "Show Inline Comparison (byte)" \
      -variable opts(showinline1) \
      -command {do-show-inline showinline1}

    $viewMenu add checkbutton -label "Show Inline Comparison (recursive)" \
      -variable opts(showinline2) \
      -command {do-show-inline showinline2}

    $viewMenu add separator

    $viewMenu add checkbutton -label "Synchronize Scrollbars" -underline 0 \
      -variable opts(syncscroll)
    $viewMenu add checkbutton -label "Auto Center" -underline 0 \
      -variable opts(autocenter) -command {if \
      {$opts(autocenter)} {center}}
    $viewMenu add checkbutton -label "Auto Select" -underline 1 \
      -variable opts(autoselect)

    $viewMenu add separator

    $viewMenu add command -label "First Diff" -underline 0 -command \
      {move first} -accelerator "F"
    $viewMenu add command -label "Previous Diff" -underline 0 -command {move \
      -1} -accelerator "P"
    $viewMenu add command -label "Center Current Diff" -underline 0 \
      -command {center} -accelerator "C"
    $viewMenu add command -label "Next Diff" -underline 0 -command {move 1} \
      -accelerator "N"
    $viewMenu add command -label "Last Diff" -underline 0 -command \
      {move last} -accelerator "L"

    set "g(tooltip,Show Change Bars)" "If set, show the changebar column for\
       each line of each file"
    set "g(tooltip,Show Line Numbers)" "If set, show line numbers beside each\
       line of each file"
    set "g(tooltip,Synchronize Scrollbars)" "If set, scrolling either window\
       will scroll both windows"
    set "g(tooltip,Diff Map)" "If set, display the graphical \"Difference\
      Map\" in the center of the display"
    set "g(tooltip,Show Line Comparison Window)" "If set, display the window\
       with byte-by-byte differences"
    set "g(tooltip,Show Inline Comparison (byte))" "If set, display inline\
      byte-by-byte differences"
    set "g(tooltip,Show Inline Comparison (recursive))" "If set, display\
      inline differences based on recursive matching regions"
    set "g(tooltip,Auto Select)" "If set, automatically selects the nearest\
       diff record while scrolling"
    set "g(tooltip,Auto Center)" "If set, moving to another diff record will\
       center the diff on the screen"
    set "g(tooltip,Center Current Diff)" "Center the display around the\
      current diff record"
    set "g(tooltip,First Diff)" "Go to the first difference"
    set "g(tooltip,Last Diff)" "Go to the last difference"
    set "g(tooltip,Previous Diff)" "Go to the diff record just prior to the\
       current diff record"
    set "g(tooltip,Next Diff)" "Go to the diff record just after the current\
       diff record"
    set "g(tooltip,Ignore White Spaces)" "If set, applys whitespace options\
       during the Diff"
    set "g(tooltip,Ignore Blank Lines)" "If set, suppress empty lines from\
       causing a Diff"
    set "g(tooltip,Ignore RE-matched Lines)" "If set, suppress Diffs from lines\
       matching Regular Expression(s)"

    # Merge menu. If you change, add or remove labels, be sure and
    # update the tooltips.
    menu $mergeMenu
    $mergeMenu add checkbutton -label "Show Merge Window" -underline 9 \
      -variable g(showmerge) -command "do-show-merge 1"
    $mergeMenu add command -underline 6 -command merge-write-file -label \
      [expr {$g(mergefileset) ? "Write Merge File" : "Write Merge File..."}]
    set "g(tooltip,Show Merge Window)" "Pops up a window showing the current\
       merge results"
    set "g(tooltip,Write Merge File...)" "Write the merge file to disk. You\
       will be prompted to confirm the filename first"
    set "g(tooltip,Write Merge File)" "Write the merge file to disk USING the\
       command line specified name"

    # Help menu. If you change, add or remove labels, be sure and
    # update the tooltips.
    menu $helpMenu
    $helpMenu add command -label "On GUI" -underline 3 -command do-help
    $helpMenu add command -label "On Command Line" -underline 3 \
      -command "do-usage gui"
    $helpMenu add command -label "On Preferences" -underline 3 \
      -command do-help-preferences
    $helpMenu add separator
    $helpMenu add command -label "About $g(name)" -underline 0 -command do-about
    $helpMenu add command -label "About Wish" -underline 0 -command about_wish
    $helpMenu add command -label "About Diff" -underline 0 -command about_diff

    bind $fileMenu <<MenuSelect>> {showTooltip menu %W}
    bind $editMenu <<MenuSelect>> {showTooltip menu %W}
    bind $viewMenu <<MenuSelect>> {showTooltip menu %W}
    bind $markMenu <<MenuSelect>> {showTooltip menu %W}
    bind $mergeMenu <<MenuSelect>> {showTooltip menu %W}
    bind $helpMenu <<MenuSelect>> {showTooltip menu %W}

    set "g(tooltip,On Preferences)" "Show help on the user-settable preferences"
    set "g(tooltip,On GUI)" "Show help on how to use the Graphical User\
      Interface"
    set "g(tooltip,On Command Line)" "Show help on the command line arguments"
    set "g(tooltip,About $g(name))" "Show information about this application"
    set "g(tooltip,About Wish)" "Show information about Wish"
    set "g(tooltip,About Diff)" "Show information about diff"
}

###############################################################################
# Enter names of file pairs accessible for diffing into the menu
###############################################################################
proc reload-multifile {pairs} {
    global w finfo

    # Empty old entries out first (if any) ...
    #   (presupposes it ALWAYS has 'prev, next, separator' as first 3 entries)
    if {[$w(multiFileMenu) index end] > 2} {
        $w(multiFileMenu) delete 3 end
    }

    # then append entries that exist NOW (caller tells us how many that is)
    set i 0
    while {[incr i] <= $pairs} {
        $w(multiFileMenu) add radiobutton -value $i -variable finfo(fCurpair) \
            -label $finfo(lbl,[expr {$i * 2 - 1}]) \
            -command [list multiFileMenu jump $i]
    }
}

###############################################################################
# Show explanation of item in the status bar at the bottom.
# Now used only for menu items
###############################################################################
proc showTooltip {which w} {
    global g

    switch -- $which {
    menu {
            if {[catch {$w entrycget active -label} label]} {
                set label ""
            }
            if {[info exists g(tooltip,$label)]} {
                set g(statusInfo) $g(tooltip,$label)
            } else {
                set g(statusInfo) $label
            }
            update idletasks
        }
    button {
            if {[info exists g(tooltip,$w)]} {
                set g(statusInfo) $g(tooltip,$w)
            } else {
                set g(statusInfo) ""
            }
            update idletasks
        }
    }
}

###############################################################################
# Build the toolbar, in text or image mode
###############################################################################
proc build-toolbar {} {
    global w g opts
    debug-info "build-toolbar ()"

    frame $w(toolbar) -bd 0

    set toolbar $w(toolbar)

    # these are used in other places..
    set w(combo) $toolbar.combo
    set w(rediff_im) $toolbar.rediff_im
    set w(rediff_tx) $toolbar.rediff_tx
    set w(splitDiff_im) $toolbar.split_im
    set w(splitDiff_tx) $toolbar.split_tx
    set w(cmbinDiff_im) $toolbar.cmbin_im
    set w(cmbinDiff_tx) $toolbar.cmbin_tx
    set w(find_im) $toolbar.find_im
    set w(find_tx) $toolbar.find_tx
    set w(mergeChoiceLabel) $toolbar.mergechoicelbl
    set w(mergeChoice1_im) $toolbar.m1_im
    set w(mergeChoice1_tx) $toolbar.m1_tx
    set w(mergeChoice2_im) $toolbar.m2_im
    set w(mergeChoice2_tx) $toolbar.m2_tx
    set w(mergeChoice12_im) $toolbar.m12_im
    set w(mergeChoice12_tx) $toolbar.m12_tx
    set w(mergeChoice21_im) $toolbar.m21_im
    set w(mergeChoice21_tx) $toolbar.m21_tx
    set w(diffNavLabel) $toolbar.diffnavlbl
    set w(prevDiff_im) $toolbar.prev_im
    set w(prevDiff_tx) $toolbar.prev_tx
    set w(firstDiff_im) $toolbar.first_im
    set w(firstDiff_tx) $toolbar.first_tx
    set w(lastDiff_im) $toolbar.last_im
    set w(lastDiff_tx) $toolbar.last_tx
    set w(nextDiff_im) $toolbar.next_im
    set w(nextDiff_tx) $toolbar.next_tx
    set w(centerDiffs_im) $toolbar.center_im
    set w(centerDiffs_tx) $toolbar.center_tx
    set w(markLabel) $toolbar.bkmklbl
    set w(markSet_im) $toolbar.bkmkset_im
    set w(markSet_tx) $toolbar.bkmkset_tx
    set w(markClear_im) $toolbar.bkmkclear_im
    set w(markClear_tx) $toolbar.bkmkclear_tx

    # separators
    toolsep $toolbar.sep1
    toolsep $toolbar.sep2
    toolsep $toolbar.sep3
    toolsep $toolbar.sep4
    toolsep $toolbar.sep5
    toolsep $toolbar.sep6

    # The combo box
    ::combobox::combobox $toolbar.combo -borderwidth 1 -editable false \
      -command moveTo -width 20

    # rediff...
    toolbutton $toolbar.rediff_im -image rediffImg -command recompute-diff \
      -bd 1
    toolbutton $toolbar.rediff_tx -text "Rediff" -command recompute-diff \
      -bd 1 -pady 1

    # split/combine ...
    toolbutton $toolbar.split_im -image splitDiffImg -bd 1 \
      -command [list splcmb-Dialog 0]
    toolbutton $toolbar.split_tx -text "Split..." -bd 1 -pady 1 \
      -command [list splcmb-Dialog 0]

    toolbutton $toolbar.cmbin_im -image cmbinDiffImg -bd 1 \
      -command [list splcmb-Dialog 1]
    toolbutton $toolbar.cmbin_tx -text "Combine..." -bd 1 -pady 1\
      -command [list splcmb-Dialog 1]

    # find...
    toolbutton $toolbar.find_im -image findImg -command do-find -bd 1
    toolbutton $toolbar.find_tx -text "Find" -command do-find -bd 1 -pady 1

    # navigation widgets
    label $toolbar.diffnavlbl -text "Diff:" -pady 0 -bd 2 -relief groove

    toolbutton $toolbar.prev_im -image prevDiffImg -command [list move -1] \
      -bd 1
    toolbutton $toolbar.prev_tx -text "Prev" -command [list move -1] -bd 1 \
      -pady 1

    toolbutton $toolbar.next_im -image nextDiffImg -command [list move 1] \
      -bd 1
    toolbutton $toolbar.next_tx -text "Next" -command [list move 1] -bd 1 \
      -pady 1

    toolbutton $toolbar.first_im -image firstDiffImg -command [list move \
      first] -bd 1
    toolbutton $toolbar.first_tx -text "First" -command [list move first] \
      -bd 1 -pady 1

    toolbutton $toolbar.last_im -image lastDiffImg -command [list move \
      last] -bd 1
    toolbutton $toolbar.last_tx -text "Last" -command [list move last] -bd 1 \
      -pady 1

    toolbutton $toolbar.center_im -image centerDiffsImg -command center -bd 1
    toolbutton $toolbar.center_tx -text "Center" -command center -bd 1 -pady 1

    # the merge widgets
    label $toolbar.mergechoicelbl -text "Merge:" -pady 0 -bd 2 -relief groove

    radiobutton $toolbar.m2_im -borderwidth 1 -indicatoron false \
      -selectcolor $w(selcolor) \
      -image mergeChoice2Img -value 2 -variable g(toggle) -command \
      [list do-merge-choice 2] -takefocus 0
    radiobutton $toolbar.m2_tx -borderwidth 1 -indicatoron true -text "R" \
      -value 2 -variable g(toggle) -command [list do-merge-choice 2] \
      -takefocus 0

    radiobutton $toolbar.m1_im -borderwidth 1 -indicatoron false \
      -selectcolor $w(selcolor) \
      -image mergeChoice1Img -value 1 -variable g(toggle) -command \
      [list do-merge-choice 1] -takefocus 0
    radiobutton $toolbar.m1_tx -borderwidth 1 -indicatoron true -text "L" \
      -value 1 -variable g(toggle) -command [list do-merge-choice 1] \
      -takefocus 0

    radiobutton $toolbar.m12_im -borderwidth 1 -indicatoron false \
      -selectcolor $w(selcolor) \
      -image mergeChoice12Img -value 12 -variable g(toggle) -command \
      [list do-merge-choice 12] -takefocus 0
    radiobutton $toolbar.m12_tx -borderwidth 1 -indicatoron true -text "LR" \
      -value 12 -variable g(toggle) -command [list do-merge-choice 12] \
      -takefocus 0

    radiobutton $toolbar.m21_im -borderwidth 1 -indicatoron false \
      -selectcolor $w(selcolor) \
      -image mergeChoice21Img -value 21 -variable g(toggle) -command \
      [list do-merge-choice 21] -takefocus 0
    radiobutton $toolbar.m21_tx -borderwidth 1 -indicatoron true -text "RL" \
      -value 21 -variable g(toggle) -command [list do-merge-choice 21] \
      -takefocus 0

    # The bookmarks
    label $toolbar.bkmklbl -text "Mark:" -pady 0 -bd 2 -relief groove

    toolbutton $toolbar.bkmkset_im -image markSetImg -command \
      [list diffmark mark] -bd 1
    toolbutton $toolbar.bkmkset_tx -text "Set" -command [list diffmark mark] \
      -bd 1 -pady 1

    toolbutton $toolbar.bkmkclear_im -image markClearImg -command \
      [list diffmark clear] -bd 1
    toolbutton $toolbar.bkmkclear_tx -text "Clear" -command [list diffmark \
      clear] -bd 1 -pady 1

    set_tooltips $w(find_im) {"Pop up a dialog to search for a string within\
      either file"}
    set_tooltips $w(find_tx) {"Pop up a dialog to search for a string within\
      either file"}
    set_tooltips $w(rediff_im) {"Recompute and redisplay the difference\
      records"}
    set_tooltips $w(rediff_tx) {"Recompute and redisplay the difference\
      records"}
    set_tooltips $w(splitDiff_im) {"Split Diff at specified bounds"}
    set_tooltips $w(splitDiff_tx) {"Split Diff at specified bounds"}
    set_tooltips $w(cmbinDiff_im) {"Combine Diff with ADJACENT neighbor(s)"}
    set_tooltips $w(cmbinDiff_tx) {"Combine Diff with ADJACENT neighbor(s)"}
    set_tooltips $w(mergeChoice12_im) {"select the diff on the left then\
      right for merging"}
    set_tooltips $w(mergeChoice12_tx) {"select the diff on the left then\
      right for merging"}
    set_tooltips $w(mergeChoice1_im) {"select the diff on the left for merging"}
    set_tooltips $w(mergeChoice1_tx) {"select the diff on the left for merging"}
    set_tooltips $w(mergeChoice2_im) {"select the diff on the right for\
      merging"}
    set_tooltips $w(mergeChoice2_tx) {"select the diff on the right for\
      merging"}
    set_tooltips $w(mergeChoice21_im) {"select the diff on the right then\
      left for merging"}
    set_tooltips $w(mergeChoice21_tx) {"select the diff on the right then\
      left for merging"}
    set_tooltips $w(prevDiff_im) {"Previous Diff"}
    set_tooltips $w(prevDiff_tx) {"Previous Diff"}
    set_tooltips $w(nextDiff_im) {"Next Diff"}
    set_tooltips $w(nextDiff_tx) {"Next Diff"}
    set_tooltips $w(firstDiff_im) {"First Diff"}
    set_tooltips $w(firstDiff_tx) {"First Diff"}
    set_tooltips $w(lastDiff_im) {"Last Diff"}
    set_tooltips $w(lastDiff_tx) {"Last Diff"}
    set_tooltips $w(markSet_im) {"Mark current diff"}
    set_tooltips $w(markSet_tx) {"Mark current diff"}
    set_tooltips $w(markClear_im) {"Clear current diff mark"}
    set_tooltips $w(markClear_tx) {"Clear current diff mark"}
    set_tooltips $w(centerDiffs_im) {"Center Current Diff"}
    set_tooltips $w(centerDiffs_tx) {"Center Current Diff"}

    pack-toolbuttons $toolbar
}

proc pack-toolbuttons {toolbar} {
    global w opts

    set bp [expr {$opts(toolbarIcons) ? "im" : "tx"}]

    pack $toolbar.combo -side left -padx 2
    pack $toolbar.sep1 -side left -fill y -pady 2 -padx 2
    pack $toolbar.rediff_$bp -side left -padx 2
    pack $toolbar.split_$bp -side left -padx 2
    pack $toolbar.cmbin_$bp -side left -padx 2
    pack $toolbar.find_$bp -side left -padx 2
    pack $toolbar.sep2 -side left -fill y -pady 2 -padx 2
    pack $toolbar.mergechoicelbl -side left -padx 2
    pack $toolbar.m12_$bp $toolbar.m1_$bp $toolbar.m2_$bp $toolbar.m21_$bp \
      -side left -padx 2
    pack $toolbar.sep3 -side left -fill y -pady 2 -padx 2
    pack $toolbar.diffnavlbl -side left -pady 2 -padx 2
    pack $toolbar.first_$bp $toolbar.last_$bp $toolbar.prev_$bp \
      $toolbar.next_$bp -side left -pady 2 -padx 2
    pack $toolbar.sep4 -side left -fill y -pady 2 -padx 2
    pack $toolbar.center_$bp -side left -pady 2 -padx 1
    pack $toolbar.sep5 -side left -fill y -pady 2 -padx 2
    pack $toolbar.bkmklbl -side left -padx 2
    pack $toolbar.bkmkset_$bp $toolbar.bkmkclear_$bp -side left -pady 2 -padx 2
    pack $toolbar.sep6 -side left -fill y -pady 2 -padx 2

    foreach b [info commands $toolbar.mark*] {
        pack $b -side left -fill y -pady 2 -padx 2
    }

    foreach b [info commands $toolbar.mark*] {
        $b configure -relief $opts(relief)
    }
    foreach b [info commands $toolbar.*_$bp] {
        $b configure -relief $opts(relief)
    }

    # Radiobuttons ignore relief configuration if they have an image, so we
    # set their borderwidth to 0 if we want them flat.
    if {$opts(relief) == "flat" && $opts(toolbarIcons)} {
        set bord 0
    } else {
        set bord 1
    }
    foreach b [info commands $toolbar.m\[12\]*] {
        $b configure -bd $bord
    }

    # The selectcolor MAY have been changed (via CustomCode) which is
    # (unfortunately) not available until AFTER the widgets have been built
    # (too dangerous to invoke CustomCode earlier). Take this opportunity
    # to apply this ONE attribute.
    if {$bp == "im" && [$toolbar.m1_$bp cget -selectcolor] != $w(selcolor)} {
        foreach b [info commands $toolbar.m\[12\]*m] {
            $b configure -selectcolor $w(selcolor)
        }
    }
}

proc reconfigure-toolbar {} {
    global w
    debug-info "reconfigure-toolbar ()"

    foreach button [winfo children $w(toolbar)] {
        pack forget $button
    }

    pack-toolbuttons $w(toolbar)
}

proc build-status {} {
    global g w
    debug-info "build-status ()"

    frame $w(status) -bd 0

    set w(statusLabel) $w(status).label
    set w(statusCurrent) $w(status).current

    # MacOS has a resize handle in the bottom right which will sit
    # on top of whatever is placed there. So, we'll add a little bit
    # of whitespace there. It's harmless, so we'll do it on all of the
    # platforms.
    label $w(status).blank -image nullImg -width 16 -bd 1 -relief sunken

    label $w(statusCurrent) -textvariable g(statusCurrent) -anchor e \
      -width 14 -borderwidth 1 -relief sunken -padx 4 -pady 2
    label $w(statusLabel) -textvariable g(statusInfo) -anchor w -width 1 \
      -borderwidth 1 -relief sunken -pady 2
    pack $w(status).blank -side right -fill y

    pack $w(statusCurrent) -side right -fill y -expand n
    pack $w(statusLabel) -side left -fill both -expand y
}

###############################################################################
# handles simulated-scroll events over the map
#  Provides 3 modes:
# B1-click (over trough) pages, B1-motion (over thumb) drags, or B2-click jumps
# Once a button is down, the mode locks and mouse X-location becomes irrelevant
###############################################################################
proc handleMapEvent {event y} {
    global g w opts
    #debug-info "handleMapEvent $event $y"

    switch -- $event {
    B1-Press {
            if {! $g(mapScrolling)} {
                set ty1 [lindex $g(thumbBbox) 1]
                set ty2 [lindex $g(thumbBbox) 3]
                if {$y >= $ty1 && $y <= $ty2} {
                    # this captures the negative delta between the mouse press
                    # and the top of the thumbbox. It's used so when we scroll
                    # by moving the mouse, we can keep this distance constant.
                    #  (this is how all scrollbars work, and what is expected)
                    set g(thumbDeltaY) [expr -1 * ($y - $ty1 - 2)]
                         set g(mapScrolling) 3
                } else { set g(mapScrolling) 1 }
                # Either way, mode is set and other mouse events are locked out
            }
        }
    B2-Press {
            # Set mode and lock out other mouse events
            if {! $g(mapScrolling)} { set g(mapScrolling) 2 }
    }
    B2-Release -
    B1-Motion {
            if {$g(mapScrolling) & 2} {
                if {$g(mapScrolling) == 3} {
                    incr y $g(thumbDeltaY)
                }

                map-seek $y

                # Release our mouse event lock (B2-click completed)
                if {$g(mapScrolling) == 2} { set g(mapScrolling) 0 }
            }
        }
    B1-Release {
            show-status ""
            if {$g(mapScrolling) & 1} {
                set ty1 [lindex $g(thumbBbox) 1]
                set ty2 [lindex $g(thumbBbox) 3]
                # if we release over the trough (*not* over the thumb)
                #   just scroll by the size of the thumb; ...
                # otherwise we must have been dragging the thumb and we're done
                if {$y < $ty1 || $y > $ty2} {
                    if {$y < $ty1} {
                        # if vertical scrollbar syncing is turned on,
                        # all the other windows should toe the line
                        # appropriately...
                        $g(activeWindow) yview scroll -1 pages
                    } else {
                        $g(activeWindow) yview scroll 1 pages
                    }
                }

                # Release our mouse event lock (B1 click/drag completed)
                set g(mapScrolling) 0
            }
        }
    }
}

# makes a toolbar "separator"
proc toolsep {w} {
    label $w -image [image create photo] -highlightthickness 0 -bd 1 -width 0 \
      -relief groove
    return $w
}

proc toolbutton {w args} {
    global g opts tcl_platform

    # create the button
    button $w {*}$args

    # add minimal tooltip-like support
    bind $w <Enter> [list toolbtnEvent <Enter> %W]
    bind $w <Leave> [list toolbtnEvent <Leave> %W]
    bind $w <FocusIn> [list toolbtnEvent <FocusIn> %W]
    bind $w <FocusOut> [list toolbtnEvent <FocusOut> %W]

    $w configure -relief $opts(relief)

    return $w
}

# handle events in our fancy toolbuttons...
proc toolbtnEvent {event w {isToolbutton 1}} {
    global g opts

    switch -- $event {
    "<Enter>" {
            showTooltip button $w
            if {$opts(fancyButtons) && $isToolbutton && [$w cget -state] == \
              "normal"} {
                $w configure -relief raised
            }
        }
    "<Leave>" {
            set g(statusInfo) ""
            if {$opts(fancyButtons) && $isToolbutton} {
                $w configure -relief flat
            }
        }
    "<FocusIn>" {
            showTooltip button $w
            if {$opts(fancyButtons) && $isToolbutton && [$w cget -state] == \
              "normal"} {
                $w configure -relief raised
            }
        }
    "<FocusOut>" {
            set g(statusInfo) ""
            if {$opts(fancyButtons) && $isToolbutton} {
                $w configure -relief flat
            }
        }
    }
}

###############################################################################
# move the map thumb to correspond to current shown merge...
###############################################################################
proc map-move-thumb {y1 y2} {
    global g w

    set thumbheight [expr {($y2 - $y1) * $g(mapheight)}]
    if {$thumbheight < $g(thumbMinHeight)} {
        set thumbheight $g(thumbMinHeight)
    }

    if {![info exists g(mapwidth)]} {
        set g(mapwidth) 0
    }
    set x1 1
    set x2 [expr {$g(mapwidth) - 3}]

    # why -2? it's the thickness of our border...
    set y1 [expr {int(($y1 * $g(mapheight)) - 2)}]
    if {$y1 < 0} {
        set y1 0
    }

    set y2 [expr {$y1 + $thumbheight}]
    if {$y2 > $g(mapheight)} {
        set y2 $g(mapheight)
        set y1 [expr {$y2 - $thumbheight}]
    }

    set dx1 [expr {$x1 + 1}]
    set dx2 [expr {$x2 - 1}]
    set dy1 [expr {$y1 + 1}]
    set dy2 [expr {$y2 - 1}]

    $w(mapCanvas) coords thumbUL $x1 $y2 $x1 $y1 $x2 $y1 $dx2 $dy1 $dx1 $dy1 \
      $dx1 $dy2
    $w(mapCanvas) coords thumbLR $dx1 $y2 $x2 $y2 $x2 $dy1 $dx2 $dy1 $dx2 \
      $dy2 $dx1 $dy2

    set g(thumbBbox) [list $x1 $y1 $x2 $y2]
    set g(thumbHeight) $thumbheight
}

###############################################################################
# Bind keys for Next, Prev, Center, Merge choices 1 and 2
#
# N.B. This is GROSS! It might have been necessary in earlier versions,
# but now I think it needs a serious rewrite. We are CURRENTLY overriding
# the text widget, so we can probably just disable the insert and delete
# commands, and use something like insert_ and delete_ internally.
###############################################################################
proc common-navigation {args} {
    global w

    bind $w(tw) <Control-f> do-find

    foreach widget $args {
        # this effectively disables the widget, without having to
        # resort to actually disabling the widget (the latter which
        # has some annoying side effects). What we really want is to
        # only disable keys that get inserted, but that's difficult
        # to do, and this works almost as well...
        bind $widget <KeyPress> {break}

        bind $widget <Alt-KeyPress> {continue}

        bind $widget <<Paste>> {break}


        # ... but now we need to restore some navigation key bindings
        # which got lost because we disable all keys. Since we are
        # attaching bindings that duplicate class bindings, we need
        # to be sure and include the break, so the events don't fire
        # twice (once for the widget, once for the class). There is
        # probably a much better way to do all this, but I'm too
        # lazy to figure it out...
        foreach event [list Next Prior Up Down Left Right Home End] {
            foreach modifier [list {} Shift Control Shift-Control] {
                set binding [bind Text <${modifier}${event}>]
                if {[string length $binding] > 0} {
                    bind $widget "<${modifier}${event}>" "
                        ${binding}
                        break
                    "
                }
            }
        }

        # these bindings allow control-f, tab and shift-tab to work
        # in spite of the fact we bound Any-KeyPress to a null action
        bind $widget <Control-f> continue

        bind $widget <Tab> continue

        bind $widget <Shift-Tab> continue

        # OPA >>>
        bind $widget <<Copy>> "
            do-copy
            break
        " 
        # OPA <<<

        bind $widget <c> "
            center
            break
        "
        bind $widget <n> "
            move 1
            break
        "
        bind $widget <p> "
            move -1
            break
        "
        bind $widget <f> "
            move first
            break
        "
        bind $widget <l> "
            move last
            break
        "
        bind $widget <j> {
            multiFileMenu next 0
            break
        }
        bind $widget <bracketright> {
            multiFileMenu next 0
            break
        }
        bind $widget <k> {
            multiFileMenu prev 0
            break
        }
        bind $widget <bracketleft> {
            multiFileMenu prev 0
            break
        }

        # OPA >>>

        bind $widget <Control-w> "
            tkdiff-CloseAppWindow
            break
        "
        bind $widget <Control-q> "
            do-exit
            break
        " 
        bind $widget <Key-Left> "
            do-merge-choice 1
            break
        "
        bind $widget <Key-Right> "
            do-merge-choice 2
            break
        "
        bind $widget <Key-Up> "
            move -1
            break
        "
        bind $widget <Key-Down> "
            move 1
            break
        "

        # OPA <<<

        bind $widget <q> "
            do-exit
            break
        "
        bind $widget <r> "
            recompute-diff
            break
        "
        bind $widget <Return> "
            moveNearest $widget mark insert
            break
        "

        # these bindings keep Alt- modified keys from triggering
        # the above actions. This way, any Alt combinations that
        # should open a menu will...
        foreach key [list c n p f l] {
            bind $widget <Alt-$key> {continue}
        }

        bind $widget <Double-1> "
            moveNearest $widget xy %x %y
            break
        "

        bind $widget <Key-1> "
            do-merge-choice 1
            break
        "
        bind $widget <Key-2> "
            do-merge-choice 2
            break
        "
        bind $widget <Key-3> "
            do-merge-choice 12
            break
        "
        bind $widget <Key-4> "
            do-merge-choice 21
            break
        "
    }
}

###############################################################################
# set or clear a "diff mark" -- a hot button to move to a particular diff
###############################################################################
proc diffmark {option {diff -1}} {
    global g w
    debug-info "diffmark ($option $diff)"

    if {$diff == -1} {
        set diff $g(pos)
    }

    switch -glob -- $option {
        activate {
            move $diff 0 1
        }
        mark { ;# Create
            if {![winfo exists [set widget $w(toolbar).mark[hunk-id $diff]]]} {
                toolbutton $widget -text "\[$diff\]" \
                         -command [list diffmark activate $diff] -bd 1 -pady 1
                pack $widget -side left -padx 2
                set g(tooltip,$widget) "Diff Marker: Jump to diff record\
                  number $diff"
            }
            update-display
        }
        clear { ;# Destroy
            if {[winfo exists [set widget $w(toolbar).mark[hunk-id $diff]]]} {
                destroy $widget
                catch {unset g(tooltip,$widget)}
            }
            update-display
        }
        clearall { ;# Destroy ALL
            set bookmarks [info commands $w(toolbar).mark*]
            if {[llength $bookmarks] > 0} {
                foreach widget $bookmarks {
                    destroy $widget
                    catch {unset g(tooltip,$widget)}
                }
            }
            update-display
        }
        "[0-9]*[acd]*[0-9]" { ;# Re-config
            if {[winfo exists [set widget $w(toolbar).mark$option]]} {
                $widget config -text "\[$diff\]" \
                         -command [list diffmark activate $diff] -bd 1 -pady 1
                set g(tooltip,$widget) "Diff Marker: Jump to diff record\
                  number $diff"
            }
        }
    }
}

###############################################################################
# Customize the display (among other things).
###############################################################################
proc customize {} {
    global g w pref opts tmpopts tcl_platform
    debug-info "customize ()"

    catch {destroy $w(preferences)}
    toplevel $w(preferences)

    wm title $w(preferences) "$g(name) Preferences"
    wm transient $w(preferences) $w(tw)
    wm group $w(preferences) $w(tw)

    if {$g(windowingSystem) == "aqua"} {
        setAquaDialogStyle $w(preferences)
    }

    wm withdraw $w(preferences)

    # the button frame...
    frame $w(preferences).buttons -bd 0
    button $w(preferences).buttons.dismiss -width 8 -text "Dismiss" \
      -command {destroy $w(preferences)}
    button $w(preferences).buttons.apply -width 8 -text "Apply" \
      -command {applypref}
    button $w(preferences).buttons.save -width 8 -text "Save" -command save

    button $w(preferences).buttons.help -width 8 -text "Help" \
      -command do-help-preferences

    pack $w(preferences).buttons -side bottom -fill x
    pack $w(preferences).buttons.dismiss -side right -padx 10 -pady 5
    pack $w(preferences).buttons.help -side right -padx 10 -pady 5
    pack $w(preferences).buttons.save -side right -padx 1 -pady 5
    pack $w(preferences).buttons.apply -side right -padx 1 -pady 5

    # a series of checkbuttons to act as a poor mans notebook tab
    frame $w(preferences).notebook -bd 0
    pack $w(preferences).notebook -side top -fill x -pady 4
    set pagelist {}

    # The relief makes these work, so we don't need to use the selcolor
    # Radiobuttons without indicators look rather sucky on MacOSX, so
    # we'll tweak the style for that platform
    if {$::tcl_platform(os) == "Darwin"} {
        set indicatoron true
    } else {
        set indicatoron false
    }
    foreach page [list General Display Appearance] {
        set frame $w(preferences).f$page
        lappend pagelist $frame
        set rb $w(preferences).notebook.f$page
        radiobutton $rb -command "customize-selectPage $frame" \
          -selectcolor $w(background) \
          -variable g(prefPage) -value $frame -height 2 -text $page \
          -indicatoron $indicatoron -borderwidth 1

        pack $rb -side left

        frame $frame -bd 2 -relief groove -width 400 -height 300
    }
    set g(prefPage) $w(preferences).fGeneral

    # make sure our labels are defined
    customize-initLabels

    # this is an option that we support internally, but don't give
    # the user a way to directly edit (right now, anyway). But we
    # need to make sure tmpopts knows about it
    set tmpopts(customCode) $opts(customCode)

    # General
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    set frame $w(preferences).fGeneral
    set row 0
    foreach key {diffcmd ignoreblanksopt tmpdir editor ignoreRegexLnopt \
                                                         filetypes geometry } {
        label $frame.l$row -text "$pref($key): " -anchor w
        set tmpopts($key) $opts($key)
        if {$key == "ignoreRegexLnopt" || $key == "filetypes"} {
            ::combobox::combobox $frame.e$row -width 50 \
                        -command "editLstPref $key" -listvar tmpopts($key)
        } else {
            entry $frame.e$row -width 50 -bd 2 -relief sunken \
                -textvariable tmpopts($key)
        }

        grid $frame.l$row -row $row -column 0 -sticky w -padx 5 -pady 2
        grid $frame.e$row -row $row -column 1 -sticky ew -padx 5 -pady 2

        incr row
    }

    # this is just for filler...
    label $frame.filler -text {}
    grid $frame.filler -row $row
    incr row

    # Option fields
    # Note that the order of the list is used to determine the layout. So, if
    # you add something to the list pay attention to how it affects things.
    #
    # Remaining layout is a 2-column, row-major order (ie. columns vary fastest)
    #       an 'x' means an empty column; a '-' means an empty row
    # (Note: each row must be fully filled - even if that means a trailing 'x')
    set col 0
    foreach key [list ignoreblanks toolbarIcons - ignoreEmptyLn autocenter - \
            ignoreRegexLn autoselect - syncscroll fancyButtons - predomMrg x] {

        if {$key != "x"} {
            if {$key == "-"} {
                frame $frame.f${row} -bd 0 -height 4
                grid $frame.f${row} -row $row -column 0 -padx 20 -pady 4 \
                                                     -columnspan 2 -sticky nsew
                set col 1 ;# forces NEXT column to zero and increments row
            } else {
                set tmpopts($key) $opts($key)
                if {"$key" == "predomMrg"} {
                    set f [frame $frame.c${row}$col -bd 0]
                    pack [label $f.l -text "$pref($key): " -anchor w] -side left
                    foreach {nam val} {Left 1 Right 2} {
                         radiobutton $f.r$val -text $nam -value $val \
                                                        -variable tmpopts($key)
                         pack $f.r$val -side left
                    }
                } else {
                    checkbutton $frame.c${row}$col -indicatoron true \
                                   -text "$pref($key)" -onvalue 1 -offvalue 0 \
                                                        -variable tmpopts($key)
                }

                # Manage each widget EXCEPT 'fancybuttons' on the (Mac?) 'aqua'
                if {$key != "fancyButtons" || $g(windowingSystem) != "aqua"} {
                    grid $frame.c${row}$col -sticky w -padx 5 -row $row -column $col
                }
            }
        }
        if {![set col [expr {$col ? 0 : 1}]]} { incr row }
    }

    # add validation to enable/disable 'ignore(blanksopt/RegexLnopt)' entries
    # and then initialize them into agreement
    trace variable tmpopts(ignoreblanks) w [list toggle-state $frame.e1 ]
    trace variable tmpopts(ignoreRegexLn) w [list toggle-state $frame.e4 ]
    toggle-state $frame.e1 tmpopts ignoreblanks w
    toggle-state $frame.e4 tmpopts ignoreRegexLn w

    # The bottom row and right column should stretch to take up any extra room
    grid columnconfigure $frame 0 -weight 0
    grid columnconfigure $frame 1 -weight 1
    grid rowconfigure $frame $row -weight 1

    # pack this window for a brief moment, and compute the window
    # size. We'll do this for each "page" and find the largest
    # size to be the size of the dialog
    pack $frame -side right -fill both -expand y
    update idletasks
    set maxwidth [winfo reqwidth $w(preferences)]
    set maxheight [winfo reqheight $w(preferences)]
    pack forget $frame

    # Appearance
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    set frame $w(preferences).fAppearance
    set row 0
    foreach key {textopt difftag deltag instag chgtag currtag bytetag \
                                                        inlinetag overlaptag} {
        set tmpopts($key) $opts($key)
        label $frame.l$row -text "$pref($key): " -anchor w
        entry $frame.e$row -textvariable tmpopts($key) -bd 2 -relief sunken

        grid $frame.l$row -row $row -column 0 -sticky w -padx 5 -pady 2
        grid $frame.e$row -row $row -column 1 -sticky ew -padx 5 -pady 2

        incr row
    }

    # tabstops are placed after a little extra whitespace, since it is
    # slightly different than all of the other options (ie: it's not
    # a list of widget options)
    frame $frame.sep$row -bd 0 -height 4
    grid $frame.sep$row -row $row -column 0 -stick ew -columnspan 2 \
      -padx 5 -pady 2
    incr row

    set key "tabstops"
    set tmpopts($key) $opts($key)
    label $frame.l$row -text "$pref($key):" -anchor w
    entry $frame.e$row -textvariable tmpopts($key) -bd 2 -relief sunken \
      -width 3
    grid $frame.l$row -row $row -column 0 -sticky w -padx 5 -pady 2
    grid $frame.e$row -row $row -column 1 -sticky w -padx 5 -pady 2

    incr row
    # Option fields
    # Note that the order of the list is used to determine the layout. So, if
    # you add something to the list pay attention to how it affects things.
    #
    # Remaining layout is a 2-column, row-major order (ie. columns vary fastest)
    #       an 'x' means an empty column; a '-' means an empty row
    # (Note: each row must be fully filled - even if that means a trailing 'x')
    set col 0
    foreach key {x adjcdr mapins mapchg mapdel mapolp} {

        if {$key != "x"} {
            if {$key == "-"} {
                frame $frame.f${row} -bd 0 -height 4
                grid $frame.f${row} -row $row -column 0 -padx 20 -pady 4 \
                                                     -columnspan 2 -sticky nsew
                set col 1 ;# forces NEXT column to zero and increments row
            } else {
               # button 'active' bg shows color as contrasted w/Txt fg
               set tmpopts($key) $opts($key)
               set b $frame.b${row}$col
               button $b -text "$pref($key)" -command [list clrpick $b $key] \
                                   -activeforeground [$w(LeftText) cget -fg] \
                                   -activebackground $tmpopts($key)
               grid $b -row $row -column $col -sticky ew -padx 5 -pady 2
            }
        }
        if {![set col [expr {$col ? 0 : 1}]]} { incr row }
    }

    # add a tiny bit of validation, so user can only enter numbers for tabwidth
    trace variable tmpopts(tabstops) w [list validate integer]

    # The bottom row and right column should stretch to take up any extra room
    grid columnconfigure $frame 0 -weight 0
    grid columnconfigure $frame 1 -weight 1
    grid rowconfigure $frame $row -weight 1

    pack $frame -side right -fill both -expand y
    update idletasks
    set maxwidth [max $maxwidth [winfo reqwidth $w(preferences)]]
    set maxheight [max $maxheight [winfo reqheight $w(preferences)]]
    pack forget $frame

    # Display
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    set frame $w(preferences).fDisplay

    # Option fields
    # Note that the order of the list is used to determine the layout. So, if
    # you add something to the list pay attention to how it affects things.
    #
    # Layout is a 2-column, row-major order (ie. columns vary fastest)
    #       an 'x' means an empty column; a '-' means an empty row
    # (Note: each row must be fully filled - even if that means a trailing 'x')
    set row 0
    set col 0
    # OPA >>> Added showcontextsave
    foreach key [list showln tagln - showcbs tagcbs - showmap colorcbs - \
      tagtext showinline1 x showinline2 - showlineview x showcontextsave ] {

        if {$key != "x"} {
            if {$key == "-"} {
                frame $frame.f${row} -bd 0 -height 4
                grid $frame.f${row} -row $row -column 0 -padx 20 -pady 4 \
                                               -columnspan 2 -sticky nsew
                set col 1 ;# forces NEXT column to zero and increments row
            } else {
                set tmpopts($key) $opts($key)
                checkbutton $frame.c${row}${col} -indicatoron true -onvalue 1 \
                        -offvalue 0 -text "$pref($key)" -variable tmpopts($key)
                grid $frame.c${row}$col -row $row -column $col -sticky w -padx 5
            }
        }
        if {![set col [expr {$col ? 0 : 1}]]} { incr row }
    }

    # add validation to make sure only one of the showinline# options are set
    trace variable tmpopts(showinline1) w [list validate-inline showinline1]
    trace variable tmpopts(showinline2) w [list validate-inline showinline2]

    # The bottom row and right column should stretch to take up any extra room
    grid columnconfigure $frame 0 -weight 0
    grid columnconfigure $frame 1 -weight 1
    grid rowconfigure $frame $row -weight 1

    pack $frame -side right -fill both -expand y
    update idletasks
    set maxwidth [max $maxwidth [winfo reqwidth $w(preferences)]]
    set maxheight [max $maxheight [winfo reqheight $w(preferences)]]
    pack forget $frame

    customize-selectPage

    # compute a reasonable location for the window...
    centerWindow $w(preferences) [list $maxwidth $maxheight]

    wm deiconify $w(preferences)
}

###############################################################################
# align status of passed widget to agree with passed ($index) value
###############################################################################
proc toggle-state {widget name index op} {
    upvar $name var

    if {$var($index)} {
        $widget configure -state normal
    } else {
        $widget configure -state disabled
    }
}

###############################################################################
# A generalized preferences entry-field data-type validator
###############################################################################
proc validate {type name index op} {
    global tmpopts

    # if we fail the check, attempt to do something clever
    if {![string is $type $tmpopts($index)]} {
        bell

        switch -- $type {
        integer {
                regsub -all -- {[^0-9]} $tmpopts($index) {} tmpopts($index)
            }
        default {
                # this should never happen. If you use this routine,
                # make sure you add cases to handle all possible
                # values of $type used by this program.
                set tmpopts($index) ""
            }
        }
    }
}

###############################################################################
# Specialized color-picker invoked by button (feedback to specific button -bg)
###############################################################################
proc clrpick {wdg key} {
    global pref tmpopts

    set color [tk_chooseColor -initialcolor [$wdg cget -activebackground] \
                      -parent [file rootname $wdg] -title "Choose $pref($key)"]
    if {"$color" != ""} {
        $wdg configure -activebackground [set tmpopts($key) $color]
    }
}

###############################################################################
# Manage user interaction with any pref represented via a 'list of values'
###############################################################################
proc editLstPref {key args} {
    global pref tmpopts

    # Empty values simply have no effect and are ignored
    #   (we sortof use it as feedback that we "accepted" the add/delete)
    foreach {wdg value} $args {
        if {![string length "[string trim "$value"]"]} {return}
    }

    # Ugh - the combobox widget apparently has a *global* GRAB in progress ...
    #    So we CANT really popup modal dialogs for confirmations, etc.
    #    Instead, we will ENCAPSULATE the notices/feedback/actions to occur
    #    *after* this callback (and combobox) are DONE (and the grab is gone)
    #
    # N.B> "subst + backslashing" is needed to resolve & embed LOCAL vars

    # Confirm requests to DELETE from the list
    if {[set ndx [lsearch -exact $tmpopts($key) "$value"]] >= 0} {
        after idle [subst {
                if {{ok} == \[tk_messageBox -type okcancel -icon question   \
                -title {Please Confirm} -parent [file rootname $wdg]        \
                -message "Remove this entry from the\n'$pref($key)' list ?" \
                                                       -default cancel ]}   \
                { set tmpopts($key) \[lreplace \$tmpopts($key) $ndx $ndx];  \
                                  editLstFeedback $wdg {    R e m o v e d} }
        }]
    } else {
        # Possibly validate the FORM of the specific entry before ADDING it
        if {"$key" == "filetypes" && [llength "$value"] != 2} {
            after idle [subst {
                    tk_messageBox -type ok -title {Syntax error} -icon info \
                    -parent [file rootname $wdg]  -detail {(not added)}     \
                    -message "Format should be '{filetype label} .extension'"
            }]
        } else {
            after idle [subst { lappend tmpopts($key) {$value} ; \
                                        editLstFeedback $wdg {    A d d e d}
            }]
        }
    }
}

# Pure unadulterated GUI fluff (lets user KNOW their edit was accepted)
proc editLstFeedback {wdg msg} {
    # Pretend to enter a new value (but dont let the command fire) ... then
    # 1250ms later, clear with an EMPTY value (and LET it fire w/no effect)
    $wdg configure -commandstate disabled
    $wdg configure -value "$msg"
    after 1250 "$wdg configure -commandstate normal -value {}"
}

###############################################################################
# Emulate SEMI-radio-button behavior: only 1 can be 'on', BUT BOTH may be 'off'
###############################################################################
proc validate-inline {option name index op} {
    global tmpopts

    if {$tmpopts($index)} {
        if {$index == "showinline1"} {
            set tmpopts(showinline2) 0
        } elseif {$index == "showinline2"} {
            set tmpopts(showinline1) 0
        }
    }
}

###############################################################################
# Finalize packing the Preferences dialog for the largest "tab" overlay
###############################################################################
proc customize-selectPage {{frame {}}} {
    global g w

    if {$frame == ""} {
        set frame $g(prefPage)
    }

    pack forget $w(preferences).fGeneral
    pack forget $w(preferences).fAppearance
    pack forget $w(preferences).fDisplay
    pack forget $w(preferences).fBehavior
    pack $frame -side right -fill both -expand y
}

###############################################################################
# define the labels for the preferences. This is done outside of
# the customize proc since the labels are used in the help text.
###############################################################################
proc customize-initLabels {} {
    global pref

    # But it only need be done once
    if {[info exists pref(diffcmd)]} return

    # Alphabetical by prefNAME, (annotated w/pane of 'customize' it appears on)
    #      A = Appearance     G = General     D = Display
    set pref(adjcdr)           {CDR region color during adjustment }      ;# A
    set pref(autocenter)      {Automatically center current diff region } ;#G
    set pref(autoselect) {Auto-select nearest diff region when scrolling} ;#G
    set pref(bytetag)          {Tag options for characters in line view}  ;#  A
    set pref(chgtag)           {Tag options for changed diff region}      ;#  A
    set pref(colorcbs)         {Color change bars to match the diff map}  ;# D
    set pref(currtag)          {Tag options for the current diff region}  ;#  A
    set pref(deltag)           {Tag options for deleted diff region}      ;#  A
    set pref(diffcmd)          {diff command}                             ;#G
    set pref(difftag)          {Tag options for diff regions}             ;#  A
    set pref(editor)           {Program for editing files}                ;#G
    set pref(fancyButtons)     {Windows-style toolbar buttons}            ;#G
    set pref(filetypes)        {Choice of file suffixes for file dialogs} ;#G
    set pref(geometry)         {Text window size}                         ;#G
    set pref(ignoreblanks)     {Ignore blanks when diffing}               ;#G
    set pref(ignoreblanksopt)  {Options for Ignoring blanks}              ;#G
    set pref(ignoreEmptyLn)    {Suppress diffs of empty lines}            ;#G
    set pref(ignoreRegexLn)    {Suppress diffs of RegExp-matched lines}   ;#G
    set pref(ignoreRegexLnopt) {RegExp(s) for matching lines}             ;#G
    set pref(inlinetag)  {Tag options for diff region inline differences} ;#  A
    set pref(instag)           {Tag options for inserted diff region}     ;#  A
    set pref(mapchg)           {Map color for changes}                    ;#  A
    set pref(mapdel)           {Map color for deletions}                  ;#  A
    set pref(mapins)           {Map color for additions}                  ;#  A
    set pref(mapolp)           {Map color for collisions}                 ;#  A
    set pref(overlaptag)       {Tag options for overlap diff region}      ;#  A
    set pref(predomMrg)        {Predominate merge choice}                 ;#G
    set pref(showcbs)          {Show change bars}                         ;# D
    set pref(showinline1)      {Show inline diffs (byte comparisons)}     ;# D
    set pref(showinline2) {Show inline diffs (recursive match algorithm)} ;# D
    set pref(showlineview)     {Show current line comparison window}      ;# D
    set pref(showln)           {Show line numbers}                        ;# D
    set pref(showmap)          {Show graphical map of diffs}              ;# D
    set pref(syncscroll)       {Synchronize scrollbars}                   ;#G
    # OPA >>>
    set pref(showcontextsave)  {Add fast save to popup menu} 
    # OPA <<< 
    set pref(tabstops)         {Tab stops}                                ;#  A
    set pref(tagcbs)           {Highlight change bars}                    ;# D
    set pref(tagln)            {Highlight line numbers}                   ;# D
    set pref(tagtext)          {Highlight file contents}                  ;# D
    set pref(textopt)          {Text widget options}                      ;#  A
    set pref(toolbarIcons) {Use icons instead of labels in the toolbar}   ;#G
    set pref(tmpdir)           {Directory for scratch files}              ;#G
}

###############################################################################
# Apply customization changes.
###############################################################################
proc applypref {} {
    global g w pref opts tmpopts tk_version screenWidth screenHeight
    debug-info "applypref ()"

    grid propagate $w(client) t
    if {! [file isdirectory $tmpopts(tmpdir)]} {
        do-error "Invalid temporary directory $tmpopts(tmpdir)"
    }

    if {[catch "
        $w(LeftText) configure $tmpopts(textopt)
        $w(RightText) configure $tmpopts(textopt)
        $w(BottomText) configure $tmpopts(textopt)
    "]} {
        do-error "Invalid text widget setting: \n\n'$tmpopts(textopt)'"
        eval "$w(LeftText)   configure $opts(textopt)"
        eval "$w(RightText)  configure $opts(textopt)"
        eval "$w(BottomText) configure $opts(textopt)"
        return
    }

    # Ensure each Info widget tracks the background of their Text widget
    $w(LeftInfo)  configure -background [$w(LeftText)  cget -background]
    $w(RightInfo) configure -background [$w(RightText) cget -background]
    $w(mergeInfo) configure -background [$w(mergeText) cget -background]

    set gridsize [wm grid $w(tw)]
    set gridx [lindex $gridsize 2]
    set gridy [lindex $gridsize 3]
    #debug-info " wm grid is $gridx x $gridy"

    set maxunitsx [expr {$screenWidth / $gridx}]
    set maxunitsy [expr {$screenHeight / $gridy}]
    #debug-info "   max X is $maxunitsx units"
    #debug-info "   max Y is $maxunitsy units"
    set halfmax [expr {$maxunitsx / 2}]

    if {$tmpopts(geometry) == "" || [catch {scan $tmpopts(geometry) \
      "%dx%d" width height} result]} {
        do-error "invalid geometry setting: $tmpopts(geometry)"
        return
    }
    #debug-info " width $width  halfmax $halfmax"
    set maxw [expr {$halfmax - 18}]
    #debug-info " maxw $maxw"
    if {$width > $maxw} {
        set width $maxw
    }
    # re-center map
    if {$tk_version < 8.4} {
      grid columnconfigure $w(client) 0 -weight 1
      grid columnconfigure $w(client) 2 -weight 1
    } else {
      grid columnconfigure $w(client) 0 -weight 100 -uniform a
      grid columnconfigure $w(client) 2 -weight 100 -uniform a
    }

    if {[catch {$w(LeftText) configure -width $width -height $height} result]} {
        do-error "invalid geometry setting: $tmpopts(geometry)"
        return
    }
    $w(RightText) configure -width $width -height $height

    $w(LeftLabel) configure -width $width
    $w(RightLabel) configure -width $width

    grid forget $w(LeftLabel)
    grid forget $w(RightLabel)
    grid $w(LeftLabel) -row 0 -column 0 -sticky ew
    grid $w(RightLabel) -row 0 -column 2 -sticky ew

    #NOTE: This loop is basically "testing" each NEW tag setting for syntactic
    #      validity (as well as 'installing' them). H O W E V E R ...
    #      it is EXPECTED to be tag-precedence-neutral as each name SHOULD
    #      already be in existence - thus no CHANGE in precedence should occur!
    foreach tag {difftag currtag deltag instag chgtag overlaptag inlinetag} {
        foreach win [list $w(LeftText) $w(RightText)] {
            if {[catch "$win tag configure $tag $tmpopts($tag)"]} {
                do-error "Invalid settings for \"$pref($tag)\": \
                \n\n'$tmpopts($tag)' is not a valid option string"
                # if one fails, restore the prior 'good' setting
                eval "$win tag configure $tag $opts($tag)"
                return
            }
        }
    }

    if {[catch "$w(BottomText) tag configure diff $tmpopts(bytetag)"]} {
        do-error "Invalid settings for \"$pref(bytetag)\": \
        \n\n'$tmpopts(bytetag)' is not a valid option string"
        # Again, if it fails, restore the prior 'good' setting
        eval "$w(BottomText) tag configure diff $opts(bytetag)"
        return
    }

    # tabstops require a little extra work. We need to figure out
    # the width of an "m" in the widget's font, then multiply that
    # by the tab stop width. For the bottom text widget the first tabstop
    # is adjusted by two to take into consideration the fact that we
    # add two bytes to each line (ie: "< " or "> ").
    set cwidth [font measure [$w(LeftText) cget -font] "m"]
    set tabstops [expr {$cwidth * $tmpopts(tabstops)}]
    $w(LeftText) configure -tabs $tabstops
    $w(RightText) configure -tabs $tabstops
    $w(mergeText) configure -tabs $tabstops

    $w(BottomText) configure -tabs [list [expr {$tabstops +($cwidth * 2)}] \
      [expr {2*$tabstops +($cwidth * 2)}]]

    # Set remaining 'opts' to the values from 'tmpopts'
    # PAY ATTENTION:
    #   Most options represent "data state" values and can simply be 'set',
    #   but some are TRANSITION (or 'edge') triggered and thus must notice
    #   when they are being CHANGED, more so than their final value.
    #
    #       With such 'edge' options, SEQUENCE *does* make a difference,
    #   such as the 'ignore...' group, which could force a REdiff and thus
    #   influence OTHER settings, such as skipping tasks which ultimately get
    #   redone anyway (such as inline-diff processing, which ITSELF has its
    #   own sequence issue [unwinding 2 NEARLY mutually exclusive values]).
    #       We also want to avoid the time it can take to RE-tag everything
    #   (via a call to 'remark-diffs') if we dont need to - so we have to
    #   watch for CHANGES among the options that *could* have altered tags.
    #
    # BUT WE CANT assess *all* of that until we've seen ALL the settings
    #   (or worse, write code to handle each COMBINATION that might occur)
    #
    # SO - we 'pre-arrange' those settings having their OWN issues into a
    # sub-order we can depend on (to write the logic ONE way), and then post
    # flag values we can assess AFTERWARD to enforce the larger precedence
    # issues - thus avoiding the "excess" work alluded to above.
    #
    #   (N.B.: when the startup coding invokes 'applypref', it just COPIES
    #   'opts' into 'tmpopts' first - as such, transitions will NEVER exist.)

    # First we need an 'inversion' primitive to access meta-state values ...
    set OTHER(showinline1) showinline2
    set OTHER(showinline2) showinline1

    # ... next, preloading of the keys needing their OWN precedence order ...
    #   (content of an '...opt' field that IS [and WILL] remain in use)
    lappend keys ignoreRegexLnopt ignoreRegexLn ignoreblanksopt ignoreblanks
    #   (switching among inline algorithms, including to ON or OFF)
    lappend keys showinline1 showinline2

    #   (then everything ELSE - alphabetically [a code reading convenience])
    lappend  keys adjcdr autocenter autoselect bytetag chgtag \
                  colorcbs currtag deltag diffcmd difftag editor \
                  fancyButtons filetypes geometry ignoreEmptyLn \
                  inlinetag instag mapchg mapdel mapins mapolp \
                  overlaptag predomMrg showcbs showlineview showln \
                  showmap syncscroll tabstops tagcbs tagln tagtext  \
                  textopt tmpdir toolbarIcons

    # ... finally, init the flags we need to derive - and then GET TO IT!!
    set remark 0                   ;# started as: 'remark' will not be run,
    set inlActn [set redoDiff {}]  ;#  nor will Diff or 'compute-inlines'
    foreach key $keys {
        if {"$tmpopts($key)" ne "$opts($key)"} {
            # What is transitioning ?
            switch $key {
                "ignoreEmptyLn" {
                    set redoDiff $key ;# either transition (on/off) counts
                }
                "ignoreRegexLnopt" -
                "ignoreblanksopt" {
                    # Does anyone appreciate all this work for 'auto-Diff'ing?
                    # Here we cover changes made in the "...opt" fields while
                    # REMAINING in a (non-transitional) 'ON' state...
                    set key2 [string range $key 0 end-3]
                    if {$tmpopts($key2) && $opts($key2)} {set redoDiff $key2}
                }
                "ignoreRegexLn" -
                "ignoreblanks" {
                    # Turning these 'ON' requires REFERING to a non-null opt
                    #   (N.B> depends on "...opt" ALREADY being processed)
                    if {$tmpopts($key)} {
                        # Unfortunately each has its own notion of 'non-null'
                        switch ${key}opt {
                        "ignoreblanksopt" {
                                if {"[string trim $opts(${key}opt)]" == ""} {
                                    set tmpopts($key) 0} {set redoDiff $key
                                }
                            }
                        "ignoreRegexLnopt" {
                                if {![llength $opts(${key}opt)]} {
                                    set tmpopts($key) 0} {set redoDiff $key
                                }
                            }
                        }
                    } else {set redoDiff $key} ;#but turning 'OFF': gauranteed
                }
                "showinline1" -
                "showinline2" {
                    # (meta-logic here only APPEARS convoluted)
                    # Basically has only 3 possibilities:
                    #
                    # ... a DOUBLE transition: MUST select the eventual 'ON'
                    if {"$tmpopts($OTHER($key))" ne "$opts($OTHER($key))"} {
                        if {$tmpopts($key)} {
                            #   THIS opt *is* the 'ON', but must then PRESET
                            # the other OFF (to eliminate the 2nd transition)
                            set inlActn "compute-inlines $key"
                            set opts($OTHER($key)) 0
                        }
                        # (assist "compute-inlines" with a NEEDED data flush)
                        array unset g "inline,*"

                    # ... a single OFF -> ON transition
                    #     (or ALLOWED 2nd transition from prior DOUBLE)
                    } elseif {$tmpopts($key)} {
                        set inlActn "compute-inlines $key"

                    # ... a single ON -> OFF transition
                    } else { set inlActn "compute-inlines {}" }
                }

                "mapchg" -
                "mapdel" -
                "mapins" - 
                "mapolp" {if {$g(mapheight) > 0} {set g(mapheight) -1}}

                "chgtag"     -
                "currtag"    -
                "deltag"     -
                "difftag"    -
                "inlinetag"  -
                "instag"     -
                "overlaptag" -
                "tagtext"    -
                "textopt"    {set remark 1}
            }
        }
        set opts($key) $tmpopts($key)
    }

    # interpret this binary toggle into its true value
    set opts(relief) [expr {$opts(fancyButtons) ? "flat" : "raised"}]

    # Need to TRANSLITERATE the USER input form of "Text tags" that deal with
    # the display attrs of Text, LineNumbers and/or ChangeBars, and INSTEAD
    # compute a derivation into data lists [g(scrInf,tags) and g(scrInf,cfg)]
    # that can emulate (via a canvas) what WAS FORMERLY implemented (TkDiff 4.2
    # and earlier) as individual Text widgets. This all comes together in
    # 'plot-line-info' which renders the EQUIVALENT Info data format as before,
    # but WITHOUT the potential line-skewing introduced by TK V8.5 enhancements
    translit-plot-txtags $w(LeftText) ;# L/R Text attrs identical: just grab 1

    # Walk down our DERIVED precedence-list flags and find out what needs doing
    #   (which is nothing if its all being handled by forcing a whole new Diff)
    if {$redoDiff == ""} {
        # (what about any altered tag SETTINGs ?)
        if {$remark} {
            eval $inlActn ;# MAYBE recompute inlines (so they CAN be tagged ?)
            remark-diffs
            show-status ""
        # (or how about ONLY an altered inline algorithm or on/off state ?)
        } elseif {"$inlActn" != ""} {
            eval $inlActn 1 ;# recompute the inlines, but tag ONLY them
        }
    }

    # OPA >>>
    # determine if we need to rebuild the popup menu
    if {$opts(showcontextsave) != $tmpopts(showcontextsave) }  {
        destroy $w(popupMenu)
        set opts(showcontextsave) $tmpopts(showcontextsave)
        build-popupMenu
    } 
    # OPA <<<

    # Align, (show or hide) various data (Lnums, Cbars, etc.), and we are done
    reconfigure-toolbar
    do-show-Info
    if {$g(mapheight) < 0} {map-resize} ;# in case colors changed
    do-show-map
    do-show-lineview
    update idletasks  ;# update all this BEFORE propagate is shut off !!
    grid propagate $w(client) f

    # Force a whole new Diff if user changed ANY of the result semantics
    if {$redoDiff != ""} "do-semantic-recompute $redoDiff"
}

###############################################################################
# Save customization changes.
###############################################################################
proc save {} {
    global g pref tmpopts rcfile tcl_platform
    debug-info "save ()"

    if {[file exists $rcfile]} {
        file rename -force $rcfile "$rcfile~"
    }

    set fid [open $rcfile w]

    # put the tkdiff version in the file. It might be handy later
    puts $fid "# This file was generated by $g(name) $g(version)"
    puts $fid "# [clock format [clock seconds]]\n"
    puts $fid "set prefsFileVersion {$g(version)}\n"

    # now, put all of the preferences in the file
    foreach key [lsort [array names pref]] {
        regsub -- "\n" $pref($key) "\n# " comment
        puts $fid "# $comment"
        puts $fid "define $key {$tmpopts($key)}\n"
    }

    # ... and any custom code
    puts $fid "# custom code"
    puts $fid "# put any custom code you want to be executed in the"
    puts $fid "# following block. This code will be automatically executed"
    puts $fid "# after the GUI has been set up but before the diff is "
    puts $fid "# performed. Use this code to customize the interface if"
    puts $fid "# you so desire."
    puts $fid "#  "
    puts $fid "# Even though you can't (as of version 3.09) edit this "
    puts $fid "# code via the preferences dialog, it will be automatically"
    puts $fid "# saved and restored if you do a SAVE from that dialog."
    puts $fid ""
    puts $fid "# Unless you really know what you are doing, it is probably"
    puts $fid "# wise to leave this unmodified."
    puts $fid ""
    puts $fid "define customCode {\n[string trim $tmpopts(customCode) \n]\n}\n"

    close $fid

    if {$::tcl_platform(platform) == "windows"} {
        file attribute $rcfile -hidden 1
    }
}

###############################################################################
# Text has scrolled, update scrollbars and synchronize windows
###############################################################################
proc hscroll-sync {id args} {
    global g w opts

    # If ignore_hevent is true, we've already taken care of scrolling.
    # We're only interested in the first event.
    if {$g(ignore_hevent,$id)} {
        return
    }

    # Scrollbar sizes
    set size1 [expr {[lindex [$w(LeftText) xview] 1] - [lindex \
      [$w(LeftText) xview] 0]}]
    set size2 [expr {[lindex [$w(RightText) xview] 1] - [lindex \
      [$w(RightText) xview] 0]}]

    if {$opts(syncscroll) || $id == 1} {
        set start [lindex $args 0]

        if {$id != 1} {
            set start [expr {$start * $size2 / $size1}]
        }
        $w(LeftHSB) set $start [expr {$start + $size1}]
        $w(LeftText) xview moveto $start
        set g(ignore_hevent,1) 1
    }
    if {$opts(syncscroll) || $id == 2} {
        set start [lindex $args 0]
        if {$id != 2} {
            set start [expr {$start * $size1 / $size2}]
        }
        $w(RightHSB) set $start [expr {$start + $size2}]
        $w(RightText) xview moveto $start
        set g(ignore_hevent,2) 1
    }

    # This forces all the event handlers for the view alterations
    # above to trigger, and we lock out the recursive (redundant)
    # events using ignore_hevent.
    update idletasks

    # Restore to normal
    set g(ignore_hevent,1) 0
    set g(ignore_hevent,2) 0
}

###############################################################################
# Text has scrolled, update scrollbars and synchronize OTHER Text window
###############################################################################
proc vscroll-sync {id y0 y1} {
    global g w opts

    if {$id == 1} {
        $w(LeftVSB) set $y0 $y1
    } else {
        $w(RightVSB) set $y0 $y1
    }

    # if syncing is disabled, we're done. This prevents a nasty
    # set of recursive calls
    if {[info exists g(disableSyncing)]} {
        return
    }

    # set the flag; this makes sure we only get called once
    set g(disableSyncing) 1

    map-move-thumb $y0 $y1

    # If syncing is turned on,
    #    select nearest visible diff region (if requested),
    # then scroll OTHER window.
    if {$opts(syncscroll)} {
        if {$opts(autoselect) && $g(count) > 0} {
            set winhalf [expr {[winfo height $w(RightText)] / 2}]
            set i [find-diff [expr {int([$w(RightText) index @1,$winhalf])}]]

            # have we found a diff other than the current diff?
            if {$i != $g(pos)} {
                # Also, make sure the diff is visible. If not, we won't
                # change the current diff region...
                set topline [$w(RightText) index @0,0]
                set bottomline [$w(RightText) index @0,10000]
                set s1 [lindex $g(scrInf,[hunk-id $i]) 0]
                if {$s1 >= $topline && $s1 <= $bottomline} {
                    move $i 0 1
                }
            }
        }

        if {$id == 1} {
            $w(RightText) yview moveto $y0
            $w(RightVSB) set $y0 $y1
        } else {
            $w(LeftText) yview moveto $y0
            $w(LeftVSB) set $y0 $y1
        }
    }

    # we apparently automatically process idle events after this
    # proc is called. Once that is done we'll unset our flag
    after idle {catch {unset g(disableSyncing)}}
}

###############################################################################
# Make a miniature map of the diff regions
###############################################################################
proc create-map {name mapwidth mapheight} {
    global g w opts map

    set map $name

    # Text widget always contains blank line at the end
    set lines [expr {double([$w(LeftText) index end]) - 2}]
    if { $lines <= 0.0 } {
        set lines 1.0
    }
    set factor [expr {$mapheight / $lines}]

    # We add some transparent stuff to make the map fill the canvas
    # in order to receive mouse events at the very bottom.
    $map blank
    $map put \#000 -to 0 $mapheight $mapwidth $mapheight

    # Paint color stripes per type of every hunk
    foreach hID $g(diff) {
        lassign $g(scrInf,$hID) S E na na C1 na na C2

        set y [expr {int(($S - 1) * $factor) + $g(mapborder)}]
        set size [expr {round(($E - $S + 1) * $factor)}]
        if {$size < 1} {
            set size 1
        }
        switch -- "[append C1 $C2]" {
        "-"  { set color $opts(mapdel) }
        "+"  { set color $opts(mapins) }
        "!!" { set color [expr {[info exists g(overlap$hID)] ? \
                         $opts(mapolp) : $opts(mapchg)}]
             }
        }

        $map put $color -to 0 $y $mapwidth [expr {$y + $size}]

    }

    # let's draw a rectangle to simulate a scrollbar thumb. The size
    # isn't important since it will get resized when map-move-thumb
    # is called...
    $w(mapCanvas) create line 0 0 0 0 -width 1 -tags thumbUL -fill white
    $w(mapCanvas) create line 1 1 1 1 -width 1 -tags thumbLR -fill black
    $w(mapCanvas) raise thumb

    # now, move the thumb
    eval map-move-thumb [$w(LeftText) yview]

}

###############################################################################
# Resize map to fit window size
###############################################################################
proc map-resize {args} {
    global g w opts

    set mapwidth [winfo width $w(map)]
    set g(mapborder) [expr {[$w(map) cget -borderwidth] + [$w(map) cget \
      -highlightthickness]}]
    set mapheight [expr {[winfo height $w(map)] - $g(mapborder) * 2}]

    # We'll get a couple of "resize" events, so DON'T draw a map ...
    # - unless the map size has changed -OR- 
    # - we don't have a map and don't want one (so don't make one)
    if {$mapheight == $g(mapheight) \
    || ($g(mapheight) == 0 && $opts(showmap) == 0)} {
        return
    }

    # This seems to happen on Windows!? _After_ the map is drawn the first time
    # another event triggers and [winfo height $w(map)] is then 0...
    if {$mapheight < 1} {
        return
    }

    set g(mapheight) $mapheight
    set g(mapwidth) $mapwidth
    create-map map $mapwidth $mapheight
}

###############################################################################
# Toggle showing the line comparison window
###############################################################################
proc do-show-lineview {{showLineview {}}} {
    global w opts

    if {$showLineview != {}} {
        set opts(showlineview) $showLineview
    }

    if {$opts(showlineview)} {
        grid $w(BottomText) -row 3 -column 0 -sticky ew -columnspan 4
    } else {
        grid forget $w(BottomText)
    }
}

###############################################################################
# Toggle showing inline comparison
###############################################################################
proc do-show-inline {which {showInline {}}} {
    global opts

    # translation tbl TO mutually-disjoint option
    set other(showinline1) showinline2
    set other(showinline2) showinline1

    if {$showInline != {}} {
        set opts($which) $showInline
    }

    # mutually disjoint options
    #   Turn requested option ON ?
    if {$opts($which)} {
        #   Yes, but was OTHER option already ON ?
        if {$opts($other($which))} {
            #   Yes - so mark IT as OFF
            set opts($other($which)) 0
        }
    } elseif {!$opts($other($which))} {
        # No, turn requested option OFF ('other' is already OFF)
        set which {}                ;# and dont generate more
    }
    # POSSIBLY recompute but ALWAYS retag (even if only removal)
    compute-inlines $which true
}

###############################################################################
# Toggle showing map or not
###############################################################################
proc do-show-map {{showMap {}}} {
    global w opts

    if {$showMap != {}} {
        set opts(showmap) $showMap
    }

    if {$opts(showmap)} {
        grid $w(map) -row 1 -column 1 -stick ns
    } else {
        grid forget $w(map)
    }
}

###############################################################################
# Find the diff INDEX nearest to SCREENLINE $line.
###############################################################################
proc find-diff {line} {
    global g w

    # Binary search for i'th hunk (by its 1st line) closest to $line
    for {set low 1; set high $g(count); set i [expr {($low + $high) / 2}]} \
                {$i >= $low} {set i [expr {($low + $high) / 2}]} {

        if {$line < [lindex $g(scrInf,[hunk-id $i]) 0]} {
                 set high [expr {$i-1}]
        } else { set low  [expr {$i+1}] }
    }

    # If next diff is closer than the one found, use it instead
    if {$i > 0 && $i < $g(count)} {
        set nexts1 [lindex $g(scrInf,[hunk-id [expr {$i + 1}]]) 0]
        set e1     [lindex $g(scrInf,[hunk-id $i])              1]
        if {$nexts1 - $line < $line - $e1} {
            incr i
        }
    }

    return $i
}

###############################################################################
# Calculate number of lines in diff region
# hID            Diff hunk identifier
# version   (1, 2, 12, 21) left and/or right window version
###############################################################################
proc diff-size {hID version} {
    global g

    lassign $g(scrInf,$hID) S E P(1) na na P(2)

    switch -- $version {
    1  -
    2  { set lines [expr {$E - $S - $P($version) + 1}] }
    12 -
    21 { set lines [expr {$E - $S - $P(1) + $E - $S - $P(2) + 2}] }
    }
    return $lines
}

###############################################################################
# Toggle showing merge preview or not
###############################################################################
proc do-show-merge {{showMerge ""}} {
    global g w
    debug-info "do-show-merge ($showMerge)"

    if {$showMerge != ""} {
        set g(showmerge) $showMerge
    }

    # Re-cfg buttons to hint at state of intended Merge FILENAME (when visible)
    if {$g(showmerge)} {
        if {$g(mergefileset)} {
            $w(mergeWriteAndExit) configure -text "Save & Exit"
            $w(mergeWrite) configure -text "Save"
        } else {
            $w(mergeWriteAndExit) configure -text "Save & Exit..."
            $w(mergeWrite) configure -text "Save..."
        }
        if {![winfo ismapped $w(merge)]} {
            wm deiconify $w(merge)
            $w(mergeText) configure -state disabled ;# for paranoia's sake
            focus -force $w(mergeText)
            merge-center
        }
    } elseif {[winfo ismapped $w(merge)]} { wm withdraw $w(merge) }
}

###############################################################################
# Create Merge preview window
###############################################################################
proc build-merge-preview {} {
    global g w opts
    debug-info "build-merge-preview ()"

    set win [toplevel $w(merge)]
    set rx [winfo rootx $w(tw)]
    set ry [winfo rooty $w(tw)]
    set px [winfo width $w(tw)]
    set py [winfo height $w(tw)]
    #debug-info "  rx $rx  ry $ry  px $px  py $py"
    set x [expr {$rx + $px / 4}]
    set y [expr {$ry + $py / 2}]
    wm geometry $win "+${x}+$y"

    wm group $win $w(tw)
    wm title $win "$g(name) Merge Preview"
    wm withdraw $w(merge)

    frame $win.bottom
    frame $win.top -bd 1 -relief sunken

    # Certain widgets need external handles, remainder are local
    set w(mergeInfo) $win.top.cvs
    set w(mergeText) $win.top.text
    set w(mergeVSB) $win.top.vsb
    set w(mergeHSB) $win.top.hsb
    set w(mergeWrite) $win.bottom.mergeWrite
    set w(mergeWriteAndExit) $win.bottom.mergeWriteAndExit

    # Window and scrollbars
    scrollbar $w(mergeHSB) -orient horizontal -command [list $w(mergeText) \
      xview]
    scrollbar $w(mergeVSB) -orient vertical -command [list $w(mergeText) yview]

    text $w(mergeText) -bd 0 -takefocus 1 -yscrollcommand [list $w(mergeVSB) \
      set] -xscrollcommand [list $w(mergeHSB) set]

    canvas $w(mergeInfo) -highlightthickness 0

    pack $win.bottom -side bottom -fill x
    pack $win.top -side top -fill both -expand yes -ipadx 5 -ipady 10
    grid $w(mergeInfo) -row 0 -column 0 -sticky nsew
    grid $w(mergeText) -row 0 -column 1 -sticky nsew
    grid $w(mergeVSB) -row 0 -column 2 -sticky ns
    grid $w(mergeHSB) -row 1 -column 0 -columnspan 2 -sticky ew

    grid rowconfigure $win.top 0 -weight 1
    grid rowconfigure $win.top 1 -weight 0

    grid columnconfigure $win.top 0 -weight 0
    grid columnconfigure $win.top 1 -weight 1
    grid columnconfigure $win.top 2 -weight 0

    # buttons
    button $win.bottom.mRecenter -width 8 -text "ReCenter" -underline 0 \
        -command merge-center

    button $win.bottom.mDismiss -width 8 -text "Dismiss" -underline 0 \
        -command "do-show-merge 0"

    button $win.bottom.mExit -width 8 -text "Exit $g(name)" -underline 0 \
        -command {do-exit}

    # These last two buttons NAMES are later re-cfg'd with "..." appended
    # when g(mergefileset)==0 to signify a file browser popup will occur
    # (provided the merge window itself is actually visible)
    button $w(mergeWrite) -width 8 -text "Save" -underline 0 \
        -command {merge-write-file}

    button $w(mergeWriteAndExit) -width 8 -text "Save & Exit" \
        -underline 8 -command {merge-write-file 1 }

    pack $win.bottom.mDismiss -side right -pady 5 -padx 10
    pack $win.bottom.mRecenter -side right -pady 5 -padx 1
    pack $w(mergeWrite) -side right -pady 5 -padx 1 -ipadx 1
    pack $w(mergeWriteAndExit) -side right -pady 5 -padx 1 -ipadx 1
    pack $win.bottom.mExit -side right -pady 5 -padx 1

    # Insert tag defs (in precedence order)
    # N.B> This matters to 'plot-merge-info':
    #    we NEED 'diffR' or 'diffL' as lowest precedence
    #    (whichever applies to the diff line in question).
    #    Its an encoding trick noting which SIDE contrib'ed a diff line.
    $w(mergeText) configure {*}$opts(textopt)
    $w(mergeText) tag configure {diffL} {*}$opts(difftag)
    $w(mergeText) tag configure {diffR} {*}$opts(difftag)
    $w(mergeText) tag configure {currtag} {*}$opts(currtag)
    $w(mergeText) tag raise sel ;# Keep this on top

    # adjust the tabstops
    set cwidth [font measure [$w(mergeText) cget -font] "m"]
    set tabstops [expr {$cwidth * $opts(tabstops)}]
    $w(mergeText) configure -tabs $tabstops

    wm protocol $w(merge) WM_DELETE_WINDOW {do-show-merge 0}

    common-navigation $w(mergeText)
}

###############################################################################
# Write merge preview to file (after optionally confirming filename)
###############################################################################

# OPA <<<
# Replaced merge-write-file with 4 procs

proc write-merge-file { fileName } {
    global g w opts
    debug-info "merge-write-file \
        ([expr {$g(mergefileset) ? "into" : "confirming" }] $g(mergefile))"

    if {!$g(mergefileset)} {
        # Uncertain of wanting 'nativename' .vs. 'normalize' here...
        #   (each supposedly yields an absolute name)
        set path [file nativename $g(mergefile)]
        # Regardless, next SPLIT that into dir & file, and pass as PIECES ...
        # otherwise any/all user "directory browsing" will be IGNORED simply
        # because the '-initialfile' was passed as an absolute path!!
        set path [tk_getSaveFile -filetypes $opts(filetypes) \
              -initialdir  [file dirname $path] \
              -initialfile [file   tail  $path] -defaultextension "" \
              -parent [expr {[winfo ismap $w(merge)]? $w(merge) : $w(client)}]]

        if {[string length $path] > 0} {
            set g(mergefile) $path
        } else return ;# file browser cancelled out - DO NOT WRITE or EXIT
    }

    # Actually write merge output to the given filename
    set hndl [open $fileName w]
    set txt [$w(mergeText) get 1.0 end-1lines]
    puts -nonewline $hndl $txt
    close $hndl
}

proc write-as-left {} {
    global g finfo

    set g(mergefileset) 1
    write-merge-file "$finfo(pth,1)"
    set g(mergefileset) 0
}

proc write-as-right {} {
    global g finfo

    set g(mergefileset) 1
    write-merge-file "$finfo(pth,2)"
    set g(mergefileset) 0
}

proc merge-write-file { { andExit 0} } {
    global g
    write-merge-file "$g(mergefile)"
    if {$andExit} do-exit
}
# OPA <<<

###############################################################################
# Add a mark where each diff begins and tag each region so they are visible.
# Default case ONLY WORKS when pre-loaded text is the original (Left) version.
# Optional arg allows adding/removing (ie. editting) hunk identifiers later on
###############################################################################
proc merge-add-marks {{hIDS {}}} {
    global g w
    debug-info "merge-add-marks ($hIDS)"

    # Mark ALL lines first, so inserting choices won't mess up line numbers.
    #   N.B> WHEN hIDS is supplied, it MUST be homogeneous: ALL or NONE can
    #   pre-exist. And, when they dont exist, ascending order is REQUIRED.
    if {"$hIDS" != {}} {
        if {"mark[lindex $hIDS 0]" in [$w(mergeText) mark names]} {
            # Exists - so remove it (and every MERGE thing pertaining to it)
            foreach hID "$hIDS" {
                # CRITICAL: Put the merge text content BACK to a "Left" view !
                #  Then eliminate the mark AND choice (caller zaps the rest)
                merge-select-version $hID $g(merge$hID) 1
                $w(mergeText) mark unset mark$hID
                unset g(merge$hID)
            }
            return 

        } else {
            # NEW hID - Find WHERE to plant each new MARK
            #   Apologies for the convoluted logic here, but we need a PRIOR
            # hunk location as an anchor (if there is one.) If NOT, then NO
            # numbers need adjusting; But if there IS, the rule of "Left only"
            # view DOES NOT APPLY to that FIRST anchor. Each planted MARK then
            # BECOMES the new anchor as we loop and is ALWAYS in "Left view"
            set prvHid {}
            foreach hID "$hIDS" {
                # Identify the 1st closest PRIOR hunk INDEX (if unknown)
                if {$prvHid == {}} {
                    if {[set i [hunk-ndx $hID]] > 1} {incr i -1}
                }
                # If not YET known, produce prvHid and verify it really IS a
                # "PRIOR" hunk, setting 'i' to ITS merge-choice value if yes
                if {$prvHid != "" || ( "[set prvHid [hunk-id $i]]" != "$hID" \
                                     && [set i $g(merge$prvHid)])} {
                    # Now determine WHERE that anchor starts in 'mergeText',
                    # ADDing its CURRENT SIZE (minus 1), plus the STARTING
                    # position of the NEW hunk
                    set S [expr {int([$w(mergeText) index mark$prvHid]) \
                                         +  [diff-size $prvHid $i] - 1  \
                                         +  [lindex $g(scrInf,$hID) 0]} ]
                    # Using SCREEN numbering is OK because when we arrange
                    # to subtract the screen END Lnum of the PRIOR hunk ...
                    set O [lindex $g(scrInf,$prvHid) 1]
                    # ... it will all convert to the NEW hunk location
                } else { lassign $g(scrInf,$hID) S na na O }

                # Set the NEW mark (and eventually fall thru to tagging)
                $w(mergeText) mark set mark$hID [incr S -$O].0
                $w(mergeText) mark gravity mark$hID left
                set prvHid $hID ;# This becomes the NEXT anchor (as we loop)
                set i 1         ;# and (by defn) is ALWAYS in a "Left" view
            }
        }
    } else { ;# Do the entire Text (MUST BE in PURE LEFT context!!)
        foreach hID [set hIDS $g(diff)] {
            lassign $g(scrInf,$hID) S na na O

            $w(mergeText) mark set mark$hID [incr S -$O].0
            $w(mergeText) mark gravity mark$hID left
        }
    }

    # ... finally, select per merge CHOICES and TAG the regions for each
    set currdiff [hunk-id $g(pos)]
    foreach hID $hIDS {

        # Tag and/or Insert designated Left or Right window text versions
        # N.B.: works PROVIDED the merge hID range is IN a "Left copy" state
        if {$g(merge$hID) == 1} {
            # (But dont do a Left 'a'-type hunk - it's not visible)
            if {![string match "*a*" "$hID"]} {
                add-tag $w(mergeText) diffL {} mark$hID "+[diff-size $hID 1]"
            }
        } else { merge-select-version $hID 1 $g(merge$hID) }

        # Also attach "currtag" if/when correct hunk encountered
        if {"$hID" == "$currdiff"} {
            add-tag $w(mergeText) currtag {} \
                                     mark$hID "+[diff-size $hID $g(merge$hID)]"
        }
    }
}

###############################################################################
# Remove/Re-Add hunk content to the merge window
# hID               diff hunk identifier
# oldversion   (1, 2, 12, 21) previous merge choice
# newversion   (1, 2, 12, 21) new merge choice
###############################################################################
proc merge-select-version {hID oldversion newversion} {
    global g w

    catch {
        if {[set tot [diff-size $hID $oldversion]]} {
            $w(mergeText) configure -state normal
            $w(mergeText) delete mark$hID "mark${hID}+${tot}lines"
            $w(mergeText) configure -state disabled
        }
    }

    # Start of hunk in screen coordinates
    set S [lindex $g(scrInf,$hID) 0]

    # Get the text to insert directly from window
    switch -- $newversion {
        1 {
            if {[set tot [set i [diff-size $hID 1]]]} {
                lappend txt [$w(LeftText)  get $S.0 $S.0+${i}lines] diffL
            } else {return}
        }
        2 {
            if {[set tot [set i [diff-size $hID 2]]]} {
                lappend txt [$w(RightText) get $S.0 $S.0+${i}lines] diffR
            } else {return}
        }
        12 {
            if {[set tot [set i [diff-size $hID 1]]]} {
                lappend txt [$w(LeftText)  get $S.0 $S.0+${i}lines] diffL
            }
            if {[set tot [diff-size $hID 2]]} {
                lappend txt [$w(RightText) get $S.0 $S.0+${i}lines] diffR
                incr tot $i
            }
        }
        21 {
            if {[set tot [set i [diff-size $hID 2]]]} {
                lappend txt [$w(RightText) get $S.0 $S.0+${i}lines] diffR
            }
            if {[set i [diff-size $hID 1]]} {
                lappend txt [$w(LeftText)  get $S.0 $S.0+${i}lines] diffL
                incr tot $i
            }
        }
    }

    # Normally (prior to Combine/Split) mark$hID would ALWAYS have been the
    # sole Left-'gravitized' Text mark (attached to the newline ending the
    # NON-hunk line PRECEEDING the hunk start edge) at any ONE Text position.
    #   But since then, MULTIPLE marks (referring to optionally merge-able
    # abutted hunks) CAN COINCIDE, possibly only for a moment (between the
    # deletion and add done in this proc), thus causing them to cluster to the
    # front of ALL the possibilities - despite the need for SOME of those
    # choices to logically FOLLOW the insertion being made (to maintain linear
    # order).
    #   Thus we must analyze EVERY insertion for such clustering and POSSIBLY
    # adjust the gravities of SOME to ensure the hunk ordering linearity
    # imposed by g(diff) remains intact...
    set pos [hunk-ndx $hID]
    set regravitize {}
    foreach {na markID na} [$w(mergeText) dump -mark mark$hID] {
        if {[hunk-ndx [string range $markID 4 end]] > $pos} {
            $w(mergeText) mark gravity $markID right
            lappend regravitize $markID
        }
    }

    # NOW insert AND tag it (txt holds PAIRS of textlines AND assoc tag)
    $w(mergeText) configure -state normal
    $w(mergeText) insert mark$hID {*}$txt
    $w(mergeText) configure -state disabled
    if {"$hID" == "[hunk-id $g(pos)]"} {
        add-tag $w(mergeText) currtag {} mark$hID "+$tot"
    }

    # ... Nevertheless, we always LEAVE all gravities as 'Left' AFTER the
    # insertion, just so we need not guess (or ask) the next time around.
    foreach {markID} $regravitize { $w(mergeText) mark gravity $markID left }
}

###############################################################################
# Center the merge region in the merge window
###############################################################################
proc merge-center {} {
    global g w

    # bail if there are no diffs
    if {$g(count) == 0} {
        return
    }

    # Size of diff in lines of text
    set hID [hunk-id $g(pos)]
    set difflines [diff-size $hID $g(merge$hID)]

    # Window height in percent
    set yview [$w(mergeText) yview]
    set ywindow [expr {[lindex $yview 1] - [lindex $yview 0]}]

    # First line of diff and total number of lines in window
    set firstline [$w(mergeText) index mark$hID]
    set totallines [$w(mergeText) index end]

    if {$difflines / $totallines < $ywindow} {
        # Diff fits in window, center it
        $w(mergeText) yview moveto [expr {($firstline + $difflines / 2) / \
          $totallines - $ywindow / 2}]
    } else {
        # Diff too big, show top part
        $w(mergeText) yview moveto [expr {($firstline - 1) / $totallines}]
    }
}

###############################################################################
# Update the merge preview window with the current merge choice
# newversion   1 or 2, new merge choice
###############################################################################
proc do-merge-choice {newversion} {
    global g w opts
    debug-info "do-merge-choice ($newversion)"

    set hID [hunk-id $g(pos)]
    $w(mergeText) configure -state normal
    merge-select-version $hID $g(merge$hID) $newversion
    $w(mergeText) configure -state disabled
    set g(merge$hID) $newversion

    # Must ask user (when this is a collision) if their choice CLEARed it
    if {[info exists g(overlap$hID)]} {
        after idle [subst -nocommands {
                if {{yes} == [tk_messageBox -type yesno -icon question  \
                -title {Please Confirm} -parent $w(client) -default no  \
                -message "Did this choice RESOLVE the collision ?" ]}   \
                     { unset g(overlap$hID)
                       set-tag $hID currtag overlaptag
                       if {$opts(showmap) || $g(mapheight)} \
                           {set g(mapheight) -1 ; map-resize}
                     }
        }]
    }

    if {$g(showmerge) && $opts(autocenter)} {
        merge-center
    }
    set g(toggle) $newversion
}

###############################################################################
# Extract the start and end lines for file1 and file2 from the diff header
# stored in "line".
###############################################################################
proc extract {line} {
    # the line darn well better be of the form <range><op><range>, where op is
    # one of "a","c" or "d" (possibly in EITHER case). range will either be a
    # single number or two numbers separated by a comma.

    # is this a cool regular expression, or what? :-)
    regexp -nocase {([0-9]*)(,([0-9]*))?([acd])([0-9]*)(,([0-9]*))?} $line \
      matchvar s1 x e1 op s2 x e2

    if {[info exists s1] && [info exists s2]} {

        if {"$e1" == ""} { set e1 $s1 }
        if {"$e2" == ""} { set e2 $s2 }

        return [list $s1 $e1 $s2 $e2 $op]
    } else {
        fatal-error "Cannot parse output from diff:\n$line"
    }

}

###############################################################################
# Add a tag to a region (of chars on a given line -OR- of lines themselves).
###############################################################################
proc add-tag {wgt tag line start end} {
    global g

    if {"$line" eq {}} {
        # interpret OUR shorthand notation allowed for line tagging
        #   (args passed are INTEGERS - convert to INDICE syntax)
        if {[string match \[0-9\]* "$start"]} {append start ".0"}
        if {[string match \[0-9\]* "$end"]} {append end ".0"}
        # 'end' may begin with JUST a plus/minus value
        #   (+/-)xxx   becomes   "start (+/-)xxx lines"
        #      xxx     becomes   "xxx +1 lines"
        set end [expr {[string match \[-+\]* "$end"] \
                        ? "$start${end}lines" : "$end+1lines"}]
        $wgt tag add $tag $start $end              ;# the lines themselves
    } else {
        $wgt tag add $tag $line.$start $line.$end  ;# chars ON $line
    }
    #debug-info "add-tag ($wgt $tag $line $start $end)"
}

###############################################################################
# Change the tag for a diff region.
# 'hID' is the region hunk identifier (from the g(diff) list)
# If 'oldtag' is present, first remove it from the region
# If 'setpos' is non-zero, make sure the region is visible.
# Returns the diff hunk identifier.
###############################################################################
proc set-tag {hID newtag {oldtag ""} {setpos 0}} {
    global g w opts

    # Figure out which lines we need to address...
    if {![info exists g(scrInf,$hID)]} {
        # This may seem an ODD place for this to be but it IS correct
        #   If the REASON we can't find the designated hID is because there is
        # NONE TO BE FOUND (zero diffs) its POSSIBLE we just did a newDiff,
        # reloading all of the Text widgets and their CONTENTS.
        #   We needed to DELAY till here so g(startPhase) could be reset to
        # allow plot actions to occur. This just fires the trace to "re-plot"
        if {!$g(count)} {
            $w(LeftText)  see 1.0
            $w(RightText) see 1.0
            if {$g(showmerge)} {$w(mergeText) see 1.0}
        }
        return ""
    }
    lassign $g(scrInf,$hID) S E na na cL na na cR

    # Remove old tag
    if {"$oldtag" != ""} {
        $w(LeftText)  tag remove $oldtag $S.0 $E.0+1lines
        $w(RightText) tag remove $oldtag $S.0 $E.0+1lines

        # Of tags to remove, only "currtag" makes sense for the Merge window
        if {"$oldtag" == "currtag"} { catch {
            set lines [diff-size $hID $g(merge$hID)]
            $w(mergeText) tag remove $oldtag mark$hID "mark$hID+${lines}lines"}
        }
    }

    # Map chgbar marker(s) into applicable tag definition (danger: cL modified)
    switch -- [append cL $cR] {
    "-"  { set coltag deltag }
    "+"  { set coltag instag }
    "!!" { set coltag [expr {[info exists g(overlap$hID)] ? \
                                             "overlaptag" : "chgtag" }]
         }
    }

    # Add new tag
    if {$opts(tagtext)} {
        add-tag $w(LeftText)  $newtag {} $S $E
        add-tag $w(RightText) $newtag {} $S $E
        add-tag $w(RightText) $coltag {} $S $E
    }

    if {[set full [diff-size $hID $g(merge$hID)]]} {
        # Merge must map 'difftag' into SIDE-SPECIFIC equivalent tags
        if {"$newtag" == "difftag"} {
            # We'll use meta-programming to unwind and map the encoding
            # so create the transforms we need to access the pieces
            set sideTag([set side2(21) [set side1(12) 1]]) "diffL"
            set sideTag([set side2(12) [set side1(21) 2]]) "diffR"

            if {$g(merge$hID) < 10} {
                # Its a single side and occupies the 'full' length ...
                lappend tags $sideTag($g(merge$hID)) mark$hID $full
            } else {
                # ... or its  2 sides that SUMS to the full length (beware of 0)
                if {[set first [diff-size $hID $side1($g(merge$hID))]} {
                    lappend tags $sideTag($side1($g(merge$hID))) mark$hID $first
                } else {
                    lappend tags $sideTag($side2($g(merge$hID))) mark$hID $first
                }
                # Append the 2nd piece (if needed)
                if {$first && $first != $full} {
                    lappend tags $sideTag($side2($g(merge$hID))) \
                                  mark$hID+${first}lines [expr {$full - $first}]
                }
            }
        } else {lappend tags $newtag mark$hID $full}
        foreach {tag where lines} "$tags" {
            add-tag $w(mergeText) $tag {} $where "+$lines"
        }
    }

    # Move the view on both text widgets so that the new region is visible.
    if {$setpos} {
        if {$opts(autocenter)} {
            center
        } else {
            $w(LeftText) see $S.0
            $w(RightText) see $S.0
            $w(LeftText) mark set insert $S.0
            $w(RightText) mark set insert $S.0

            if {$g(showmerge)} {
                $w(mergeText) see mark$hID
            }
        }
    }

    return $hID
}

###############################################################################
# moves to the diff nearest the insertion cursor or the mouse click,
# depending on $mode (which should be either "xy" or "mark")
###############################################################################
proc moveNearest {window mode args} {
    switch -- $mode {
    "xy" {
            set x [lindex $args 0]
            set y [lindex $args 1]
            set index [$window index @$x,$y]
        }
    "mark" {
            set index [$window index [lindex $args 0]]
        }
    }

    move [find-diff [expr {int($index)}]] 0 1
}

###############################################################################
# this is called to decode a combobox entry into which hunk to jump to
###############################################################################
proc moveTo {window value} {
    global g w

    # we know that the value is prefixed by the number/index of
    # the diff the user wants. So, just grab that out of the string
    regexp {([0-9]+) *:} $value matchVar index
    move $index 0 1
}

###############################################################################
# this is called when the user scrolls the map thumb interactively.
###############################################################################
proc map-seek {y} {
    global g w

    set yview [expr {(double($y) / double($g(mapheight)))}]

    # Show text corresponding to map;
    $g(activeWindow) yview moveto $yview
}

###############################################################################
# Move the "current" diff indicator (i.e. go to a different diff region:
# If "relative" is 0 go to the GIVEN diff number; else treat as increment (+/-)
# Also accepts keywords "first" and "last"
###############################################################################
proc move {value {relative 1} {setpos 1}} {
    global g w
    debug-info "move ($value $relative $setpos)"

    if {$value == "first"} {
        set value 1
        set relative 0
    }
    if {$value == "last"} {
        set value $g(count)
        set relative 0
    }

    # Remove old 'curr' tag
    set-tag [hunk-id $g(pos)] difftag currtag

    # Bump 'pos' (one way or the other).
    if {$relative} {
        set g(pos) [expr {$g(pos) + $value}]
    } else {
        set g(pos) $value
    }

    # Range check 'pos'.
    set g(pos) [max $g(pos) 1]
    set g(pos) [min $g(pos) $g(count)]

    # Set new 'curr' tag
    set g(currdiff) [set-tag [hunk-id $g(pos)] currtag "" $setpos]

    # update the buttons, etc.
    update-display

}

###############################################################################
# Align the availability of UI elements to the tools CURRENT context conditions
###############################################################################
proc update-display {} {
    global g w opts finfo
    debug-info "update-display () from [info level -1]"

    #debug-info "  init_OK $g(initOK)"
    #debug-info "  startPhase $g(startPhase)"
    #if {!$g(startPhase)} return
    # The coding approach here is somewhat unusual:
    #   It's organized as sequential LAYERS of decisions instead of a single
    #   TREE of chained tests to arrive at each items proper '-state' setting.
    #
    #   To limit "flickering" of widgets, that choice of LAYER is critical.
    #
    #   Its best to try avoiding toggling the same widget from multiple layers,
    #   particularly as "else" clauses, only to nearly ALWAYS redo it at a
    #   LOWER layer. Think about the frequency that each layer-test is most
    #   likely to branch during general operation of the tool.
    #
    #   This works (and results in fewer code lines) - but its confusing to
    #   assess WHERE (which layer) any given widget BELONGS at and if it
    #   NEEDS to be repeated at MULTIPLE levels

    ##### First layer - Does the tool have enough input to attempt a diff ?
    if {!$g(initOK)} {
        # disable darn near everything

        foreach b [list rediff splitDiff cmbinDiff find \
                   prevDiff firstDiff nextDiff lastDiff centerDiffs \
                   mergeChoice1 mergeChoice2 mergeChoice12 mergeChoice21] {
            $w(${b}_im) configure -state disabled
            $w(${b}_tx) configure -state disabled
        }
        foreach menu [list $w(popupMenu) $w(viewMenu)] {
            $menu entryconfigure "Previous*" -state disabled
            $menu entryconfigure "First*" -state disabled
            $menu entryconfigure "Next*" -state disabled
            $menu entryconfigure "Last*" -state disabled
            $menu entryconfigure "Center*" -state disabled
        }
        $w(popupMenu) entryconfigure "Find..." -state disabled
        $w(popupMenu) entryconfigure "Find Nearest*" -state disabled
        $w(popupMenu) entryconfigure "Edit*" -state disabled

        $w(editMenu) entryconfigure "Find*" -state disabled
        $w(editMenu) entryconfigure "Edit File 1" -state disabled
        $w(editMenu) entryconfigure "Edit File 2" -state disabled

        $w(fileMenu) entryconfigure "File List" -state disabled
        $w(fileMenu) entryconfigure "Write*" -state disabled
        $w(fileMenu) entryconfigure "Recompute*" -state disabled

        $w(mergeMenu) entryconfigure "Show*" -state disabled
        $w(mergeMenu) entryconfigure "Write*" -state disabled -label \
         [expr {$g(mergefileset) ? "Write Merge File" : "Write Merge File..."}]

        $w(markMenu) entryconfigure "Mark*" -state disabled
        $w(markMenu) entryconfigure "Clear*" -state disabled

    } else {
        # these are generally enabled, assuming we have (or about to)
        # run a proper DIFF of a couple of files
        foreach b [list rediff find prevDiff firstDiff nextDiff lastDiff \
                   centerDiffs mergeChoice1 mergeChoice2 mergeChoice12   \
                   mergeChoice21] {
            $w(${b}_im) configure -state normal
            $w(${b}_tx) configure -state normal
        }

        $w(popupMenu) entryconfigure "Find..." -state normal
        $w(popupMenu) entryconfigure "Find Nearest*" -state normal
        $w(popupMenu) entryconfigure "Edit*" -state normal

        $w(editMenu) entryconfigure "Find*" -state normal
        $w(editMenu) entryconfigure "Edit File 1" -state normal
        $w(editMenu) entryconfigure "Edit File 2" -state normal

        if {$finfo(fPairs) > 1} {
            $w(fileMenu) entryconfigure "File List" -state normal
        } else {
            $w(fileMenu) entryconfigure "File List" -state disabled
        }
        $w(fileMenu) entryconfigure "Write*" -state normal
        $w(fileMenu) entryconfigure "Recompute*" -state normal

        $w(mergeMenu) entryconfigure "Show*" -state normal
        $w(mergeMenu) entryconfigure "Write*" -state normal -label \
         [expr {$g(mergefileset) ? "Write Merge File" : "Write Merge File..."}]

        # Hmmm.... on my Mac the combobox flashes if we don't add this
        # check. Is this a bug in AquaTk, or in my combobox... :-|
        if {[$w(combo) cget -state] != "normal"} {
            $w(combo) configure -state normal
        }
    }

    # update the status line AND if any RE-match data exists
    set g(statusCurrent) "$g(pos) of $g(count)"
    set g(statusInfo) ""
    $w(viewMenu) entryconfigure "Ignore RE*" -state \
        [expr {[llength $opts(ignoreRegexLnopt)] ? "normal":"disabled"}]

    ##### Second layer - Do any diffs exist ? <implies a REAL g(pos)>
    #
    # Update the combobox, merge choices, and hunk centering.
    if {$g(count)} {
        # update the combobox. We don't want its command to fire, so
        # we'll disable it temporarily
        $w(combo) configure -commandstate "disabled"
        set i [expr {$g(pos) - 1}]
        $w(combo) configure -value [lindex [$w(combo) list get 0 end] $i]
        $w(combo) selection clear
        $w(combo) configure -commandstate "normal"

        # Merge choices and hunk centering
        foreach buttonpref {im tx} {
            $w(centerDiffs_$buttonpref) configure -state normal
            $w(mergeChoice1_$buttonpref) configure -state normal
            $w(mergeChoice2_$buttonpref) configure -state normal
            $w(mergeChoice12_$buttonpref) configure -state normal
            $w(mergeChoice21_$buttonpref) configure -state normal
        }
        catch { $w(mergeChoiceLabel) configure -state normal }

        $w(popupMenu) entryconfigure "Center*" -state normal
        $w(viewMenu) entryconfigure "Center*" -state normal

    } else {
        # Note: this is essentially for the "No-Diffs-found" case
        #   and effectively suggests that Layer 4 will do NOTHING!
        foreach b [list splitDiff cmbinDiff centerDiffs markClear markSet \
                   mergeChoice1 mergeChoice2 mergeChoice12 mergeChoice21] {
            $w(${b}_im) configure -state disabled
            $w(${b}_tx) configure -state disabled
        }
        catch { $w(mergeChoiceLabel) configure -state disabled }

        $w(popupMenu) entryconfigure "Center*" -state disabled
        $w(viewMenu) entryconfigure "Center*" -state disabled
        $w(editMenu) entryconfigure "Split*" -state disabled
        $w(editMenu) entryconfigure "Combine*" -state disabled
        $w(markMenu) entryconfigure "Mark*" -state disabled
        $w(markMenu) entryconfigure "Clear*" -state disabled
    }

    ##### Third layer - is CDR at (or beyond) edges of its valid range ?
    #   (N.B> also applies to the legitimate "No Diffs Found" situation)
    #
    # Update navigation items
    if {$g(pos) <= 1} {
        foreach buttonpref {im tx} {
            $w(prevDiff_$buttonpref) configure -state disabled
            $w(firstDiff_$buttonpref) configure -state disabled
        }

        $w(popupMenu) entryconfigure "Previous*" -state disabled
        $w(popupMenu) entryconfigure "First*" -state disabled
        $w(viewMenu) entryconfigure "Previous*" -state disabled
        $w(viewMenu) entryconfigure "First*" -state disabled

    } else {   ;# can transition lower
        foreach buttonpref {im tx} {
            $w(prevDiff_$buttonpref) configure -state normal
            $w(firstDiff_$buttonpref) configure -state normal
        }
        $w(popupMenu) entryconfigure "Previous*" -state normal
        $w(popupMenu) entryconfigure "First*" -state normal
        $w(viewMenu) entryconfigure "Previous*" -state normal
        $w(viewMenu) entryconfigure "First*" -state normal
    }

    if {$g(pos) >= $g(count)} {
        foreach buttonpref {im tx} {
            $w(nextDiff_$buttonpref) configure -state disabled
            $w(lastDiff_$buttonpref) configure -state disabled
        }
        $w(popupMenu) entryconfigure "Next*" -state disabled
        $w(popupMenu) entryconfigure "Last*" -state disabled
        $w(viewMenu) entryconfigure "Next*" -state disabled
        $w(viewMenu) entryconfigure "Last*" -state disabled
    } else {   ;# can transition higher
        foreach buttonpref {im tx} {
            $w(nextDiff_$buttonpref) configure -state normal
            $w(lastDiff_$buttonpref) configure -state normal
        }
        $w(popupMenu) entryconfigure "Next*" -state normal
        $w(popupMenu) entryconfigure "Last*" -state normal
        $w(viewMenu) entryconfigure "Next*" -state normal
        $w(viewMenu) entryconfigure "Last*" -state normal
    }

    ##### Fourth layer - is the specific CDR encumbered in some way
    # (thus g(pos) MUST have a legitimate value)
    #
    # Update availability of bookmarking and Split/Combine actions
    # AND the specific merge-choice selected
    if {$g(count) > 0} {

        # Show which merge option is current for this CDR
        set g(toggle) $g(merge[set hID [hunk-id $g(pos)]])

        # Bookmark (S)et and (C)lear items depend on the CDR marker
        # existance and are ALWAYS in opposite states to each other
        if {[winfo exists $w(toolbar).mark$hID]} \
            { set tmp {C S} }   { set tmp {S C} }
        lassign {normal disabled} {*}$tmp 
        foreach buttonpref {im tx} {
            $w(markClear_$buttonpref) configure -state $C
            $w(markSet_$buttonpref) configure -state $S
        }

        $w(markMenu) entryconfigure "Clear*" -state $C
        $w(markMenu) entryconfigure "Mark*" -state $S

        # (S)plit/(C)ombine each have specific condition checks
        set S [expr {[splcmb-chk split $g(pos)] ? "normal" : "disabled"}]
        set C [expr {[splcmb-chk cmbin $g(pos)] ? "normal" : "disabled"}]
        foreach buttonpref {im tx} {
                $w(splitDiff_$buttonpref) configure -state $S
                $w(cmbinDiff_$buttonpref) configure -state $C
            }

        $w(editMenu) entryconfigure "Split*" -state $S
        $w(editMenu) entryconfigure "Combine*" -state $C
    }
}

###############################################################################
# Center the top line of the CDR in each window.
###############################################################################
proc center {} {
    global g w

    if {! [info exists g(scrInf,[hunk-id $g(pos)])]} {return}
    lassign $g(scrInf,[hunk-id $g(pos)]) S E

    # Window requested height in pixels
    set opix [winfo reqheight $w(LeftText)]
    # Window requested lines
    set olin [$w(LeftText) cget -height]
    # Current window height in pixels
    set npix [winfo height $w(LeftText)]

    # Visible lines
    set winlines [expr {$npix * $olin / $opix}]
    # Lines in diff
    set diffsize [expr {$E - $S + 1}]

    if {$diffsize < $winlines} {
        set h [expr {($winlines - $diffsize) / 2}]
    } else {
        set h 2
    }

    $w(LeftText)  mark set insert $S.0
    $w(RightText) mark set insert $S.0
    $w(LeftText)  yview [max 0 [expr {$S - $h}]]
    $w(RightText) yview [max 0 [expr {$S - $h}]]

    if {$g(showmerge)} {
        merge-center
    }
}

###############################################################################
# Change the state on all of the diff-sensitive buttons.
###############################################################################
proc buttons {{newstate "normal"}} {
    global w

    $w(combo) configure -state $newstate
    foreach buttonpref {im tx} {
        $w(prevDiff_$buttonpref) configure -state $newstate
        $w(nextDiff_$buttonpref) configure -state $newstate
        $w(firstDiff_$buttonpref) configure -state $newstate
        $w(lastDiff_$buttonpref) configure -state $newstate
        $w(centerDiffs_$buttonpref) configure -state $newstate
    }
}

###############################################################################
# Wipe the slate clean...
###############################################################################
proc wipe {} {
    global g
    debug-info "wipe ()"

    # Short cicuit useless traces and key indexing lists
    if {$g(startPhase)} {set g(startPhase) 1}
    set g(pos) 0
    set g(COUNT) [set g(count) 0]
    set g(DIFF)  [set g(diff) ""]
    set g(currdiff) ""

    # N.B: It is critical that hID-related datums, particularly those that use
    # their EXISTANCE as the basis for internal decision making, be REMOVED
    # when attempting to "start over" to avoid seemingly random errors.
    array unset g {scrInf,[0-9]*}
    array unset g {overlap[0-9]*}
    array unset g {merge[0-9]*}
    array unset g {d3[RL]*}
    array unset g {inline,*}
}

###############################################################################
# Wipe all data and all windows
###############################################################################
proc wipe-window {} {
    global g w
    debug-info "wipe-window ()"

    wipe

    foreach wdg {LeftText RightText} {
        $w($wdg) configure -state normal
        $w($wdg) tag remove difftag 1.0 end
        $w($wdg) tag remove currtag 1.0 end
        $w($wdg) tag remove inlinetag 1.0 end
        $w($wdg) delete 1.0 end
        # Left/Right Info is repainted on every access - no need here
    }

    catch {
        $w(mergeText) configure -state normal
        $w(mergeText) delete 1.0 end
        $w(mergeText) configure -state disabled
        eval $w(mergeText) mark unset [$w(mergeText) mark names]
    }

    if {[string length $g(destroy)] > 0} {
        eval $g(destroy)
        set g(destroy) ""
    }

    $w(combo) list delete 0 end
    buttons disabled

    diffmark clearall
}

###############################################################################
# Search an ascending sorted list of lower/upper bound pairs for a given value.
#  [**> LIST MUST EXIST AS A NAMED ARRAY ELEMENT OF THE GLOBAL ('g') SPACE <**]
#
# Returns the index that either CONTAINS it, or FOLLOWS it; -OR-
# the original list LENGTH (i.e. an invalid index), indicating 'Exceeds range'
#
#   N.B> as long as the bounds info is in the 1st two elements of the item
#        being searched, additional fields may be stored in the same 'record'.
###############################################################################
proc rngeSrch {rnge val {indirect {}}} {
    global g

    # Until TcL V8.(6?).? arrives, there is NO "lsearch -bisect -command"
    #   (so this code is our own customized 'tuple binary-search' instead)

    # If 'rnge' contains (what amounts to) array INDICES to yet ANOTHER
    # table of values, then 'indirect' can be used to specify the PREFIX
    # name of where to indirectly access those ACTUAL range values
    if {$indirect != {}} {
        set ithItem {$g($indirect[lindex $g($rnge) $i])}
    }  {set ithItem          {[lindex $g($rnge) $i]} }

    # Dont bother if 'rnge' is empty or 'val' exceeds its largest value
    set max [llength $g($rnge)]
    if {([set HI [set i [incr max -1]]] >= [set LO 0])    \
    &&             ($val <= [lindex [subst $ithItem] 1])} {

        # Pick the FIRST midpoint and extract its values
        set i [expr {($LO + $HI)/2}]
        lassign [lindex [subst $ithItem]] low hgh

        # Repetitively narrow the boundaries until we find it
        #   N.B> (extra expression ENSURES boundary ALWAYS moves)
        while {$HI > $LO} {
            if {$val > $hgh} {set LO [expr {$LO==$i ? $i+1 : $i}]} {
            if {$val < $low} {set HI [expr {$HI==$i ? $i-1 : $i}]} {
            break}} ;# Wow - a lucky HIT - stop NOW!!

            # Pick NEW midpoint and try again
            set i [expr {($LO + $HI)/2}]
            lassign [lindex [subst $ithItem]] low hgh
        }
    } else {return [incr max]}
    return $i
}

###############################################################################
# Specialized range-check machinery to find ancestor collisions (by mark-diffs)
# Returns a truth value indicative of range S->E intersecting another range
#
#   N.B> optional arg is an initially unknown VarName (in callers stackframe)
#   to permit CHAINED accesses. It avoids searching for the correct 'anc' range
#   as is done on the FIRST such access by storing its LAST USED 'anc' index
#   to simply resume from that point (not unlike a co-routine or iterator)
###############################################################################
proc chk-ancRnge {anclst S E {prev {}}} {
    global g

    if {![set result [llength $g($anclst)]]} {return 0}
    if {$prev != {}} {upvar $prev  ndx} ;# (Remember where NEXT call starts)

    # Should we skip the 'binary searching' for the ancestor range?
    if {![info exists ndx]} {
        # No...but if searching says 'Exceeds known ranges' that IS an answer,
        # yet needs DECREMENTing (to a valid value) to be CACHEd (if it will)
        if {$result == [set ndx [rngeSrch $anclst $S]]} {incr ndx -1}
    } 

    # Get values of first ancestor range to check
    #   (args S & E are expected to BE in min/max order)
    lassign "$S $E 0 [lindex $g($anclst) $ndx]" s(0) e(0) result s(1) e(1)

    # Check ancestral ranges until found (or is known it CANT be found)
    while {$s(1) <= $e(0)} {
        # choose i'th segment as leftmost (and j as other)
        set i  [expr {$s(0) > $s(1)}]
        set j  [expr {$i == 0}]

        # Check for overlap
        if {[set result [expr {$s(0) == $s(1) || $e($i) >= $s($j)}]]} {break}

        # Step to next ancestor range (if one actually exists)
        if {$ndx < [llength $g($anclst)] - 1} {
            lassign [lindex $g($anclst) [incr ndx]] s(1) e(1)
        } else {break}
    }
    # If result is true, then  $s($j)  and  [min $e($i) $e($j)]
    # IS the OVERLAP BOUNDS (I think)
    # (could maybe be sent back as an optional upvar "list" ?)
    return $result 
}

# OPA >>>
proc StopDiff { { onOff 1 } } {
    global g

    set g(StopDiff) $onOff
}

proc UpdateDiffStatus { msg count total } {
    show-status [format "%s (%3d%% finished)" $msg \
                [expr {int( 100.0 * $count / $total) }]]
    update 
}
# OPA <<<

###############################################################################
# Mark difference regions and build up the combobox
#   N.B> Be very AWARE of when/why g(diff) .vs. g(DIFF) is used!!!
###############################################################################
proc mark-diffs {{rmvrpl {}}} {
    global g w opts
    debug-info "mark-diffs ()"

    set wdg(1) $w(LeftText)
    set wdg(2) $w(RightText)
    set g(COUNT) [set g(count) [set boxW [set delta(1) [set delta(2) 0]]]]

    # Distinguishing between EDITTING .vs. LOADING of the global diff hunk
    # list is defined by the OPTIONAL "(r)e(m)o(v)e and (r)e(pl)ace" argument
    if {$rmvrpl != {}} {
        set Lpad [set Rpad {}]      ;# (tmps for scheduling Pad-line removal)
        set g(startPhase) 1         ;# ... but RE-suspend "plot-line-info"
        $w(combo) list delete 0 end ;# ComboBox will simply be RE-loaded

        # Next do the REMOVEs of hunks from the diff list FIRST (including all
        # that depends on them) ... REPLACing with the NEW hunks before return.
        #   This mostly works because the entries being removed occupy the
        #   SAME SINGLE contiguous run as the entries taking their place.
        # Happily, Tcl ALLOWS modifying a list ACTIVELY being processed!!
        # N.B> We DO NOT re-evaluate "suppression" rules when editting diffs!
        #    It would interfere with the ability to RE-edit later...sorry!
        set i 0
        foreach d $g(diff) {
            if {[set ndx [lsearch -exact $rmvrpl $d]] >= 0} {
                if {![info exists inject]} {
                    set i [set inject [lsearch -exact $g(diff) $d]];#1st delete
                }

                # Only ONE side ever has Pad lines - remove them
                lassign $g(scrInf,$d) na E Pl na na Pr
                set S [incr E] ;# (shift range downward for Widget addressing)
                if {$Pl} {lappend Lpad [incr S -$Pl].0 $E.0} ;# Left  Padding
                if {$Pr} {lappend Rpad [incr S -$Pr].0 $E.0} ;# Right Padding

                $w(LeftText)  mark unset vL$d ;# Left Vertical-Linearity
                $w(LeftText)  tag delete vL$d ;# Left Vertical-Linearity
                $w(RightText) mark unset vL$d ;#Right Vertical-Linearity
                $w(RightText) tag delete vL$d ;#Right Vertical-Linearity

                diffmark clear  [incr i]    ;# Eliminate bookmark (if any)
                merge-add-marks [list $d]   ;# ... and its Merge data

                unset -nocomplain g(inline,$d) ;# inline diffs
                unset -nocomplain g(overlap$d) ;# 3way diff collision
                unset g(scrInf,$d) ;# line numbering information

                # Now that everything is gone, remove the hID from $rmvrpl
                set rmvrpl  [lreplace $rmvrpl $ndx $ndx]
            } elseif {$i>0} { break } ;# early out once contiguous block found
        }

        # We MUST have deleted SOMETHING by now... ?
        if {$i} {
            # Must eliminate Padding all at once to avoid shifting the indices
            if {[llength $Lpad]} {$w(LeftText)  delete {*}$Lpad}
            if {[llength $Rpad]} {$w(RightText) delete {*}$Rpad}

            # ... finally overlay the NEW hIDs ... REPLACING what was deleted
            # N.B> 'i' begins as an "index+1" position against g(diff) ...
            #   afterward, 'inject' refers to 1st NEW index in g(DIFF)
            set j [lsearch -exact $g(DIFF) [lindex $g(diff) $inject]];#map 1st,
            set g(diff) [lreplace $g(diff) $inject [incr i -1] {*}$rmvrpl]
            set i [expr {$i - $inject + $j}] ;# readjust i to last mapped index
            set g(DIFF) [lreplace $g(DIFF) [set inject $j] $i {*}$rmvrpl]
        }
    }

    # Compute minimal spacing to format the combobox entry numbering
    set fmtW [string length "[llength "$g(diff)"]"]

    # Walk through each diff hunk DERIVING global data for eventual use
    StopDiff 0
    foreach d $g(DIFF) {
        if { $g(StopDiff) } {
            set g(count) 0
            set g(COUNT) 0
            set g(diff) [list]
            set g(DIFF) [list]
            break
        }

        # If its Info ALREADY exists, we are obviously in EDIT mode, needing
        # primarily to keep the 'delta(*)'s updated AND (re)add into comboBox
        if {[info exists g(scrInf,$d)]} {

            # Get most of what we know of this hunk ...
            # ... derive its type and determine if we count it as a REAL hunk
            lassign $g(scrInf,$d) S E Pl na Cl Pr Or Cr
            if {[string is lower [set type [expr {"$Cl$Cr"=="" ? "I":"i"}]]]} {
                incr g(count)
            }
            incr g(COUNT) ;# It ALWAYS counts in the superset list


            # However, ALL existing hunks BEYOND the injected entries require
            # certain minor realignments:
            #   a) "scrInf,*" Ofst fields MUST be rewritten to the NEW deltas
            #      likewise the S & E fields must adjust to the new delta SUM
            #   b) if REAL (and bookmarked?), it will need a renumbered label
            if {$inject < $g(COUNT)} {
                set S [expr {$delta(2) - $Or + $S}]
                set E [expr {$delta(2) - $Or + $E}]
                set g(scrInf,$d) \
                              [list $S $E $Pl $delta(1) $Cl $Pr $delta(2) $Cr]
                if {"$type" == "i"} {diffmark $d $g(count)}
            }
            incr delta(1) $Pl  ;# Keep the deltas CURRENT for EVERY hunk
            incr delta(2) $Pr

        } elseif { [set result [extract $d]] != ""} {
        # Otherwise, its a NEW hunk needing to be processed
            lassign $result s(1) e(1) s(2) e(2) type

            # Count it ... but only NON-suppressed hunks count as REAL
            incr g(COUNT)
            if {[string is lower $type]} {
                incr g(count)

                # In addition, before ALTERING any of those start/end numbers,
                # check for an active 3way diff and whether this hunk collides
                # any ancestral changes together. Moreover, also establish its
                # 'default' L/R merge choice (Ancestral over User preferred)
                if {$g(is3way)} {
                    set g(merge$d) 0; # begin as temporarily unknown
                    switch -- $type {
                    "a" {   if {[chk-ancRnge d3Right $s(2) $e(2) RaNDX]} {
                                set g(merge$d) 2}
                        }
                    "c" {   if {[chk-ancRnge d3Left  $s(1) $e(1) LaNDX]} {
                                set g(merge$d) 1}
                            if {[chk-ancRnge d3Right $s(2) $e(2) RaNDX]} {
                                if {$g(merge$d)} {set g(overlap$d) 1}; # Collision
                                set g(merge$d) 2};# Right overrides Left
                        }
                    "d" {   if {[chk-ancRnge d3Left  $s(1) $e(1) LaNDX]} {
                                set g(merge$d) 1}
                        }
                    }
                    if {!$g(merge$d)} {set g(merge$d) $opts(predomMrg)}
                } else { set g(merge$d) $opts(predomMrg) } ;# when NO 3way at all
            }

            # Now REmap s(1),e(1) s(2),e(2) to refer to SCREEN linenumbers
            # First, compute the RAW Left and Right linecounts
            set siz(1) [expr {$e(1) - $s(1)}]
            set siz(2) [expr {$e(2) - $s(2)}]

            # Then adjust BOTH starts, accounting for ALL PRIOR hunk padding
            #   (these then become this hunks starting SCREEN linenumbers)
            incr s(1) $delta(1)
            incr s(2) $delta(2)

            # Next, based on what TYPE of diff it is, decide WHICH widget:
            #   - gets any (and how much) blankline padding (via setting "i")
            #   - gets what type-associated ChangegBar character
            # N.B. Note that the RAW s($i) on "a,d"-types is 1-less initially
            # because it refers to a line number BEFORE the line that (by
            # virtue of the add/delete) does not actually exist on that side.
            # Uppercase types are hunks to be IGNORED (they get Padded only)
            set pad(1) [set pad(2) 0]
            set cbar(1) [set cbar(2) ""]
            switch -- $type {
            "A" -
            "a" {    ;# an 'add' pads to the LEFT widget
                    set pad([set i 1]) [incr siz(2)]
                    incr s(1) ;# (RAW lnum was the one BEFORE the add)
                    set cbar(2) [expr {$type == "a" ? "+" : ""}]
                }
            "D" -
            "d" {   ;# a 'delete' pads to the RIGHT widget
                    set pad([set i 2]) [incr siz(1)]
                    incr s(2) ;# (RAW lnum was the one BEFORE the delete)
                    set cbar(1) [expr {$type == "d" ? "-" : ""}]
                }
            "C" -
            "c" {   ;# a 'change' pads to the SHORTER widget
                    set i [expr {$siz(1) < $siz(2) ? 1 : 2}]
                    set pad($i) [expr {abs([incr siz(1)] - [incr siz(2)])}]
                    set cbar(2) [set cbar(1) [expr {$type == "c" ? "!" : ""}]]
                }
            }

            # Now, compute the END line numbers to THEIR screen values...
            incr siz($i) $pad($i)
            set e(2) [expr {$s(2) + $siz(2) - 1}]

            # IMPORTANT: if you've done the math (and logic), "e(1)" MUST EQUAL
            # "e(2)" when all is complete. But we still need the UNpadded value
            # as well -- so UNTIL THE NEXT ITERATION:
            #         e(2) will hold the PADDED end value and
            #         e(1) the UNpadded one.
            # Watch CAREFULLY where each gets used!!!
            # Moreover, s(1) will LIKELY be utilized as an INITIALIZED temp
            set e(1) [expr {$e(2) - $pad($i)}]

            # SAVE all this SCREEN ADJUSTED data for mapping various operations
            # later on throughout the tool
            #   N.B!!     s(1),e(1) == s(2),e(2)  so only one set is recorded
            set g(scrInf,$d) [list $s(2) $e(2) \
                $pad(1) $delta(1) $cbar(1) $pad(2) $delta(2) $cbar(2) ]

            # Accumulate any newly computed padding for the NEXT iteration
            incr delta($i) $pad($i)

            # FINALLY, we can ACTUALLY pad the widget into compliance (if reqd),
            # and plant the vL* MARK on that FINAL LINE of a REAL hunk...to
            # retain WHERE to place the vertical linearity TAG (vL*) later on,
            # AFTER any user pref changes (which MIGHT mention fonts).
            #
            #       The vL* TAG ensures each L/R hunk pairing remains the same
            #       PHYSICAL height in BOTH Text widgets, PROVIDING a L/R
            #       alignment of MOST lines, diminishing the scrolling skew
            #       introduced by TK Vrsn(>= 8.5) "display .vs. logical" lines.
            if {$pad($i) > 0} {
                $wdg($i) insert $e(1).end [string repeat "\n" $pad($i)]
            }
            # (of course, only REAL hunks might ever need skew compensation)
            if {[string is lower "$type"]} {
                $w(LeftText)  mark set vL$d  $e(2).0
                $w(RightText) mark set vL$d  $e(2).0
            }

            # Lastly - (if on) generate inline diff data for this hunk
            if {"$type" == "c" && ($opts(showinline1) || $opts(showinline2))} {
                while {$s(1) <= $e(1)} {
                    if {$opts(showinline1)} {
                        find-inline-diff-byte $d [expr {$s(1) - $s(2)}] \
                               [$w(LeftText)  get $s(1).0 $s(1).end] \
                               [$w(RightText) get $s(1).0 $s(1).end]
                    } else {
                        find-inline-diff-ratcliff $d [expr {$s(1) - $s(2)}] \
                               [$w(LeftText)  get $s(1).0 $s(1).end] \
                               [$w(RightText) get $s(1).0 $s(1).end]
                    }
                    incr s(1) ;# (warned you this value could be trashed)
                }
            }
        }

        # Append entry into combobox (and hilight when its a 3way collision)
        if {[string is lower "$type"]} {
            $w(combo) list insert end \
                             "[set item [format "%*d: %s" $fmtW $g(count) $d]]"
            if {[info exists g(overlap$d)]} {
                $w(combo) list itemconf end -background $opts(mapolp)
            }
            # measure it, remembering the LONGEST entry seen ...
            set boxW [max $boxW [string length "$item"]]
        }
        if { $g(count) % 500 == 0 } {
            UpdateDiffStatus "Step 1 of 2: Mark differences" $g(count) [llength $g(DIFF)]
        }
    }
    UpdateDiffStatus "Step 1 of 2: Mark differences" 100 100
    # Beyond here, MOST other tool functions are based on g(diff) and g(count)
    #   [big exception is "line numbering" code that uses g(DIFF) and g(COUNT)]

    # Shrinkwrap combobox TO its data (avoids clipping AND excess space)
    #  (N.B> decrement of 2 ??appears?? to be an artifact of combobox font?)
    #  (or perhaps spacing STOLEN from the width for the pulldown button?)
    if {$g(count)} { $w(combo) configure -width [incr boxW -2] }

    # Ensure that any NEWLY CREATED diff regions are 'mark'ed in the MERGE
    # window (so they can be tagged in the next step -- note that 'rmvrpl' here
    # either HAS the list of ONLY the additions, or is EMPTY which flags the
    # procedure to mark EVERY diff
    if {$g(count)} {merge-add-marks $rmvrpl}

    # Lastly, ensure the MAP reflects the CURRENT diffs and go (re-)TAG it all
    map-resize
    remark-diffs
    return $g(count)
}

###############################################################################
# start a new diff from the popup dialog
###############################################################################
proc do-new-diff {} {
    global g finfo
    debug-info "do-new-diff ()"

    # Unlock the PRESENT mergefile settings (but leave name for now), then ...
    # Pop up the dialog to collect the args and form them together
    # into a command - bailing out if Dialog cancels or args is malformed
    set g(mergefileset) 0
    if {![newDiffDialog] || ![assemble-args]} return

    set g(disableSyncing) 1 ;# turn off syncing until things settle down

    # make new args available then do the diff
    reload-multifile $finfo(fPairs)
    do-diff

    move first 1 1

    update-display
    catch {unset g(disableSyncing)}
}

###############################################################################
# Remark difference regions...
###############################################################################
proc remark-diffs {} {
    global g w pref opts
    debug-info "remark-diffs ()"

    if {$g(statusInfo) == ""} {show-status "Re-Marking differences..."}
    # Delete, then reconfigure ALL tags (based on the current options) ...
    foreach win [list $w(LeftText) $w(RightText) $w(mergeText)] {
        eval $win tag delete [$win tag names]

        # (tag names here abbreviated simply to fit in 80 columns)
        # IMPORTANT - this DEFINES tag PRECEDENCE throughout TkDiff
        #   (and MUST SYNC with the 'translit-plot-txtags' emulation coding!!)
        foreach tag {diff curr del ins chg overlap inline sel} {
            # Yet 'difftag' cfgs into mergeText as TWO names: diffR & diffL,
            # but as ITSELF in the main Text windows (despite the same attrs)
            #  - a coding trick so merge knows which SIDE provided the line!
            #
            # Catch provides an error check against bad userpref settings
            if { "$tag" == "sel"} {
                $win tag raise $tag

            } elseif {($win != $w(mergeText) || $tag == "curr") \
             && [catch "$win tag configure ${tag}tag $opts(${tag}tag)"]} {
                do-error "Invalid settings for \"$pref(${tag}tag)\": \
                \n\n'$opts(${tag}tag)' is not a valid option string."
                # Re-run OUTSIDE the catch to let it blow up for real
                eval "$win tag configure ${tag}tag $opts(${tag}tag)"
                return

            } elseif {$win == $w(mergeText) && "$tag" == "diff"} {
                # (difftag has already been validity checked by now)
                $win tag configure ${tag}R {*}$opts(${tag}tag)
                $win tag configure ${tag}L {*}$opts(${tag}tag)
            }
        }
    }

    # Now, reapply the tags applicable to all the diff regions
    set count 0
    if { [llength $g(diff)] > 0 } {
        StopDiff 0
    }
    foreach hID $g(diff) {
        if { $g(StopDiff) } {
            break
        }
        # First the difftag ...
        set-tag $hID difftag

        # ... then a POTENTIALLY needed UNIQUE vertical linearity tag ...
        #   (on LAST line of every hunk - MIGHT never be configured)
        # N.B: uses a preset MARK to survive the earlier mass TAG deletion
        add-tag $w(LeftText)  vL$hID {} vL$hID vL$hID
        add-tag $w(RightText) vL$hID {} vL$hID vL$hID

        # ... and finally any inline annotations
        if {[string match "*c*" "$hID"] && \
                    ($opts(showinline1) || $opts(showinline2))} {
            remark-inline $hID false ;# "false" -> Cfg (not ReCfg) skew

        # Remember to handle NON chg-type hunks for screen height skew also
        } else {
            de-skew-hunk $hID false
        }
        incr count
        if { $count % 500 == 0 } {
            UpdateDiffStatus "Step 2 of 2: Apply tags" $count [llength $g(diff)]
        }
    }
    UpdateDiffStatus "Step 2 of 2: Apply tags" 100 100

    # Turn "plot-line-info" processing back ON if it was OFF
    if {$g(startPhase) == 1} {incr g(startPhase)}

    # finally, re-establish the current diff
    set g(currdiff) [set-tag [hunk-id $g(pos)] currtag]
}

###############################################################################
# Update Skew correction on given hunk
###############################################################################
proc de-skew-hunk {hID {reCfgSkew true}} {
    global g w

    # Get screen difftag range (same for Left or Right)
    lassign $g(scrInf,$hID) s1 e1

    # Force measurements to be REcalculated WITHOUT any PRIOR value
    if {$reCfgSkew} {
        $w(LeftText)  tag configure vL$hID -spacing3 0
        $w(RightText) tag configure vL$hID -spacing3 0
    }
    update idletasks ;# Tk8.6.3 BUG: measure AFTER things go quiet (see below)
    set lsz [$w(LeftText)  count -update -ypixels $s1.0 $e1.0+1lines]
    set rsz [$w(RightText) count -update -ypixels $s1.0 $e1.0+1lines]

    # Only config shortest if NEEDED to make left/right screen heights agree
    if {$lsz < $rsz} {
        $w([set wdg LeftText])  tag configure vL$hID -spacing3 [expr $rsz-$lsz]
    } elseif {$lsz > $rsz} {
        $w([set wdg RightText]) tag configure vL$hID -spacing3 [expr $lsz-$rsz]
    } else {return}

    # N.B.  BUT - RERUN the "count" JUST TO FORCE '-update' to be completed!
    #  -otherwise ANY scroll performed (BEFORE 'idletasks' finishes?) is wrong
    #   As of Tk8.6.6 a new subcmd (sync) is possible, but this method MIGHT
    #   still be faster given it targets a smaller specific indice range.
    $w($wdg) count -update -ypixels $s1.0 $e1.0+1lines

    update idletasks ;# Tk8.6.3 *BUG*: "legacy" Txtwdg implementation MIGHT
    # invalidate internal BTree ptrs when the data size is very small. SEEMS to
    # involve deferred processing somehow, and will hopefully be gone if/when
    # the Txtwdg impl is redone (see http://core.tcl.tk/ TIP #466)
    # Both "idletasks" calls (here and earlier) has STOPPED an observed SEGV.
}

###############################################################################
# Add inline tags for a given SINGLE hunk to BOTH Text widgets
###############################################################################
proc remark-inline {hID {reCfgSkew true}} {
    global g w
    #debug-info "remark-inline ($hID)"

    # N.B> Oddly enough, it is legitimately POSSIBLE that ABSOLUTELY IDENTICAL
    # linepairs can be 'inline-diff'ed resulting in NO output list of ranges!
    #   eg.:     1c1,2
    #                  |  abc  |     |  abc  |     <--- compares identical
    #                  |       |     |  d e  |     <--- skips (left is empty)
    #                  |  xyz  |     |  xyz  |
    #   versus:  1a2
    #                  |  abc  |     |  abc  |
    #                  |       |     |  de   |     (only 'c' types do inlines)
    #                  |  xyz  |     |  xyz  |
    #
    #      (Diff output can be quite capricious at times!!)
    if {[info exists g(inline,$hID)]} {
        set wdg(l) "LeftText"
        set wdg(r) "RightText"

        # Presumes 'inlinetag' was ALREADY removed from BOTH Text widgets
        set Lno [lindex $g(scrInf,$hID) 0]
        foreach {side lndx Scol Ecol} $g(inline,$hID) {
            add-tag $w($wdg($side)) inlinetag [incr lndx $Lno] $Scol $Ecol
        }
    }
    de-skew-hunk $hID $reCfgSkew
}

###############################################################################
# Put up some informational text.
###############################################################################
proc show-status {message} {
    global g

    debug-info "(show-status) $message"
    set g(statusInfo) $message
    update idletasks
}

###############################################################################
# Trace output, enabled by a global variable
###############################################################################
proc debug-info {message {force 0}} {
    global g

    if {$g(debug) || $force} {
        puts "$message"
    }
}

###############################################################################
# Compute differences (start from the beginning, basically).
###############################################################################
proc rediff {} {
    global g w opts finfo
    debug-info "rediff ()"

    buttons disabled

    # Read the files into their respective widgets
    # and derive the overall line number magnitude.
    set g(lnumDigits) 0
    set  i [set j [expr $finfo(fCurpair) * 2]]
    incr i -1
    set msg {} ;# Assume this is gonna work ....
    foreach {LR ndx} [list Left $i Right $j] {
        # When finfo(pth,X) is NOT set yet, its a SCM file that
        # has not yet been obtained -- go get it
        show-status "reading $finfo(lbl,$ndx) ..."
        if {![info exists finfo(pth,$ndx)]} {
            # if it fails: finfo(pth,$ndx) will LIKELY be an empty tmpfile
            if {"" != [set msg [scm-chkget $ndx]]} {do-error "$msg"}
        }
        if {[catch {set hndl [open "$finfo(pth,$ndx)" r]}]} {
            fatal-error "Failed to open file: $finfo(pth,$ndx)"
        } else {fconfigure $hndl -translation \
            [expr {"$::tcl_platform(platform)" == "windows" ? "crlf" : "lf"}]}
        $w(${LR}Text) insert 1.0 [read $hndl]
        # Must also replace the merge window contents (w/Left contents)
        if {$LR == "Left"} {
            seek $hndl 0 start ;# Rewind the Left file
            catch { $w(mergeText) mark unset [$w(mergeText) mark names] }
            $w(mergeText) configure -state normal
            $w(mergeText) delete 1.0 end
            $w(mergeText) insert 1.0 [read $hndl]
            if {![regexp {\.0$} [$w(mergeText) index "end-1lines lineend"]]} {
                $w(mergeText) insert end "\n"
            }
            $w(mergeText) configure -state disabled
        }
        close $hndl
        set lines [expr {int([$w(${LR}Text) index end-1lines])}]
        set g(lnumDigits) [max [string length "$lines"] $g(lnumDigits)]
    }
    # Provide feedback on this filepair being successfully accessed (or not)...
    # then push g(lnumDigits) to reconfig width of Info canvas widgets
    $w(multiFileMenu) entryconf "$finfo(lbl,$i)" \
        -activebackg [expr {"$msg" != {}  ? {Tomato} : {PaleGreen}}]
    alignDecor $finfo(fCurpair)
    cfg-line-info

    # Diff the two files and store the summary lines into 'g(diff)'
    if {$opts(ignoreblanks) == 1} {
        set diffcmd "$opts(diffcmd) $opts(ignoreblanksopt)  {$finfo(pth,$i)} \
          {$finfo(pth,$j)}"
    } else {
        set diffcmd "$opts(diffcmd) {$finfo(pth,$i)} {$finfo(pth,$j)}"
    }
    show-status "Executing \"$diffcmd\""

    set result [run-poExec "::poExec::Exec $diffcmd"]
    set stdout [lindex $result 0]
    set stderr [lindex $result 1]
    set exitcode [lindex $result 2]
    set g(returnValue) $exitcode

    # The exit code is 0 if there are no differences and 1 if there
    # are differences. Any other exit code means trouble
    if {$exitcode < 0 || $exitcode > 1 || $stderr != ""} {
        do-error "diff failed:\n$stderr"
    }

    # If there is no output and we got this far the files are equal ...
    if {"[set lines [split $stdout "\n"]]" != ""} {

        # ... otherwise check if the first line begins with a line number.
        # If not there was trouble and we abort. For instance, using a binary
        # file produces "Binary files ..." etc on stdout, with exit code 1.
        # The message may vary depending on locale (being produced by Diff).
        if {[string match {[0-9]*} $lines]} {
            # There ARE diffs!
            lappend lines "0" ;# Cheap trick: add sentinel to flush next loop
        } else {fatal-error "diff failed:\n$stdout"}
    }

    # Collect all lines containing diff hunk headers
    #    N.B> Critical Concept- There are TWO lists of headers:
    #   'g(DIFF)' is the superset and includes EVERY reported hunk
    #   'g(diff)' is POTENTIALLY a subset, but is USED by MOST OF THE TOOL
    #
    # The distinction comes from options the user MAY have used to suppress
    # certain kinds of hunks (blanklines, REmatched) which WE MUST PROCESS and
    # NOT pass to Diff (it would HIDE places where widget padding is needed).
    #   Our technique is to UPPERCASE the headers for hunks being suppressed,
    # but then ALSO restrict such headers to the 'g(DIFF)' list.
    #
    #   When the options are NOT used, both lists are identical - (but beware
    # of LATENT bugs being CAUSED by keying some downstream feature to the
    # WRONG list!!). Otherwise, THIS code simply APPLYS the suppression options
    # and forms BOTH lists, in a "state machine" style of parsing.
    #   Generally, it is Text widget "Padding" and "Line numbering" tasks that
    # require the use of 'g(DIFF)'; everything(?) else should use 'g(diff)'.
    set hID [set g(DIFF) [set g(diff) {}]]
    foreach line $lines {
        switch -glob [string index $line 0] {
            "-" {continue}
            "[0-9]" {if {$opts(ignoreEmptyLn) \
                 || ($opts(ignoreRegexLn) && $opts(ignoreRegexLnopt) != "")} {
                    if {[string length $hID]} {
                        if {[string match {*[acd]*} $hID]} {
                            lappend g(diff) $hID
                        }
                        lappend g(DIFF) $hID
                    }
                    # Presume it WILL suppress (re-activating at each hunk)
                    set hID [string toupper $line]
                    if {[set Esuppress $opts(ignoreEmptyLn)]} {
                        if {$opts(ignoreblanks) \
                        &&  ([string length [string map {b {} w {} Z {}} \
                                            $opts(ignoreblanksopt)]] \
                        <    [string length $opts(ignoreblanksopt)])} {
                            set Eexpn {^..[[:space:]]*$};# any of "-bwZ" used
                        } else {set Eexpn {^..$}}       ;#     otherwise
                    }
                    set Rsuppress [llength $opts(ignoreRegexLnopt)]
                } elseif {[string length $line]-1} {
                    lappend g(diff) $line
                    lappend g(DIFF) $line
                    set hID {}
                }
            }
            "[<>]" {if {![string match {*[ACD]*} $hID]} {continue}
                # Verify this lines data against the reasons for suppression
                if {$Esuppress} {
                    if {![regexp $Eexpn $line]} {set Esuppress 0}
                }
                if {$Rsuppress} {
                    set Rsuppress [llength $opts(ignoreRegexLnopt)]
                    # (if ANY expn matches, then the suppression remains valid)
                    foreach Iexpn $opts(ignoreRegexLnopt) {
                        if {![regexp $Iexpn [string range $line 2 end]]} {
                            incr Rsuppress -1} {break}
                    }
                }
                # Cancel the presumption of suppression if the reason is gone
                if {!$Esuppress && !$Rsuppress} {set hID [string tolower $hID]}
            }
        }
    }
    debug-info "DIFF([llength $g(DIFF)]) .vs. diff([llength $g(diff)])"

    if {$g(is3way)} {
        foreach {LR NDX} [list Left $i Right $j] {

            # 3-way merge - compare file  with ancestor
            #  N.B> note we are diffing TO (not from) the Ancestor
            #       This effectively flips 'a/d' hunk type designators 
            set diffcmd "$opts(diffcmd)"
            if {$opts(ignoreblanks) == 1} {
                 lappend diffcmd $opts(ignoreblanksopt)
            } 
            append diffcmd " {$finfo(pth,$NDX)} {$finfo(pth,0)}"

            show-status "Executing \"$diffcmd\""
            set result [run-poExec "::poExec::Exec $diffcmd"]
            set stdout [lindex $result 0]
            set stderr [lindex $result 1]
            set exitcode [lindex $result 2]
            if {$exitcode < 0 || $exitcode > 1 || $stderr != ""} {
                fatal-error "diff3 failed:\n$stderr"
            }
            set lines [split $stdout "\n"]
            set g(d3$LR) {}
            foreach line $lines {
                if {[string match {[0-9]*} $line]} {
                    foreach {s1 e1 s2 e2 type} [extract $line] {
                        # Ignore any DELETIONS by this side FROM the Ancestor
                        # (they exist only at the ancestors level and earlier)
                        if {$type == "a"} {break} ;# (but they LOOK like adds)

                        # 'mapping' is because we diffed to (not from) ancestor
                        #  (but we want the user seeing a more normalized view)
                        lappend g(d3$LR) "$s1 $e1 [string map {c C d A} $type]"
                    }
                }
            }
            debug-info "$LR  ancestral data $g(d3$LR)"
        }
    }

    # Mark up the two text widgets and go to the first diff (if there is one).
    # Otherwise BLANK the combobox (in case it has old data from a PRIOR diff)
    show-status "Marking differences..."

    if {[mark-diffs]} {
        set g(pos) 1
        move 1 0 1
        buttons normal
    } else {
        $w(combo) configure -commandstate disabled
        $w(combo) configure -value {}
        $w(combo) configure -commandstate normal
        if { $g(StopDiff) } {
            after idle {show-status "Comparison cancelled"}
        } else {
            after idle {show-status "Files are identical"}
        }
        buttons disabled
    }
}

###############################################################################
# Set the X cursor to "watch" for a window and all of its descendants.
#
# An optional msg 'WHY' will post to the status area (when BOTH exist); if the
# '.status' window DOESN'T exist yet, one **MAY** be temporarily built, and the
# reason posted there, PROVIDED it takes longer than a specifiable delay(in ms)
# to REACH the code that can cancel the need (ie- the message is only IMPORTANT
# if the GUI isn't inplace yet AND the action we elected to be BUSY about takes
# randomly longer than someone can withstand waiting for feedback:
#   Prime example:  hung networks or simply unpredictable latency.
###############################################################################
proc watch-cursor {{WHY {}} {delay 1250}} {
    global g w ASYNc
    #debug-info "watch-cursor ($msg)"

    # Cant 'busy' out windows that arent't there yet ...
    if {[winfo exists w(LeftText)]} {
        . configure -cursor watch
        $w(LeftText) configure -cursor watch
        $w(RightText) configure -cursor watch
        $w(combo) configure -cursor watch
        if {$WHY != {}} {show-status "$WHY"}
        update idletasks

    # ... but if we gave a REASON WHY - someone should see THAT reasonably soon
    } elseif {$WHY != {}} {
        # Thus we want to REQUEST a status window be built after a short delay;
        #   HOWEVER if we can complete the "busy" task and get back in time to
        # CANCEL the request, the user need NEVER see it -BUT- that means
        # changing to ASYNC processing for any external tasks we might spawn or
        # we will NEVER see the timer fire (it needs an event loop running).
        #   This temp Status window IS removed @pgm exit (on failures), OR as
        # soon as we replace it with the main GUI (eg. success). Once built,
        # future Busy/Unbusy pairs simply USE whatever status window exists.
        # (sadly, MacOS X wont do a "wm manage .." so NO point to going ASYNC)
        if {$g(windowingSystem) != "aqua" && ![winfo exists .status]} {
            #   So post the timer, SAVING its ID in a global whose EXISTENCE
            # will be used as a flag, so 'run-command' operates in ASYNC mode.
            # (N.B> but only the first one to get here can actually post)
            if {![info exists ASYNc(trigger)]} {
                set ASYNc(trigger) [after $delay need-status]
                debug-info "Posted ASYNc(trigger)($ASYNc(trigger))"
            }
        }
        show-status "$WHY"
        update idletasks
    }
}

###############################################################################
# Give the user SOMETHING to look at while they wait 
#
# N.B> if processing hangs, clicking the window 'exit' decoration will kill pgm
###############################################################################
proc need-status {} {
    global g w    

    debug-info "need-status fired"
    set w(status) $w(tw).status
    build-status
    set W  [winfo pixels $w(tw).status "3.5i"]
    set Ofst [winfo pixels $w(tw).status "1i"]
    wm manage   $w(status)
    wm title    $w(status) "$g(name) Status"
    wm geometry $w(status) "${W}x30+$Ofst+$Ofst"
    wm protocol $w(status) WM_DELETE_WINDOW {do-exit}
    # N.B> Protocol works 'IFF' an event loop is RUNNING (to see the msg event)
    update idletasks
}

###############################################################################
# Restore the X cursor for a window and all of its descendants.
###############################################################################
proc restore-cursor {} {
    global w ASYNc
    #debug-info "restore-cursor"

    if {[winfo exists w(LeftText)]} {
        . configure -cursor {}
        $w(LeftText) configure -cursor {}
        $w(RightText) configure -cursor {}
        $w(combo) configure -cursor {}
        show-status ""
        update idletasks
    } elseif {[info exists ASYNc(trigger)]} {
        if {$ASYNc(trigger) != {}} {
            # if got here in time ... cancel this attempt and reset to normal
            # but if we get here LATE, maintain ASYNC mode until its removed
            if {![winfo exists .status]} {
                after cancel $ASYNc(trigger)
                debug-info "Canceled ASYNc(trigger)($ASYNc(trigger))"
                unset ASYNc(trigger)
            } else {set ASYNc(trigger) {}}
        }
    }
}

###############################################################################
# Check if error was thrown by us or unexpected
###############################################################################
proc check-error {result output} {
    global g errorInfo

    if {$result && $output != "Fatal"} {
        error $result $errorInfo
    }
}


###############################################################################
# redo the current diff. Attempt to return to the same diff region,
# numerically speaking.
###############################################################################
proc recompute-diff {} {
    global g
    debug-info "recompute-diff ()"

    set current $g(pos)
    debug-info "saving current position $g(pos)"

    do-diff
    move $current 0 1
    center
}


###############################################################################
# Wipe most everything and then kick off a rediff.
###############################################################################
proc do-diff {} {
    global g opts map errorInfo
    debug-info "do-diff ()"

    wipe-window
    watch-cursor    ;# in case of delay from diff OR a maybe-slow SCM
    update idletasks
    set result [catch {
        if {$g(mapheight)} {
            ## ?? Not sure why THIS needs to be caught ...
            #   (when 'g(mapheight)' is non-zero, 'map' should exist)
            catch {$map blank}
            set g(mapheight) -1 ;# once its ON, keep it updated because
            # toggling it to show only (un)maps the widget itself
        }

        rediff

    } output]

    #debug-info "  rediff result: $result   outptut: $output"
    check-error $result $output

    if {$g(mergefileset)} {
        do-show-merge 1
    }
    restore-cursor
}

###############################################################
# Convert from hunk-index
#   a 1-based monotonic difference position (called a hunk)
# to hunk-id
#   a diff-encoded (nnn[acd]mmm) descriptive format
###############################################################
proc hunk-id { ndx {lst diff}} {
    global g

    # lst:    'DIFF'  (superset diffs) has ALL hunks (inclds fakes)
    #         'diff'   (subset diffs)  has only REAL hunks 
    # Both lists expect to NOT have a *dummy* index-0 element
    lindex $g($lst) [incr ndx -1]
}

###############################################################
# Convert from hunk-id
#   a diff-encoded (nnn[acd]mmm) descriptive format
# to hunk-ndx
#   a 1-based monotonic difference position (called a hunk)
###############################################################
proc hunk-ndx { id {lst diff}} {
    global g

    # lst:    'DIFF'  (superset diffs) has ALL hunks (inclds fakes)
    #         'diff'   (subset diffs)  has only REAL hunks 
    # Both lists expect to NOT have a *dummy* index-0 element
    expr { 1 + [lsearch -exact $g($lst) $id] }
}

###############################################################################
# Get things going...
###############################################################################
# OPA >>>
proc tkdiff-main { { leftFile "" } { rightFile "" } { removeFilesAtEnd false } } {
# OPA <<<
    global g w opts ASYNc startupError errorInfo tk_version
    # debug-info "main" - No point... only works AFTER "commandline" runs

    # OPA >>>
    if { $leftFile ne "" || $rightFile ne "" } {
        set ::argc 0
        set ::argv [list]
    }
    if { $leftFile ne "" } {
        lappend ::argv $leftFile
        incr ::argc
    }
    if { $rightFile ne "" } {
        lappend ::argv $rightFile
        incr ::argc
    } 
    # OPA <<< 
    wm withdraw .
    # OPA >>>
    if { [winfo exists $w(tw)] } {
        tkdiff-CloseAppWindow
    }
    toplevel $w(tw)

    wm protocol $w(tw) WM_DELETE_WINDOW tkdiff-CloseAppWindow
    wm title $w(tw) "$g(name) $g(version)"

    if { $leftFile ne "" } {
        if { $removeFilesAtEnd } {
            lappend g(tempfiles) $leftFile
        }
    }
    if { $rightFile ne "" } {
        if { $removeFilesAtEnd } {
            lappend g(tempfiles) $rightFile
        }
    }
    # OPA <<< 

    if {![catch {set windowingsystem [tk windowingsystem]}]} {
        if {$windowingsystem == "x11"} {
            # All this nonsense is necessary to use an icon bitmap that's
            # not in a separate file.
            # OPA <<< 
            catch { destroy .icw }
            # OPA <<< 
            toplevel .icw
            if {[string first "color" [winfo visual $w(tw)]] >= 0} {
                label .icw.l -image deltaGif
            } else {
                label .icw.l -image delta48
            }

            pack .icw.l
            bind .icw <Button-1> "wm deiconify $w(tw)"
            wm iconwindow $w(tw) .icw
        }
    }

    if {$g(windowingSystem) == "x11"} {
        if {[get_gtk_params]} {
           debug-info "gtk"
        } elseif {[get_cde_params]} {
           debug-info "cde"
        } else {
           debug-info "x11 fallback"
           set hlbg "#4a6984"
           set hlfg "#ffffff"
           #set w(selcolor) $hlbg
           if {$tk_version >= 8.5} {
             option add *Menu.selectColor $w(foreground)
             option add *Checkbutton.selectColor ""
             option add *Radiobutton.selectColor ""
           } else {
             option add *selectColor $hlbg
           }
        }
    }
    if {$g(windowingSystem) == "aqua"} {
        get_aqua_params
    }

#   Wipe the data structure clean ...
    wipe

#   ... then interpolate command args
#
#       'commandline' will EXIT if args are INCORRECT/INVALID, or pass
#   control to 'newDiffDialog' if simply missing; EITHER of which will,
#   in turn, invoke 'assemble-args' to OBTAIN the first (or only)
#   pairing of actual files to DIFF. If MULTIPLE pairs resulted from
#   that proc, SUBSEQUENT pairings will be chooseable via the GUI.
#   Insufficient pairings results in an "Abort".

    if {[commandline] > 0 || [newDiffDialog]} {
        if {![assemble-args]} {fatal-error "$g(name): Aborted"}
    } elseif {![info exists ::waitvar] || !$::waitvar} {do-exit}

    # The ONLY WAY this exists is if 'assemble-args' was forced
    # to warn about delayed SCM access time - get rid of it
    #   (and any lingering ASYNC processing condition)
    if {[info exists w(status)] && [winfo exists $w(status)]} {
        wm forget $w(status)
        unset -nocomplain ASYNc(trigger)
        debug-info "ASYNC mode has been dropped"
    }

    set g(startPhase) 1

    create-display

    update

    # Evaluate any custom code the user MAY have provided
    if { "$opts(customCode)" != {}} {
        debug-info "Custom code IS in use...beware"
        if {[catch [list uplevel \#0 $opts(customCode)] error]} {
            set startupError "Error in custom code: \n\n$error"
        } else {
            update
        }
        reconfigure-toolbar ;# which MAY have tried to set w(selcolor)
    }

    do-diff

    update-display

    # this forces all of the various scrolling windows (line numbers,
    # change bars, etc) to get in sync.
    set yview [$w(RightText) yview]
    vscroll-sync 2 [lindex $yview 0] [lindex $yview 1]
    hscroll-sync 1 0
    hscroll-sync 2 0

    # OPA >>>
    # wm deiconify .
    # OPA <<<
    update idletasks
    raise $w(tw)

    if {[info exists startupError]} {
        tk_messageBox -icon warning -type ok -title "$g(name) - Error in\
          Startup File" -message $startupError
    }
}

###############################################################################
# Erase tmp files (if necessary) and destroy the application.
###############################################################################
proc del-tmp {} {
    global g

    foreach f $g(tempfiles) {
        file delete $f
    }
}

###############################################################################
# Put up a window with formatted text
###############################################################################
proc do-text-info {wid title text} {
    global g w

    catch "destroy $wid"
    toplevel $wid

    wm group $wid $w(tw)
    wm transient $wid $w(tw)
    wm title $wid "$g(name) Help - $title"

    if {$g(windowingSystem) == "aqua"} {
        setAquaDialogStyle $wid
    }

    set width 64
    set height 32

    frame $wid.f -bd 2 -relief sunken
    pack $wid.f -side top -fill both -expand y

    text $wid.f.title -highlightthickness 0 -bd 0 -height 2 -wrap word \
      -width 50 -background white -foreground black

    text $wid.f.text -wrap word -setgrid true -padx 20 -highlightthickness 0 \
      -bd 0 -width $width -height $height -yscroll [list $wid.f.vsb set] \
      -background white -foreground black
    scrollbar $wid.f.vsb -borderwidth 1 -command [list $wid.f.text yview] \
      -orient vertical

    pack $wid.f.vsb -side right -fill y -expand n
    pack $wid.f.title -side top -fill x -expand n
    pack $wid.f.text -side left -fill both -expand y

    focus $wid.f.text

    button $wid.done -text Dismiss -command "destroy $wid"
    pack $wid.done -side right -fill none -pady 5 -padx 5

    put-text $wid.f.title "<ttl>$title</ttl>"
    put-text $wid.f.text $text
    $wid.f.text configure -state disabled

    wm geometry $wid ${width}x${height}
    update idletasks
    raise $wid
}

###############################################################################
# centers window w over parent
###############################################################################
proc centerWindow {w {size {}}} {
    update
    set parent .

    if {[llength $size] > 0} {
        set wWidth [lindex $size 0]
        set wHeight [lindex $size 1]
    } else {
        set wWidth [winfo reqwidth $w]
        set wHeight [winfo reqheight $w]
    }

    set pWidth [winfo reqwidth $parent]
    set pHeight [winfo reqheight $parent]
    set pX [winfo rootx $parent]
    set pY [winfo rooty $parent]

    set centerX [expr {$pX +($pWidth / 2)}]
    set centerY [expr {$pY +($pHeight / 2)}]

    set x [expr {$centerX -($wWidth / 2)}]
    set y [expr {$centerY -($wHeight / 2)}]

    if {[llength $size] > 0} {
        wm geometry $w "=${wWidth}x${wHeight}+${x}+${y}"
    } else {
        wm geometry $w "=+${x}+${y}"
    }
    update
}

###############################################################################
# The "New Diff" dialog
# In order to be able to enter only one filename if it's a revision-controlled
# file, the dialog now collects the arguments and sends them through the
# command line parser.
###############################################################################
proc newDiffDialog {} {
    global g w finfo opts pref waitvar
    debug-info "newDiffDialog"

    # OPA >>>
    set g(havePlainFiles) 0
    # OPA <<<

    set waitvar {}
    customize-initLabels ;# Needed for access to global 'pref' array

    if {![info exists w(newDiffPopup)]} {
        set w(newDiffPopup) .newDiffPopup
        debug-info " creating $w(newDiffPopup)"
        toplevel $w(newDiffPopup)

        wm group $w(newDiffPopup) $w(tw)
        # Won't start as the first window on Windows if it's transient
        if {[winfo exists $w(tw).client]} {
            wm transient $w(newDiffPopup) $w(tw)
        }
        wm title $w(newDiffPopup) "New Diff"

        if {$g(windowingSystem) == "aqua"} {
            setAquaDialogStyle $w(newDiffPopup)
        }

        wm protocol $w(newDiffPopup) WM_DELETE_WINDOW { \
            if {! [winfo exists $w(tw).client]} do-exit
            wm withdraw $w(newDiffPopup)              }
        wm withdraw $w(newDiffPopup)

        set simple [frame $w(newDiffPopup).simple -borderwidth 2 -relief groove]

        # N.B> The entry widget naming is constrained by the 'newDiffBrowse'
        #      callback in regard to the LAST letter of their pathname to
        #      implement a 'shared directory path' protocol among the TWO main
        #      entry widgets 'e1' and 'e2'. A trailing NON-digit will AVOID it.
        # Each revision label must also reflect when its ENTRY is non-null
        label $simple.l1 -text "FSpec 1:"
        set w(newDiffPopup,refocus) [entry $simple.e1 -textvariable finfo(f,1)]
        entry $simple.er1 -textvariable finfo(rev,1) -validate key \
                      -vcmd [list occupancy [label $simple.lr1 -text "-r"] %P]
        $simple.er1 validate

        label $simple.l2 -text "FSpec 2:"
        entry $simple.e2 -textvariable finfo(f,2)
        entry $simple.er2 -textvariable finfo(rev,2) -validate key \
                      -vcmd [list occupancy [label $simple.lr2 -text "-r"] %P] 
        $simple.er2 validate

        label $simple.lA -text "Ancestor:"
        entry $simple.eA -textvariable finfo(f,0)
        entry $simple.erA -textvariable finfo(rev,0) -validate key \
                      -vcmd [list occupancy [label $simple.lrA -text "-r"] %P]
        $simple.erA validate

        set mrgopt [frame $simple.f4] ;# pre-pack all this
          label $mrgopt.l4 -text "$pref(predomMrg):" -anchor w
          radiobutton $mrgopt.r1 -variable opts(predomMrg) -text Left  -value 1
          radiobutton $mrgopt.r2 -variable opts(predomMrg) -text Right -value 2
          pack $mrgopt.l4 $mrgopt.r1 $mrgopt.r2 -side left


        # We need the Browser buttons to fit the COMBINED height of BOTH the
        # filename entry and revision fields, so pre-pack it into a subframe
        set Brws1 [labelframe $simple.fB1 -text "Browse..."]
            button $Brws1.bf -borderwidth 1 -highlightthickness 0 -image \
                   txtfImg -command [list newDiffBrowse   "File"    $simple.e1]
            button $Brws1.bd -borderwidth 1 -highlightthickness 0 -image \
                   fldrImg -command [list newDiffBrowse "Directory" $simple.e1]
            pack $Brws1.bf -padx {7 0} -pady {0 2} -side left
            pack $Brws1.bd -padx {0 7} -pady {0 2} -side right
            set_tooltips $Brws1.bf {"to a file"}
            set_tooltips $Brws1.bd {"to a directory"}

        set Brws2 [labelframe $simple.fB2 -text "Browse..."]
            button $Brws2.bf -borderwidth 1 -highlightthickness 0 -image \
                   txtfImg -command [list newDiffBrowse   "File"    $simple.e2]
            button $Brws2.bd -borderwidth 1 -highlightthickness 0 -image \
                   fldrImg -command [list newDiffBrowse "Directory" $simple.e2]
            pack $Brws2.bf -padx {7 0} -pady {0 2} -side left
            pack $Brws2.bd -padx {0 7} -pady {0 2} -side right
            set_tooltips $Brws2.bf {"to a file"}
            set_tooltips $Brws2.bd {"to a directory"}

        set Brws3 [labelframe $simple.fB3 -text "Browse..."]
            button $Brws3.bf -borderwidth 1 -highlightthickness 0 \
                     -image txtfImg \
                     -command [list newDiffBrowse "File" $simple.eA "Ancestor"]
            pack $Brws3.bf -side top
            set_tooltips $Brws2.bf {"to a file"}

        # we'll use the grid geometry manager to get things lined up right...
        grid $simple.l1 -row 0 -column 0 -sticky e
        grid $simple.e1 -row 0 -column 1 -columnspan 4 -sticky nsew -pady 4
        grid $simple.lr1 -row 1 -column 2
        grid $simple.er1 -row 1 -column 3
        grid $Brws1 -row 0 -column 5 -rowspan 2 -sticky nsew -padx 4 -pady 4

        grid $simple.l2 -row 2 -column 0 -sticky e
        grid $simple.e2 -row 2 -column 1 -columnspan 4 -sticky nsew -pady 4
        grid $simple.lr2 -row 3 -column 2
        grid $simple.er2 -row 3 -column 3
        grid $Brws2 -row 2 -column 5 -rowspan 2 -sticky nsew -padx 4 -pady 4

        grid $simple.lA -row 4 -column 0 -sticky e
        grid $simple.eA -row 4 -column 1 -columnspan 4 -sticky nsew -pady 4
        grid $simple.lrA -row 5 -column 2
        grid $simple.erA -row 5 -column 3
        grid $Brws3 -row 4 -column 5 -rowspan 2 -sticky nsew -padx 4 -pady 4

        grid $simple.f4 -row 6 -column 0 -columnspan 4 -sticky w -pady 4

        grid columnconfigure $simple 1 -weight 1
        grid columnconfigure $simple 4 -weight 2

        set options [frame $w(newDiffPopup).options -borderwidth 2 \
          -relief groove]

        button $options.more -text "More" -command open-more-options

        label $options.ml -text "Merge Output"
        entry $options.me -textvariable g(mergefile)
        label $options.al -text "Ancestor"
        entry $options.ae -textvariable finfo(f,0)
        label $options.l1l -text "Label for File 1"
        entry $options.l1e -textvariable finfo(ulbl,1)
        label $options.l2l -text "Label for File 2"
        entry $options.l2e -textvariable finfo(ulbl,2)

        grid $options.more -column 0 -row 0 -sticky nw
        grid columnconfigure $options -0 -weight 0

        # here are the buttons for this dialog...
        set commands [frame $w(newDiffPopup).buttons]

        button $commands.ok -text "Ok" -width 5 -default active -command {
            set waitvar 1
        }
        button $commands.cancel -text "Cancel" -width 5 -default normal \
          -command {
            if {! [winfo exists $w(tw).client]} {tkdiff-CloseAppWindow}
            wm withdraw $w(newDiffPopup); set waitvar 0
        }
        pack $commands.ok $commands.cancel -side left -fill none -expand y \
          -pady 4

        catch {$commands.ok -default 1}

        # pack this crud in...
        pack $commands -side bottom -fill x -expand n
        pack $simple -side top -fill both -ipady 2 -ipadx 20 -padx 5 -pady 5

        pack $options -side top -fill both -ipady 5 -ipadx 5 -padx 5 -pady 5

        bind $w(newDiffPopup) <Return> [list $commands.ok invoke]
        bind $w(newDiffPopup) <Escape> [list $commands.cancel invoke]

    } else {
        debug-info " $w(newDiffPopup) already exists, just centering"
        if {[winfo exists $w(tw).client]} {
            # but it SHOULD be a transient from now on (if it isnt already)
            if {[wm transient $w(newDiffPopup)] == ""} {
                wm transient $w(newDiffPopup) $w(tw)
            }
            centerWindow $w(newDiffPopup)
        }
        update
    }
    wm deiconify $w(newDiffPopup)
    raise $w(newDiffPopup)
    focus $w(newDiffPopup,refocus)
    set detectMrgFilChg $g(mergefile)
    ######
    tkwait variable waitvar        ;# MODAL: wait for user to interact
    ######
    # Only lock-in Mergefile if user CHANGED and ACCEPTED it
    if {$waitvar && $g(mergefile) != "" } {
        set g(mergefileset) [expr {$g(mergefile) != $detectMrgFilChg}]
    }
    wm withdraw $w(newDiffPopup)
    return $waitvar
}

proc occupancy {wdg newV} {
    # Disables the LABEL (wdg) when the ENTRY value (newV) is empty ...
    #   (simply a GUI feedback trick to discern an EMPTY field from BLANKS)
    if {[string length $newV]} {
        $wdg configure -state normal
    } else {
        $wdg configure -state disabled
    }
    return true
}

proc open-more-options {} {
    global w

    grid $w(newDiffPopup).options.ml -row 0 -column 1 -sticky e
    grid $w(newDiffPopup).options.me -row 0 -column 2 -sticky nsew -pady 4
    grid $w(newDiffPopup).options.l1l -row 1 -column 1 -sticky e
    grid $w(newDiffPopup).options.l1e -row 1 -column 2 -sticky nsew -pady 4
    grid $w(newDiffPopup).options.l2l -row 2 -column 1 -sticky e
    grid $w(newDiffPopup).options.l2e -row 2 -column 2 -sticky nsew -pady 4

    grid columnconfigure $w(newDiffPopup).options 2 -weight 1

    $w(newDiffPopup).options.more configure -text "Less" \
      -command close-more-options
    set x [winfo width $w(newDiffPopup)]
    set y [winfo height $w(newDiffPopup)]
    set yi [winfo reqheight $w(newDiffPopup).options]
    set newy [expr $y + $yi]
    if {[winfo exists $w(tw).client]} {
       centerWindow $w(newDiffPopup)
    } else {
       update
    }
}

proc close-more-options {} {
    global g w finfo

    grid remove $w(newDiffPopup).options.ml
    grid remove $w(newDiffPopup).options.me
    grid remove $w(newDiffPopup).options.l1l
    grid remove $w(newDiffPopup).options.l1e
    grid remove $w(newDiffPopup).options.l2l
    grid remove $w(newDiffPopup).options.l2e

    set g(conflictset) 0
    set g(mergefileset) 0
    set g(mergefile) ""
    set finfo(ulbl,1) ""
    set finfo(ulbl,2) ""

    $w(newDiffPopup).options.more configure -text "More" \
      -command open-more-options
}

###############################################################################
# File/Directory browser for the "New Diff" dialog
###############################################################################
proc newDiffBrowse {type widget {title {}}} {
    global w opts
    debug-info "newDiffBrowse($type $widget)"

    # Uses TARGET widget name to locate OTHER widget field (expects a 1 or 2)
    if {[string is digit [set n [string index $widget end]]]} {
    set widgroot [string range $widget 0 end-1]
    set other([set other(2) 1]) 2
    } else { set n {} }

    # Start from what is IN the target already
    #   Basically we want each item to START browsing from where
    #   the most recent request left off; that means (in order):
    #      - the dirctory of where it is already
    #      - the directory of where the OTHER entry is (widgets 1 & 2 only)
    #      - the current working directory
    #   Note that the PRIOR use of EITHER item CAN itself BE a directory
    if {[set entrystuff [$widget get]] != ""} {
        if {![file isdirectory [set initdir $entrystuff]]} {
            set initfil [file tail $initdir]
            set initdir [file dirname $initdir]
        } else {set initfil {}}

    } elseif {$n!={} && [set entrystuff [${widgroot}$other($n) get]] != ""} {
        if {![file isdirectory [set initdir $entrystuff]]} {
            set initfil [file tail $initdir]
            set initdir [file dirname $initdir]
        } else {set initfil {}}

    } else { set initdir [pwd]; set initfil {} }
    debug-info "initdir($initdir) initfil($initfil)"

    # What KIND of entry are we browsing to find ?
    switch -glob $type {
    "D*" { set chosen [tk_chooseDirectory -title "$type ${n}${title}" \
                        -parent $w(newDiffPopup) \
                        -initialdir $initdir]
        }
    "F*" { set chosen [tk_getOpenFile -title "$type ${n}$title" \
                        -parent $w(newDiffPopup)    \
      -filetypes $opts(filetypes) \
                        -initialfile $initfil       \
                        -initialdir  $initdir]
        }
    }

    # Send back what we got (inserted if successful)
    if {[string length $chosen] > 0} {
        $widget delete 0 end
        $widget insert 0 $chosen
        $widget selection range 0 end
        $widget xview end
        focus $widget
    } else { after idle {raise $w(newDiffPopup)} }
    return $chosen
}

###############################################################################
# Split or Combine Dialog (modal): adjust CDR bounds & form EQUIVALENT diff(s)
###############################################################################
proc splcmb-Dialog {Combine} {
    global g w opts splcmb

    # (If first time invoked) ... Construct the Dialog window itself)
    if {! [winfo exists $w(scDialog)]} {
        # Encode the addressable slots/labels for loading into a 5x3 grid:
        set row(u)  [set col(l) 0]     ;# Upper row  (or)  Left col-pair(0&1)
        set row(l)              2      ;# Lower row
        set col(r)              3      ;# Right col-pair(3&4)
        set lbl(l)  "Left Side"        ;# (both SIDE labels go in row 1)
        set lbl(r)  "Right Side"       ;#
        set lbl(lu) "Upper Edge"       ;# (both EDGE labels go in col 2)
        set lbl(ll) "Lower Edge"       ;#
        #   (Button columns are designed as VERTICALLY-OPPOSED pairings)
        lassign { 0 0  1 1  3 3  4 4}  col(luu) col(lld)   col(lud) col(llu) \
                                       col(rud) col(rlu)   col(ruu) col(rld)

        # Now start building the dialog
        toplevel $w(scDialog)
        label $w(scDialog).msg ;# Message content will be supplied later
        wm transient $w(scDialog) .
        if {$g(windowingSystem) == "aqua"} {
            setAquaDialogStyle $w(scDialog)
        }
        pack $w(scDialog).msg -side top -padx 4 -pady 4

        # Populate the 5x3 grid (logically 3x3, but outer cols span 2 each)
        frame [set BtnFr $w(scDialog).btn] -relief groove -padx 4 -pady 4
        foreach LR {l r} {      ;# Left Right    SIDE > collectively forms
          foreach UL {u l} {    ;# Upper Lower   EDGE > widget names & args
            foreach DU {d u} {  ;# Down Up       BUTN >  to "splcmb-adj"
              set nm "."
              button ${BtnFr}[append nm $LR $UL $DU] -image arroW$DU \
                  -repeatdelay 750  -repeatinterval 400 \
                  -command [list splcmb-adj $LR $UL $DU]
          ### Huh? this was INTENDED to make btn image disappear when disabled
          #   Instead it just stipples the original buttonface image. Why??
          ### ${BtnFr}$nm configure -disabledf [${BtnFr}$nm cget -bg]
              grid ${BtnFr}$nm -row $row($UL) -column $col(${LR}${UL}$DU)
            }
            if {[info exists lbl(${LR}$UL)]} {                  ;# Edge label
              label ${BtnFr}[set nm .lB${LR}$UL] -text "$lbl(${LR}$UL)"
              grid  ${BtnFr}$nm -row $row($UL) -column 2
            }
          }
          label ${BtnFr}[set nm .lB$LR] -text "$lbl($LR)"   ;# Side label
          grid ${BtnFr}$nm -row 1 -column $col($LR) -columnspan 2
        }
        pack $BtnFr -side top -padx 4 -pady 4

        # Set up to signal 'tkwait ::scDialogRet' when user has completed task
        button $w(scDialog).done -command {set scDialogRet 1} ;# -text later
        button $w(scDialog).cncl -command {set scDialogRet 0} -text "Cancel"
        pack $w(scDialog).done $w(scDialog).cncl -pady 4 -side left -expand yes
        set ::scDialogRet 0 ;# (N.B> make certain this exists)

        # Tell window manager who we are and not to initially display us
        wm title $w(scDialog) "Adjust Diff Bounds"
        wm withdraw $w(scDialog)

        # (Should put this definition somewhere more global for use elsewhere)
        bind modalDialog <ButtonPress> {wm deiconify %W ; raise %W}

        # Ensure dialog can be RAISED during its modal-grab if hidden
        # and arrange to simply 'Cancel' if closed by the window manager
        bindtags $w(scDialog) [linsert [bindtags $w(scDialog)] 0 modalDialog]
        wm protocol $w(scDialog) WM_DELETE_WINDOW  {$w(scDialog).cncl invoke}
    } { set BtnFr $w(scDialog).btn }
    set oldFocus [focus] ;# (just hang on to this to restore afterward)

    # # # # # # # # # # # # # # # # # # # # #
    # Re-configure Dialog contents for PRESENT usage
    #   Some settings MAY depend on whether mode is "Split" .vs. "Combine"
    if {$Combine} {
        $w(scDialog).done configure -text "Combine"
        $w(scDialog).msg configure -text \
                             "Use buttons to EXPAND the current diff region"
        lassign {disable normal} inward outward ;# cmbin btns init state
    } else {
        $w(scDialog).done configure -text "Split"
        $w(scDialog).msg configure -text \
                             "Use buttons to REDUCE the current diff region"
        lassign {normal disable} inward outward ;# split btns init state
    }
    foreach {b} {luu ruu lld rld} {$BtnFr.$b configure -state $outward}
    foreach {b} {lud rud llu rlu} {$BtnFr.$b configure -state $inward}

    # Identify the target CDR, its Line info (and extract its type)
    lassign $g(scrInf,[set hID [hunk-id $g(pos)]]) S E Pl Ol na Pr Or
    regexp {[0-9,]*([acd])[0-9,]*} $hID na CDRtyp

    # # # # # # # # # # # # # # # # # # # # #
    # Next, establish the 'working set' of data (global splcmb array entries)
    # Start fresh by flushing any old data and recording the CDR info and ID
    unset -nocomplain splcmb
    set splcmb(rnge) [list [list $S $E $Pl $Ol $Pr $Or $hID]]
 
    # Also initialize the 'Pad'-lines "jump" table for EACH side
    #   A jump table records pairs of line numbers that correspond to the top
    #   and bottom of a contiguous run of "Pad" lines IN a splcmb(rnge) entry.
    #   Used later in "splcmb-adj" to *jump* past those lines when editting.
    set splcmb(jl) [set splcmb(jr) {}]
    if {$Pl} {set splcmb(jl) [list [expr {$E-$Pl+1}] $E]}
    if {$Pr} {set splcmb(jr) [list [expr {$E-$Pr+1}] $E]}

    # Hmm, 'Combine' requires a lttle more work -
    if {$Combine} {
        # Must RE-derive the ORIGINAL bounds of which this CDR is a SUBSET
        #   (create some temps to work with)
        set minpos [set maxpos $g(pos)]
        set nS $S
        set nE $E

        # Now try to EXTEND those values OUTWARD as far as they can go
        while {$minpos > 1} {
            set nhID [hunk-id [incr minpos -1]]

            if {$nS == [lindex $g(scrInf,$nhID) 1] + 1} {
                # Subsume this hunk (it abuts the CDR leading edge)
                lassign $g(scrInf,$nhID) nS tE tPl tOl na tPr tOr
                set splcmb(rnge) [linsert $splcmb(rnge) 0 \
                                     [list $nS $tE $tPl $tOl $tPr $tOr $nhID]]
                if {$tPl} {set splcmb(jl) [linsert $splcmb(jl) 0 \
                                                  [expr {$tE-$tPl+1}] $tE]}
                if {$tPr} {set splcmb(jr) [linsert $splcmb(jr) 0 \
                                                  [expr {$tE-$tPr+1}] $tE]}
            } else { break }
        }

        while {$maxpos < $g(count)} {
            set nhID [hunk-id [incr maxpos]]

            if {$nE == [lindex $g(scrInf,$nhID) 0] - 1} {
                # Subsume this hunk (it abuts the CDR trailing edge)
                lassign $g(scrInf,$nhID) tS nE tPl tOl na tPr tOr
                lappend splcmb(rnge)  [list $tS $nE $tPl $tOl $tPr $tOr $nhID]
                if {$tPl} {lappend splcmb(jl) [expr {$nE-$tPl+1}] $nE}
                if {$tPr} {lappend splcmb(jr) [expr {$nE-$tPr+1}] $nE}
            } else { break }
        }
        # splcmb(rnge) now has an ORDERED list of possibly involved hunks;
        # and ORDERED splcmb(jr/jl) lists - ie. ALL its "jump table" info.
        # ALSO 'nS' and 'nE' now have the OUTERMOST encompassing EDGE values
    } else { set nS $S ; set nE $E }

    # Further adjust the "Combine"-mode buttons if CDR is AT either edge of
    #      the rnge (ie. already sitting at an exterior limit) ... 
    # -OR- further adjust the "Split"-mode buttons if its an "a/d"-type CDR to
    #      disallow adjustment to the ALL "Pad" lines side  (its pointless).
    set btns {} ;# Note: default is that NEITHER adjustment will be required
    if {$Combine} {
        if {$S == $nS} {set btns {luu ruu} }
        if {$E == $nE} {set btns {lld rld} }
    } elseif {"$CDRtyp" == "a" || "$CDRtyp" == "d"} {
        if {$Pl} {set btns {lud llu} }
        if {$Pr} {set btns {rud rlu} }
    }
    if {[llength $btns]} {foreach b $btns {$BtnFr.$b configure -state disable}}

    # Construct the (user modifiable) 'working set' of the PRESENT CDR edges
    #   (semantic indices refer to   SIDE and EDGE   pairings)
    # Note that the RELATIONSHIP of these MOVABLE edges to the 'hard limit'
    # EDGES (defined next) WILL DEPEND on the "Split" .vs. "Combine" mode
    lassign "$S $E $S $E" splcmb(lu) splcmb(ll) splcmb(ru) splcmb(rl)
    incr splcmb(ll)  ;# Txt-wdg require 'lower' edge specs be 1 lower
    incr splcmb(rl)

    # Next, a (static) set of 'hard limits' semantically BRACKETING the edges
    #   This semantic is an ['i'nner/'o'uter -plus- 'u'pper/'l'ower] concept
    #   describing where any given BTN (and its implied EDGE) is HEADING to.
    #       NOTE: this will LATER REQUIRE a mode-specific reverse-mapping
    #   conversion (in "splcmb-adj") that can mirror the distinct edge VALUE
    #   REARRANGEMENT being done here (would've been easy if Tcl had pointers!)
    lassign "$nS $S $E $nE" splcmb(ou) splcmb(iu) splcmb(il) splcmb(ol)
    incr splcmb(ol)  ;# As before, lower bnds must be BELOW range (for Txt-wdg)
    incr splcmb(il)
    
    # Last config step - setup for the Txt-wdg tagging, ensuring visibility...
    foreach wdg "$w(LeftText) $w(RightText)" {
        $wdg  tag configure scCDR -background $opts(adjcdr)
        $wdg  tag configure scADD -background $opts(mapins)
        $wdg  tag configure scCHG -background $opts(mapchg)
        $wdg  tag configure scDEL -background $opts(mapdel)
        $wdg  see $S.0 ;# N.B> grab will BLOCK scrolling: becomes OUR problem
    }
    # ... and now 'paint' the CURRENT (starting) state for the user.
    #   (Note: this ALSO *creates* datums describing the Split/Combine STATE)
    splcmb-Feedback $Combine

    # # # # # # # # # # # # # # # # # # # # #
    # FINALLY ... Invoke the actual Dialog
    wm deiconify $w(scDialog)
    catch {tkwait visibility $w(scDialog)}
    catch {grab set $w(scDialog)}
    tkwait variable ::scDialogRet
    #
    # # # # # # # # # # # # # # # # # # # # #
    # wait here for the user to do their thing ... (tick, tick, tick)
    # # # # # # # # # # # # # # # # # # # # #
    #
    # Continue processing, beginning with taking down the Dialog itself
    grab release $w(scDialog)
    focus $oldFocus
    wm withdraw $w(scDialog)

    # ELIMINATE all Dialog-overlaid-tagging in the Text widgets
    foreach wdg "$w(LeftText) $w(RightText)" {
        $wdg tag delete scADD scDEL scCHG scCDR
    }

    #splcmb-chk data ;# Formatted DEBUG output

    # And BAIL-OUT if user Cancelled  -OR-  made no ACTUAL changes
    #   (each movable edge is AT its original STARTING position)
    if {!$::scDialogRet || \
        ( ($splcmb(lu)==$splcmb(ru) && $splcmb(lu)==$S)   && \
          ($splcmb(ll)==$splcmb(rl) && $splcmb(ll)==$E+1) )} {
        return
    }

    # # # # # # # # # # # # # # # # # # # # #
    # Interpret/process the users interaction
    #

    # Factor-out/realign the minor inconsistencies between Split and Combine
    if {$Combine} {
        # Among the hIDs within 'splcmb(rnge)', ignore ALL that the user has
        # chosen to NOT coalesce any portion of BACK within the CDR boundary
        #   (Remember: to discount the implicit +1 of lower EDGE values)
        foreach {tS tE na tOl na tOr thID} [join $splcmb(rnge)] {
            if {($splcmb(lu)   > $tE && $splcmb(ru)   > $tE) \
            ||  ($splcmb(ll)-1 < $tS && $splcmb(rl)-1 < $tS)} {continue}

            lappend rnge $thID

            # Realign Numbering to FIRST involved hunk (to init LN(l/r) below)
            if {[llength $rnge]==1}  { lassign "$tS $tOl $tOr" S Ol Or }

            # Rewrite (promote) the CDR type UNLESS they will ALL agree
            if {"$CDRtyp" != "c" && "$thID" != \
                           [regexp -inline "\[0-9,]+$CDRtyp\[0-9,]+" $thID]} {
                set CDRtyp "c"
            }
        }
    } else { set rnge [list $hID] } ;# However, Split only involves the CDR

    # Neither mode should EVER evaluate the 'Pad'-side of a "NON-chg" CDR
    if {"$CDRtyp" == "a"} {set splcmb(l2) 0}
    if {"$CDRtyp" == "d"} {set splcmb(r2) 0}

    # (L)ine (N)umbering begins with values just PRIOR to first INVOLVED hunk
    set LN(l) [expr {$S -$Ol -1}]
    set LN(r) [expr {$S -$Or -1}]

    # At the moment, 'rnge' is a list of the INVOLVED hIDs (to be deleted).
    # Grab its count, to use later in ensuring g(pos) REMAINS a legal value
    # when the hunks being deleted HAPPEN to be at the high end of g(diff).
    set minpos [llength $rnge]

    # Walk each region - forming any NEW "hID"s (into 'rnge') as we go
    foreach rgn {1 2 3} { set NEWid {}
        # Skip entire region if BOTH sides empty ...
        if {!$splcmb(l$rgn) && !$splcmb(r$rgn)} { continue }

        # ... otherwise process BOTH halves to construct the SINGLE new hID
        # using a technique that roughly parallels what "mark-diffs" would do
        #   Step through the (D)datum item (bounds and type) for each side
        foreach LR {l r} {
            if {$splcmb(${LR}$rgn)} {
                foreach "bgn($LR) end($LR) typ" $splcmb(${LR}${rgn}D) {
                    # factor out encompassed jump entries (if any)
                    set i 0
                    foreach {n1 n2} $splcmb(j$LR) {
                        if {$bgn($LR) <= $n1 && $n2 <= $end($LR)} {
                            set i [expr {$i + $n2 - $n1 + 1}]
                        }
                    }
                    # THEN compute number of LOGICAL lines, and MAP the type
                    set sz($LR) [expr {$end($LR) - $bgn($LR) - $i}]
                    set t [string map "CDR $CDRtyp  ADD a  DEL d  CHG c" $typ]
                    switch $t {
                        "a" {    append NEWid $LN(l) a [incr LN(r)]
                             if {$sz($LR)} {
                                 append NEWid "," [incr LN(r) $sz($LR)]
                             }
                        }
                        "d" {    append NEWid [incr LN(l)]
                             if {$sz($LR)} {
                                 append NEWid "," [incr LN(l) $sz($LR)]
                             }
                                 append NEWid d $LN(r)
                        }
                        "c" {if {"$LR" == "r" } {
                                     append NEWid [incr LN(l)]
                                 if {$bgn(l) != $end(l)} {
                                     append NEWid "," [incr LN(l) $sz(l)]
                                 }
                                     append NEWid c [incr LN(r)]
                                 if {$bgn(r) != $end(r)} {
                                     append NEWid "," [incr LN(r) $sz(r)]
                                 }
                             }
                        }
                    }
                }
            }
        }
        lappend rnge $NEWid
    }
    # Combine will likely REMOVE more hunks than it ADDS. Ensure g(pos)
    # REMAINS within its eventual bounds; preferably unchanged
    #   (minpos was earlier set to the nunmber of hunks being removed)
    set minpos [expr {(-2 * $minpos) + [llength $rnge] + [llength $g(diff)]}]
    set g(pos) [min $minpos $g(pos)]

    # Remove and Replace the designated HIDs
    #   (but ensure the MAP is adjusted to the new regions)
    if {$opts(showmap) || $g(mapheight)} {set g(mapheight) -1}
    mark-diffs $rnge
    update-display
}

###############################################################################
# Split/Combine Dialog button callback: perform edge movement (and update UI)
###############################################################################
proc splcmb-adj {side edge btn} {
    global w splcmb

    # Only PERMITTED actions can invoke us, so NO CHECKs are EVER reqd
    #   (buttons are enabled/disabled as needed per invocation)
    # N.B> Args not only describe the action, but also the INVOKING widget
    debug-info "\n    Btn HIT: Side<$side>  Edge<$edge>  Btn<$btn>"

    # Invent some static translations to provide "symbolic meta-programming".
    # Many are basically just 'inverse mappings' indexed by an EDGE or a BTN,
    # (or a +/- 'btn' move defn). "push" (a <Split-only> predicate) says WHEN
    # colocated edges MUST move together and is indexed by an EDGE plus a BTN
    lassign { 1 1 0 0     1  -1     r l   l u   d u }                     \
            push(ud) push(lu) push(uu) push(ld)          mvEg(d) mvEg(u)  \
            otherS(l) otherS(r)   otherE(u) otherE(l)   otherB(u) otherB(d)

    # Recover the semantic MODE we are operating under (because we can't PASS
    # its value from a widget cmd), then use it to create a CONTEXT-SPECIFIC
    # mapping from Edge/Btn specs to the 'LIMit edge' each is APPROACHING
    # N.B> The Combine-mode mapping is  NECESSARILY DIFFERENT  than Split-mode
    #       Edge - Btn        "Combine"          "Split"
    #      Upperedge-Up   -> Outer-Upper    -> Outer-Upper
    #      Upperedge-Down -> Inner-Upper    -> Outer-Lower
    #      Loweredge-Up   -> Inner-Lower    -> Outer-Upper
    #      Loweredge-Down -> Outer-Lower    -> Outer-Lower
    if {[set CS [expr {[llength $splcmb(rnge)] - 1}]]} {
              set CSmap {uu ou    ud iu    lu il    ld ol}
    } else {  set CSmap {uu ou    ud ol    lu ou    ld ol} }

    # OK - Extract/categorize the CURRENT edge location values
    # THEN actually MOVE the designated edge ...
    #   (HOWEVER when in <Split-mode>):  IFF both edges WERE coincident, also
    #   conceptually PUSH (really drag) the OPPOSING edge along as well ...
    #   UNLESS the movement logically SEPARATEs the edges (ie. stops pushing)
    set aLIM $splcmb([string map $CSmap ${edge}$btn])      ;# (a)pproached LIM
    set bLIM $splcmb([string map $CSmap ${edge}$otherB($btn)]) ;# (b)ehind LIM
    set oldE $splcmb(${side}$edge)             ;# Edge ABOUT to move
    set oppE $splcmb(${side}$otherE($edge))    ;# (opp)osed Edge <Split only>

    #   MOVE the EDGE  !!
    set newE [incr splcmb(${side}$edge) $mvEg($btn)] 

    # Special condition (mostly meaningful for Combine):
    #   If moved edge WAS sitting *on* the "Opposite" LIM, its possibly ALSO
    #   a jump entry - so PRETEND we just moved THERE and let jumping fix it.
    # HOWEVER - This is really all about ensuring we NEVER "jump BACKWARD" by
    # accidentally STARTing from a "wrong direction" half of a jump tuple.
    #   (because *that* causes an endless-loop toggling jump condition)
    if {($oldE == $bLIM && [set i [lsearch $splcmb(j$side) $oldE]] >= 0) \
    &&  (($i & 1  && $mvEg($btn) < 0) || (!($i & 1) && $mvEg($btn) > 0))} {
        set newE $oldE}

    set i 0
    # Check if the move TRIGGERS a "jump": jumping moves to the "other end" 
    # of the jump tuple (which MUST be in the direction we are moving) ...
    # and THEN moves the edge AGAIN (by 1) UNLESS doing so would exceed the
    # approaching limit. Barring that, each successful jump forces a new pass,
    # looking for an ABUTTED jump, until no more exist (or 'aLIM' is found)
    #   N.B> A Split NEVER has abutted entries - Combine may have several
    while {$i < [llength $splcmb(j$side)]} {
        set i 0 ;# (start a new pass - ends @ aLIM or when NO jump is found)
        foreach jmp $splcmb(j$side) {
            if {$jmp == $newE} {
                set newE [lindex $splcmb(j$side) [expr {$i & 1 ? $i-1 : $i+1}]]
                if {$newE == $aLIM} { set i [llength $splcmb(j$side)]
                         set splcmb(${side}$edge) $newE
                } else { set splcmb(${side}$edge) [incr newE $mvEg($btn)]
                    if {$newE == $aLIM} { set i [llength $splcmb(j$side)] }
                }
                break
            }
            incr i
        }
    }
    # Also check if moving is "push"ing the opposing edge with it (Split only)
    if {$oldE == $oppE && $push(${edge}$btn)} {
        set oppE [set splcmb(${side}$otherE($edge)) $newE] }
 
    # Now the FUN - First, readjust which buttons will NOW be available ...
    set Bwdg $w(scDialog).btn.$side     ;# (just conserving src-code typing)
    if {$newE == $aLIM} {  if {$oppE == $aLIM && !$CS} {
            ${Bwdg}${edge}$otherB($btn)        configure -state normal
            ${Bwdg}$otherE($edge)$btn          configure -state disabled } \
          { ${Bwdg}${edge}$otherB($btn)        configure -state normal   }
        ${Bwdg}${edge}$btn                     configure -state disabled
    } else {
        if {!$CS && $oppE != $aLIM  && $oppE != $bLIM} {
            ${Bwdg}$otherE($edge)$otherB($btn) configure -state normal }
        ${Bwdg}${edge}$otherB($btn)            configure -state normal
    }

    # ... THEN add visual user feedback of what this boundary move MEANT
    splcmb-Feedback $CS

    # ADJUST Text VIEW (in the side just changed) so we see what happenned
    #   (user is UNABLE to scroll for themselves ... grab is in force)
    incr oldE $mvEg($otherB($btn))       ;# keeps OLD(+1) and NEW in view !!
    if {"$side"=="l"}  {$w(LeftText) see $oldE.0}  {$w(RightText) see $oldE.0}
}

###############################################################################
# Interpret, display and produce a data mapping of the CURRENT moved-edge state
###############################################################################
proc splcmb-Feedback {Combine} {
    global g w splcmb

    # Begin by UNtagging all Split/Combine highlighting from affected area
    foreach wdg "$w(LeftText) $w(RightText)" {
        foreach tag {scCDR scADD scDEL scCHG} {
            $wdg tag remove $tag $splcmb(ou).0 $splcmb(ol).0
        }
    }

    # Then put back what belongs based on CURRENT boundary conditions
    #   For Combine, compute the current EFFECTIVE Outer (U/L) bounds;
    #   Split ALREADY knows those bounds - just copy to the local vars
    if {$Combine} {
        # Begin by FINDING the outer (u/l) edges of the INVOLVED hIDs
        #   (remember to discount the +1 of the lower edges when comparing)
        set upper [set lower 0]
        foreach hunk $splcmb(rnge) {
            lassign $hunk S E na na na na hID
            if {($splcmb(lu)   > $E && $splcmb(ru)   > $E) \
            ||  ($splcmb(ll)-1 < $S && $splcmb(rl)-1 < $S)} {continue}

            # extract type
            regexp {[0-9,]*([acd])[0-9,]*} $hID na type

            # Retain JUST the first and last edge values (and its diff-type)
            if {!$upper}     {set upper $S; set typ(u) $type}
            if {$E > $upper} {set lower $E; set typ(l) $type; incr lower}
        }
    } else { lassign "$splcmb(ou) $splcmb(ol)" upper lower }

    # Now, arrange ALL edges (working and limits) as 3 top-to-btm
    # sub-regions, noting which HAS any content (per sub-region, per side).
    foreach LR {l r} {
        lassign {0 1 0} splcmb(${LR}1) splcmb(${LR}2) splcmb(${LR}3)
        set splcmb(${LR}1)  [expr \
                   {[set t(1$LR) $upper] < [set b(1$LR) $splcmb(${LR}u)]}]

        set splcmb(${LR}2)  [expr \
          {[set t(2$LR) $splcmb(${LR}u)] < [set b(2$LR) $splcmb(${LR}l)]}]

        set splcmb(${LR}3)  [expr \
                   {[set t(3$LR) $splcmb(${LR}l)] < [set b(3$LR) $lower]}]

        #debug-info [join [list \
        "<${LR}1>$splcmb(${LR}1)  <t1$LR>$t(1$LR)  <b1$LR>$b(1$LR)"    \
        "<${LR}2>$splcmb(${LR}2)  <t2$LR>$t(2$LR)  <b2$LR>$b(2$LR)"    \
        "<${LR}3>$splcmb(${LR}3)  <t3$LR>$t(3$LR)  <b3$LR>$b(3$LR)" ] "\n"]
    }

    # Then "paint" (tag) the occupied sub-regions in appropriate MAP colors
    # based on the LOGICALLY IMPLIED DIFFERENCE of each sub-region pairing
    # ALSO RECORD (via L/R sub-region 'D'atums) WHICH lines + type was set
    #
    # N.B> DECREMENTing 'bottom' values IN-BETWEEN its widget use and the
    #   subsequent recording produces a PURE "screen Lnum" data viewpoint
    #
    # Note: The only distinction reqd for 'Combine' is to PREVENT treating
    # the 'Pad'-only half of region 1&3 'a/d'-type hunks AS data (by turning
    # the 'occupied' flag OFF ... *AFTER* highlighting for user feedback)
    foreach rgn {1 2 3} {
        if {$splcmb(r$rgn) || $splcmb(l$rgn)} {
            if {$splcmb(r$rgn) && $splcmb(l$rgn)} {
                if {$rgn == 2} {       set tag scCDR
                if {! $splcmb(r$rgn)} {set tag scDEL}
                if {! $splcmb(l$rgn)} {set tag scADD}
                } else                {set tag scCHG}
                $w(LeftText)  tag add  $tag  $t(${rgn}l).0 $b(${rgn}l).0
                $w(RightText) tag add  $tag  $t(${rgn}r).0 $b(${rgn}r).0
                incr b(${rgn}l) -1
                incr b(${rgn}r) -1
                set splcmb(l${rgn}D) \
                         "$t(${rgn}l) $b(${rgn}l) [string range $tag 2 4]"
                set splcmb(r${rgn}D) \
                         "$t(${rgn}r) $b(${rgn}r) [string range $tag 2 4]"
            } elseif {$splcmb(r$rgn)} {
                $w(RightText) tag add scADD $t(${rgn}r).0 $b(${rgn}r).0
                incr b(${rgn}r) -1
                if {$Combine && (($rgn==1 && "$typ(u)"=="d") \
                || ($rgn==3 && "$typ(l)"=="d"))} {set splcmb(r$rgn) 0}
                set splcmb(r${rgn}D) "$t(${rgn}r) $b(${rgn}r) ADD"
            } else {
                $w(LeftText)  tag add scDEL $t(${rgn}l).0 $b(${rgn}l).0
                incr b(${rgn}l) -1
                if {$Combine && (($rgn==1 && "$typ(l)"=="a") \
                || ($rgn==3 && "$typ(l)"=="a"))} {set splcmb(l$rgn) 0}
                set splcmb(l${rgn}D) "$t(${rgn}l) $b(${rgn}l) DEL"
            }
        }
    }
}

###############################################################################
# Primarily code that advises (1|0) on eligibility of hunk for Split/Combine...
# ...but also provides a formatted STDOUT data-dump for debugging purposes
###############################################################################
proc splcmb-chk {what {pos 0}} {
    global g splcmb

    switch -exact -- $what {
        "split" {
            # Is dependant on there being MORE than 1 line on EITHER side
            # N.B> this PREVENTS splitting ANY one-line hunk (incl. "chg"-type)
            if {$pos <= $g(count) && $g(count) > 0} {
                lassign $g(scrInf,[hunk-id $pos]) S E Pl na na Pr
                return [expr {($E - $S) || ($Pl + $Pr > 1)}]
            }
        }

        "cmbin" {
            # Is dependant on there being some hunk ABUTTED either above/below
            if {$pos <= $g(count) && $g(count) > 1} {

                # Grab edge values of the target CDR at 'pos'
                lassign $g(scrInf,[hunk-id $pos]) S E

                # Validate and check BELOW target first, then ABOVE - and exit ASAP
                if {[incr pos -1]} {
                    if {($S - 1 == [lindex $g(scrInf,[hunk-id $pos]) 1])} {return 1}
                }
                if {[incr pos 2] <= $g(count)} {
                    if {($E + 1 == [lindex $g(scrInf,[hunk-id $pos]) 0])} {return 1}
                }
            }
        }

        "data" {
            if {"$pos" != "0"} { puts "***** $pos" } ;# <-- simply a dump identifier
            # This is a DRAMATICALLY more READABLE output format!!!
            puts " EDGES : <l>$splcmb(lu) $splcmb(ll)    <r>$splcmb(ru) $splcmb(rl)"
            puts " AMONG :"
            foreach {S E Pl Ol Pr Or hID} [join $splcmb(rnge)] {
                puts "[format "\t%d  %d    P=%d,%d    O=%d,%d    %s" \
                                 $S  $E     $Pl $Pr    $Ol $Or  $hID]"
            }
            puts "\nou $splcmb(ou)"
            foreach side {l r} {
                foreach rgn {1 2 3} {
                    if {$splcmb(${side}$rgn)} {
                        puts "\t${side}$rgn $splcmb(${side}$rgn)\t${side}${rgn}D\
                                                          $splcmb(${side}${rgn}D)"
                    } else {puts "\t${side}$rgn $splcmb(${side}$rgn)"}
                }
                if {"$splcmb(j$side)" != {}} {puts "\t\tj$side  $splcmb(j$side)"}
                if {"$side" == "l"} { if {[llength $splcmb(rnge)] > 1} {
                    puts "iu $splcmb(iu)\n\t(CDR)\nil $splcmb(il)" }  { puts "" }
                }
            }
            puts "ol+ $splcmb(ol)\n"
        }
    }
    return 0
}

###############################################################################
# all the code to handle the report writing dialog.
###############################################################################
proc write-report {command args} {
    global g w opts finfo report

    set w(reportPopup) .reportPopup
    switch -- $command {
    popup {
            if {![winfo exists $w(reportPopup)]} {
                write-report build
            }
            set report(filename) [file join [pwd] $report(filename)]
            write-report update

            centerWindow $w(reportPopup)
            wm deiconify $w(reportPopup)
            raise $w(reportPopup)
        }
    cancel {
            wm withdraw $w(reportPopup)
        }
    update {

            set stateLeft "disabled"
            set stateRight "disabled"
            if {$report(doSideLeft)} {
                set stateLeft "normal"
            }
            if {$report(doSideRight)} {
                set stateRight "normal"
            }

            $w(reportLinenumLeft) configure -state $stateLeft
            $w(reportCMLeft) configure -state $stateLeft
            $w(reportTextLeft) configure -state $stateLeft

            $w(reportLinenumRight) configure -state $stateRight
            $w(reportCMRight) configure -state $stateRight
            $w(reportTextRight) configure -state $stateRight

        }
    save {
            # probably ought to catch this, in case it fails. Maybe later...
            set handle [open $report(filename) w]

            puts $handle "$g(name) $g(version) report\n"

            # Mention the file name(s) ... BOTH unless exactly one is OFF
            set not([set not(Right) Left]) Right
            foreach {side} {Left Right} {
                if {$report(doSide$side) || !$report(doSide$not($side))} {
                    puts $handle "$side file : \t$finfo(lbl,$side)"
                }
            }

            puts $handle "\nNumber of diffs: $g(count)"

            # Produce some simple statistical data (REAL hunks ONLY)
            #   ("F" is simply a list of FIELD names to read hunk data into)
            #
            # First, initialize and get the counts of various quantities ...
            lappend F S E P(Left) O(Left) C(Left) P(Right) O(Right) C(Right)
            lassign { 0 0 0 0 "" 0 0 "" }  {*}$F
            set aCnt [set dCnt [set cCnt [set modLft 0]]]
            set aTot [set dTot [set cTot [set modRgt 0]]]
            foreach hID $g(diff) {
                lassign $g(scrInf,$hID) {*}$F

                switch -- "[append C(Left) $C(Right)]" {
                "+"  { incr aCnt ; incr aTot $P(Left)  ; incr modRgt $P(Left) }
                "-"  { incr dCnt ; incr dTot $P(Right) ; incr modLft $P(Right)}
                "!!" { incr cCnt ; incr cTot [expr {$P(Left) - $P(Right)}]
                       incr modLft     [expr {$E - $S - $P(Left)  + 1}]
                       incr modRgt     [expr {$E - $S - $P(Right) + 1}]       }
                }
            }
            set maxlns  [expr {int([$w(LeftText)  index end-1lines])}]

            # ... then compute what we can from them ...
            set sz(Left)  [expr {$maxlns - $O(Left)  - $P(Left) }]
            set sz(Right) [expr {$maxlns - $O(Right) - $P(Right)}]
            set pctLft [expr {double($modLft*100)/double($sz(Left)) }]
            set pctRgt [expr {double($modRgt*100)/double($sz(Right))}]

            # ... and report our findings
            set msg "%6d regions were %s: %d(net) modified lines"
            puts $handle [format "    $msg" $dCnt "deleted" $dTot]
            puts $handle [format "    $msg" $aCnt " added " $aTot]
            puts $handle [format "    $msg" $cCnt "changed" $cTot]
            puts -nonewline $handle "\n"
            set msg "%6d %s lines were affected: %4.4g %% of %6d"
            puts $handle [format "    $msg" $modLft "Left " $pctLft $sz(Left) ]
            puts $handle [format "    $msg" $modRgt "Right" $pctRgt $sz(Right)]
            puts $handle "\n"

            # (Re-)Load FIRST diff hunk values (if any - Fakes still exist)
            #   ("H", "skpH" & "pfxH" just track the hunk 'ndx' for use later)
            # N.B. code DETECTs & INTERPOLATEs further hunks AS lines advance
            if {$g(COUNT) > [set i [set skpH [set pfxH [set H 0]]]]} {
                    lassign $g(scrInf,[set hID [hunk-id [incr H] DIFF]]) {*}$F 
                if {[info exists g(overlap$hID)]}     {
                    set C(Left) [set C(Right) "?"]} \
                elseif {"$C(Left)$C(Right)" == ""}    {
                    incr skpH ;# account for the 'ignored' hunk
                }
            }

            # Now produce the requested categories of data (if any)
            if {(!$report(doSideRight) && !$report(doSideLeft))} {set maxlns 0}
            while {[incr i] < $maxlns} {

                set out(Left) [set out(Right) ""]
                foreach side {Left Right} {
                    if {!$report(doSide$side)} {continue}

                    # Waterfall test detects phase of WHERE "$i" falls IN hunk,
                    # thus what SHOULD be displayed (if not 'off' by request)
                    #
                    # N.B> DESPITE coding as loop - this RARELY ever needs to!
                    #   It exists ENTIRELY because there is NO 'goto' in Tcl;
                    # thus a 'continue' is the ONLY way to RE-start this code !
                    while {true} {

                    if {$H > 0 && $i >= $S} {
                        if {$i > ($E - $P($side))} {
                            if {$i > $E} {
                                if {$H < $g(COUNT)} {
                                    # Step forward to the NEXT hunk mapping
                                    set hID [hunk-id [incr H] DIFF]
                                    lassign $g(scrInf,$hID) {*}$F
                                    if {[info exists g(overlap$hID)]}  {
                                               set C(Left) [set C(Right) ?]} \
                                    elseif {"$C(Left)$C(Right)" == ""} {
                                        incr skpH ;# account for 'ignored' hunk
                                    }
                                    # WHY IS THERE NO goto IN THIS LANGUAGE!!!
                                    #
                                    # RESTART waterfall: 'i' MAY now be INSIDE
                                    # newly read-in hunk (supports abutted hunk
                                    # defs as created by Split/Combine feature)
                                    continue
                                    ## (Poor PGMRS is the problem - NOT goto !)

                                } else {set LN 1;set CB 0 } ;# Is beyond hunk
                            } else    { set LN  [set CB 0]} ;# A PADDING line
                        } else        { set LN  [set CB 1]} ;# A  DIFF   line
                    } else            { set LN 1;set CB 0 } ;# Is before hunk

                    break ;# if we reach here, we need NOT go back around!!
                    }

                    # "Diffs Only" acts as a filter, blocking ALL other attrs.
                    if {"$report(doText$side)"=="Diffs Only"} {
                        if {$LN && !$CB} { continue } {
                            # However, when actually *IN* a diff region make
                            # ONE 'Diff Header' prefix at 1st line of 1st side
                            if {$pfxH < ($H - $skpH) } {
                                puts $handle "\nDiff #[incr pfxH] ($hID):"
                            }
                        }
                    }

                    if {$report(doLineNumbers$side)} {
                        if {$LN} { append out($side) \
                           [format "%*d " $g(lnumDigits) [expr {$i-$O($side)}]]
                        } else {continue}
                        # N.B> LN==0 implys a PAD line (No Cbar/Text can exist)
                        #   Thus no need to append ANYTHING to this line !!
                    }

                    if {$report(doChangeMarkers$side)} {
                        append out($side) [string range \
                                      [expr {$CB ? "$C($side)  " : "  "}] 0 1]
                    }

                    if {"$report(doText$side)" != " (no text) "} {
                        append out($side) [string trimright \
                                   [$w(${side}Text) get "$i.0" "$i.0 lineend"]]
                    }
                }

                if {$report(doSideLeft) == 1 && $report(doSideRight) == 1} {
                    set output [format "%-90s%-90s" "$out(Left)" "$out(Right)"]

                } elseif {$report(doSideRight) == 1} {
                    set output "$out(Right)"

                } elseif {$report(doSideLeft) == 1} {
                    set output "$out(Left)"

                }
                set output "[string trimright "$output"]"
                if {[string length "$output"]} { puts $handle "$output" }
            }
            close $handle

            wm withdraw $w(reportPopup)
        }
    browse {
            set path [tk_getSaveFile -parent $w(reportPopup) \
              -filetypes $opts(filetypes) \
              -initialdir [file dirname $report(filename)] \
              -initialfile [file tail $report(filename)]]

            if {[string length $path] > 0} {
                set report(filename) $path
            }
        }
    build {
            catch {destroy $w(reportPopup)}
            toplevel $w(reportPopup)
            wm group $w(reportPopup) $w(tw)
            wm transient $w(reportPopup) $w(tw)
            wm title $w(reportPopup) "$g(name) - Generate Report"
            wm protocol $w(reportPopup) WM_DELETE_WINDOW [list write-report \
              cancel]
            wm withdraw $w(reportPopup)

            if {$g(windowingSystem) == "aqua"} {
                setAquaDialogStyle $w(reportPopup)
            }

            set cf [frame $w(reportPopup).clientFrame -bd 2 -relief groove]
            set bf [frame $w(reportPopup).buttonFrame -bd 0]
            pack $cf -side top -fill both -expand y -padx 5 -pady 5
            pack $bf -side bottom -fill x -expand n

            # buttons...
            set w(reportSave) $bf.save
            set w(reportCancel) $bf.cancel

            button $w(reportSave) -text "Save" -underline 0 -command \
              [list write-report save] -width 6
            button $w(reportCancel) -text "Cancel" -underline 0 \
              -command [list write-report cancel] -width 6

            pack $w(reportCancel) -side right -pady 5 -padx 5
            pack $w(reportSave) -side right -pady 5

            # client area.
            set col(Left) 0
            set col(Right) 1
            foreach side [list Left Right] {
                set choose [checkbutton $cf.choose$side]
                set linenum [checkbutton $cf.linenum$side]
                set cm [checkbutton $cf.changemarkers$side]
                tk_optionMenu [set txt $cf.text$side] report(doText$side) \
                                   "Full Text"    "Diffs Only"    " (no text) "

                $choose configure -text "$side Side" \
                  -variable report(doSide$side) -command [list write-report \
                  update]

                $linenum configure -text "Line Numbers" \
                  -variable report(doLineNumbers$side)
                $cm configure -text "Change Markers" \
                  -variable report(doChangeMarkers$side)

                grid $choose -row 0 -column $col($side) -sticky w
                grid $linenum -row 1 -column $col($side) -sticky w -padx 10
                grid $cm -row 2 -column $col($side) -sticky w -padx 10
                grid $txt -row 3 -column $col($side) -sticky w -padx 10

                # save the widget paths for later use...
                set w(reportChoose$side) $choose
                set w(reportLinenum$side) $linenum
                set w(reportCM$side) $cm
                set w(reportText$side) $txt
            }

            # the entry, label and button for the filename will get
            # stuffed into a frame for convenience...
            frame $cf.fileFrame -bd 0
            grid $cf.fileFrame -row 4 -columnspan 2 -sticky ew -padx 5

            label $cf.fileFrame.l -text "File:"
            entry $cf.fileFrame.e -textvariable report(filename) -width 30
            button $cf.fileFrame.b -text "Browse..." -pady 0 \
              -highlightthickness 0 -borderwidth 1 -command \
              [list write-report browse]

            pack $cf.fileFrame.l -side left -pady 4
            pack $cf.fileFrame.b -side right -pady 4 -padx 2
            pack $cf.fileFrame.e -side left -fill x -expand y -pady 4

            grid rowconfigure $cf 0 -weight 0
            grid rowconfigure $cf 1 -weight 0
            grid rowconfigure $cf 2 -weight 0
            grid rowconfigure $cf 3 -weight 0

            grid columnconfigure $cf 0 -weight 1
            grid columnconfigure $cf 1 -weight 1

            # make sure the widgets are in the proper state
            write-report update
        }
    }
}

###############################################################################
# Report the version of wish
###############################################################################
proc about_wish {} {
  global tk_patchLevel

  set version $tk_patchLevel
  set whichwish [info nameofexecutable]

  set about_string "$whichwish\n\n"
  append about_string "Tk version  $version"

  tk_messageBox -title "About Wish" \
    -message $about_string \
    -parent . \
    -type ok
}

###############################################################################
# Report the version of diff
###############################################################################
proc about_diff {} {

  set whichdiff [auto_execok diff]
  if {[llength $whichdiff]} {
    set whichdiff [join $whichdiff]
    set cmdline "diff -v"
    catch {eval "exec $cmdline"} output
    set message "$whichdiff\n$output"
  } else {
    set message "diff was not found in your path!"
  }

  tk_messageBox -title "About Diff" \
    -message $message \
    -parent . \
    -type ok
}

###############################################################################
# Throw up an "about" window.
###############################################################################
proc do-about {} {
    global g

    set title "About $g(name)"
    set text {
<hdr>$g(name) $g(version)</hdr>

<itl>$g(name)</itl> is a Tcl/Tk front-end to <itl>diff</itl> for Unix and\
      Windows, and is Copyright (C) 1994-2005 by John M. Klassa.

Many of the toolbar icons were created by Dean S. Jones and used with his\
      permission. The icons have the following copyright:

Copyright(C) 1998 by Dean S. Jones
dean@gallant.com
http://www.gallant.com/icons.htm
http://www.javalobby.org/jfa/projects/icons/

<bld>This program is free software; you can redistribute it and/or modify it\
      under the terms of the GNU General Public License as published by the\
      Free Software Foundation; either version 2 of the License, or (at your\
      option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT\
      ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or\
      FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License\
      for more details.

You should have received a copy of the GNU General Public License along with\
      this program; if not, write to the Free Software Foundation, Inc., 59\
      Temple Place, Suite 330, Boston, MA 02111-1307 USA</bld>
    }

    set text [subst -nobackslashes -nocommands $text]
    do-text-info .about $title $text
}

###############################################################################
# Throw up a "command line usage" window.
###############################################################################
proc do-usage {mode} {
    global g
    debug-info "do-usage ($mode)"

    set usage {
    $g(name) may be started in any of the following ways:
        (Note that a FILESPEC is either a file or a directory and
         optional parameters are documented here in square brackets)

    Interactive selection of files to compare:
        tkdiff

    Plain files:
        tkdiff FILESPEC1 FILESPEC2

    Plain file with conflict markers:
        tkdiff -conflict FILE

    Source control (AccuRev, BitKeeper, ClearCase, CVS, Git, Mercurial,\
      Perforce, PVCS, RCS, SCCS, Subversion)
        tkdiff  -rREV1 [-rREV2]  FILESPEC1 [FILESPEC2]
        tkdiff [-rREV1 [-rREV2]]              (Git or Subversion)
        tkdiff OLD-URL[@OLDREV] NEW-URL[@NEWREV]  (Subversion)

    Additional optional parameters:
        -a ANCESTORFILE
        -@ REV        (of Ancestorfile - if comming from Source control)
        -o MERGEOUTPUTFILE
        -L LEFT_FILE_LABEL [-L RIGHT_FILE_LABEL]
        -I RegularExpression           (ignore matched-lines)
        -B            (ignore empty-lines)
        -1,-2        (preferred default merge side)
        -d            (debugging output)
    }

    set usage [subst -nobackslashes -nocommands $usage]

    set text {
<hdr>Description</hdr>
Generally speaking, a diff is a <itl>directed</itl> comparison of two text\
      files that describes what would need to be changed to convert the first\
      such file content into the second. $g(name) thus groups its parameters\
      as specified into a "Left" and "Right" pairing based on their\
      <itl>repetition</itl> on the command line. Thus the first\
      <cmp>FILESPEC</cmp> encountered is <bld>usually</bld> the "Left" and the\
      next would be the "Right". Revision specifications work similarly.
      However, $g(name) occasionally <itl>infers</itl> an argument (be it\
      'filespec' or 'revision') to satisfy the need for two items to compare.\
      When this occurs, $g(name) will attempt to access a Source Code\
      Management (SCM: see below) system to provide the missing item, but it\
      will <itl>ALSO</itl> force that item to be the "Left", or first, element\
      of the comparison. Beyond that convention, each parameter is indepedent\
      of others on the commandline. Ultimately, all "Left" args are\
      collectively used to specify the item(s) to compare to item(s)\
      collectively formed by "Right" args.

In the first form, $g(name) will generally present a dialog to allow you to\
      choose the files to diff interactively (providing a detected SCM does\
      NOT produce a default comparison list). At present this dialog only\
      supports a diff between files or directories that already exist or can\
      be obtained by a recognized SCM (see below). Specifically it does not\
      permit the third form (described shortly), nor "Browsing" to a URL for\
      either <cmp>FILESPEC</cmp>. However, you may always <itl>type</itl>\
      anything that makes sense, be it URL, file path, or directory path or\
      simply "Browse" to <itl>either</itl> files or directories.
      Please note that <itl>most</itl> of the "Additional Optional parameters"\
      <itl>are available</itl> from the dialog, but are initially hidden from\
      view, as they are often not applicable except in special cases. If you\
      need to set them, <bld>do not</bld> re-"hide" them before clicking the\
      <btn>OK</btn> button on the dialog as hiding them <itl>ALSO</itl> causes\
      them ALL to become completely <bld>unset</bld>. Any items not provided\
      on that dialog ('Ignore...' settings) are presented elsewhere in $g(name).

In the second form, either or both <cmp>FILESPEC</cmp>s may be to a local file\
      or directory, or symbolic links to such. When a directory is involved,\
      only its contained FILES sharing a common name will be paired together,\
      one from each original <cmp>FILESPEC</cmp>. Note that this <itl>CAN</itl>\
      produce multiple pairs of files to be diffed (if both were directories).\
      $g(name) remembers all of them, and permits switching among them later.

In the third form, a single <cmp>FILE</cmp> containing "conflict markers" will\
      be split into two temporary files and used as ordinary input by $g(name).\
      Such files can be generated by external tools such as "<cmp>merge</cmp>",\
      "<cmp>cvs</cmp>", or "<cmp>vmrg</cmp>" and perhaps others.

The fourth form is conditional on $g(name) being able to detect a viable SCM\
      system (see below). However, make note that if it <itl>DOES</itl>, it\
      <bld>may</bld> effectively override the first form described earlier\
      (i.e. interactive startup). Presently only the "Git" or "Subversion" SCM\
      systems will behave this way, when invoked with no arguments as is\
      suggested here as syntactically possible.

<hdr>Source Code Control</hdr>
In all the SCM forms, $g(name) will detect which SCM system to utilize. This\
      detection supports RCS, CVS and SCCS by looking for a directory\
      with the same name, although RCS can also be detected via its ",v" file\
      naming suffix convention. It detects and supports PVCS by looking for a\
      vcs.cfg file. It detects and supports AccuRev, Perforce and ClearCase\
      by looking for the environment variables named ACCUREV_BIN, P4CLIENT,\
      and CLEARCASE_ROOT respectively. It detects Git by looking for a .git\
      directory, but will only work when started from within a Git work-tree.\
      Similarly, Subversion looks for a .svn directory, except when using\
      URLs, expecting any <cmp>FILESPEC</cmp> to reside within a recognized\
      "Working Copy" (WC). Mercurial is supported by looking for a directory\
      named ".hg" in the <cmp>FILESPEC</cmp> directory or any of its ancestor\
      directories, which is also how .git and .svn are searched.
      It is important to recognize that several detections are based on the\
      provided FILESPEC(s), or alternately the "current working directory"\
      where $g(name) was invoked, and at times, BOTH. Often this can\
      necessitate invoking $g(name) from <itl>within</itl> the "Sandbox" (a\
      synonym for "WC") which are the actual files and directories that the\
      specific SCM is actively tracking.

<cmp>REV1</cmp> and <cmp>REV2</cmp>, when given, must be a valid revision value\
      for <cmp>FILESPEC</cmp>. When the SCM system (RCS, CVS, etc.) is detected\
      (see above), but no revision number is given, <cmp>FILESPEC</cmp> is\
      compared with the revision most recently checked in. Again, multiple\
      pairings may still be possible, if <cmp>FILESPEC</cmp> was specified as\
      a directory; where each would then use the same revision.

Revision values are generally peculiar to a specific SCM. For example, a Git <cmp>REV</cmp>\
(see man git-rev-parse) offers several unusual variations:
     <cmp>FILE</cmp>                 [compare with <cmp>HEAD</cmp> by default]
  -r <cmp>HEAD</cmp> <cmp>FILE</cmp>        [compare with <cmp>HEAD</cmp>]
  -r <cmp>HEAD^</cmp> <cmp>FILE</cmp>      [compare with parent of <cmp>HEAD</cmp>]
  -r <cmp>HEAD~5</cmp> <cmp>FILE</cmp>    [compare with 5th parent of <cmp>HEAD</cmp>]
  -r <cmp>HEAD~20</cmp> -r <cmp>HEAD^</cmp> <cmp>FILE</cmp>   [compare 20th parent and parent of <cmp>HEAD</cmp>]
  -r 29329e <cmp>FILE</cmp>    [compare with commit 29329e (full/partial SHA1)]
  -r v1.2.3 <cmp>FILE</cmp>      [compare with tag (UNTESTED)]
$g(name) does not, itself, do anything with the value other than pass it along.

Lastly, some SCM systems provide utilities that can identify which of their\
      files are <itl>different</itl> given <itl>only</itl> a pair of revisions.\
      $g(name), using its capacity for accepting multiple pairings, will\
      attempt to access the utilities it knows about to obtain such as an\
      input source. SCM systems lacking this ability will simply reject the\
      existing command arguments as inadequate with an error message.
      Note that given the <bld>lack</bld> of a <cmp>FILESPEC</cmp> in this\
      instance, such SCM utilities basically expect the\
      "current working directory" (of, in this case, $g(name)) to <bld>be</bld>\
      the same as where they place the "working copies" of the files they\
      manage. Thus the directory where you invoke $g(name) plays a role, but\
      was likely instrumental in getting that SCM to be detected in the first\
      place, so should not be an issue.
      Accordingly, if only <itl>fewer</itl> than two revisions are given\
      <bld>and</bld> the SCM can accomodate it, inferred revisions will be\
      supplied (generally the latest or HEAD, or similar). However, note that\
      the <bld>Git</bld> SCM has an unusual arrangement in that an intermediate\
      UNNAMED revision (referred to as the 'stage' or 'index') sits between\
      the working copy and the last commit; $g(name) will allow you to specify\
      this quasi-revision using a revision value of " " (blanks) either on the\
      commandline or in the GUI dialog. Remember that on the commandline this\
      will require quoting (to be parsed correctly). For the GUI, the field\
      label for the revision will be dimmed when it is EMPTY, as it would\
      otherwise be difficult to actually SEE a legally enterred blank.

<hdr>A quick word about quoting</hdr>
Most command environments, a Unix/Linux Shell for example, offer multiple\
      means of quoting (such as single or double quote characters). As a\
      <itl>general</itl> rule, any $g(name) option flag that takes a value\
      (such as a <cmp>REV</cmp> or others) may be specified as directly\
      prefixed to that value, or separated by "white space" (blanks, tabs,\
      etc.). However you must <itl>not</itl> try to <bld>pack</bld> multiple\
      $g(name) flags into a single parameter as they will not be recognized\
      by $g(name), and would thus likely be passed directly to "diff" or\
      whatever other differencing engine has been configured, as is.\
      See the section "The Diff engine" below for further specific rules.

<hdr>Requesting a 3-Way diff</hdr>
A "3-Way" diff is most often used for merging a file that different people\
      may have worked on both <itl>independently</itl> and\
      <itl>simultaneously</itl>, <bld>back</bld> into a single file. Just as\
      files for comparison are designated with some combination of a FILESPEC\
      (and possible REV value), an ANCESTORFILE may be specified as a\
      <itl>third</itl> file using the "<bld>-a</bld>" option to designate it.
      To be useful, this file should be a version that <itl>closely</itl>\
      predates BOTH versions being compared/merged. If using an SCM to track\
      past versions, also specifying the "<bld>-@</bld>" option will provide\
      the necessary REV value to obtain the file.

<hdr>Additional hints</hdr>
With regard to inferred SCM revision fields, invoking $g(name) with no viable\
      arguments at all <itl>MAY</itl> result in <itl>either</itl> an SCM\
      trying to supply such args <bld>OR</bld> presenting the interactive\
      dialog. However, when an SCM <itl>is</itl> detected and accessed, but\
      results in not <itl>finding</itl> any files to compare, only a\
      termination message will be produced.

It is <itl>NOT</itl> recommended to specify an <cmp>ANCESTORFILE</cmp>,\
      <cmp>MERGEOUTPUTFILE</cmp> or more than two "<cmp>-L File-label</cmp>"\
      options when using any form that will resolve to more than a\
      <itl>single</itl> diff pair (i.e. generally when a directory\
      <cmp>FILESPEC</cmp> is paired against anything but a <cmp>FILESPEC</cmp>\
      that is a single <cmp>FILE</cmp>). It will likely produce\
      <itl>undesired</itl> results, an example of which is outlined as follows:
      When the merge output filename is not specified, $g(name) will present a\
      dialog to allow you to choose a name for that file when attempting to\
      write it. This is actually the simplest method of operation. If you\
      <itl>do</itl> choose to provide a name (via the command line\
      <itl>or</itl> the <btn>New Diff</btn> dialog window) $g(name) will\
      <bld>try</bld> to honor it. But there is a strong possibility you may\
      be asked to reconfirm that name <itl>OR</itl> be presented with an\
      entirely new name when you attempt to write to it. This generally occurs\
      when $g(name) detects that multiple file pairs are in use, which would\
      result in cross associating the single given merge output name to an\
      indeterminate file pairing. Thus $g(name) then reverts to "suggesting"\
      its own name. Of course, you may <itl>at that point</itl> then choose\
      whatever filename you wish.
      In a similar fashion, many of the "Additional Optional parameters"\
      shown are intended for use when $g(name) is invoked to process a\
      <itl>SINGLE</itl> file pair, as was its original historical heritage. 

As a further note regarding the $g(name) "<itl>suggested</itl>" merge file\
      output names, be advised that $g(name) will try to fabricate a name that\
      derives from the filename used in the Left window, unless that file\
      itself derives from an SCM system, in which case it will try to choose\
      its name from that of the Right window. When BOTH windows represent SCM\
      files, it will aim for the current directory that $g(name) was invoked\
      from, but the default name chosen will then be based from a fairly\
      cryptic tempfile name which almost certainly will need renaming.\
      Regardless of the <itl>default</itl> name presented, you may, of\
      course, place the output in any filename you designate.

The remaining options perform the following services:
      Both <cmp>-B</cmp> and <cmp>-I RegularExpression</cmp> are intended to\
      suppress differences from EMPTY or RE-matched lines respectively, and\
      you may specify the "<cmp>-I</cmp>" option more than once. Each operates\
      as described by the GNU Diff documentation, but are part of $g(name)\
      itself and NEITHER is passed to the Diff engine (thus making them usable\
      by <itl>any</itl> such engine).
      The mutually exclusive options <cmp>-1</cmp> and <cmp>-2</cmp> allow\
      one to suggest to $g(name) which side (Left or Right, respectively),\
      should be chosen <itl>during initial read-in</itl> as the contributing\
      side for any diff region for which $g(name) cannot discern a reason\
      (such as in a 3way ancestor-file situation) to choose one versus the\
      other. Oftentimes the intent of the merge (back porting, etc.) and\
      the order of files on the command line can dictate which file should\
      be treated as the contributing "source" for the eventual merge output.
      Debug output (<cmp>-d</cmp>) while not really meant for the average\
      user, is simply mentioned here for completeness sake.

<hdr>Network latency</hdr>
$g(name) does not, itself, require network access to run. However, certain\
      SCM systems are based on such technology and can thus introduce delays\
      in the processing performed by $g(name). In fact, a network\
      <itl>outage</itl> could even hang $g(name) while waiting for a response.
      To help combat that possibility,\
      <itl>particularly at tool startup</itl>, $g(name) <itl>may</itl> alert\
      you that such a delay appears to be occurring. A popup status panel, in\
      advance of the main $g(name) display, will present messages of\
      activities occurring. As long as new activities continue to occur\
      (perhaps every few seconds), no action is needed on your part.
      However, be advised that should the messages stall and you attempt to\
      <bld>dismiss</bld> this panel, you are, in fact, requesting that\
      $g(name) <itl>ABORT</itl> completely.
      This feedback mechanism simply provides you with interim updates until\
      sufficient information can be obtained to present the main display.
      Under normal conditions, no such messages are needed nor produced, and\
      $g(name) <itl>will remove</itl> the status display itself when the main\
      display is ready. <itl>Unfortunately</itl>, due to inadequacies in the\
      MacOS X graphics support (Aqua), this messaging feature is unavailable\
      on that platform.

<hdr>The Diff engine (and more quoting)</hdr>
Although $g(name) was designed as a frontend to the classic, UNIX derived,\
      "diff" command, there is no specific reason some other utility meeting\
      its input/output and invocation requirements cannot be used. Because of\
      this, $g(name) can be configured to interoperate with other differencing\
      engines, some having perhaps more advanced (or desireable) detection\
      methods.
      Accordingly, any option flag having a leading dash that is <itl>not</itl>\
      recognized as a $g(name) option is passed <itl>almost untouched</itl>\
      to your Diff engine of choice. This permits you to temporarily alter the\
      way Diff is called, without resorting to a change in your preferences\
      file. However it also means that to use, for example, the "-d" option for\
      GNU diff (which <itl>is</itl> a $g(name) option), you would need to pass\
      it using its equivalent long-form equivalent of "--minimal" (to avoid the\
      mis-interpretation).
      But as a related issue, trying to pass <itl>any</itl> option that\
      requires a <bld>value</bld> <itl>MAY</itl> necessitate an unusual form\
      of quoting to preserve syntactically required "white space" characters.\
      As noted earlier, if the value portion has NO blanks and is permitted to\
      be physically attached to its option flag, no special action is required.
      But if the value itself requires a "space" -or- must be SEPARATED from\
      its option flag by one (to satisfy the parsing rules of the Diff engine),\
      then you should pass the <itl>entire construct</itl> within double quote\
      characters, and perhaps even <itl>doubly</itl> so. As an example,\
      GNU diff has an option whose syntax is:
      <bld>-I, --ignore-matching-lines=RE</bld>
Admittedly, this option <itl>is</itl> a $g(name) recognized option (at least\
      via the "-I" flag) and thus would not be passed on to the engine, but it\
      can illustrate the issues involved. Thus if something similar\
      <itl>WERE</itl> to be passed to tell Diff (in this example) to not\
      consider any line that starts with a octathorp (#) followed by a space,\
      you might specify this to $g(name) as <itl>either</itl> :
      "--ignore-matching-lines=^#  "   (or even "-I^#  ")
or
      <bld>"</bld>-I  <bld>\"</bld>^#  <bld>\" "</bld>    (or "-I  {^#  }")
Note in each case, the quoting of BOTH the flag and its value\
      <itl>together</itl>. But particularly, in the second form, note the extra\
      quoting (done with escaped double quotes or "brace" characters as shown)\
      surrounding the value as well; be aware that <itl>single quotes will NOT\
      work</itl> here. A "brace" character is simply the lexical mechanism used\
      by the internals of $g(name) to quote its contained content. Without this\
      'extra' quoting as shown, $g(name) <itl>would pass</itl> the option, but\
      the resulting Diff would <itl>MISS</itl> the trailing blank of the RE.
      The reason is primarily that $g(name) <itl>has no understanding</itl> of\
      any flags being passed to the engine, nor if they might legitimately\
      require a value, or need said value to be separated from its flag while\
      still <itl>preserving</itl> any embedded blanks.
      IMPORTANT NOTE - from a $g(name) perspective, this particular GNU Diff\
      option should <bld>never</bld> be passed to <bld>ANY</bld> diff engine\
      ... it was designed to make the <itl>direct output of Diff itself</itl>\
      more meaningful to a <itl>human</itl> by simply suppressing what is,\
      in reality, actual differences. $g(name) <itl>will fail badly</itl> if\
      you were to sneak the option to Diff (using its long-form flag name).\
      You have been warned.
    }

    if {$mode == "cline"} {
        puts $usage
    } else {
        set text [subst -nobackslashes -nocommands $text]
        append usage $text
        do-text-info .usage "$g(name) Usage" $usage
    }
}

###############################################################################
# Throw up a help window for the GUI.
###############################################################################
proc do-help {} {
    global g pref

    customize-initLabels ;# Needed for access to global 'pref' array

    set title "How to use the $g(name) GUI"
    set text {
<hdr>Layout</hdr>

The top row contains the <btn>File</btn>, <btn>Edit</btn>, <btn>View</btn>,\
      <btn>Mark</btn>, <btn>Merge</btn> and <btn>Help</btn> menus. The second\
      row contains a toolbar which contains navigation and merge selection\
      tools. Below that are labels which identify the contents for each of the\
      two text windows that follow just below them. Note that these labels\
      will <itl>also</itl> produce a tooltip popup showing the ACTUAL filename\
      and its modification time when hoverring over it with the mouse,\
      <itl>provided</itl> it is not a tempfile (such as extracted from an SCM).
      In addition, if an ANCESTORFILE was specified at startup, a third label\
      (a graphic denoting a text file labelled  "A") will appear between the\
      other two labels. It also will display a tooltip indicating its name,\
      and <itl>possibly</itl> its modification time, the latter based on the\
      file <itl>not</itl> having been extracted from an SCM. But in reality\
      it is actually a <bld>button</bld> that when pressed, will popup a\
      <itl>display only</itl> presentation of that Ancestor file, for those\
      who simply <itl>have</itl> to see it.

The left-most text widget displays the contents of <cmp>FILE1</cmp>, the most\
      recently checked-in revision, <cmp>REV</cmp> or <cmp>REV1</cmp>,\
      respectively (as per the startup options described in\
      the "On Command Line" help). The right-most widget displays the\
      contents of <cmp>FILE2</cmp>, <cmp>FILE</cmp> or <cmp>REV2</cmp>,\
      respectively. Clicking the right mouse button over either of\
      these windows will give you a context sensitive menu with actions that\
      will act on the window you clicked over. For example, if you click\
      right over the right hand window and select\
      "Edit", the file displayed on the right hand side will be loaded into a\
      text editor.

At the bottom of the display is a two line window called the\
      "Line Comparison" window. This will show the "current line" from the\
      left and right windows, one on top of the other. The "current line"\
      is defined by the line that has the blinking insertion cursor, which\
      can be set by merely clicking on any line in the display. This window\
      may be hidden if the <btn>View</btn> menu item "Show Line Comparison\
      Window" is deselected.

All difference regions (DRs) are <itl>usually</itl> highlighted to set them\
      apart from the surrounding text, unless the "$pref(tagtext)" preference\
      has been deselected. The <itl>current difference region</itl>, or\
      <bld>CDR</bld>, is further set apart so that it can be\
      correlated to its partner in the other text widget (that is, the CDR on\
      the left matches the CDR on the right). And when "$pref(syncscroll)" is\
      also set, that Left and Right CDR will be horizontally aligned as well.

<hdr>Changing the CDR</hdr>

The CDR can be selected in a sequential manner by means of the <btn>Next</btn>\
      and <btn>Previous</btn> buttons. The <btn>First</btn> and\
      <btn>Last</btn> buttons allow you to quickly navigate to the\
      first or last CDR, respectively. For random access to the DRs, use the\
      dropdown listbox in the toolbar or the diff map, described below.

By clicking right over a window and using the popup menu you can select\
      <btn>Find Nearest Diff</btn> to find the diff record nearest the point\
      where you clicked, or simply double-click <itl>NOT</itl> over an\
      existing DR, as a shortcut to the same result.

You may also select any highlighted diff region as the current diff region by\
      just double-clicking <bld>on</bld> it.

<hdr>Operations</hdr>

1. From the <btn>File</btn> menu:

The <btn>New...</btn> item displays a dialog where you may choose two files\
      to compare. Selecting "Ok" from that dialog will diff the two files. Be\
      advised that this is the same dialog as may appear when $g(name) is\
      started with no command line parameters given, and its described\
      behavior there is the same as invoking it from this context (see the\
      help topic "On Command Line" for specific details). Next, the\
      <btn>File List</btn> item will only be active when the current $g(name)\
      command parameters yeilds more than a single pairing of files to compare;\
      pressing it produces a submenu list of the other available comparisons.\
      Choosing one re-initializes the display to the file pair thus selected.\
      Note that <itl>after</itl> choosing an item, the background of that item\
      will henceforth be red or green when the mouse hovers over that item,\
      based on whether that pairing was successfully read into $g(name). When\
      no color is shown, that item has NOT yet been accessed.\
      <btn>File List</btn> items <itl>may</itl> require noticeable time to load\
      if the files each represents requires network access to be processed;\
      however, once loaded, subsequent reloading is entirely a local task. The\
      <btn>Recompute Diffs</btn> item recomputes the differences between the\
      two files whose names appear above each of the two text display windows.\
      The <btn>Write Report...</btn> item lets you create a report\
      file that contains various information visible in the windows. Lastly,\
      the <btn>Exit</btn> item terminates $g(name).

2. From the <btn>Edit</btn> menu:

<btn>Copy</btn> copies the currently selected text to the system clipboard.\
      <btn>Find</btn> pops up a dialog to let you search either text window\
      for a specified text string. <btn>Split...</btn> and\
      <btn>Combine...</btn> pops up a dialog that allows you to rearrange\
      the CONTENT of the CDR to isolate specific lines, facilitating\
      specific merge file generation goals. <btn>Edit File 1</btn> and\
      <btn>Edit File 2</btn> launch an editor on the files displayed in the\
      left- and right-hand panes.  <btn>Preferences</btn> pops up a dialog\
      box from which display (and other) options can be changed and saved.

3. From the <btn>View</btn> menu:

This menu is organized into a few sections, the first of which deals with\
      how the output from the diff engine can be tuned or interpretted.\
      <btn>Ignore White Spaces</btn> toggles whether certain user preference\
      defined options should (or not) be used when invoking Diff. Both of\
      <btn>Ignore Blank Lines</btn> and <btn>Ignore RE-matched Lines</btn>\
      in turn, toggle an ability to suppress (basically NOT notice or\
      highlight) any difference region identified by the engine that is\
      <itl>exclusively</itl> comprised of the indicated category. Lines that\
      otherwise seem to match, but have been "grouped" by Diff into a larger\
      difference region are <bld>NEVER</bld> suppressed.
      IMPORTANT: toggling <itl>any</itl> of these settings will cause $g(name)\
      to <itl>immediately</itl> (upon "Apply"ing the dialog settings) re-invoke\
      the diff engine so as to provide the requested interpretation. This\
      <bld>will cause the loss</bld> of any merge work that may have been in\
      progress at that time.
      In the second section are items controlling what information gets\
      displayed within the tool itself. Both <btn>$pref(showln)</btn> and\
      <btn>$pref(showcbs)</btn> toggle the display of line numbers and\
      markers (respectively) in the text widgets. <btn>Show Diff Map</btn>\
      toggles the display of the diff map (see below) on or off.\
      The "Show Line Comparison Window" item toggles the display of a literal\
      two line over/under "line comparison" window at the bottom of the\
      display. As an alternative to that, the two mutually exclusive items\
      <btn>Show Inline Comparison (byte)</btn> or\
      <btn>Show Inline Comparison (recursive)</btn> will display the specific\
      interline differences as configurable highlighting directly\
      <itl>within</itl> the Left and Right text displays themselves. You may\
      choose any combination, at any time, as suits your comprehension needs.
      The third section addresses automatic processing that can be performed\
      as other iteractions in $g(name) take place.\
      If <btn>Synchronize Scrollbars</btn> is on, the Left and Right\
      text windows are synchronized i.e. scrolling one of the windows scrolls\
      the other. If <btn>Auto Center</btn> is on, jumping (by whatever means)\
      to a new CDR centers that new CDR automatically. <btn>Auto Select</btn>\
      will attempt to designate the diff region currently closest to the\
      middle of a scrolled Left/Right text window <itl>AS</itl> the new CDR;\
      however, but only when <btn>$pref(syncscroll)</btn> is also ON.
      The fourth (and final) section basically reiterates simple navigation\
      actions available elsewhere (toolbar, popup menu) for moving among the\
      various diff regions.

4. From the <btn>Mark</btn> menu:

The <btn>Mark Current Diff</btn> creates a new toolbar button that will jump\
      to the current diff region. The <btn>Clear Current Diff Mark</btn> will\
      remove the toolbar mark button associated with\
      the current diff region, if one exists.

5. From the <btn>Merge</btn> menu:

The <btn>Show Merge Window</btn> item pops up a window with the current\
      merged version of the two files. This will be described further in a\
      section called "Merge Preview" below. The <btn>Write Merge File</btn>\
      item (or possibly the <btn>Write Merge File...</btn>) will allow you to\
      save the contents of that window to a file.
      Pay special attention to the existance of those three trailing dots when\
      electing to write the Merge File (either here <itl>OR</itl> from the\
      buttons on the popup window) - if they are <bld>NOT</bld> present,\
      it means $g(name) <itl>already knows</itl> what filename to produce,\
      (i.e. from the command line) and you will not be given a chance to\
      confirm or alter that name.

6. From the <btn>Help</btn> menu:

The <btn>About $g(name)</btn> item displays copyright and author\
      information. The <btn>On GUI</btn> item generates this window. The\
      <btn>On Command Line</btn> item displays help on the\
      $g(name) command line options. The <btn>On Preferences</btn> item\
      displays help on the user-settable preferences.

7. From the toolbar:

(Be advised that in these explanations, many button descriptions refer to the\
      <itl>textual</itl> name <bld>ON</bld> that button as would be seen when\
      the user preference to "$pref(toolbarIcons)" is unset.)

The first tool is a dropdown list of all of the differences in a standard\
      diff-type format. You may use this list to go directly to any diff\
      record. Further navigation tools will be described in due turn.  The\
      next tool, <btn>Rediff</btn>, simply re-computes the diff of the\
      CURRENT two files from scratch as if it was a New Diff. This could be\
      appropriate if you have invoked an editor on either file since starting\
      and now wish to see the net effects of your editting. The following two\
      tools, <btn>Split</btn> and <btn>Combine</btn>, each provide\
      complimentary abilities to adjust the boundaries of the CDR. The\
      reasons for doing this are further explained in the section below on\
      Merging.
The remaining tools on the toolbar consist of the <btn>Find</btn> tool for\
      searching the text for a given word or phrase. This is then followed\
      (in order) by groupings of tools dealing with merge choice selections,\
      navigation, and lastly a bookmarking, or Diff Marks, facility for\
      remembering specific diff positions so that jumping among them does\
      not require memorization. These, among other topics, will now be\
      further described.

<hdr>Navigation tools</hdr>

      The <btn>Next</btn> and <btn>Previous</btn> buttons take you to the\
      "next" and "previous" DR, respectively. The <btn>First</btn> and\
      <btn>Last</btn> buttons take you to the "first" and "last" DR. These\
      actions will <itl>also</itl> affect the Merge Window (when displayed).\
      The <btn>Center</btn> button centers the CDRs in their respective text\
      windows. You can also set <btn>Auto Center</btn> in\
      <btn>Preferences</btn> (or via the <btn>View</btn> menu) to do this\
      automatically for you as you navigate through the diff records.


<hdr>Keyboard Navigation</hdr>

When a text widget has the focus, you may use the following shortcut keys:
<cmp>
	c      Center current diff
	f      First diff
	j      Load NEXT file pair (from File->File List)
	k      Load PREV file pair (from File->File List)
	l      Last diff
	n      Next diff
	p      Previous diff
	1      Elect Left as the CDR Merge Choice
	2      Elect Right as the CDR Merge Choice
	3      Elect Left-then-Right as the CDR Merge Choice
	4      Elect Right-then-Left as the CDR Merge Choice
</cmp>
The cursor keys, Home, End, PageUp and PageDown work as expected, adjusting\
      the view in whichever text window has the focus. Note that if\
      <btn>$pref(syncscroll)</btn> is set in <btn>Preferences</btn>, both\
      windows will scroll at the same time.

<hdr>Scrolling</hdr>

To scroll the text widgets independently, make sure\
      <btn>$pref(syncscroll)</btn> in <btn>Preferences</btn> is off. If it is\
      on, scrolling either text widget scrolls the other. Scrolling does not\
      change the current diff record (CDR), nor will it cause the Merge\
      Window (if displayed) to scroll. A Mouse scroll-wheel is also\
      recognized for scrolling vertically, or, if the <cmp>Shift</cmp> key\
      is simultaneously pressed, horizontally, as well.

<hdr>Diff Marks</hdr>

You can set "markers" at specific diff regions for easier navigation. To do\
      this, click on the <btn>Set</btn> Mark button when the desired DR is\
      currently the CDR. It will create a new toolbar button that will jump\
      back to this specific diff region. To clear a diff mark, first go to\
      that diff record, then click on the <btn>Clear</btn> Mark button.

<hdr>Diff Map</hdr>

The diff map is a map of all the diff regions. It is shown in the middle of\
      the main window if <btn>Show Diff Map</btn> on the <btn>View</btn> menu\
      is on. The map is a miniature of the file's diff regions from top to\
      bottom. Each diff region is rendered as a patch of color; initially\
      Delete as red, Insert as green and Change as blue and in the case of a\
      3-way merge, overlap regions are marked in yellow. These colors are the\
      defaults provided by $g(name), but can be adjusted via the\
      <btn>Preferences...</btn> item in the <btn>Edit</btn> menu, to perhaps\
      compensate for better contrast or spectrum adjustments given other\
      objects onscreen with your particular monitor (or simply personal taste).
      The height of each patch corresponds to the relative size of the diff\
      region. A thumb lets you interact with the map as if it were a scrollbar,\
      and Mouse scroll-wheel actions are fully supported, but will be\
      <itl>directed</itl> to whichever of the two text windows is holding\
      the current input focus, if the windows are not synchronized.\
      All diff regions are drawn on the map even if too thin to ordinarily be\
      visible. For large files with small nearby diff regions, this may result\
      in patches overwriting each other.

<hdr>Merge Preview</hdr>

To see an ongoing preview of the file that would be written by\
      <btn>Write Merge File</btn>, select <btn>Show Merge Window</btn> in the\
      <btn>Merge</btn> menu. A separate window will be shown containing the\
      preview. It is updated as you select merge choices, and provides markers\
      that remind you as to which side (Left/Right) is contributing its diff\
      region into the result. Note that when viewing a choice such as the\
      Left-side of an "add"-type CDR, there is <itl>nothing</itl> to actually\
      display. Additionally, the Preview window is responsive to the current\
      <btn>$pref(showln)</btn> preference setting. It is also synchronized\
      with the other text widgets when <btn>Synchronize Scrollbars</btn> is\
      on, at least as far as actions that <itl>change</itl> the CDR, however\
      it <bld>does not</bld> actually <itl>scroll</itl> in unison with the\
      other windows, primarily because as a representation of the eventual\
      Merge file, it does NOT HAVE any <itl>padding</itl> lines which accounts\
      for a substantial amount of the vertical spacing being scrolled by the\
      other windows.

<hdr>Merging</hdr>

To merge the two files, go through the difference regions (via <btn>Next</btn>,\
      <btn>Prev</btn> or whatever other means you prefer) and select\
      <btn>L</btn> (for "Left") or <btn>R</btn> (for "Right"), located\
      adjacent to the toolbar "Merge Choice:" label, assigning which side\
      should be used for each. Alternately, the "<bld>1</bld>" & "<bld>2</bld>"\
      keys will do the same, respectively. The initial selections (after\
      invoking Diff) will have already been established by a user preference\
      and/or whether a 3way (involving an ancestor file) was performed\
      (explained further in the section "<bld>3way merging</bld>" below).
      Selecting <btn>L</btn> means that the the left-most file's version of\
      the difference will be used in creating the final result; choosing\
      <btn>R</btn> means that the right-most file's difference is used. Each\
      choice is recorded, and can be changed arbitrarily many times.\
      If you need pieces from BOTH the Left AND Right versions you may choose\
      the <btn>LR</btn> or <btn>RL</btn> (Left-then-Right or\
      Right-then-Left, respectively) choices instead, <itl>but then</itl> you\
      must remember to edit the merged result <bld>AFTER</bld> you commit it to\
      disk. This might be useful, for example, if <itl>both</itl> variations\
      should exist with additional wording, or in the case of source coding, a\
      conditional inclusion macro, surrounding the entire result. To commit\
      the final, merged result to disk, choose <btn>Write Merge File</btn>\
      from the <btn>Merge</btn> menu, or one of the <btn>Save</btn> buttons\
      provided on the "Merge Window" (if it is displayed). Remember that each\
      of these items may be labelled with a trailing "..." if $g(name) is\
      <itl>uncertain</itl> of what the target filename should be, thereby\
      providing a file browser dialog to either specify and/or confirm the name.

<hdr>Merging - in more detail</hdr>

Oftentimes, you may find that the "Diff" program has packed several lines\
      worth of differences into a large chunk, simply because it never found a\
      <itl>common</itl> line that BOTH files could agree was the SAME in both\
      files. Yet only a <itl>SINGLE</itl> defined difference record (a CDR)\
      can have its Left or Right side chosen for merging at any one time.\
      This is the "problem" that <btn>Split</btn> or <btn>Combine</btn> are\
      intended to address. Using these tools, you will be permitted to\
      repartition the exact lines that should be treated as a distinct\
      difference record. In each case, you start from some specific CDR,\
      and then either break it apart into smaller pieces ("Split") or\
      reassemble it ("Combine") at boundaries of your choice.
      A dialog window is provided to oversee the movement of the CDR boundary\
      edges, with feedback provided in the Text windows. You need only to\
      click on arrows to adjust either or both edges in the Left or Right\
      text window displays until satisfied that the <itl>NEW</itl> CDR\
      describes the change content you wish to convey. Be aware these arrow\
      buttons will <itl>automatically</itl> advance if you press and hold\
      instead of of clicking, making it easier to adjust a large expanse.
      Once accepted, $g(name) will treat the new difference record exactly\
      the same as any other, despite the fact that it appears run together\
      with other adjoining records, having NO common line to separate them.\
      The power of this is that two modifications, having NOTHING to do\
      with each other beyond proximity, can thus be merged (or not)\
      <itl>INDIVIDUALLY</itl> as needed. Given that many version control\
      systems prefer that only those lines pertinent to a specific logical\
      change reside in a given 'patch', these features allows the user to\
      surgically distinguish one <itl>logical</itl> change from another.
      Note that ONLY a previously Split record, can ever be Combined, and\
      that $g(name) will always assign each line of the original CDR into an\
      appropriate record (creating and/or removing existing records as\
      necessary), automatically assigning its type (add/change/delete).
      If you have difficulty envisioning which edges to move to accomplish\
      a specific goal, think of the edges as defining 3 individual regions\
      per side of data: Above-the-CDR, the NEW CDR, and Below-the CDR. Then\
      remember that changes always flow from the left side to the right. Thus\
      when a Left side region has a zero size, the corresponding Right side\
      region is being "added". Conversely, if a right-side region describes\
      zero lines, the left-side region describes a "delete". Regions that BOTH\
      have lines are "changes".
      Note that only REAL lines (those having Line numbers, when shown) are\
      ever counted toward the occupancy of the regions. Padding lines\
      (displayed to align CDRs on screen) mean nothing despite their being\
      highlighted as part of a CDR, and will be <itl>stepped over</itl> as\
      edges are moved. Finally, remember that any changes <itl>YOU</itl> might\
      make to any CDR content is transitory, and only exists within $g(name)\
      until the next time any "Diff" is invoked, even a <btn>Rediff</btn>. This\
      suggests that before beginning any merge work, you shoud ensure that all\
      settings or menu choices that adjust or interpret the Diff results\
      (predominate side, ignored blanks/lines), or worse, those that might\
      <itl>trigger</itl> a new Diff invocation, have all been configured\
      appropriately. ALL interactive merge work (including Split/Combine) is\
      transitory until the merge file is actually written out, and\
      <itl>can not</itl> be automatically recovered.

<hdr>3way Merging</hdr>

A 3way merge, as the name suggests, involves a third file that is expected\
      to have been an earlier <itl>common</itl> version to <itl>both</itl>\
      files presently being compared. Providing this <bld>ancestor</bld> file\
      will cause an icon to appear <itl>between</itl> the normal Left/Right\
      file labels on the display (indicating the mode is in force and\
      permitting viewing access if absolutely necessary) and thereby\
      allow $g(name) to look backward in time, to address the unique issue of\
      intentionally diverged <itl>independent</itl> modifications (the Left\
      and Right files) being merged back together into a single output file. 
      Specifically, $g(name) wants to identify the modifications that\
      <itl>created</itl> the Left and Right variants, with the intention of\
      preserving <bld>ALL</bld> such changes (both sides) into the final\
      result, as automatically as possible. Thus, among the Left/Right diffs\
      being shown by $g(name), certain lines may, or may not, have been\
      modified during their creation from the ancestor. We call these\
      <bld>ancestral</bld> artifacts, and $g(name) will annotate such lines\
      using markers to the left of the line numbers (if displayed), denoting\
      what kind of modification (add, chg) had previously occurred. Note that\
      <itl>ancestral deletions</itl> no longer <itl>exist</itl> in their\
      respective Left/Right files, and thus were effectively and implicitly\
      embedded into those files at that time.
      Generally, when ancestral markers show up in ONLY the Left (or Right)\
      windows, $g(name) simply responds by choosing that side as the initial\
      merge choice for that region. When <itl>BOTH</itl> sides show markers\
      $g(name) selects the "Right" side, but also declares the region as a\
      <bld>collision</bld> which requires user assistance to solve,\
      highlighting it appropriately to draw it to your attention. As a further\
      reminder, it will also highlight within the dropdown list of diff\
      regions on the toolbar, which can thus be used to quickly locate these\
      problematic areas.
      Despite all automatic attempts to choose the proper merge choice,\
      $g(name) does not and can not, itself, <itl>resolve</itl> arbitrary\
      collisions. However, as it turns out, the <btn>Split</btn> tool, by\
      repartitioning the region into distinct smaller regions, can often be\
      used to <bld>resolve</bld> what we call <itl>simple</itl> collisions by\
      ensuring only one side of each split portion carries markers from\
      a single side (if possible). At such time, $g(name) will re-assign the\
      affected merge choices appropriately, possibly eliminating the entire\
      collision altogether.
      Because of this ability to remove the collisions through direct user\
      interaction using <btn>Split</btn>, $g(name) will <itl>also presume</itl>\
      that independently choosing any <bld>manually selected</bld> merge choice\
      <itl>yourself</itl>, when dealing with a collision region is trying to\
      accomplish the same goal, and <bld>will remove</bld> the primary\
      indications of the collision, <itl>provided</itl> you agree via a popup\
      question. Yet note however, that the responsibility in that case, is\
      yours; $g(name) has no additional means to actually determine if the\
      collision was truely resolved. Note that "resolved" regions are only\
      ever <itl>de-highlighted</itl> from the Left and Right windows; the\
      toolbar diff region dropdown list ALWAYS retains which regions were\
      formerly collisions <itl>unless</itl> the region was resolved via\
      the <btn>Split</btn> tool.
      Finally, remember that like all "adjustments" done after having run a\
      Diff, all of it is <itl>entirely</itl> transitory until the Merge output\
      file is generated, or another Diff is invoked.

<hdr>Original Author</hdr>
John M. Klassa

<hdr>Comments</hdr>
Questions and comments should be sent to the TkDiff mailing list at
      tkdiff-discuss@lists.sourceforge.net.
Or directly into the Discussion forum at
      https://sourceforge.net/p/tkdiff/discussion
    }

    set text [subst -nobackslashes -nocommands $text]
    do-text-info .help $title $text
}

######################################################################
# display help on the preferences
######################################################################
proc do-help-preferences {} {
    global g pref

    customize-initLabels

    set title "$g(name) Preferences"

# OPA >>> Added help about showcontextsave
    set text {
<hdr>Overview</hdr>

Preferences are stored in a file in your home directory (identified by the\
      environment variable <cmp>HOME</cmp>.) If the environment variable\
      <cmp>HOME</cmp> is not set the platform-specific variant\
      of "/" will be used. If you are on a Windows platform the file will be\
      named <cmp>_tkdiff.rc</cmp> and will have the attribute "hidden". For\
      all other platforms the file will be named\
      "<cmp>.tkdiffrc</cmp>". You may override the name and location of this\
      file by setting the environment variable <cmp>TKDIFFRC</cmp> to\
      whatever filename you wish.

Preferences are organized onscreen into three categories: General, Display and\
      Appearance. Conversely in the resulting file, they are in alphabetical\
      order of the preference identifier, but both have the same descriptive\
      labels (on screen, or as a comment in the file). For discussion here,\
      they will be presented in their onscreen order.

<hdr>General</hdr>

<bld>$pref(diffcmd)</bld>

This is the command that will be run to generate a diff of the two files.\
      Typically this will be "diff"; yet other differencing engines, providing\
      other algorithms are possible. When this command is run, the names\
      of the two files to be diffed will be added as the last two arguments\
      on the command line.
If the \"<itl>$pref(ignoreblanksopt)</itl>\" (described below) is specified\
      <itl>and</itl> enabled, it too will be included in the resulting command.

<bld>$pref(ignoreblanksopt)</bld>

Arguments to send with the diff command to tell it how to ignore whitespace.\
      If you are using GNU diff, "-b" or "--ignore-space-change" ignores\
      changes in the amount of whitespace, while "-w" or\
      "--ignore-all-space" ignores all white space. Because of an unfortunate\
      interaction with yet another option ("-B" which $g(name) itself handles)\
      we currently require the use of the <itl>short</itl> names here.
If this field is shown <itl>disabled</itl>, it can be accessed by toggling\
      the \"<itl>$pref(ignoreblanks)</itl>\" option described below.
Note that when this field is <itl>disabled</itl>, its value will be ignored.

<bld>$pref(tmpdir)</bld>

The name of a directory for files that are temporarily created while $g(name)\
      is running.

<bld>$pref(editor)</bld>

The name of an external editor program to use when editing a file (ie: when\
      you select "Edit" from the popup menu). If this value is empty, a\
      simple editor built in to $g(name) will be used, and will be positioned\
      such that the current diff is visible. Windows users might want to set\
      this to "notepad". Unix users may want to set this to "xterm -e vi" or\
      perhaps "gnuclient". When run, the name of the file to edit will be\
      appened as the last argument on the command line.
If the supplied string contains the string "\$file", it\'s treated as a whole\
      external command line, where the following parameters can be used:
      \$file: the file of the window you invoked upon
      \$line: the starting line of the current diff
For example, in the case of NEdit or Emacs you can use "nc -line \$line\
      \$file" and "emacs +\$line \$file" respectively.

<bld>$pref(ignoreRegexLnopt)</bld>

An editable dropdown list of Regular Expressions that is used to identify text\
      lines that should be ignored/suppressed (when possible, and activated)\
      thus eliminating them from being displayed/highlighted <itl>AS</itl>\
      real Diff regions; but you must be <bld>very cautious</bld> when forming\
      such Regular Expressions, that it does NOT identify a line that might\
      have <itl>OTHER legitimate</itl> differences on it.
      Initially, the item will display nothing except its dropdown arrow.\
      To view the existing list, simply click the dropdown arrow, and scroll\
      thru the resulting list. Clicking on an <bld>entry</bld> of that list,\
      is a request to <bld>delete</bld> it, but you will be asked for\
      confirmation first, which you may decline.
      However, declining conveniently PLACES that entry into the originally\
      empty dropdown entry box, where you may then <bld>edit</bld> it by\
      <itl>first</itl> clicking on it (to remove the selection highlight) and\
      then using the keyboard to traverse about the entry (arrows, backspace,\
      retyping) until satisfied, whereupon pressing [Return] will\
      <bld>add</bld> the new value. Note that shifting the current focus\
      <itl>away</itl> via a mouse click elsewhere, or pressing [Tab], also\
      counts as a [Return].
      If instead you simply start typing first, either AFTER a declined\
      deletion, or from the initial empty display state, you will simply\
      <bld>add</bld> whatever is typed.
      Nevertheless, confirmation of each "add" or "delete" will be flashed\
      momentarily whenever the list is actually modifed (and the entry will\
      then be returned to its empty state).
      If the entire item is shown <itl>disabled</itl>, it can be accessed by\
      toggling the \"<itl>$pref(ignoreRegexLn)</itl>\" option described below.

<bld>$pref(filetypes)</bld>

Another editable dropdown list of file suffixes you may wish to see in the\
      various file open and save dialogs throughout the tool. Editting\
      procedures are as described immediately above, except that the format\
      is that of two "words" separated by white space. The first word is used\
      as a label, and if it contains spacing, should be enclosed in\
      <bld>braces</bld>. The second is a file-glob pattern for the applicable\
      file extensions you wish to see. Thus entries like "{All Files} *" or\
      "{Text Files} .txt" or even "{C Files} .[cChH]" should all be self\
      explanatory. For sanitys sake, please keep the labels short!

<bld>$pref(geometry)</bld>

This defines the default size, in characters of the two text windows. The\
      format should be <cmp>WIDTHxHEIGHT</cmp>. For example, "80x40".

<bld>$pref(ignoreblanks)</bld>

If <bld>set</bld>, then the above \"<itl>$pref(ignoreblanksopt)</itl>\" will\
      be included whenever a diff is executed. It also permits that option\
      to be editted.
If <bld>unset</bld>, that same option will <itl>not</itl> participate in any\
      diff and is also disabled from being modified.
You may toggle this setting simply to gain editting access to the\
      \"<itl>$pref(ignoreblanksopt)</itl>\", but if you press <bld>Apply</bld>\
      BEFORE toggling BACK to the original value (either <bld>set</bld>\
      <itl>or</itl> <bld>unset</bld>), it will trigger an immediate\
      \"<btn>Recompute Diff</btn>\" which <bld>WILL DISCARD</bld> any\
      mergefile activity not yet completed.

<bld>$pref(toolbarIcons)</bld>

If <bld>set</bld>, the toolbar buttons will use icons instead of text labels.
If <bld>unset</bld>, the toolbar buttons will use text labels instead of icons.

<bld>$pref(ignoreEmptyLn)</bld>

If <bld>set</bld>, then $g(name) will not count, nor highlight, any region\
      that is exclusively comprised of empty (or possibly white space filled\
      lines if the above \"<itl>$pref(ignoreblanksopt)</itl>\" is active)\
      whenever a diff is executed. This essentially mimics a feature of the\
      original Diff program, but is performed entirely within $g(name).
If <bld>unset</bld>, no special significance is attached to blank/empty lines\
      and Diff will report changes as it sees fit.
Note if you press <bld>Apply</bld> AFTER changing this setting (either to\
      <bld>set</bld> <itl>or</itl> <bld>unset</bld>), it will trigger an\
      immediate \"<btn>Recompute Diff</btn>\" which <bld>WILL DISCARD</bld>\
      any mergefile activity not yet completed.

<bld>$pref(autocenter)</bld>

If <bld>set</bld>, whenever a new diff record becomes the current diff record (for\
      example, when pressing the next or previous buttons), the diff record\
      will be automatically centered on the screen.
If <bld>unset</bld>, no automatic centering will occur.

<bld>$pref(ignoreRegexLn)</bld>

If <bld>set</bld>, then the above \"<itl>$pref(ignoreRegexLnopt)</itl>\" will\
      participate whenever a diff is executed. It also permits that option\
      to be editted.
If <bld>unset</bld>, that same option will <itl>not</itl> participate\
      in any invoked diff and is also disabled from being modified.
You may toggle this setting simply to gain editting access to the\
      \"<itl>$pref(ignoreRegexLnopt)</itl>\", but if you press <bld>Apply</bld>\
      BEFORE toggling BACK to the original value (be it <bld>set</bld>\
      <itl>or</itl> <bld>unset</bld>), it will trigger an immediate\
      \"<btn>Recompute Diff</btn>\" which <bld>WILL DISCARD</bld> any\
      mergefile activity not yet completed.
Conversely, if you <bld>set</bld> this, but the list of REs is empty at the\
      time of the "Apply", this setting will simply revert to <bld>unset</bld>.

<bld>$pref(autoselect)</bld>

If <bld>set</bld>, automatically select the nearest visible diff region when\
      scrolling.
If <bld>unset</bld>, the current diff region will not change during scrolling.
This only takes effect if "<itl>$pref(syncscroll)</itl>" is <bld>set</bld>.

<bld>$pref(syncscroll)</bld>

If <bld>set</bld>, scrolling either text window will result in both windows\
      scrolling.
If <bld>unset</bld>, the windows will scroll independent of each other.
Note that it has only a <itl>limited effect</itl> on the Merge Preview window\
      contents, in that changes of the CDR will "jump" scroll, but direct\
      interactive scrolling will not (explained in the "<bld>On GUI</bld>" help.

<bld>$pref(fancyButtons)</bld>

If <bld>set</bld>, toolbar buttons will mimic the visual behavior of typical\
      Microsoft Windows applications. Buttons will initially be flat until the\
      cursor moves over them, at which time they will be raised.
If <bld>unset</bld>, toolbar buttons will always appear raised.
This feature is not supported in MacOSX.

<bld>$pref(predomMrg)</bld>

This setting decides, for those cases where no specific reason (such as an\
      implied choice from a 3way ancestor diff) exists, which of the two sides\
      <bld>Left</bld> or <bld>Right</bld>, should be <itl>initialized</itl>\
      as contributing its portion of the changed lines to the eventual merge\
      result.
      Determining how best to toggle this setting involves not only the order\
      of files as provided initially, but also on the specific goals\
      envisioned by the user for the merge as a whole. For example, if\
      back-porting some specifc capability, it might be best to select the\
      side of the older file, and then only interactively merge the needed\
      individual regions from the newer one.
      This option only comes into play when a Diff is invoked, as every region\
      must ultimately posess <itl>SOME</itl> setting prior to being displayed.

<hdr>Display</hdr>

<bld>$pref(showln)</bld>

If <bld>set</bld>, line numbers will be displayed alongside each line of each file.
If <bld>unset</bld>, no line numbers will appear.

<bld>$pref(tagln)</bld>

If <bld>set</bld>, line numbers are highlighted with the options defined in the\
       Appearance section of the preferences.
If <bld>unset</bld>, line numbers won\'t be highlighted.

<bld>$pref(showcbs)</bld>

If <bld>set</bld>, change bars will be displayed alongside each line of each file.
If <bld>unset</bld>, no change bars will appear.

<bld>$pref(tagcbs)</bld>

If <bld>set</bld>, change indicators will be highlighted. If <itl>$pref(colorcbs)</itl>\
      is set they will appear as solid colored bars that match the colors\
      used in the diff map. If <itl>$pref(colorcbs)</itl>\
      is <bld>unset</bld>, the change indicators will be highlighted according to the\
      options defined in the Appearance section of the preferences.

<bld>$pref(showmap)</bld>

If <bld>set</bld>, a colorized, graphical "diff map" will be displayed between the two\
      files, showing regions that have changed. Red is used to show deleted\
      lines, green for added lines, blue for changed\
      lines, and yellow for overlapping lines during a 3-way merge.
If <bld>unset</bld>, the diff map will not be shown.

<bld>$pref(showlineview)</bld>

If <bld>set</bld>, show a window at the bottom of the display that shows the current\
      line from each file, one on top of the other. This window is most\
      useful to do a byte-by-byte comparison of a line that has\
      changed.
If <bld>unset</bld>, the window will not be shown.

<bld>$pref(showinline1)</bld>

If <bld>set</bld>, show inline diffs in the main window. This is useful to see what the\
      actual diffs are within a large diff region.\
If <bld>unset</bld>, the inline diffs are neither computed nor shown.  This is the\
      simpler approach, where byte-by-byte comparisons\
      are used.  However, this inline diff <itl>never</itl> honors\
      any \"<itl>$pref(ignoreblanksopt)</itl>\" value, regardless of that\
      option being enabled.

<bld>$pref(showinline2)</bld>

If <bld>set</bld>, show inline diffs in the main window. This is useful to see what the\
      actual diffs are within a large diff region.\
If <bld>unset</bld>, the inline diffs are neither computed nor shown.  This approach\
      is more complex, but should give more pleasing\
      results for source code and written text files.  This is the\
      Ratcliff/Obershelp pattern matching algorithm which recursively\
      finds the largest common substring, and recursively repeats on the left\
      and right remainders.  However, this inline diff <itl>never</itl> honors\
      any \"<itl>$pref(ignoreblanksopt)</itl>\" value, regardless of that\
      option being enabled.

<bld>$pref(tagtext)</bld>

If <bld>set</bld>, the file contents will be highlighted with the options defined in the\
       Appearance section of the preferences.
If <bld>unset</bld>, the file contents won\'t be highlighted.

<bld>$pref(colorcbs)</bld>

If <bld>set</bld>, the change bars will display as solid bars of color that match the\
      colors used by the diff map.
If <bld>unset</bld>, the change bars will display a "+" for lines that exist in only\
      one file, a "-" for lines that are missing from only one file, and\
      "!" for lines that are different between the two files.

<bld>$pref(showcontextsave)</bld>

If set, two entries (Save as left / Save as right) will be added to the popup\
      menu. These entries allow to quickly save the current merge state to\
      either the left or right file.\
      Note, that this function only works with 2 files from the file system.\
      The original file (left or right) will be overwritten without warning.

<hdr>Appearance</hdr>

<bld>$pref(textopt)</bld>

This is a list of Tk text widget options that are applied to each of the two\
      text windows in the main display, and the Merge Preview. If you have Tk\
      installed on your machine these will be documented in the "Text.n" man\
      page.

<bld>$pref(difftag)</bld>

This is a list of Tk text widget tag options that are applied to all diff\
      regions. These options have a higher priority than those for just plain\
      text. Use this option to make diff regions stand out from regular text.

<bld>$pref(deltag)</bld>

This is a list of Tk text widget tag options that are applied to regions that\
      have been deleted. These options have a higher priority than those for\
      all diff regions.

<bld>$pref(instag)</bld>

This is a list of Tk text widget tag options that are applied to regions that\
      have been inserted. These options have a higher priority than those for\
      all diff regions.

<bld>$pref(chgtag)</bld>

This is a list of Tk text widget tag options that are applied to regions that\
      have been changed. These options have a higher priority than those for\
      all diff regions.

<bld>$pref(currtag)</bld>

This is a list of Tk text widget tag options that are applied to the current\
      diff region. So, for example, if you set the forground for all diff\
      regions to be black and set the foreground for this option to be blue,\
      these current diff region settings (eg. foreground color) will be used.\
      These tags have a higher priority than those for all diff regions, AND\
      a higher priority than the change, inserted and deleted diff regions,\
      but ONLY in the LEFT text window. In the RIGHT text window, these\
      settings fall BELOW the individual change-category ones described.

<bld>$pref(inlinetag)</bld>

This is a list of Tk text widget tag options that are applied to differences\
      within lines in a diff region. These tags have a higher priority than\
      those for all diff regions, and a higher priority than the change,\
      inserted and deleted diff regions, AND the current region.

<bld>$pref(bytetag)</bld>

This is a list of Tk text widget tag options that are applied to individual\
      characters in the line view. These options do not affect the main text\
      displays.

<bld>$pref(tabstops)</bld>

This defines the number of characters for each tabstop in the main display\
      windows. The default is 8.

<bld>The remaining Appearance items</bld>
are all formerly internal color settings that have now being made\
      accessible for customization. Each takes the form of a button, when\
      hovered over by the mouse, displays the current color each uses.
      Pressing that button will popup a color chooser dialog to make\
      adjustments for the items (described) that the setting covers.

<bld>$pref(adjcdr)</bld>
      is used exclusively by the <btn>Split</btn> or <btn>Combine</btn>\
      features to highlight (in the text windows) the bounds of the CDR as\
      it is being adjusted. The default is "magenta".

<bld>$pref(mapins)</bld>
      is used by the "<bld>Diff Map</bld>" as well as Split/Combine text\
      window feedback and potentially the highlighting of Line numbers or\
      Changebars (if requested), to indicate something being "added". The\
      default is "Pale Green".

<bld>$pref(mapchg)</bld>
      is used by the "<bld>Diff Map</bld>" as well as Split/Combine text\
      window feedback and potentially the highlighting of Line numbers or\
      Changebars (if requested), to indicate something being "changed". The\
      default is "Dodger Blue".

<bld>$pref(mapdel)</bld>
      is used by the "<bld>Diff Map</bld>" as well as Split/Combine text\
      window feedback and potentially the highlighting of Line numbers or\
      Changebars (if requested), to indicate something being "deleted". The\
      default is "Tomato".

<bld>$pref(mapolp)</bld>
      is used by the "<bld>Diff Map</bld>" as well as Split/Combine text\
      window feedback and potentially the highlighting of Line numbers or\
      Changebars (if requested), to indicate a COLLISION between diff\
      regions during a 3way diff. Classically this color had actually\
      been hardcoded, let alone defaulted to "yellow".

<hdr>Custom Settings</hdr>

There is an additional setting built-in to the Preferences file called\
     <bld>customCode</bld> (together with a comment about not using it) that\
     nevertheless has some simple uses. The big advantage is that, like each\
     other setting described above, the contents of this setting <itl>IS</itl>\
     retained automatically when modified by the $g(name) Preferences Dialog.
     However, it can only be <itl>set</itl> or <itl>modified</itl> externally\
     via a text editor. Still, occasionally there have been customizations of\
     the GUI that many users found helpful that are often difficult (if not\
     impossible) to specify correctly using other means. Although there are\
     fewer at the moment (per the newer 'color' buttons described above), we
     offer up the following (still valid) possibilit(y/ies) as suggestions:

    1. Highlighting the current Merge Choice (when in Icon mode) -
This item, typically required the use of XResources in the past to do\
    correctly, but the following is much simpler:
<cmp>
	      set w(selcolor) orange
</cmp>
makes it easier to see which of the four icons is presently "selected", as\
    the default is generally only a greyed background shading of the\
    unselected state. Note that the command "set" and name "w(selcolor)"\
    must be exactly as shown (using parenthesis).

CAVEAT: Doing more than this requires intimate knowledge of the internal\
    code, and, as such, could be subject to future elimination or even\
    promotion to a full fledged REAL 'Preference' setting. But for now,\
    it works. Moreover, the admonishment to not misuse this facility still\
    applies, as it is exceedingly easy to disrupt normal program operation.
    }

    # since we have embedded references to the preference labels in
    # the text, we need to perform substitutions. Because of this, if
    # you edit the above text, be sure to properly escape any dollar
    # signs that are not meant to be treated as a variable reference

    set text [subst -nocommands $text]
    do-text-info .help-preferences $title $text
}

######################################################################
#
# text formatting routines derived from Klondike
# Reproduced here with permission from their author.
#
# Copyright (C) 1993,1994 by John Heidemann <johnh@ficus.cs.ucla.edu>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of John Heidemann may not be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY JOHN HEIDEMANN ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL JOHN HEIDEMANN BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
######################################################################
proc put-text {tw txt} {

    $tw configure -font {Fixed 12}

    $tw configure -font -*-Times-Medium-R-Normal-*-14-*

    $tw tag configure bld -font -*-Times-Bold-R-Normal-*-14-*
    $tw tag configure cmp -font -*-Courier-Medium-R-Normal-*-12-*
    $tw tag configure hdr -font -*-Helvetica-Bold-R-Normal-*-16-* -underline 1
    $tw tag configure itl -font -*-Times-Medium-I-Normal-*-14-*
    $tw tag configure ttl -font -*-Helvetica-Bold-R-Normal-*-18-*
    #$tw tag configure h3 -font -*-Helvetica-Bold-R-Normal-*-14-*
    $tw tag configure btn -foreground white -background grey


    $tw mark set insert 0.0

    set t $txt

    while {[regexp -indices {<([^@>]*)>} $t match inds] == 1} {

        set start [lindex $inds 0]
        set end [lindex $inds 1]
        set keyword [string range $t $start $end]

        set oldend [$tw index end]

        $tw insert end [string range $t 0 [expr {$start - 2}]]

        purge-all-tags $tw $oldend insert

        if {[string range $keyword 0 0] == "/"} {
            set keyword [string trimleft $keyword "/"]
            if {[info exists tags($keyword)] == 0} {
                error "end tag $keyword without beginning"
            }
            $tw tag add $keyword $tags($keyword) insert
            unset tags($keyword)
        } else {
            if {[info exists tags($keyword)] == 1} {
                error "nesting of begin tag $keyword"
            }
            set tags($keyword) [$tw index insert]
        }

        set t [string range $t [expr {$end + 2}] end]
    }

    set oldend [$tw index end]
    $tw insert end $t
    purge-all-tags $tw $oldend insert
}

proc purge-all-tags {w start end} {
    foreach tag [$w tag names $start] {
        $w tag remove $tag $start $end
    }
}

# Open one of the diffed files in an editor if possible
proc do-edit {} {
    global g w opts finfo
    debug-info "do-edit ()"

    # Locate the correct filename
    set ndx [expr {$finfo(fCurpair) * 2}]
    if {$g(activeWindow) == $w(LeftText)} {incr ndx -1}

    if {[info exists finfo(tmp,$ndx)]} {
        do-error "This file is not editable"
    } else {
        # Got the file - GET the line number
        set file "$finfo(pth,$ndx)"
        if {$g(count)} {
            lassign $g(scrInf,$g(currdiff)) line na na O(1) na na O(0)
            incr line -$O([expr {int($ndx & 1)}])
        } else {set line 1} ;# have to pick something if no CDR exists

        if {[string length [string trim $opts(editor)]] == 0} {
            # OPA >>>
            poExtProg StartOneEditProg "$file"
            # simpleEd open "$file" $line
            # OPA <<<
        } elseif {[regexp "\\\$file" "$opts(editor)"] == 1} {
            eval set cmdline \"$opts(editor) &\"
            debug-info "exec $cmdline"
            eval exec $cmdline
        } else {
            debug-info "exec $opts(editor) \"{$file}\" &"
            eval exec $opts(editor) "{$file}" &
        }
    }
}

##########################################################################
# platform-specific stuff
##########################################################################
proc setAquaDialogStyle {toplevel} {
    if {[catch {tk::unsupported::MacWindowStyle style $toplevel moveableModal}] } {
        tk::unsupported::MacWindowStyle style $toplevel movableDBoxProc
    }
}

##########################################################################
# A simple editor, from Bryan Oakley.
# 22Jun2018  mpm: now accepts (opt.) line number to display (dflt = 1)
# 04Aug2018  mpm: additional keywords/parsing added for open subcmd
#            mpm: now provides line numbering (in seperate subwindow)
##########################################################################
proc simpleEd {command args} {
    global w textfont
    debug-info "simpleEd ($command $args)"

    switch -- $command {
    open {
            # Ingest required args (and establish default options):
            #   filename
            if {[set argn [llength $args]]} {
                set filename [lindex $args [set count 0]]
                set line 1
                set title  "$filename - Simple Editor"
                set FG {}
                set BG {}
            } {error "simpleEd open ?filename?: reqd arg missing"}

            # ... then see if others were provided (in any order)
            #   [Lnum] ['fg' color] ['bg' color] ['title' xxxx] ['ro']
            while {[incr count] < $argn} {
                switch -glob [set arg [lindex $args $count]] {
                "\[0-9]" { set line $arg }
                "f*"     { lappend FG -fg [lindex $args [incr count]] }
                "b*"     { lappend BG -bg [lindex $args [incr count]] }
                "t*"     { set title      [lindex $args [incr count]] }
                "ro"     { set RO    [list configure -state disabled] }
                }
            }

            set w .editor
            set count 0
            while {[winfo exists ${w}$count]} {
                incr count 1
            }
            set w ${w}$count

            toplevel $w -borderwidth 2 -relief sunken
            wm title $w $title
            wm group $w $w(tw)

            menu $w.menubar
            $w configure -menu $w.menubar
            $w.menubar add cascade -label "File" -menu $w.menubar.fileMenu

            menu $w.menubar.fileMenu

            if {![info exists RO]} {
                $w.menubar.fileMenu add command -label "Save" \
                  -underline 1 -command [list simpleEd save $filename $w]
                $w.menubar.fileMenu add command -label "Save As..." \
                  -underline 1 -command [list simpleEd saveAs $filename $w]
            $w.menubar.fileMenu add separator
            }
            $w.menubar.fileMenu add command -label "Exit" -underline 1 \
              -command [list simpleEd exit $w]

            if {![info exists RO]} {
                $w.menubar add cascade -label "Edit" -menu $w.menubar.editMenu

                menu $w.menubar.editMenu

                $w.menubar.editMenu add command -label "Cut" -command \
                  [list event  generate $w.text <<Cut>>]
            $w.menubar.editMenu add command -label "Copy" -command \
              [list event generate $w.text <<Copy>>]
            $w.menubar.editMenu add command -label "Paste" -command \
              [list event generate $w.text <<Paste>>]
            }

            text $w.text -wrap none -xscrollcommand [list $w.hsb set] \
              -yscrollcommand [list $w.vsb set] -borderwidth 0 \
              -font $textfont {*}$FG {*}$BG
            scrollbar $w.vsb -orient vertical -command [list $w.text yview]
            scrollbar $w.hsb -orient horizontal -command [list $w.text xview]

            # Derive needed info to fabricate/utilize a line numbering canvas
            set Aft [font metrics $textfont -ascent]   ;# Ascent of font
            set Dw  [font measure $textfont "8"]       ;# Digit width
            set Fg  [$w.text cget -fg]        ;# Same foreground & background
            canvas $w.cnvs -highlightthickness 0 -bg [$w.text cget -bg]

            grid $w.cnvs -row 0 -column 0 -sticky nsew
            grid $w.text -row 0 -column 1 -sticky nsew
            grid $w.vsb -row 0 -column 2 -sticky ns
            grid $w.hsb -row 1 -column 1 -sticky ew

            grid columnconfigure $w 0 -weight 0
            grid columnconfigure $w 1 -weight 1
            grid columnconfigure $w 2 -weight 0
            grid rowconfigure $w 0 -weight 1
            grid rowconfigure $w 1 -weight 0

            set fd [open $filename]
            $w.text insert 1.0 [read $fd]
            close $fd

            set lenDigits [string length [$w.text index end]]
            $w.cnvs configure -width [set X [expr {int($lenDigits-2)*$Dw+3}]]
            # N.B> tracing on the Vert-Scrlbar trips on window resizes too
            trace add execution $w.vsb leave [list apply "{Fg Asc X args} {
                $w.cnvs delete all
                set Lnum \[expr {int(\[$w.text index @0,0])}]
                set LastLnum \[expr {int(\[$w.text index end-1lines])}]
                while {\[llength \[set dl \[$w.text dlineinfo \$Lnum.0]]]>0} {
                    if {\$Lnum == \$LastLnum} {break} ;# ignore extra last line
                    lassign \$dl na y na na bl
                    incr y \$bl
                    incr y -\$Asc
                    $w.cnvs create text \$X \$y -anchor ne -font \"$textfont\" \
                              -fill \$Fg -text \$Lnum
                    incr Lnum
                }
                update idletasks
            }" $Fg $Aft [incr X -2]]
            $w.text see $line.0 ;# N.B> done AFTER the trace setup to tickle it
            if {[info exists RO]} {$w.text {*}$RO }
        }
    save {
            set filename [lindex $args 0]
            set w [lindex $args 1]
            set fd [open $filename w]
            puts $fd [$w.text get 1.0 "end-1c"]
            close $fd
        }
    saveAs {
            set filename [lindex $args 0]
            set w [lindex $args 1]
            set filename [tk_getSaveFile -filetypes $opts(filetypes) \
                                         -initialfile [file tail $filename] \
                                         -initialdir [file dirname $filename]]
            if {$filename != ""} {
                simpleEd save $filename $w
            }
        }
    exit {
            set w [lindex $args 0]
            destroy $w
        }
    }
}

# end of simpleEd

# Copyright (c) 1998-2003, Bryan Oakley
# All Rights Reserved
#
# Bryan Oakley
# oakley@bardo.clearlight.com
#
# combobox v2.3 August 16, 2003
#
# MODIFIED (for TkDiff)
# 31Jul2018  mpm: (tagged) added support for 'list itemconfigure' subcommand
#
# a combobox / dropdown listbox (pick your favorite name) widget 
# written in pure tcl
#
# this code is freely distributable without restriction, but is 
# provided as-is with no warranty expressed or implied. 
#
# thanks to the following people who provided beta test support or
# patches to the code (in no particular order):
#
# Scott Beasley     Alexandre Ferrieux      Todd Helfter
# Matt Gushee       Laurent Duperval        John Jackson
# Fred Rapp         Christopher Nelson
# Eric Galluzzo     Jean-Francois Moine     Oliver Bienert
#
# A special thanks to Martin M. Hunt who provided several good ideas, 
# and always with a patch to implement them. Jean-Francois Moine, 
# Todd Helfter and John Jackson were also kind enough to send in some 
# code patches.
#
# ... and many others over the years.

package require Tk 8.0
package provide combobox 2.3

namespace eval ::combobox {

    # this is the public interface
    namespace export combobox

    # these contain references to available options
    variable widgetOptions

    # these contain references to available commands and subcommands
    variable widgetCommands
    variable scanCommands
    variable listCommands
}

# ::combobox::combobox --
#
#     This is the command that gets exported. It creates a new
#     combobox widget.
#
# Arguments:
#
#     w        path of new widget to create
#     args     additional option/value pairs (eg: -background white, etc.)
#
# Results:
#
#     It creates the widget and sets up all of the default bindings
#
# Returns:
#
#     The name of the newly create widget

proc ::combobox::combobox {w args} {
    variable widgetOptions
    variable widgetCommands
    variable scanCommands
    variable listCommands

    # perform a one time initialization
    if {![info exists widgetOptions]} {
        Init
    }

    # build it...
    eval Build $w $args

    # set some bindings...
    SetBindings $w

    # and we are done!
    return $w
}

# ::combobox::Init --
#
#     Initialize the namespace variables. This should only be called
#     once, immediately prior to creating the first instance of the
#     widget
#
# Arguments:
#
#    none
#
# Results:
#
#     All state variables are set to their default values; all of 
#     the option database entries will exist.
#
# Returns:
# 
#     empty string

proc ::combobox::Init {} {
    variable widgetOptions
    variable widgetCommands
    variable scanCommands
    variable listCommands
    variable defaultEntryCursor

    array set widgetOptions [list \
        -background          {background          Background} \
        -bd                  -borderwidth \
        -bg                  -background \
        -borderwidth         {borderWidth         BorderWidth} \
        -buttonbackground    {buttonBackground    Background} \
        -command             {command             Command} \
        -commandstate        {commandState        State} \
        -cursor              {cursor              Cursor} \
        -disabledbackground  {disabledBackground  DisabledBackground} \
        -disabledforeground  {disabledForeground  DisabledForeground} \
        -dropdownwidth       {dropdownWidth       DropdownWidth} \
        -editable            {editable            Editable} \
        -elementborderwidth  {elementBorderWidth  BorderWidth} \
        -fg                  -foreground \
        -font                {font                Font} \
        -foreground          {foreground          Foreground} \
        -height              {height              Height} \
        -highlightbackground {highlightBackground HighlightBackground} \
        -highlightcolor      {highlightColor      HighlightColor} \
        -highlightthickness  {highlightThickness  HighlightThickness} \
        -image               {image               Image} \
        -listvar             {listVariable        Variable} \
        -maxheight           {maxHeight           Height} \
        -opencommand         {opencommand         Command} \
        -relief              {relief              Relief} \
        -selectbackground    {selectBackground    Foreground} \
        -selectborderwidth   {selectBorderWidth   BorderWidth} \
        -selectforeground    {selectForeground    Background} \
        -state               {state               State} \
        -takefocus           {takeFocus           TakeFocus} \
        -textvariable        {textVariable        Variable} \
        -value               {value               Value} \
        -width               {width               Width} \
        -xscrollcommand      {xScrollCommand      ScrollCommand} \
    ]


    set widgetCommands [list \
        bbox      cget     configure    curselection \
        delete    get      icursor      index        \
        insert    list     scan         selection    \
        xview     select   toggle       open         \
        close    subwidget  \
    ]

    set listCommands [list \
        delete       get      \
        index        insert   itemconfigure    size \
    ]  ;# mpm - added itemconfigure

    set scanCommands [list mark dragto]

    # why check for the Tk package? This lets us be sourced into 
    # an interpreter that doesn't have Tk loaded, such as the slave
    # interpreter used by pkg_mkIndex. In theory it should have no
    # side effects when run 
    if {[lsearch -exact [package names] "Tk"] != -1} {

        ##################################################################
        #- this initializes the option database. Kinda gross, but it works
        #- (I think). 
        ##################################################################

        # the image used for the button...
        if {$::tcl_platform(platform) == "windows"} {
            image create bitmap ::combobox::bimage -data {
                #define down_arrow_width 12
                #define down_arrow_height 12
                static char down_arrow_bits[] = {
                    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                    0xfc,0xf1,0xf8,0xf0,0x70,0xf0,0x20,0xf0,
                    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00;
                }
            }
        } else {
            image create bitmap ::combobox::bimage -data  {
                #define down_arrow_width 15
                #define down_arrow_height 15
                static char down_arrow_bits[] = {
                    0x00,0x80,0x00,0x80,0x00,0x80,0x00,0x80,
                    0x00,0x80,0xf8,0x8f,0xf0,0x87,0xe0,0x83,
                    0xc0,0x81,0x80,0x80,0x00,0x80,0x00,0x80,
                    0x00,0x80,0x00,0x80,0x00,0x80
                }
            }
        }

        # compute a widget name we can use to create a temporary widget
        set tmpWidget ".__tmp__"
        set count 0
        while {[winfo exists $tmpWidget] == 1} {
            set tmpWidget ".__tmp__$count"
            incr count
        }

        # get the scrollbar width. Because we try to be clever and draw our
        # own button instead of using a tk widget, we need to know what size
        # button to create. This little hack tells us the width of a scroll
        # bar.
        #
        # NB: we need to be sure and pick a window  that doesn't already
        # exist... 
        scrollbar $tmpWidget
        set sb_width [winfo reqwidth $tmpWidget]
        set bbg [$tmpWidget cget -background]
        destroy $tmpWidget

        # steal options from the entry widget
        # we want darn near all options, so we'll go ahead and do
        # them all. No harm done in adding the one or two that we
        # don't use.
        entry $tmpWidget 
        foreach foo [$tmpWidget configure] {
            # the cursor option is special, so we'll save it in
            # a special way
            if {[lindex $foo 0] == "-cursor"} {
                set defaultEntryCursor [lindex $foo 4]
            }
            if {[llength $foo] == 5} {
                set option [lindex $foo 1]
                set value [lindex $foo 4]
                option add *Combobox.$option $value widgetDefault

                # these options also apply to the dropdown listbox
                if {[string compare $option "foreground"] == 0 \
                        || [string compare $option "background"] == 0 \
                        || [string compare $option "font"] == 0} {
                    option add *Combobox*ComboboxListbox.$option $value \
                            widgetDefault
                }
            }
        }
        destroy $tmpWidget

        # these are unique to us...
        option add *Combobox.elementBorderWidth  1      widgetDefault
        option add *Combobox.buttonBackground    $bbg   widgetDefault
        option add *Combobox.dropdownWidth       {}     widgetDefault
        option add *Combobox.openCommand         {}     widgetDefault
        option add *Combobox.cursor              {}     widgetDefault
        option add *Combobox.commandState        normal widgetDefault
        option add *Combobox.editable            1      widgetDefault
        option add *Combobox.maxHeight           10     widgetDefault
        option add *Combobox.height              0
    }

    # set class bindings
    SetClassBindings
}

# ::combobox::SetClassBindings --
#
#    Sets up the default bindings for the widget class
#
#    this proc exists since it's The Right Thing To Do, but
#    I haven't had the time to figure out how to do all the
#    binding stuff on a class level. The main problem is that
#    the entry widget must have focus for the insertion cursor
#    to be visible. So, I either have to have the entry widget
#    have the Combobox bindtag, or do some fancy juggling of
#    events or some such. What a pain.
#
# Arguments:
#
#    none
#
# Returns:
#
#    empty string

proc ::combobox::SetClassBindings {} {

    # make sure we clean up after ourselves...
    bind Combobox <Destroy> [list ::combobox::DestroyHandler %W]

    # this will (hopefully) close (and lose the grab on) the
    # listbox if the user clicks anywhere outside of it. Note
    # that on Windows, you can click on some other app and
    # the listbox will still be there, because tcl won't see
    # that button click
    set this {[::combobox::convert %W -W]}
    bind Combobox <Any-ButtonPress>   "$this close"
    bind Combobox <Any-ButtonRelease> "$this close"

    # this helps (but doesn't fully solve) focus issues. The general
    # idea is, whenever the frame gets focus it gets passed on to
    # the entry widget
    bind Combobox <FocusIn> {::combobox::tkTabToWindow \
                                 [::combobox::convert %W -W].entry}

    # this closes the listbox if we get hidden
    bind Combobox <Unmap> {[::combobox::convert %W -W] close}

    return ""
}

# ::combobox::SetBindings --
#
#    here's where we do most of the binding foo. I think there's probably
#    a few bindings I ought to add that I just haven't thought
#    about...
#
#    I'm not convinced these are the proper bindings. Ideally all
#    bindings should be on "Combobox", but because of my juggling of
#    bindtags I'm not convinced thats what I want to do. But, it all
#    seems to work, its just not as robust as it could be.
#
# Arguments:
#
#    w    widget pathname
#
# Returns:
#
#    empty string

proc ::combobox::SetBindings {w} {
    upvar ::combobox::${w}::widgets  widgets
    upvar ::combobox::${w}::options  options

    # juggle the bindtags. The basic idea here is to associate the
    # widget name with the entry widget, so if a user does a bind
    # on the combobox it will get handled properly since it is
    # the entry widget that has keyboard focus.
    bindtags $widgets(entry) \
            [concat $widgets(this) [bindtags $widgets(entry)]]

    bindtags $widgets(button) \
            [concat $widgets(this) [bindtags $widgets(button)]]

    # override the default bindings for tab and shift-tab. The
    # focus procs take a widget as their only parameter and we
    # want to make sure the right window gets used (for shift-
    # tab we want it to appear as if the event was generated
    # on the frame rather than the entry. 
    bind $widgets(entry) <Tab> \
            "::combobox::tkTabToWindow \[tk_focusNext $widgets(entry)\]; break"
    bind $widgets(entry) <Shift-Tab> \
            "::combobox::tkTabToWindow \[tk_focusPrev $widgets(this)\]; break"
    
    # this makes our "button" (which is actually a label)
    # do the right thing
    bind $widgets(button) <ButtonPress-1> [list $widgets(this) toggle]

    # this lets the autoscan of the listbox work, even if they
    # move the cursor over the entry widget.
    bind $widgets(entry) <B1-Enter> "break"

    bind $widgets(listbox) <ButtonRelease-1> \
        "::combobox::Select [list $widgets(this)] \
         \[$widgets(listbox) nearest %y\]; break"

    bind $widgets(vsb) <ButtonPress-1>   {continue}
    bind $widgets(vsb) <ButtonRelease-1> {continue}

    bind $widgets(listbox) <Any-Motion> {
        %W selection clear 0 end
        %W activate @%x,%y
        %W selection anchor @%x,%y
        %W selection set @%x,%y @%x,%y
        # need to do a yview if the cursor goes off the top
        # or bottom of the window... (or do we?)
    }

    # these events need to be passed from the entry widget
    # to the listbox, or otherwise need some sort of special
    # handling. 
    foreach event [list <Up> <Down> <Tab> <Return> <Escape> \
            <Next> <Prior> <Double-1> <1> <Any-KeyPress> \
            <FocusIn> <FocusOut>] {
        bind $widgets(entry) $event \
            [list ::combobox::HandleEvent $widgets(this) $event]
    }

    # like the other events, <MouseWheel> needs to be passed from
    # the entry widget to the listbox. However, in this case we
    # need to add an additional parameter
    catch {
        bind $widgets(entry) <MouseWheel> \
            [list ::combobox::HandleEvent $widgets(this) <MouseWheel> %D]
    }
}

# ::combobox::Build --
#
#    This does all of the work necessary to create the basic
#    combobox. 
#
# Arguments:
#
#    w        widget name
#    args     additional option/value pairs
#
# Results:
#
#    Creates a new widget with the given name. Also creates a new
#    namespace patterened after the widget name, as a child namespace
#    to ::combobox
#
# Returns:
#
#    the name of the widget

proc ::combobox::Build {w args } {
    variable widgetOptions

    if {[winfo exists $w]} {
        error "window name \"$w\" already exists"
    }

    # create the namespace for this instance, and define a few
    # variables
    namespace eval ::combobox::$w {

        variable ignoreTrace 0
        variable oldFocus    {}
        variable oldGrab     {}
        variable oldValue    {}
        variable options
        variable this
        variable widgets

        set widgets(foo) foo  ;# coerce into an array
        set options(foo) foo  ;# coerce into an array

        unset widgets(foo)
        unset options(foo)
    }

    # import the widgets and options arrays into this proc so
    # we don't have to use fully qualified names, which is a
    # pain.
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    # this is our widget -- a frame of class Combobox. Naturally,
    # it will contain other widgets. We create it here because
    # we need it in order to set some default options.
    set widgets(this)   [frame  $w -class Combobox -takefocus 0]
    set widgets(entry)  [entry  $w.entry -takefocus 1]
    set widgets(button) [label  $w.button -takefocus 0] 

    # this defines all of the default options. We get the
    # values from the option database. Note that if an array
    # value is a list of length one it is an alias to another
    # option, so we just ignore it
    foreach name [array names widgetOptions] {
        if {[llength $widgetOptions($name)] == 1} continue

        set optName  [lindex $widgetOptions($name) 0]
        set optClass [lindex $widgetOptions($name) 1]

        set value [option get $w $optName $optClass]
        set options($name) $value
    }

    # a couple options aren't available in earlier versions of
    # tcl, so we'll set them to sane values. For that matter, if
    # they exist but are empty, set them to sane values.
    if {[string length $options(-disabledforeground)] == 0} {
        set options(-disabledforeground) $options(-foreground)
    }
    if {[string length $options(-disabledbackground)] == 0} {
        set options(-disabledbackground) $options(-background)
    }

    # if -value is set to null, we'll remove it from our
    # local array. The assumption is, if the user sets it from
    # the option database, they will set it to something other
    # than null (since it's impossible to determine the difference
    # between a null value and no value at all).
    if {[info exists options(-value)] \
            && [string length $options(-value)] == 0} {
        unset options(-value)
    }

    # we will later rename the frame's widget proc to be our
    # own custom widget proc. We need to keep track of this
    # new name, so we'll define and store it here...
    set widgets(frame) ::combobox::${w}::$w

    # gotta do this sooner or later. Might as well do it now
    pack $widgets(button) -side right -fill y    -expand no
    pack $widgets(entry)  -side left  -fill both -expand yes

    # I should probably do this in a catch, but for now it's
    # good enough... What it does, obviously, is put all of
    # the option/values pairs into an array. Make them easier
    # to handle later on...
    array set options $args

    # now, the dropdown list... the same renaming nonsense
    # must go on here as well...
    set widgets(dropdown)   [toplevel  $w.top]
    set widgets(listbox) [listbox   $w.top.list]
    set widgets(vsb)     [scrollbar $w.top.vsb]

    pack $widgets(listbox) -side left -fill both -expand y

    # fine tune the widgets based on the options (and a few
    # arbitrary values...)

    # NB: we are going to use the frame to handle the relief
    # of the widget as a whole, so the entry widget will be 
    # flat. This makes the button which drops down the list
    # to appear "inside" the entry widget.

    $widgets(vsb) configure \
            -borderwidth 1 \
            -command "$widgets(listbox) yview" \
            -highlightthickness 0

    $widgets(button) configure \
            -background $options(-buttonbackground) \
            -highlightthickness 0 \
            -borderwidth $options(-elementborderwidth) \
            -relief raised \
            -width [expr {[winfo reqwidth $widgets(vsb)] - 2}]

    $widgets(entry) configure \
            -borderwidth 0 \
            -relief flat \
            -highlightthickness 0 

    $widgets(dropdown) configure \
            -borderwidth $options(-elementborderwidth) \
            -relief sunken

    $widgets(listbox) configure \
            -selectmode browse \
            -background [$widgets(entry) cget -bg] \
            -yscrollcommand "$widgets(vsb) set" \
            -exportselection false \
            -borderwidth 0


#    trace variable ::combobox::${w}::entryTextVariable w \
#        [list ::combobox::EntryTrace $w]

    # do some window management foo on the dropdown window
    wm overrideredirect $widgets(dropdown) 1
    wm transient        $widgets(dropdown) [winfo toplevel $w]
    wm group            $widgets(dropdown) [winfo parent $w]
    wm resizable        $widgets(dropdown) 0 0
    wm withdraw         $widgets(dropdown)
    
    # this moves the original frame widget proc into our
    # namespace and gives it a handy name
    rename ::$w $widgets(frame)

    # now, create our widget proc. Obviously (?) it goes in
    # the global namespace. All combobox widgets will actually
    # share the same widget proc to cut down on the amount of
    # bloat. 
    proc ::$w {command args} \
        "eval ::combobox::WidgetProc $w \$command \$args"


    # ok, the thing exists... let's do a bit more configuration. 
    if {[catch "::combobox::Configure [list $widgets(this)] [array get options]" error]} {
        catch {destroy $w}
        error "internal error: $error"
    }

    return ""
}

# ::combobox::HandleEvent --
#
#    this proc handles events from the entry widget that we want
#    handled specially (typically, to allow navigation of the list
#    even though the focus is in the entry widget)
#
# Arguments:
#
#    w       widget pathname
#    event   a string representing the event (not necessarily an
#            actual event)
#    args    additional arguments required by particular events

proc ::combobox::HandleEvent {w event args} {
    upvar ::combobox::${w}::widgets  widgets
    upvar ::combobox::${w}::options  options
    upvar ::combobox::${w}::oldValue oldValue

    # for all of these events, if we have a special action we'll
    # do that and do a "return -code break" to keep additional 
    # bindings from firing. Otherwise we'll let the event fall
    # on through. 
    switch $event {

        "<MouseWheel>" {
            if {[winfo ismapped $widgets(dropdown)]} {
                set D [lindex $args 0]
                # the '120' number in the following expression has
                # it's genesis in the tk bind manpage, which suggests
                # that the smallest value of %D for mousewheel events
                # will be 120. The intent is to scroll one line at a time.
                $widgets(listbox) yview scroll [expr {-($D/120)}] units
            }
        } 

        "<Any-KeyPress>" {
            # if the widget is editable, clear the selection. 
            # this makes it more obvious what will happen if the 
            # user presses <Return> (and helps our code know what
            # to do if the user presses return)
            if {$options(-editable)} {
                $widgets(listbox) see 0
                $widgets(listbox) selection clear 0 end
                $widgets(listbox) selection anchor 0
                $widgets(listbox) activate 0
            }
        }

        "<FocusIn>" {
            set oldValue [$widgets(entry) get]
        }

        "<FocusOut>" {
            if {![winfo ismapped $widgets(dropdown)]} {
                # did the value change?
                set newValue [$widgets(entry) get]
                if {$oldValue != $newValue} {
                    CallCommand $widgets(this) $newValue
                }
            }
        }

        "<1>" {
            set editable [::combobox::GetBoolean $options(-editable)]
            if {!$editable} {
                if {[winfo ismapped $widgets(dropdown)]} {
                    $widgets(this) close
                    return -code break;

                } else {
                    if {$options(-state) != "disabled"} {
                        $widgets(this) open
                        return -code break;
                    }
                }
            }
        }

        "<Double-1>" {
            if {$options(-state) != "disabled"} {
                $widgets(this) toggle
                return -code break;
            }
        }

        "<Tab>" {
            if {[winfo ismapped $widgets(dropdown)]} {
                ::combobox::Find $widgets(this) 0
                return -code break;
            } else {
                ::combobox::SetValue $widgets(this) [$widgets(this) get]
            }
        }

        "<Escape>" {
#           $widgets(entry) delete 0 end
#           $widgets(entry) insert 0 $oldValue
            if {[winfo ismapped $widgets(dropdown)]} {
                $widgets(this) close
                return -code break;
            }
        }

        "<Return>" {
            # did the value change?
            set newValue [$widgets(entry) get]
            if {$oldValue != $newValue} {
                CallCommand $widgets(this) $newValue
            }

            if {[winfo ismapped $widgets(dropdown)]} {
                ::combobox::Select $widgets(this) \
                        [$widgets(listbox) curselection]
                return -code break;
            } 
        }

        "<Next>" {
            $widgets(listbox) yview scroll 1 pages
            set index [$widgets(listbox) index @0,0]
            $widgets(listbox) see $index
            $widgets(listbox) activate $index
            $widgets(listbox) selection clear 0 end
            $widgets(listbox) selection anchor $index
            $widgets(listbox) selection set $index
        }

        "<Prior>" {
            $widgets(listbox) yview scroll -1 pages
            set index [$widgets(listbox) index @0,0]
            $widgets(listbox) activate $index
            $widgets(listbox) see $index
            $widgets(listbox) selection clear 0 end
            $widgets(listbox) selection anchor $index
            $widgets(listbox) selection set $index
        }

        "<Down>" {
            if {[winfo ismapped $widgets(dropdown)]} {
                ::combobox::tkListboxUpDown $widgets(listbox) 1
                return -code break;

            } else {
                if {$options(-state) != "disabled"} {
                    $widgets(this) open
                    return -code break;
                }
            }
        }

        "<Up>" {
            if {[winfo ismapped $widgets(dropdown)]} {
                ::combobox::tkListboxUpDown $widgets(listbox) -1
                return -code break;

            } else {
                if {$options(-state) != "disabled"} {
                    $widgets(this) open
                    return -code break;
                }
            }
        }
    }

    return ""
}

# ::combobox::DestroyHandler {w} --
# 
#    Cleans up after a combobox widget is destroyed
#
# Arguments:
#
#    w    widget pathname
#
# Results:
#
#    The namespace that was created for the widget is deleted,
#    and the widget proc is removed.

proc ::combobox::DestroyHandler {w} {

    catch {
        # if the widget actually being destroyed is of class Combobox,
        # remove the namespace and associated proc.
        if {[string compare [winfo class $w] "Combobox"] == 0} {
            # delete the namespace and the proc which represents
            # our widget
            namespace delete ::combobox::$w
            rename $w {}
        }   
    }
    return ""
}

# ::combobox::Find
#
#    finds something in the listbox that matches the pattern in the
#    entry widget and selects it
#
#    N.B. I'm not convinced this is working the way it ought to. It
#    works, but is the behavior what is expected? I've also got a gut
#    feeling that there's a better way to do this, but I'm too lazy to
#    figure it out...
#
# Arguments:
#
#    w      widget pathname
#    exact  boolean; if true an exact match is desired
#
# Returns:
#
#    Empty string

proc ::combobox::Find {w {exact 0}} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    ## *sigh* this logic is rather gross and convoluted. Surely
    ## there is a more simple, straight-forward way to implement
    ## all this. As the saying goes, I lack the time to make it
    ## shorter...

    # use what is already in the entry widget as a pattern
    set pattern [$widgets(entry) get]

    if {[string length $pattern] == 0} {
        # clear the current selection
        $widgets(listbox) see 0
        $widgets(listbox) selection clear 0 end
        $widgets(listbox) selection anchor 0
        $widgets(listbox) activate 0
        return
    }

    # we're going to be searching this list...
    set list [$widgets(listbox) get 0 end]

    # if we are doing an exact match, try to find,
    # well, an exact match
    set exactMatch -1
    if {$exact} {
        set exactMatch [lsearch -exact $list $pattern]
    }

    # search for it. We'll try to be clever and not only
    # search for a match for what they typed, but a match for
    # something close to what they typed. We'll keep removing one
    # character at a time from the pattern until we find a match
    # of some sort.
    set index -1
    while {$index == -1 && [string length $pattern]} {
        set index [lsearch -glob $list "$pattern*"]
        if {$index == -1} {
            regsub -- {.$} $pattern {} pattern
        }
    }

    # this is the item that most closely matches...
    set thisItem [lindex $list $index]

    # did we find a match? If so, do some additional munging...
    if {$index != -1} {

        # we need to find the part of the first item that is 
        # unique WRT the second... I know there's probably a
        # simpler way to do this... 

        set nextIndex [expr {$index + 1}]
        set nextItem [lindex $list $nextIndex]

        # we don't really need to do much if the next
        # item doesn't match our pattern...
        if {[string match $pattern* $nextItem]} {
            # ok, the next item matches our pattern, too
            # now the trick is to find the first character
            # where they *don't* match...
            set marker [string length $pattern]
            while {$marker <= [string length $pattern]} {
                set a [string index $thisItem $marker]
                set b [string index $nextItem $marker]
                if {[string compare $a $b] == 0} {
                    append pattern $a
                    incr marker
                } else {
                    break
                }
            }
        } else {
            set marker [string length $pattern]
        }

    } else {
        set marker end
        set index 0
    }

    # ok, we know the pattern and what part is unique;
    # update the entry widget and listbox appropriately
    if {$exact && $exactMatch == -1} {
        # this means we didn't find an exact match
        $widgets(listbox) selection clear 0 end
        $widgets(listbox) see $index

    } elseif {!$exact}  {
        # this means we found something, but it isn't an exact
        # match. If we find something that *is* an exact match we
        # don't need to do the following, since it would merely 
        # be replacing the data in the entry widget with itself
        set oldstate [$widgets(entry) cget -state]
        $widgets(entry) configure -state normal
        $widgets(entry) delete 0 end
        $widgets(entry) insert end $thisItem
        $widgets(entry) selection clear
        $widgets(entry) selection range $marker end
        $widgets(listbox) activate $index
        $widgets(listbox) selection clear 0 end
        $widgets(listbox) selection anchor $index
        $widgets(listbox) selection set $index
        $widgets(listbox) see $index
        $widgets(entry) configure -state $oldstate
    }
}

# ::combobox::Select --
#
#    selects an item from the list and sets the value of the combobox
#    to that value
#
# Arguments:
#
#    w      widget pathname
#    index  listbox index of item to be selected
#
# Returns:
#
#    empty string

proc ::combobox::Select {w index} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    # the catch is because I'm sloppy -- presumably, the only time
    # an error will be caught is if there is no selection. 
    if {![catch {set data [$widgets(listbox) get [lindex $index 0]]}]} {
        ::combobox::SetValue $widgets(this) $data

        $widgets(listbox) selection clear 0 end
        $widgets(listbox) selection anchor $index
        $widgets(listbox) selection set $index

    }
    $widgets(entry) selection range 0 end
    $widgets(entry) icursor end

    $widgets(this) close

    return ""
}

# ::combobox::HandleScrollbar --
# 
#    causes the scrollbar of the dropdown list to appear or disappear
#    based on the contents of the dropdown listbox
#
# Arguments:
#
#    w       widget pathname
#    action  the action to perform on the scrollbar
#
# Returns:
#
#    an empty string

proc ::combobox::HandleScrollbar {w {action "unknown"}} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    if {$options(-height) == 0} {
        set hlimit $options(-maxheight)
    } else {
        set hlimit $options(-height)
    }

    switch $action {
        "grow" {
            if {$hlimit > 0 && [$widgets(listbox) size] > $hlimit} {
                pack forget $widgets(listbox)
                pack $widgets(vsb) -side right -fill y -expand n
                pack $widgets(listbox) -side left -fill both -expand y
            }
        }

        "shrink" {
            if {$hlimit > 0 && [$widgets(listbox) size] <= $hlimit} {
                pack forget $widgets(vsb)
            }
        }

        "crop" {
            # this means the window was cropped and we definitely 
            # need a scrollbar no matter what the user wants
            pack forget $widgets(listbox)
            pack $widgets(vsb) -side right -fill y -expand n
            pack $widgets(listbox) -side left -fill both -expand y
        }

        default {
            if {$hlimit > 0 && [$widgets(listbox) size] > $hlimit} {
                pack forget $widgets(listbox)
                pack $widgets(vsb) -side right -fill y -expand n
                pack $widgets(listbox) -side left -fill both -expand y
            } else {
                pack forget $widgets(vsb)
            }
        }
    }

    return ""
}

# ::combobox::ComputeGeometry --
#
#    computes the geometry of the dropdown list based on the size of the
#    combobox...
#
# Arguments:
#
#    w     widget pathname
#
# Returns:
#
#    the desired geometry of the listbox

proc ::combobox::ComputeGeometry {w} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options
    
    if {$options(-height) == 0 && $options(-maxheight) != "0"} {
        # if this is the case, count the items and see if
        # it exceeds our maxheight. If so, set the listbox
        # size to maxheight...
        set nitems [$widgets(listbox) size]
        if {$nitems > $options(-maxheight)} {
            # tweak the height of the listbox
            $widgets(listbox) configure -height $options(-maxheight)
        } else {
            # un-tweak the height of the listbox
            $widgets(listbox) configure -height 0
        }
        update idletasks
    }

    # compute height and width of the dropdown list
    set bd [$widgets(dropdown) cget -borderwidth]
    set height [expr {[winfo reqheight $widgets(dropdown)] + $bd + $bd}]
    if {[string length $options(-dropdownwidth)] == 0 || 
        $options(-dropdownwidth) == 0} {
        set width [winfo width $widgets(this)]
    } else {
        set m [font measure [$widgets(listbox) cget -font] "m"]
        set width [expr {$options(-dropdownwidth) * $m}]
    }

    # figure out where to place it on the screen, trying to take into
    # account we may be running under some virtual window manager
    set screenWidth  [winfo screenwidth $widgets(this)]
    set screenHeight [winfo screenheight $widgets(this)]
    set rootx        [winfo rootx $widgets(this)]
    set rooty        [winfo rooty $widgets(this)]
    set vrootx       [winfo vrootx $widgets(this)]
    set vrooty       [winfo vrooty $widgets(this)]

    # the x coordinate is simply the rootx of our widget, adjusted for
    # the virtual window. We won't worry about whether the window will
    # be offscreen to the left or right -- we want the illusion that it
    # is part of the entry widget, so if part of the entry widget is off-
    # screen, so will the list. If you want to change the behavior,
    # simply change the if statement... (and be sure to update this
    # comment!)
    set x  [expr {$rootx + $vrootx}]
    if {0} { 
        set rightEdge [expr {$x + $width}]
        if {$rightEdge > $screenWidth} {
            set x [expr {$screenWidth - $width}]
        }
        if {$x < 0} {set x 0}
    }

    # the y coordinate is the rooty plus vrooty offset plus 
    # the height of the static part of the widget plus 1 for a 
    # tiny bit of visual separation...
    set y [expr {$rooty + $vrooty + [winfo reqheight $widgets(this)] + 1}]
    set bottomEdge [expr {$y + $height}]

    if {$bottomEdge >= $screenHeight} {
        # ok. Fine. Pop it up above the entry widget isntead of
        # below.
        set y [expr {($rooty - $height - 1) + $vrooty}]

        if {$y < 0} {
            # this means it extends beyond our screen. How annoying.
            # Now we'll try to be real clever and either pop it up or
            # down, depending on which way gives us the biggest list. 
            # then, we'll trim the list to fit and force the use of
            # a scrollbar

            # (sadly, for windows users this measurement doesn't
            # take into consideration the height of the taskbar,
            # but don't blame me -- there isn't any way to detect
            # it or figure out its dimensions. The same probably
            # applies to any window manager with some magic windows
            # glued to the top or bottom of the screen)

            if {$rooty > [expr {$screenHeight / 2}]} {
                # we are in the lower half of the screen -- 
                # pop it up. Y is zero; that parts easy. The height
                # is simply the y coordinate of our widget, minus
                # a pixel for some visual separation. The y coordinate
                # will be the topof the screen.
                set y 1
                set height [expr {$rooty - 1 - $y}]

            } else {
                # we are in the upper half of the screen --
                # pop it down
                set y [expr {$rooty + $vrooty + \
                        [winfo reqheight $widgets(this)] + 1}]
                set height [expr {$screenHeight - $y}]

            }

            # force a scrollbar
            HandleScrollbar $widgets(this) crop
        }
    }

    if {$y < 0} {
        # hmmm. Bummer.
        set y 0
        set height $screenheight
    }

    set geometry [format "=%dx%d+%d+%d" $width $height $x $y]

    return $geometry
}

# ::combobox::DoInternalWidgetCommand --
#
#    perform an internal widget command, then mung any error results
#    to look like it came from our megawidget. A lot of work just to
#    give the illusion that our megawidget is an atomic widget
#
# Arguments:
#
#    w           widget pathname
#    subwidget   pathname of the subwidget 
#    command     subwidget command to be executed
#    args        arguments to the command
#
# Returns:
#
#    The result of the subwidget command, or an error

proc ::combobox::DoInternalWidgetCommand {w subwidget command args} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    set subcommand $command
    set command [concat $widgets($subwidget) $command $args]

    if {[catch $command result]} {
        # replace the subwidget name with the megawidget name
        regsub -- $widgets($subwidget) $result $widgets(this) result

        # replace specific instances of the subwidget command
        # with our megawidget command
        switch $subwidget,$subcommand {
            listbox,index  {regsub -- "index"  $result "list index"  result}
            listbox,insert {regsub -- "insert" $result "list insert" result}
            listbox,delete {regsub -- "delete" $result "list delete" result}
            listbox,get    {regsub -- "get"    $result "list get"    result}
            listbox,size   {regsub -- "size"   $result "list size"   result}
            listbox,itemconfigure   { ;# mpm: added entire switch clause
              regsub -- "itemconfigure" $result "list itemconfigure" result}
        }
        error $result

    } else {
        return $result
    }
}


# ::combobox::WidgetProc --
#
#    This gets uses as the widgetproc for an combobox widget. 
#    Notice where the widget is created and you'll see that the
#    actual widget proc merely evals this proc with all of the
#    arguments intact.
#
#    Note that some widget commands are defined "inline" (ie:
#    within this proc), and some do most of their work in 
#    separate procs. This is merely because sometimes it was
#    easier to do it one way or the other.
#
# Arguments:
#
#    w         widget pathname
#    command   widget subcommand
#    args      additional arguments; varies with the subcommand
#
# Results:
#
#    Performs the requested widget command

proc ::combobox::WidgetProc {w command args} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options
    upvar ::combobox::${w}::oldFocus oldFocus
    upvar ::combobox::${w}::oldFocus oldGrab

    set command [::combobox::Canonize $w command $command]

    # this is just shorthand notation...
    set doWidgetCommand \
            [list ::combobox::DoInternalWidgetCommand $widgets(this)]

    if {$command == "list"} {
        # ok, the next argument is a list command; we'll 
        # rip it from args and append it to command to
        # create a unique internal command
        #
        # NB: because of the sloppy way we are doing this,
        # we'll also let the user enter our secret command
        # directly (eg: list-insert, list-delete), but we
        # won't document that fact (mpm: bugfix - was missing Canonize)
        set command "list-[::combobox::Canonize \
                                 $w {list command} [lindex $args 0]]"
        set args [lrange $args 1 end]
    }

    set result ""

    # many of these commands are just synonyms for specific
    # commands in one of the subwidgets. We'll get them out
    # of the way first, then do the custom commands.
    switch $command {
        bbox -
        delete -
        get -
        icursor -
        index -
        insert -
        scan -
        selection -
        xview {
            set result [eval $doWidgetCommand entry $command $args]
        }
        list-get    {set result [eval $doWidgetCommand listbox get $args]}
        list-index  {set result [eval $doWidgetCommand listbox index $args]}
        list-size   {set result [eval $doWidgetCommand listbox size $args]}
        list-itemconfigure   { ;# mpm - added entire switch clause
               set result [eval $doWidgetCommand listbox itemconfigure $args]}

        select {
            if {[llength $args] == 1} {
                set index [lindex $args 0]
                set result [Select $widgets(this) $index]
            } else {
                error "usage: $w select index"
            }
        }

        subwidget {
            set knownWidgets [list button entry listbox dropdown vsb]
            if {[llength $args] == 0} {
                return $knownWidgets
            }

            set name [lindex $args 0]
            if {[lsearch $knownWidgets $name] != -1} {
                set result $widgets($name)
            } else {
                error "unknown subwidget $name"
            }
        }

        curselection {
            set result [eval $doWidgetCommand listbox curselection]
        }

        list-insert {
            eval $doWidgetCommand listbox insert $args
            set result [HandleScrollbar $w "grow"]
        }

        list-delete {
            eval $doWidgetCommand listbox delete $args
            set result [HandleScrollbar $w "shrink"]
        }

        toggle {
            # ignore this command if the widget is disabled...
            if {$options(-state) == "disabled"} return

            # pops down the list if it is not, hides it
            # if it is...
            if {[winfo ismapped $widgets(dropdown)]} {
                set result [$widgets(this) close]
            } else {
                set result [$widgets(this) open]
            }
        }

        open {

            # if this is an editable combobox, the focus should
            # be set to the entry widget
            if {$options(-editable)} {
                focus $widgets(entry)
                $widgets(entry) select range 0 end
                $widgets(entry) icursor end
            }

            # if we are disabled, we won't allow this to happen
            if {$options(-state) == "disabled"} {
                return 0
            }

            # if there is a -opencommand, execute it now
            if {[string length $options(-opencommand)] > 0} {
                # hmmm... should I do a catch, or just let the normal
                # error handling handle any errors? For now, the latter...
                uplevel \#0 $options(-opencommand)
            }

            # compute the geometry of the window to pop up, and set
            # it, and force the window manager to take notice
            # (even if it is not presently visible).
            #
            # this isn't strictly necessary if the window is already
            # mapped, but we'll go ahead and set the geometry here
            # since its harmless and *may* actually reset the geometry
            # to something better in some weird case.
            set geometry [::combobox::ComputeGeometry $widgets(this)]
            wm geometry $widgets(dropdown) $geometry
            update idletasks

            # if we are already open, there's nothing else to do
            if {[winfo ismapped $widgets(dropdown)]} {
                return 0
            }

            # save the widget that currently has the focus; we'll restore
            # the focus there when we're done
            set oldFocus [focus]

            # ok, tweak the visual appearance of things and 
            # make the list pop up
            $widgets(button) configure -relief sunken
            wm deiconify $widgets(dropdown) 
            update idletasks
            raise $widgets(dropdown) 

            # force focus to the entry widget so we can handle keypress
            # events for traversal
            focus -force $widgets(entry)

            # select something by default, but only if its an
            # exact match...
            ::combobox::Find $widgets(this) 1

            # save the current grab state for the display containing
            # this widget. We'll restore it when we close the dropdown
            # list
            set status "none"
            set grab [grab current $widgets(this)]
            if {$grab != ""} {set status [grab status $grab]}
            set oldGrab [list $grab $status]
            unset grab status

            # *gasp* do a global grab!!! Mom always told me not to
            # do things like this, but sometimes a man's gotta do
            # what a man's gotta do.
            grab -global $widgets(this)

            # fake the listbox into thinking it has focus. This is 
            # necessary to get scanning initialized properly in the
            # listbox.
            event generate $widgets(listbox) <B1-Enter>

            return 1
        }

        close {
            # if we are already closed, don't do anything...
            if {![winfo ismapped $widgets(dropdown)]} {
                return 0
            }

            # restore the focus and grab, but ignore any errors...
            # we're going to be paranoid and release the grab before
            # trying to set any other grab because we really really
            # really want to make sure the grab is released.
            catch {focus $oldFocus} result
            catch {grab release $widgets(this)}
            catch {
                set status [lindex $oldGrab 1]
                if {$status == "global"} {
                    grab -global [lindex $oldGrab 0]
                } elseif {$status == "local"} {
                    grab [lindex $oldGrab 0]
                }
                unset status
            }

            # hides the listbox
            $widgets(button) configure -relief raised
            wm withdraw $widgets(dropdown) 

            # select the data in the entry widget. Not sure
            # why, other than observation seems to suggest that's
            # what windows widgets do.
            set editable [::combobox::GetBoolean $options(-editable)]
            if {$editable} {
                $widgets(entry) selection range 0 end
                $widgets(button) configure -relief raised
            }


            # magic tcl stuff (see tk.tcl in the distribution 
            # lib directory)
            ::combobox::tkCancelRepeat

            return 1
        }

        cget {
            if {[llength $args] != 1} {
                error "wrong # args: should be $w cget option"
            }
            set opt [::combobox::Canonize $w option [lindex $args 0]]

            if {$opt == "-value"} {
                set result [$widgets(entry) get]
            } else {
                set result $options($opt)
            }
        }

        configure {
            set result [eval ::combobox::Configure {$w} $args]
        }

        default {
            error "bad option \"$command\""
        }
    }

    return $result
}

# ::combobox::Configure --
#
#    Implements the "configure" widget subcommand
#
# Arguments:
#
#    w      widget pathname
#    args   zero or more option/value pairs (or a single option)
#
# Results:
#    
#    Performs typcial "configure" type requests on the widget

proc ::combobox::Configure {w args} {
    variable widgetOptions
    variable defaultEntryCursor

    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options

    if {[llength $args] == 0} {
        # hmmm. User must be wanting all configuration information
        # note that if the value of an array element is of length
        # one it is an alias, which needs to be handled slightly
        # differently
        set results {}
        foreach opt [lsort [array names widgetOptions]] {
            if {[llength $widgetOptions($opt)] == 1} {
                set alias $widgetOptions($opt)
                set optName $widgetOptions($alias)
                lappend results [list $opt $optName]
            } else {
                set optName  [lindex $widgetOptions($opt) 0]
                set optClass [lindex $widgetOptions($opt) 1]
                set default [option get $w $optName $optClass]
                if {[info exists options($opt)]} {
                    lappend results [list $opt $optName $optClass \
                            $default $options($opt)]
                } else {
                    lappend results [list $opt $optName $optClass \
                            $default ""]
                }
            }
        }

        return $results
    }
    
    # one argument means we are looking for configuration
    # information on a single option
    if {[llength $args] == 1} {
        set opt [::combobox::Canonize $w option [lindex $args 0]]

        set optName  [lindex $widgetOptions($opt) 0]
        set optClass [lindex $widgetOptions($opt) 1]
        set default [option get $w $optName $optClass]
        set results [list $opt $optName $optClass \
                $default $options($opt)]
        return $results
    }

    # if we have an odd number of values, bail. 
    if {[expr {[llength $args]%2}] == 1} {
        # hmmm. An odd number of elements in args
        error "value for \"[lindex $args end]\" missing"
    }
    
    # Great. An even number of options. Let's make sure they 
    # are all valid before we do anything. Note that Canonize
    # will generate an error if it finds a bogus option; otherwise
    # it returns the canonical option name
    foreach {name value} $args {
        set name [::combobox::Canonize $w option $name]
        set opts($name) $value
    }

    # process all of the configuration options
    # some (actually, most) options require us to
    # do something, like change the attributes of
    # a widget or two. Here's where we do that...
    #
    # note that the handling of disabledforeground and
    # disabledbackground is a little wonky. First, we have
    # to deal with backwards compatibility (ie: tk 8.3 and below
    # didn't have such options for the entry widget), and
    # we have to deal with the fact we might want to disable
    # the entry widget but use the normal foreground/background
    # for when the combobox is not disabled, but not editable either.

    set updateVisual 0
    foreach option [array names opts] {
        set newValue $opts($option)
        if {[info exists options($option)]} {
            set oldValue $options($option)
        }

        switch -- $option {
            -buttonbackground {
                $widgets(button) configure -background $newValue
            }
            -background {
                set updateVisual 1
                set options($option) $newValue
            }

            -borderwidth {
                $widgets(frame) configure -borderwidth $newValue
                set options($option) $newValue
            }

            -command {
                # nothing else to do...
                set options($option) $newValue
            }

            -commandstate {
                # do some value checking...
                if {$newValue != "normal" && $newValue != "disabled"} {
                    set options($option) $oldValue
                    set message "bad state value \"$newValue\";"
                    append message " must be normal or disabled"
                    error $message
                }
                set options($option) $newValue
            }

            -cursor {
                $widgets(frame) configure -cursor $newValue
                $widgets(entry) configure -cursor $newValue
                $widgets(listbox) configure -cursor $newValue
                set options($option) $newValue
            }

            -disabledforeground {
                set updateVisual 1
                set options($option) $newValue
            }

            -disabledbackground {
                set updateVisual 1
                set options($option) $newValue
            }

            -dropdownwidth {
                set options($option) $newValue
            }

            -editable {
                set updateVisual 1
                if {$newValue} {
                    # it's editable...
                    $widgets(entry) configure -state normal \
                            -cursor $defaultEntryCursor
                } else {
                    $widgets(entry) configure -state disabled \
                            -cursor $options(-cursor)
                }
                set options($option) $newValue
            }

            -elementborderwidth {
                $widgets(button) configure -borderwidth $newValue
                $widgets(vsb) configure -borderwidth $newValue
                $widgets(dropdown) configure -borderwidth $newValue
                set options($option) $newValue
            }

            -font {
                $widgets(entry) configure -font $newValue
                $widgets(listbox) configure -font $newValue
                set options($option) $newValue
            }

            -foreground {
                set updateVisual 1
                set options($option) $newValue
            }

            -height {
                $widgets(listbox) configure -height $newValue
                HandleScrollbar $w
                set options($option) $newValue
            }

            -highlightbackground {
                $widgets(frame) configure -highlightbackground $newValue
                set options($option) $newValue
            }

            -highlightcolor {
                $widgets(frame) configure -highlightcolor $newValue
                set options($option) $newValue
            }

            -highlightthickness {
                $widgets(frame) configure -highlightthickness $newValue
                set options($option) $newValue
            }
    
            -image {
                if {[string length $newValue] > 0} {
                    puts "old button width: [$widgets(button) cget -width]"
                    $widgets(button) configure \
                        -image $newValue \
                        -width [expr {[image width $newValue] + 2}]
                    puts "new button width: [$widgets(button) cget -width]"
    
                } else {
                    $widgets(button) configure -image ::combobox::bimage
                }
                set options($option) $newValue
            }

            -listvar {
                if {[catch {$widgets(listbox) cget -listvar}]} {
                    return -code error \
                        "-listvar not supported with this version of tk"
                }
                $widgets(listbox) configure -listvar $newValue
                set options($option) $newValue
            }

            -maxheight {
                # ComputeGeometry may dork with the actual height
                # of the listbox, so let's undork it
                $widgets(listbox) configure -height $options(-height)
                HandleScrollbar $w
                set options($option) $newValue
            }

            -opencommand {
                # nothing else to do...
                set options($option) $newValue
            }

            -relief {
                $widgets(frame) configure -relief $newValue
                set options($option) $newValue
            }

            -selectbackground {
                $widgets(entry) configure -selectbackground $newValue
                $widgets(listbox) configure -selectbackground $newValue
                set options($option) $newValue
            }

            -selectborderwidth {
                $widgets(entry) configure -selectborderwidth $newValue
                $widgets(listbox) configure -selectborderwidth $newValue
                set options($option) $newValue
            }

            -selectforeground {
                $widgets(entry) configure -selectforeground $newValue
                $widgets(listbox) configure -selectforeground $newValue
                set options($option) $newValue
            }

            -state {
                if {$newValue == "normal"} {
                    set updateVisual 1
                    # it's enabled

                    set editable [::combobox::GetBoolean \
                            $options(-editable)]
                    if {$editable} {
                        $widgets(entry) configure -state normal
                        $widgets(entry) configure -takefocus 1
                    }

                    # note that $widgets(button) is actually a label,
                    # not a button. And being able to disable labels
                    # wasn't possible until tk 8.3. (makes me wonder
                    # why I chose to use a label, but that answer is
                    # lost to antiquity)
                    if {[info patchlevel] >= 8.3} {
                        $widgets(button) configure -state normal
                    }

                } elseif {$newValue == "disabled"}  {
                    set updateVisual 1
                    # it's disabled
                    $widgets(entry) configure -state disabled
                    $widgets(entry) configure -takefocus 0
                    # note that $widgets(button) is actually a label,
                    # not a button. And being able to disable labels
                    # wasn't possible until tk 8.3. (makes me wonder
                    # why I chose to use a label, but that answer is
                    # lost to antiquity)
                    if {$::tcl_version >= 8.3} {
                        $widgets(button) configure -state disabled 
                    }

                } else {
                    set options($option) $oldValue
                    set message "bad state value \"$newValue\";"
                    append message " must be normal or disabled"
                    error $message
                }

                set options($option) $newValue
            }

            -takefocus {
                $widgets(entry) configure -takefocus $newValue
                set options($option) $newValue
            }

            -textvariable {
                $widgets(entry) configure -textvariable $newValue
                set options($option) $newValue
            }

            -value {
                ::combobox::SetValue $widgets(this) $newValue
                set options($option) $newValue
            }

            -width {
                $widgets(entry) configure -width $newValue
                $widgets(listbox) configure -width $newValue
                set options($option) $newValue
            }

            -xscrollcommand {
                $widgets(entry) configure -xscrollcommand $newValue
                set options($option) $newValue
            }
        }

        if {$updateVisual} {UpdateVisualAttributes $w}
    }
}

# ::combobox::UpdateVisualAttributes --
#
# sets the visual attributes (foreground, background mostly) 
# based on the current state of the widget (normal/disabled, 
# editable/non-editable)
#
# why a proc for such a simple thing? Well, in addition to the
# various states of the widget, we also have to consider the 
# version of tk being used -- versions from 8.4 and beyond have
# the notion of disabled foreground/background options for various
# widgets. All of the permutations can get nasty, so we encapsulate
# it all in one spot.
#
# note also that we don't handle all visual attributes here; just
# the ones that depend on the state of the widget. The rest are 
# handled on a case by case basis
#
# Arguments:
#    w   widget pathname
#
# Returns:
#    empty string

proc ::combobox::UpdateVisualAttributes {w} {

    upvar ::combobox::${w}::widgets     widgets
    upvar ::combobox::${w}::options     options

    if {$options(-state) == "normal"} {

        set foreground $options(-foreground)
        set background $options(-background)

    } elseif {$options(-state) == "disabled"} {

        set foreground $options(-disabledforeground)
        set background $options(-disabledbackground)
    }

    $widgets(entry)   configure -foreground $foreground -background $background
    $widgets(listbox) configure -foreground $foreground -background $background
    $widgets(button)  configure -foreground $foreground 
    $widgets(vsb)     configure -background $background -troughcolor $background
    $widgets(frame)   configure -background $background

    # we need to set the disabled colors in case our widget is disabled. 
    # We could actually check for disabled-ness, but we also need to 
    # check whether we're enabled but not editable, in which case the 
    # entry widget is disabled but we still want the enabled colors. It's
    # easier just to set everything and be done with it.
    
    if {$::tcl_version >= 8.4} {
        $widgets(entry) configure \
            -disabledforeground $foreground \
            -disabledbackground $background
        $widgets(button)  configure -disabledforeground $foreground
        $widgets(listbox) configure -disabledforeground $foreground
    }
}

# ::combobox::SetValue --
#
#    sets the value of the combobox and calls the -command, 
#    if defined
#
# Arguments:
#
#    w          widget pathname
#    newValue   the new value of the combobox
#
# Returns
#
#    Empty string

proc ::combobox::SetValue {w newValue} {

    upvar ::combobox::${w}::widgets     widgets
    upvar ::combobox::${w}::options     options
    upvar ::combobox::${w}::ignoreTrace ignoreTrace
    upvar ::combobox::${w}::oldValue    oldValue

    if {[info exists options(-textvariable)] \
            && [string length $options(-textvariable)] > 0} {
        set variable ::$options(-textvariable)
        set $variable $newValue
    } else {
        set oldstate [$widgets(entry) cget -state]
        $widgets(entry) configure -state normal
        $widgets(entry) delete 0 end
        $widgets(entry) insert 0 $newValue
        $widgets(entry) configure -state $oldstate
    }

    # set our internal textvariable; this will cause any public
    # textvariable (ie: defined by the user) to be updated as
    # well
#    set ::combobox::${w}::entryTextVariable $newValue

    # redefine our concept of the "old value". Do it before running
    # any associated command so we can be sure it happens even
    # if the command somehow fails.
    set oldValue $newValue


    # call the associated command. The proc will handle whether or 
    # not to actually call it, and with what args
    CallCommand $w $newValue

    return ""
}

# ::combobox::CallCommand --
#
#   calls the associated command, if any, appending the new
#   value to the command to be called.
#
# Arguments:
#
#    w         widget pathname
#    newValue  the new value of the combobox
#
# Returns
#
#    empty string

proc ::combobox::CallCommand {w newValue} {
    upvar ::combobox::${w}::widgets widgets
    upvar ::combobox::${w}::options options
    
    # call the associated command, if defined and -commandstate is
    # set to "normal"
    if {$options(-commandstate) == "normal" && \
            [string length $options(-command)] > 0} {
        set args [list $widgets(this) $newValue]
        uplevel \#0 $options(-command) $args
    }
}


# ::combobox::GetBoolean --
#
#     returns the value of a (presumably) boolean string (ie: it should
#     do the right thing if the string is "yes", "no", "true", 1, etc
#
# Arguments:
#
#     value       value to be converted 
#     errorValue  a default value to be returned in case of an error
#
# Returns:
#
#     a 1 or zero, or the value of errorValue if the string isn't
#     a proper boolean value

proc ::combobox::GetBoolean {value {errorValue 1}} {
    if {[catch {expr {([string trim $value])?1:0}} res]} {
        return $errorValue
    } else {
        return $res
    }
}

# ::combobox::convert --
#
#     public routine to convert %x, %y and %W binding substitutions.
#     Given an x, y and or %W value relative to a given widget, this
#     routine will convert the values to be relative to the combobox
#     widget. For example, it could be used in a binding like this:
#
#     bind .combobox <blah> {doSomething [::combobox::convert %W -x %x]}
#
#     Note that this procedure is *not* exported, but is intended for
#     public use. It is not exported because the name could easily 
#     clash with existing commands. 
#
# Arguments:
#
#     w     a widget path; typically the actual result of a %W 
#           substitution in a binding. It should be either a
#           combobox widget or one of its subwidgets
#
#     args  should one or more of the following arguments or 
#           pairs of arguments:
#
#           -x <x>      will convert the value <x>; typically <x> will
#                       be the result of a %x substitution
#           -y <y>      will convert the value <y>; typically <y> will
#                       be the result of a %y substitution
#           -W (or -w)  will return the name of the combobox widget
#                       which is the parent of $w
#
# Returns:
#
#     a list of the requested values. For example, a single -w will
#     result in a list of one items, the name of the combobox widget.
#     Supplying "-x 10 -y 20 -W" (in any order) will return a list of
#     three values: the converted x and y values, and the name of 
#     the combobox widget.

proc ::combobox::convert {w args} {
    set result {}
    if {![winfo exists $w]} {
        error "window \"$w\" doesn't exist"
    }

    while {[llength $args] > 0} {
        set option [lindex $args 0]
        set args [lrange $args 1 end]

        switch -exact -- $option {
            -x {
                set value [lindex $args 0]
                set args [lrange $args 1 end]
                set win $w
                while {[winfo class $win] != "Combobox"} {
                    incr value [winfo x $win]
                    set win [winfo parent $win]
                    if {$win == "."} break
                }
                lappend result $value
            }

            -y {
                set value [lindex $args 0]
                set args [lrange $args 1 end]
                set win $w
                while {[winfo class $win] != "Combobox"} {
                    incr value [winfo y $win]
                    set win [winfo parent $win]
                    if {$win == "."} break
                }
                lappend result $value
            }

            -w -
            -W {
                set win $w
                while {[winfo class $win] != "Combobox"} {
                    set win [winfo parent $win]
                    if {$win == "."} break;
                }
                lappend result $win
            }
        }
    }
    return $result
}

# ::combobox::Canonize --
#
#    takes a (possibly abbreviated) option or command name and either 
#    returns the canonical name or an error
#
# Arguments:
#
#    w        widget pathname
#    object   type of object to canonize; must be one of "command",
#             "option", "scan command" or "list command"
#    opt      the option (or command) to be canonized
#
# Returns:
#
#    Returns either the canonical form of an option or command,
#    or raises an error if the option or command is unknown or
#    ambiguous.

proc ::combobox::Canonize {w object opt} {
    variable widgetOptions
    variable columnOptions
    variable widgetCommands
    variable listCommands
    variable scanCommands

    switch $object {
        command {
            if {[lsearch -exact $widgetCommands $opt] >= 0} {
                return $opt
            }

            # command names aren't stored in an array, and there
            # isn't a way to get all the matches in a list, so
            # we'll stuff the commands in a temporary array so
            # we can use [array names]
            set list $widgetCommands
            foreach element $list {
                set tmp($element) ""
            }
            set matches [array names tmp ${opt}*]
        }

        {list command} {
            if {[lsearch -exact $listCommands $opt] >= 0} {
                return $opt
            }

            # command names aren't stored in an array, and there
            # isn't a way to get all the matches in a list, so
            # we'll stuff the commands in a temporary array so
            # we can use [array names]
            set list $listCommands
            foreach element $list {
                set tmp($element) ""
            }
            set matches [array names tmp ${opt}*]
        }

        {scan command} {
            if {[lsearch -exact $scanCommands $opt] >= 0} {
                return $opt
            }

            # command names aren't stored in an array, and there
            # isn't a way to get all the matches in a list, so
            # we'll stuff the commands in a temporary array so
            # we can use [array names]
            set list $scanCommands
            foreach element $list {
                set tmp($element) ""
            }
            set matches [array names tmp ${opt}*]
        }

        option {
            if {[info exists widgetOptions($opt)] \
                    && [llength $widgetOptions($opt)] == 2} {
                return $opt
            }
            set list [array names widgetOptions]
            set matches [array names widgetOptions ${opt}*]
        }
    }

    if {[llength $matches] == 0} {
        set choices [HumanizeList $list]
        error "unknown $object \"$opt\"; must be one of $choices"

    } elseif {[llength $matches] == 1} {
        set opt [lindex $matches 0]

        # deal with option aliases
        switch $object {
            option {
                set opt [lindex $matches 0]
                if {[llength $widgetOptions($opt)] == 1} {
                    set opt $widgetOptions($opt)
                }
            }
        }

        return $opt

    } else {
        set choices [HumanizeList $list]
        error "ambiguous $object \"$opt\"; must be one of $choices"
    }
}

# ::combobox::HumanizeList --
#
#    Returns a human-readable form of a list by separating items
#    by columns, but separating the last two elements with "or"
#    (eg: foo, bar or baz)
#
# Arguments:
#
#    list    a valid tcl list
#
# Results:
#
#    A string which as all of the elements joined with ", " or 
#    the word " or "

proc ::combobox::HumanizeList {list} {

    if {[llength $list] == 1} {
        return [lindex $list 0]
    } else {
        set list [lsort $list]
        set secondToLast [expr {[llength $list] -2}]
        set most [lrange $list 0 $secondToLast]
        set last [lindex $list end]

        return "[join $most {, }] or $last"
    }
}

# This is some backwards-compatibility code to handle TIP 44
# (http://purl.org/tcl/tip/44.html). For all private tk commands
# used by this widget, we'll make duplicates of the procs in the
# combobox namespace. 
#
# I'm not entirely convinced this is the right thing to do. I probably
# shouldn't even be using the private commands. Then again, maybe the
# private commands really should be public. Oh well; it works so it
# must be OK...
foreach command {TabToWindow CancelRepeat ListboxUpDown} {
    if {[llength [info commands ::combobox::tk$command]] == 1} break;

    set tmp [info commands tk$command]
    set proc ::combobox::tk$command
    if {[llength [info commands tk$command]] == 1} {
        set command [namespace which [lindex $tmp 0]]
        proc $proc {args} "uplevel $command \$args"
    } else {
        if {[llength [info commands ::tk::$command]] == 1} {
            proc $proc {args} "uplevel ::tk::$command \$args"
        }
    }
}

# end of combobox.tcl

######################################################################
# icon image data.
######################################################################
image create bitmap delta48 -data {
  #define delta48_width 48
  #define delta48_height 48
  static char delta48_bits[] = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x80, 0x13, 0x00, 0x00,
  0x00, 0x00, 0xc0, 0x10, 0x00, 0x00, 0x00, 0x00, 0x40, 0x08, 0x00, 0x00,
  0x00, 0x00, 0x20, 0x08, 0x00, 0x00, 0x00, 0x00, 0x30, 0x0c, 0x00, 0x00,
  0x00, 0x00, 0x10, 0x04, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x0e, 0x00, 0x00,
  0x00, 0x00, 0x04, 0x1b, 0x00, 0x00, 0x00, 0x00, 0x06, 0x1b, 0x00, 0x00,
  0x00, 0x00, 0x02, 0x33, 0x00, 0x00, 0x00, 0x00, 0x03, 0x2e, 0x00, 0x00,
  0x00, 0x00, 0x11, 0x6c, 0x00, 0x00, 0x00, 0x00, 0x11, 0x68, 0x00, 0x00,
  0x00, 0x80, 0x10, 0xc8, 0x00, 0x00, 0x00, 0x80, 0x10, 0xa8, 0x01, 0x00,
  0x00, 0x80, 0x08, 0x08, 0x01, 0x00, 0x00, 0x80, 0x08, 0xac, 0x03, 0x00,
  0x00, 0x80, 0x09, 0x06, 0x02, 0x00, 0x00, 0xc0, 0x09, 0xaa, 0x06, 0x00,
  0x00, 0x40, 0x09, 0x01, 0x04, 0x00, 0x00, 0xe0, 0x93, 0xae, 0x0a, 0x00,
  0x00, 0x30, 0x92, 0x06, 0x18, 0x00, 0x00, 0xb0, 0x92, 0xad, 0x1a, 0x00,
  0x00, 0x18, 0x53, 0x04, 0x30, 0x00, 0x00, 0xa8, 0x11, 0xac, 0x2a, 0x00,
  0x00, 0x0c, 0x12, 0x04, 0x60, 0x00, 0x00, 0xac, 0x12, 0xac, 0x6a, 0x00,
  0x00, 0x02, 0x14, 0x04, 0x80, 0x00, 0x00, 0xab, 0x0a, 0xae, 0xaa, 0x01,
  0x00, 0x01, 0x28, 0x02, 0x00, 0x01, 0x80, 0xab, 0x3a, 0xaf, 0xaa, 0x03,
  0x80, 0x00, 0x70, 0x0c, 0x00, 0x02, 0xc0, 0xaa, 0x5a, 0xa8, 0xaa, 0x06,
  0x40, 0x00, 0xa0, 0x08, 0x00, 0x0c, 0xa0, 0xaa, 0xea, 0xac, 0xaa, 0x0a,
  0x30, 0x00, 0x80, 0x05, 0x00, 0x18, 0xb0, 0xaa, 0xaa, 0xab, 0xaa, 0x1a,
  0x08, 0x00, 0x00, 0x04, 0x00, 0x30, 0xfc, 0xff, 0xff, 0xbe, 0xff, 0x7f,
  0xfc, 0xff, 0xff, 0xbd, 0xff, 0x7f, 0x00, 0x00, 0x00, 0x70, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  }
}

image create photo deltaGif -format gif -data {
R0lGODlhMAAwAOcAAAIyRsQWGJ4eIIYrK0aK4jZ2yXIkKOJ2hhpKgqZ+isJW
Y1IuNpBebKJifi5qumpKUsQ0OE4ySkJiip5SXoZWXnpWahZGfp5GUideptrG
yopSWtpOVnp+kiY6XiVaoIJGTphKVjxMcJ45Pso6PiFWmgYyZt5SWroeHrau
tmaClu4eJsoeHlJmhts+Q3JCSi5Kepo2PpKGkiBSlqIiIuaWllY6QrQmJmJy
kjp6zk6W9h5Ojx4yPh1Cc5YeIspaatoiJvJcaE5eekpihpR2gMIiItteZz6C
2nZqfuY2Pu9MVG5aYq4iIutGTqJOXkY+SuKKkgc6c4YyMkqO6cZCUgI2Vipi
rV4iInI2Pq5yepIiIsIrK6ErLBpKhrY+RsozM052uhIuTsJqhrJebu5UWLRM
WopWbr4iIl5mjtpCRE6G2u5eatVibqwcHjZGVoAoKr52ftoSEmo2SsYmKlaS
5pYiItZWbrpucppialKO3m5GUscqKyBGfudKUc8yMyZKeh46YiZGag42Ts46
PjZyxKcqK+JCSMpCSu7Gxh5Skp5CRtU+Px9OiUI+YropKUSC2ppOWm4eHpIp
KbV/h85qcsYuLnZOYospKoZmcqlaY5ZWWnZiZuYoLl5Scm4qLlSW8jZCXpgm
KIJCStpibAI2TrYuMK4pKp4yNtpaZr58hk6O5t1GSNE2N85CRopSciJKfuY+
Rgo2UuJOWj5+1CpmsLJkcn4uNi5QgEWG4ZI+RBpGgNU6PEZOcpAyNL5OWoBQ
ZJJKZqpSYi5eovKWnmpaflea+CZSjjFuvU2K3couMLpkcnIqLuJaXnpyhupa
Zj5Gar4uLpIuMo4uLuFLT84qKk6S7JZZZ6klJ/ZKUuJmdjZGah5WorUqKqY2
QudOUpkqK4ZabnJaegI2XiNGdspqguJGS7IaHuJeZuJaYlKS7SpGbkyK5Op0
fN5CRY5mctZESDZShtZmbhpKir4qKi5mtAIyUtpGUuBYbh5KgIJ6im5+ltIe
IlpmgnpCSuIiJgY4Tv///yH5BAEKAP8ALAAAAAAwADAAAAj+AP8JHEiwoMGD
CBMqXJgwFMOHEA0usIJpSMSLC10oMzCAFsaPBx/0yOJmwBuQKAXmccNmgBte
WFKCrFFLgIABlkRckvmRwoByloJO4PmxUxY2lgww+kI04hVILGdAiyPDGLWm
DD8M2FoOFLcLw4LJIoZVIS6c0U54AwWjQrFZUsoi1MDLUqQlS7ZYYxDiHQkc
6OQafBQtkrcA1rZ0wQQi2b0q6gQXTBTJMBxr1kpZs1FHCIlBniQLZCDCmzdr
AQiV2rbtmah8izDcCiwZk6ktW2ysWL1NHqU1N7ggchBXMjDchIiY2dZIXiNk
ayRwiecBB1m5+MhsUa2vUXM9lFb+jVuEQDhkwczIqN72Q54WLZT0CEJ1LxeC
eCQK0MZ6ptfqRv3IAx4llLByBAL2caGDbGVRw4ICpDQihwrwUYIMBJeIg8CG
uXBRVQ5YGWELLRA0oscmyCDjBSXV8MAhhzp4YAQeRKEzzyKVGKLFNJtYiEwy
QQCSzYZECjfPVTJ5IgsJ8YSggBd9IOGFF2vEkIIkkyBo34b4yZKKTARUoUMu
PHyzQR+veLGKKKjYMQI2RCJYng5V3JKSFIOQwEUuEfCjSB98rLKKIl4go0sR
RNqX4GfFfeQIBotwcQ8IpOixyhiCrqKLLoogumWiCzoCEjUOILInAmW404cX
mG7KqS7+9myp6IbCOfDlRcfI4kGkG3JyiqBJbKpICy3oYk6csk7ngSzHXCTF
LDqcmosrDUjThzRocKoIGvU88WKcc84SGUTEFMDkt9mEUY8qfCiyLTvL7APu
rPfldx1Dt2Aw5ry7iMJOEu/qQoO89M6qIIMMoWOMDNK+mAs4zSTBDhrsrLOP
OOJ8imx5Ve2XkBEeRJtoos6okQQ57MQiTDoJSJKOnDDTGqMRzSZEzTymahyn
M+e4wwTK6xQRywEvjCxngjrMM+5BqSwZj6ww27eHL7FcQw450rRQCCp7OLxx
l0gadAu0XHzrtTitAMGENFgXMoTZZis4i50GEZNn2RrrjMCzHmXwwUc30sBj
y8h50yrDIHMUlEa+vG589NG/MKGKCRzo/TiCXMR2SxoESWEMIhaELvropIf+
BzdqNMFD6ayLPlyjnuCACBQl1F57OLbnrnsHU/gAhu7A6w4FIjjULIs2UNAz
CgCjNN8888s7Lz0ATtijhD/RQy/9883TA4U2svzjCPLhUGH++einnz4sl4ji
yw6B+KP+/OF8LypRbWgiBjwKVPOJaA+5Ay4yAcACGhAiAQEAOw==
}

image create photo findImg -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAjUAAMIHEiwoEF3
AOQpXMiQIQB3ARC6a6fO3buHAiVWfAcPYwB1AN6pa/fQnUkAIy+qEwiy3bp07DqaPPmS3TqS
Kz/SA8ATQDyB8XoCoJczI4B2F+VBjCjvocyBCNOVS9cxAE+rUqliRHhznbunEY96dbl15kyC
Zs8OrDgzJ1uTRVnSYzcO5M8AQeu6I0oQ5DukAOAJlglPJVR5gBMifNjUqTyoAM6NK1f1auTJ
YDuuOxdTKM/NneGFHVkRLEKKE0GeFGzRdODWMhd7Xipb6FKDuAsGBAA7
}

image create photo centerDiffsImg -format gif -data {
R0lGODlhFAAUAPcAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAAAiUAAMIHBjAHYCD
ANwRHHjOncOHBgkRSgjRYUOEGAEYMpQRoUMA/8SJFGdwY0JyKFFSBGCuZcuSHN25bLmyo0aO
Nj+GJAkg0caNiU6q/DjToE9DQWW6rNkxUdCcBneONHhy5FCDM106zErzo82vB3XuTEm27Equ
aJd6BQsVpFSRZcmeTYuWKduM7hpW3Lv33MK/gAUGBAA7
}

image create photo firstDiffImg -format gif -data {
R0lGODlhFAAUAPcAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAAAiUAAMIdFevoMGD
Bd0JXBig3j9ChAxJnDixHkOBDilqlGjxIkGEIBVevHjOnbtzI1MKLAkAwEmVJN0BIKTIJUqY
AVgS+neo5kuVOv9J7Gkzpc5BFIn+XHg06SGlN1fKbDlTYiKqRRmWNFnV0FWTS7XqtGoz6six
XrMClRkxbdizbMm+jQngUKK7ao1OxTo3JliTZgUGBAA7
}

image create photo prevDiffImg -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAiGAAMIHCjwnDt3
5wgqLHjQHQBChgwlAtAw4cIABh9GnIjwIsOH/yIeUkTR4sWMECWW9DgQJcmOJx0SGhRR5KGR
Kxei3JjT406VMH06BECUaFCWGXsilfkP51GCKGnWdGryY9GUE4s+xfiT47mqCrsq1SmT51ao
ZYGCDevwUKK3Y8k2PLg2IAA7
}

image create photo nextDiffImg -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAiGAAMIHHjOncGD
5wYqVFgQACFDhhIBcJdwIUN3DgsdUjSxokWBDR9G7PixIYCTIiWeJGmx4T9ChA6x/BggJESJ
FGnWtDmSoseLGSFC3DizJMaiNE2uRLrQ5U2mQFNCJYhRak6dPHH+vGjQ4VOETasWEmrokFmO
V6OOLYt2a1iHbXWGTbswIAA7
}

image create photo lastDiffImg -format gif -data {
R0lGODlhFAAUAPcAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAAAiTAAMIHHjOncGD
5wYqVFgQgMOH7hIuZOgOwD9ChA4BiDiRokVDhhJtlNgxQENCIEVyLGmyIsqQI1meO5lyJEmK
BgG8VGnwZsuHOmtCvHmyEEiQh5IqiumRkNGjh5auXFgUqVSfTQtFZSrT5VWWHrmCFVhwakl3
9dKqXZvW3cR6F18enVvv7b+5eEHWXYiWrV+3AgMCADs=
}

image create photo rediffImg -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQCrPQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAicAAMIHEiwoMF0
7AD0euVKl8OHrhjqAgDvnDsAGDOmG2jR3TmDIAVaxFiRoMJXKF/1ypgR5UqPIWOCTIfQnc2b
ABpS/Bgg3cmUQIOqBHBxIUpYADYKLEqUp8ynUKMatFgy5LmrWEdOrDoQIcuvrnSWPJfQqFCg
YhPCAtqrrduUL8/9fIWUJs2LQ2EGmFt34MWmBNPdvKlUquEAAQEAOw==
}

image create photo markSetImg -format gif -data {
R0lGODlhFAAUAPcAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1Pjisd/UjtHJ
a8O4SL2qJcWqAK+SAJN6AGJiAEpKADIyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAAAiZAAMIHEhQoLqD
CAsqFAigIQB3Dd0tNKjOXSxXrmABWBABgLqCByECuAir5EYJHimKvOgqFqxXrzZ2lBhgJUaY
LV/GOpkSIqybOF3ClPlQIEShMF/lfLVzAcqPRhsKXRqTY1GCFaUy1ckTKkiRGhtapTkxa82u
ExUSJZs2qtOUbQ2ujTsQ4luvbdXNpRtA712+UeEC7ou3YEAAADt=
}

image create photo markClearImg -format gif -data {
R0lGODlhFAAUAPcAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1Pjisd/UjtHJ
a8O4SL2qJcWqAK+SAJN6AGJiAEpKADIyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAAAiwAAMIHEhQoLqD
CAsCWKhwIbyFANwNXBiD4UF3sVw9rLhQXQCKNTguzLgxZMePMWqo5OgqVkmVNwAIXHhDpUl3
7gCkhMkwJ02bHHfWiCkzQM5YP1cKJepRoM+kNoculEhQXc6cNW3GzNm0oFWdUSviLDgRbFST
RRsuzYpWrVaoHMsujYgVKMOPUYkCWPCQbY2iP/UuiACgr9S0NDvulQBAXd+7ZYv6bPowLdmB
By8LDAgAOw==
}

image create photo mergeChoice1Img -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAiIAAMIHEiwYMFz
7gAQ+meoIaGHECEeAuDuoDt35wxqFIgQAMWMGzkmVHRooseTKD1WPAgy5MCOhAZRvEizJsaR
hxrq3LkzEcWXIz+eG0qUqMujSJMixJg0AEyhRYuKVDjIUMqrMxUy5MnVkM+bAEgaOpSorNmz
X6eSnGmzZkunCT825fh2btKAADt=
}

image create photo mergeChoice2Img -format gif -data {
R0lGODdhFAAUAPf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8P/w1P/isf/Ujv/G
a/+4SP+qJf+qANySALl6AJZiAHNKAFAyAP/j1P/Hsf+rjv+Pa/9zSP9XJf9VANxJALk9AJYx
AHMlAFAZAP/U1P+xsf+Ojv9ra/9ISP8lJf4AANwAALkAAJYAAHMAAFAAAP/U4/+xx/+Oq/9r
j/9Ic/8lV/8AVdwASbkAPZYAMXMAJVAAGf/U8P+x4v+O1P9rxv9IuP8lqv8AqtwAkrkAepYA
YnMASlAAMv/U//+x//+O//9r//9I//8l//4A/twA3LkAuZYAlnMAc1AAUPDU/+Kx/9SO/8Zr
/7hI/6ol/6oA/5IA3HoAuWIAlkoAczIAUOPU/8ex/6uO/49r/3NI/1cl/1UA/0kA3D0AuTEA
liUAcxkAUNTU/7Gx/46O/2tr/0hI/yUl/wAA/gAA3AAAuQAAlgAAcwAAUNTj/7HH/46r/2uP
/0hz/yVX/wBV/wBJ3AA9uQAxlgAlcwAZUNTw/7Hi/47U/2vG/0i4/yWq/wCq/wCS3AB6uQBi
lgBKcwAyUNT//7H//47//2v//0j//yX//wD+/gDc3AC5uQCWlgBzcwBQUNT/8LH/4o7/1Gv/
xkj/uCX/qgD/qgDckgC5egCWYgBzSgBQMtT/47H/x47/q2v/j0j/cyX/VwD/VQDcSQC5PQCW
MQBzJQBQGdT/1LH/sY7/jmv/a0j/SCX/JQD+AADcAAC5AACWAABzAABQAOP/1Mf/sav/jo//
a3P/SFf/JVX/AEncAD25ADGWACVzABlQAPD/1OL/sdT/jsb/a7j/SKr/Jar/AJLcAHq5AGKW
AEpzADJQAP//1P//sf//jv//a///SP//Jf7+ANzcALm5AJaWAHNzAFBQAPLy8ubm5tra2s7O
zsLCwra2tqqqqp6enpKSkoaGhnp6em5ubmJiYlZWVkpKSj4+PjIyMiYmJhoaGg4ODv/78KCg
pICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEAAAEALAAAAAAUABQAQAiNAAMIHEiwYEF3
AP79GzSIkMOHhAwZKkQIgLtzBguec3cxo8eNACxiHIgwpMmTIQ8dUiTSo8aRBDdynEkTIcWW
ARBGlMizJ8+VFgOcG0q0KEKWHV0qXcp0qUyYA4tKBVkxaU6UWAFMrIoR4SCfYCXe5AjgUKKz
aNMeMgT0osyaNMsihfqxpNWmQ5s2DQgAOw==
}

image create photo mergeChoice12Img -format gif -data {
R0lGODlhFAAUAPMHAAAAAAB6uQCS3CWq/0i4/47U/7Hi/////729vQAAAAAAAAAAAAAAAAAAAAAA
AAAAACH5BAEAAAgALAAAAAAUABQAAAT+ECGEECgAIYQQggghhBBCCIFiAEQIIYQQQgghhCACxRAA
AAAAAAABAAghUA4hpBRYSimllAEQAuVAQgghhBBCCCECAoRAGIQQQgghkBBCiAAIIRAGgUMIIYQQ
QggBEEQIgTAGAAAAACAAAACEEEIgDAARQgghhBBCCCGIEAIBIIQQQghBhBBCCCGEEEIIIgQKQAgh
hBBCECGEEEIImAIQggghAAAAAAAAAATEFIAQQmCUUmAppZRCCDkFIAQREIQQQgghhBBIyCkAISAI
IYRAQgghhJARAEIACiGEEEIIIQYZMACEEAAAAAAAgACAMQJACCGEEEQIIYQQAiMAhCAPQgghhBBC
CCEEQQAIIYQiADs=
}

image create photo mergeChoice21Img -format gif -data {
R0lGODlhFAAUAPMHAAAAAAB6uQCS3CWq/0i4/47U/7Hi/////729vQAAAAAAAAAAAAAAAAAAAAAA
AAAAACH5BAEAAAgALAAAAAAUABQAAAT+ECGEEEIIIYRAgQAhhBBCCCGEEEQIIWAKQAghBCAAAAAA
AACAmAIBQgiBUUoppRRYCiHkFIAQAoJAQgghhBBCCDkFAoSAIIQQQgghkBBCRgAIASGEgEIIIYQY
ZASAEEQAAAAAAAAAMOAIACGEEEIIIQQRQgiMABBCCCGIEEIIIYQQCABBhBBCCCEECkAIIoQQQggh
hBBCEBQDEEIIIYQQggghhEAxBAAAAAQAAAAAQgiUQyAhpZRSSillAAQRKIcQQgghhBBICBEAIRAG
IYRAQgghhBAiAEIIgjDIEEIIIYQQUAiAEEIgjAEAgAAAAAAAACGEEARhAIQQQgghhCAPQgghhEAA
CCEEEUIIIYQiADs=
}

image create photo splitDiffImg -format gif -data {
R0lGODlhFgAWALMAANnZ2ba2tkpKSp6enmJiYgAAAAC5AACWMQBQAP//////////////////
/////////yH5BAEAAAAALAAAAAAWABYAAASKEMhJaRAD41G7DEQhipjXBYWhqoVgWmBxzEjB
vUAQG/NRuy9diNercXTIJGHYOxR+gcFyOhURfYUQYTAYeUdXI4Cbk63O4Wyl22z3bB22uw2v
oHyIvL5pUFO6X158cGQ6XIeHIoNaR0lJXDI9fT84hpFFdUFRl1hAlTGYN5+cTp44Ul8lOBMZ
rRsRADs=
}

image create photo cmbinDiffImg -format gif -data {
R0lGODlhFgAWAKIAANnZ2ba2tkpKSgAAAJ6engC5AACWMQBQACH5BAEAAAAALAAAAAAWABYA
AAOACLrcEGKQ4OqCowxBbcOFYUgeA4riUCqneGwm8QUZ+spXhCtE7cK5wUgw6YV+u0ckNGg2
C8ehaSmCWqM3hhHF7ZK0wq54lFQODq6DuvvqXHpoZ5Or4XwiL2KgR9+4WT1JfCh1fw9lATR9
dit7YVVAjRFcLytvYVmWLJN+mpcTAAkAOw==
}

image create photo fldrImg -format gif -data {
R0lGODlhFAAWAKIAANnZ2QAAAP/MmZlmMzMzM////////////yH5BAEAAAAALAAAAAAUABYA
AANUCLrc/tCFSWdUQeitQ8xcWFnYEG6miAlD67Yn64Hx2RJTXQ84raO83C8U9A1vwiGqpwQy
m5oilCVlWU3YKwsHCLy+YAK3Ky6bzzjCYsSuqC/w+CMBADs=
}

image create photo txtfImg -format gif -data {
R0lGODlhFAAWAKIAANnZ2TMzM////wAAAJmZmf///////////yH5BAEAAAAALAAAAAAUABYA
AANYGLq88BAEQaudIb5pO88R11UiuI3XBXFD61JDEM8nCrtujbcW4RODmq3yC0puuxcFKBwS
jaykUsA8OntQpPTZvFZF2un3iu1ul1kyuuv8Bn7wuE8WkdqNCQA7
}

image create photo ancfImg -format gif -data {
R0lGODlhFAAUAJEAANnZ2QAAAD8/P////yH5BAEAAAAALAAAAAAUABQAAAJKRI6ZwB0N4Xsy
WkpZttp57igdaCgYiVQGuAiAcEaHtsUNjNUjXfYMPFqUZp8MMaTaXDLAFUcYRB2dyovrZSMl
r9yX1yVoDk3kRwEAOw==
}

image create photo nullImg

image create bitmap resize -data {
    #define resize_width 14
    #define resize_height 11
    static char resize_bits[] = {
        0x20, 0x01, 0x30, 0x03, 0x38, 0x07, 0x3c, 0x0f, 0x3e, 0x1f, 0x3f, 0x3f,
        0x3e, 0x1f, 0x3c, 0x0f, 0x38, 0x07, 0x30, 0x03, 0x20, 0x01
    }
}

image create bitmap arroWu -data {
    #define arroWu_width 29
    #define arroWu_height 15
    static unsigned char arroWu_bits[] = {
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x40,0x00,0x00,
        0x00,0xe0,0x00,0x00, 0x00,0xf0,0x01,0x00, 0x00,0xf8,0x03,0x00,
        0x00,0xfc,0x07,0x00, 0x00,0xfe,0x0f,0x00, 0x00,0xff,0x1f,0x00,
        0x80,0xff,0x3f,0x00, 0xc0,0xff,0x7f,0x00, 0xe0,0xff,0xff,0x00,
        0xf0,0xff,0xff,0x01, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00
    }
}

image create bitmap arroWd -data {
    #define arroWd_width 29
    #define arroWd_height 15
    static unsigned char arroWd_bits[] = {
        0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00, 0xf0,0xff,0xff,0x01,
        0xe0,0xff,0xff,0x00, 0xc0,0xff,0x7f,0x00, 0x80,0xff,0x3f,0x00,
        0x00,0xff,0x1f,0x00, 0x00,0xfe,0x0f,0x00, 0x00,0xfc,0x07,0x00,
        0x00,0xf8,0x03,0x00, 0x00,0xf0,0x01,0x00, 0x00,0xe0,0x00,0x00,
        0x00,0x40,0x00,0x00, 0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00
    }
}

# Tooltip popups

#
# tooltips version 0.1
# Paul Boyer
# Science Applications International Corp.
#
# MODIFIED (for TkDiff)
# 31Jul2018  mpm: will UN-bind if setting to an empty string

##############################
# set_tooltips gets a button's name and the tooltip string as
# arguments and creates the proper bindings for entering
# and leaving the button
##############################
proc set_tooltips {widget name} {
    global g

    if {$name == {}} {
        bind $widget <Enter> {}
        bind $widget <Leave> {}
        bind $widget <Button-1> {}
        return
    }

    bind $widget <Enter> "
    catch { after 500 { internal_tooltips_PopUp %W $name } }  g(tooltip_id)
  "
    bind $widget <Leave> "internal_tooltips_PopDown"
    bind $widget <Button-1> "internal_tooltips_PopDown"
}

##############################
# internal_tooltips_PopUp is used to activate the tooltip window
##############################
proc internal_tooltips_PopUp {wid name} {
    global g w

    # get rid of other existing tooltips
    catch {destroy .tooltips_wind}

    toplevel .tooltips_wind -class ToolTip
    set size_changed 0
    set bg [option get .tooltips_wind background background]
    set fg [option get .tooltips_wind foreground foreground]

    # get the cursor position
    set X [winfo pointerx $wid]
    set Y [winfo pointery $wid]

    # add a slight offset to make tooltips fall below cursor
    set Y [expr {$Y + 20}]

    # Now pop up the new widgetLabel
    wm overrideredirect .tooltips_wind 1
    wm geometry .tooltips_wind +$X+$Y
    label .tooltips_wind.l -text $name -border 2 -relief raised \
      -background $bg -foreground $fg
    pack .tooltips_wind.l

    # make invisible
    wm withdraw .tooltips_wind
    update idletasks

    # adjust for bottom of screen
    if {($Y + [winfo reqheight .tooltips_wind]) > [winfo screenheight $w(tw)]} {
        set Y [expr {$Y - [winfo reqheight .tooltips_wind] - 25}]
        set size_changed 1
    }
    # adjust for right border of screen
    if {($X + [winfo reqwidth .tooltips_wind]) > [winfo screenwidth $w(tw)]} {
        set X [expr {[winfo screenwidth $w(tw)] - [winfo reqwidth .tooltips_wind]}]
        set size_changed 1
    }
    # reset position
    if {$size_changed == 1} {
        wm geometry .tooltips_wind +$X+$Y
    }
    # make visible
    wm deiconify .tooltips_wind

    # make tooltip dissappear after 5 sec
    set g(tooltip_id) [after 5000 { internal_tooltips_PopDown }]
}

proc internal_tooltips_PopDown {} {
    global g

    if { [info exists g(tooltip_id)] } {
        after cancel $g(tooltip_id)
    }
    catch {destroy .tooltips_wind}
}

proc get_gtk_params { } {
    global w tk_version

    if {! [llength [auto_execok xrdb]]} {
      return 0
    }
    set pipe [open "|xrdb -q" r]
    while {[gets $pipe ln] > -1} {
      switch -glob -- $ln {
        {\*Toplevel.background:*} {
          #puts $ln
          set bg [lindex $ln 1]
        }
        {\*Toplevel.foreground:*} {
          #puts $ln
          set fg [lindex $ln 1]
        }
        {\*Text.background:*} {
          #puts $ln
          set textbg [lindex $ln 1]
        }
        {\*Text.foreground:*} {
          #puts $ln
          set textfg [lindex $ln 1]
        }
        {\*Text.selectBackground:*} {
          #puts $ln
          set hlbg [lindex $ln 1]
        }
        {\*Text.selectForeground:*} {
          #puts $ln
        set hlfg [lindex $ln 1]
        }
      }
    }
    close $pipe

    if {! [info exists bg] || ! [info exists fg]} {
        return 0
    }
    set w(selcolor) $hlbg
    option add *Entry.Background $textbg
    option add *Entry.Foreground $textfg
    option add *Entry.selectBackground $hlbg
    option add *Entry.selectForeground $hlfg
    option add *Entry.readonlyBackground $bg
    option add *Listbox.background $textbg
    option add *Listbox.selectBackground $hlbg
    option add *Listbox.selectForeground $hlfg
    option add *Text.Background $textbg
    option add *Text.Foreground $textfg
    option add *Text.selectBackground $hlbg
    option add *Text.selectForeground $hlfg
    # Menu checkboxes
    if {$tk_version >= 8.5} {
       option add *Menu.selectColor $fg
       option add *Checkbutton.selectColor ""
       option add *Radiobutton.selectColor ""
    } else {
       option add *selectColor $w(selcolor)
    }

    return 1
}

proc get_cde_params {} {
    global w tk_version

    # Set defaults for all the necessary things
    set bg [option get . background background]
    set fg [option get . foreground foreground]
    set guifont [option get . buttonFontList buttonFontList]
    set txtfont [option get . FontSet FontSet]
    set listfont [option get . textFontList textFontList]

    set textbg white
    set textfg black

    # If any of these aren't set, I don't think we're in CDE after all
    if {![string length $fg]} { return 0 }
    if {![string length $bg]} { return 0 }
    if {![string length $guifont]} {
      # For AIX
      set guifont [option get . FontList FontList]
    }
    if {![string length $guifont]} { return 0 }
    if {![string length $txtfont]} { return 0 }

    set guifont [string trimright $guifont ":"]
    set txtfont [string trimright $txtfont ":"]
    set listfont [string trimright $txtfont ":"]
    regsub -- {medium} $txtfont "bold" dlgfont

    # They don't tell us the slightly darker color they use for the
    # scrollbar backgrounds and graphics backgrounds, so we'll make
    # one up.
    set rgb_bg [winfo rgb $w(tw) $bg]
    set shadow [format #%02x%02x%02x [expr {(9*[lindex $rgb_bg 0]) /2560}] \
      [expr {(9*[lindex $rgb_bg 1]) /2560}] [expr {(9*[lindex $rgb_bg 2]) \
      /2560}]]

    # If we can find the user's dt.resources file, we can find out the
    # palette and background/foreground colors
    set fh ""
    set palette ""
    set cur_rsrc ~/.dt/sessions/current/dt.resources
    set hom_rsrc ~/.dt/sessions/home/dt.resources
    if {[IsReadableFile $cur_rsrc] && [IsReadableFile $hom_rsrc]} {
        # Both exist.  Use whichever is newer
        if {[file mtime $cur_rsrc] > [file mtime $hom_rsrc]} {
            if {[catch {open $cur_rsrc r} fh]} {
                set fh ""
            }
        } else {
            if {[catch {open $hom_rsrc r} fh]} {
                set fh ""
            }
        }
    } elseif {[IsReadableFile $cur_rsrc]} {
        if {[catch {open $cur_rsrc r} fh]} {
            set fh ""
        }
    } elseif {[IsReadableFile $hom_rsrc]} {
        if {[catch {open $hom_rsrc r} fh]} {
            set fh ""
        }
    }
    if {[string length $fh]} {
        set palf ""
        while {[gets $fh ln] != -1} {
            regexp "^\\*background:\[ \t]*(.*)\$" $ln nil textbg
            regexp "^\\*foreground:\[ \t]*(.*)\$" $ln nil textfg
            regexp "^\\*0\\*ColorPalette:\[ \t]*(.*)\$" $ln nil palette
            regexp "^Window.Color.Background:\[ \t]*(.*)\$" $ln nil textbg
            regexp "^Window.Color.Foreground:\[ \t]*(.*)\$" $ln nil textfg
        }
        catch {close $fh}
        #
        # If the *0*ColorPalette setting was found above, try to find the
        # indicated file in ~/.dt, $DTHOME, or /usr/dt.
        #
        if {[string length $palette]} {
            foreach dtdir {/usr/dt /etc/dt ~/.dt} {
                # This uses the last palette that we find
                if {[IsReadableFile [file join $dtdir palettes $palette]]} {
                    set palf [file join $dtdir palettes $palette]
                }
            }
            # debug-info "Using palette $palf"
            if {[string length $palf]} {
                if {![catch {open $palf r} fh]} {
                    gets $fh activetitle
                    gets $fh inactivetitle
                    gets $fh wkspc1
                    gets $fh textbg
                    gets $fh guibg ;#(*.background) - default for tk under cde
                    gets $fh menubg
                    gets $fh wkspc4
                    gets $fh iconbg ;#control panel bg too
                    close $fh

                    option add *Text.highlightColor $wkspc4
                    option add *Dialog.Background $menubg
                    option add *Menu.Background $menubg
                    option add *Menu.activeBackground $menubg
                    option add *Menu.activeForeground $fg
                    option add *Menubutton.Background $menubg
                    option add *Menubutton.activeBackground $menubg
                    option add *Menubutton.activeForeground $fg
                }
            }
        }
    } else {
        puts stderr "Neither ~/.dt/sessions/current/dt.resources nor"
        puts stderr "        ~/.dt/sessions/home/dt.resources was readable"
        puts stderr "   Falling back to plain X"
        return 0
    }

    if {[info exists activetitle]} {
      set hlbg $activetitle
    } else {
      set hlbg "#b24d7a"
    }
    set w(selcolor) $hlbg
    option add *Button.activeBackground $bg
    option add *Button.activeForeground $fg
    option add *Canvas.Background $shadow
    option add *Canvas.Foreground black
    option add *Entry.Background $textbg
    option add *Entry.Foreground $textfg
    option add *Entry.readonlyBackground $bg
    option add *Entry.highlightBackground $bg
    option add *Entry.highlightColor $hlbg
    option add *Listbox.background $textbg
    option add *Listbox.selectBackground $w(selcolor)
    option add *Listbox.selectForeground $fg
    option add *Menu.borderWidth 1
    option add *Scrollbar.activeBackground $bg
    option add *Scrollbar.troughColor $shadow
    option add *Text.Background $textbg
    option add *Text.Foreground $textfg
    option add *Text.highlightBackground $bg

    # Menu checkboxes
    if {$tk_version >= 8.5} {
      # This makes it look like the native CDE checkbox
      option add *Menu.selectColor $fg
      option add *Checkbutton.offRelief sunken
      option add *Checkbutton.selectColor ""
      option add *Radiobutton.selectColor ""
      option add *Checkbutton.activeBackground $bg
      option add *Checkbutton.activeForeground $fg
    } else {
      option add *selectColor $w(selcolor)
    }

    # Suppress the border
    option add *HighlightThickness 0 userDefault
    # Add it back for text and entry widgets
    option add *Text.HighlightThickness 2 userDefault
    option add *Entry.HighlightThickness 1 userDefault

    return 1
}

proc get_aqua_params {} {
    global w

    # Keep everything from being blinding white
    option add *Frame.background #ebebeb userDefault
    option add *Label.background #ebebeb userDefault
    option add *Checkbutton.Background #ebebeb userDefault
    option add *Radiobutton.Background #ebebeb userDefault
    option add *Message.Background #ebebeb userDefault
    # or else there are little white boxes around the button "pill"
    option add *Button.highlightBackground #ebebeb userDefault
    option add *Entry.highlightBackground #ebebeb userDefault
}

###############################################################################

# OPA >>>
if { [file tail [info script]] eq [file tail $::argv0] } {
    # run the main proc
    tkdiff-main
}
# OPA <<<

