# Module:         poSlideShow
# Copyright:      Paul Obermeier 2014-2023 / paul@poSoft.de
# First Version:  2014 / 02 / 26
#
# Distributed under BSD license.
#
# This program can be used to compare two images.


namespace eval poSlideShow {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export OpenWin OkWin CancelWin
    namespace export LoadSettings SaveSettings
    namespace export ShowMainWin CloseAppWindow
    namespace export ParseCommandLine IsOpen
    namespace export GetUsageMsg
    namespace export GetTextColor GetDisabledColor GetEnabledColor
    namespace export SetInitialFile SetMarkList SetFileMarkList
    namespace export StartSlideShow 

    # The following variables must be set, before reading parameters and
    # before calling LoadSettings.
    proc Init {} {
        variable sPo

        set sPo(tw)      ".poSlideShow" ; # Name of toplevel window
        set sPo(appName) "poSlideShow"  ; # Name of tool
        set sPo(cfgDir)  ""             ; # Directory containing config files

        set sPo(onScreenHelp) 0
        set sPo(textColors) [list "white" "blue" "red" "yellow"]
    }

    proc IncrSlideShowDuration { durationIncr } {
        variable sPo

        set sPo(slideDuration) [expr { $sPo(slideDuration) + $durationIncr }]
        set sPo(slideDuration) [poMisc Max 0 $sPo(slideDuration)]
    }

    proc SetSlideShowDuration { duration } {
        variable sPo

        set sPo(slideDuration) $duration
    }

    proc GetSlideShowDuration {} {
        variable sPo

        return $sPo(slideDuration)
    }

    proc SetSlideShowDirection { dir } {
        variable sPo

        set sPo(slideDirection) $dir
    }

    proc GetSlideShowDirection {} {
        variable sPo

        return $sPo(slideDirection)
    }

    proc SetAdvanceMode { mode } {
        variable sPo

        set sPo(slideAdvanceMode) $mode
    }

    proc GetAdvanceMode {} {
        variable sPo

        return $sPo(slideAdvanceMode)
    }

    proc SetScaleToFitMode { onOff } {
        variable sPo

        set sPo(scaleToFitMode) $onOff
    }

    proc GetScaleToFitMode {} {
        variable sPo

        return $sPo(scaleToFitMode)
    }

    proc SetShowInfoMode { onOff } {
        variable sPo

        set sPo(showInfoMode) $onOff
    }

    proc GetShowInfoMode {} {
        variable sPo

        return $sPo(showInfoMode)
    }

    proc SetTextColor { color } {
        variable sPo

        set sPo(color,text) $color
    }

    proc GetTextColor {} {
        variable sPo

        return $sPo(color,text)
    }

    proc SetEnabledColor { color } {
        variable sPo

        set sPo(color,enabled) $color
    }

    proc GetEnabledColor {} {
        variable sPo

        return $sPo(color,enabled)
    }

    proc SetDisabledColor { color } {
        variable sPo

        set sPo(color,disabled) $color
    }

    proc GetDisabledColor {} {
        variable sPo

        return $sPo(color,disabled)
    }

    proc SetLogoFile { fileName } {
        variable sPo

        set sPo(logoFile) $fileName
    }

    proc GetLogoFile {} {
        variable sPo

        return $sPo(logoFile)
    }

    proc SetUseLogoFile { onOff } {
        variable sPo

        set sPo(useLogoFile) $onOff
    }

    proc GetUseLogoFile {} {
        variable sPo

        return $sPo(useLogoFile)
    }

    proc AddLogo { canvId } {
        variable sPo

        if { [GetUseLogoFile] && [GetLogoFile] ne "" } {
            set retVal [catch {poImgMisc LoadImg [GetLogoFile]} imgDict]

            if { $retVal == 0 } {
                set phImg [dict get $imgDict phImg]
                set top   $sPo(screenHeight)
                set right $sPo(screenWidth)
                $canvId create image $right 0 -anchor ne -image $phImg -tags tagLogoImg
            }
        }
    }

