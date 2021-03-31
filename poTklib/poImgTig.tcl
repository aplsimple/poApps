# Module:         poImgTig
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 07 / 30
#
# Distributed under BSD license.
#
# Module with utility procedures for generating test images.
# Derived from code found on the Wiki: http://wiki.tcl.tk/48893

namespace eval poImgTig {
    namespace ensemble create

    namespace export Draw

    variable Pattern   {}
    variable ForeColor white
    variable BackColor black
    variable PenSize   1
    variable Font      {Courier 12}
    variable DrawPos

    set DrawPos(x) 0
    set DrawPos(y) 0

    proc hsv2rgb { hue sat value } {
        set v $value
        if {$sat == 0} {
            set v [format %04X [expr $v * 65535]]
            return "#$v$v$v"
        } else {
            set hue [expr $hue * 6.0]
            if {$hue >= 6.0} {
                set hue 0.0
            }
            scan $hue. %d i
            set f [expr $hue - $i]
            set p [expr $value * (1 - $sat)]
            set q [expr $value * (1 - ($sat * $f))]
            set t [expr $value * (1 - ($sat * (1 - $f)))]
            switch -exact $i {
                0 { set r $v; set g $t; set b $p }
                1 { set r $q; set g $v; set b $p }
                2 { set r $p; set g $v; set b $t }
                3 { set r $p; set g $q; set b $v }
                4 { set r $t; set g $p; set b $v }
                5 { set r $v; set g $p; set b $q }
                default {
                    error "hsv2rgb: i value $i is out of range"
                }
            }
            set r [format %04X [expr int($r * 65535)]]
            set g [format %04X [expr int($g * 65535)]]
            set b [format %04X [expr int($b * 65535)]]
            return "#$r$g$b"
        }
    }

    proc transform { x a1 a2 b1 b2 } {
        expr ((double($x) - double($a1)) / (double($a2) - double($a1))) * \
              (double($b2) - double($b1)) + double($b1)
    }

    proc Transform { x a1 a2 b1 b2 } {
        expr round(((double($x) - double($a1)) / (double($a2) - double($a1))) * \
                    (double($b2) - double($b1)) + double($b1))
    }

    proc XPos { p } {
        upvar prc rc
        expr round($p * ($rc(right) - $rc(left)) + $rc(left))
    }

    proc XPos1 { p } {
        upvar prc rc
        expr round($p * ($rc(right) - $rc(left)) + $rc(left)) +1
    }

    proc YPos { p } {
        upvar prc rc
        expr round($p * ($rc(bottom) - $rc(top)) + $rc(top))
    }

    proc YPos1 { p } {
        upvar prc rc
        expr round($p * ($rc(bottom) - $rc(top)) + $rc(top)) +1
    }

    proc SetRect { v_rc x0 y0 x1 y1 } {
        upvar $v_rc rc
        set rc(top)    $y0
        set rc(left)   $x0
        set rc(bottom) $y1
        set rc(right)  $x1
    }

    proc GetFontInfo { v_finfo } {
        upvar $v_finfo finfo
        variable Font

        set finfo(ascent)    [font metrics $Font -ascent]
        set finfo(descent)   [font metrics $Font -descent]
        set finfo(linespace) [font metrics $Font -linespace]
    }

    proc StringWidth { str } {
        variable Font

        return [font measure $Font $str]
    }

    proc TextFont { which } {
        variable Font

        set Font $which
    }

    proc DrawString { canvasId str {anchor w} } {
        variable DrawPos
        variable Font
        variable ForeColor

        $canvasId create text $DrawPos(x) $DrawPos(y) -font $Font -fill $ForeColor \
                  -anchor $anchor -text $str
    }

    proc SetPenSize { width } {
        variable PenSize

        set PenSize $width
    }

    proc FillRect { canvasId v_rc } {
        upvar $v_rc rc
        variable Pattern
        variable ForeColor

        if {$Pattern != {}} {
            $canvasId create rect $rc(left) $rc(top) $rc(right) $rc(bottom) \
                -fill $ForeColor -stipple $Pattern -width 0
        } else {
            $canvasId create rect $rc(left) $rc(top) $rc(right) $rc(bottom) \
                -fill $ForeColor -width 0
        }
    }

