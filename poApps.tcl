# Module:         poApps
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2013 / 03 / 30
#
# Distributed under BSD license.
#
# The startup scipt for all portable apps.
# See http://www.poSoft.de for screenshots and examples.
#
############################################################################

namespace eval poApps {
    variable ns [namespace current]

    namespace ensemble create

    namespace export InitPackages Init
    namespace export HelpCont HelpProg HelpTcl PkgInfo
    namespace export LoadSettings SaveSettings ViewSettingsDir
    namespace export AddEvents
    namespace export ShowSysNotify
    namespace export StartApp ExitApp GetToplevel
    namespace export GetAppName GetAppDescription GetAppDescriptionList
    namespace export IsValidAppName IsValidAppDescription
    namespace export GetUsageMsg PrintUsage
    namespace export GetImgUsageMsg PrintImgUsage
    namespace export GetFileUsageMsg PrintFileUsage
    namespace export PrintPkgInfo GetCopyright
    namespace export GetBuildInfo GetVersion GetVersionNumber
    namespace export SetVerbose GetVerbose
    namespace export SetBatchMode UseBatchMode
    namespace export SetOverwrite GetOverwrite
    namespace export SetDisplayImage GetDisplayImage
    namespace export SetHideWindow GetHideWindow
    namespace export SetAutosaveOnExit GetAutosaveOnExit
    namespace export SetDefaultAppOnStart GetDefaultAppOnStart
    namespace export SetTheme GetTheme
    namespace export SetConfigVersion GetConfigVersion
    namespace export SetDeveloperMode GetDeveloperMode
    namespace export SetScriptDir GetScriptDir
    namespace export AddFileMatchIgnoreOption IsFileMatchIgnoreOption

    proc WriteRuntimeLibs {} {
        if { ! [info exists ::starkit::topdir] } {
            return
        }
        set dirName [file dirname $::starkit::topdir]
        if { ! [file isdirectory $dirName] } {
            file mkdir $dirName
        }
        set redistributables [file normalize [file join $::starkit::topdir "runtime" "*.dll"]]
        foreach f [glob -nocomplain -- $redistributables] {
            set retVal [catch { file copy -force -- $f $dirName }]
            if { $retVal != 0 } {
                error "Error copying file $f to directory $dirName"
            }
        }
    }

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo
        variable sApps

        set sPo(tw)      ".poApps" ; # Name of toplevel window
        set sPo(appName) "poApps"  ; # Name of main application
        set sPo(cfgDir)  ""        ; # Directory containing config files
        set sPo(lastDir) [pwd]

        # Default values for general batch options.
        SetVerbose      false
        SetBatchMode    false
        SetOverwrite    false
        SetHideWindow   false
        SetDisplayImage true

        # Work around a bug introduced in Tk 8.6.6.
        option add *Tablelist.body.undo 0

