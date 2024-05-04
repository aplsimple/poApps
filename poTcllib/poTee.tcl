# Module:         poTee
# Copyright:      Paul Obermeier 2021-2023 / paul@poSoft.de
# First Version:  2021 / 12 / 22
#
# Distributed under BSD license.
#
# Module implementing functionality like Unix tee.

namespace eval poTee {
    variable methods {initialize finalize write}

    namespace ensemble create -command transchan -parameters fd \
              -subcommands $methods
    namespace export tee
}

proc poTee::tee {chan file} {
    set fd [open $file w]
    chan push $chan [list [namespace which transchan] $fd]
}

proc poTee::initialize {fd handle mode} {
    variable methods
    return $methods
}

proc poTee::finalize {fd handle} {
   close $fd
}

proc poTee::write {fd handle buffer} {
    puts -nonewline $fd $buffer
    return $buffer
}
