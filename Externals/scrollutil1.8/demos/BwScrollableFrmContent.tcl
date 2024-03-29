#==============================================================================
# Populates the content frame of the BWidget ScrollableFrame widget created in
# the demo script BwScrollableFrmDemo2.tcl.
#
# Copyright (c) 2019-2021  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Add an entry to the Tk option database
#
tablelist::setThemeDefaults
option add *selectBorderWidth	$tablelist::themeDefaults(-selectborderwidth)

#
# Create some widgets in the content frame
#

#
# A scrolled text widget with old-school mouse wheel support
#
set row 0
set l [ttk::label $cf.l$row -text \
       "Contents of the Tablelist distribution file \"CHANGES.txt\":"]
grid $l -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {7p 0}
incr row
set _sa [scrollutil::scrollarea $cf.sa$row]
set txt [text $_sa.txt -font TkFixedFont -width 73]
scrollutil::addMouseWheelSupport $txt
$_sa setwidget $txt
grid $_sa -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {4p 0}

#
# A scrolled listbox widget
#
incr row
set l [ttk::label $cf.l$row -text "Tablelist releases:"]
grid $l -row $row -column 0 -sticky w -padx {7p 0} -pady {7p 0}
incr row
set _sa [scrollutil::scrollarea $cf.sa$row]
set lb [listbox $_sa.lb -width 0]
$_sa setwidget $lb
grid $_sa -row $row -rowspan 6 -column 0 -sticky w -padx {7p 0} -pady {4p 0}

#
# A ttk::combobox widget
#
set l [ttk::label $cf.l$row -text "Release:"]
grid $l -row $row -column 1 -sticky w -padx {7p 0} -pady {4p 0}
set cb [ttk::combobox $cf.cb -state readonly -width 14]
bind $cb <<ComboboxSelected>> updateWidgets
grid $cb -row $row -column 2 -sticky w -padx {4p 7p} -pady {4p 0}

#
# A ttk::spinbox widget
#
incr row
set l [ttk::label $cf.l$row -text "Changes:"]
grid $l -row $row -column 1 -sticky w -padx {7p 0} -pady {7p 0}
set sb [ttk::spinbox $cf.sb -from 0 -to 20 -state readonly -width 4]
grid $sb -row $row -column 2 -sticky w -padx {4p 7p} -pady {7p 0}

#
# A ttk::entry widget
#
incr row
set l [ttk::label $cf.l$row -text "Comment:"]
grid $l -row $row -column 1 -sticky w -padx {7p 0} -pady {7p 0}
set e [ttk::entry $cf.e -width 32]
grid $e -row $row -column 2 -sticky w -padx {4p 7p} -pady {7p 0}

#
# A ttk::separator widget
#
incr row
set sep [ttk::separator $cf.sep]
grid $sep -row $row -column 1 -columnspan 2 -sticky we -padx 7p -pady {7p 0}

#
# A mentry widget of type "Date"
#
incr row
set l [ttk::label $cf.l$row -text "Date of first release:"]
grid $l -row $row -column 1 -sticky w -padx {7p 0} -pady {7p 0}
set me [mentry::dateMentry $cf.me Ymd -]
grid $me -row $row -column 2 -sticky w -padx {4p 7p} -pady {7p 0}

incr row
grid rowconfigure $cf $row -weight 1

#
# A scrolled tablelist widget
#
incr row
set l [ttk::label $cf.l$row -text \
       "Tablelist release statistics, displayed in a tablelist widget:"]
grid $l -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {7p 0}
incr row
set _sa [scrollutil::scrollarea $cf.sa$row]
set tbl [tablelist::tablelist $_sa.tbl \
	 -columns {0 "Release" left  0 "Changes" right  0 "Comment" left} \
	 -height 16 -width 0 -showseparators yes -incrarrowtype down \
	 -labelcommand tablelist::sortByColumn]
if {$ttk::currentTheme ne "aqua"} {
    $tbl configure -background white -stripebackground #f0f0f0
}
if {[$tbl cget -selectborderwidth] == 0} {
    $tbl configure -spacing 1
}
$tbl columnconfigure 0 -name release -sortmode dictionary
$tbl columnconfigure 1 -name changes -sortmode integer
$tbl columnconfigure 2 -name comment
$_sa setwidget $tbl
grid $_sa -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {4p 0}

