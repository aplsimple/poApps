# Module:         poPhotoUtil
# Copyright:      Paul Obermeier 2009-2023 / paul@poSoft.de
# First Version:  2009 / 09 / 13
#
# Distributed under BSD license.
#
# Collection of procedures for image processing with pure Tk commands.
# Implemented functions:
#     CopyImg
#     ColorImg
#     FlipHorizontal
#     FlipVertical
#     Rotate (from http://wiki.tcl.tk/4022)
#     Resize (from http://wiki.tcl.tk/11196)
#     Blur   (from http://wiki.tcl.tk/10521)
#     HSV    (from http://wiki.tcl.tk/10524)
#     Tile
#     Compose (from http://wiki.tcl.tk/12225)
#     Reduce (from http://wiki.tcl.tk/11234)
#     Difference
#     GetImgStats
#     GetImgStatsLabels
#     Histogram
#     ScaleHistogram
#     DrawHistogram
#     CountColors
#     MarkColors

namespace eval poPhotoUtil {
    variable ns [namespace current]

    namespace ensemble create

    namespace export CopyImg
    namespace export ColorImg
    namespace export FlipHorizontal
    namespace export FlipVertical
    namespace export Rotate
    namespace export Resize
    namespace export Blur
    namespace export HSV
    namespace export Tile
    namespace export Compose
    namespace export Reduce
    namespace export Difference
    namespace export GetImgStats
    namespace export GetImgStatsLabels
    namespace export Histogram
    namespace export ScaleHistogram
    namespace export DrawHistogram
    namespace export CountColors
    namespace export MarkColors
    namespace export SetTransparentColor
    namespace export AssignPalette

    proc CopyImg { img } {
        set w [image width  $img]
        set h [image height $img]
        set newImg [image create photo -width $w -height $h]
        $newImg copy $img
        return $newImg
    }

    proc ColorImg { w h { red 255 } { green 255 } { blue 255 } } {
        # Create an image with a given size (w x h) and fill it with color
        # (red, green, blue). Return the new photo image.

        set phImg [image create photo -width $w -height $h]
        set color [format "#%02x%02x%02x" $red $green $blue]

        $phImg put $color -to 0 0 $w $h
        return $phImg
    }

    proc FlipHorizontal { phImg } {
        # Flip an image horizontally (around y axis) and return the
        # flipped image as a new photo image.

        set w [image width  $phImg]
        set h [image height $phImg]
        set tmp [image create photo -width $w -height $h]
        $tmp copy $phImg -subsample -1 1
        return $tmp
    }

    proc FlipVertical { phImg } {
        # Flip an image vertically (around y axis) and return the
        # flipped image as a new photo image.

        set w [image width  $phImg]
        set h [image height $phImg]
        set tmp [image create photo -width $w -height $h]
        $tmp copy $phImg -subsample 1 -1
        return $tmp
    }

    proc Rotate { phImg angle } {
        # Rotate an image by -90, 90, 180 or 270 degrees and return
        # the rotated image as a new photo image.

        set w [image width  $phImg]
        set h [image height $phImg]

        switch -- $angle {
            180 {
                set tmp [image create photo -width $w -height $h]
                $tmp copy $phImg -subsample -1 -1
                return $tmp
            }
            270 - 90 - -90 {
                set tmp [image create photo -width $h -height $w]
                set matrix [string repeat "{[string repeat {0 } $h]} " $w]
                if { $angle == -90 || $angle == 270 } {
                    set x0 0; set y [expr {$h-1}]; set dx 1; set dy -1
                } else {
                    set x0 [expr {$w-1}]; set y 0; set dx -1; set dy 1
                }
                foreach row [$phImg data] {
                    set x $x0
                    foreach pixel $row {
                        lset matrix $x $y $pixel
                        incr x $dx
                    }
                    incr y $dy
                }
                $tmp put $matrix
                return $tmp
            }
            default {
                error "Invalid angle $angle specified"
            }
        }
    }

