# Module:         poTklib
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Index file for the poTklib package.


proc __poTklibSourcePkgs { dir } {
    rename ::__poTklibSourcePkgs {}
    source [file join $dir poBmpData.tcl]
    source [file join $dir poImgData.tcl]
    source [file join $dir poCombobox.tcl]
    source [file join $dir poMenu.tcl]
    source [file join $dir poLogOpt.tcl]
    source [file join $dir poCalendar.tcl]
    source [file join $dir poWin.tcl]
    source [file join $dir poWinCapture.tcl]
    source [file join $dir poToolhelp.tcl]
    source [file join $dir poToolbar.tcl]
    source [file join $dir poWinSelect.tcl]
    source [file join $dir poWinDateSelect.tcl]
    source [file join $dir poWinInfo.tcl]
    source [file join $dir poWinRollUp.tcl]
    source [file join $dir poWinPreview.tcl]
    source [file join $dir poTree.tcl]
    source [file join $dir poSoftLogo.tcl]
    source [file join $dir poFileType.tcl]
    source [file join $dir poImgType.tcl]
    source [file join $dir poPhotoUtil.tcl]
    source [file join $dir poImgMisc.tcl]
    source [file join $dir poImgDetail.tcl]
    source [file join $dir poImgTig.tcl]
    source [file join $dir poZoomRect.tcl]
    source [file join $dir poSelRect.tcl]
    source [file join $dir poImgDict.tcl]
    source [file join $dir poImgPalette.tcl]
    source [file join $dir poRawParse.tcl]
    source [file join $dir poFlirParse.tcl]
    source [file join $dir poPpmParse.tcl]
    source [file join $dir poFontSel.tcl]
    source [file join $dir poExtProg.tcl]
    source [file join $dir poConsole.tcl]
    source [file join $dir poHistogram.tcl]
    source [file join $dir poColorCount.tcl]
    source [file join $dir poSettings.tcl]
    source [file join $dir poTablelistUtil.tcl]
    source [file join $dir poUkazUtil.tcl]
    source [file join $dir poDial.tcl]
    source [file join $dir poAngleView.tcl]
    source [file join $dir poDragAndDrop.tcl]
    package provide poTklib 2.6.2
}

if {[catch {package require Tcl 8.5}]} return

# All modules are exported as package poTklib
package ifneeded poTklib 2.6.2 "[list __poTklibSourcePkgs $dir]"
