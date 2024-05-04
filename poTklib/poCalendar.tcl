# Module:         poCalendar
# Copyright:      Paul Obermeier 2001-2023 / paul@poSoft.de
# First Version:  2001 / 08 / 04
#
# Distributed under BSD license.
#
# Module for handling and displaying a calendar.
# Adapted from http://wiki.tcl.tk/1816 (An i15d date chooser)

namespace eval poCalendar {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Chooser
    namespace export ShowCalendarWindow

    proc Chooser {w args} {
        variable $w
        variable defaults
        array set $w [array get defaults]
        upvar 0 $w a
 
        set now [clock scan now]
        set a(year) [clock format $now -format "%Y"]
        scan [clock format $now -format "%m"] %d a(month)
        scan [clock format $now -format "%d"] %d a(day)
 
        array set a {
            -font {Helvetica 9} -titlefont {Helvetica 12} -bg white
            -highlight orange -mon 0 -langauge en -textvariable {}
            -command {} -clockformat "%m/%d/%Y" -showpast 1
        }
        # The -mon switch gives the position of Monday (1 or 0)
        array set a $args
        set a(canvas) [canvas $w -bg $a(-bg) -width 200 -height 180]
        $w bind day <1> {
            set item [%W find withtag current]
            set poCalendar::%W(day) [%W itemcget $item -text]
            poCalendar::Display %W
            poCalendar::HandleCallback %W
        }
 
        if { $a(-textvariable) ne {} } {
            set tmp [set $a(-textvariable)]
            if { $tmp ne "" } {
                set date [clock scan $tmp -format $a(-clockformat)]
                set a(thisday)   [clock format $date -format %d]
                set a(thismonth) [clock format $date -format %m]
                set a(thisyear)  [clock format $date -format %Y]
            }
        }
 
        cbutton $w 60  10 "<<" { poCalendar::Adjust %W  0 -1 }
        cbutton $w 80  10 "<"  { poCalendar::Adjust %W -1  0 }
        cbutton $w 120 10 ">"  { poCalendar::Adjust %W  1  0 }
        cbutton $w 140 10 ">>" { poCalendar::Adjust %W  0  1 }
        bind $w <Key-M> "poCalendar::Adjust $w -1 0"
        bind $w <Key-m> "poCalendar::Adjust $w  1 0"
        bind $w <Key-Y> "poCalendar::Adjust $w 0 -1"
        bind $w <Key-y> "poCalendar::Adjust $w 0  1"
        Display $w
        set w
    }

    proc DateOkCmd {} {
        variable sPo

        set sPo(dateFlag) 1
    }

    proc DateCancelCmd {} {
        variable sPo

        set sPo(dateFlag) 0
    }

    proc ShowCalendarWindow { x y clockFormat startDate } {
        variable ns
        variable sPo

        set tw ".poCalendar_Chooser"
        if { [winfo exists $tw] } {
            destroy $tw
        }

        toplevel $tw
        wm overrideredirect $tw true
        if { [tk windowingsystem] eq "aqua" }  {
            ::tk::unsupported::MacWindowStyle style $tw help none
        }
        wm geometry $tw [format "+%d+%d" $x [expr $y +10]]

        set ${ns}::sPo(date) $startDate

        ttk::frame $tw.fr -borderwidth 2 -relief raised
        poCalendar::Chooser $tw.fr.d -language en \
            -command ${ns}::DateOkCmd \
            -textvariable ${ns}::sPo(date) -clockformat $clockFormat
        pack $tw.fr.d
        pack $tw.fr

        bind $tw <KeyPress-Return> "${ns}::DateOkCmd"
        bind $tw <KeyPress-Escape> "${ns}::DateCancelCmd"

        update 
 
        set oldFocus [focus]
        set oldGrab [grab current $tw]
        if { $oldGrab ne "" } {
            set grabStatus [grab status $oldGrab]
        }
        grab $tw
        focus $tw.fr.d

        tkwait variable ${ns}::sPo(dateFlag)

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

        if { $sPo(dateFlag) } {
            return $sPo(date)
        } else {
            return ""
        }
    }

    proc Adjust {w dmonth dyear} {
        variable $w
        upvar 0 $w a
 
        incr a(year)  $dyear
        incr a(month) $dmonth
        if {$a(month)>12} {set a(month) 1; incr a(year)}
        if {$a(month)<1}  {set a(month) 12; incr a(year) -1}
        set maxday [NumberOfDays $a(month) $a(year)]
        if {$maxday < $a(day)} {set a(day) $maxday}
        Display $w
    }