    proc _Resize { phImg newx newy } {
        # Scale an image to new size (newx, newy) and return
        # the resized image as a new photo image.

        set mx [image width  $phImg]
        set my [image height $phImg]

        set dest [image create photo -width $newx -height $newy]

        # Check if we can just zoom using -zoom option on copy
        if { $newx % $mx == 0 && $newy % $my == 0} {
            set ix [expr {$newx / $mx}]
            set iy [expr {$newy / $my}]
            $dest copy $phImg -zoom $ix $iy
            return $dest
        }

        set ny 0
        set ytot $my
        for {set y 0} {$y < $my} {incr y} {
            # Do horizontal resize
            foreach {pr pg pb} [$phImg get 0 $y] {break}

            set row [list]
            set thisrow [list]
            set nx 0
            set xtot $mx
            for {set x 1} {$x < $mx} {incr x} {
                # Add whole pixels as necessary
                while { $xtot <= $newx } {
                    lappend row [format "#%02x%02x%02x" $pr $pg $pb]
                    lappend thisrow $pr $pg $pb
                    incr xtot $mx
                    incr nx
                }

                # Now add mixed pixels
                foreach {r g b} [$phImg get $x $y] {break}

                # Calculate ratios to use
                set xtot [expr {$xtot - $newx}]
                set rn $xtot
                set rp [expr {$mx - $xtot}]

                # This section covers shrinking an image where
                # more than 1 source pixel may be required to
                # define the destination pixel
                set xr 0
                set xg 0
                set xb 0
                while { $xtot > $newx } {
                    incr xr $r
                    incr xg $g
                    incr xb $b
                    set xtot [expr {$xtot - $newx}]
                    incr x
                    foreach {r g b} [$phImg get $x $y] {break}
                }

                # Work out the new pixel colours
                set tr [expr {int( ($rn*$r + $xr + $rp*$pr) / $mx)}]
                set tg [expr {int( ($rn*$g + $xg + $rp*$pg) / $mx)}]
                set tb [expr {int( ($rn*$b + $xb + $rp*$pb) / $mx)}]

                if {$tr > 255} {set tr 255}
                if {$tg > 255} {set tg 255}
                if {$tb > 255} {set tb 255}

                # Output the pixel
                lappend row [format "#%02x%02x%02x" $tr $tg $tb]
                lappend thisrow $tr $tg $tb
                incr xtot $mx
                incr nx

                set pr $r
                set pg $g
                set pb $b
            }

            # Finish off pixels on this row
            while { $nx < $newx } {
                lappend row [format "#%02x%02x%02x" $r $g $b]
                lappend thisrow $r $g $b
                incr nx
            }

            # Do vertical resize
            if {[info exists prevrow]} {
                set nrow [list]
                # Add whole lines as necessary
                while { $ytot <= $newy } {
                    $dest put [list $prow] -to 0 $ny 
                    incr ytot $my
                    incr ny
                }

                # Now add mixed line
                # Calculate ratios to use
                set ytot [expr {$ytot - $newy}]
                set rn $ytot
                set rp [expr {$my - $rn}]

                # This section covers shrinking an image
                # where a single pixel is made from more than
                # 2 others.  Actually we cheat and just remove
                # a line of pixels which is not as good as it should be
                while { $ytot > $newy } {
                    set ytot [expr {$ytot - $newy}]
                    incr y
                    continue
                }

                # Calculate new row
                foreach {pr pg pb} $prevrow {r g b} $thisrow {
                    set tr [expr {int( ($rn*$r + $rp*$pr) / $my)}]
                    set tg [expr {int( ($rn*$g + $rp*$pg) / $my)}]
                    set tb [expr {int( ($rn*$b + $rp*$pb) / $my)}]
                    lappend nrow [format "#%02x%02x%02x" $tr $tg $tb]
                }

                $dest put [list $nrow] -to 0 $ny
                incr ytot $my
                incr ny
            }

            set prevrow $thisrow
            set prow $row
        }

        # Finish off last rows
        while { $ny < $newy } {
            $dest put [list $row] -to 0 $ny
            incr ny
        }
        return $dest
    }

