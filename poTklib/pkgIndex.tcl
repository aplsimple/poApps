# Module:         poTklib
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Index file for the poTklib package.


proc __poTklibSourcePkgs { dir } {
    package require poTcllib
    package require Tk

    rename ::__poTklibSourcePkgs {}
    source -encoding utf-8 [file join $dir poBmpData.tcl]
    source -encoding utf-8 [file join $dir poImgData.tcl]
    source -encoding utf-8 [file join $dir poCombobox.tcl]
    source -encoding utf-8 [file join $dir poMenu.tcl]
    source -encoding utf-8 [file join $dir poLogOpt.tcl]
    source -encoding utf-8 [file join $dir poCalendar.tcl]
    source -encoding utf-8 [file join $dir poWin.tcl]
    source -encoding utf-8 [file join $dir poImgPages.tcl]
    source -encoding utf-8 [file join $dir poWinCapture.tcl]
    source -encoding utf-8 [file join $dir poWinClipboard.tcl]
    source -encoding utf-8 [file join $dir poToolhelp.tcl]
    source -encoding utf-8 [file join $dir poToolbar.tcl]
    source -encoding utf-8 [file join $dir poWinSelect.tcl]
    source -encoding utf-8 [file join $dir poWinDateSelect.tcl]
    source -encoding utf-8 [file join $dir poWinInfo.tcl]
    source -encoding utf-8 [file join $dir poWinRollUp.tcl]
    source -encoding utf-8 [file join $dir poWinPreview.tcl]
    source -encoding utf-8 [file join $dir poTree.tcl]
    source -encoding utf-8 [file join $dir poSoftLogo.tcl]
    source -encoding utf-8 [file join $dir poFileType.tcl]
    source -encoding utf-8 [file join $dir poImgType.tcl]
    source -encoding utf-8 [file join $dir poImgFits.tcl]
    source -encoding utf-8 [file join $dir poImgPdf.tcl]
    source -encoding utf-8 [file join $dir poPhotoUtil.tcl]
    source -encoding utf-8 [file join $dir poImgMisc.tcl]
    source -encoding utf-8 [file join $dir poImgExif.tcl]
    source -encoding utf-8 [file join $dir poImgTig.tcl]
    source -encoding utf-8 [file join $dir poZoomRect.tcl]
    source -encoding utf-8 [file join $dir poSelRect.tcl]
    source -encoding utf-8 [file join $dir poImgPalette.tcl]
    source -encoding utf-8 [file join $dir poFontSel.tcl]
    source -encoding utf-8 [file join $dir poExtProg.tcl]
    source -encoding utf-8 [file join $dir poConsole.tcl]
    source -encoding utf-8 [file join $dir poHistogram.tcl]
    source -encoding utf-8 [file join $dir poColorCount.tcl]
    source -encoding utf-8 [file join $dir poSettings.tcl]
    source -encoding utf-8 [file join $dir poTablelistUtil.tcl]
    source -encoding utf-8 [file join $dir poUkazUtil.tcl]
    source -encoding utf-8 [file join $dir poDial.tcl]
    source -encoding utf-8 [file join $dir poAngleView.tcl]
    source -encoding utf-8 [file join $dir poDragAndDrop.tcl]
    package provide poTklib 2.12.0
}

# All modules are exported as package poTklib
package ifneeded poTklib 2.12.0 "[list __poTklibSourcePkgs $dir]"
