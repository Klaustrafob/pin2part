package require Tcl 8.4
package require DboTclWriteBasic 16.3.0

package require debug_log
package require Pin2Part
package require Pin2PartCfg

package provide capPin2PartApp 1.0

namespace eval ::capPin2PartApp {
    set fname      ""
    set reference  ""
    set return_str ""
}


proc ::capPin2PartApp::addDesignAccessoryMenu {} {
    AddAccessoryMenu "Pin2Part" "Launch" "::capPin2PartApp::GUI"
}
RegisterAction "_cdnCapTclAddDesignCustomMenu" "::capPin2PartApp::capTrue" "" "::capPin2PartApp::addDesignAccessoryMenu" ""


proc ::capPin2PartApp::exi {} {
    wm withdraw .
    ::Pin2PartCfg::WriteCfgFile
}

debug_log::set_fname "pin2part.log"


proc ::capPin2PartApp::openPinFile {} {
    set types_quartus {
        {"Quartus pin file" {.pin}}
        {"All files"        {*}}
    }
    set label "QUARTUS PIN file:"
    set fname [tk_getOpenFile -filetypes $types_quartus -parent .]
    if [file exists $fname] {
        debug_log::write "Selected Quartus pin-file: $fname"
        set ::capPin2PartApp::fname $fname
        Pin2PartCfg::SetFName $fname
    }
}


proc ::capPin2PartApp::Run {} {
    set fname $::capPin2PartApp::fname
    set return_str "ERROR!"
    if [file exists $fname] {
        ::Pin2Part::ReadPinFile $::capPin2PartApp::fname
        ::Pin2Part::Draw
        set return_str "Done"
    } else {
        set return_str "ERROR! Can't find file: $fname"
    }
    set ::capPin2PartApp::return_str $return_str
}


proc ::capPin2PartApp::Init {} {
    debug_log::write "Run time: [clock format [clock seconds]]"
    set fname [Pin2PartCfg::GetFName]
    set ref   [Pin2PartCfg::GetReference]
    set ::capPin2PartApp::fname $fname
    set ::capPin2PartApp::reference $ref
    debug_log::write "read fname from cfg-file: $fname"
    debug_log::write "read ref from cfg-file: $ref"
    debug_log::write "fname: $::capPin2PartApp::fname"
    debug_log::write "reference: $::capPin2PartApp::reference"
}


proc ::capPin2PartApp::GUI {pLib} {

    ::capPin2PartApp::Init

    package require Tk 8.4
    wm deiconify .
    wm title . "Pin to Part"

    wm protocol . WM_DELETE_WINDOW {
    }
    set fname $::capPin2PartApp::fname
    set ref   $::capPin2PartApp::reference

    label .l1 -text "Export Altera pin-file to Cadence Capture part\n"
    label .l2 -text "Current configuration:"
    label .l3 -text "  pin-file:  $fname"
    label .l4 -text "  reference: $ref \n"

    button .open_pin -text "Select Quartus pin-file" -command ::capPin2PartApp::openPinFile -width 40
    button .run_pin -text "RUN" -command ::capPin2PartApp::Run -width 40

    label .l10 -text "$::capPin2PartApp::return_str"
    button .exi -text "EXIT" -command ::capPin2PartApp::exi -width 40

    grid .l1 -row 0
    grid .l2 -row 1
    grid .l3 -row 2
    grid .l4 -row 3
    grid .open_pin -row 8
    grid .run_pin -row 9
    grid .l10 -row 10
    grid .exi -row 11
}

proc ::capPin2PartApp::capTrue {} {
    return 1
}