    proc _ResizeAlpha { phImg newx newy { dest "" } } {
        # Scale an image to new size (newx, newy) and return
        # the resized image as a new photo image, if "dest" is
        # the empty string. Otherwise "dest" must be a valid 
        # photo image, where the resize image will be written to.

        set mx [image width  $phImg]
        set my [image height $phImg]

        if { $dest eq "" } {
            set dest [image create photo -width $newx -height $newy]
        } else {
            $dest configure -width $newx -height $newy
        }

        # Check if we can just zoom using -zoom option on copy
        if { $newx % $mx == 0 && $newy % $my == 0} {
            set ix [expr {$newx / $mx}]
            set iy [expr {$newy / $my}]
            $dest copy $phImg -zoom $ix $iy
            return $dest
        }

        set ny 0
        set ytot $my
        for {set y 0} {$y < $my} {incr y} {
            # Do horizontal resize
            foreach {pr pg pb pa} [$phImg get 0 $y -withalpha] {break}

            set row [list]
            set thisrow [list]
            set nx 0
            set xtot $mx
            for {set x 1} {$x < $mx} {incr x} {
                # Add whole pixels as necessary
                while { $xtot <= $newx } {
                    lappend row [format "#%02x%02x%02x%02x" $pr $pg $pb $pa]
                    lappend thisrow $pr $pg $pb $pa
                    incr xtot $mx
                    incr nx
                }

                # Now add mixed pixels
                foreach {r g b a} [$phImg get $x $y -withalpha] {break}

                # Calculate ratios to use
                set xtot [expr {$xtot - $newx}]
                set rn $xtot
                set rp [expr {$mx - $xtot}]

                # This section covers shrinking an image where
                # more than 1 source pixel may be required to
                # define the destination pixel
                set xr 0
                set xg 0
                set xb 0
                set xa 0
                while { $xtot > $newx } {
                    incr xr $r
                    incr xg $g
                    incr xb $b
                    incr xa $a
                    set xtot [expr {$xtot - $newx}]
                    incr x
                    foreach {r g b a} [$phImg get $x $y -withalpha] {break}
                }

                # Work out the new pixel colours
                set tr [expr {int( ($rn*$r + $xr + $rp*$pr) / $mx)}]
                set tg [expr {int( ($rn*$g + $xg + $rp*$pg) / $mx)}]
                set tb [expr {int( ($rn*$b + $xb + $rp*$pb) / $mx)}]
                set ta [expr {int( ($rn*$a + $xa + $rp*$pa) / $mx)}]

                if {$tr > 255} {set tr 255}
                if {$tg > 255} {set tg 255}
                if {$tb > 255} {set tb 255}
                if {$ta > 255} {set ta 255}

                # Output the pixel
                lappend row [format "#%02x%02x%02x%02x" $tr $tg $tb $ta]
                lappend thisrow $tr $tg $tb $ta
                incr xtot $mx
                incr nx

                set pr $r
                set pg $g
                set pb $b
                set pa $a
            }

            # Finish off pixels on this row
            while { $nx < $newx } {
                lappend row [format "#%02x%02x%02x%02x" $r $g $b $a]
                lappend thisrow $r $g $b $a
                incr nx
            }

            # Do vertical resize
            if {[info exists prevrow]} {
                set nrow [list]
                # Add whole lines as necessary
                while { $ytot <= $newy } {
                    $dest put [list $prow] -to 0 $ny 
                    incr ytot $my
                    incr ny
                }

                # Now add mixed line
                # Calculate ratios to use
                set ytot [expr {$ytot - $newy}]
                set rn $ytot
                set rp [expr {$my - $rn}]

                # This section covers shrinking an image
                # where a single pixel is made from more than
                # 2 others.  Actually we cheat and just remove
                # a line of pixels which is not as good as it should be
                while { $ytot > $newy } {
                    set ytot [expr {$ytot - $newy}]
                    incr y
                    continue
                }

                # Calculate new row
                foreach {pr pg pb pa} $prevrow {r g b a} $thisrow {
                    set tr [expr {int( ($rn*$r + $rp*$pr) / $my)}]
                    set tg [expr {int( ($rn*$g + $rp*$pg) / $my)}]
                    set tb [expr {int( ($rn*$b + $rp*$pb) / $my)}]
                    set ta [expr {int( ($rn*$a + $rp*$pa) / $my)}]
                    lappend nrow [format "#%02x%02x%02x%02x" $tr $tg $tb $ta]
                }

                $dest put [list $nrow] -to 0 $ny
                incr ytot $my
                incr ny
            }

            set prevrow $thisrow
            set prow $row
        }

        # Finish off last rows
        while { $ny < $newy } {
            $dest put [list $row] -to 0 $ny
            incr ny
        }
        return $dest
    }

    if { [package vsatisfies [package version Tk] "8.7-"] } {
        rename _ResizeAlpha Resize
    } else {
        rename _Resize Resize
    }

