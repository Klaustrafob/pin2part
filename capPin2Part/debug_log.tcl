#
# Package for writing debug messages
#
# Usage example:
#   package require debug_log
#   debug_log::set_fname "log_file_name.log"
#   debug_log::write "message1"
#   debug_log::write "message2"
#

package provide debug_log 1.0

namespace eval ::debug_log {
    set fname "debug_log.txt"
    set file_open 0
}

proc ::debug_log::write {str} {
    set pfile 0
    if {$::debug_log::file_open} {
        set pfile [open $::debug_log::fname a]
    } else {
        set pfile [open $::debug_log::fname w]
        set ::debug_log::file_open 1
    }
    puts $pfile $str
    close $pfile
}

proc ::debug_log::set_fname {fname} {
    set ::debug_log::fname $fname
}
