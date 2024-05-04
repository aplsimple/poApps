# Module:         poTcllib
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 07 / 13
#
# Distributed under BSD license.
#
# Index file for the poTcllib package.


proc __poTcllibSourcePkgs { dir } {
    rename ::__poTcllibSourcePkgs {}
    source -encoding utf-8 [file join $dir poLog.tcl]
    source -encoding utf-8 [file join $dir poMisc.tcl]
    source -encoding utf-8 [file join $dir poLock.tcl]
    source -encoding utf-8 [file join $dir poWatch.tcl]
    source -encoding utf-8 [file join $dir poType.tcl]
    source -encoding utf-8 [file join $dir poExec.tcl]
    source -encoding utf-8 [file join $dir poCfgFile.tcl]
    source -encoding utf-8 [file join $dir poMath.tcl]
    source -encoding utf-8 [file join $dir poGeoMath.tcl]
    source -encoding utf-8 [file join $dir poMatrix.tcl]
    source -encoding utf-8 [file join $dir poCsv.tcl]
    package provide poTcllib 2.12.0
}

# All modules are exported as package poTcllib
package ifneeded poTcllib 2.12.0 "[list __poTcllibSourcePkgs $dir]"
