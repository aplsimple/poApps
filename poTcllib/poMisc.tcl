# Module:         poMisc
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 01 / 23
#
# Distributed under BSD license.
#
# Module with miscellaneous functionality.

namespace eval poMisc {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export HavePkg GetPkgVersion
    namespace export HaveTcl87OrNewer
    namespace export HaveTcl9OrNewer
    namespace export SearchInFile ReplaceInFile SearchReplaceInFile
    namespace export FileSizeCompare FileDateCompare FileContentCompare
    namespace export GetCmpMode GetCmpModeString
    namespace export FileIdent
    namespace export FileCat FileConcat FileSplit
    namespace export FileConvert
    namespace export GetNetworkFolders GetNetworkDrives GetDrives
    namespace export DiskUsage
    namespace export GetFileInfoLabels FileInfo
    namespace export FormatByteSize
    namespace export FileCutPath
    namespace export AbsToRel
    namespace export FileSlashName
    namespace export HexDump HexDumpToFile
    namespace export CheckMatchList
    namespace export QuoteTilde QuoteSpaces QuoteRegexpChars QuoteSearchPattern
    namespace export CompactSpaces SplitMultSpaces
    namespace export AddNewlines
    namespace export Square IsSquare Abs Min Max
    namespace export Distance2D Distance3D
    namespace export IsPowerOfTwo
    namespace export DegToRad RadToDeg
    namespace export Plural
    namespace export RandomInit Random RandomRange
    namespace export ArrayToList ListToArray InsertIntoList
    namespace export CleanTclkitDirs
    namespace export GetTmpDir GetDesktopDir GetHomeDir
    namespace export GetFileAttr
    namespace export GetFileNumber ReplaceFileNumber
    namespace export IsHiddenFile
    namespace export IsReadableFile
    namespace export IsCaseSensitiveFileSystem 
    namespace export CountDirsAndFiles
    namespace export GetDirCont GetDirList GetDirsAndFiles
    namespace export Pack Unpack
    namespace export PrintMachineInfo PrintTclInfo
    namespace export DecToRgb RgbToDec
    namespace export Bitset GetBitsetIndices
    namespace export CharToNum NumToChar
    namespace export IsAndroid
    namespace export GetOSBits GetOSBitsStr
    namespace export BoolAsInt
    namespace export GetExtensionByType GetExtensions IsValidExtension
    namespace export PrintDict

    proc Init {} {
        variable PI
        variable randomSeed
        variable haveTcl84AndUp
        variable haveTcl87AndUp
        variable haveTcl9AndUp

        set PI 3.14159265358979323846
        set randomSeed 1.0

        # Check if Tcl version is greater than 8.4. glob semantics has changed slightly with 8.4.
        set haveTcl84AndUp [expr [package vcompare "8.4" [info tclversion]] <= 0]

        # Tcl must be greater or equal to 8.7 to have -text option with progressbar.
        set haveTcl87AndUp [expr [package vcompare "8.7" [info tclversion]] <= 0]

        # Tcl must be greater or equal to 9.0 to have "file tildeexpand" as replacement to ~.
        set haveTcl9AndUp [expr [package vcompare "9.0" [info tclversion]] <= 0]

        # Require packages, which are needed by some of the procedures.
        set retVal [catch { package require "tar" } version]
    }

    proc HavePkg { pkgName } {
        set retVal [catch {package present $pkgName} versionStr]
        if { $retVal != 0 } {
            return false
        } else {
            return true
        }
    } 

    proc GetPkgVersion { pkgName } {
        set retVal [catch {package present $pkgName} versionStr]
        if { $retVal != 0 } {
            return "0.0.0"
        } else {
            return $versionStr
        }
    }

    proc HaveTcl87OrNewer {} {
        variable haveTcl87AndUp

        return $haveTcl87AndUp
    }

    proc HaveTcl9OrNewer {} {
        variable haveTcl9AndUp

        return $haveTcl9AndUp
    }

    proc FileSlashName { fileName } {
        global tcl_platform

        # Convert file or directory name to Unix slash notation
        set slashName [file normalize $fileName]
        # Use the long name on Windows. Looks nicer in file lists. :-)
        if { $tcl_platform(platform) eq "windows" } {
            if { [file exists $slashName] } {
                set slashName [file attributes $slashName -longname]
            }
        }
        return $slashName
    }

    proc FileCutPath { pathName numPathItems } {
        # Return the last numPathItems of given path name.
        # If numPathItems is zero and pathName contains the file name,
        # it behaves like "file tail".

        set itemList [file split $pathName]
        set cutList [lrange $itemList end-$numPathItems end]
        set newName ""
        foreach item $cutList {
            set newName [file join $newName $item]
        }
        return $newName
    }

    proc AbsToRel { fileName rootDir } {
        # Return the relative path name of fileName compared to rootDir.
        # If fileName is not contained in rootDir, the original file name 
        # is returned.
        set rootDir  [string trimright $rootDir  "/"]
        set fileName [string trimright $fileName "/"]
        set rootLen [string length $rootDir]
        set fileLen [string length $fileName]
        if { $rootLen > $fileLen } {
            return $fileName
        }
        set rootItemList [file split $rootDir]
        set fileItemList [file split $fileName]
        if { [llength $rootItemList] > [llength $fileItemList] } {
            return $fileName
        }
        set ind 0
        foreach rootItem $rootItemList {
            if { $rootItem ne [lindex $fileItemList $ind] } {
                return $fileName
            }
            incr ind
        }
        set relPath [file join {*}[lrange $fileItemList $ind end]]
        return [format "./%s" $relPath]
    }

    proc FileCat { args } {
        foreach filename $args {
            # Don't bother catching errors, just let them propagate up
            set fd [open $filename r]
            # Use the [file size] command to get the size, which preallocates
            # memory rather than trying to grow it as the read progresses.
            set size [file size $filename]
            if { $size } {
                append data [read $fd $size]
            } else {
                # if the file has zero bytes it is either empty, or something
                # where [file size] reports 0 but the file actually has data (like
                # the files in the /proc filesystem on Linux)
                append data [read $fd]
            }
            close $fd
        }
        return $data
    }

