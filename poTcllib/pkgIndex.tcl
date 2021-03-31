# Module:         poTcllib
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 07 / 13
#
# Distributed under BSD license.
#
# Index file for the poTcllib package.


proc __poTcllibSourcePkgs { dir } {
    rename ::__poTcllibSourcePkgs {}
    source [file join $dir poLog.tcl]
    source [file join $dir poMisc.tcl]
    source [file join $dir poLock.tcl]
    source [file join $dir poWatch.tcl]
    source [file join $dir poType.tcl]
    source [file join $dir poExec.tcl]
    source [file join $dir poCfgFile.tcl]
    source [file join $dir poMath.tcl]
    source [file join $dir poGeoMath.tcl]
    source [file join $dir poMatrix.tcl]
    source [file join $dir poCsv.tcl]
    package provide poTcllib 2.6.2
}

if {[catch {package require Tcl 8.5}]} return

# All modules are exported as package poTcllib
package ifneeded poTcllib 2.6.2 "[list __poTcllibSourcePkgs $dir]"
