#
# Package to rename Cadence Capture Net alias
#


package provide Pin2PartRename 1.0


namespace eval ::Pin2PartRename {
    set fname_template "_rename.dat"
    set fname ""
    set old_name [list]
    set new_name [list]
}


proc ::Pin2PartRename::SetFName {fname} {
    set dir [file dirname $fname]
    set fbasename [file rootname [file tail $fname]]
    set newname "${fbasename}${::Pin2PartRename::fname_template}"
    set path2file [file join $dir $newname]
    set ::Pin2PartRename::fname $path2file
    puts "Rename mask file: $::Pin2PartRename::fname"
}


proc ::Pin2PartRename::ReadMask2Rename {fname} {
    ::Pin2PartRename::SetFName $fname
    set fname $::Pin2PartRename::fname

    if [file exists $fname] {
        set fp [open $fname r]
        set lines [split [read $fp] "\n"]
        close $fp

        foreach line $lines {
            #set line [string trim $line]
            # if the first char is '#' - skip this line(line is commented)
            set first_char [string range $line 0 0]
            if {$first_char != "#" } {
                set line [split $line ":"]
                set old_name [string trim [lindex $line 0]]
                set new_name [string trim [lindex $line 1]]
                if {$old_name != ""} {
                    lappend ::Pin2PartRename::old_name $old_name
                    lappend ::Pin2PartRename::new_name $new_name
                    puts "Rename condition: '$old_name' to '$new_name'"
                }
            }
        }

    } else {
        set pf [open $fname w]
        puts $pf "# HEADER (begin)"
        puts $pf "# Configuration file for rename Cadence Net Alias"
        puts $pf "# DO NOT MODIFY <HEADER> of this file"
        puts $pf "# "
        puts $pf "# Template for rename:"
        puts $pf "# <rename mask> : <new name mask>"
        puts $pf "# "
        puts $pf "# Example:"
        puts $pf "# DATA_BUS10 : CON10"
        puts $pf "# DATA_BUS20 : CON20"
        puts $pf "# "
        puts $pf "# Result:"
        puts $pf "# BUS10_IN1 rename to: BUS_IN1"
        puts $pf "# BUS30_IN2 rename to: BUS_IN2"
        puts $pf "# "
        puts $pf "# HEADER (end)"
        puts $pf "# "
        close $pf
    }
}


proc ::Pin2PartRename::ExistInMask {name} {
    set exist 0
    if {"$name" in $::Pin2PartRename::old_name} {
        set exist 1
    }
    return $exist
}


proc ::Pin2PartRename::GetNewName {name} {
    set id [lsearch -exact $::Pin2PartRename::old_name "$name"]
    set new_name [lindex $::Pin2PartRename::new_name $id]
    puts "					RENAMING: '$name' to '$new_name'"
    return $new_name
}