    proc ClearPoly3 { canvasId x0 y0 x1 y1 x2 y2 } {
        variable BackColor

        $canvasId create poly $x0 $y0 $x1 $y1 $x2 $y2 -fill $BackColor -width 0
    }

    proc FrameRect { canvasId v_rc } {
        upvar $v_rc rc

        MoveTo $rc(left)  $rc(top)
        LineTo $canvasId $rc(right) $rc(top)
        LineTo $canvasId $rc(right) $rc(bottom)
        LineTo $canvasId $rc(left)  $rc(bottom)
        LineTo $canvasId $rc(left)  $rc(top)
    }

    proc EraseRect { canvasId v_rc } {
        upvar $v_rc rc
        variable Pattern
        variable BackColor

        $canvasId create rect $rc(left) $rc(top) $rc(right) $rc(bottom) -fill $BackColor
    }

    proc FrameCircle { canvasId v_rc } {
        upvar $v_rc rc
        variable Pattern
        variable ForeColor
        variable PenSize 

        $canvasId create oval $rc(left) $rc(top) $rc(right) $rc(bottom) \
            -outline $ForeColor -width $PenSize
    }

    proc MoveTo { x0 y0 } {
        variable DrawPos

        set DrawPos(x) $x0
        set DrawPos(y) $y0
    }

    proc LineTo { canvasId x1 y1 } {
        variable DrawPos
        variable ForeColor
        variable PenSize

        $canvasId create line $DrawPos(x) $DrawPos(y) $x1 $y1 \
                  -fill $ForeColor -width $PenSize
        set DrawPos(x) $x1
        set DrawPos(y) $y1
    }

    proc RGBForeColor { color } {
        variable ForeColor

        set ForeColor $color
    }

    proc RGBBackColor { color } {
        variable BackColor

        set BackColor $color
    }

    proc PenPattern { id } {
        variable Pattern

        set Pattern $id
    }