        array set sApps {
            "main"          "Main window"
            "poDiff"        "Directory diff"
            "poImgview"     "Image view"
            "poImgdiff"     "Image diff"
            "poImgBrowse"   "Image browser"
            "poBitmap"      "Bitmap editor"
            "tkdiff"        "File diff"
            "poPresMgr"     "Presentation manager"
            "poOffice"      "Office utilities"
        }
    }

    proc GetAppName { { appDescription "" } } {
        variable sPo
        variable sApps

        if { $appDescription eq "" } {
            return $sPo(appName)
        }

        foreach appName [array names sApps] {
            if { $sApps($appName) eq $appDescription } {
                return $appName
            }
        }
        return ""
    }

    proc GetAppDescription { appName } {
        variable sApps

        if { [info exists sApps($appName)] } {
            return $sApps($appName)
        }
        return ""
    }

    proc GetAppDescriptionList {} {
        variable sApps

        foreach appName [array names sApps] {
            lappend descriptionList $sApps($appName)
        }
        return [lsort -dictionary $descriptionList]
    }

    proc IsValidAppName { appName } {
        variable sApps

        if { [lsearch [array names sApps] $appName] < 0 } {
            return false
        } else {
            return true
        }
    }

    proc IsValidAppDescription { appDescription } {
        variable sApps

        if { [lsearch [GetAppDescriptionList] $appDescription] < 0 } {
            return false
        } else {
            return true
        }
    }

    proc InitPackages { args } {
        variable sPo

        foreach pkg $args {
            set retVal [catch {package require $pkg} version]
            set loaded [expr !$retVal]
            dict set sPo(pkgDict) $pkg "version" $version
            dict set sPo(pkgDict) $pkg "loaded"  $loaded
        }
    }

    proc PkgInfo {} {
        variable sPo

        set msg ""
        if { $::tcl_platform(platform) eq "windows" && [info exists ::starkit::topdir] } {
            append msg "\ntkMuPdf and fitsTcl need VisualStudio or gcc runtime libraries."
            append msg "\nUse menu Settings->Image settings->Appearance to install."
        }
        poWin ShowPkgInfo $sPo(pkgDict) $msg
    }

    proc PrintPkgInfo {} {
        variable sPo

        set maxLen 0
        foreach pkg [dict keys $sPo(pkgDict)] {
            if { [string length $pkg] > $maxLen } {
                set maxLen [string length $pkg]
            }
        }
        foreach pkg [lsort -dictionary [dict keys $sPo(pkgDict)]] {
            puts [format "  %-${maxLen}s: %s" $pkg [dict get $sPo(pkgDict) $pkg version]]
        }
    }

    proc SetVerbose { onOff } {
        variable sPo

        set sPo(verbose) $onOff
    }

    proc GetVerbose {} {
        variable sPo

        return $sPo(verbose)
    }

    proc SetBatchMode { onOff } {
        variable sPo

        set sPo(useBatch) $onOff
    }

    proc UseBatchMode {} {
        variable sPo

        return $sPo(useBatch)
    }

    proc SetOverwrite { onOff } {
        variable sPo

        set sPo(overwrite) $onOff
    }

    proc GetOverwrite {} {
        variable sPo

        return $sPo(overwrite)
    }

    proc SetDisplayImage { onOff } {
        variable sPo

        set sPo(displayImage) $onOff
    }

    proc GetDisplayImage {} {
        variable sPo

        return $sPo(displayImage)
    }

    proc SetHideWindow { onOff } {
        variable sPo

        set sPo(hideWindow) $onOff
    }

    proc GetHideWindow {} {
        variable sPo

        return $sPo(hideWindow)
    }

    proc SetWindowPos { winName x y { w -1 } { h -1 } } {
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
            # On Mac the values for w and h are returned as 1, when poApps is called
            # with --imgview and the app is closed from the sub-window.
            if { $w <= 1 } {
                set w $sPo($winName,w)
            }
            if { $h <= 1 } {
                set h $sPo($winName,h)
            }
        } else {
            set x $sPo($winName,x)
            set y $sPo($winName,y)
            set w $sPo($winName,w)
            set h $sPo($winName,h)
        }
        return [list $winName $x $y $w $h]
    }

    proc SetWorkingSet { fileOrDirList } {
        variable sPo

        set sPo(workingSet) [list]
        foreach f $fileOrDirList {
            if { [file isfile $f] || [file isdirectory $f] } {
                lappend sPo(workingSet) $f
            }
        }
    }

    proc GetWorkingSet {} {
        variable sPo

        return [list $sPo(workingSet)]
    }

    proc SetAutosaveOnExit { onOff } {
        variable gPo

        set gPo(autosaveOnExit) $onOff
    }

    proc GetAutosaveOnExit {} {
        variable gPo

        return [list $gPo(autosaveOnExit)]
    }

    proc SetDefaultAppOnStart { appName } {
        variable sPo

        set sPo(defaultAppOnStart) $appName
    }

    proc GetDefaultAppOnStart {} {
        variable sPo

        return [list $sPo(defaultAppOnStart)]
    }

    proc SetTheme { theme } {
        variable sPo

        set sPo(theme) $theme
        if { $theme eq "" || [llength $theme] == 0 } {
            return
        }
        ttk::style theme use $theme
    }

    proc GetTheme {} {
        variable sPo

        return [list $sPo(theme)]
    }

    proc AddFileMatchIgnoreOption { option } {
        variable sPo

        lappend sPo(fileMatchIgnore) $option
    }

    proc IsFileMatchIgnoreOption { option } {
        variable sPo

        if { [lsearch -exact $sPo(fileMatchIgnore) $option] >= 0 } {
            return true
        } else {
            return false
        }
    }

    proc SetConfigVersion { version } {
        variable sPo

        set sPo(configVersion) $version
    }

    proc GetConfigVersion {} {
        variable sPo

        return [list $sPo(configVersion)]
    }

    proc SetDeveloperMode { onOff } {
        variable sPo

        set sPo(developerMode) $onOff
    }

    proc GetDeveloperMode {} {
        variable sPo

        return [list $sPo(developerMode)]
    }

    proc SetScriptDir { dir } {
        variable sPo

        set sPo(scriptDir) $dir
    }

    proc GetScriptDir {} {
        variable sPo

        return [list $sPo(scriptDir)]
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

    proc ViewSettingsDir {} {
        variable sPo

        poExtProg StartFileBrowser $sPo(cfgDir)
    }

    proc _WorkingSetCallback { tableId content } {
        foreach fileOrDir $content {
            AddFileOrDir $fileOrDir
        }
    }

    proc GetToplevel {} {
        variable sPo

        return $sPo(tw)
    }

    proc ShowSysNotify { title msg args } {
        if { [poMisc HaveTcl87OrNewer] && [poAppearance GetUseMsgBox "Notify"] } {
            foreach w $args {
                if { [winfo exists $w] && [focus -displayof $w] eq "" } {
                    tk sysnotify $title $msg
                    return
                }
            }
        }
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            wm deiconify $sPo(tw)
            return
        }

        if { [poAppearance GetShowSplash] } {
            if { ! [info exists sPo(dontShowSplash)] } {
                HelpProg "."
            }
        }

        toplevel $sPo(tw)
        wm withdraw .

        set sPo(mainWin,name) $sPo(tw)

        # Create the windows title.
        wm title $sPo(tw) "$sPo(appName) - [GetAppDescription main]"
        wm minsize $sPo(tw) 300 200
        set sw [winfo screenwidth $sPo(tw)]
        set sh [winfo screenheight $sPo(tw)]
        wm maxsize $sPo(tw) [expr $sw -20] [expr $sh -40]
        if { $sPo(mainWin,w) <= 0 || $sPo(mainWin,h) <= 0 } {
            wm geometry $sPo(tw) [format "+%d+%d" $sPo(mainWin,x) $sPo(mainWin,y)]
        } else {
            wm geometry $sPo(tw) [format "%dx%d+%d+%d" \
                        $sPo(mainWin,w) $sPo(mainWin,h) \
                        $sPo(mainWin,x) $sPo(mainWin,y)]
        }

        ttk::frame $sPo(tw).workfr
        pack $sPo(tw).workfr -side top -fill both -expand 1

        set btnfr $sPo(tw).workfr.btnfr
        set inpfr $sPo(tw).workfr.inpfr
        set statfr $sPo(tw).workfr.statfr
        ttk::frame $btnfr
        ttk::frame $inpfr
        ttk::frame $statfr -borderwidth 1

        grid $btnfr  -row 0 -column 0
        grid $inpfr  -row 1 -column 0 -sticky news
        grid $statfr -row 2 -column 0 -sticky news
        grid rowconfigure    $sPo(tw).workfr 1 -weight 1
        grid columnconfigure $sPo(tw).workfr 0 -weight 1

        # Row 1
        ttk::button $btnfr.poImgview -text "Image view (Key-1)" -image [::poImgData::poImgview] \
                    -compound top -command "${ns}::SelectApp poImgview"
        ttk::button $btnfr.poImgBrowse -text "Image browser (Key-2)" -image [::poImgData::poImgBrowse] \
                    -compound top -command "${ns}::SelectApp poImgBrowse"
        ttk::button $btnfr.poBitmap -text "Bitmap editor (Key-3)" -image [::poImgData::poBitmap] \
                    -compound top -command "${ns}::SelectApp poBitmap"

        # Row 2
        ttk::button $btnfr.poImgdiff -text "Image diff (Key-4)" -image [::poImgData::poImgdiff] \
                    -compound top -command "${ns}::SelectApp poImgdiff"
        ttk::button $btnfr.poDiff -text "Directory diff (Key-5)" -image [::poImgData::poDiff] \
                    -compound top -command "${ns}::SelectApp poDiff"
        ttk::button $btnfr.tkdiff -text "File diff (Key-6)" -image [::poImgData::tkdiff] \
                    -compound top -command "${ns}::SelectApp tkdiff"

        # Row 3
        ttk::button $btnfr.poSlideShow -text "Slide show (Key-7)" -image [::poImgData::poSlideShow] \
                    -compound top -command "${ns}::SelectApp poSlideShow"
        ttk::button $btnfr.poPresMgr -text "PPT manager (Key-8)" -image [::poImgData::poPresMgr] \
                    -compound top -command "${ns}::SelectApp poPresMgr"
        ttk::button $btnfr.poOffice -text "Office utilities (Key-9)" -image [::poImgData::poOffice] \
                    -compound top -command "${ns}::SelectApp poOffice"

        poDragAndDrop AddTtkBinding $btnfr.poImgview   "${ns}::StartAppImgview"
        poDragAndDrop AddTtkBinding $btnfr.poImgBrowse "${ns}::StartAppImgBrowse"
        poDragAndDrop AddTtkBinding $btnfr.poBitmap    "${ns}::StartAppBitmap"

        poDragAndDrop AddTtkBinding $btnfr.poImgdiff   "${ns}::StartAppImgdiff"
        poDragAndDrop AddTtkBinding $btnfr.poDiff      "${ns}::StartAppDirDiff"
        poDragAndDrop AddTtkBinding $btnfr.tkdiff      "${ns}::StartAppTkdiff"

        poDragAndDrop AddTtkBinding $btnfr.poSlideShow "${ns}::StartAppSlideShow"
        poDragAndDrop AddTtkBinding $btnfr.poPresMgr   "${ns}::StartAppPresMgr"
        poDragAndDrop AddTtkBinding $btnfr.poOffice    "${ns}::StartAppOffice"

        grid $btnfr.poImgview   -row 0 -column 0 -sticky news
        grid $btnfr.poImgBrowse -row 0 -column 1 -sticky news
        grid $btnfr.poBitmap    -row 0 -column 2 -sticky news

        grid $btnfr.poImgdiff   -row 1 -column 0 -sticky news
        grid $btnfr.poDiff      -row 1 -column 1 -sticky news
        grid $btnfr.tkdiff      -row 1 -column 2 -sticky news

        grid $btnfr.poSlideShow -row 2 -column 0 -sticky news
        grid $btnfr.poPresMgr   -row 2 -column 1 -sticky news
        grid $btnfr.poOffice    -row 2 -column 2 -sticky news

        bind $sPo(tw) <Key-1> "${ns}::SelectApp poImgview"
        bind $sPo(tw) <Key-2> "${ns}::SelectApp poImgBrowse"
        bind $sPo(tw) <Key-3> "${ns}::SelectApp poBitmap"

        bind $sPo(tw) <Key-4> "${ns}::SelectApp poImgdiff"
        bind $sPo(tw) <Key-5> "${ns}::SelectApp poDiff"
        bind $sPo(tw) <Key-6> "${ns}::SelectApp tkdiff"

        bind $sPo(tw) <Key-7> "${ns}::SelectApp poSlideShow"
        bind $sPo(tw) <Key-8> "${ns}::SelectApp poPresMgr"
        bind $sPo(tw) <Key-9> "${ns}::SelectApp poOffice"

        bind $sPo(tw) <Control-Key-1> "${ns}::StartApp  poImgview"
        bind $sPo(tw) <Control-Key-2> "${ns}::StartApp  poImgBrowse"
        bind $sPo(tw) <Control-Key-3> "${ns}::StartApp  poBitmap"

        bind $sPo(tw) <Control-Key-4> "${ns}::StartApp  poImgdiff"
        bind $sPo(tw) <Control-Key-5> "${ns}::StartApp  poDiff"
        bind $sPo(tw) <Control-Key-6> "${ns}::SelectApp tkdiff"

        bind $sPo(tw) <Control-Key-7> "${ns}::SelectApp poSlideShow"
        bind $sPo(tw) <Control-Key-8> "${ns}::StartApp  poPresMgr"
        bind $sPo(tw) <Control-Key-9> "${ns}::StartApp  poOffice"

        set sPo(tableId) [poWin CreateScrolledTablelist $inpfr true "" \
            -height 2 -exportselection false \
            -columns {0 "#" "right"
                      0 "Type" "left"
                      0 "Working set (Command line parameters)" "left" } \
            -stretch 2 \
            -setfocus 1 \
            -stripebackground [poAppearance GetStripeColor] \
            -selectmode extended \
            -showseparators yes]
        $sPo(tableId) columnconfigure 0 -showlinenumbers true
        set bodyTag [$sPo(tableId) bodytag]
        bind $bodyTag <<RightButtonPress>> \
            [list ${ns}::OpenTablelistContextMenu $sPo(tableId) %X %Y]
        bind $bodyTag <Control-a> "${ns}::SelectAllInList $sPo(tableId)"
        bind $bodyTag <Control-r> "${ns}::RemoveFromList $sPo(tableId)"

        poDragAndDrop AddCanvasBinding $sPo(tableId) "${ns}::_WorkingSetCallback"

        # Create menus.
        set hMenu $sPo(tw).menufr
        menu $hMenu -borderwidth 2 -relief sunken
        if { $::tcl_platform(os) eq "Darwin" } {
            $hMenu add cascade -menu $hMenu.apple -label $sPo(appName)
            set appleMenu $hMenu.apple
            menu $appleMenu -tearoff 0
            poMenu AddCommand $appleMenu "About $sPo(appName) ..." ""   ${ns}::HelpProg
            poMenu AddCommand $appleMenu "About Tcl/Tk ..."        ""   ${ns}::HelpTcl
            poMenu AddCommand $appleMenu "About packages ..."      ""   ${ns}::PkgInfo

            proc ::tk::mac::ShowPreferences {} {
                poSettings ShowGeneralSettWin
            }

            proc ::tk::mac::ShowHelp {} {
                ::poApps::HelpCont
            }
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
        set sPo(openMenu)   $fileMenu.open
        set sPo(browseMenu) $fileMenu.browse

        $fileMenu add cascade -label "Open"   -menu $sPo(openMenu)
        $fileMenu add cascade -label "Browse" -menu $sPo(browseMenu)

        menu $sPo(openMenu) -tearoff 0 -postcommand "${ns}::AddRecentFiles $sPo(openMenu)"
        poMenu AddCommand $sPo(openMenu) "Select ..."    "Ctrl+O" ${ns}::AskAddFile
        poMenu AddCommand $sPo(openMenu) "Edit list ..." ""       "poAppearance EditRecentList recentFileList"
        $sPo(openMenu) add separator

        menu $sPo(browseMenu) -tearoff 0 -postcommand "${ns}::AddRecentDirs $sPo(browseMenu)"
        poMenu AddCommand $sPo(browseMenu) "Select ..."    "Ctrl+B" ${ns}::AskAddDir
        poMenu AddCommand $sPo(browseMenu) "Edit list ..." ""       "poAppearance EditRecentList recentDirList"
        $sPo(browseMenu) add separator

        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $fileMenu "Quit" "Ctrl+Q" ${ns}::ExitApp
        }
        bind $sPo(tw) <Control-o> ${ns}::AskAddFile
        bind $sPo(tw) <Control-b> ${ns}::AskAddDir
        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }
        wm protocol $sPo(tw) WM_DELETE_WINDOW ${ns}::ExitApp


        # Menu Settings
        set imgSettMenu $settMenu.img
        set genSettMenu $settMenu.gen
        menu $settMenu -tearoff 0

        $settMenu add cascade -label "Image settings" -menu $imgSettMenu
        menu $imgSettMenu -tearoff 0
        poMenu AddCommand $imgSettMenu "Appearance"          "" [list poSettings ShowImgSettWin "Appearance"]
        poMenu AddCommand $imgSettMenu "Image types"         "" [list poSettings ShowImgSettWin "Image types"]
        poMenu AddCommand $imgSettMenu "Image browser"       "" [list poSettings ShowImgSettWin "Image browser"]
        poMenu AddCommand $imgSettMenu "Slide show"          "" [list poSettings ShowImgSettWin "Slide show"]
        poMenu AddCommand $imgSettMenu "Zoom rectangle"      "" [list poSettings ShowImgSettWin "Zoom rectangle"]
        poMenu AddCommand $imgSettMenu "Selection rectangle" "" [list poSettings ShowImgSettWin "Selection rectangle"]
        poMenu AddCommand $imgSettMenu "Palette"             "" [list poSettings ShowImgSettWin "Palette"]

        $settMenu add cascade -label "General settings" -menu $genSettMenu
        menu $genSettMenu -tearoff 0
        poMenu AddCommand $genSettMenu "Appearance"   "" [list poSettings ShowGeneralSettWin "Appearance"]
        poMenu AddCommand $genSettMenu "File types"   "" [list poSettings ShowGeneralSettWin "File types"]
        poMenu AddCommand $genSettMenu "Edit/Preview" "" [list poSettings ShowGeneralSettWin "Edit/Preview"]
        poMenu AddCommand $genSettMenu "Logging"      "" [list poSettings ShowGeneralSettWin "Logging"]

        $settMenu add separator
        poMenu AddCheck   $settMenu "Save on exit"       "" ${ns}::gPo(autosaveOnExit) ""
        poMenu AddCommand $settMenu "View setting files" "" ${ns}::ViewSettingsDir
        poMenu AddCommand $settMenu "Save settings"      "" ${ns}::SaveSettings

        # Menu Window
        menu $winMenu -tearoff 0
        poMenu AddCommand $winMenu [GetAppDescription main] "" "poApps StartApp main" -state disabled
        $winMenu add separator
        poMenu AddCommand $winMenu [GetAppDescription poImgview]   "" "${ns}::StartApp  poImgview"
        poMenu AddCommand $winMenu [GetAppDescription poImgBrowse] "" "${ns}::StartApp  poImgBrowse"
        poMenu AddCommand $winMenu [GetAppDescription poBitmap]    "" "${ns}::StartApp  poBitmap"
        $winMenu add separator
        poMenu AddCommand $winMenu [GetAppDescription poImgdiff]   "" "${ns}::StartApp  poImgdiff"
        poMenu AddCommand $winMenu [GetAppDescription poDiff]      "" "${ns}::StartApp  poDiff"
        poMenu AddCommand $winMenu [GetAppDescription tkdiff]      "" "${ns}::SelectApp tkdiff"
        $winMenu add separator
        poMenu AddCommand $winMenu [GetAppDescription poPresMgr]   "" "${ns}::StartApp  poPresMgr"
        poMenu AddCommand $winMenu [GetAppDescription poOffice]    "" "${ns}::StartApp  poOffice"

        # Menu Help
        menu $helpMenu -tearoff 0
        if { $::tcl_platform(os) ne "Darwin" } {
            poMenu AddCommand $helpMenu "Help ..." "F1" ${ns}::HelpCont
            bind $sPo(tw) <Key-F1>  ${ns}::HelpCont
            poMenu AddCommand $helpMenu "About $sPo(appName) ..." "" ${ns}::HelpProg
            poMenu AddCommand $helpMenu "About Tcl/Tk ..."        "" ${ns}::HelpTcl
            poMenu AddCommand $helpMenu "About packages ..."      "" ${ns}::PkgInfo
        }

        $sPo(tw) configure -menu $hMenu

        # Create widget for status messages.
        set sPo(StatusWidget) [poWin CreateStatusWidget $statfr]

        CheckSettingsCompatibility
    }

    proc SelectAllInList { tableId } {
        $tableId selection set 0 end
    }

    proc RemoveFromList { tableId } {
        set indList [$tableId curselection]
        if { [llength $indList] > 0 } {
            $tableId delete $indList
        }
    }

    proc ClearWorkingSetList {} {
        variable sPo

        $sPo(tableId) delete 0 end
    }

    proc OpenTablelistContextMenu { tableId x y } {
        variable sPo
        variable ns

        set w .poApps:tablelistContextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        set numSel [llength [$tableId curselection]]
        if { $numSel == 0 } {
            set menuTitle "Nothing selected"
        } else {
            set menuTitle "$numSel selected"
        }
        $w add command -label "$menuTitle" -state disabled -background "#303030"
        if { $numSel == 0 } {
            tk_popup $w $x $y
            return
        }
        $w add command -label "Select all"       -underline 0 -command "${ns}::SelectAllInList $tableId"
        $w add command -label "Remove from list" -underline 0 -command "${ns}::RemoveFromList $tableId"
        tk_popup $w $x $y
    }

    proc AddRecentFiles { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 3
        poMenu AddRecentFileList $menuId ${ns}::AddFile
    }

    proc AddRecentDirs { menuId } {
        variable ns

        poMenu DeleteMenuEntries $menuId 3
        poMenu AddRecentDirList $menuId ${ns}::AddDir
    }

    proc AskAddFile {} {
        variable sPo

        set fileList [tk_getOpenFile  \
                     -initialdir $sPo(lastDir) \
                     -multiple true \
                     -title "Select file"]
        foreach fileName $fileList {
            AddFile $fileName
        }
    }

    proc AskAddDir {} {
        variable sPo

        set selDir [poWin ChooseDir "Select directory" $sPo(lastDir)]
        if { $selDir ne "" && [file isdirectory $selDir] } {
            AddDir $selDir
        }
    }

    proc AddFileOrDir { name } {
        variable sPo

        set type "Unknown"
        if { [file isdirectory $name] } {
            set type "Directory"
        } elseif { [file isfile $name] } {
            set type "File"
        }
        if { $type ne "Unknown" } {
            if { [info exists sPo(tableId)] && [winfo exists $sPo(tableId)] } {
                $sPo(tableId) insert end [list "" $type [file normalize $name]]
                $sPo(tableId) selection set end end
            }
        }
    }

    proc AddFile { fileName } {
        variable sPo

        set sPo(lastDir) [file dirname $fileName]
        AddFileOrDir $fileName
    }

    proc AddDir { dirName } {
        variable sPo

        set sPo(lastDir) $dirName
        AddFileOrDir $dirName
    }

    proc WriteInfoStr { str { icon "None" } } {
        variable sPo

        if { [info exists sPo(StatusWidget)] && [winfo exists $sPo(StatusWidget)] } {
            poWin WriteStatusMsg $sPo(StatusWidget) $str $icon
        }
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        SetConfigVersion "0.0.0"
        SetWindowPos mainWin 10 30
        SetAutosaveOnExit 1
        SetDefaultAppOnStart "main"
        SetTheme ""
        SetDeveloperMode 0
        SetWorkingSet [list]

        poFileType LoadSettings $cfgDir
        poImgType  LoadSettings $cfgDir

        poImgview   LoadSettings $cfgDir
        poImgBrowse LoadSettings $cfgDir
        poBitmap    LoadSettings $cfgDir
        poImgdiff   LoadSettings $cfgDir
        poDiff      LoadSettings $cfgDir
        poSlideShow LoadSettings $cfgDir
        poPresMgr   LoadSettings $cfgDir
        poOffice    LoadSettings $cfgDir

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file \"$cfgFile\"."
            set sPo(initType) "Ok"
            source $cfgFile
        } else {
            SetConfigVersion [GetVersionNumber]
            set sPo(initStr) "No settings file \"$cfgFile\" found. Using default values."
            set sPo(initType) "Warning"
        }

        set sPo(cfgDir) $cfgDir
    }

    proc PrintCmd { fp cmdName { ns "" } } {
        puts $fp "\n# Set${cmdName} [info args ${ns}::Set${cmdName}]"
        puts $fp "catch {${ns}::Set${cmdName} [${ns}::Get${cmdName}]}"
    }

    proc PrintCmd2 { fp cmdName arg { ns "" } } {
        puts $fp "\n# Set${cmdName} $arg [info args ${ns}::Set${cmdName}]"
        puts $fp "catch {${ns}::Set${cmdName} $arg [${ns}::Get${cmdName} $arg]}"
    }

    proc SaveSettings {} {
        variable ns
        variable sPo
        variable gConv

        poFileType SaveSettings
        poImgType  SaveSettings

        poImgdiff   SaveSettings
        poImgview   SaveSettings
        poBitmap    SaveSettings
        poImgBrowse SaveSettings
        poDiff      SaveSettings
        poSlideShow SaveSettings
        poPresMgr   SaveSettings
        poOffice    SaveSettings

        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $sPo(cfgDir)]]
        poCfgFile CreateBackupFile $cfgFile
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            puts $fp "\n# SetConfigVersion [info args SetConfigVersion]"
            puts $fp "catch {SetConfigVersion [GetVersionNumber]}"

            puts $fp "\n# SetWindowPos [info args SetWindowPos]"
            puts $fp "catch {SetWindowPos [GetWindowPos mainWin]}"

            PrintCmd $fp "UseVertTabs"    "::poAppearance"
            PrintCmd $fp "ShowSplash"     "::poAppearance"
            PrintCmd $fp "StripeColor"    "::poAppearance"
            PrintCmd $fp "NumPathItems"   "::poAppearance"

            PrintCmd2 $fp "UseMsgBox" "Exit"     "::poAppearance"
            PrintCmd2 $fp "UseMsgBox" "Error"    "::poAppearance"
            PrintCmd2 $fp "UseMsgBox" "Warning"  "::poAppearance"
            PrintCmd2 $fp "UseMsgBox" "Notify"   "::poAppearance"

            PrintCmd $fp "RecentFileList"       "::poAppearance"
            PrintCmd $fp "RecentDirList"        "::poAppearance"

            PrintCmd $fp "ShowColorInHex"        "::poImgAppearance"
            PrintCmd $fp "ShowColorCountColumn"  "::poImgAppearance"
            PrintCmd $fp "UseLastImgFmt"         "::poImgAppearance"
            PrintCmd $fp "LastImgFmtUsed"        "::poImgAppearance"
            PrintCmd $fp "RowOrderCount"         "::poImgAppearance"
            PrintCmd $fp "HistogramType"         "::poImgAppearance"
            PrintCmd $fp "HistogramHeight"       "::poImgAppearance"
            PrintCmd $fp "CanvasBackgroundColor" "::poImgAppearance"
            PrintCmd $fp "ShowRawCurValue"       "::poImgAppearance"
            PrintCmd $fp "ShowRawImgInfo"        "::poImgAppearance"
            PrintCmd $fp "UsePoImg"              "::poImgAppearance"
            PrintCmd $fp "UseMuPdf"              "::poImgAppearance"
            PrintCmd $fp "UseFitsTcl"            "::poImgAppearance"

            PrintCmd $fp "SelRectParams"  "::poSelRect"
            PrintCmd $fp "ZoomRectParams" "::poZoomRect"

            PrintCmd $fp "DebugFile"   "::poLog"
            PrintCmd $fp "ShowConsole" "::poLog"
            PrintCmd $fp "DebugLevels" "::poLog"

            PrintCmd $fp "TextWidgetSaveMode"    "::poExtProg"
            PrintCmd $fp "TextWidgetLineNumMode" "::poExtProg"
            PrintCmd $fp "TextWidgetWrapLines"   "::poExtProg"
            PrintCmd $fp "TextWidgetTabStop"     "::poExtProg"
            PrintCmd $fp "TextWidgetFont"        "::poExtProg"

            PrintCmd $fp "ShowHistoTable" "::poHistogram"

            PrintCmd $fp "MarkColor" "::poColorCount"

            PrintCmd $fp "PaletteParams" "::poImgPalette"

            PrintCmd $fp "WindowPos" "::poWinInfo"

            set sPo(workingSet) [list]
            foreach row [$sPo(tableId) get 0 end] {
                lappend sPo(workingSet) [lindex $row 2]
            }
            PrintCmd $fp "WorkingSet"        "$ns"
            PrintCmd $fp "AutosaveOnExit"    "$ns"
            PrintCmd $fp "DefaultAppOnStart" "$ns"
            PrintCmd $fp "Theme"             "$ns"
            PrintCmd $fp "DeveloperMode"     "$ns"

            close $fp
            WriteInfoStr "Settings stored in file $cfgFile"
        }
    }

    proc CheckSettingsCompatibility {} {
        set msg ""
        # Check for new poImgtype settings introduced in version 2.6.0
        # using new Img 1.5.0 package.
        if { [package vcompare [GetVersionNumber] "2.6.0"] >= 0 } {
            if { [package vcompare "2.6.0" [GetConfigVersion]] > 0 } {
                append msg "Settings for image types have changed in poApps 2.6.0.\n"
                append msg "Please remove settings file poImgtype.cfg and restart poApps."
            }
        }
        if { $msg ne "" } {
            ViewSettingsDir
            after 500
            tk_messageBox -title "Compatibility warning" -icon warning -message "$msg"
        }
    }

    proc ExitApp { { errorCode 0 } } {
        variable sPo
        variable gPo

        set exitApp true

        if { ! [UseBatchMode] && [poAppearance GetUseMsgBox "Exit"] } {
            set parentWin ""
            if { $::tcl_platform(os) ne "Darwin" } {
                set parentWin "-parent $sPo(tw) "
            }
            set retVal [tk_messageBox -icon question -type yesno -default no \
                -message "Really quit poApps ?" \
                {*}$parentWin \
                -title "Confirmation"]
            if { $retVal eq "no" } {
                set exitApp false
            }
        }

        if { $exitApp } {
            # Save settings of all applications. Must be done before closing to
            # know about the windows sizes.
            if { [info exists gPo(autosaveOnExit)] && $gPo(autosaveOnExit) } {
                SaveSettings
            }

            # Close all application windows.
            poImgdiff   CloseAppWindow
            poImgview   CloseAppWindow
            poBitmap    CloseAppWindow
            poImgBrowse CloseAppWindow
            poDiff      CloseAppWindow
            poSlideShow CloseAppWindow
            poPresMgr   CloseAppWindow
            poOffice    CloseAppWindow
            poTkDiff    CloseAppWindow

            if { [poMisc HaveTcl87OrNewer] } {
                tk systray destroy
            }

            # Enable next line for debugging photo and poImage usage.
            # ImageInfo

            poMisc CleanTclkitDirs
            exit $errorCode
        }
    }

    proc ImageInfo {} {
        puts "Number of photo images left: [llength [image names]]"
        foreach ph [lsort -dictionary [image names]] {
            puts "  $ph ([image width $ph] x [image height $ph])"
        }
        catch {puts "poImages left: [info commands poImage*]"}
        if { [poImgAppearance UsePoImg] } {
            memcheck
        }
    }

    proc GetUsageMsg { { whichApp "" } } {
        variable sPo

        if { [poAppearance GetShowSplash] } {
            set showSplash "Show splash"
        } else {
            set showSplash "Do not show splash"
        }

        set msg ""
        append msg "\n"
        append msg "Usage: $sPo(appName) \[Options\] \[DirOrFile1]\ \[DirOrFileN\]\n"
        append msg "\n"
        append msg "Start the portable application selection window.\n"
        append msg "\n"
        append msg "If files or directories have been specified, but no application\n"
        append msg "use some heuristics to determine the best fitting application.\n"
        append msg "\n"
        append msg "General options:\n"
        append msg "--help            : Display this usage message and exit.\n"
        append msg "--helpimg         : Display image type settings and exit.\n"
        append msg "--helpfile        : Display file type settings and exit.\n"
        append msg "--helpall         : Display all usage messages and settings and exit.\n"
        append msg "--version         : Display version and copyright messages and exit.\n"
        append msg "--config <dir>    : Specify directory of the configuration files.\n"
        append msg "                    Default: User home directory ([poCfgFile GetCfgDefaultDir]).\n"
        append msg "\n"
        append msg "General batch options:\n"
        append msg "--batch           : Enable batch processing.\n"
        append msg "                    See the application specific help for more batch options.\n"
        append msg "                    Default: No\n"
        append msg "--verbose         : Display verbose information.\n"
        append msg "                    Default: No.\n"
        append msg "--overwrite       : Overwrite existing files.\n"
        append msg "                    Default: No.\n"
        append msg "--nosaveonexit    : Do not save settings on exit. Use this flag, if using\n"
        append msg "                    batch mode and don't want to change current settings.\n"
        append msg "--nosplash        : Do not show splash screen on startup.\n"
        append msg "                    Current setting: $showSplash.\n"
        append msg "--nodisplay       : Do not display images when performing batch processing.\n"
        append msg "                    Default: Yes.\n"
        append msg "--hidewindow      : Hide windows when performing batch processing.\n"
        append msg "                    Default: No.\n"
        append msg "--gzip <string>   : Pack specified directories and files into a gzipped tar file.\n"
        append msg "--gziplevel <int> : Gzip compression level (1 - 9). Default: 6.\n"
        append msg "                    A value of 0 means no compression, i.e. a pure tar file.\n"
        append msg "\n"
        append msg "Application selection options:\n"
        append msg "--main            : Start the main window.\n"
        append msg "--imgview         : Start the image view application.\n"
        append msg "--imgbrowse       : Start the image browse application.\n"
        append msg "--imgdiff         : Start the image diff application.\n"
        append msg "--slideshow       : Start the image slide show application.\n"
        append msg "--bitmap          : Start the bitmap edit application.\n"
        append msg "--dirdiff         : Start the directory diff application.\n"
        append msg "--filediff        : Start the file diff application.\n"
        append msg "--presmgr         : Start the PowerPoint presentation management application.\n"
        append msg "--office          : Start the Office utilities application.\n"
        append msg "\n"
        append msg "Use --help and one of the above selection options for application specific help.\n"
        append msg "\n"
        append msg "Note: If using options with parameters, you have to specify the\n"
        append msg "      application selection option.\n"
        append msg "\n"
        if { $whichApp eq "poImgview" || $whichApp eq "all" } {
            append msg [poImgview GetUsageMsg]
        }
        if { $whichApp eq "poImgBrowse" || $whichApp eq "all" } {
            append msg [poImgBrowse GetUsageMsg]
        }
        if { $whichApp eq "poImgdiff" || $whichApp eq "all" } {
            append msg [poImgdiff GetUsageMsg]
        }
        if { $whichApp eq "poSlideShow" || $whichApp eq "all" } {
            append msg [poSlideShow GetUsageMsg]
        }
        if { $whichApp eq "poBitmap" || $whichApp eq "all" } {
            append msg [poBitmap GetUsageMsg]
        }
        if { $whichApp eq "poDiff" || $whichApp eq "all" } {
            append msg [poDiff GetUsageMsg]
        }
        if { $whichApp eq "poPresMgr" || $whichApp eq "all" } {
            append msg [poPresMgr GetUsageMsg]
        }
        if { $whichApp eq "poOffice" || $whichApp eq "all" } {
            append msg [poOffice GetUsageMsg]
        }
        if { $whichApp eq "tkdiff" || $whichApp eq "all" } {
            append msg [poTkDiff GetUsageMsg]
        }
        if { $whichApp eq "all" } {
            append msg "\n\n"
            append msg "Image type settings:\n"
            append msg [GetImgUsageMsg]
            append msg "\n\n"
            append msg "File type settings:\n"
            append msg [GetFileUsageMsg]
        }
        return $msg
    }

    proc GetImgUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "Available image formats:\n"
        append msg "  [poImgType GetFmtList]\n"

        append msg "\n"
        append msg "Available read format options:\n"
        foreach fmt [poImgType GetFmtList] {
            append msg [format "  %-10s: %s\n" $fmt [poImgType GetOptAsString $fmt "read"]]
        }

        append msg "\n"
        append msg "Available write format options:\n"
        foreach fmt [poImgType GetFmtList] {
            append msg [format "  %-10s: %s\n" $fmt [poImgType GetOptAsString $fmt "write"]]
        }

        append msg "\n"
        append msg "Current settings of read format options:\n"
        foreach fmt [poImgType GetFmtList] {
            append msg [format "  %-10s: %s\n" $fmt [poImgType GetOptByFmt $fmt "read"]]
        }

        append msg "\n"
        append msg "Current settings of write format options:\n"
        foreach fmt [poImgType GetFmtList] {
            append msg [format "  %-10s: %s\n" $fmt [poImgType GetOptByFmt $fmt "write"]]
        }

        append msg "\n"
        append msg "File extensions associated to image formats:\n"
        foreach fmt [poImgType GetFmtList] {
            append msg [format "  %-10s: %s\n" $fmt [poImgType GetExtList $fmt]]
        }

        return $msg
    }

    proc GetFileUsageMsg {} {
        variable sPo

        set msg ""

        append msg "\n"
        append msg "Current file types and associated file matches:\n"
        foreach type [poFileType GetTypeList] {
            set ext [poFileType GetTypeMatches $type]
            append msg [format "  %-16s: %s\n" $type $ext]
        }

        return $msg
    }

    proc HelpCont {} {
        variable sPo

        poWin CreateHelpWin [GetUsageMsg "all"] "$sPo(appName) command line help"
    }

    proc GetVersionNumber {} {
        return "2.12.0"
    }

    proc GetVersion {} {
        variable sPo

        return "[GetAppName] [GetVersionNumber] ([poMisc GetOSBitsStr])"
    }

    proc GetBuildInfo {} {
        set buildNumber "Developer"
        set buildDate   "N/A"
        if { [info procs GetBuildNumber] ne "" } {
            set buildNumber [GetBuildNumber]
        }
        if { [info procs GetBuildDate] ne "" } {
            set buildDate [GetBuildDate]
        }
        return [format "Build: %s (Date: %s)" $buildNumber $buildDate]
    }

    proc GetCopyright {} {
        return "Copyright 1999-2023 Paul Obermeier"
    }

    proc HelpProg { {splashWin ""} } {
        variable sPo

        poSoftLogo ShowLogo [GetVersion] [GetBuildInfo] [GetCopyright] $splashWin
        if { $splashWin ne "" } {
            poSoftLogo DestroyLogo
        }
    }

    proc HelpTcl {} {
        set pkgs "Tcl Tk Img scrollutil_tile tablelist_tile tkdnd tkMuPDF fitstcl"
        if { ! [poMisc HaveTcl87OrNewer] } {
            append pkgs " tksvg"
        }
        if { $::tcl_platform(platform) eq "windows" } {
            append pkgs " twapi"
        }
        poSoftLogo ShowTclLogo {*}$pkgs
    }

    proc PrintUsage { { whichApp "" } } {
        puts [GetUsageMsg $whichApp]
    }

    proc PrintImgUsage {} {
        puts [GetImgUsageMsg]
    }

    proc PrintFileUsage {} {
        puts [GetFileUsageMsg]
    }

    proc PrintErrorAndExit { showMsgBox msg } {
        puts "\nError: $msg"
        PrintUsage
        if { $showMsgBox } {
            tk_messageBox -title "Error" -icon error -message "$msg"
        }
        exit 1
    }

    proc IsSubAppOpen {} {
        if { [poBitmap    IsOpen] || \
             [poDiff      IsOpen] || \
             [poImgBrowse IsOpen] || \
             [poImgview   IsOpen] || \
             [poImgdiff   IsOpen] || \
             [poPresMgr   IsOpen] || \
             [poOffice    IsOpen] || \
             [poTkDiff    IsOpen] } {
            return true
        } else {
            return false
        }
    }

    proc SelectApp { app } {
        variable sPo

        set indList [$sPo(tableId) curselection]
        if { [llength $indList] == 0 } {
            StartApp $app
            return
        }
        set argList [list]
        foreach ind $indList {
            lappend argList [lindex [$sPo(tableId) get $ind] 2]
        }
        StartApp $app $argList
    }

    proc StartAppImgview { w fileList } {
        StartApp "poImgview" $fileList
    }

    proc StartAppImgBrowse { w fileList } {
        StartApp "poImgBrowse" $fileList
    }

    proc StartAppBitmap { w fileList } {
        StartApp "poBitmap" $fileList
    }

    proc StartAppSlideShow { w fileList } {
        StartApp "poSlideShow" $fileList
    }

    proc StartAppImgdiff { w fileList } {
        StartApp "poImgdiff" $fileList
    }

    proc StartAppDirDiff { w fileList } {
        StartApp "poDiff" $fileList
    }

    proc StartAppTkdiff { w fileList } {
        StartApp "tkdiff" $fileList
    }

    proc StartAppPresMgr { w fileList } {
        StartApp "poPresMgr" $fileList
    }

    proc StartAppOffice { w fileList } {
        StartApp "poOffice" $fileList
    }

    proc StartApp { app { argList {} } } {
        variable sPo

        if { $app eq "" } {
            # If argList is not empty (i.e. files or directories have been specified), but no
            # application has been specified, use some heuristics to determine the best fitting
            # application.
            set filesOrDirList [list]
            foreach param $argList {
                if { [string compare -length 1 $param "-"]  != 0 } {
                    lappend filesOrDirList $param
                }
            }
            set app [GetDefaultAppOnStart]
            if { [llength $filesOrDirList] == 1 } {
                set f [lindex $filesOrDirList 0]
                if { [file isdirectory $f] } {
                    set filesInDir [lindex [poMisc GetDirsAndFiles $f \
                                                   -showdirs false \
                                                   -showhiddendirs false \
                                                   -showhiddenfiles false] 1]
                    set numFilesToCheck [poMisc Min [llength $filesInDir] 10]
                    set numImgs 0
                    for { set i 0 } { $i < $numFilesToCheck } { incr i } {
                        if { [poImgMisc IsImageFile [file join $f [lindex $filesInDir $i]]] } {
                            incr numImgs
                        }
                    }
                    if { $numImgs > $numFilesToCheck/2 } {
                        set app "poImgBrowse"
                    } else {
                        set app "poDiff"
                    }
                } elseif { [poOffice HasSupportedExtension $f] } {
                    set app "poOffice"
                } elseif { [poType IsImage $f "xbm"] } {
                    set app "poBitmap"
                } elseif { [poImgMisc IsImageFile $f] } {
                    set app "poImgview"
                }
            } elseif { [llength $filesOrDirList] == 2 } {
                set f1 [lindex $filesOrDirList 0]
                set f2 [lindex $filesOrDirList 1]
                if { [file isdirectory $f1] && [file isdirectory $f2] } {
                    set app "poDiff"
                } elseif { [poImgMisc IsImageFile $f1] && [poImgMisc IsImageFile $f2] } {
                    set app "poImgdiff"
                } elseif { ! [poType IsBinary $f1] && ! [poType IsBinary $f2] } {
                    set app "tkdiff"
                }
            } elseif { [llength $filesOrDirList] > 2 } {
                set app "poImgview"
            }
        }
        set initStrShown false
        if { ! [winfo exists $sPo(tw)] } {
            ShowMainWin
            WriteInfoStr $sPo(initStr) $sPo(initType)
            set initStrShown true
        }

        if { $app eq "main" } {
            ShowMainWin
            if { ! $initStrShown } {
                WriteInfoStr $sPo(initStr) $sPo(initType)
            }
        } elseif { $app eq "deiconify" } {
            if { ! [IsSubAppOpen] } {
                ShowMainWin
            }
        } else {
            if { ! [poMisc IsAndroid] } {
                wm iconify $sPo(tw)
            }
            if { $app eq "poBitmap" } {
                poBitmap ShowMainWin
                poBitmap ParseCommandLine $argList
            } elseif { $app eq "poImgview" } {
                poImgview ShowMainWin
                poImgview ParseCommandLine $argList
            } elseif { $app eq "poImgBrowse" } {
                poImgBrowse ShowMainWin
                poImgBrowse ParseCommandLine $argList
            } elseif { $app eq "poImgdiff" } {
                poImgdiff ShowMainWin
                poImgdiff ParseCommandLine $argList
            } elseif { $app eq "poSlideShow" } {
                poSlideShow ShowMainWin
                poSlideShow ParseCommandLine $argList
            } elseif { $app eq "poDiff" } {
                poDiff ShowMainWin
                poDiff ParseCommandLine $argList
            } elseif { $app eq "poPresMgr" } {
                poPresMgr ShowMainWin
                poPresMgr ParseCommandLine $argList
            } elseif { $app eq "poOffice" } {
                poOffice ShowMainWin
                poOffice ParseCommandLine $argList
            } elseif { $app eq "tkdiff" } {
                poTkDiff ShowMainWin
                poTkDiff ParseCommandLine $argList
            }
        }
    }
}