    proc Display {w} {
        variable $w
        upvar 0 $w a
 
        set c $a(canvas)
        foreach tag {title otherday day} {$c delete $tag}
        set x0 20; set x $x0; set y 50
        set dx 25; set dy 20
        set xmax [expr {$x0+$dx*6}]
        set a(date) [clock scan $a(month)/$a(day)/$a(year)]
        set title [FormatMY $w [MonthName $w $a(month)] $a(year)]
        $c create text [expr ($xmax+$dx)/2] 30 -text $title -fill blue \
            -font $a(-titlefont) -tag title
        set weekdays $a(weekdays,$a(-language))
        if !$a(-mon) {lcycle weekdays}
        foreach i $weekdays {
            $c create text $x $y -text $i -fill blue \
                -font $a(-font) -tag title
            incr x $dx
        }
        set first $a(month)/1/$a(year)
        set weekday [clock format [clock scan $first] -format %w]
        if !$a(-mon) {set weekday [expr {($weekday+6)%7}]}
        set x [expr {$x0+$weekday*$dx}]
        set x1 $x; set offset 0
        incr y $dy
        while {$weekday} {
            set t [clock scan "$first [incr offset] days ago"]
            scan [clock format $t -format "%d"] %d day
            $c create text [incr x1 -$dx] $y -text $day \
                -fill grey -font $a(-font) -tag otherday
            incr weekday -1
        }
        set dmax [NumberOfDays $a(month) $a(year)]
        for {set d 1} {$d<=$dmax} {incr d} {
            if {($a(-showpast) == 0) && ($d<$a(thisday)) && ($a(month) <= $a(thismonth)) \
                && ($a(year) <= $a(thisyear)) } {

                set id [$c create text $x $y -text $d -fill grey -tag otherday -font $a(-font)]
            } else {
                set id [$c create text $x $y -text $d -tag day -font $a(-font)]
            }
            if {$d==$a(day)} {
                eval $c create rect [$c bbox $id] \
                    -fill $a(-highlight) -outline $a(-highlight) -tag day
            }
            $c raise $id
            if {[incr x $dx]>$xmax} {set x $x0; incr y $dy}
        }
        if {$x != $x0} {
            for {set d 1} {$x<=$xmax} {incr d; incr x $dx} {
                $c create text $x $y -text $d \
                    -fill grey -font $a(-font) -tag otherday
            }
        }
        if { $a(-textvariable) ne {} } {
            # puts "[info level 0]: $a(-clockformat)"
            set $a(-textvariable) [clock format $a(date) -format $a(-clockformat)]
        }
    }
 
    proc HandleCallback {w} {
        variable $w
        upvar 0 $w a
        if { $a(-command) ne {} } {
            uplevel \#0 $a(-command)
        }
    }
 
    proc FormatMY {w month year} {
        variable $w
        upvar 0 $w a
 
        if ![info exists a(format,$a(-language))] {
            set format "%m %y" ;# default
        } else {set format $a(format,$a(-language))}
        foreach {from to} [list %m $month %y $year] {
            regsub -- $from $format $to format
        }
        subst $format
    }

    proc MonthName {w month {language default}} {
        variable $w
        upvar 0 $w a
 
        if {$language=="default"} {set language $a(-language)}
        if {[info exists a(mn,$language)]} {
            set res [lindex $a(mn,$language) $month]
        } else {set res $month}
    }
 
    variable defaults