    proc FileConcat { outFile args } {
        if { [file exists $outFile] } {
            set outFp [open $outFile "a"]
        } else {
            set outFp [open $outFile "w"]
        }
        fconfigure $outFp -translation binary

        foreach fileName $args {
            set catchVal [catch {open $fileName r} fp]
            if { $catchVal != 0 } {
                close $outFp
                error "Could not open file \"$fileName\" for reading."
            }
            fconfigure $fp -translation binary
            fcopy $fp $outFp
            close $fp
        }
        close $outFp
    }

    proc FileSplit { inFile { maxFileSize 2048 } { outFilePrefix "" } } {
        set catchVal [catch {open $inFile r} inFp]
        if { $catchVal != 0 } {
            error "Could not open file \"$inFile\" for reading."
        }
        fconfigure $inFp -translation binary

        if { $outFilePrefix ne "" } {
            set outFileName $outFilePrefix
        } else {
            set outFileName $inFile
        }
        set count 1
        set fileList [list]
        while { 1 } {
            set str [read $inFp $maxFileSize]
            if { $str ne "" } {
                set fileName [format "%s-%05d" $outFileName $count]
                set catchVal [catch {open $fileName w} outFp]
                if { $catchVal != 0 } {
                    close $inFp
                    error "Could not open file \"$fileName\" for writing."
                }
                fconfigure $outFp -translation binary
                puts -nonewline $outFp $str
                close $outFp
                lappend fileList $fileName
                incr count
            }
            if { [eof $inFp] } {
                break
            }
        }
        close $inFp
        return $fileList
    }

    proc FileConvert { fileName mode } {
        set size [file size $fileName]
        if { $size } {
            set catchVal [catch { open $fileName r } fpIn]
            if { $catchVal } {
                error "Could not read file \"$fileName\"."
            }
            fconfigure $fpIn -translation auto
            set data [read $fpIn $size]
            close $fpIn
            set catchVal [catch { open $fileName w } fpOut]
            if { $catchVal } {
                error "Could not write file \"$fileName\"."
            }
            fconfigure $fpOut -translation $mode
            puts -nonewline $fpOut $data
            close $fpOut
        }
    }

    proc GetNetworkFolders { networkDrive } {
        set folderList [list]

        set CSIDL_NETWORK 18
        set shell [twapi::comobj Shell.Application]
        set network [$shell NameSpace $CSIDL_NETWORK]

        set networkItems    [$network Items]
        set numNetworkItems [$networkItems Count]
        set found false
        for { set i 0 } { $i < $numNetworkItems } { incr i } {
            set networkItem [$networkItems Item $i]
            if { [string map { "\\" "/" } [$networkItem Path]] eq $networkDrive } {
                set folderObj [$networkItem GetFolder]
                set folderItems [$folderObj Items]
                set numFolderItems [$folderItems Count]
                for { set f 0 } { $f < $numFolderItems } { incr f } {
                    set folderItem [$folderItems Item $f]
                    lappend folderList [string map { "\\" "/" } [$folderItem Path]]
                    $folderItem -destroy
                }
                $folderItems -destroy
                $folderObj   -destroy
                set found true
            }
            $networkItem -destroy
            if { $found } {
                break
            }
        }
        $networkItems -destroy
        $network      -destroy
        $shell       -destroy
        return $folderList
    }

    proc GetNetworkDrives {} {
        set driveList [list]

        set CSIDL_NETWORK 18
        set shell [twapi::comobj Shell.Application]
        set network [$shell NameSpace $CSIDL_NETWORK]

        set networkItems [$network Items]
        set numNetworkItems [$networkItems Count]
        for { set i 0 } { $i < $numNetworkItems } { incr i } {
            set networkItem [$networkItems Item $i]
            if { [$networkItem IsFolder] && [string first "\\\\" [$networkItem Path]] == 0 } {
                lappend driveList [string map { "\\" "/" } [$networkItem Path]]
            }
            $networkItem -destroy
        }
        $networkItems -destroy
        $network      -destroy
        $shell        -destroy
        return $driveList
    }

    proc GetDrives { args } {
        global tcl_platform

        set opts [dict create \
            -networkdrives false \
        ]

        foreach { key value } $args {
            if { [dict exists $opts $key] } {
                if { $value eq "" } {
                    error "GetDrives: No value specified for key \"$key\"."
                }
                dict set opts $key $value
            } else {
                error "GetDrives: Unknown option \"$key\" specified."
            }
        }

        set driveList [list]
        switch $tcl_platform(platform) {
            windows {
                foreach drive [file volumes] {
                    if {[string match "//zipfs*" $drive] } {
                        continue
                    } else {
                        lappend driveList $drive
                    }
                }
                if { [dict get $opts "-networkdrives"] } {
                    foreach networkDrive [GetNetworkDrives] {
                        lappend driveList [list $networkDrive]
                    }
                }
            }
            default {
                set driveList [file volumes]
            }
        }
        return $driveList
    }