    proc Blur { phImg coef } {
        # Blur an image with factor coef (0.0 .. 1.0) and return
        # the blurred image as a new photo image.

        # check coef
        if {$coef < 0.0 || $coef > 1.0} {
            error "bad coef \"$coef\": should be in the range 0.0, 1.0"
        }
        if {$coef < 1.e-5} { return $phImg }
        set coef2 [expr {$coef / 8.0}]
        # get the old image content
        set width  [image width $phImg]
        set height [image height $phImg]
        if {$width * $height == 0} { error "bad image" }
        # create corresponding planes
        for {set y 0} {$y < $height} {incr y} {
            set r:row {}
            set g:row {}
            set b:row {}
            for {set x 0} {$x < $width} {incr x} {
                foreach {r g b} [$phImg get $x $y] break
                foreach c {r g b} { lappend $c:row [set $c] }
            }
            foreach c {r g b} { lappend $c:data [set $c:row] }
        }
        # blurring
        for {set y 0} {$y < $height} {incr y} {
            set row2 {}
            for {set x 0} {$x < $width} {incr x} {
                foreach c {r g b} {
                    set c00 [lindex [set $c:data] [expr {$y-2}] [expr {$x-2}]]
                    set c01 [lindex [set $c:data] [expr {$y-1}] [expr {$x  }]]
                    set c02 [lindex [set $c:data] [expr {$y-2}] [expr {$x+2}]]
                    set c10 [lindex [set $c:data] [expr {$y  }] [expr {$x-1}]]
                    set c11 [lindex [set $c:data] [expr {$y  }] [expr {$x  }]]
                    set c12 [lindex [set $c:data] [expr {$y  }] [expr {$x+1}]]
                    set c20 [lindex [set $c:data] [expr {$y+2}] [expr {$x-2}]]
                    set c21 [lindex [set $c:data] [expr {$y+1}] [expr {$x  }]]
                    set c22 [lindex [set $c:data] [expr {$y+2}] [expr {$x+2}]]
                    foreach v {c00 c01 c02 c10 c12 c20 c21 c22} {
                        if {[set $v] == ""} { set $v 0.0 }
                    }
                    set cc [expr {int((1.0 - $coef) * $c11 + \
                            $coef2 * ($c00 + $c01 + $c02 + $c10 + $c12 + $c20 + $c21 + $c22))}]
                    if {$cc < 0}   { set cc 0 }
                    if {$cc > 255} { set cc 255 }
                    set $c $cc
                }
                lappend row2 [format #%02x%02x%02x $r $g $b]
            }
            lappend data2 $row2
        }
        set dest [image create photo]
        $dest put $data2
        return $dest
    }

    proc HSV { phImg brightness { saturation 1.0 } } {
        # Change brightness and saturation of an image and return
        # the changed image as a new photo image.

        set vcoef $brightness
        set scoef $saturation
        # get the old image content
        set width  [image width $phImg]
        set height [image height $phImg]
        if {$width * $height == 0} { error "bad image" }
        # create corresponding planes
        for {set y 0} {$y < $height} {incr y} {
            set row2 {}
            for {set x 0} {$x < $width} {incr x} {
                foreach {r g b} [$phImg get $x $y] break
                # convert to HSV
                set min [expr {$r < $g ? $r : $g}]
                set min [expr {$b < $min ? $b : $min}]
                set max [expr {$r > $g ? $r : $g}]
                set max [expr {$b > $max ? $b : $max}]
                set v $max
                set delta [expr {$max - $min}]
                if {$max == 0 || $delta == 0} {
                    set s 0
                    set h -1
                } else {
                    set s [expr {$delta / double($max)}]
                    if {$r == $max} {
                        set h [expr {0.0   + ($g - $b) * 60.0 / $delta}]
                    } elseif {$g == $max} {
                        set h [expr {120.0 + ($b - $r) * 60.0 / $delta}]
                    } else {
                        set h [expr {240.0 + ($r - $g) * 60.0 / $delta}]
                    }
                }
                if {$h < 0.0} { set h [expr {$h + 360.0}] }
                # manipulate HSV components
                set s [expr {$s * $scoef}]
                set v [expr {$v * $vcoef}]
                # convert to RGB
                if {$s == 0} {
                    foreach c {r g b} { set $c [expr {int($v)}] }
                } else {
                    set f [expr {$h / 60.0}]
                    set i [expr {int($f)}]
                    set f [expr {$f - $i}]
                    set p [expr {$v * (1 - $s)}]
                    set q [expr {$v * (1 - $s * $f)}]
                    set t [expr {$v * (1 - $s * (1 - $f))}]
                    set list {
                        {v t p}
                        {q v p}
                        {p v t}
                        {p q v}
                        {t p v}
                        {v p q}
                    }
                    foreach c {r g b} u [lindex $list $i] {
                        set $c [expr {int([set $u])}]
                        if {[set $c] < 0} { set $c 0 }
                        if {[set $c] > 255} { set $c 255 }
                    }
                }
                lappend row2 [format #%02x%02x%02x $r $g $b]
            }
            lappend data2 $row2
        }
        set phImg2 [image create photo]
        $phImg2 put $data2
        return $phImg2
    }

    proc Tile { phImg xRepeat yRepeat { xMirror false } { yMirror false } } {
        # Tile an image horizontally by "xRepeat" and vertically by "yRepeat".
        # If "xMirror" is given and true, the images are mirrored horizontally.
        # If "yMirror" is given and true, the images are mirrored vertically.
        # The tiled image is returned as a new photo image.

        set w [image width  $phImg]
        set h [image height $phImg]
        set w2 [expr {$w * $xRepeat}]
        set h2 [expr {$h * $yRepeat}]

        set tileImg [image create photo -width $w2 -height $h2]

        for { set x 0 } { $x < $xRepeat } { incr x } {
            for { set y 0 } { $y < $yRepeat } { incr y } {
                if { $xMirror || $yMirror } {
                    set xsamp 1
                    set ysamp 1
                    if { $xMirror && [expr {$x %2}] == 1 } {
                        set xsamp -1
                        }
                    if { $yMirror && [expr {$y %2}] == 1 } {
                        set ysamp -1
                    }
                    set sampleCmd [format "-subsample %d %d" $xsamp $ysamp]
                } else {
                    set sampleCmd ""
                }
                eval $tileImg copy $phImg -to [expr $x*$w] [expr $y*$h] $sampleCmd
            }
        }
        return $tileImg
    }

    proc Compose { numColumns args } {
        # Compose a list of images given in "args" into one image.
        # The images are arranged from left to right, top to bottom,
        # assuming "numColumns" columns.
        # The composed image is returned as a new photo image.

        set dest [image create photo]
        set x 0
        set y 0
        set curColumn 0
        foreach phImg $args {
            $dest copy $phImg -to $x $y
            incr x [image width $phImg]
            incr curColumn
            if { $curColumn >= $numColumns } {
                set x 0
                set y [image height $dest]
                set curColumn 0
            }
        }
        return $dest
    }

    # Internal utility procedure for Reduce.
    proc _Subdivide { pixList depth } {
        variable new

        set num [llength $pixList]

        for {set i 0} {$i < 256} {incr i} {
            set n(r,$i) 0
            set n(g,$i) 0
            set n(b,$i) 0
        }

        foreach pix $pixList {
            foreach {r g b} $pix break
            incr n(r,$r)
            incr n(g,$g)
            incr n(b,$b)
        }

        # Work out which colour has the widest range
        foreach col [list r g b] {
            set l($col) [list]
            for {set i 0} {$i < 256} {incr i} {
                if { $n($col,$i) != 0 } {
                    lappend l($col) $i
                }
            }
            set range($col) [expr {[lindex $l($col) end] - [lindex $l($col) 0]}]
        }

        if { $depth == 0 || \
            ($range(r) == 0 && $range(g) == 0 && $range(b) == 0) } {
            # Average colours
            foreach col [list r g b] {
                set tot 0
                foreach entry $l($col) {
                    incr tot [expr {$n($col,$entry) * $entry}]
                }
                set av($col) [expr {$tot / $num}]
            }

            set newpixel [list $av(r) $av(g) $av(b)]
            set fpixel [format "#%02x%02x%02x" $av(r) $av(g) $av(b)]

            foreach entry $pixList {
                set new($entry) $fpixel
            }
            incr new(count)
        } else {
            # Find out which colour has the maximum range
            # (green, red, blue in order of importance)
            set maxrange -1
            foreach col [list g r b] {
                if { $range($col) > $maxrange } {
                    set splitcol $col
                    set maxrange $range($col)
                }
            }

            # Now work out where to split it
            set thres [expr {$num / 2}]
            set pn 0
            set tn 0
            set pl [lindex $l($splitcol) 0]

            foreach tl $l($splitcol) {
                incr tn $n($splitcol,$tl)
                if { $tn > $thres } {
                    if { $tn - $thres < $thres - $pn } {
                        set cutnum $tl
                    } else {
                        set cutnum $pl
                    }
                    break
                }
                set pn $tn
                set pl $tl
            }
            # Now split the pixels into the 2 lists
            set hiList [list]
            set loList [list]

            set i [lsearch [list r g b] $splitcol]
            foreach entry $pixList {
                if { [lindex $entry $i] <= $cutnum } {
                    lappend loList $entry
                } else {
                    lappend hiList $entry
                }
            }
            incr depth -1

            _Subdivide $loList $depth
            _Subdivide $hiList $depth
        }
    }

    # Internal utility procedure for Reduce.
    proc _Apply { phImg dest } {
        variable new

        set w [image width $phImg]
        set h [image height $phImg]
        $dest configure -width $w -height $h

        for {set y 0} {$y < $h} {incr y} {
            set row [list]
            for {set x 0} {$x < $w} {incr x} {
                lappend row $new([$phImg get $x $y])
            }
            $dest put [list $row] -to 0 $y
            update idletasks
        }
    }

    proc Reduce { phImg depth } {
        # Reduce the color depth of an image to "depth" bits.
        # The reduction uses the median-cut algorithm.
        # The reduced image is returned as a new photo image.

        variable new

        set w [image width $phImg]
        set h [image height $phImg]
        set dest [image create photo -width $w -height $h]

        set pixList [list]
        set new(count) 0

        for {set y 0} {$y < $h} {incr y} {
            for {set x 0} {$x < $w} {incr x} {
                lappend pixList [$phImg get $x $y]
            }
        }
        _Subdivide $pixList $depth
        _Apply $phImg $dest
        return $dest
    }

    proc Difference { phImg1 phImg2 } {
        # Calculate the difference image of images "phImg1" and "phImg2".
        # The difference image is returned as a new photo image.

        set w1 [image width  $phImg1]
        set h1 [image height $phImg1]
        set w2 [image width  $phImg2]
        set h2 [image height $phImg2]
        if { $w1 != $w2 && $h1 != $h2 } {
            error "Images differ in size. No difference image possible."
        }
        set dest [image create photo -width $w1 -height $h1]

        for { set y 0 } { $y < $h1 } { incr y } {
            set data [list]
            set scanline [list]
            for { set x 0 } { $x < $w1 } { incr x } {
                set left  [$phImg1 get $x $y]
                set right [$phImg2 get $x $y]

                set dr [expr { [lindex $right 0] - [lindex $left 0] }]
                if { $dr < 0 } { set dr [expr {-$dr}] }

                set dg [expr { [lindex $right 1] - [lindex $left 1] }]
                if { $dg < 0 } { set dg [expr {-$dg}] }

                set db [expr { [lindex $right 2] - [lindex $left 2] }]
                if { $db < 0 } { set db [expr {-$db}] }

                lappend scanline [format "#%02X%02X%02X" $dr $dg $db]
            }
            lappend data $scanline
            $dest put $data -to 0 $y
        }
        return $dest
    }

    # Some internal utility procedures for GetImgStats.
    proc _Min { a b } {
        if { $a < $b } {
            return $a
        } else {
            return $b
        }
    }

    proc _Max { a b } {
        if { $a > $b } {
            return $a
        } else {
            return $b
        }
    }

    proc _Square { x } {
        return [expr {$x * $x}]
    }

    proc GetImgStats { phImg { calcStdDev false } \
                       { x1 0 } { y1 0 } { x2 100000 } { y2 100000 } } {
        # Calculate the minimum, maximum and arithmetic mean values of parts of an
        # image. If "calcStdDev" is given and set to true, the standard deviation
        # is calculated, too.
        # The image statistics values are returned as a dictionary containing the keys
        # "min", "max", "mean", "std" and "num".
        # "num" gives the number of pixels processed.

        set w1 [expr {[image width $phImg]  - 1}]
        set h1 [expr {[image height $phImg] - 1}]

        set x1 [_Max $x1 0]
        set y1 [_Max $y1 0]
        set x2 [_Min $x2 $w1]
        set y2 [_Min $y2 $h1]

        set count [expr {($x2-$x1+1) * ($y2-$y1+1)}]

        foreach color [list red green blue] {
            set min($color) 255
            set max($color)   0
            set sum($color)   0
        }
        for { set x $x1 } { $x <= $x2 } { incr x } {
            for { set y $y1 } { $y <= $y2 } { incr y } {
                set rgb [$phImg get $x $y]
                set r [lindex $rgb 0]
                set g [lindex $rgb 1]
                set b [lindex $rgb 2]
                if { $r < $min(red) } {
                    set min(red) $r
                } elseif { $r > $max(red) } {
                    set max(red) $r
                }
                if { $g < $min(green) } {
                    set min(green) $g
                } elseif { $g > $max(green) } {
                    set max(green) $g
                }
                if { $b < $min(blue) } {
                    set min(blue) $b
                } elseif { $b > $max(blue) } {
                    set max(blue) $b
                }
                set sum(red)   [expr {$sum(red)   + $r}]
                set sum(green) [expr {$sum(green) + $g}]
                set sum(blue)  [expr {$sum(blue)  + $b}]
            }
        }
        if { $count > 0 } {
            foreach color [list red green blue] {
                set mean($color) [expr {double($sum($color)) / double($count)}]
                dict set statDict "min"  $color $min($color)
                dict set statDict "max"  $color $max($color)
                dict set statDict "mean" $color $mean($color)
            }
        }
        if { $calcStdDev } {
            set std(red)   0.0
            set std(green) 0.0
            set std(blue)  0.0
            for { set x $x1 } { $x <= $x2 } { incr x } {
                for { set y $y1 } { $y <= $y2 } { incr y } {
                    set rgb [$phImg get $x $y]
                    set diff(red)   [_Square [expr {$mean(red)  -[lindex $rgb 0]}]]
                    set diff(green) [_Square [expr {$mean(green)-[lindex $rgb 1]}]]
                    set diff(blue)  [_Square [expr {$mean(blue) -[lindex $rgb 2]}]]
                    set std(red)   [expr {$std(red)   + $diff(red)}]
                    set std(green) [expr {$std(green) + $diff(green)}]
                    set std(blue)  [expr {$std(blue)  + $diff(blue)}]
                }
            }
            if { $count > 0 } {
                foreach color [list red green blue] {
                    if { $count == 1 } {
                        dict set statDict "std" $color $std($color)
                     } else {
                        dict set statDict "std" $color \
                             [expr {sqrt (double ($std($color)) / double ($count-1))}]
                    }
                }
            }
        }
        dict set statDict "num" $count
        return $statDict
    }

    proc GetImgStatsLabels { { level 0 } } {
        set infoLabels [list "Width" "Height" "Pixels" "Pages"]

        if { $level >= 1 } {
            lappend infoLabels "Minimum"
            lappend infoLabels "Maximum"
            lappend infoLabels "Mean"
        }
        if { $level >= 2 } {
            lappend infoLabels "StdDev"
        }
        if { [poImgType HaveDpiSupport] } {
            lappend infoLabels "DPI"
        }
        return $infoLabels
    }

    proc Histogram { phImg { description "" } } {
        # Return the histogram of photo image "img" as a dictionary.
        # The dictionary has the following keys:
        # "red", "green" and "blue", each containing a list of 256 values
        # representing the number of pixels with that color value.
        # "width" and "height" containing the width andthe height of the
        # supplied image.
        # The key "description" can be specified as optional parameter.
        # If "description" is not specified or an empty string,
        # the identifier of "img" is used as the description.

        set w [image width  $phImg]
        set h [image height $phImg]

        foreach color { red green blue } {
            for { set i 0 } { $i < 256 } { incr i } {
                set count($color,$i) 0
            }
        }
        for { set y 0 } { $y < $h } { incr y } {
            for { set x 0 } { $x < $w } { incr x } {
                set val [$phImg get $x $y]
                incr count(red,[lindex $val 0])
                incr count(green,[lindex $val 1])
                incr count(blue,[lindex $val 2])
            }
        }
        foreach color { red green blue } {
            set histoList [list]
            for { set i 0 } { $i < 256 } { incr i } {
                lappend histoList $count($color,$i)
            }
            dict set histoDict $color $histoList
        }

        dict set histoDict "width"  $w
        dict set histoDict "height" $h

        if { $description eq "" } {
            dict set histoDict "description" $phImg
        } else {
            dict set histoDict "description" $description
        }
        return $histoDict
    }

    proc ScaleHistogram { histoDict height { histoType "log" } } {
        # Return a scaled histogram dictionary based on the given histogram
        # dictionary "histoDict. The values of the given histogram are scaled
        # either logarithmically or linearly, depending on the value of "histoType".
        # Possible "histoType" values are: log or lin.
        # The returned dictionary has 3 keys "red", "green" and "blue",
        # each containing a list of 256 values, so that the maximum value
        # is equal to "height".
        # Use this procedure to scale histogram values to fit into an image or
        # canvas of size 256xheight.
        # See DrawHistogram.

        set useLogScale false
        if { $histoType eq "log" } {
            set useLogScale true
        }
        foreach color { red green blue } {
            set max 0
            for { set i 0 } { $i < 256 } { incr i } {
                set max [_Max [lindex [dict get $histoDict $color] $i] $max]
            }
            set scaledList [list]
            if { $useLogScale } {
                set denom [expr {$height / log10($max)}]
            } else {
                set denom [expr {$height / double($max)}]
            }
            for { set i 0 } { $i < 256 } { incr i } {
                set histoVal [lindex [dict get $histoDict $color] $i]
                set val 0
                if { $histoVal != 0 } {
                    if { $useLogScale } {
                        set val [expr {int(log10($histoVal) * $denom)}]
                    } else {
                        set val [expr {int($histoVal * $denom)}]
                    }
                    # The scale value might be clipped to zero, but the
                    # histogram value is greater than zero. Set the scaled
                    # value to at least 1, so that there is at least 1 pixel
                    # in a visual representation.
                    set val [_Max $val 1]
                }
                lappend scaledList $val
            }
            dict set scaledDict $color $scaledList
        }
        return $scaledDict
    }

    # Internal utility procedure for DrawHistogram.
    proc _DrawVertLine { phImg x y1 y2 color } {
        set ymin [_Min $y1 $y2]
        set ymax [_Max $y1 $y2]
        $phImg put $color -to $x $ymin [expr {$x +1}] $ymax
    }

    proc DrawHistogram { scaledDict height color } {
        # Draw the histogram of color channel "color" of an image.
        # The histogram is drawn into a photo image of size 256x$height.
        # The values of the histogram must be supplied as a dictionary in
        # "scaledDict", which can be retrieved by ScaleHistogram.
        # The new histogram image is returned as a new photo image.

        if { $color eq "red" } {
            set imgColor "#FF0000"
        } elseif { $color eq "green" } {
            set imgColor "#00FF00"
        } elseif { $color eq "blue" } {
            set imgColor "#0000FF"
        } else {
            error "Invalid color name $color"
        }
        set dest [image create photo -width 256 -height $height]
        set col 0
        foreach val [dict get $scaledDict $color] {
            _DrawVertLine $dest $col $height [expr {$height - $val}] $imgColor
            incr col
        }
        return $dest
    }

    proc CountColors { phImg pixelArray } {
        # Count unique colors of photo image "img".
        # Each different color is stored as a key in Tcl array pixelArray.
        # The number of occurences of each color is the corresponding value.
        # Example: pixelArray(0 128 255) 12 indicates that color (0, 128,255)
        # occurs 12 times in the image.
        # To get the number of unique colors, use [array size pixelArray]

        upvar $pixelArray arr

        set w [image width  $phImg]
        set h [image height $phImg]

        for { set y 0 } { $y < $h } { incr y } {
            for { set x 0 } { $x < $w } { incr x } {
                set val [$phImg get $x $y]
                if { ! [info exists arr($val)] } {
                    set arr($val) 1
                } else {
                    incr arr($val)
                }
            }
        }
    }

    proc MarkColors { phImg sr sg sb markColor } {
        # Mark pixels of a given color of photo image "img".

        set w [image width  $phImg]
        set h [image height $phImg]

        set dest [CopyImg $phImg]

        for { set y 0 } { $y < $h } { incr y } {
            for { set x 0 } { $x < $w } { incr x } {
                foreach {r g b} [$phImg get $x $y] {break}
                if { $r == $sr && $g == $sg && $b == $sb } {
                    $dest put $markColor -to $x $y
                }
            }
        }
        return $dest
    }

    proc SetTransparentColor { phImg { red 255 } { green 255 } { blue 255 } } { 
        set colorStr [format "#%02x%02x%02x" $red $green $blue]
        set y 0
        foreach row [$phImg data] {
            set x 0
            foreach pixel $row {
                if { $colorStr eq $pixel } { 
                    $phImg transparency set $x $y 1
                }
                incr x
            }
            incr y
        }
    }

    proc AssignPalette { phImg channelNum paletteList { inverseMap false } } {
        set w [image width  $phImg]
        set h [image height $phImg]

        set dest [image create photo -width $w -height $h]

        if { $inverseMap } {
            set index 0
            foreach color $paletteList {
                lassign $color r g b
                set map([format "#%02x%02x%02x" $r $g $b]) [format "#%02x%02x%02x" $index $index $index]
                incr index
            }

            for { set y 0 } { $y < $h } { incr y } {
                set rowList [list]
                for { set x 0 } { $x < $w } { incr x } {
                    set pixelVal [$phImg get $x $y]
                    lassign $pixelVal r g b
                    set pixelStr [format "#%02x%02x%02x" $r $g $b]
                    if { [info exists map($pixelStr)] } {
                        lappend rowList $map($pixelStr)
                    } else {
                        lappend rowList [poImgPalette GetUnusedColor]
                    }
                }
                lappend imgList $rowList
            }
        } else {
            foreach color $paletteList {
                lassign $color r g b
                lappend colorList [format "#%02x%02x%02x" $r $g $b]
            }

            for { set y 0 } { $y < $h } { incr y } {
                set rowList [list]
                for { set x 0 } { $x < $w } { incr x } {
                    set channelVal [lindex [$phImg get $x $y] $channelNum]
                    lappend rowList [lindex $colorList $channelVal]
                }
                lappend imgList $rowList
            }
        }
        $dest put $imgList
        return $dest
    }
}
