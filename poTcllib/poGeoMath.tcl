# Module:         poGeoMath
# Copyright:      Paul Obermeier 2016-2023 / paul@poSoft.de
# First Version:  2016 / 09 / 27
#
# Distributed under BSD license.
#
# Module for handling geographic coordinate conversions.
#

namespace eval poGeoMath {
    variable ns [namespace current]

    namespace ensemble create

    namespace export DecToDMS DMSToDec

    proc DecToDMS { decDeg { asString true } { numDigits 5 } } {
        # Convert decimal degree to DMS notation.
        #
        # decDeg   - double (angle in degrees)
        # asString - bool
        # numDigits- integer
        #
        # Convert angle "decDeg" into the DMS notation(i.e. Degree, Minute, Seconds).
        # If "asString" is true, the DMS value is returned as a string in the
        # format (+-)D°M'S".
        # Example: -32°15'1.23"
        #
        # Otherwise the DMS values are returned as a list in the
        # following order: { D M S Sign }
        # "numDigits" specifies the number of digits for the S value.
        #
        # See also: DMSToDec

        set scale [expr {wide (pow (10, $numDigits)) }]
        set scale3600 [expr {$scale*3600}]

        set angleInt [expr {wide (([poMisc Abs $decDeg] + 1.0/($scale3600*60)) * $scale3600) }]
        set degrees  [expr {$angleInt / 3600 / $scale}]
        set minutes  [expr {($angleInt - $degrees*$scale3600) / 60 / $scale }]
        set seconds  [expr {double ($angleInt - $degrees*$scale3600 - $minutes*60*$scale) / \
                            double ($scale) }]

        if { $decDeg < 0.0 } {
            set sign -1
            set signStr "-"
        } else {
            set sign 1
            set signStr " "
        }
        if { $asString } {
            return [format "%s%d°%d'%f\"" $signStr $degrees $minutes $seconds]
        } else {
            return [list $degrees $minutes $seconds $sign]
        }
    }

    proc DMSToDec { deg min sec sign } {
        # Convert DMS notation into decimal degree.
        #
        # deg  - integer (degrees of the angle)
        # min  - integer (minutes of the angle)
        # sec  - double  (seconds of the angle)
        # sign - integer
        #
        # Convert an angle specified in the DMS notation into a
        # decimal value. The converted value is returned as a
        # double value.
        #
        # See also: DecToDMS

        set absVal [expr {[poMisc Abs $deg] + $min/60.0 + $sec/3600.0 }]
        if { $sign < 0 } {
            return [expr {-$absVal}]
        } else {
            return $absVal
        }
    }
}

