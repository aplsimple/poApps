# Module:         poWinClipboard
# Copyright:      Paul Obermeier 2013-2023 / paul@poSoft.de
# First Version:  2023 / 04 / 15
#
# Distributed under BSD license.
#
# Module for graphical user interface for the Windows clipboard.

set scriptDir [file normalize [file dirname [info script]]]
set auto_path [linsert $auto_path 0 $scriptDir]

package require Tk
package require scrollutil_tile
package require tablelist_tile
package require poTklib

wm withdraw .
poWinClipboard OpenClipboardWin "Clipboard Viewer"