    proc _OpenContextMenu { x y } {
        variable ns
        variable sPo

        set w .poSlideShow:contextMenu
        catch { destroy $w }
        menu $w -tearoff false -disabledforeground white

        $w add command -label "Close this menu"
        $w add separator
        $w add command -label "Leave slideshow (cancel marks)" -command "${ns}::CloseAppWindow false"
        $w add command -label "Leave slideshow (use marks)"    -command "${ns}::CloseAppWindow true"
        $w add separator
        $w add command -label "Show first image"               -command "${ns}::ShowImgByNum 0" 
        $w add command -label "Load image into poImgView"      -command "${ns}::LoadInImgview"
        $w add command -label "Rotate left"                    -command "${ns}::RotImg  90" 
        $w add command -label "Rotate right"                   -command "${ns}::RotImg -90" 
        $w add separator
        $w add command -label "Toggle adavance mode"           -command "${ns}::ToggleAdvanceMode"
        $w add command -label "Toggle scale to fit mode"       -command "${ns}::ToggleScaleToFit" 
        $w add command -label "Toggle image marking"           -command "${ns}::ToggleMark"
        $w add command -label "Toggle display of info line"    -command "${ns}::ToggleInfoMsg"
        $w add command -label "Toggle text colors"             -command "${ns}::ToggleTextColor" 
        $w add command -label "Toggle shortcut help"           -command "${ns}::ToggleOnScreenHelp"

        tk_popup $w $x $y
    }

    proc _SetMousePos { x y } {
        variable sPo

        set sPo(mouse,x) $x
        set sPo(mouse,y) $y
    }

    proc _CalcGesture { x y } {
        variable sPo

        set dirx [expr { $x - $sPo(mouse,x) }]
        set diry [expr { $y - $sPo(mouse,y) }]

        if { [poMisc Abs $dirx] < 10 && [poMisc Abs $diry] < 10 } {
            _OpenContextMenu $x $y
            return
        }

        if { [poMisc Abs $diry] > 50 } {
            if { $diry > 0 } {
                DecrDuration 1
            } else {
                IncrDuration 1
            }
        }

        set factor [poMisc Max 1 [expr [poMisc Abs $dirx] / 200]]
        if { $dirx < 0 } {
            ShowPrevImg $factor
        } else {
            ShowNextImg $factor
        }
    }

    proc ShowMainWin {} {
        variable ns
        variable sPo

        if { [winfo exists $sPo(tw)] } {
            poWin Raise $sPo(tw)
            return
        }

        set sPo(screenHeight) [winfo screenheight .]
        set sPo(screenWidth)  [winfo screenwidth .]

        toplevel $sPo(tw)

        # Keep that order of statements for fullscreen to work correctly on Darwin.
        wm withdraw .
        wm attributes $sPo(tw) -fullscreen 1
        wm deiconify $sPo(tw)

        ttk::frame $sPo(tw).fr
        pack $sPo(tw).fr -expand 1 -fill both

        set canvId $sPo(tw).fr.c
        set sPo(canvId) $canvId
        canvas $canvId -background $sPo(color,disabled) -borderwidth 0
        pack $canvId -fill both -expand 1 -side left

        # Gestures for stepping through images.
        bind $sPo(tw) <ButtonPress-1>   "${ns}::_SetMousePos %x %y"
        bind $sPo(tw) <ButtonRelease-1> "${ns}::_CalcGesture %x %y"

        # Keys for stepping through images.
        bind $sPo(tw) <Left>        "${ns}::ShowPrevImg"
        bind $sPo(tw) <Right>       "${ns}::ShowNextImg"
        bind $sPo(tw) <Shift-Left>  "${ns}::ShowPrevImg 10"
        bind $sPo(tw) <Shift-Right> "${ns}::ShowNextImg 10"
        bind $sPo(tw) <Home>        "${ns}::ShowImgByNum 0"
        bind $sPo(tw) <s>           "${ns}::ToggleAdvanceMode"

        # Keys for adjusting image display duration.
        bind $sPo(tw) <Down>  "${ns}::DecrDuration"
        bind $sPo(tw) <Up>    "${ns}::IncrDuration"
        bind $sPo(tw) <Key-0> "${ns}::SetDuration 0"
        bind $sPo(tw) <Key-1> "${ns}::SetDuration 1"
        bind $sPo(tw) <Key-2> "${ns}::SetDuration 2"
        bind $sPo(tw) <Key-3> "${ns}::SetDuration 3"
        bind $sPo(tw) <Key-4> "${ns}::SetDuration 4"
        bind $sPo(tw) <Key-5> "${ns}::SetDuration 5"
        bind $sPo(tw) <Key-6> "${ns}::SetDuration 6"
        bind $sPo(tw) <Key-7> "${ns}::SetDuration 7"
        bind $sPo(tw) <Key-8> "${ns}::SetDuration 8"
        bind $sPo(tw) <Key-9> "${ns}::SetDuration 9"

        # Keys for manipulating images.
        bind $sPo(tw) <v>     "${ns}::LoadInImgview"
        bind $sPo(tw) <space> "${ns}::ToggleMark"
        bind $sPo(tw) <h>     "${ns}::ToggleOnScreenHelp"
        bind $sPo(tw) <i>     "${ns}::ToggleInfoMsg"
        bind $sPo(tw) <c>     "${ns}::ToggleTextColor"
        bind $sPo(tw) <f>     "${ns}::ToggleScaleToFit"
        bind $sPo(tw) <l>     "${ns}::RotImg  90"
        bind $sPo(tw) <r>     "${ns}::RotImg -90"

        # Keys for terminating slide show.
        bind $sPo(tw) <Return>    "${ns}::CloseAppWindow true"
        bind $sPo(tw) <Escape>    "${ns}::CloseAppWindow"
        bind $sPo(tw) <Control-w> "${ns}::CloseAppWindow"
        wm protocol $sPo(tw) WM_DELETE_WINDOW "${ns}::CloseAppWindow"

        bind $sPo(tw) <Control-q> ${ns}::ExitApp
        if { $::tcl_platform(platform) eq "windows" } {
            bind $sPo(tw) <Alt-F4> ${ns}::ExitApp
        }

        if { [poApps GetHideWindow] } {
            wm withdraw $sPo(tw)
        } else {
            poWin Raise $sPo(tw)
            focus $sPo(tw)
        }
        update
    }

