# Module:         poWatch
# Copyright:      Paul Obermeier 2000-2023 / paul@poSoft.de
# First Version:  2000 / 03 / 13
#
# Distributed under BSD license.
#
# The "clock microseconds" command is used to simulate a simple stop watch.
# You can generate multiple stop watches, which are identified by its names.
#
# Typical usage (see also Test procedure):
#     poWatch Reset watch1 # Reset watch1 to zero
#     poWatch Start watch1 # Start watch1 running
#     # After some time
#     set sec [poWatch Lookup watch1] # Get current time 

namespace eval poWatch {
    variable ns [namespace current]

    namespace ensemble create

    namespace export Reset Start Stop Lookup

    proc Reset { name { time 0.0 } } {
        # Reset stop watch.
        #
        # name - Name of stop watch
        # time - Reset time of stop watch
        #
        # Stop watch "name" is reset to "time" seconds, but its
        # state (stopped or running) is not changed. 
        #
        # See also: Start Stop Lookup

        variable watches 

        set t [clock microseconds]

        if { [info exists watches($name,running)] } {
           if { $watches($name,running) } {
                set watches($name,starttime) $t
            }
        } else {
            set watches($name,running) 0
            set watches($name,starttime) $t
        }
        set watches($name,acctime) [expr { int ($time * 1.0E6) }]
    }

    proc Start { name } {
        # Start stop watch.
        #
        # name - Name of stop watch
        #
        # Stop watch "name" starts or continues to run.
        #
        # See also: Reset Stop Lookup

        variable watches 

        set t [clock microseconds]

        if { ! [info exists watches($name,running)] } {
            Reset $name
        }
        set watches($name,starttime) $t
        set watches($name,running) 1
    }

    proc Stop { name } {
        # Stop stop watch.
        #
        # name - Name of stop watch
        #
        # Stop watch "name" is stopped, but not reset.
        #
        # See also: Reset Start Lookup

        variable watches

        set t [clock microseconds]

        if { ! [info exists watches($name,running)] } {
            Reset $name
        }
        if { $watches($name,running) } {
            set watches($name,acctime) [expr {$watches($name,acctime) + $t \
                                              - $watches($name,starttime)}]
            set watches($name,running) 0
        }
    }

    proc Lookup { name } {
        # Lookup stop watch.
        #
        # name - Name of stop watch
        #
        # Lookup stop watch "name" to get it's current time.
        # The number of seconds since the last call to Reset is returned.
        # The precision depends on the high resolution counter available on the system.
        #
        # See also: Reset Start Stop

        variable watches 

        set t [clock microseconds]

        if { ! [info exists watches($name,running)] } {
            Reset $name
        }
        if { $watches($name,running) } {
            set retVal [expr {$watches($name,acctime) + $t \
                              - $watches($name,starttime)}]
        } else {
            set retVal $watches($name,acctime)
        }
        return [expr {$retVal * 1.0E-6}]
    }

    # Utility functions for Test.

    proc P { str verbose } {
        if { $verbose } {
            puts $str
        }
    }

    proc Abs { a } {
        if { $a < 0.0 } {
            return [expr -1.0 * $a]
        } else {
            return $a
        }
    }

    proc CheckLookup { watch acc cmp verbose } {
        set t [Lookup $watch]
        P [format "Lookup of watch %s after %.0f seconds: %.8f (Should be around %.0f)" $watch $acc $t $cmp] $verbose
        if { [Abs [expr $t - $cmp]] < 0.2 } {
            return 1
        }
        puts stderr "Clock time ($t) and compare value ($cmp) \
                     differ by more than 0.2 seconds."
        return 0
    }

    # Simple test to check the correctness of this package.
    # If "verbose" is true, messages are printed out, otherwise test runs silently.
    # "maxTime" determines the duration of the test.

    proc Test { { maxTime 4 } { verbose true } } {
        set retVal 1

        if { $maxTime < 4 } {
            set maxTime 4
        }

        P "" $verbose
        P "Start of watch test" $verbose

        Reset a
        Reset b

        P "" $verbose
        P "Starting watch a and b" $verbose

        Start a
        Start b
        after 1000
        set retVal [expr [CheckLookup a 1 1.0 $verbose] && $retVal]
        after 1000
        set retVal [expr [CheckLookup b 2 2.0 $verbose] && $retVal]

        P "" $verbose
        P "Stopping watch a" $verbose
        Stop a
        after 1000

        set retVal [expr [CheckLookup a 3 2.0 $verbose] && $retVal]
        set retVal [expr [CheckLookup b 3 3.0 $verbose] && $retVal]

        P "" $verbose
        P "Starting watch a again" $verbose
        Start a
        after [expr ($maxTime - 3) * 1000]

        set accTime  $maxTime
        set accTime1 [expr $accTime - 1]
        set retVal [expr [CheckLookup a $accTime $accTime1 $verbose] && $retVal]
        set retVal [expr [CheckLookup b $accTime $accTime  $verbose] && $retVal]
        P "" $verbose
        P "Test finished" $verbose
        return $retVal
    }

    proc TestReset { { verbose true } } {
        set retVal 1

        P "" $verbose
        P "Start of watch reset test" $verbose

        Reset a 0.0
        Reset b 1.0

        set retVal [expr [CheckLookup a 0 0.0 $verbose] && $retVal]
        set retVal [expr [CheckLookup b 1 1.0 $verbose] && $retVal]

        P "" $verbose
        P "Starting watch a and b" $verbose
        Start a
        Start b
        after 1000
        set retVal [expr [CheckLookup a 1 1.0 $verbose] && $retVal]
        set retVal [expr [CheckLookup b 2 2.0 $verbose] && $retVal]

        P "" $verbose
        P "Stopping watch a" $verbose
        Stop a
        after 1000
        set retVal [expr [CheckLookup a 1 1.0 $verbose] && $retVal]
        set retVal [expr [CheckLookup b 3 3.0 $verbose] && $retVal]

        P "" $verbose
        P "Reset watch b to 2" $verbose
        Reset b 2
        set retVal [expr [CheckLookup a 1 1.0 $verbose] && $retVal]
        set retVal [expr [CheckLookup b 2 2.0 $verbose] && $retVal]

        P "" $verbose
        P "Test finished" $verbose
        return $retVal
    }
}