#
# Start of program
#
set scriptDir [file normalize [file dirname [info script]]]
poApps SetScriptDir $scriptDir

set osBits [expr $tcl_platform(pointerSize) * 8]
set osPlatform $tcl_platform(os)
if { $tcl_platform(platform) eq "windows" } {
    set osPlatform "win"
}
set osDir "${osPlatform}${osBits}"

set auto_path [linsert $auto_path 0 $scriptDir]
set auto_path [linsert $auto_path 0 [file join $scriptDir Externals scrollutil]]

# Initialize external packages
# Note, that cawt must be initialized before poApplib.
if { $::tcl_platform(platform) eq "windows" } {
    poApps InitPackages twapi cawt
}

poApps InitPackages Tcl Tk
wm withdraw .

poApps InitPackages tdom jpeg scrollutil_tile tablelist_tile \
                    tkdnd poTcllib poTklib poApplib
# (apl
poApps InitPackages apave
namespace eval poToolhelp {
  proc Init { tw { bgColor yellow } { fgColor black } { xoff 0 } { yoff 20 } } {
    variable pkgInt
    set pkgInt(tw) $tw
    ::baltip configure -under [expr {$yoff?3:-16}] \
      -fg #000 -bg #dede95 -padx 5 -pady 4 -padding 0 -bd 1 -relief raised
  }
  proc HideToolhelp {} {}
  proc AddBinding { w msg args } {
    variable pkgInt
    if {![info exists pkgInt(tw)]} {Init stub}
    set options {}
    foreach { key value } $args {
      switch -exact $key {
        switch -- [winfo class $w] {
          Text   {append options " -tag $value -under -16"}
          Canvas {append options " -ctag $value -under -16"}
        }
      }
    }
    # most poSoft tips should be shown under a host widget,
    # but some under the mouse pointer (poShowLogo etc.)
    foreach underpointer {poShowLogo} {
      if {[string first $underpointer $w]>-1} {
        append options " -under -16"
        break
      }
    }
    ::baltip tip $w $msg {*}$options
  }
}
# apl)