    proc Color { which } {
        switch $which {
            gray     { return #C000C000C000 }
            yellow   { return #FF00EA000000 }
            cyan     { return #0000A400DE00 }
            green    { return #0000FFFF0000 }
            magenta  { return #CE0000006800 }
            red      { return #FFFF00000000 }
            blue     { return #00000000FFFF }
            black    { return #000000000000 }
            white_25 { return #400040004000 }
            white_50 { return #800080008000 }
            white_75 { return #C000C000C000 }
            white    { return #FFFFFFFFFFFF }
            default  { return $which        }
        }
    }

    proc Draw4Rects { canvasId x0 x1 x2 x3 y0 y1 y2 y3 } {
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x2 $y0 $x3 $y1
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        FillRect $canvasId rc
        SetRect rc $x2 $y2 $x3 $y3
        FillRect $canvasId rc
    }

    proc DrawBalken { canvasId v_prc } {
        upvar $v_prc prc
  
        array set rc [array get prc]
        set x1 [XPos 0]
        set pos 0.125
        foreach color {gray yellow cyan green magenta red blue black} {
            set x0 $x1
            set x1 [XPos $pos]
            set rc(left)  $x0
            set rc(right) $x1
            RGBForeColor [Color $color]
            FillRect $canvasId rc
            set pos [expr $pos + 0.125]
        }
    }

    proc DrawFuBK { canvasId v_prc { testText "" } } {
        upvar $v_prc prc

        if { $testText eq "" } {
            set testText "Farb-Testbild Generator - J.Mehring 1.2"
        }

        # Hintergrundfarbe schwarz
        RGBBackColor [Color black]
        RGBForeColor [Color black]
        FillRect $canvasId prc

        # 14 horizontale Linien
        RGBForeColor [Color white]
        array set rc [array get prc]
        set pos 0.033333333
        for {set idx 0} {$idx < 15} {incr idx} {
            set y0 [YPos $pos]
            MoveTo $rc(left)  $y0
            LineTo $canvasId $rc(right) $y0
            set pos [expr $pos + 0.066666666]
        }

        # 18 verticale Linien
        RGBForeColor [Color white]
        array set rc [array get prc]
        set pos 0.026315789
        for {set idx 0} {$idx < 19} {incr idx} {
            set x0 [XPos $pos]
            MoveTo $x0 $rc(top)
            LineTo $canvasId $x0 $rc(bottom)
            set pos [expr $pos + 0.052631578]
        }
      
        # die inneren 12x3 K‰stchen ausblenden
        RGBForeColor [Color black]
        SetRect rc [XPos1 0.1842105263] [YPos1 0.1666666667] \
                   [XPos1 0.8157894737] [YPos1 0.8333333333]
        FillRect $canvasId rc
  
        # 8 Farbbalken in die oberen 12x3 K‰stchen
        set rc(top)    [YPos1 0.1666666667]
        set rc(bottom) [YPos  0.3666666667]
        set x1         [XPos  0.1842105263]
        set pos 0.263157894
        foreach color {gray yellow cyan green magenta red blue black} {
            set x0 $x1
            set x1 [XPos $pos]
            set rc(left)  $x0
            set rc(right) $x1
            RGBForeColor [Color $color]
            FillRect $canvasId rc
            set pos [expr $pos + 0.078947368]
        }

        # 5 Graustufen in die darunter liegenden 12x2 K‰stchen
        set rc(top)    [YPos1 0.3666666667]
        set rc(bottom) [YPos  0.5]
        set x1         [XPos  0.1842105263]
        set pos 0.310526315
        foreach color {black white_25 white_50 white_75 white} {
            set x0 $x1
            set x1 [XPos $pos]
            set rc(left)  $x0
            set rc(right) $x1
            RGBForeColor [Color $color]
            FillRect $canvasId rc
            set pos [expr $pos + 0.126315789]
        }
      
        # die "Senderkennung" umrahmt von 2 Weiﬂk‰stchen in die Zeile darunter
        RGBForeColor [Color black]
        SetRect rc [XPos 0.1842105263] [YPos 0.5] \
                   [XPos 0.2894736840] [YPos 0.5526315789]
        FillRect $canvasId rc
        RGBForeColor [Color white]
        SetRect rc [XPos 0.1842105263] [YPos 0.5] \
                   [XPos 0.2894736842] [YPos 0.5666666667]
        FillRect $canvasId rc
        SetRect rc [XPos 0.7105263158] [YPos 0.5] \
                   [XPos 0.8157894737] [YPos 0.5666666667]
        FillRect $canvasId rc
        
        # Pattern in die n‰chste Zeile
        set y0 [YPos 0.5666666667]
        set y1 [YPos 0.6333333333]
        RGBForeColor [Color white]
        SetRect rc [XPos 0.1842105263] $y0 [XPos 0.2631578947] $y1
        FillRect $canvasId rc
        SetRect rc [XPos 0.2631578947] $y0 [XPos 0.3815789474] $y1
        PenPattern gray12
        FillRect $canvasId rc
        SetRect rc [XPos 0.3815789474] $y0 [XPos 0.5000000000] $y1
        PenPattern gray25
        FillRect $canvasId rc
        SetRect rc [XPos 0.5000000000] $y0 [XPos 0.6184210530] $y1
        PenPattern gray50
        FillRect $canvasId rc
        SetRect rc [XPos 0.6184210530] $y0 [XPos 0.7631578947] $y1
        PenPattern gray75
        FillRect $canvasId rc
        PenPattern {}
        RGBForeColor [Color white_50]
        SetRect rc [XPos 0.7631578947] $y0 [XPos 0.8157894737] $y1
        FillRect $canvasId rc
        
        # ein weiﬂes Kreuz in die Mitte
        RGBForeColor [Color white]
        set x0 [XPos  0.5]
        set y0 [YPos1 0.3666666667]
        set y1 [YPos  0.6333333333]
        SetPenSize 3
        MoveTo $x0 $y0
        LineTo $canvasId $x0 $y1
        set y0 [YPos 0.5]
        set x0 [XPos 0.1842105263]
        set x1 [XPos 0.8157894737]
        MoveTo $x0 $y0
        LineTo $canvasId $x1 $y0
        SetPenSize 1
        
        # den Text der "Senderkennung" anzeigen
        set len [XPos 0.3684210526]
        TextFont "Courier 24 bold"
        if {[StringWidth $testText] > $len} { TextFont "Courier 18 bold" }
        if {[StringWidth $testText] > $len} { TextFont "Courier 14 bold" }
        if {[StringWidth $testText] > $len} { TextFont "Courier 12 bold" }
        if {[StringWidth $testText] > $len} { TextFont "Courier 10 bold" }
        if {[StringWidth $testText] > $len} { TextFont "Courier  8 bold" }
        set x0 [XPos 0.5]
        set y0 [YPos 0.5333333333]
        GetFontInfo fInfo
        set len [StringWidth $testText]
        SetRect rc \
                [expr $x0 - $len / 2] \
                [expr $y0 - $fInfo(ascent) / 2 -1] \
                [expr $x0 + $len / 2] \
                [expr $y0 + $fInfo(ascent) / 2 + $fInfo(descent) +1]
        EraseRect $canvasId rc
        MoveTo [expr $x0 - $len / 2] [expr $y0 + $fInfo(ascent) / 2]
        RGBForeColor [Color white]
        DrawString $canvasId $testText
        
        # Weiﬂbalken mit kurzem Schwarzimpuls in die n‰chste Zeile
        RGBForeColor [Color white]
        set y0 [YPos 0.6333333333]
        set y1 [YPos 0.7]
        SetRect rc [XPos 0.1842105263] $y0 [XPos 0.49] $y1
        FillRect $canvasId rc
        SetRect rc [XPos 0.51] $y0 [XPos 0.8157894737] $y1
        FillRect $canvasId rc
        
        # Graukeile
        set x0 [XPos 0.1842105263]
        set x1 [XPos 0.6052631579]
        set y0 [YPos 0.7000000000]
        set y1 [YPos 0.8333333333]
        for {set x $x0} {$x <= $x1} {incr x} {
            set color [format %04X [Transform $x $x0 $x1 0 65535]]
            RGBForeColor #$color$color$color
            MoveTo $x $y0
            LineTo $canvasId $x $y1
        }
  
        # RGB-Farbkeil
        set x0 [XPos 0.6052631579]
        set x1 [XPos 0.8157894737]
        set y0 [YPos 0.7000000000]
        set y1 [YPos 0.8333333333]
        for {set x $x0} {$x <= $x1} {incr x} {
            set hue [transform $x $x0 $x1 0 1]
            set rgb [hsv2rgb $hue 1.0 0.9]
            RGBForeColor $rgb
            MoveTo $x $y0
            LineTo $canvasId $x $y1
        }                     

        # den inneren Rahmen neu zeichnen
        RGBForeColor [Color white]
        SetRect rc [XPos  0.1842105263] [YPos  0.1666666667] \
                   [XPos1 0.8157894737] [YPos1 0.8333333333]
        FrameRect $canvasId rc
  
        # ein Kreis in die Mitte
        RGBForeColor [Color white]
        set x0 [XPos 0.5]
        set y0 [YPos 0.5]
        set r  [YPos 0.45]
        SetRect rc [expr $x0 - $r] [expr $y0 - $r] [expr $x0 + $r] [expr $y0 + $r]
        SetPenSize 2
        FrameCircle $canvasId rc
        SetPenSize 1
  
        # vier Kreise f¸r die Ecken
        SetRect rc [XPos 0.028947368] [YPos 0.036666667] \
                   [XPos 0.181578947] [YPos 0.230000000]
        FrameCircle $canvasId rc
        SetRect rc [XPos 0.818421052] [YPos 0.036666667] \
                   [XPos 0.971052631] [YPos 0.230000000]
        FrameCircle $canvasId rc
        SetRect rc [XPos 0.028947368] [YPos 0.770000000] \
                   [XPos 0.181578947] [YPos 0.963333333]
        FrameCircle $canvasId rc
        SetRect rc [XPos 0.818421052] [YPos 0.770000000] \
                   [XPos 0.971052631] [YPos 0.963333333]
        FrameCircle $canvasId rc
    }

    proc DrawCt { canvasId v_prc } {
        upvar $v_prc prc

        # Hintergrundfarbe schwarz
        RGBBackColor [Color black]

        # schwarzer Hintergrund
        RGBForeColor [Color black]
        FillRect $canvasId prc
      
        # weiﬂer Rahmen
        array set rc [array get prc]
        RGBForeColor [Color white]
        FrameRect $canvasId rc
        
        # weiﬂe horizontale Linien
        set pos 0.0625
        for {set idx 0} {$idx < 16} {incr idx} {
            set x0 [XPos $pos]
            MoveTo $x0 [expr $prc(top) +2]
            LineTo $canvasId $x0 [expr $prc(bottom) -3]
            set pos [expr $pos + 0.0625]
        }
      
        # weiﬂe vertikale Linien
        set pos 0.0833333333
        for {set idx 0} {$idx < 16} {incr idx} {
            set y0 [YPos $pos]
            MoveTo [expr $prc(left) +2] $y0
            LineTo $canvasId [expr $prc(right) -3] $y0
            set pos [expr $pos + 0.0833333333]
        }
      
        # weiﬂe Balken (n x 24) an die R‰nder
        set y0 [expr $prc(top) +2]
        set y1 [expr $y0 +24]
        set y3 [expr $prc(bottom) -2]
        set y2 [expr $y3 -24]
        set x0 [XPos 0.1250]
        set x1 [XPos 0.3125]
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        FillRect $canvasId rc
        set x0 [XPos 0.4375]
        set x1 [XPos 0.5625]
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        FillRect $canvasId rc
        set x0 [XPos 0.6875]
        set x1 [XPos 0.8750]
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        FillRect $canvasId rc
        set x0 [expr $prc(left) +2]
        set x1 [expr $x0 +24]
        set x3 [expr $prc(right) -2]
        set x2 [expr $x3 - 24]
        set y0 [YPos 0.1666666666]
        set y1 [YPos 0.4166666666]
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x2 $y0 $x3 $y1
        FillRect $canvasId rc
        set y0 [YPos 0.5833333333]
        set y1 [YPos 0.8333333333]
        SetRect rc $x0 $y0 $x1 $y1
        FillRect $canvasId rc
        SetRect rc $x2 $y0 $x3 $y1
        FillRect $canvasId rc
        
        # einen dicken weiﬂen Balken links
        SetRect rc [expr $prc(left) +2 +24 +1] [YPos 0.4166666666] \
                   [XPos 0.21875] [YPos 0.5833333333]
        FillRect $canvasId rc
        
        # vier kleine weiﬂe Balken innen
        set x0 [XPos 0.3125]
        set x1 [XPos 0.34375]
        set x2 [XPos 0.65625]
        set x3 [XPos 0.6875]
        set y0 [YPos 0.3333333333]
        set y1 [YPos 0.375]
        set y2 [YPos 0.625]
        set y3 [YPos 0.6666666666]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        
        # verschiedene Pattern (24 x 24) in die Ecken
        PenPattern gray12
        set y0 [expr $prc(top) + 2]
        set y1 [expr $y0 + 24]
        set y3 [expr $prc(bottom) - 2]
        set y2 [expr $y3 - 24]
        set x0 [expr $prc(left) + 2]
        set x1 [expr $x0 + 24]
        set x3 [expr $prc(right) - 2]
        set x2 [expr $x3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        PenPattern gray25
        set x0 [expr $x1]
        set x1 [expr $x0 + 24]
        set x3 [expr $x2]
        set x2 [expr $x3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        PenPattern gray50
        set x0 [expr $x1]
        set x1 [expr $x0 + 24]
        set x3 [expr $x2]
        set x2 [expr $x3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        PenPattern gray75
        set x0 [expr $prc(left) + 2]
        set x1 [expr $x0 + 24]
        set x3 [expr $prc(right) - 2]
        set x2 [expr $x3 - 24]
        set y0 [expr $prc(top) + 2 + 24]
        set y1 [expr $y0 + 24]
        set y3 [expr $prc(bottom) - 2 - 24]
        set y2 [expr $y3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        PenPattern {}
        set y0 [expr $y1]
        set y1 [expr $y0 + 24]
        set y3 [expr $y2]
        set y2 [expr $y3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
  
        # farbige (R,G,B) K‰stchen in die Ecken der Pattern
        RGBForeColor [Color blue]
        set x0 [expr $prc(left) + 2 + 25]
        set x1 [expr $x0 + 24]
        set x3 [expr $prc(right) - 2 - 25]
        set x2 [expr $x3 - 24]
        set y0 [expr $prc(top) + 2 + 25]
        set y1 [expr $y0 + 24]
        set y3 [expr $prc(bottom) - 2 - 25]
        set y2 [expr $y3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        RGBForeColor [Color green]
        set x0 [expr $x1]
        set x1 [expr $x0 + 24]
        set x3 [expr $x2]
        set x2 [expr $x3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        RGBForeColor [Color red]
        set x0 [expr $x0 - 24]
        set x1 [expr $x1 - 24]
        set x2 [expr $x2 + 24]
        set x3 [expr $x3 + 24]
        set y0 [expr $y1]
        set y1 [expr $y0 + 24]
        set y3 [expr $y2]
        set y2 [expr $y3 - 24]
        Draw4Rects $canvasId $x0 $x1 $x2 $x3 $y0 $y1 $y2 $y3
        
        # mit Pattern die inneren Felder umrahmen
        RGBForeColor [Color white]
        set x1 [XPos 0.25]
        set y0 [YPos 0.25]
        set y1 [YPos 0.3333333333]
        set pos 0.3125
        set pats {gray12 gray25 gray50 gray75 gray12 gray25 gray50 gray75}
        for {set idx 0} {$idx < 8} {incr idx} {
            # HexPenPat [expr $idx + 6]
            PenPattern [lindex $pats $idx]
            set x0 $x1
            set x1 [XPos $pos]
            SetRect rc $x0 $y0 $x1 $y1
            FillRect $canvasId rc
            set pos [expr $pos + 0.0625]
        }
        set x0 [XPos 0.25]
        set x1 [XPos 0.3125]
        set x2 [XPos 0.6875]
        set x3 [XPos 0.75]
        set y1 [YPos 0.3333333333]
        set pos 0.4166666666
        set pats {gray12 gray12 gray25 gray25 gray50 gray50 gray75 gray75}
        for {set idx 0} {$idx < 8} {incr idx 2} {
            # HexPenPat [expr $idx + 14]
            PenPattern [lindex $pats $idx]
            set y0 $y1
            set y1 [YPos $pos]
            SetRect rc $x0 $y0 $x1 $y1
            FillRect $canvasId rc
            # HexPenPat [expr $idx + 14 +1]
            PenPattern [lindex $pats $idx]
            SetRect rc $x2 $y0 $x3 $y1
            FillRect $canvasId rc
            set pos [expr $pos + 0.0833333333]
        }
        PenPattern {}
        
        # RGB-Farbkeil
        set x0 [XPos 0.25]
        set x1 [XPos 0.75]
        set y0 [YPos 0.6666666666]
        set y1 [YPos 0.75]
        for {set x $x0} {$x <= $x1} {incr x} {
            set hue [transform $x $x0 $x1 0 0.6666666667]
            set rgb [hsv2rgb $hue 1.0 0.9]
            RGBForeColor $rgb
            MoveTo $x $y0
            LineTo $canvasId $x $y1
        }                     
        RGBForeColor [Color white]
  
        # Strahlen, die von der Mitte ausgehen
        set x0 [XPos 0.5]
        set y0 [YPos 0.5]
        set x1 [XPos 0.6875]
        ClearPoly3 $canvasId $x0 $y0 $x1 [YPos 0.416666666] $x1 [YPos 0.583333333]
        set pos 0.416666666
        while {$pos <= 0.583333333} {
            MoveTo $x0 $y0
            LineTo $canvasId $x1 [YPos $pos]
            set pos [expr $pos + 0.005555555]
        }
        set x1 [XPos 0.3125]
        ClearPoly3 $canvasId $x0 $y0 $x1 [YPos 0.416666666] $x1 [YPos 0.583333333]
        set pos 0.416666666
        while {$pos <= 0.583333333} {
            MoveTo $x0 $y0
            LineTo $canvasId $x1 [YPos $pos]
            set pos [expr $pos + 0.005555555]
        }
        set y1 [YPos 0.333333333]
        ClearPoly3 $canvasId $x0 $y0 [XPos 0.4375] $y1 [XPos 0.5625] $y1
        set pos 0.4375
        while {$pos <= 0.5625} {
            MoveTo $x0 $y0
            LineTo $canvasId [XPos $pos] $y1
            set pos [expr $pos + 0.004166666]
        }
        set y1 [YPos 0.666666666]
        ClearPoly3 $canvasId $x0 $y0 [XPos 0.4375] $y1 [XPos 0.5625] $y1
        set pos 0.4375
        while {$pos <= 0.5625} {
            MoveTo $x0 $y0
            LineTo $canvasId [XPos $pos] $y1
            set pos [expr $pos + 0.004166666]
        }
        
        # zwei Kreise in die Mitte
        SetRect rc [XPos1 0.1875] [YPos1 0.0833333333] \
                   [XPos  0.8125] [YPos  0.9166666666]
        FrameCircle $canvasId rc
        SetRect rc [XPos1 0.4375] [YPos1 0.4166666666] \
                   [XPos  0.5625] [YPos  0.5833333333]
        FrameCircle $canvasId rc
  
        # einen Kreis in die jede Ecke
        SetRect rc [XPos1 0.0625] [YPos1 0.0833333333] \
                   [XPos  0.1875] [YPos  0.2500000000]
        FrameCircle $canvasId rc
        SetRect rc [XPos1 0.0625] [YPos1 0.7500000000] \
                   [XPos  0.1875] [YPos  0.9166666666]
        FrameCircle $canvasId rc
        SetRect rc [XPos1 0.8125] [YPos1 0.0833333333] \
                   [XPos  0.9375] [YPos  0.2500000000]
        FrameCircle $canvasId rc
        SetRect rc [XPos1 0.8125] [YPos1 0.7500000000] \
                   [XPos  0.9375] [YPos  0.9166666666]
        FrameCircle $canvasId rc
        
        # farbige K‰stchen in die Mitte
        set y0 [YPos 0.3333333333]
        set y1 [YPos 0.375]
        set y2 [YPos 0.625]
        set y3 [YPos 0.6666666666]
        set x0 [XPos 0.375]
        set x1 [XPos 0.4375]
        SetRect rc $x0 $y0 $x1 $y1
        RGBForeColor [Color blue]
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        RGBForeColor [Color cyan]
        FillRect $canvasId rc
        set x0 $x1
        set x1 [XPos 0.5]
        SetRect rc $x0 $y0 $x1 $y1
        RGBForeColor [Color green]
        FillRect $canvasId rc
        set x0 $x1
        set x1 [XPos 0.5625]
        SetRect rc $x0 $y0 $x1 $y1
        RGBForeColor [Color red]
        FillRect $canvasId rc
        set x0 $x1
        set x1 [XPos 0.625]
        SetRect rc $x0 $y0 $x1 $y1
        RGBForeColor [Color yellow]
        FillRect $canvasId rc
        SetRect rc $x0 $y2 $x1 $y3
        RGBForeColor [Color magenta]
        FillRect $canvasId rc
    }

    proc DrawPattern { canvasId v_prc } {
        upvar $v_prc prc

        # Hintergrundfarbe schwarz
        RGBBackColor [Color white]
        RGBForeColor [Color black]
        EraseRect $canvasId prc
  
        # 2 Pattern (links und rechts)
        array set rc [array get prc]
        set rc(right) [XPos 0.5]
        PenPattern gray25
        FillRect $canvasId rc
  
        array set rc [array get prc]
        set rc(left) [XPos 0.5]
        PenPattern gray75
        FillRect $canvasId rc
  
        PenPattern {}
    }


    proc DrawTestText { canvasId v_prc { testText "" } } {
        upvar $v_prc prc

        if { $testText eq "" } {
            set testText "Das ist ein Test-Text zur Bestimmung von Konvergenzfehlern mittels kleiner Schrift. "
        }

        # Hintergrundfarbe schwarz
        RGBBackColor [Color white]
        RGBForeColor [Color black]
        EraseRect $canvasId prc

        # Text
        RGBForeColor [Color black]
        TextFont {Courier 8}
        set l   [StringWidth "D"]
        set len [StringWidth $testText]
        GetFontInfo fInfo
        set x0 [expr $prc(left) - $l / 2]
        set y0 [expr $prc(top) + $fInfo(ascent) / 2]
        set h  [expr $fInfo(ascent) + $fInfo(descent)]
        while {$y0 < [expr $prc(bottom) + $h]} {
            for {set x1 $x0} {$x1 < $prc(right)} {incr x1 $len} {
                MoveTo $x1 $y0
                DrawString $canvasId $testText
            }
            incr x0 -$l
            incr y0 $h
        }
    }

    proc Draw100Pixel { canvasId v_prc } {
        upvar $v_prc prc

        # Hintergrundfarbe schwarz
        RGBBackColor [Color black]

        # schwarzer Hintergrund
        RGBForeColor [Color black]
        FillRect $canvasId prc
      
        # weiﬂer Rahmen
        array set rc [array get prc]
        RGBForeColor [Color white]
        FrameRect $canvasId rc
      
        RGBForeColor [Color white_25]

        # dunkelgraue horizontale Linien alle 10 Pixel
        for {set x 10} {$x < $rc(right)} {incr x 10} {
            MoveTo $x [expr $prc(top) +2]
            LineTo $canvasId $x [expr $prc(bottom) -3]
        }
      
        # dunkelgraue vertikale Linien alle 10 Pixel
        for {set y 10} {$y < $rc(bottom)} {incr y 10} {
            MoveTo [expr $prc(left) +2] $y
            LineTo $canvasId [expr $prc(right) -3] $y
        }
      
        RGBForeColor [Color white_50]
  
        # graue horizontale Linien alle 50+100 Pixel
        for {set x 50} {$x < $rc(right)} {incr x 100} {
            MoveTo $x [expr $prc(top) +2]
            LineTo $canvasId $x [expr $prc(bottom) -3]
        }
      
        # graue vertikale Linien alle 50+100 Pixel
        for {set y 50} {$y < $rc(bottom)} {incr y 100} {
            MoveTo [expr $prc(left) +2] $y
            LineTo $canvasId [expr $prc(right) -3] $y
        }
      
        RGBForeColor [Color white]
  
        # weiﬂe horizontale Linien alle 100 Pixel
        for {set x 100} {$x < $rc(right)} {incr x 100} {
            MoveTo $x [expr $prc(top) +2]
            LineTo $canvasId $x [expr $prc(bottom) -3]
        }
      
        # weiﬂe vertikale Linien alle 100 Pixel
        for {set y 100} {$y < $rc(bottom)} {incr y 100} {
            MoveTo [expr $prc(left) +2] $y
            LineTo $canvasId [expr $prc(right) -3] $y
        }
      
        TextFont "Courier 18 bold"
        set xm [XPos 0.5]
        set ym [YPos 0.5]
        MoveTo $xm $ym
        set txt "$rc(right) x $rc(bottom) Pixel"
        set l [StringWidth $txt]
        SetRect crc [expr {$xm - $l / 2 - 25}] [expr {$ym - 25}] \
                    [expr {$xm + $l / 2 + 25}] [expr {$ym + 25}]
        EraseRect $canvasId crc
        DrawString $canvasId $txt center
    }

    proc DrawUniColor { canvasId v_prc color } {
        upvar $v_prc prc

        RGBForeColor [Color $color]
        FillRect $canvasId prc
    }

    proc Draw { which { xsize -1 } { ysize -1 } { testText "" } } {
        variable cvrc

        if { $xsize < 0 } {
            set xsize [winfo screenwidth .]
        }
        if { $ysize < 0 } {
            set ysize [winfo screenheight .]
        }
        set win .tig
        toplevel $win -bg black -bd 0
        wm title $win "Creating test image. Please wait."
        ttk::frame $win.fr
        pack $win.fr -expand 1 -fill both
        set canvasId [poWin CreateScrolledCanvas $win.fr false "" -bd 0 -bg black -highlightthickness 0]
        $canvasId configure -width 512 -height 512
        $canvasId configure -scrollregion "0 0 $xsize $ysize"

        poImgTig::SetRect poImgTig::cvrc 0 0 $xsize $ysize
        switch $which {
            ColorBar   { DrawBalken   $canvasId cvrc }
            Grid       { Draw100Pixel $canvasId cvrc }
            Pattern    { DrawPattern  $canvasId cvrc }
            TestImage1 { DrawFuBK     $canvasId cvrc $testText }
            TestImage2 { DrawCt       $canvasId cvrc }
            Text       { DrawTestText $canvasId cvrc $testText }
        }
        update
        raise $win
        after 1000
        set phImg [poWin Canvas2Img $canvasId]
        destroy $win
        return $phImg
    }
}
