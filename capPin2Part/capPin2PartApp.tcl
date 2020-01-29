package require Tcl 8.4
package require DboTclWriteBasic 16.3.0

package require debug_log
package require Pin2Part

package provide capPin2PartApp 1.0

namespace eval ::capPin2PartApp {
}


proc ::capPin2PartApp::addDesignAccessoryMenu {} {
    AddAccessoryMenu "Pin2Part" "Launch" "::capPin2PartApp::GUI"
}
RegisterAction "_cdnCapTclAddDesignCustomMenu" "::capPin2PartApp::capTrue" "" "::capPin2PartApp::addDesignAccessoryMenu" ""


proc exi {} {
    wm withdraw .
}

debug_log::set_fname "pin2part.log"

proc openPinFile {} {

    set types_quartus {
        {"Quartus pin file" {.pin}}
        {"All files"        {*}}
    }

    set label "QUARTUS PIN file:"
    set fname [tk_getOpenFile -filetypes $types_quartus -parent .]
    if [file exists $fname] {
        debug_log::write "Selected Quartus pin-file: $fname"
        ::Pin2Part::ReadPinFile $fname
        ::Pin2Part::Draw
    }
}


proc ::capPin2PartApp::GUI {pLib} {

    package require Tk 8.4
    wm deiconify .
    wm title . "Pin to Part"

    wm protocol . WM_DELETE_WINDOW {
    }

    label .l1 -text "Export Altera pin-file to Cadence Capture part"

    button .open_pin -text "Open Quartus pin-file, run" -command openPinFile -width 40

    button .exi -text EXIT -command exi -width 40

    grid .l1 -row 0
    grid .open_pin -row 2
    grid .exi -row 11
}

proc ::capPin2PartApp::capTrue {} {
	return 1
}