    proc ToggleOnScreenHelp {} {
        variable sPo

        set canvId $sPo(canvId)
        set textXPos 10
        set textYPos 40

        if { $sPo(onScreenHelp) } {
            catch { $canvId delete onscreenhelp }
            set sPo(onScreenHelp) 0
        } else {
            append msg [GetShortcutMsg true]
            $canvId create text $textXPos $textYPos -font [poWin GetFixedFont] \
                    -anchor nw -fill $sPo(color,text) -text $msg -tags onscreenhelp
            set sPo(onScreenHelp) 1
        }
    }

    proc ToggleInfoMsg {} {
        variable sPo

        SetShowInfoMode [expr ! [GetShowInfoMode]]
        if { [GetShowInfoMode] } {
            UpdateInfoMsg $sPo(canvId)
        } else {
            ShowInfoMsg $sPo(canvId) 0 0 ""
        }
    }

    proc ShowInfoMsg { canvId textXPos textYPos msg } {
        variable sPo

        catch { $canvId delete tagInfoMsg }
        $canvId create text $textXPos $textYPos -font [poWin GetFixedFont] \
                -anchor nw -fill $sPo(color,text) -text $msg -tags tagInfoMsg
        $canvId raise tagInfoMsg
        update idletasks
    }

    proc UpdateInfoMsg { canvId } {
        variable sPo

        if { [GetAdvanceMode] eq "auto" } {
            set infoStr [format "%s Duration: %.1f" $sPo(imgInfoStr) [GetSlideShowDuration]]
        } else {
            set infoStr [format "%s Manual mode" $sPo(imgInfoStr)]
        }
        ShowInfoMsg $canvId 10 10 $infoStr
    }

    proc ShowImg { phImg poImg } {
        variable sPo

        set canvId $sPo(canvId)
        set imgName $sPo(imgName)
        set infoStr $sPo(infoStr)

        set sw $sPo(screenWidth)
        set sh $sPo(screenHeight)
        set xpos [expr {$sw / 2}]
        set ypos [expr {$sh / 2}]

        catch { $canvId delete tagImg }

        if { $phImg ne "" } {
            set phWidth  [image width $phImg]
            set phHeight [image height $phImg]
            if { [poImgAppearance UsePoImg] && [GetScaleToFitMode] } {
                set newImgAllocated false
                if { $poImg eq "" } {
                    set poImg [poImage NewImageFromPhoto $phImg]
                    set newImgAllocated true
                }
                set xzoom [expr {(double ($phWidth)  / $sw)}]
                set yzoom [expr {(double ($phHeight) / $sh)}]
                set zoomFact [poMisc Max $xzoom $yzoom]
                set nw [expr {int ($phWidth  / $zoomFact)}]
                set nh [expr {int ($phHeight / $zoomFact)}]
                poImageMode GetFormat savePixFmt
                $poImg GetImgInfo w h a g
                $poImg GetImgFormat fmtList
                poImageMode SetFormat $fmtList
                set poZoomImg [poImage NewImage $nw $nh]
                $poZoomImg ScaleRect $poImg 0 0 $w $h 0 0 $nw $nh true
                set sPo(phZoomImg) [image create photo -width $nw -height $nh]
                $poZoomImg AsPhoto $sPo(phZoomImg)
                poImgUtil DeleteImg $poZoomImg
                if { $newImgAllocated } {
                    poImgUtil DeleteImg $poImg
                }
                poImageMode SetFormat $savePixFmt
                $canvId create image $xpos $ypos -anchor center -image $sPo(phZoomImg) -tags tagImg
            } else {
                set xzoom [expr {($phWidth  / $sw) + 1}]
                set yzoom [expr {($phHeight / $sh) + 1}]
                set zoomFact [poMisc Max $xzoom $yzoom]
                if { [GetScaleToFitMode] && $zoomFact > 1 } {
                    set sPo(phZoomImg) [image create photo \
                                   -width  [expr {$phWidth / $zoomFact}] \
                                   -height [expr {$phHeight / $zoomFact}]]
                    $sPo(phZoomImg) copy $phImg -subsample $zoomFact
                    $canvId create image $xpos $ypos -anchor center -image $sPo(phZoomImg) -tags tagImg
                } else {
                    $canvId create image $xpos $ypos -anchor center -image $phImg -tags tagImg
                }
            }
        }
        $canvId raise tagLogoImg
        $canvId raise onscreenhelp
        set date [clock format [file mtime $imgName] -format "%Y-%m-%d %H:%M"]
        set size [file size $imgName]
        append infoStr " Size: [poMisc FormatByteSize $size]"
        append infoStr " Date: $date"
        if { $phImg ne "" } {
            append infoStr " Pixel: $phWidth x $phHeight"
            append infoStr [format " Zoom: %.0f%%" [expr 100.0 / $zoomFact]]
        } else {
            append infoStr " (No valid image)"
        }
        set sPo(imgInfoStr) $infoStr
        if { [GetShowInfoMode] } {
            UpdateInfoMsg $canvId
        }
    }

