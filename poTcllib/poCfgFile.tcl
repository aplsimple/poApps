# Module:         poCfgFile
# Copyright:      Paul Obermeier 2000-2020 / paul@poSoft.de
# First Version:  2000 / 02 / 20
#
# Distributed under BSD license.
#
# Module for handling configuration files.


namespace eval poCfgFile {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Init
    namespace export CreateBackupFile
    namespace export GetCfgDefaultDir GetCfgFilename
    namespace export ReadCfgFile SaveCfgFile
    namespace export Test

    proc Init {} {
        variable sDefaultDir

        set sDefaultDir "~"
    }

    proc GetCfgDefaultDir {} {
        variable sDefaultDir

        return [file nativename $sDefaultDir]
    }

    proc CreateBackupFile { cfgFile } {
        set backupFile [format "%s.bak" $cfgFile]
        if { [file exists $cfgFile] } {
            file copy -force $cfgFile $backupFile
        }
    }

    proc GetCfgFilename { module { cfgDir "" } } {
        variable sDefaultDir

        if { $cfgDir eq "" } {
            set dir $sDefaultDir
        } else {
            set dir $cfgDir
        }
        set cfgName [format "%s.cfg" $module]
        return [file join $dir $cfgName]
    }

    proc ReadCfgFile { cfgFile cmds } {
        # cfgFile - configuration filename
        # cmds - allowed 'commands' in the configuration file as a list where each
        # element is {cmdName defVal}
        # returns: cmdName Value cmdName Value [...] _errorMsg <rc> (<rc> empty if ok)
        catch {
            set id [interp create -safe]
            # Maximum security in the slave: Delete all available commands.
            interp eval $id {
                foreach cmd [info commands] {
                    if {$cmd != {rename} && $cmd != {if}} {
                        rename $cmd {}
                    }
                }
                rename if {}; rename rename {}
            }
            array set temp $cmds
            proc set$id {key args} {
                upvar 1 temp myArr; set myArr($key) [join $args]
            }
            # Define aliases in the slave for each available configuration-'command'
            # and map each command to the set$id procedure.
            foreach {cmd default} $cmds {
                interp alias $id $cmd {} poCfgFile::set$id $cmd; # arg [...]
            }
            # Source the configuration file.
            $id invokehidden source $cfgFile

            # Clean up.
            interp delete $id
            rename set$id {}
        } rc
        if { $rc != "" } {
            error "Could not read configuration file \"$cfgFile\" ($rc)."
        }
        return [array get temp]
    }

    proc SaveCfgFile { cfgFile cmds } {
        set retVal [catch {open $cfgFile w} fp]
        if { $retVal == 0 } {
            foreach { key val } $cmds {
                puts $fp "$key $val"
            }
        } else {
            error "Could not open file \"$cfgFile\" for writing."
        }
        close $fp
    }

    proc Test {} {
        array set opts {
            integer0         0
            integer1         1
            float0           0.0
            float1           0.00001
            str0             String
            str1             "This is a string"
            list0            {List}
            list1            {El1 El2 El3}
            list2            { {El1_1 El1_1} {El2_1 El2_2} }
        }
        set cfgFile [file join [poMisc GetTmpDir] "poCfgFile.test"]

        puts "Writing these values to configuration file $cfgFile"
        parray opts

        SaveCfgFile $cfgFile [array get opts]

        array set new [ReadCfgFile $cfgFile [array get opts]]
        puts "Read these values from written configuration file $cfgFile"
        parray new

        foreach el $new(list1) {
            puts "list1: $el"
        }
    }
}

poCfgFile Init