#
# On X11 configure the tablelist according to the display's
# DPI scaling level (redundant for Tablelist 6.10 and later)
#
if {[tk windowingsystem] eq "x11"} {
    array set arr {100 8x4  125 9x5  150 11x6  175 13x7  200 15x8}
    $tbl configure -arrowstyle flat$arr($scrollutil::scalingpct)
}

#
# A scrolled ttk::treeview widget
#
incr row
set l [ttk::label $cf.l$row -text \
       "Tablelist release statistics, displayed in a ttk::treeview widget:"]
grid $l -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {7p 0}
incr row
set _sa [scrollutil::scrollarea $cf.sa$row -borderwidth 0]
set font [ttk::style lookup Treeview -font]
ttk::style configure Treeview -rowheight \
    [expr {[font metrics $font -linespace] + 3}]
set tv [ttk::treeview $_sa.tv -columns {release changes comment} \
	-show headings -height 16 -selectmode browse]
if {$ttk::currentTheme eq "aqua" &&
    [package vcompare $::tk_patchLevel "8.6.10"] >= 0} {
    $_sa configure -borderwidth 1 ;# because in this case $tv has a flat relief
}
$tv heading release -text " Release" -anchor w
$tv heading changes -text "Changes " -anchor e
$tv heading comment -text " Comment" -anchor w
$tv column release -anchor w
$tv column changes -anchor e
$tv column comment -anchor w
$_sa setwidget $tv
grid $_sa -row $row -column 0 -columnspan 3 -sticky w -padx 7p -pady {4p 7p}

grid columnconfigure $cf 2 -weight 1

#
# Populate the widgets
#

set chan [open [file join $tablelist::library "CHANGES.txt"]]
set content [read -nonewline $chan]
close $chan
$txt insert end $content

#
# Make the text widget readonly
#
$txt configure -insertwidth 0
wcb::callback $txt before insert cancelEdit
wcb::callback $txt before delete cancelEdit

set lineList [split $content "\n"]
set totalChanges 0
set lineIdx 0
set latest true
foreach line $lineList {
    if {[string match "What *" $line]} {
	if {$lineIdx != 0} {
	    if {$changes == 0} {
		set changes 1
	    }
	    switch $version {
		6.0 { set comment "Added support for header items" }
		5.0 { set comment "Added support for tree functionality" }
		4.0 { set comment "Added support for the tile engine" }
		3.0 { set comment "Added support for interactive cell editing" }
		2.0 { set comment "Added support for embedded images" }
		default {
		    if {$latest} {
			set comment "Latest release"
			set latest false
		    } else {
			set comment ""
		    }
		}
	    }
	    set item [list "Tablelist $version" $changes $comment]
	    $tbl insert end $item
	    $tv insert {} end -values $item
	    incr totalChanges $changes
	}

	set idx [string last " " $line]
	set version [string range $line [incr idx] end-1]
	$lb insert end "Tablelist $version"

	set changes 0
    } elseif {[string match {[1-9]*} $line]} {
	incr changes
    }

    incr lineIdx
}

if {$changes == 0} {
    set changes 1
}
set comment ""
set item [list "Tablelist $version" $changes $comment]
$tbl insert end $item
$tv insert {} end -values $item
incr totalChanges $changes

$lb insert end "Tablelist 0.8"
set item [list "Tablelist 0.8" 0 "First release, on 2000-10-27"]
$tbl insert end $item
$tv insert {} end -values $item

$tbl header insert 0 \
     [list "All [$tbl size] releases" $totalChanges "Total number"]
$tbl header rowconfigure 0 -foreground blue

if {$ttk::currentTheme eq "aqua" &&
    [package vcompare $tk_patchLevel "8.6.10"] >= 0} {
    if {[tk::unsupported::MacWindowStyle isdark .]} {
	$tbl header rowconfigure 0 -foreground SkyBlue
    }
    bind . <<LightAqua>> { $tbl header rowconfigure 0 -foreground blue }
    bind . <<DarkAqua>>  { $tbl header rowconfigure 0 -foreground SkyBlue }
}

$cb configure -values [$lb get 0 end]
$cb current 0

$sb set [$tbl getcells 0,changes]
$e insert 0 [$tbl getcells 0,comment]
$me put 0 2000 10 27