    proc AdvanceCurImgNum { { factor 1 } } {
        variable sPo

        set sPo(curImgNum) [expr {($sPo(curImgNum) + $factor * [GetSlideShowDirection]) % \
                           [llength $sPo(fileList)]}]
    }

    proc ReadImg {} {
        variable ns
        variable sPo

        set canvId $sPo(canvId)
        if { ! [winfo exists $canvId] } {
            return
        }
        $canvId config -cursor watch
        update idletasks

        set sPo(imgName) [lindex $sPo(fileList) $sPo(curImgNum)]
        set numImgs [llength $sPo(fileList)]
        set sPo(infoStr) "File [expr $sPo(curImgNum)+1] of $numImgs: [poAppearance CutFilePath $sPo(imgName)]"

        # Remove old poImg or photo images.
        ClearImg

        set retVal [catch {poImgMisc LoadImg $sPo(imgName)} imgDict]

        if { $retVal == 0 } {
            # We suceeded in reading an image from file.
            set phImg [dict get $imgDict phImg]
            set poImg [dict get $imgDict poImg]
            ShowImg $phImg $poImg
            set sPo(phImg) $phImg
            if { $poImg ne "" } {
                set sPo(poImg) $poImg
            }
        } else {
            ShowImg "" ""
        }
        if { [GetSlideShowDirection] > 0 } {
            $canvId config -cursor sb_right_arrow
        } else {
            $canvId config -cursor sb_left_arrow
        }

        set curMark [lindex $sPo(fileMark) $sPo(curImgNum)]
        if { $curMark } {
            $canvId configure -background $sPo(color,enabled)
        } else {
            $canvId configure -background $sPo(color,disabled)
        }
        update idletasks

        if { [GetAdvanceMode] eq "auto" } {
            set sPo(afterId) [after [expr {int (1000 * [GetSlideShowDuration])}] ${ns}::DelayedReadImg]
        } else {
            catch { unset sPo(afterId) }
        }
    }

    proc RotImg { angle } {
        variable sPo

        if { [poImgAppearance UsePoImg] } {
            if { ! [info exists sPo(poImg)] } {
                set sPo(poImg) [poImage NewImageFromPhoto $sPo(phImg)]
            }
            poImageMode GetFormat savePixFmt
            set poImg $sPo(poImg)
            $poImg GetImgInfo w h a g
            $poImg GetImgFormat fmtList
            poImageMode SetFormat $fmtList
            set dstImg [poImage NewImage $h $w [expr 1.0/$a] $g]
            $dstImg GetImgFormat fmtList
            $dstImg Rotate $poImg $angle
            poImgUtil DeleteImg $poImg
            set sPo(poImg) $dstImg
            $sPo(phImg) blank
            $dstImg AsPhoto $sPo(phImg)
            poImageMode SetFormat $savePixFmt
            ShowImg $sPo(phImg) $sPo(poImg)
        } else {
            set rotImg [poPhotoUtil Rotate $sPo(phImg) $angle]
            image delete $sPo(phImg)
            set sPo(phImg) $rotImg
            ShowImg $sPo(phImg) ""
        }
    }

    proc SetInitialFile { fileNameOrIndex } {
        variable sPo

        if { [string is integer $fileNameOrIndex] } {
            set imgNum $fileNameOrIndex
        } else {
            set imgNum [lsearch -exact $sPo(fileList) $fileNameOrIndex]
        }
        if { [info exists sPo(afterId)] } {
            after cancel $sPo(afterId)
            unset sPo(afterId)
        }
        ShowImgByNum $imgNum
    }