# Initialize photo image related packages. Use special packages first,
# as the matching of image file formats occurs in reverse order.

# If running poApps from within a starkit, do not load package imgjp2,
# as this package needs the external libopenjp2 library.
if { ! [info exists starkit::topdir] } {
    poApps InitPackages imgjp2
}
# SVG support is part of Tk 8.7, so we do not need the tksvg extension.
if { ! [poMisc HaveTcl87OrNewer] } {
    poApps InitPackages tksvg
}
poApps InitPackages img::raw img::flir img::dted Img poImg


if { $::tcl_platform(os) eq "Darwin" } {
    proc ::tk::mac::OpenDocument { args } {
        poApps::ClearWorkingSetList
        foreach param $args {
            poApps::AddFileOrDir $param
        }
        poApps StartApp "" $args
    }

    proc ::tk::mac::Quit {} {
        poApps ExitApp
    }
}

# Initialize the poApps package itself.
poApps Init

poApps AddEvents

# Default values for the general command line options.
set optStartApp      [list]
set optPrintVersion  false
set optPrintHelp     false
set optPrintHelpImg  false
set optPrintHelpFile false
set optPrintHelpAll  false
set optNoSaveOnExit  false
set optZipFile       ""
set optZipLevel      6
set optCfgDir        [file join [poMisc GetHomeDir] ".[poApps GetAppName]"]
set optColorScheme   -2
set optHue           0
set argList          [list]

