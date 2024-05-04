# Module:         poApplib
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Index file for the poApplib package.


proc __poApplibSourcePkgs { dir } {
    rename ::__poApplibSourcePkgs {}
    source -encoding utf-8 [file join $dir poBitmap.tcl]
    source -encoding utf-8 [file join $dir poImgBrowse.tcl]
    source -encoding utf-8 [file join $dir poImgview.tcl]
    source -encoding utf-8 [file join $dir poImgdiff.tcl]
    source -encoding utf-8 [file join $dir poSlideShow.tcl]
    source -encoding utf-8 [file join $dir poDiff.tcl]
    source -encoding utf-8 [file join $dir poPresMgr.tcl]
    source -encoding utf-8 [file join $dir poOffice.tcl]
    source -encoding utf-8 [file join $dir poOfficeExcel.tcl]
    source -encoding utf-8 [file join $dir poOfficePpt.tcl]
    source -encoding utf-8 [file join $dir poOfficeWord.tcl]
    source -encoding utf-8 [file join $dir poOfficeOutlook.tcl]
    source -encoding utf-8 [file join $dir poOfficeOneNote.tcl]
    source -encoding utf-8 [file join $dir poTkDiff.tcl]
    package provide poApplib 2.12.0
}

# All modules are exported as package poApplib
package ifneeded poApplib 2.12.0 "[list __poApplibSourcePkgs $dir]"