    proc DelayedReadImg {} {
        variable sPo
        variable ns

        AdvanceCurImgNum
        ReadImg
        incr sPo(imgCount)
        if { $sPo(once) && $sPo(imgCount) >= [llength $sPo(fileList)] } {
            ${ns}::ExitApp
        }
    }

    proc ShowImgByNum { imgNum } {
        variable sPo

        if { $imgNum >= 0 && $imgNum < [llength $sPo(fileList)] } {
            set sPo(curImgNum) $imgNum
            ReadImg
        }
    }

    proc ShowPrevImg { { factor 1 } } {
        variable sPo

        SetSlideShowDirection -1
        if { [GetAdvanceMode] ne "auto" } {
            AdvanceCurImgNum $factor
            ReadImg
        }
    }

    proc ShowNextImg { { factor 1 } } {
        variable sPo

        SetSlideShowDirection 1
        if { [GetAdvanceMode] ne "auto" } {
            AdvanceCurImgNum $factor
            ReadImg
        }
    }

    proc SetDuration { duration } {
        variable sPo

        SetSlideShowDuration $duration
        if { ! [info exists sPo(afterId)] } {
            ReadImg
        }
    }

    proc DecrDuration { { incrDur 0.5 } } {
        variable sPo

        IncrSlideShowDuration [expr -1.0 * $incrDur]
        if { ! [info exists sPo(afterId)] } {
            ReadImg
        }
    }

    proc IncrDuration { { incrDur 0.5 } } {
        variable sPo

        IncrSlideShowDuration $incrDur
        if { ! [info exists sPo(afterId)] } {
            ReadImg
        }
    }

    proc ToggleScaleToFit {} {
        SetScaleToFitMode [expr ! [GetScaleToFitMode]]
        ReadImg
    }

    proc ToggleTextColor {} {
        variable sPo

        set ind [lsearch $sPo(textColors) [GetTextColor]]
        set ind [expr ($ind + 1) % [llength $sPo(textColors)]]
        SetTextColor [lindex $sPo(textColors) $ind]
        ToggleOnScreenHelp
        ToggleOnScreenHelp
        if { [GetShowInfoMode] } {
            UpdateInfoMsg $sPo(canvId)
        }
    }

    proc ToggleAdvanceMode {} {
        if { [GetAdvanceMode] eq "auto" } {
            SetAdvanceMode "manual"
            StopSlideShow
        } else {
            SetAdvanceMode "auto"
            ReadImg
        }
    }

    proc ToggleMark {} {
        variable sPo

        set curMark [lindex $sPo(fileMark) $sPo(curImgNum)]
        if { $curMark } {
            lset sPo(fileMark) $sPo(curImgNum) 0
            $sPo(canvId) configure -background $sPo(color,disabled)
        } else {
            lset sPo(fileMark) $sPo(curImgNum) 1
            $sPo(canvId) configure -background $sPo(color,enabled)
        }
    }

    proc GetMarkedImgs {} {
        variable sPo

        set markedImgs [list]
        foreach file $sPo(fileList) mark $sPo(fileMark) {
            if { $mark } {
                lappend markedImgs [file normalize $file]
            }
        }
        return $markedImgs
    }

    proc StopSlideShow {} {
        variable sPo

        if { [info exists sPo(afterId)] } {
            after cancel $sPo(afterId)
            unset sPo(afterId)
        }
        if { [GetShowInfoMode] } {
            UpdateInfoMsg $sPo(canvId)
        }
    }

    proc SetMarkList { markList } {
        variable sPo

        if { [llength $markList] != [llength $sPo(fileList)] } {
            error "File list and mark list length are different."
        }
        set sPo(fileMark) $markList
        if { ! [info exists sPo(afterId)] } {
            ReadImg
        }
    }

    proc SetFileMarkList { fileMarkList } {
        variable sPo

        set markList [list]
        foreach fileName $sPo(fileList) {
            if { [lsearch -exact $fileMarkList $fileName] >= 0 } {
                lappend markList 1
            } else {
                lappend markList 0
            }
        }
        SetMarkList $markList
    }

    proc StartSlideShow { fileList } {
        variable sPo

        if { [llength $fileList] > 0 } {
            poApps StartApp poSlideShow $fileList
        }
    }

    proc LoadInImgview {} {
        variable sPo

        set imgName [lindex $sPo(fileList) $sPo(curImgNum)]
        poImgview ShowMainWin
        poImgview ReadImg $imgName
        poWin Raise $sPo(tw)
        focus $sPo(tw)
    }