# Parse command line for general options.
# Append all parameters not handled here to a list (argList) which is handed
# over to the application specific ParseCommandLine procedures.
set curArg 0
set isFileMatchIgnoreOption false
while { $curArg < $argc } {
    set curParam [lindex $argv $curArg]
    if { [string compare -length 1 $curParam "-"]  == 0 || \
         [string compare -length 2 $curParam "--"] == 0 } {
        set curOpt [string tolower [string trimleft $curParam "-"]]
        set isFileMatchIgnoreOption [poApps IsFileMatchIgnoreOption $curOpt]
        if { $curOpt eq "config" } {
            incr curArg
            set tmpDir [lindex $argv $curArg]
            if { ! [file isdirectory $tmpDir] } {
                tk_messageBox -title "Error" -icon error \
                -message "Configuration directory \"$tmpDir\" not existent."
                exit 1
            }
            set optCfgDir [poMisc FileSlashName $tmpDir]
        } elseif { $curOpt eq "cs" } {
            incr curArg
            set optColorScheme [lindex $argv $curArg]
        } elseif { $curOpt eq "hue" } {
            incr curArg
            set optHue [lindex $argv $curArg]
        } elseif { $curOpt eq "version" } {
            set optPrintVersion true
        } elseif { $curOpt eq "help" } {
            set optPrintHelp true
        } elseif { $curOpt eq "helpimg" } {
            set optPrintHelpImg true
        } elseif { $curOpt eq "helpfile" } {
            set optPrintHelpFile true
        } elseif { $curOpt eq "helpall" } {
            set optPrintHelpAll true
        } elseif { $curOpt eq "verbose" } {
            poApps SetVerbose true
        } elseif { $curOpt eq "batch" } {
            poApps SetBatchMode true
        } elseif { $curOpt eq "overwrite" } {
            poApps SetOverwrite true
        } elseif { $curOpt eq "nosaveonexit" } {
            set optNoSaveOnExit true
        } elseif { $curOpt eq "nosplash" } {
            set poApps::sPo(dontShowSplash) true
        } elseif { $curOpt eq "nodisplay" } {
            poApps SetDisplayImage false
        } elseif { $curOpt eq "hidewindow" } {
            poApps SetHideWindow true
        } elseif { $curOpt eq "gzip" } {
            incr curArg
            set optZipFile [lindex $argv $curArg]
        } elseif { $curOpt eq "gziplevel" } {
            incr curArg
            set optZipLevel [lindex $argv $curArg]
        } elseif { $curOpt eq "main" } {
            lappend optStartApp "main"
        } elseif { $curOpt eq "bitmap" } {
            lappend optStartApp "poBitmap"
        } elseif { $curOpt eq "imgview" } {
            lappend optStartApp "poImgview"
        } elseif { $curOpt eq "imgbrowse" } {
            lappend optStartApp "poImgBrowse"
        } elseif { $curOpt eq "imgdiff" } {
            lappend optStartApp "poImgdiff"
        } elseif { $curOpt eq "slideshow" } {
            lappend optStartApp "poSlideShow"
        } elseif { $curOpt eq "dirdiff" } {
            lappend optStartApp "poDiff"
        } elseif { $curOpt eq "filediff" } {
            lappend optStartApp "tkdiff"
        } elseif { $curOpt eq "presmgr" } {
            lappend optStartApp "poPresMgr"
        } elseif { $curOpt eq "office" } {
            lappend optStartApp "poOffice"
        } elseif { [string first "-psn" $curParam] == 0 } {
            # Ignore this option. This parameter is supplied automatically
            # by OS X, when using this program as a starpack in a Mac APP.
        } else {
            lappend argList $curParam
        }
    } else {
        # A DOS shell does no file expansion, as is done with a Unix style shell.
        # So we do this here. Only "?" and "*" are recognized.
        if { $::tcl_platform(platform) eq "windows" && ! $isFileMatchIgnoreOption } {
            if { [string match "*\\**" $curParam] || [string match "*\\?*" $curParam] } {
                foreach f [lsort -dictionary [glob -nocomplain -- [file normalize $curParam]]] {
                    lappend argList $f
                }
            } else {
                lappend argList $curParam
            }
        } else {
            lappend argList $curParam
        }
        set isFileMatchIgnoreOption false
    }
    incr curArg
}

