# Module:         poTablelistUtil
# Copyright:      Paul Obermeier 2014-2023 / paul@poSoft.de
# First Version:  2014 / 10 / 26
#
# Distributed under BSD license.

namespace eval poTablelistUtil {
    variable ns [namespace current]

    namespace ensemble create

    # Table related utility procedures.
    namespace export RevertTable
    namespace export SelectTable
    namespace export GetNumRows GetNumCols

    # Row related utility procedures.
    namespace export IsRowSelected
    namespace export GetFirstSelectedRow
    namespace export SelectRow
    namespace export RemoveSelectedRows
    namespace export ShiftRow

    # Column related utility procedures.
    namespace export IsColumnSelected
    namespace export GetNumSelectedColumns
    namespace export GetFirstSelectedColumn
    namespace export SelectColumn
    namespace export DeselectColumn
    namespace export ToggleColumn

    # Cell related utility procedures.
    namespace export GetCellValue SetCellValue

    namespace export Init

    # Init is called at package load time.
    proc Init {} {
    }

    #
    # Table related utility procedures.
    #

    proc RevertTable { tableId } {
        if { [$tableId size] > 1 } {
            set rowList [$tableId get 0 end]
            $tableId delete 0 end
            foreach row [lreverse $rowList] {
                $tableId insert end $row
            }
        }
    }

    proc SelectTable { tableId { select true } } {
        if { $select } {
            $tableId selection set 0 end
        } else {
            $tableId selection clear 0 end
        }
    }

    proc GetNumRows { tableId } {
        return [$tableId size]
    }

    proc GetNumCols { tableId } {
        set matrix [$tableId get 0 end]
        set maxColSize 0
        foreach row $matrix {
            set colSize [llength $row]
            if { $colSize > $maxColSize } {
                set maxColSize $colSize
            }
        }
        return $maxColSize
    }

    #
    # Row related utility procedures.
    #

    proc IsRowSelected { tableId { row "" } } {
        set indList [$tableId curselection]
        if { $row eq "" } {
            return [expr { [llength $indList] > 0 }]
        } else {
            if { [lsearch -exact -integer $indList $row] >= 0 } {
                return true
            } else {
                return false
            }
        }
    }

    proc GetFirstSelectedRow { tableId } {
        set indList [$tableId curselection]
        if { [llength $indList] == 0 } {
            error "No row selected"
        }
        return [lindex $indList 0]
    }

    proc SelectRow { tableId row { showSelectedRow true } } {
        $tableId selection clear 0 end
        $tableId selection set $row $row
        if { $showSelectedRow } {
            $tableId see $row
        }
    }

    proc RemoveSelectedRows { tableId { selectNextEntry true } } {
        set indList [$tableId curselection]
        if { [llength $indList] > 0 } {
            set lastSelectedInd [lindex $indList end]
            $tableId delete $indList
            if { $selectNextEntry } {
                if { $lastSelectedInd < [$tableId size] } {
                    $tableId selection set $lastSelectedInd
                } else {
                    $tableId selection set end
                }
            }
        }
    }

    proc ShiftRow { tableId direction } {
        # Shift selected row up or down.
        # If direction is negative or zero, the row is shifted up.
        # Otherwise the row is shifted down.
        # If more than one row is selected, only the first selected row is shifted.
        # Return the source and target row as a list.

        set indList [$tableId curselection]
        set sourceRow -1
        set targetRowReturn -1
        if { [llength $indList] > 0 } {
            set sourceRow [lindex $indList 0]
            if { $direction < 0 } {
                set targetRow [expr {$sourceRow - 1}]
                set targetRowReturn $targetRow
            } else {
                set targetRow [expr {$sourceRow + 2}]
                set targetRowReturn [expr {$targetRow -1}]
            }
            # puts "$sourceRow -> $targetRow"
            if { $targetRow >= 0 && $targetRow <= [$tableId size] } {
                # puts "Move $sourceRow -> $targetRow"
                $tableId move $sourceRow $targetRow
            } else {
                set targetRowReturn -1
            }
        }
        return [list $sourceRow $targetRowReturn]
    }

    #
    # Column related utility procedures.
    #
    proc IsColumnSelected { tableId col } {
        set attrib [$tableId columnattrib $col "Selected"]
        if { $attrib == 0 || $attrib eq "" } {
            return false
        } else {
            return true
        }
    }

    proc GetNumSelectedColumns { tableId { dataColStart 0 } } {
        set numSelected 0
        for { set col $dataColStart } { $col < [$tableId columncount] } { incr col } {
            if { [IsColumnSelected $tableId $col] } {
                incr numSelected
            }
        }
        return $numSelected
    }

    proc GetFirstSelectedColumn { tableId { dataColStart 0 } } {
        for { set col $dataColStart } { $col < [$tableId columncount] } { incr col } {
            if { [IsColumnSelected $tableId $col] } {
                return $col
            }
        }
        return -1
    }

    proc SelectColumn { tableId colInd { color {} } } {
        $tableId columnconfigure $colInd -bg $color
        $tableId columnconfigure $colInd -labelbg $color
        $tableId columnattrib $colInd "Selected" 1
    }

    proc DeselectColumn { tableId colInd } {
        $tableId columnconfigure $colInd -bg {}
        $tableId columnconfigure $colInd -labelbg {}
        $tableId columnattrib $colInd "Selected" 0
    }

    proc ToggleColumn { tableId col { dataColStart 0 } { color {} } } {
        # The first two columns (Numbering and Time) enable/disable all data columns.
        if { $col < $dataColStart } {
            if { [IsColumnSelected $tableId $col] } {
                for { set c 0 } { $c < [$tableId columncount] } { incr c } {
                    DeselectColumn $tableId $c
                }
            } else {
                for { set c 0 } { $c < [$tableId columncount] } { incr c } {
                    SelectColumn $tableId $c $color
                }
            }
        } else {
            if { [IsColumnSelected $tableId $col] } {
                DeselectColumn $tableId $col
            } else {
                SelectColumn $tableId $col $color
            }
        }
    }

    #
    # Cell related utility procedures.
    #

    proc GetCellValue { tableId row col } {
        return [$tableId cellcget "$row,$col" -text]
    }

    proc SetCellValue { tableId row col value } {
        $tableId cellconfigure "$row,$col" -text $value
    }
}

poTablelistUtil Init
