# Module:         poOffice
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 08 / 07
#
# Distributed under BSD license.
#
# Tool for handling Office programs.

namespace eval poOffice {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init LoadSettings SaveSettings
    namespace export ShowMainWin ParseCommandLine IsOpen
    namespace export GetUsageMsg

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poOffice"  ; # Name of toplevel window
        set sPo(appName) "poOffice"   ; # Name of tool
        set sPo(cfgDir)  ""           ; # Directory containing config files

        set sPo(curFrame) ""

        set sPo(FileType,Office) {
            {"Word files"    ".doc .docx"}
            {"Holiday files" ".hol"}
            {"All files"     "*"}
        }
    }

    # The following functions are used for loading/storing application
    # specific settings in a configuration file.

    proc SetWindowPos { winName x y w h } {
        variable sPo

        set sPo($winName,x) $x
        set sPo($winName,y) $y
        set sPo($winName,w) $w
        set sPo($winName,h) $h
    }

    proc GetWindowPos { winName } {
        variable sPo

        if { [info exists sPo($winName,name)] && \
            [winfo exists $sPo($winName,name)] } {
            scan [wm geometry $sPo($winName,name)] "%dx%d+%d+%d" w h x y
        } else {
            set x $sPo($winName,x)
            set y $sPo($winName,y)
            set w $sPo($winName,w)
            set h $sPo($winName,h)
        }
        return [list $winName $x $y $w $h]
    }

    proc SetCurDirectory { curDir } {
        variable sPo

        set sPo(LastDir) $curDir
    }

    proc GetCurDirectory {} {
        variable sPo

        return [list $sPo(LastDir)]
    }

    proc SetCurFile { curFile } {
        variable sPo

        set sPo(CurFile) $curFile
    }

    proc GetCurFile {} {
        variable sPo

        return [list $sPo(CurFile)]
    }

    proc UpdateMainTitle { { selTool "None" } } {
        variable sPo

        set msg [format "%s - %s" $sPo(appName) $selTool] 
        wm title $sPo(tw) $msg
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc ReadOfficeFile {} {
        variable sPo

        CloseSubWindows
        set fileName [poWinSelect GetValue $sPo(fileCombo)]
        if { [file extension $fileName] eq ".hol" } {
            OpenHolidayFile $fileName
        } elseif { [file extension $fileName] eq ".doc" || \
                   [file extension $fileName] eq ".docx" } {
            OpenWordFile $fileName
        }
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo

        if { [poApps HavePkg "cawt"] } {
            set retVal [catch {Word Open} appId]
            if { $retVal != 0 } {
                set sPo(HaveCawt)  false
                set sPo(CawtState) "disabled"
                set sPo(initStr) "No Office programs available"
            } else {
                set sPo(HaveCawt)  true
                set sPo(CawtState) "normal"
                Word Quit $appId
            }
        } else {
            set sPo(HaveCawt)  false
            set sPo(CawtState) "disabled"
            set sPo(initStr)   "Office utilities not supported for this platform"
        }

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        wm minsize $sPo(tw) 300 200
        set sw [winfo screenwidth $sPo(tw)]
        set sh [winfo screenheight $sPo(tw)]
        wm maxsize $sPo(tw) [expr $sw -20] [expr $sh -40]
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]

        # Create 3 main frames for tool buttons, work frame and status window.
        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both

        ttk::frame $sPo(tw).fr.toolfr -relief groove -padding 1 -borderwidth 1
        ttk::frame $sPo(tw).fr.workfr
        ttk::frame $sPo(tw).fr.statfr -borderwidth 1
        grid $sPo(tw).fr.toolfr -row 0 -column 0 -sticky news
        grid $sPo(tw).fr.workfr -row 1 -column 0 -sticky news
        grid $sPo(tw).fr.statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).fr 1 -weight 1
        grid columnconfigure $sPo(tw).fr 0 -weight 1
     
        set sPo(fileCombo) [poWinSelect CreateFileSelect $sPo(tw).fr.toolfr \
                           [GetCurFile] "open" \
                           [poBmpData::open] "Select Office file ..."]
        poWinSelect Enable $sPo(fileCombo) $sPo(HaveCawt)
        poWinSelect SetFileTypes $sPo(fileCombo) $sPo(FileType,Office)
        bind $sPo(fileCombo) <Key-Return>     "${ns}::ReadOfficeFile"
        bind $sPo(fileCombo) <<FileSelected>> "${ns}::ReadOfficeFile"

        set sPo(workFr) $sPo(tw).fr.workfr.fr
        ttk::frame $sPo(workFr)
        pack $sPo(workFr) -expand 1 -fill both

        # Create menus File, Settings, Window and Help
        set hMenu $sPo(tw).menufr
        menu $hMenu -borderwidth 2 -relief sunken
        if { $::tcl_platform(os) eq "Darwin" } {
            $hMenu add cascade -menu $hMenu.apple -label "poApps"
            set appleMenu $hMenu.apple
            menu $appleMenu -tearoff 0
            poMenu AddCommand $appleMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $appleMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $appleMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        set fileMenu $hMenu.file
        set settMenu $hMenu.sett
        set winMenu  $hMenu.win
        set helpMenu $hMenu.help
        $hMenu add cascade -menu $fileMenu -label File     -underline 0
        $hMenu add cascade -menu $settMenu -label Settings -underline 0
        $hMenu add cascade -menu $winMenu  -label Window   -underline 0
        $hMenu add cascade -menu $helpMenu -label Help     -underline 0

        # Menu File
        menu $fileMenu -tearoff 0

        poMenu AddCommand $fileMenu "Open holiday file ..." "" ${ns}::AskOpenHolidayFile -state $sPo(CawtState)
        poMenu AddCommand $fileMenu "Open Word file ..."    "" ${ns}::AskOpenWordFile    -state $sPo(CawtState)

        $fileMenu add separator
        poMenu AddCommand $fileMenu "Close subwindows" "Ctrl+G" ${ns}::CloseSubWindows
        poMenu AddCommand $fileMenu "Close window"     "Ctrl+W" ${ns}::CloseAppWindow
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }

        bind $sPo(tw) <Control-g> ${ns}::CloseSubWindows
        bind $sPo(tw) <Control-w> ${ns}::CloseAppWindow
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::CloseAppWindow

        # Menu Settings
        set appSettMenu $settMenu.app
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        # TODO No application specific settings yet.
        # $settMenu add cascade -label "Application settings" -menu $appSettMenu
        # menu $appSettMenu -tearoff 0

        $settMenu add cascade -label "Image settings" -menu $imgSettMenu
        menu $imgSettMenu -tearoff 0
        poMenu AddCommand $imgSettMenu "Appearance"          "" [list poSettings ShowImgSettWin "Appearance"          ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Image types"         "" [list poSettings ShowImgSettWin "Image types"         ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Image browser"       "" [list poSettings ShowImgSettWin "Image browser"       ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Slide show"          "" [list poSettings ShowImgSettWin "Slide show"          ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Zoom rectangle"      "" [list poSettings ShowImgSettWin "Zoom rectangle"      ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Selection rectangle" "" [list poSettings ShowImgSettWin "Selection rectangle" ${ns}::SettingsOkCallback]
        poMenu AddCommand $imgSettMenu "Palette"             "" [list poSettings ShowImgSettWin "Palette"             ${ns}::SettingsOkCallback]

        $settMenu add cascade -label "General settings" -menu $genSettMenu
        menu $genSettMenu -tearoff 0
        poMenu AddCommand $genSettMenu "Appearance"   "" [list poSettings ShowGeneralSettWin "Appearance"]
        poMenu AddCommand $genSettMenu "File types"   "" [list poSettings ShowGeneralSettWin "File types"]
        poMenu AddCommand $genSettMenu "Edit/Preview" "" [list poSettings ShowGeneralSettWin "Edit/Preview"]
        poMenu AddCommand $genSettMenu "Logging"      "" [list poSettings ShowGeneralSettWin "Logging"]

        $settMenu add separator
        poMenu AddCheck   $settMenu "Save on exit"       "" poApps::gPo(autosaveOnExit) ""
        poMenu AddCommand $settMenu "View setting files" "" "poApps ViewSettingsDir"
        poMenu AddCommand $settMenu "Save settings"      "" "poApps SaveSettings"

        # Menu Window
        menu $winMenu -tearoff 0
        poMenu AddCommand $winMenu [poApps GetAppDescription main]        "" "poApps StartApp main"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgview]   "" "poApps StartApp poImgview"
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgBrowse] "" "poApps StartApp poImgBrowse"
        poMenu AddCommand $winMenu [poApps GetAppDescription poBitmap]    "" "poApps StartApp poBitmap"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poImgdiff]   "" "poApps StartApp poImgdiff"
        poMenu AddCommand $winMenu [poApps GetAppDescription poDiff]      "" "poApps StartApp poDiff"
        $winMenu add separator
        poMenu AddCommand $winMenu [poApps GetAppDescription poPresMgr]   "" "poApps StartApp poPresMgr"
        poMenu AddCommand $winMenu [poApps GetAppDescription poOffice]    "" "poApps StartApp poOffice" -state disabled

        # Menu Help
        menu $helpMenu -tearoff 0
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $helpMenu "Help ..." "F1" ${ns}::HelpCont
            bind $sPo(tw) <Key-F1> ${ns}::HelpCont
            poMenu AddCommand $helpMenu "About poApps ..."    ""  "poApps HelpProg"
            poMenu AddCommand $helpMenu "About Tcl/Tk ..."    ""  "poApps HelpTcl"
            poMenu AddCommand $helpMenu "About packages ..."  ""  "poApps PkgInfo"
        }

        $sPo(tw) configure -menu $hMenu

        # Create widget for status messages with progress bar.
        set sPo(StatusWidget) [poWin CreateStatusWidget $sPo(tw).fr.statfr]

        UpdateMainTitle
        WriteInfoStr $sPo(initStr)

        # This must be done, after all other widgets have been created and an update
        # has occured. Otherwise the sash position is not correctly set and restored.
        wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                    $sPo(mainWin,w) $sPo(mainWin,h) \
                    $sPo(mainWin,x) $sPo(mainWin,y)]
        if { ! [poApps GetHideWindow] } {
            update
        }

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init all variables stored in the config file with default values.
        SetWindowPos mainWin 10 30 800 500
        SetCurDirectory [pwd]
        SetCurFile "Untitled"

        # Settings from poOfficeAbbreviation.
        SetMinLength      2
        SetMaxLength     -1
        SetShowNumbers   false
        SetAbbrTableName ""
        SetAbbrTableRow  2 
        SetAbbrTableCol  1 

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file found. Using default values."
        }
        set sPo(cfgDir) $cfgDir
    }

    proc PrintCmd { fp cmdName } {
        puts $fp "\n# Set${cmdName} [info args Set${cmdName}]"
        puts $fp "catch {Set${cmdName} [Get${cmdName}]}"
    }

    proc SaveSettings {} {
        variable sPo

        set cfgFile [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetWindowPos [info args SetWindowPos]"
            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"

            # As we can close the window and reopen through the poApps main window
            # store the current window positions also in the namespace variables.
            eval SetWindowPos [GetWindowPos mainWin]

            PrintCmd $fp "CurDirectory"
            PrintCmd $fp "CurFile"

            # Settings from poOfficeAbbreviation.
            PrintCmd $fp "MinLength"
            PrintCmd $fp "MaxLength"
            PrintCmd $fp "ShowNumbers"
            PrintCmd $fp "AbbrTableName"
            PrintCmd $fp "AbbrTableRow"
            PrintCmd $fp "AbbrTableCol"

            close $fp
        }
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\]\n"
        append msg "\n"
        append msg "Tools for handling Office applications.\n"
        append msg "  Import of holiday files into Outlook.\n"
        append msg "  Word count and abbreviation finder for Word documents.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--holidayfile <string>: Use specified holiday file for import.\n"
        append msg "--abbrfile <string>   : Use specified Word file for abbreviation finder.\n"
        append msg "\n"
        return $msg
    }

    proc HelpCont {} {
        variable sPo

        set msg [poApps GetUsageMsg]
        append msg [GetUsageMsg]
        poWin CreateHelpWin $msg "Help for $sPo(appName)"
    }

    proc PrintUsage {} {
        puts [GetUsageMsg]
    }

    proc PrintErrorAndExit { showMsgBox msg } {
        variable sPo

        puts "\nError: $msg"
        PrintUsage
        if { $showMsgBox } {
            tk_messageBox -title "Error" -icon error -message "$msg"
        }
        exit 1
    }

    proc CloseSubWindows {} {
        variable sPo

        if { $sPo(HaveCawt) } {
            DeleteHolidayFrame
            DeleteAbbreviationFrame
            Cawt Destroy
        }
    }

    proc CloseAppWindow {} {
        variable sPo

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        # Delete (potentially open) sub-toplevels of this application.
        CloseSubWindows

        # Delete main toplevel of this application.
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify
    }

    proc ExitApp {} {
        CloseAppWindow
        poApps ExitApp
    }

    proc ParseCommandLine { argList } {
        variable ns
        variable sPo

        set curArg 0
        set fileList [list]
        set holidayFile ""
        set abbrFile    ""

        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "holidayfile" } {
                    incr curArg
                    set holidayFile [lindex $argList $curArg]
                } elseif { $curOpt eq "abbrfile" } {
                    incr curArg
                    set abbrFile [lindex $argList $curArg]
                }
            } else {
                lappend fileList $curParam
            }
            incr curArg
        }
        foreach fileOrDirName $fileList {
            if { [file extension $fileOrDirName] eq ".hol" } {
                set holidayFile $fileOrDirName
            } elseif { [file extension $fileOrDirName] eq ".doc" || \
                       [file extension $fileOrDirName] eq ".docx" } {
                set abbrFile $fileOrDirName
            }
        }
        # Check the specified command line parameters.
        if { $sPo(HaveCawt) } {
            if { $holidayFile ne "" } {
                OpenHolidayFile $holidayFile
            } elseif { $abbrFile ne "" } {
                OpenWordFile $abbrFile
            }
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poOffice Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
