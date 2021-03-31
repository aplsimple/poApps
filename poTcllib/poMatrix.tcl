# Module:         poMatrix
# Copyright:      Paul Obermeier 2017-2020 / paul@poSoft.de
# First Version:  2017 / 01 / 20
#
# Distributed under BSD license.
#
# Module for handling matrices stored as a list of lists.
# Each sublist corresponds to a row of the matrix.
#
# Example:
# set myMatrix = { { 1 2 3 }  { 4 5 6 }  { 7 8 9 } }
#     1 2 3
#     4 5 6
#     7 8 9

namespace eval poMatrix {
    variable ns [namespace current]

    namespace ensemble create

    namespace export ListToMatrix MatrixToList
    namespace export GetNumRows GetNumCols
    namespace export GetSum
    namespace export Normalize
    namespace export Format
    namespace export GetValue SetValue

    proc ListToMatrix { list numCols } {
        set mat [list]
        set col 0
        set rowList [list]
        foreach elem $list {
            lappend rowList $elem
            incr col
            if { $col == $numCols } {
                lappend mat $rowList
                set rowList [list]
                set col 0
            }
        }
        return $mat
    }

    proc MatrixToList { matrix } {
        return [join $matrix]
    }

    proc GetNumRows { matrix } {
        return [llength $matrix]
    }

    proc GetNumCols { matrix } {
        return [llength [lindex $matrix 0]]
    }

    proc GetSum { matrix } {
        set sum 0.0
        foreach rowList $matrix {
            foreach val $rowList {
                set sum [expr { $sum + $val }]
            }
        }
        return $sum
    }

    proc _Abs { a } {
        if { $a < 0 } {
            return [expr {-$a}]
        } else {
            return $a
        }
    }

    proc Normalize { matrix } {
        set sum [GetSum $matrix]

        if { [_Abs $sum] < 1.0E-4 } {
            error "Sum of matrix ($sum) is zero or near zero. Not able to normalize."
            return
        }

        set newMatrix [list]
        foreach rowList $matrix {
            set newRowList [list]
            foreach val $rowList {
                lappend newRowList [expr { $val / $sum }]
            }
            lappend newMatrix $newRowList
        }
        return $newMatrix
    }

    proc Format { matrix formatProc } {
        set newMatrix [list]
        foreach rowList $matrix {
            set newRowList [list]
            foreach val $rowList {
                lappend newRowList [$formatProc $val]
            }
            lappend newMatrix $newRowList
        }
        return $newMatrix
    }

    proc GetValue { matrix row col } {
        return [lindex [lindex $matrix $row] $col]
    }

    proc SetValue { matrix row col value } {
        upvar 0 $matrix mat
        lset mat $row $col $value
    }
}
