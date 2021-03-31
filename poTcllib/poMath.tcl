# Module:         poMath
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 06 / 22
#
# Distributed under BSD license.
#
# Module with math related procedures.

namespace eval poMath {
    variable ns [namespace current]

    namespace ensemble create

    variable sMaxInt32   2147483647
    variable sMaxFloat64 1.7976931348623158e+308

    namespace export ZeroKelvinAsCelsius
    namespace export CheckIntRange CheckRealRange
    namespace export CheckDateOrTimeString

    proc ZeroKelvinAsCelsius {} {
        return -273.15
    }

    proc CheckIntRange { checkVal { minVal "" } { maxVal "" } } {
        variable sMaxInt32

        if { $minVal eq "" && $maxVal eq "" } {
            return [string is integer -strict $checkVal]
        }

        if { $maxVal eq "" } {
            set maxVal $sMaxInt32
        }
        if { ! [string is integer -strict $checkVal] } {
            return 0
        }
        if { $checkVal >= $minVal && $checkVal <= $maxVal } {
            return 1
        }
        return 0
    }

   proc CheckRealRange { checkVal { minVal "" } { maxVal "" } } {
        variable sMaxFloat64

        if { $minVal eq "" && $maxVal eq "" } {
            return [string is double -strict $checkVal]
        }
        if { $maxVal eq "" } {
            set maxVal $sMaxFloat64
        }
        set retVal [catch {set curVal [expr double ($checkVal)] }]
        if { $retVal == 0 } {
            if { $curVal >= $minVal && $curVal <= $maxVal } {
                return 1
            }
        }
        return 0
    }

    proc CheckDateOrTimeString { dateOrTimeString dateOrTimeFmt } {
        set retVal [catch { clock scan $dateOrTimeString -format $dateOrTimeFmt } dateOrTimeVal]
        return [expr ! $retVal]
    }
}