#
# Make the columns of the treeview as wide as those of the tablelist
#
foreach colId [$tv cget -columns] {
    $tv column $colId -width [$tbl columnwidth $colId -total]
}

#
# Set the ScrollableFrame's width, height, and yscrollincrement
#
wm withdraw .
update idletasks
set width [winfo reqwidth $cf]
set height [expr {[winfo reqheight $cf.l0] + [winfo pixels . 4p] + \
		  [winfo reqheight $cf.sa1] + 2*[winfo pixels . 7p]}]
$sf configure -width $width -height $height \
    -yscrollincrement [expr {[winfo reqheight $lb] / 10}]

pack $sa -expand yes -fill both -padx 7p -pady 7p

#
# Create two ttk::button widgets within a frame outside the scrollarea
#
set bf [ttk::frame .bf]
set b1 [ttk::button $bf.b1 -text "Configure Tablelist Widget" \
        -command configTablelist]
set b2 [ttk::button $bf.b2 -text "Close" -command exit]
pack $b2 -side right -padx 7p -pady {0 7p}
pack $b1 -side left -padx 7p -pady {0 7p}

pack $bf -side bottom -fill x
pack $tf -side top -expand yes -fill both

wm deiconify .

#
# Work around a potential accuracy problem related to [$sf xview]
#
tkwait visibility $sf
while {[lindex [$sf xview] 1] != 1.0} {
    $sf configure -width [incr width]
    update idletasks
}

#------------------------------------------------------------------------------

proc updateWidgets {} {
    global cb tbl sb e
    set release [$cb get]
    set idx [$tbl searchcolumn 0 $release]
    set item [$tbl get $idx]
    $sb set [lindex $item 1]
    $e delete 0 end; $e insert 0 [lindex $item 2]
    $tbl selection clear 0 end; $tbl selection set $idx; $tbl see $idx
}

#------------------------------------------------------------------------------

proc cancelEdit {w args} {
    wcb::cancel
}

#------------------------------------------------------------------------------

