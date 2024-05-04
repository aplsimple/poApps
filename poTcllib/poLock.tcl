# Module:         poLock
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 06 / 19
#
# Distributed under BSD license.
#
# Module for simple file locking and unlocking.


namespace eval poLock {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export LockFile UnlockFile
    namespace export SetVerboseMode SetLockExtension
    namespace export Test

    proc SetVerboseMode { { verboseMode 0 } } {
        variable verbose

        set verbose $verboseMode
    }

    proc SetLockExtension { { lockExtension "lck" } } {
        variable lockExt

        set lockExt $lockExtension
    }

    proc Init {} {
        SetVerboseMode
        SetLockExtension
    }

    proc LockFile { fileName { timeOutSec 10.0 } } {
        # Lock a file.
        #
        # fileName   - The file which should be locked.
        # timeOutSec - Timeout in seconds.
        #
        # Return 1, if the file could be locked, zero otherwise.
        #
        # See also: UnlockFile

        variable lockExt
        variable verbose

        set lockFile "$fileName.$lockExt"
        set checkTime 0.0
        set checkInterval 1.0
        if { $verbose } {
            puts -nonewline "Trying to lock $fileName "
            flush stdout
        }

        while { [file exists $lockFile] } {
            if { $verbose } {
                puts -nonewline "."
                flush stdout
            }
            after [expr int ($checkInterval * 1000.0)]
            set checkTime [expr $checkTime + $checkInterval]
            if { $checkTime > $timeOutSec } {
                if { $verbose } {
                    set catchVal [catch {open $lockFile r} fp] 
                    if { $catchVal != 0 } {  
                        puts "Could not open lockfile \"$lockFile\" for reading."
                    } else {
                        set lockedBy [gets $fp]
                        close $fp
                    }
                    puts "\nLocking of file $fileName failed."
                    puts "File is locked by host $lockedBy."
                }
                return 0
            }
        }

        set catchVal [catch { open $lockFile "w" } fp] 
        if { $catchVal != 0 } {  
            if { $verbose } {
                puts "Could not open lockfile \"$lockFile\" for reading."
            }
            return 0
        } else {
            puts $fp "[info hostname]"
            close $fp
        }
        if { $verbose } {
            puts "\nLocking of file $fileName successful"
            flush stdout
        }
        return 1
    }

    proc UnlockFile { fileName } {
        # Unlock a file.
        #
        # fileName   - The file which should be unlocked.
        #
        # Return 1, if the file could be unlocked, zero otherwise.
        #
        # See also: LockFile

        variable lockExt
        variable verbose

        set lockFile "$fileName.$lockExt"
        file delete $lockFile
        if { $verbose } {
            puts "File $fileName unlocked."
            flush stdout
        }
        return 1
    }

    proc Test { testFile } {
        SetVerboseMode true
        set retVal [catch {open $testFile w} fp]
        if { $retVal != 0 } {
            tk_messageBox -message "Could not open $testFile for writing" \
                          -icon warning -type ok
            return false
        }
        if { ! [LockFile $testFile] } {
            tk_messageBox -message "Could not lock file $testFile" \
                          -icon warning -type ok
            return false 
        }

        puts $fp "Written to file"

        if { ! [UnlockFile $testFile] } {
            tk_messageBox -message "Could not unlock file $testFile" \
                          -icon warning -type ok
            return false 
        }
        close $fp
        return true
    }
}

poLock Init