# (apl
#ARGS1: -cs 5 -hue 10
source [file join [file dirname [info script]] Externals apave baltip baltip.tcl]
if {$optColorScheme > -2 && $optColorScheme < 23} {
  source [file join [file dirname [info script]] Externals apave apave.tcl]
  apave::obj csSet $optColorScheme . -doit
  if {$optHue} {apave::obj csToned $optColorScheme $optHue yes}
  ttk::style config . -troughcolor
}
# apl)

# Try to load settings file.
if { ! [file isdirectory $optCfgDir] } {
    file mkdir $optCfgDir
}
poApps LoadSettings $optCfgDir

poApps SetTheme [lindex [poApps GetTheme] 0]

# Load the tkMuPdf and fitsTcl package after loading the settings file,
# as this action can be selected by user settings.
if { [poImgAppearance GetUseMuPdf] } {
    poApps InitPackages tkMuPDF
}
if { [poImgAppearance GetUseFitsTcl] } {
    poApps InitPackages fitstcl
}
# Load PAWT after fitsTcl, as it relies on it.
poApps InitPackages pawt

if { $optPrintVersion } {
    poLog SetShowConsole 0

    puts "[poApps GetVersion] is based on:"
    poApps PrintPkgInfo
    puts "[poApps GetBuildInfo]"
    puts "[poApps GetCopyright]"
    exit 0
}