proc configTablelist {} {
    set top .top
    if {[winfo exists $top]} {
	raise $top
	focus $top
	return ""
    }

    toplevel $top
    wm title $top "Tablelist Widget Configuration"

    #
    # Create a ScrollableFrame within a scrollarea
    #
    set f  [ttk::frame $top.f]
    set sa [scrollutil::scrollarea $f.sa]
    set sf [ScrollableFrame $sa.sf -constrainedwidth yes]
    $sa setwidget $sf

    #
    # Work around a tile bug which is not handled in
    # the BWidget procedure ScrollableFrame::create
    #
    if {$ttk::currentTheme eq "aqua" &&
	[package vcompare $::tk_patchLevel "8.6.10"] < 0} {
	$sf:cmd configure -background #ececec
    }

    #
    # Register the ScrollableFrame for scrolling by the mouse wheel event
    # bindings created by the scrollutil::createWheelEventBindings command
    #
    scrollutil::enableScrollingByWheel $sf

    #
    # Get the content frame
    #
    set cf [$sf getframe]

    #
    # Create some widgets in the content frame, corresponding
    # to the configuration options of the tablelist widget
    #
    global tbl
    set row 0
    foreach configSet [$tbl configure] {
	if {[llength $configSet] != 5} {
	    continue
	}

	set opt [lindex $configSet 0]
	set w [ttk::label $cf.l$row -text $opt]
	grid $w -row $row -column 0 -sticky w -padx {4p 0} -pady {4p 0}

	set w $cf.w$row
	switch -- $opt {
	    -activestyle -
	    -arrowstyle -
	    -incrarrowtype -
	    -labelrelief -
	    -relief -
	    -selectmode -
	    -selecttype -
	    -state -
	    -treestyle {
		ttk::combobox $w -state readonly -width 12

		switch -- $opt {
		    -activestyle { set values {frame none underline} }
		    -arrowstyle {
			set values $tablelist::arrowStyles   ;# dirty, but safe
		    }
		    -incrarrowtype { set values {up down} }
		    -labelrelief -
		    -relief {
			set values {flat groove raised ridge solid sunken}
		    }
		    -selectmode { set values {single browse multiple extended} }
		    -selecttype { set values {row cell} }
		    -state { set values {disabled normal} }
		    -treestyle {
			set values $tablelist::treeStyles    ;# dirty, but safe
		    }
		}

		$w configure -values $values
		$w set [$tbl cget $opt]
		bind $w <<ComboboxSelected>> [list applyValue %W $opt]
		grid $w -row $row -column 1 -sticky w -padx 4p -pady {4p 0}

		#
		# Adapt the handling of the mouse wheel
		# events for the ttk::combobox widget
		#
		scrollutil::adaptWheelEventHandling $w
	    }

	    -autofinishediting -
	    -autoscan -
	    -customdragsource -
	    -displayondemand -
	    -editendonfocusout -
	    -editendonmodclick -
	    -editselectedonly -
	    -exportselection -
	    -forceeditendcommand -
	    -fullseparators -
	    -instanttoggle -
	    -movablecolumns -
	    -movablerows -
	    -protecttitlecolumns -
	    -resizablecolumns -
	    -setfocus -
	    -setgrid -
	    -showarrow -
	    -showbusycursor -
	    -showeditcursor -
	    -showhorizseparator -
	    -showlabels -
	    -showseparators -
	    -tight {
		ttk::checkbutton $w -command [list applyBoolean $w $opt]
		global $w
		set $w [$tbl cget $opt]
		$w configure -text [expr {[set $w] ? "true": "false"}]
		grid $w -row $row -column 1 -sticky w -padx 4p -pady {4p 0}
	    }

	    -borderwidth -
	    -height -
	    -highlightthickness -
	    -labelborderwidth -
	    -labelheight -
	    -labelpady -
	    -selectborderwidth -
	    -spacing -
	    -stripeheight -
	    -titlecolumns -
	    -treecolumn -
	    -width {
		ttk::spinbox $w -from 0 -to 999 -width 4 -command \
		    [list applyValue $w $opt]
		$w set [$tbl cget $opt]
		$w configure -invalidcommand bell -validate key \
		    -validatecommand \
		    {expr {[string length %P] <= 3 && [regexp {^[0-9]*$} %S]}}
		foreach event {<Return> <KP_Enter> <FocusOut>} {
		    bind $w $event [list applyValue %W $opt]
		}
		grid $w -row $row -column 1 -sticky w -padx 4p -pady {4p 0}

		#
		# Adapt the handling of the mouse wheel
		# events for the ttk::spinbox widget
		#
		scrollutil::adaptWheelEventHandling $w
	    }

	    default {
		ttk::entry $w -width 20
		$w insert 0 [$tbl cget $opt]
		foreach event {<Return> <KP_Enter> <FocusOut>} {
		    bind $w $event [list applyValue %W $opt]
		}
		grid $w -row $row -column 1 -sticky we -padx 4p -pady {4p 0}
	    }
	}

	#
	# Make the keyboard navigation more user-friendly
	#
	bind $w <<TraverseIn>> [list $sf see %W]

	incr row
    }

    grid rowconfigure    $cf all -uniform AllRows
    grid columnconfigure $cf 1   -weight 1

    #
    # Set the ScrollableFrame's width, height, and yscrollincrement
    #
    update idletasks
    set rowHeight [expr {[winfo reqheight $cf] / $row}]
    set height [expr {10*$rowHeight + [winfo pixels .top 4p]}]
    $sf configure -width [winfo reqwidth $cf] -height $height \
	-yscrollincrement $rowHeight

    #
    # Create a ttk::button widget outside the scrollarea
    #
    set b [ttk::button $f.b -text "Close" -command [list destroy $top]]

    pack $b  -side bottom -pady {0 7p}
    pack $sa -side top -expand yes -fill both -padx 7p -pady 7p
    pack $f  -expand yes -fill both
}

#------------------------------------------------------------------------------

proc applyValue {w opt} {
    global tbl
    if {[catch {$tbl configure $opt [$w get]} result] != 0} {
	bell
	tk_messageBox -title "Error" -icon error -message $result \
	    -parent [winfo toplevel $w]
	### $w set [$tbl cget $opt]		;# not supported by ttk::entry
	$w delete 0 end
	$w insert 0 [$tbl cget $opt]
    }
}

#------------------------------------------------------------------------------

proc applyBoolean {w opt} {
    global tbl $w
    set val [set $w]
    $tbl configure $opt $val
    $w configure -text [expr {$val ? "true" : "false"}]
}
