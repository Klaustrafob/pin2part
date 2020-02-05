
package require debug_log
package require Pin2Part
package require Pin2PartCfg

package provide capPin2PartApp 1.0

namespace eval ::capPin2PartApp {
    set fname      ""
    set reference  ""
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
    global label_pinfile
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
        set label_pinfile $fname
    }
}


proc ::capPin2PartApp::Run {} {
    global label_status

    ::capPin2PartApp::SetReference

    set fname $::capPin2PartApp::fname
    if [file exists $fname] {
        ::Pin2Part::ReadPinFile $::capPin2PartApp::fname
        ::Pin2Part::Draw $::capPin2PartApp::reference
        set label_status "Done"
    } else {
        set label_status "ERROR! Can't find file: $fname"
    }
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


proc ::capPin2PartApp::SetReference {} {
    set ref [.eref_des get]
    set ::capPin2PartApp::reference $ref
    Pin2PartCfg::SetReference $ref

    .eref_des delete 0 end
    .eref_des insert 0 $ref
}


proc ::capPin2PartApp::GUI {pLib} {

    ::capPin2PartApp::Init

    package require Tk 8.4
    wm deiconify .
    wm title . "Pin to Part"
    wm geometry . 400x300

    wm protocol . WM_DELETE_WINDOW {
    }
    set fname $::capPin2PartApp::fname
    set ref   $::capPin2PartApp::reference

    label .ltitle -text "Export Altera pin-file to Cadence Capture part\n"

    label .lfile -text "Path to pin-file:"
    label .lpin_file -textvariable label_pinfile -text $fname
    button .sel_pin_file -text "Select pin-file" -command ::capPin2PartApp::openPinFile -width 15

    set entry_ref $ref
    entry .eref_des -textvariable entry_ref -width 10
    .eref_des insert 0 $ref
    button .set_ref -text "Set reference" -command "::capPin2PartApp::SetReference" -width 15

    button .run_pin -text "RUN" -command ::capPin2PartApp::Run -width 15

    label .lstatus -text idle -textvariable label_status
    button .exi -text "EXIT" -command ::capPin2PartApp::exi -width 15

    grid .ltitle -row 0

    grid .lfile -row 1 -sticky w
    grid .lpin_file -row 2 -sticky w
    grid .sel_pin_file -row 4
    grid [label .lempty1 -text ""] -row 5

    grid .eref_des -row 6
    grid .set_ref -row 7
    grid [label .lempty2 -text ""] -row 8

    grid .run_pin -row 9
    grid [label .lempty3 -text ""] -row 10

    grid .lstatus -row 11
    grid .exi -row 12

}

proc ::capPin2PartApp::capTrue {} {
    return 1
}