    array set defaults {
        -language en
         mn,crk {
         . Kis\u01E3p\u012Bsim Mikisiwip\u012Bsim Niskip\u012Bsim Ay\u012Bkip\u012Bsim
         S\u0101kipak\u0101wip\u012Bsim                                     
         P\u0101sk\u0101wihowip\u012Bsim Paskowip\u012Bsim Ohpahowip\u012Bsim     
         N\u014Dcihitowip\u012Bsim Pin\u0101skowip\u012Bsim Ihkopiwip\u012Bsim
         Paw\u0101cakinas\u012Bsip\u012Bsim
        }
        weekdays,crk {P\u01E3 N\u01E3s Nis N\u01E3 Niy Nik Ay}
 
        mn,crx-nak {
            . {Sacho Ooza'} {Chuzsul Ooza'} {Chuzcho Ooza'} {Shin Ooza'} {Dugoos Ooza'} {Dang Ooza'}\
           {Talo Ooza'} {Gesul Ooza'} {Bit Ooza'} {Lhoh Ooza'} {Banghan Nuts'ukih} {Sacho Din'ai}
        }
        weekdays,crx-nak {Ji Jh WN WT WD Ts Sa}
 
        mn,crx-lhe {
            . {'Elhdzichonun} {Yussulnun} {Datsannadulhnun} {Dulats'eknun} {Dugoosnun} {Daingnun}\
            {Gesnun} {Nadlehcho} {Nadlehyaz} {Lhewhnandelnun} {Benats'ukuihnun} {'Elhdziyaznun}
        }
        weekdays,crx-lhe {Ji Jh WN WT WD Ts Sa}
 
        mn,de {
        . Januar Februar März April Mai Juni Juli August
        September Oktober November Dezember
        }
        weekdays,de {So Mo Di Mi Do Fr Sa}
 
        mn,en {
        . January February March April May June July August
        September October November December
        }
        weekdays,en {Sun Mon Tue Wed Thu Fri Sat}
 
        mn,es {
        . Enero Febrero Marzo Abril Mayo Junio Julio Agosto
        Septiembre Octubre Noviembre Diciembre
        }
        weekdays,es {Do Lu Ma Mi Ju Vi Sa}
 
        mn,fr {
        . Janvier Février Mars Avril Mai Juin Juillet Août
        Septembre Octobre Novembre Décembre
        }
        weekdays,fr {Di Lu Ma Me Je Ve Sa}
 
        mn,gr {
        . Îýýa??Ïýý?Ïýý??Ïýý FeßÏýý?Ïýý?Ïýý??Ïýý Îýý?ÏýýÏýý??Ïýý ÎýýÏýýÏýý????Ïýý ÎýýaÎýý?Ïýý Îýý?Ïýý???Ïýý Îýý?Ïýý???Ïýý ÎýýÏýý??ÏýýÏýýÏýý?Ïýý
        SeÏýýÏýýÎýýµßÏýý??Ïýý Îýý?ÏýýÏýýµßÏýý??Ïýý Îýý?ÎýýµßÏýý??Ïýý Îýýe?ÎýýµßÏýý??Ïýý
        }
        weekdays,gr {ÎýýÏýýÏýý ÎýýeÏýý TÏýý? ?eÏýý Î eµ Î aÏýý Saß}
 
        mn,he {
         . ×ýý× ×ýý×ýý? ?×ýý?×ýý×ýý? ×ýý?? ×ýý??×ýý×ýý ×ýý×ýý×ýý ×ýý×ýý× ×ýý ×ýý×ýý×ýý×ýý ×ýý×ýý×ýý×ýý?×ýý ??×ýý×ýý×ýý? ×ýý×ýý?×ýý×ýý×ýý? × ×ýý×ýý×ýý×ýý? ×ýý?×ýý×ýý?
        }
        weekdays,he {?×ýý?×ýý×ýý ?× ×ýý ?×ýý×ýý?×ýý ?×ýý×ýý?×ýý ×ýý×ýý×ýý?×ýý ?×ýý?×ýý ?×ýý?}
        mn,it {
        . Gennaio Febraio Marte Aprile Maggio Giugno Luglio Agosto
        Settembre Ottobre Novembre Dicembre
        }
        weekdays,it {Do Lu Ma Me Gi Ve Sa}
 
        format,ja {%y\u5e74 %m\u6708}
        weekdays,ja {\u65e5 \u6708 \u706b \u6c34 \u6728 \u91d1 \u571f}
 
        mn,nl {
        . januari februari maart april mei juni juli augustus
        september oktober november december
        }
        weekdays,nl {Zo Ma Di Wo Do Vr Za}
 
        mn,ru {
        . \u042F\u043D\u0432\u0430\u0440\u044C
        \u0424\u0435\u0432\u0440\u0430\u043B\u044C \u041C\u0430\u0440\u0442
        \u0410\u043F\u0440\u0435\u043B\u044C \u041C\u0430\u0439
        \u0418\u044E\u043D\u044C \u0418\u044E\u043B\u044C
        \u0410\u0432\u0433\u0443\u0441\u0442
        \u0421\u0435\u043D\u0442\u044F\u0431\u0440\u044C
        \u041E\u043A\u0442\u044F\u0431\u0440\u044C \u041D\u043E\u044F\u0431\u0440\u044C
        \u0414\u0435\u043A\u0430\u0431\u0440\u044C
        }
        weekdays,ru {
            \u432\u43e\u441 \u43f\u43e\u43d \u432\u442\u43e \u441\u440\u435
            \u447\u435\u442 \u43f\u44f\u442 \u441\u443\u431
        }
 
        mn,sv {
            . januari februari mars april maj juni juli augusti
            september oktober november december
        }
        weekdays,sv {s\u00F6n m\u00E5n tis ons tor fre l\u00F6r}
 
        mn,pt {
        . Janeiro Fevereiro Mar\u00E7o Abril Maio Junho
        Julho Agosto Setembro Outubro Novembro Dezembro
        }
        weekdays,pt {Dom Seg Ter Qua Qui Sex Sab}
 
        format,zh {%y\u5e74 %m\u6708}
        mn,zh {
            . \u4e00 \u4e8c \u4e09 \u56db \u4e94 \u516d \u4e03
              \u516b \u4e5d \u5341 \u5341\u4e00 \u5341\u4e8c
        }
        weekdays,zh {\u65e5 \u4e00 \u4e8c \u4e09 \u56db \u4e94 \u516d}
        mn,fi {
          . Tammikuu Helmikuu Maaliskuu Huhtikuu Toukokuu Kesäkuu
          Heinäkuu Elokuu Syyskuu Lokakuu Marraskuu Joulukuu
        }
        weekdays,fi {Ma Ti Ke To Pe La Su}
        mn,tr {
           . ocak \u015fubat mart nisan may\u0131s haziran temmuz a\u011fustos eyl\u00FCl ekim kas\u0131m aral\u0131k
        }
        weekdays,tr {pa'tesi sa \u00e7a pe cu cu'tesi pa}
    }

