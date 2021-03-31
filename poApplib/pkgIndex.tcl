# Module:         poApplib
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Index file for the poApplib package.


proc __poApplibSourcePkgs { dir } {
    rename ::__poApplibSourcePkgs {}
    source [file join $dir poBitmap.tcl]
    source [file join $dir poImgBrowse.tcl]
    source [file join $dir poImgview.tcl]
    source [file join $dir poImgdiff.tcl]
    source [file join $dir poSlideShow.tcl]
    source [file join $dir poDiff.tcl]
    source [file join $dir poPresMgr.tcl]
    source [file join $dir poOffice.tcl]
    source [file join $dir poOfficeAbbreviation.tcl]
    source [file join $dir poOfficeAppointment.tcl]
    source [file join $dir poTkDiff.tcl]
    package provide poApplib 2.6.2
}

if {[catch {package require Tcl 8.5}]} return

# All modules are exported as package poApplib
package ifneeded poApplib 2.6.2 "[list __poApplibSourcePkgs $dir]"
