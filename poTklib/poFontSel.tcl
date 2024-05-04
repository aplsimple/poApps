# Module:         poFontSel
# Copyright:      Paul Obermeier 2001-2023 / paul@poSoft.de
# First Version:  2001 / 11 / 12
#
# Distributed under BSD license.
#
# Module for displaying a font selection window.

namespace eval poFontSel {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export OpenWin

    proc Init {} {
        variable pkgInt
        variable fontSpec

        # default values
        set pkgInt(size)       12
        set pkgInt(family)     [lindex [lsort -dictionary [font families]] 0]
        set pkgInt(slant)      roman
        set pkgInt(weight)     normal
        set pkgInt(overstrike) 0
        set pkgInt(underline)  0

        set fontSpec [list \
                -family     $pkgInt(family) \
                -size       $pkgInt(size) \
                -weight     $pkgInt(weight) \
                -underline  $pkgInt(underline) \
                -slant      $pkgInt(slant) \
                -overstrike $pkgInt(overstrike) \
        ]
    }

    proc _FontOkCmd {} {
        variable pkgInt

        set pkgInt(fontFlag) 1
    }

    proc _FontCancelCmd {} {
        variable pkgInt

        set pkgInt(fontFlag) 0
    }

    proc OpenWin { x y { font "" } } {
        variable ns
        variable fontSpec
        variable pkgInt

        set tw ".poFontSel_mainWin"
        if { [winfo exists $tw] } {
            destroy $tw
        }

        toplevel $tw
        wm overrideredirect $tw true
        if { [tk windowingsystem] eq "aqua" }  {
            ::tk::unsupported::MacWindowStyle style $tw help none
        }
        wm geometry $tw [format "+%d+%d" $x [expr $y +10]]

        ttk::frame $tw.fr -borderwidth 4 -relief raised
        pack $tw.fr

        # The main two areas: a frame to hold the font picker widgets
        # and a label to display a sample from the font
        set fp  [frame $tw.fr.fp]
        set msg [label $tw.fr.msg -borderwidth 2 -relief groove -width 30 -bg white]
        set btn [frame $tw.fr.btn]

        pack $fp  -side top -fill x
        pack $msg -side top -fill both -expand y -pady 2
        pack $btn -side top -fill x

        $msg configure -text [join [list \
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
                "abcdefghijklmnopqrstuvwxyz" \
                "0123456789~`!@#$%^&*()_-+=" \
                "{}[]:;\"'<>,.?/"] "\n"]

        if { $font ne "" } {
            set pkgInt(size)       [font actual $font -size]
            set pkgInt(family)     [font actual $font -family]
            set pkgInt(slant)      [font actual $font -slant]
            set pkgInt(weight)     [font actual $font -weight]
            set pkgInt(overstrike) [font actual $font -overstrike]
            set pkgInt(underline)  [font actual $font -underline]
        }
        # this will set the font of the message according to our defaults
        _ChangeFont $msg

        # font family...
        label $fp.famLabel -text "Font Family:"
        ttk::combobox $fp.famCombo \
                -textvariable ${ns}::pkgInt(family) \
                -state readonly
        bind $fp.famCombo <<ComboboxSelected>> "${ns}::_ChangeFont $msg"

        pack $fp.famLabel -side left
        pack $fp.famCombo -side left -fill x -expand y

        # we'll do these one at a time so we can find the widest one and
        # set the width of the combobox accordingly (hmmm... wonder if this
        # sort of thing should be done by the combobox itself...?)
        set widest 0
        foreach family [lsort -dictionary [font families]] {
            if {[set length [string length $family]] > $widest} {
                set widest $length
            }
        }
        $fp.famCombo configure -values [lsort -dictionary [font families]]
        $fp.famCombo configure -width $widest

        # the font size. We know we are puting a fairly small, finite
        # number of items in this combobox, so we'll set its maxheight
        # to zero so it will grow to fit the number of items
        label $fp.sizeLabel -text "Font Size:"
        ttk::combobox $fp.sizeCombo \
                -width 3 \
                -textvariable ${ns}::pkgInt(size) \
                -state normal
        bind $fp.sizeCombo <<ComboboxSelected>> "${ns}::_ChangeFont $msg"

        pack $fp.sizeLabel -side left
        pack $fp.sizeCombo -side left
        $fp.sizeCombo configure -values [list 8 9 10 11 12 14 16 18 20 22 24 26 28 36 48 72]

        # a dummy frame to give a little spacing...
        frame $fp.dummy -width 5
        pack $fp.dummy -side left

        # bold
        checkbutton $fp.bold -variable ${ns}::pkgInt(weight) \
                -indicatoron false -onvalue bold -offvalue normal \
                -text "B" -width 2 -height 1 \
                -font {-weight bold -family Times -size 10} \
                -highlightthickness 1 -padx 0 -pady 0 -borderwidth 1 \
                -command [list ${ns}::_ChangeFont $msg]
        pack $fp.bold -side left

        # underline
        checkbutton $fp.underline -variable ${ns}::pkgInt(underline) \
                -indicatoron false -onvalue 1 -offvalue 0 \
                -text "U" -width 2 -height 1 \
                -font {-underline 1 -family Times -size 10} \
                -highlightthickness 1 -padx 0 -pady 0 -borderwidth 1 \
                -command [list ${ns}::_ChangeFont $msg]
        pack $fp.underline -side left

        # italic
        checkbutton $fp.italic -variable ${ns}::pkgInt(slant) \
                -indicatoron false -onvalue italic -offvalue roman \
                -text "I" -width 2 -height 1 \
                -font {-slant italic -family Times -size 10} \
                -highlightthickness 1 -padx 0 -pady 0 -borderwidth 1 \
                -command [list ${ns}::_ChangeFont $msg]
        pack $fp.italic -side left

        # overstrike
        checkbutton $fp.overstrike -variable ${ns}::pkgInt(overstrike) \
                -indicatoron false -onvalue 1 -offvalue 0 \
                -text "O" -width 2 -height 1 \
                -font {-overstrike 1 -family Times -size 10} \
                -highlightthickness 1 -padx 0 -pady 0 -borderwidth 1 \
                -command [list ${ns}::_ChangeFont $msg]
        pack $fp.overstrike -side left 

        ttk::button $btn.close -text "OK" -command "${ns}::_FontOkCmd"
        pack $btn.close -side left -expand 1 -fill x

        bind $tw <KeyPress-Return> "${ns}::_FontOkCmd"
        bind $tw <KeyPress-Escape> "${ns}::_FontCancelCmd"

        update 
 
        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if { $oldGrab ne "" } {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $fp.famCombo

        tkwait variable ${ns}::pkgInt(fontFlag)

        catch { focus $oldFocus }
        grab release $tw
        destroy $tw
        if { $oldGrab ne "" } {
            if { $grabStatus eq "global" } {
                grab -global $oldGrab
            } else {
                grab $oldGrab
            }
        }

        if { $pkgInt(fontFlag) } {
            return $fontSpec
        } else {
            return ""
        }
    }

    proc _ChangeFont { w args } {
        # this proc changes the font. It is called by various methods, so
        # the only parameter we are guaranteed is the first one, since
        # we supply it ourselves...

        variable ns
        variable fontSpec
        variable pkgInt

        foreach foo [list family size weight underline slant overstrike] {
            if {[set ${ns}::pkgInt($foo)] == ""} {
                return
            }
        }
        set fontSpec [list \
                -family     $pkgInt(family) \
                -size       $pkgInt(size) \
                -weight     $pkgInt(weight) \
                -underline  $pkgInt(underline) \
                -slant      $pkgInt(slant) \
                -overstrike $pkgInt(overstrike) \
        ]
        $w configure -font $fontSpec
    }
}

poFontSel Init