if { $optPrintHelp || $optPrintHelpImg || $optPrintHelpFile || $optPrintHelpAll } {
    poLog SetShowConsole 0

    if { $optPrintHelpAll } {
        poApps PrintUsage "all"
        exit 0
    }
    if { $optPrintHelp } {
        poApps PrintUsage [lindex $optStartApp end]
    }
    if { $optPrintHelpImg } {
        poApps PrintImgUsage
    }
    if { $optPrintHelpFile } {
        poApps PrintFileUsage
    }
    exit 0
}

if { $optNoSaveOnExit } {
    poApps SetAutosaveOnExit 0
}

if { [poMisc HaveTcl87OrNewer] } {
    proc SystrayCB {} {
        set wmState [wm state [poApps GetToplevel]]
        if { $wmState eq "withdrawn" || $wmState eq "iconic" } {
            poApps::ShowMainWin
        } else {
            wm iconify [poApps GetToplevel]
        }
    }

    tk systray create \
        -image [poImgData::poLogo32] \
        -text "poApps main window" \
        -button1 SystrayCB

    if { $::tcl_platform(os) eq "Linux" } {
        set ::tk::icons::base_icon([poApps GetToplevel]) [poImgData::poLogo32]
    }
}

if { $optZipFile ne "" } {
    set zipList [list]
    foreach name $argList {
        if { [file isdirectory $name] } {
            lappend zipList $name
            if { [poApps GetVerbose] } {
                puts "Adding directory $name"
            }
        } elseif { [file isfile $name] } {
            lappend zipList $name
            if { [poApps GetVerbose] } {
                puts "Adding file     $name"
            }
        } else {
            if { [poApps GetVerbose] } {
                puts "Skipping        $name"
            }
        }
    }
    if { [llength $zipList] > 0 } {
        if { ! [string is integer $optZipLevel] || $optZipLevel > 9 } {
            set optZipLevel 9
        }
        if { $optZipLevel < 1 } {
            set optZipLevel 0
        }

        if { [poApps GetVerbose] } {
            puts "Creating file $optZipFile using compression level $optZipLevel"
        }
        poMisc Pack $optZipFile $optZipLevel {*}$zipList
        exit 0
    } else {
        if { [poApps GetVerbose] } {
            puts "No files specified for packing."
        }
        exit 1
    }
}

if { [llength $optStartApp] == 0 } {
    poApps StartApp "" $argList
} else {
    foreach startApp $optStartApp {
        poApps StartApp $startApp $argList
    }
}

set paramList [list]
foreach param $argList {
    if { [string compare -length 1 $param "-"] != 0 } {
        lappend paramList $param
    }
}

if { [llength $paramList] > 0 } {
    foreach param $paramList {
        poApps::AddFileOrDir $param
    }
} else {
    if { [info exists poApps::sPo(workingSet)] } {
        foreach f $poApps::sPo(workingSet) {
            poApps::AddFileOrDir $f
        }
    }
}

tk appname [poApps GetAppName]

poAppearance UpdateRecentCaches

# Now we are in the Tk event loop.