    proc NumberOfDays {month year} {
        if {$month==12} {set month 0; incr year}
        clock format [clock scan "[incr month]/1/$year  1 day ago"] \
            -format %d
    } 

    proc lcycle _list {
        upvar $_list list
        set list [concat [lrange $list 1 end] [list [lindex $list 0]]]
    }

    proc cbutton { w x y text command } {
        set txt [$w create text $x $y -text " $text "]
        set btn [eval $w create rect [$w bbox $txt] \
            -fill grey -outline grey]
        $w raise $txt
        foreach i [list $txt $btn] { $w bind $i <1> $command }
    }
}

if { [info exists ::argv0] && ([file tail [info script]] eq [file tail $::argv0]) } {
    # Start as standalone program.
    package require Tk

    poCalendar::Chooser .1
    entry .2 -textvar poCalendar::.1(date)
    regsub -all -- weekdays, [array names poCalendar::.1 weekdays,*] "" languages
    foreach i [lsort -dictionary $languages] {
        radiobutton .b$i -text $i -variable poCalendar::.1(-language) -value $i -pady 0
    }
    trace variable poCalendar::.1(-language) w {poCalendar::Display .1;#}
    checkbutton .mon -variable poCalendar::.1(-mon) -text "Sunday starts week"
    trace variable poCalendar::.1(-mon) w {poCalendar::Display .1;#}
            
    pack {*}[winfo children .] -fill x -anchor w
 
    # example 2
    # requires tcl 8.5
    
    # set german clock format
    set clockformat "%d.%m.%Y"
    set ::DATE [clock format [clock seconds] -format $clockformat]
 
    set w [toplevel .x]
    entry $w.date -textvariable ::DATE
    button $w.b -command [list ShowCalendar %X %Y $clockformat]
 
    pack $w.date $w.b -side left
 
 
    proc ShowCalendar { x y clockformat} {
        puts "begin $::DATE"
        set w [toplevel .d]
        wm overrideredirect $w 1
        frame $w.f -borderwidth 2 -relief solid -takefocus 0
        poCalendar::Chooser $w.f.d -language de \
            -command [list set ::SEMA close] \
            -textvariable ::DATE -clockformat $clockformat
        pack $w.f.d
        pack $w.f
 
        lassign [winfo pointerxy .] x y
        # puts "$x $y"
        wm geometry $w "+${x}+${y}"
 
        set _w [grab current]
        if {$_w ne {} } {
            grab release $_w
            grab set $w
        }
 
        set ::SEMA ""
        tkwait variable ::SEMA
 
        if {$_w ne {} } {
            grab release $w
            grab set $_w
        }
        destroy $w
        puts "end $::DATE"
 
        puts [.x.date get]
    }
}