    proc DiskUsage { dirName { countHidden true } } {
        # Return the size of a folder in bytes. Similar to Unix du command.
        # By default, hidden folders and files are counted, too.

        set res 0
        foreach item [glob -nocomplain -- $dirName/*] {
            switch -- [file type $item] {
                directory {
                    set res [expr {$res + [DiskUsage $item $countHidden]}]
                }
                file {
                    set res [expr {$res + [file size $item]}]
                }
            }
        }

        if { $countHidden } {
            foreach item [glob -nocomplain -types {hidden} -- $dirName/*] {
                switch -- [file type $item] {
                    directory {
                        set res [expr {$res + [DiskUsage $item $countHidden]}]
                    }
                    file {
                        set res [expr {$res + [file size $item]}]
                    }
                }
            }
        }
        return $res
    }

    proc GetFileInfoLabels {} {
        global tcl_platform

        set infoLabels [list "Filename" "Path" "Type" "Size in Bytes" \
                             "Last time modified" "Last time accessed"]

        if { $tcl_platform(platform) eq "windows" } {
            lappend infoLabels "Archiv"
            lappend infoLabels "Hidden"
            lappend infoLabels "Readonly"
            lappend infoLabels "System"
        } elseif { $tcl_platform(platform) eq "unix" } {
            lappend infoLabels "Owner"
            lappend infoLabels "Group"
            lappend infoLabels "Permissions"
        }
        return $infoLabels
    }

    proc FormatByteSize { sizeInBytes } {
        set KB 1024.0
        set MB [expr {$KB * $KB}]
        set GB [expr {$MB * $KB}]

        if { $sizeInBytes < $KB } {
            return [format "%d Byte" $sizeInBytes]
        } elseif { $sizeInBytes < $MB } {
            return [format "%.1f KB" [expr {$sizeInBytes / $KB}]]
        } elseif { $sizeInBytes < $GB } {
            return [format "%.1f MB" [expr {$sizeInBytes / $MB}]]
        } else {
            return [format "%.1f GB" [expr {$sizeInBytes / $GB}]]
        }
    }

    proc FileInfo { fileName  { showImgSize false } } {
        global tcl_platform

        if { ! [file exists $fileName] } {
            return [list]
        }

        set KB 1024.0
        set MB [expr {$KB * $KB}]
        set GB [expr {$MB * $KB}]
        set attrList [list]
        set labelList [GetFileInfoLabels]
        set ind 0

        # Note: If adding another element, don't forget to update
        #       proc GetFileInfoLabels accordingly.
        set tmp [file tail $fileName]
        lappend attrList [list [lindex $labelList $ind] $tmp]
        incr ind
        set tmp [file nativename [file dirname $fileName]]
        lappend attrList [list [lindex $labelList $ind] $tmp]
        incr ind
        set typeDict [poType GetFileType $fileName]
        set tmp [list]
        if { [dict exists $typeDict style] } {
            lappend tmp [dict get $typeDict style]
        }
        if { [dict exists $typeDict substyle] } {
            lappend tmp [dict get $typeDict substyle]
        }
        if { [dict exists $typeDict fmt] } {
            lappend tmp [dict get $typeDict fmt]
        }
        if { [dict exists $typeDict subfmt] } {
            lappend tmp [dict get $typeDict subfmt]
        }
        if { [dict exists $typeDict imgsubfmt] } {
            lappend tmp [dict get $typeDict imgsubfmt]
        }
        if { $showImgSize && [dict exists $typeDict width] } {
            lappend tmp "[dict get $typeDict width] x [dict get $typeDict height]"
        }
        lappend attrList [list [lindex $labelList $ind] $tmp]
        incr ind

        set tmp [dict get $typeDict size]
        if { $tmp < $KB } {
            lappend attrList [list [lindex $labelList $ind] $tmp]
        } elseif { $tmp < $MB } {
            lappend attrList [list [lindex $labelList $ind] \
                    [format "%d (%.2f KBytes)" $tmp [expr {$tmp / $KB}]]]
        } elseif { $tmp < $GB } {
            lappend attrList [list [lindex $labelList $ind] \
                    [format "%d (%.2f MBytes)" $tmp [expr {$tmp / $MB}]]]
        } else {
            lappend attrList [list [lindex $labelList $ind] \
                    [format "%d (%.2f GBytes)" $tmp [expr {$tmp / $GB}]]]
        }
        incr ind

        set tmp [clock format [file mtime $fileName] -format "%Y-%m-%d %H:%M:%S"]
        lappend attrList [list [lindex $labelList $ind] $tmp]
        incr ind
        set tmp [clock format [file atime $fileName] -format "%Y-%m-%d %H:%M:%S"]
        lappend attrList [list [lindex $labelList $ind] $tmp]
        incr ind

        if { $tcl_platform(platform) eq "windows" } {
            set tmp [file attributes $fileName -archive]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
            set tmp [file attributes $fileName -hidden]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
            set tmp [file attributes $fileName -readonly]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
            set tmp [file attributes $fileName -system]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
        } elseif { $tcl_platform(platform) eq "unix" } {
            set tmp [file attributes $fileName -owner]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
            set tmp [file attributes $fileName -group]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
            set tmp [file attributes $fileName -permissions]
            lappend attrList [list [lindex $labelList $ind] $tmp]
            incr ind
        } else {
            error "Unsupported platform $tcl_platform(platform)"
        }
        return $attrList
    }

    proc FileSizeCompare { f1 f2 } {
        if { [file size $f1] == [file size $f2] } {
            return 1
        } else {
            return 0
        }
    }

    proc FileDateCompare { f1 f2 { ignOneHour 0 } } {
        set f1Date [file mtime $f1]
        set f2Date [file mtime $f2]
        if { $f1Date == $f2Date } {
            return 1
        } else {
            if { $ignOneHour } {
                if { [Abs [expr {$f1Date - $f2Date}]] == 3600 } {
                    return 1
                }
            }
            return 0
        }
    }

    proc FileContentCompare { f1 f2 { ignEOL 0 } { bufSize 2048 } } {
        set retVal 0
        set catchVal [catch { open $f1 "r" } fp1]
        if { $catchVal } {
            error "Could not read file \"$f1\"."
        }

        set catchVal [catch { open $f2 "r" } fp2]
        if { $catchVal } {
            close $fp1
            error "Could not read file \"$f2\"."
        }
        if { $ignEOL } {
            fconfigure $fp1 -translation auto -eofchar ""
            fconfigure $fp2 -translation auto -eofchar ""
        } else {
            fconfigure $fp1 -translation binary
            fconfigure $fp2 -translation binary
        }

        set str1 [read $fp1 $bufSize]
        while { 1 } {
            set str2 [read $fp2 $bufSize]
            if { $str1 ne $str2 } {
                # Files differ
                set retVal 0
                break
            }
            set str1 [read $fp1 $bufSize]
            if { $str1 eq "" } {
                # Files are identical
                set retVal 1
                break
            }
        }
        close $fp1
        close $fp2
        return $retVal
    }

    proc GetCmpMode { modeString } {
        # cmpMode 0: Compare files by size only
        # cmpMode 1: Compare files by date only
        # cmpMode 2: Compare files by content
        # cmpMode 3: Compare files by existence

        set mode [string tolower $modeString]
        if { $mode eq "size" } {
            return 0
        } elseif { $mode eq "date" } {
            return 1
        } elseif { $mode eq "content" } {
            return 2
        } elseif { $mode eq "exist" } {
            return 3
        } else {
            error "GetCmpMode: Unknown compare mode string $modeString"
        }
    }

    proc GetCmpModeString { mode } {
        if { $mode == 0 } {
            return "size"
        } elseif { $mode == 1 } {
            return "date"
        } elseif { $mode == 2 } {
            return "content"
        } elseif { $mode == 3 } {
            return "exist"
        } else {
            error "GetCmpModeString: Unknown compare mode $mode"
        }
    }

    proc FileIdent { f1 f2 { cmpMode 2 } { ignEOL 0 } { ignOneHour 0 } { bufSize 2048 } } {
        # cmpMode 0: Compare files by size only
        # cmpMode 1: Compare files by date only
        # cmpMode 2: Compare files by content
        # cmpMode 3: Compare files by existence

        if { ! [file isfile $f1] } {
            error "Parameter $f1 is not a file"
        }
        if { ! [file isfile $f2] } {
            error "Parameter $f2 is not a file"
        }

        if { $cmpMode == 0 } {
            return [FileSizeCompare $f1 $f2]
        } elseif { $cmpMode == 1 } {
            return [FileDateCompare $f1 $f2 $ignOneHour]
        } elseif { $cmpMode == 2 } {
            return [FileContentCompare $f1 $f2 $ignEOL $bufSize]
        } elseif { $cmpMode == 3 } {
            return true
        } else {
            error "FileIdent: Unknown compare mode $cmpMode"
        }
    }

    proc CheckMatchList { searchString matchList { ignCase false } } {
        # Compare a string against a list of glob-style patterns.
        #
        # searchString - String to be compared.
        # matchList    - List of glob-style patterns.
        # ignCase      - Ignore case when matching. 
        #
        # Example: This procedure is used in poDiff, where a file name is checked
        #          against the matchList containing strings like "*.o" ".dll", which
        #          are file patterns to be ignored in directory diff.
        #
        # Return true, if the searchString matches a pattern in the matchList.
        # Otherwise return false.
        #
        # See also:

        if { $ignCase } {
            set matchCmd "string match -nocase"
        } else {
            set matchCmd "string match"
        }
        foreach matchString $matchList {
            if { [eval $matchCmd {$matchString $searchString}] } {
                return true
            }
        }
        return false
    }

    proc QuoteRegexpChars { str } {
        # Quote all regexp special chars: "^$*+.?()|[]\"

        regsub -all -- {\^|\$|\*|\+|\.|\?|\(|\)|\||\[|\]|\\} $str {\\&} tmpStr
        return $tmpStr
    }

    proc QuoteSearchPattern { searchPatt searchMode matchWord } {
        if { $searchMode eq "exact" } {
            set quotedPatt [QuoteRegexpChars $searchPatt]
            if { $matchWord } {
                set quotedPatt [format "\\m(%s)\\M" $quotedPatt]
            }
        } elseif { $searchMode eq "match" } {
            # if searchMode is set to match, we use * as a wildcard for
            # 0 and more characters.
            # TODO: Not working yet.
            regsub -all -- {\+|\.|\?|\(|\)|\||\[|\]|\\} \
                $searchPatt {\\&} tmpStr
            regsub -all -- {\*} $tmpStr1 {.*} quotedPatt
        } elseif { $searchMode eq "regexp" } {
            # TODO: Not yet implemented.
        }
        return $quotedPatt
    }

    proc SearchInFile { fileName searchPatt { ignCase false } \
                        { searchMode "exact" } { matchWord false } } {
        return [SearchReplaceInFile $fileName $searchPatt \
                                    "" false $ignCase $searchMode $matchWord]
    }

    proc ReplaceInFile { fileName searchPatt replacePatt { ignCase false } \
                         { searchMode "exact" } { matchWord false } } {
        return [SearchReplaceInFile $fileName $searchPatt \
                                              $replacePatt true $ignCase $searchMode $matchWord]
    }

    proc SearchReplaceInFile { fileName searchPatt replacePatt doReplace { ignCase false } \
                               { searchMode "exact" } { matchWord false } } {
        set catchVal [catch { open $fileName r } fp]
        if { $catchVal } {
            error "Could not read file \"$fileName\"."
        }
        fconfigure $fp -translation binary
        set srcCont [read $fp [file size $fileName]]
        close $fp

        if { ! $doReplace && $searchMode eq "exact" && ! $ignCase && ! $matchWord } {
            # Special faster case: Search for exact case-sensitive string only.
            set numFound 0
            set pos 0
            set strlen [string length $searchPatt]
            while { 1 } {
                set ind [string first "$searchPatt" $srcCont $pos]
                if { $ind < 0 } {
                    break
                }
                set pos [expr { $ind + $strlen }]
                incr numFound
            }
            return $numFound
        }

        set quotedSearch  [QuoteSearchPattern $searchPatt  $searchMode $matchWord]
        set quotedReplace $replacePatt

        if { $ignCase } {
            set numSubst [regsub -nocase -all -- "$quotedSearch" $srcCont \
                                                 "$quotedReplace" substCont]
        } else {
            set numSubst [regsub -all -- "$quotedSearch" $srcCont \
                                         "$quotedReplace" substCont]
        }

        if { $numSubst > 0 } {
            if { $doReplace } {
                set catchVal [catch { open $fileName w } fp]
                if { $catchVal } {
                    error "Could not write file \"$fileName\"."
                }
                fconfigure $fp -translation binary
                puts -nonewline $fp $substCont
                close $fp
            }
        }
        return $numSubst
    }

    proc HexDump { fileName { channel "" } { textWidget "" } } {
        # Open the file, and set up to process it in binary mode.
        set catchVal [catch { open $fileName r } fp]
        if { $catchVal } {
            error "Could not read file \"$fileName\"."
        }
        fconfigure $fp -translation binary -encoding binary \
                       -buffering full -buffersize 16384

        while { 1 } {
            # Record the seek address.  Read 16 bytes from the file.
            set addr [tell $fp]
            set s [read $fp 16]

            # Convert the data to hex and to characters.
            binary scan $s H*@0a* hex ascii

            # Replace non-printing characters in the data.
            regsub -all -- {[^[:graph:] ]} $ascii {.} ascii

            # Split the 16 bytes into two 8-byte chunks
            set hex1 [string range $hex 0 15]
            set hex2 [string range $hex 16 31]

            # Convert the hex to pairs of hex digits
            regsub -all -- {..} $hex1 {& } hex1
            regsub -all -- {..} $hex2 {& } hex2

            # Put the hex and Latin-1 data to the channel
            set hexStr [format "%08x  %-24s %-24s %-16s\n" \
                                $addr $hex1 $hex2 $ascii]
            if { $channel ne "" } {
                puts $channel $hexStr
            }
            if { $textWidget ne "" } {
                $textWidget insert end $hexStr
                $textWidget insert end "\n"
            }
            # Stop if we've reached end of file
            if { [string length $s] == 0 } {
                break
            }
        }

        close $fp
        return
    }

    proc HexDumpToFile { binFile hexFile } {
        set catchVal [catch { open $hexFile w } hexFp]
        if { $catchVal } {
            error "Could not write file \"$hexFile\"."
        }
        HexDump $binFile $hexFp

        close $hexFp
    }

    proc QuoteTilde { fileName } {
        if { ! [HaveTcl9OrNewer] } {
            if { [string index $fileName 0] eq "~" } {
                # File starts with tilde. This will generate errors "user ~XXX does not exist"
                return [format "./%s" $fileName]
            }
        }
        return $fileName
    }

    proc QuoteSpaces { str } {
        regsub -all -- { } $str {\\&} quoted
        return $quoted
    }

    proc CompactSpaces { str {replaceChar " "} } {
        regsub -all -- {\s+} $str "$replaceChar" compact
        return $compact
    }

    proc SplitMultSpaces { str } {
        # Like split, but eliminates multiple whitespaces in string before splitting.

        return [regexp -all -inline -- {\S+} $str]
    }

    proc AddNewlines { str { maxChars 10 } } {
        # Add newlines to a string at word boundaries.

        set newStr ""
        set sum 0
        set l [regexp -all -inline -- {\S+} $str]
        foreach word $l {
            append newStr $word " "
            incr sum [string length $word]
            if { $sum >= $maxChars } {
                append newStr "\n"
                set sum 0
            }
        }
        return $newStr
    }

    proc Plural { num } {
        if { $num == 1 } {
            return ""
        } else {
            return "s"
        }
    }

    proc RandomInit { seed } {
        variable randomSeed
        set randomSeed $seed
    }

    proc Random { } {
        variable randomSeed
        set randomSeed [expr {($randomSeed * 9301 + 49297) % 233280}]
        return [expr {$randomSeed/double(233280)}]
    }

    proc RandomRange { range } {
        return [expr {int ([Random]*$range)}]
    }

    proc DegToRad { phi } {
        variable PI
        return [expr {$phi * $PI / 180.0}]
    }

    proc RadToDeg { rad } {
        variable PI
        return [expr {$rad * 180.0 / $PI}]
    }

    proc ArrayToList { arr noElem } {
        upvar $arr a
        set tmpList [list]
        for { set i 0 } { $i < $noElem } { incr i } {
            lappend tmpList $a($i)
        }
        return $tmpList
    }

    proc ListToArray { lst noElem arr } {
        upvar $arr a
        for { set i 0 } { $i < $noElem } { incr i } {
            set a($i) [lindex $lst $i]
        }
    }

    proc InsertIntoList { l val reserved } {
        # Insert a value "val" into a list "l".
        # The last "reserved" entries should be left unchanged and unsorted.
        # The rest of the list is sorted with "-dictionary" option and the
        # supplied value is inserted at the right position.

        set reserved1 [expr {$reserved-1}]
        set reservedList [lrange $l end-$reserved1 end]
        # Check, if val is already contained in the reserved part of the list.
        # In this case, we only sort the first part and append the reserved part.
        if { [lsearch -exact $reservedList $val] >= 0 } {
            return [concat [lsort -dictionary [lrange $l 0 end-$reserved]] $reservedList]
        }

        set ind 0
        set found false
        set tmpList [list]
        foreach key [lsort -dictionary [lrange $l 0 end-$reserved]] {
            if { [string compare -nocase $key $val] < 0 } {
                lappend tmpList $key
            } elseif { [string compare -nocase $key $val] == 0 } {
                set found true
                lappend tmpList $key
            } else {
                if { ! $found } {
                    lappend tmpList $val
                    set found true
                }
                lappend tmpList $key
            }
        }
        if { ! $found } {
            lappend tmpList $val
        }
        return [concat $tmpList $reservedList]
    }

    proc Square { x } {
        return [expr {$x * $x}]
    }

    proc IsSquare { x } {
        set root [expr { round (sqrt ($x)) }]
        if { $x == $root * $root } {
            return [expr {int ($root) }]
        }
        return -1
    }

    proc Distance2D { pos1 pos2 } {
        set dx [expr { [lindex $pos2 0] - [lindex $pos1 0] }]
        set dy [expr { [lindex $pos2 1] - [lindex $pos1 1] }]
        return [expr { sqrt( $dx*$dx + $dy*$dy ) }]
    }

    proc Distance3D { pos1 pos2 } {
        set dx [expr { [lindex $pos2 0] - [lindex $pos1 0] }]
        set dy [expr { [lindex $pos2 1] - [lindex $pos1 1] }]
        set dz [expr { [lindex $pos2 2] - [lindex $pos1 2] }]
        return [expr { sqrt( $dx*$dx + $dy*$dy + $dz*$dz ) }]
    }

    proc IsPowerOfTwo { x } {
        for { set exp 0 } { $exp < 64 } { incr exp } {
            if { [expr { 1 << $exp }] == $x } {
                return $exp
            }
        }
        return -1
    }

    proc Abs { a } {
        if { $a < 0 } {
            return [expr {-$a}]
        } else {
            return $a
        }
    }

    proc Min { a b } {
        if { $a < $b } {
            return $a
        } else {
            return $b
        }
    }

    proc Max { a b } {
        if { $a > $b } {
            return $a
        } else {
            return $b
        }
    }

    proc CleanTclkitDirs {} {
        global env

        if { $::tcl_platform(platform) ne "windows" } {
            return
        }
        foreach name { TMP TEMP TMPDIR } {
            if { ! [info exists env($name)] } {
                continue
            }
            set tmpDir $env($name)
            set dirList [glob -nocomplain -types d -directory $tmpDir -- \
                "TCL\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]\[0-9a-f\]"]
            foreach dir $dirList {
                catch { file delete -force $dir }
            }
        }
    }

    proc GetTmpDir {} {
        global tcl_platform env

        set tmpDir ""
        # Try different environment variables.
        if { [info exists env(TMP)] && [file isdirectory $env(TMP)] } {
            set tmpDir $env(TMP)
        } elseif { [info exists env(TEMP)] && [file isdirectory $env(TEMP)] } {
            set tmpDir $env(TEMP)
        } elseif { [info exists env(TMPDIR)] && [file isdirectory $env(TMPDIR)] } {
            set tmpDir $env(TMPDIR)
        } else {
            # Last resort. These directories should be available at least.
            switch $tcl_platform(platform) {
                windows {
                    if { [file isdirectory "C:/Windows/Temp"] } {
                        set tmpDir "C:/Windows/Temp"
                    } elseif { [file isdirectory "C:/Winnt/Temp"] } {
                        set tmpDir "C:/Winnt/Temp"
                    }
                }
                unix {
                    if { [file isdirectory "/tmp"] } {
                        set tmpDir "/tmp"
                    }
                }
            }
        }
        return [file nativename $tmpDir]
    }

    proc GetDesktopDir {} {
        global tcl_platform env

        set desktopDir ""
        switch $tcl_platform(platform) {
            windows {
                # Load the registry package
                package require "registry"

                # Define likely registry locations
                set keys [list \
                    {HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders}\
                    {HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\ProfileList}\
                    {HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell Folders}]

                # Try each location till we find a result
                foreach key $keys {
                    if ![catch "registry get \"$key\" Desktop" result] {
                        set desktopDir $result
                        break
                    }
                }
            }
            unix {
                set tmpDir [file join [GetHomeDir] "KDesktop"]
                if { [file isdirectory $tmpDir] } {
                    set desktopDir $tmpDir
                }
            }
        }
        if { ! [file isdirectory $desktopDir] } {
            set desktopDir ""
        }
        return [file nativename $desktopDir]
    }

    proc GetHomeDir {} {
        global tcl_platform env

        if { [HaveTcl9OrNewer] } {
            set homeDir [file tildeexpand "~"]
        } else {
            set homeDir "~"
        }
        if { ! [file isdirectory $homeDir] } {
            set homeDir ""
        }
        return [file nativename $homeDir]
    }

    proc GetFileAttr { fileList dirName } {
        set fileLongList  [list]
        foreach f $fileList {
            set af   [file join $dirName $f]
            set date [clock format [file mtime $af] -format "%Y-%m-%d %H:%M"]
            set size [file size  $af]
            lappend fileLongList [list $f $size $date]
        }
        return $fileLongList
    }

    proc _GetNumberIndices { fileName } {
        set len [string length $fileName]
        set ind [expr {$len - 1}]
        set index1 -1
        set index2 -1
        while { $ind >= 0 } {
            set char [string index $fileName $ind]
            if { [string is digit $char] } {
                # puts "Found last number at $ind"
                set index2 $ind
                while { $ind >= 0 } {
                    set char [string index $fileName $ind]
                    if { ! [string is digit $char] } {
                        # puts "Found first non-number at $ind"
                        set index1 [expr { $ind + 1 }]
                        break
                    }
                    incr ind -1
                }
                if { $index1 >= 0 } {
                    break
                }
            }
            incr ind -1
        }
        if { $index1 < 0 && $index2 >= 0 } {
            set index1 0
        }
        return [list $index1 $index2]
    }

    proc GetFileNumber { fileName } {
        lassign [_GetNumberIndices $fileName] index1 index2
        set retVal ""
        if { $index1 >= 0 && $index2 >= 0 } {
            set retVal [string range $fileName $index1 $index2]
        }
        return $retVal
    }

    proc ReplaceFileNumber { fileName replaceString } {
        lassign [_GetNumberIndices $fileName] index1 index2
        set retVal $fileName
        if { $index1 >= 0 && $index2 >= 0 } {
            set retVal [string replace $fileName $index1 $index2 $replaceString]
        }
        return $retVal
    }

    proc IsReadableFile { name } {
        set retVal [catch { open $name "r" } fp]
        if { $retVal == 0 } {
            close $fp
            return true
        }
        return false
    }

    proc IsHiddenFile { absName } {
        global tcl_platform

        switch $tcl_platform(platform) {
            unix {
                return [string match ".*" [file tail $absName]]
            }
            windows {
                return [file attributes $absName -hidden]
            }
            macintosh {
                return [file attributes $absName -hidden]
            }
            default {
                error "Missing implementation of IsHiddenFile \
                       for platform $tcl_platform(platform)"
            }
        }
    }

    proc IsCaseSensitiveFileSystem {} {
        global tcl_platform

        if { $tcl_platform(platform) eq "windows" || [IsAndroid] } {
            return false
        } else {
            return true
        }
    }

    proc CountDirsAndFiles { rootDir } {
        set numDirs  0
        set numFiles 0

        set dirAndFileList [poMisc GetDirsAndFiles $rootDir]
        incr numDirs  [llength [lindex $dirAndFileList 0]]
        incr numFiles [llength [lindex $dirAndFileList 1]]

        foreach dir [lindex $dirAndFileList 0] {
            set subDirCount [CountDirsAndFiles [file join $rootDir $dir]]
            incr numDirs  [lindex $subDirCount 0]
            incr numFiles [lindex $subDirCount 1]
        }
        return [list $numDirs $numFiles]
    }

    proc GetDirCont { dirName { patt "*" } } {
        global tcl_platform env

        set fileList [list]

        set curDir [pwd]
        set catchVal [catch {cd $dirName}]
        if { $catchVal } {
            return $fileList
        }

        set fileList [glob -nocomplain -- {*}$patt]

        cd $curDir
        return [lsort -dictionary $fileList]
    }

    proc GetDirList { dirName \
                      { showDirs 1} { showFiles 1 } \
                      { showHiddenDirs 1} { showHiddenFiles 1 } \
                      { dirPattern * } { filePattern * } } {
        return [GetDirsAndFiles $dirName \
                -showdirs        $showDirs \
                -showfiles       $showFiles \
                -showhiddendirs  $showHiddenDirs \
                -showhiddenfiles $showHiddenFiles \
                -dirpattern      $dirPattern \
                -filepattern     $filePattern]
    }

    proc GetDirsAndFiles { dirName args } {
        global tcl_platform

        set showDirs        true
        set showFiles       true
        set showHiddenDirs  true
        set showHiddenFiles true
        set nocomplain      true
        set dirPattern      "*"
        set filePattern     "*"

        foreach { key value } $args {
            if { $value eq "" } {
                error "GetDirsAndFiles: No value specified for key \"$key\""
            }
            switch -exact $key {
                "-showdirs"        { set showDirs        $value }
                "-showfiles"       { set showFiles       $value }
                "-showhiddendirs"  { set showHiddenDirs  $value }
                "-showhiddenfiles" { set showHiddenFiles $value }
                "-nocomplain"      { set nocomplain      $value }
                "-dirpattern"      { set dirPattern      $value }
                "-filepattern"     { set filePattern     $value }
                default            { error "GetDirsAndFiles: Unknown key \"$key\" specified" }
            }
        }

        set curDir [pwd]
        set catchVal [catch {cd $dirName}]
        if { $catchVal } {
            return [list]
        }

        set absDirList  [list]
        set relFileList [list]

        if { $showDirs } {
            set catchVal [catch { glob -nocomplain -types d -- {*}$dirPattern } relDirList]
            if { $catchVal } {
                if { $nocomplain } {
                    set relDirList [list]
                } else {
                    error "$relDirList"
                }
            }
            foreach dir $relDirList {
                set dir [poMisc QuoteTilde $dir]
                set absName [file join $dirName $dir]
                lappend absDirList $absName
            }
            if { $showHiddenDirs } {
                set catchVal [catch { glob -nocomplain -types {d hidden} -- {*}$dirPattern } relHiddenDirList]
                if { $catchVal } {
                    if { $nocomplain } {
                        set relHiddenDirList [list]
                    } else {
                        error "$relHiddenDirList"
                    }
                }
                foreach dir $relHiddenDirList {
                    if { $dir eq "." || $dir eq ".." } {
                        continue
                    }
                    set absName [file join $dirName $dir]
                    lappend absDirList $absName
                }
            }
        }
        if { $showFiles } {
	    set catchVal [catch { glob -nocomplain -types f -- {*}$filePattern } relFileList]
            if { $catchVal } {
                if { $nocomplain } {
                    set relFileList [list]
                } else {
                    error "$relFileList"
                }
            }
            if { $showHiddenFiles } {
	        set catchVal [catch { glob -nocomplain -types {f hidden} -- {*}$filePattern } relHiddenFileList]
                if { $catchVal } {
                    if { $nocomplain } {
                        set relHiddenFileList [list]
                    } else {
                        error "$relFileList"
                    }
                }
                if { [llength $relHiddenFileList] != 0 } {
                    set relFileList [concat $relFileList $relHiddenFileList]
                }
            }
        }
        cd $curDir

        return [list $absDirList $relFileList]
    }

    proc Pack { tgzFile level args } {
        if { [HavePkg "tar"] } {
            set catchVal [catch {open $tgzFile wb} fp]
            if { $catchVal != 0 } {
                error "Could not open file \"$tgzFile\" for writing."
            }
            if { $level < 1 } {
                tar::create $fp $args -chan
            } else {
                zlib push gzip $fp -level $level
                tar::create $fp $args -chan
            }
            close $fp
        } else {
            error "Pack: Package \"tar\" not available."
        }
    }

    proc Unpack { tgzFile level args } {
        if { [HavePkg "tar"] } {
            set catchVal [catch {open $tgzFile rb} fp]
            if { $catchVal != 0 } {
                error "Could not open file \"$tgzFile\" for reading."
            }
            if { $level < 1 } {
                tar::untar $fp
            } else {
                zlib push gunzip $fp
                tar::untar $fp -chan
            }
            close $fp
        } else {
            error "Unpack: Package \"tar\" not available."
        }
    }

    proc PrintMachineInfo {} {
        global tcl_platform

        puts ""
        puts "Machine specific information:"
        puts "  platform    : $tcl_platform(platform)"
        puts "  os          : $tcl_platform(os)"
        puts "  osVersion   : $tcl_platform(osVersion)"
        puts "  machine     : $tcl_platform(machine)"
        puts "  hostname    : [info hostname]"
    }

    proc PrintTclInfo {} {
        global tcl_platform

        set loadedPackages [info loaded]

        puts ""
        puts "Tcl specific information:"
        puts "  Tcl version : [info patchlevel]"

        set i 1
        foreach pckg $loadedPackages {
            if { $i == 1 } {
                puts  [format "  Packages    : %-8s (%s)" \
                              [lindex $pckg 1] [lindex $pckg 0]]
            } else {
                puts  [format "                %-8s (%s)" \
                              [lindex $pckg 1] [lindex $pckg 0]]
            }
            incr i
        }
    }

    proc DecToRgb {r {g 0} {b UNSET} {clip 0}} {
        #   Takes a color name or dec triplet and returns a #RRGGBB color.
        #   If any of the incoming values are greater than 255,
        #   then 16 bit value are assumed, and #RRRRGGGGBBBB is
        #   returned, unless $clip is set.
        #
        # Arguments:
        #   r           red dec value, or list of {r g b} dec value or color name
        #   g           green dec value, or the clip value, if $r is a list
        #   b           blue dec value
        #   clip        Whether to force clipping to 2 char hex
        # Results:
        #   Returns a #RRGGBB or #RRRRGGGGBBBB color

        if { $b eq "UNSET" } {
            set clip $g
            if {[regexp -- {^-?(0-9)+$} $r]} {
                foreach {r g b} $r {break}
            } else {
                foreach {r g b} [winfo rgb . $r] {break}
            }
        }
        set max 255
        set len 2
        if {($r > 255) || ($g > 255) || ($b > 255)} {
            if {$clip} {
                set r [expr {$r>>8}]; set g [expr {$g>>8}]; set b [expr {$b>>8}]
            } else {
                set max 65535
                set len 4
            }
        }
        return [format "#%.${len}X%.${len}X%.${len}X" \
                [expr {($r>$max)?$max:(($r<0)?0:$r)}] \
                [expr {($g>$max)?$max:(($g<0)?0:$g)}] \
                [expr {($b>$max)?$max:(($b<0)?0:$b)}]]
    }

    proc RgbToDec { c } {
        # Turns #rgb into 3 elem list of decimal vals.
        #
        # Arguments:
        #   c           The #rgb hex of the color to translate
        # Results:
        #   Returns a #RRGGBB or #RRRRGGGGBBBB color

        set c [string tolower $c]
        if {[regexp -- {^\#([0-9a-f])([0-9a-f])([0-9a-f])$} $c x r g b]} {
            # double'ing the value make #9fc == #99ffcc
            scan "$r$r $g$g $b$b" "%x %x %x" r g b
        } else {
            if {![regexp -- {^\#([0-9a-f]+)$} $c junk hex] || \
                    [set len [string length $hex]]>12 || $len%3 != 0} {
                return -code error "bad color value \"$c\""
            }
            set len [expr {$len/3}]
            scan $hex "%${len}x%${len}x%${len}x" r g b
        }
        return [list $r $g $b]
    }

    proc Bitset { varName pos {bitval {}} } {
        # Implementation of a bitset datastructure with Tcl lists.
        # Taken from the Tcl'ers Wiki. Original by Richard Suchenwirth.

        variable haveTcl84AndUp

        upvar 1 $varName var
        if {![info exist var]} {
            set var 0
        }
        set element [expr {$pos/32}]
        while {$element >= [llength $var]} {
            lappend var 0
        }
        set bitpos [expr {$pos%32}]
        set word [lindex $var $element]
        if {$bitval ne ""} {
            if {$bitval} {
                set word [expr {$word | 1 << $bitpos}]
            } else {
                set word [expr {$word & ~(1 << $bitpos)}]
            }
            if { $haveTcl84AndUp } {
                lset var $element $word
            } else {
                set var [lreplace $var $element $element $word]
            }
        }
        expr {($word & 1 << $bitpos) != 0}
    }

    proc GetBitsetIndices { bitset } {
        # Return the numeric indices of all set bits in a bitset.

        set res [list]
        set pos 0
        foreach word $bitset {
            for { set i 0 } { $i<32 } { incr i } {
                if { $word & 1<<$i } {
                    lappend res $pos
                }
                incr pos
            }
        }
        return $res
    }

    proc CharToNum { char } {
        scan $char %c value
        return $value
    }

    proc NumToChar { value } {
        return [format %c $value]
    }

    proc IsAndroid {} {
        if { [info commands "borg"] eq "borg" } {
            return true
        }
        return false
    }

    proc GetOSBits {} {
        return [expr {$::tcl_platform(pointerSize) * 8}]
    }

    proc GetOSBitsStr {} {
        return [format "%d-bit" [GetOSBits]]
    }

    proc BoolAsInt { boolString } {
        return [string map -nocase {true 1 false 0 on 1 off 0} $boolString]
    }

    proc GetExtensionByType { typeList type } {
        set elem [lsearch -exact -index 0 -inline $typeList $type]
        set ext ""
        if { [llength $elem] > 0 } {
            set ext [lindex [lindex $elem 1] 0]
        }
        return $ext
    }

    proc GetExtensions { typeList } {
        set extList [list]
        foreach elem $typeList {
            set extString [lindex $elem 1]
            if { $extString ne "*" && $extString ne "*.*" } {
                foreach ext $extString {
                    lappend extList $ext
                }
            }
        }
        return $extList
    }

    proc IsValidExtension { typeList ext } {
        set extList [GetExtensions $typeList]
        if { [llength $extList] == 0 } {
            return true
        }
        if { [lsearch -exact -nocase $extList $ext] >= 0 } {
            return true
        } else {
            return false
        }
    }

    # Pretty print a dict similar to parray.
    #
    # USAGE:
    #
    #   PrintDict d [fp] [i [p [s]]]
    #
    # WHERE:
    #  d - dict value or reference to be printed
    # fp - File pointer of a file openend for writing or "stdout"
    #  i - indent level
    #  p - prefix string for one level of indent
    #  s - separator string between key and value
    #
    # EXAMPLE:
    # % set d [dict create a {1 i 2 j 3 k} b {x y z} c {i m j {q w e r} k o}]
    # a {1 i 2 j 3 k} b {x y z} c {i m j {q w e r} k o}
    # % PrintDict $d stdout
    # a ->
    #   1 -> 'i'
    #   2 -> 'j'
    #   3 -> 'k'
    # b -> 'x y z'
    # c ->
    #   i -> 'm'
    #   j ->
    #     q -> 'w'
    #     e -> 'r'
    #   k -> 'o'
    # % PrintDict d stdout
    # dict d
    # a ->
    # ...
    proc PrintDict { d { fp stdout } {i 0} {p "  "} {s " -> "} } {
        set fRepExist [expr {0 < [llength\
            [info commands tcl::unsupported::representation]]}]
        if { (![string is list $d] || [llength $d] == 1)
            && [uplevel 1 [list info exists $d]] } {
            set dictName $d
            unset d
            upvar 1 $dictName d
            puts $fp "dict $dictName"
        }
        if { ! [string is list $d] || [llength $d] % 2 != 0 } {
            return -code error  "error: PrintDict - argument is not a dict"
        }
        set prefix [string repeat $p $i]
        set max 0
        foreach key [dict keys $d] {
            if { [string length $key] > $max } {
                set max [string length $key]
            }
        }
        dict for {key val} ${d} {
            puts -nonewline $fp "${prefix}[format "%-${max}s" $key]$s"
            if {    $fRepExist && [string match "value is a dict*"\
                        [tcl::unsupported::representation $val]]
                    || ! $fRepExist && [string is list $val]
                        && [llength $val] % 2 == 0 } {
                puts $fp ""
                PrintDict $val $fp [expr {$i+1}] $p $s
            } else {
                puts $fp "'${val}'"
            }
        }
        return
    }
}

poMisc Init