    proc ClearImg {} {
        variable sPo

        if { [info exists sPo(phImg)] } {
            image delete $sPo(phImg)
            unset sPo(phImg)
        }
        if { [info exists sPo(phZoomImg)] } {
            image delete $sPo(phZoomImg)
            unset sPo(phZoomImg)
        }
        if { [info exists sPo(poImg)] } {
            poImgUtil DeleteImg $sPo(poImg)
            unset sPo(poImg)
        }
    }

    proc GetShortcutMsg { useOnlineMsg } {
        append msg "Escape     : Leave slide show (cancel marks).\n"
        append msg "Return     : Leave slide show (use marks).\n"
        append msg "Left/Right : Goto previous/next image in manual mode.\n"
        append msg "             Set slide show direction in automatic mode.\n"
        append msg "Shift-L/R  : Use an increment of 10 for previous/next image.\n"
        append msg "Home       : Goto first image in manual mode.\n"
        append msg "Down/Up    : Decrease/Increase slide duration by 0.5 seconds.\n"
        append msg "0 .. 9     : Set slide show duration to specified seconds.\n"
        append msg "s          : Toggle automatic/manual advance mode.\n"
        append msg "v          : Load current image into poImgview.\n"
        append msg "l/r        : Rotate current image by 90° to the left or right.\n"
        append msg "Space      : Toggle image marking.\n"
        append msg "f          : Toggle scale to fit mode.\n"
        append msg "c          : Switch text colors: white, blue, red, yellow.\n"
        append msg "i          : Toggle display of info line.\n"
        if { $useOnlineMsg } {
            append msg "h          : Toggle this help message.\n"
        } else {
            append msg "h          : Toggle shortcut help on slide show screen.\n"
        }

        return $msg
    }

    proc GetUsageMsg {} {
        variable sPo

        set msg ""
        append msg "\n"
        append msg "poApps: $sPo(appName) \[Options\] \[DirOrImageFile1\] \[DirOrImageFileN\]\n"
        append msg "\n"
        append msg "Display the supplied image files or images contained in supplied directories\n"
        append msg "as a slide show.\n"
        append msg "\n"
        append msg "Options:\n"
        append msg "--duration <int>   : Display duration of each image in seconds.\n"
        append msg "                     Current setting: [GetSlideShowDuration].\n"
        append msg "--direction <int>  : Slide show direction.\n"
        append msg "                     Possible values 1 (forwards) or -1 (backwards).\n"
        append msg "                     Current setting: [GetSlideShowDirection].\n"
        append msg "--mode <string>    : Slide advance mode.\n"
        append msg "                     Possible values: \"auto\", \once\" or \"manual\".\n"
        append msg "                     Current setting: \"[GetAdvanceMode]\".\n"
        append msg "--fit <bool>       : Scale image to fit screen size.\n"
        append msg "                     Current setting: [GetScaleToFitMode].\n"
        append msg "--showinfo <bool>  : Show image information.\n"
        append msg "                     Current setting: [GetShowInfoMode].\n"
        append msg "--showlogo <string>: Add specified image file as logo in the top-right corner.\n"
        append msg "\n"
        append msg "Shortcuts:\n"
        append msg [GetShortcutMsg false]

        return $msg
    }

    proc LoadSettings { cfgDir } {
        variable sPo

        # Init all variables stored in the cfg file with default values.
        SetSlideShowDuration  2
        SetSlideShowDirection 1
        SetAdvanceMode        "auto"
        SetScaleToFitMode     1
        SetShowInfoMode       1
        SetTextColor          "white"
        SetEnabledColor       "green"
        SetDisabledColor      "black"
        SetUseLogoFile        0
        SetLogoFile           ""

        # Now try to read the cfg file.
        set cfgFile [file normalize [poCfgFile GetCfgFilename $sPo(appName) $cfgDir]]
        if { [poMisc IsReadableFile $cfgFile] } {
            set sPo(initStr) "Settings loaded from file $cfgFile"
            source $cfgFile
        } else {
            set sPo(initStr) "No settings file \"$cfgFile\" found. Using default values."
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
            PrintCmd $fp "SlideShowDuration"
            PrintCmd $fp "SlideShowDirection"
            PrintCmd $fp "AdvanceMode"
            PrintCmd $fp "ScaleToFitMode"
            PrintCmd $fp "ShowInfoMode"
            PrintCmd $fp "TextColor"
            PrintCmd $fp "EnabledColor"
            PrintCmd $fp "DisabledColor"
            PrintCmd $fp "UseLogoFile"
            PrintCmd $fp "LogoFile"

            close $fp
        }
    }

