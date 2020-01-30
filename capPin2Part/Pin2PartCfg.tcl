#
# Read/Write configuration file
#
# Usage example:
#   package require Pin2PartCfg
#   set <var1> [Pin2PartCfg::GetFName]
#   set <var2> [Pin2PartCfg::GetReference]
#   Pin2PartCfg::SetFName <val1>
#   Pin2PartCfg::SetReference <val2>
#   Pin2PartCfg::WriteCfgFile

package provide Pin2PartCfg 1.0

namespace eval ::Pin2PartCfg {
    set cfg_fname ".pin2partcfg.dat"
    set fname ""
    set reference ""
}

proc ::Pin2PartCfg::WriteCfgFile {} {
    set fname $::Pin2PartCfg::cfg_fname
    set pf [open $fname w]
    puts $pf "# Configuration file for Pin2Part(Cadence Capture Application)"
    puts $pf "# DO NOT MODIFY this file"
    puts $pf $::Pin2PartCfg::fname
    puts $pf $::Pin2PartCfg::reference
    close $pf
}

proc ::Pin2PartCfg::ReadCfgFile {} {
    set fname $::Pin2PartCfg::cfg_fname
    if [file exists $fname] {
        set pf [open $fname r]
        set lines [split [read $pf] "\n"]
        close $pf

        set fname [lindex $lines 2]
        set ref [lindex $lines 3]
        set ::Pin2PartCfg::fname $fname
        set ::Pin2PartCfg::reference $ref
    }
}

proc ::Pin2PartCfg::GetFName {} {
    ::Pin2PartCfg::ReadCfgFile
    return $::Pin2PartCfg::fname
}

proc ::Pin2PartCfg::GetReference {} {
    ::Pin2PartCfg::ReadCfgFile
    return $::Pin2PartCfg::reference
}

proc ::Pin2PartCfg::SetFName {fname} {
    set ::Pin2PartCfg::fname $fname
}

proc ::Pin2PartCfg::SetReference {ref} {
    set ::Pin2PartCfg::reference $ref
}