    proc CloseAppWindow { { returnFlag false } } {
        variable sPo

       if { ! [info exists sPo(tw)] || ! [winfo exists $sPo(tw)] } {
            return
        }

        if { [info exists sPo(afterId)] } {
            after cancel $sPo(afterId)
            unset sPo(afterId)
        }

        if { [poApps GetAutosaveOnExit] } {
            SaveSettings
        }

        # Delete image.
        ClearImg

        # Delete main toplevel of this application.
        wm attributes $sPo(tw) -fullscreen 0
        destroy $sPo(tw)

        # Show the main app window, which might be iconified.
        poApps StartApp deiconify

        return $returnFlag
    }

    proc ExitApp {} {
        poApps ExitApp
    }

    # Functions for handling the settings window of this module.

    proc CloseWin { w } {
        destroy $w
    }

    proc CancelWin { w args } {
        variable sPo

        foreach pair $args {
            set var [lindex $pair 0]
            set val [lindex $pair 1]
            set cmd [format "set %s %s" $var $val]
            eval $cmd
        }
        CloseWin $w
    }

    proc OkWin { w } {
        CloseWin $w
    }

    proc GetLogoFileFromWinSelect { comboId } {
        variable sPo

        set sPo(logoFile) [poWinSelect GetValue $comboId]
    }

    proc _GetColor { buttonId type } {
        variable sPo

        set newColor [tk_chooseColor -initialcolor $sPo(color,$type)]
        if { $newColor ne "" } {
            set sPo(color,$type) $newColor
            # Color settings window may have already been closed. So catch it.
            catch { $buttonId configure -background $newColor }
        }
    }

    proc OpenWin { fr } {
        variable ns
        variable sPo

        set tw $fr

        # Generate left column with text labels.
        set row 0
        foreach labelStr [list \
                           "Slide show duration (seconds):" \
                           "Slide show direction:" \
                           "Advance mode:" \
                           "View options:" \
                           "Color of text:" \
                           "Background color of enabled slides:" \
                           "Background color of disabled slides:" \
                           "Show logo:" ] {
            ttk::label $tw.l$row -text $labelStr
            grid $tw.l$row -row $row -column 0 -sticky new
            incr row
        }

        set varList [list]

        # Generate right column with entries and buttons.
        # Row 0: Slide show duration
        set row 0
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        poWin CreateCheckedRealEntry $tw.fr$row ${ns}::sPo(slideDuration) -row $row -width 5 -min 0

        set tmpList [list [list sPo(slideDuration)] [list $sPo(slideDuration)]]
        lappend varList $tmpList

        # Row 1: Slide show direction
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::radiobutton $tw.fr$row.rb1 -text "Forwards" \
                    -variable ${ns}::sPo(slideDirection) -value 1
        ttk::radiobutton $tw.fr$row.rb2 -text "Backwards" \
                    -variable ${ns}::sPo(slideDirection) -value -1
        pack $tw.fr$row.rb1 $tw.fr$row.rb2 -side left -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(slideDirection)] [list $sPo(slideDirection)]]
        lappend varList $tmpList

        # Row 2: Slide show advance mode
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::radiobutton $tw.fr$row.rb1 -text "Automatic" \
                    -variable ${ns}::sPo(slideAdvanceMode) -value "auto"
        ttk::radiobutton $tw.fr$row.rb2 -text "Manual" \
                    -variable ${ns}::sPo(slideAdvanceMode) -value "manual"
        pack $tw.fr$row.rb1 $tw.fr$row.rb2 -side left -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(slideAdvanceMode)] [list $sPo(slideAdvanceMode)]]
        lappend varList $tmpList

        # Row 3: View options
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        ttk::checkbutton $tw.fr$row.cb1 -text "Scale to fit" \
                    -variable ${ns}::sPo(scaleToFitMode) \
                    -onvalue 1 -offvalue 0
        ttk::checkbutton $tw.fr$row.cb2 -text "Show image info" \
                    -variable ${ns}::sPo(showInfoMode) \
                    -onvalue 1 -offvalue 0
        pack $tw.fr$row.cb1 $tw.fr$row.cb2 -side top -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(scaleToFitMode)] [list $sPo(scaleToFitMode)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(showInfoMode)] [list $sPo(showInfoMode)]]
        lappend varList $tmpList

        # Row 4: Color of text
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(color,text)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l text"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(color,text)] [list $sPo(color,text)]]
        lappend varList $tmpList

        # Row 5: Background color of enabled slides
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(color,enabled)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l enabled"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(color,enabled)] [list $sPo(color,enabled)]]
        lappend varList $tmpList

        # Row 6: Background color of disabled slides
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky new

        label $tw.fr$row.l -width 10 -relief sunken -background $sPo(color,disabled)
        ttk::button $tw.fr$row.b -text "Select ..." \
                                 -command "${ns}::_GetColor $tw.fr$row.l disabled"
        pack $tw.fr$row.l $tw.fr$row.b -side left -fill x -expand 1

        set tmpList [list [list sPo(color,disabled)] [list $sPo(color,disabled)]]
        lappend varList $tmpList

        # Row 7: Logo options
        incr row
        ttk::frame $tw.fr$row
        grid $tw.fr$row -row $row -column 1 -sticky news

        ttk::checkbutton $tw.fr$row.cb -text "Use logo file" \
                         -variable ${ns}::sPo(useLogoFile) \
                         -onvalue 1 -offvalue 0

        ttk::frame $tw.fr$row.fr
        pack $tw.fr$row.fr -expand 1 -fill both
        set comboId [poWinSelect CreateFileSelect $fr.fr$row.fr $sPo(logoFile) "open" \
                                 "Select ..." "Select logo file"]
        poWinSelect SetFileTypes $comboId [poImgType GetSelBoxTypes]
        bind $comboId <<NameValid>> "${ns}::GetLogoFileFromWinSelect $comboId"
        pack $tw.fr$row.cb $tw.fr$row.fr -side top -anchor w -in $tw.fr$row

        set tmpList [list [list sPo(useLogoFile)] [list $sPo(useLogoFile)]]
        lappend varList $tmpList
        set tmpList [list [list sPo(logoFile)] [list $sPo(logoFile)]]
        lappend varList $tmpList

        return $varList
    }

    proc ParseCommandLine { argList } {
        variable sPo

        set sPo(fileList) [list]
        set sPo(fileMark) [list]
        set sPo(once)     false
        set curArg 0
        while { $curArg < [llength $argList] } {
            set curParam [lindex $argList $curArg]
            if { [string compare -length 1 $curParam "-"]  == 0 || \
                 [string compare -length 2 $curParam "--"] == 0 } {
                set curOpt [string tolower [string trimleft $curParam "-"]]
                if { $curOpt eq "duration" } {
                    incr curArg
                    SetSlideShowDuration [poMisc Max 0 [lindex $argList $curArg]]
                } elseif { $curOpt eq "direction" } {
                    incr curArg
                    SetSlideShowDirection [expr [lindex $argList $curArg] > 0? 1: -1]
                } elseif { $curOpt eq "mode" } {
                    incr curArg
                    set advanceMode [lindex $argList $curArg]
                    if { $advanceMode eq "once" } {
                        set advanceMode "auto"
                        set sPo(once) true
                    }
                    SetAdvanceMode $advanceMode
                } elseif { $curOpt eq "fit" } {
                    incr curArg
                    SetScaleToFitMode [expr [lindex $argList $curArg]? 1: 0]
                } elseif { $curOpt eq "showinfo" } {
                    incr curArg
                    SetShowInfoMode [expr [lindex $argList $curArg]? 1: 0]
                } elseif { $curOpt eq "showlogo" } {
                    incr curArg
                    SetUseLogoFile 1
                    SetLogoFile [lindex $argList $curArg]
                }
            } else {
                if { [file isdirectory $curParam] } {
                    set dirCont [lsort -dictionary \
                        [lindex [poMisc GetDirsAndFiles $curParam \
                                        -showdirs false \
                                        -showhiddendirs false \
                                        -showhiddenfiles false] 1]]
                    ShowInfoMsg $sPo(canvId) 50 50 "Scanning directory $curParam for images ..."
                    set imgsFound 0
                    foreach f $dirCont {
                        set f [file normalize [file join $curParam $f]]
                        if { [poImgMisc IsImageFile $f] } {
                            lappend sPo(fileList) $f
                            lappend sPo(fileMark) 0
                            incr imgsFound
                            if { $imgsFound % 50 == 0 } {
                                ShowInfoMsg $sPo(canvId) 50 50 "Scanning directory $curParam for images ($imgsFound found) ..."
                            }
                        }
                    }
                } elseif { [poImgMisc IsImageFile $curParam] } {
                    ShowInfoMsg $sPo(canvId) 50 50 "Adding image $curParam ..."
                    lappend sPo(fileList) [file normalize $curParam]
                    lappend sPo(fileMark) 0
                }
            }
            incr curArg
        }
        ShowInfoMsg $sPo(canvId) 50 50 ""
        set sPo(curImgNum) 0
        set sPo(imgCount)  0
        if { [llength $sPo(fileList)] > 0 } {
            ReadImg
            AddLogo $sPo(canvId)
        } else {
            CloseAppWindow
            tk_messageBox -message "No images available in supplied parameters." -title "Information" \
                          -type ok -icon info
        }
    }

    proc IsOpen {} {
        variable sPo

        return [winfo exists $sPo(tw)]
    }
}

poSlideShow Init
catch {poLog Debug "Loaded Package poApplib (Module [info script])"}
