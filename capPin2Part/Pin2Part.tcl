package require debug_log

package provide Pin2Part 1.0


namespace eval ::Pin2Part {
    set SplitNetlist ""
}


proc wrlog {str} {
    debug_log::write $str
}


proc ::Pin2Part::ReadPinFile {fname} {
    set AlteraPinFileName $fname
    wrlog "Get Altera pin-file name: $fname"
    set AllteraPinFile [open  $AlteraPinFileName r]
    set AlteraNetlist  [read  $AllteraPinFile]
    set SplitNetlist   [split $AlteraNetlist "\n"]
    set ::Pin2Part::SplitNetlist $SplitNetlist
}


proc ::Pin2Part::NetNameUni {pNetName pStandard} {
    if {[expr {($pNetName eq "GXB_GND*") || ($pNetName eq "GND+")} || [regexp {GNDA+} $pNetName match]]} {
        return "GND"
    } elseif {[expr {
                     ($pNetName eq "") ||
                     ($pNetName eq "DNU") ||
                     ($pNetName eq "RESERVED_INPUT_WITH_WEAK_PULLUP") ||
                     ($pNetName eq "GXB_NC")  ||
                     ($pNetName eq "~ALTERA_DATA0~ / RESERVED_INPUT") ||
                     ($pNetName eq "~ALTERA_CLKUSR~ / RESERVED_INPUT") ||
                     ($pNetName eq "~ALTERA_nCEO~ / RESERVED_OUTPUT_OPEN_DRAIN") ||
                     ($pNetName eq "GNDSENSE") ||
                     ($pNetName eq "VCCLSENSE")}]} {
        return "NC"
    } elseif {[expr {($pStandard eq "LVDS") || ($pStandard eq "High Speed Differential I/O")}]} {
        set Negativ [regexp {\(n\)+} $pNetName match]
        regsub -all -- {\(n\)} $pNetName {} pNetName
        if {$Negativ} {
            set Polarity "n"
        } else {
            set Polarity "p"
        }

        set IsVector [regexp {\[+} $pNetName match]
        regsub -all -- {\]} $pNetName {} pNetName
        set pNetName [string toupper $pNetName]
        if {$IsVector!=0} {
            set pos [string last "\[" $pNetName]
            set pNetName [string replace $pNetName $pos $pos $Polarity]
        } else {
            set pNetName "$pNetName$Polarity"
        }
    } else {
        set pNetName [string toupper $pNetName]
        regsub -all -- {\]} $pNetName {} pNetName
        regsub -all -- {\[} $pNetName {} pNetName
        regsub -all -- {\)} $pNetName {} pNetName
        regsub -all -- {\(} $pNetName {} pNetName
    }

    return $pNetName
}


proc ::Pin2Part::GetAlteraNet {Netlist PinNumber} {
    foreach quartus_string [lindex $Netlist] {
        set split_quartus_string [split $quartus_string :]
        set current_pin [string trim [lindex $split_quartus_string 1]]
        if {$current_pin eq $PinNumber} {
            set current_net [string trim [lindex $split_quartus_string 0]]
            set current_standard [string trim [lindex $split_quartus_string 3]]
            return [::Pin2Part::NetNameUni $current_net $current_standard]
        }
    }
}


proc ::Pin2Part::AddNetToPin {pPin pAlias} {
    set lStatus [DboState]
    set lWireLength 12
    # dependet of Page Grid Refrence
    set UnitFactor 0.12

    # Get starting coordinates
    set lStartPoint [$pPin GetOffsetStartPoint $lStatus]
    set lStartPointX [expr [DboTclHelper_sGetCPointX $lStartPoint]* $UnitFactor]
    set lStartPointY [expr [DboTclHelper_sGetCPointY $lStartPoint]* $UnitFactor]
    # puts "Start: $lStartPointX , $lStartPointY"

    # Get endpoint coordinates
    set lHotSpotPoint [$pPin GetOffsetHotSpot $lStatus]
    set lHotSpotPointX [expr [DboTclHelper_sGetCPointX $lHotSpotPoint]* $UnitFactor]
    set lHotSpotPointY [expr [DboTclHelper_sGetCPointY $lHotSpotPoint]* $UnitFactor]
    # puts "HotSpotPointY: $lHotSpotPointX , $lHotSpotPointY"

    if {$lHotSpotPointY == $lStartPointY} {
        if {$lHotSpotPointX > $lStartPointX} {
            PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX+$lWireLength] $lHotSpotPointY
            PlaceNetAlias [expr $lHotSpotPointX+3] $lHotSpotPointY $pAlias
        } elseif {$lHotSpotPointX < $lStartPointX} {
            PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX-$lWireLength] $lHotSpotPointY
            PlaceNetAlias [expr $lHotSpotPointX-$lWireLength+1] $lHotSpotPointY $pAlias
        }
    }
    $lStatus -delete
}


proc ::Pin2Part::ModifyNetOfPin {pWire pNet pAlteraNet} {
    set lStatus [DboState]
    set lAliasIter [$pWire NewAliasesIter $lStatus]
    # get the first alias of wire
    set lAlias [$lAliasIter NextAlias $lStatus]
    set lNullObj NULL
    set lStatus [$pNet SetName [DboTclHelper_sMakeCString $pAlteraNet]]
    while {$lAlias!=$lNullObj} {
        # set pReplacedAliasCStr [DboTclHelper_sMakeCString $pAlteraNet]
        UnSelectAll
        set ID [$lAlias GetId $lStatus]
        SelectObjectById $ID
        SetProperty {Name} $pAlteraNet
        SetColor 4
        SetFont "" 1864124768 FALSE TRUE
        # set lStatus [$lAlias SetName $pReplacedAliasCStr]
        # UnSelectAll
        # get the next alias of wire
        set lAlias [$lAliasIter NextAlias $lStatus]
    }
    delete_DboWireAliasesIter $lAliasIter
    $lStatus -delete
}


proc ::Pin2Part::DeleteNetOfPin {pWire} {
    set lStatus [DboState]
    UnSelectAll
    set ID [$pWire GetId $lStatus]
    SelectObjectById $ID
    Delete
    $lStatus -delete
}


proc ::Pin2Part::Draw {reference} {
    set lStatus [DboState]
    set lNullObj NULL
    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lDesign [$lSession GetActiveDesign]
    if {$lDesign == $lNullObj} {
        set lError [DboTclHelper_sMakeCString "Active design not found"]
        DboState_WriteToSessionLog $lError
        return
    }
    set lDesignName [DboTclHelper_sMakeCString]
    set lStatus [$lDesign GetName $lDesignName]
    set lDesignNameStr [DboTclHelper_sGetConstCharPtr $lDesignName]
    wrlog $lDesignNameStr
    puts $lDesignNameStr

    set lSchematicIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
    # get the first schematic view
    set lView [$lSchematicIter NextView $lStatus]
    while {$lView != $lNullObj} {
        # dynamic cast from DboView to DboSchematic
        set lSchematic [DboViewToDboSchematic $lView]
        set lSchematicName [DboTclHelper_sMakeCString]
        set lStatus [$lSchematic GetName $lSchematicName]
        set lSchematicNameStr [DboTclHelper_sGetConstCharPtr $lSchematicName]
        wrlog " $lSchematicNameStr"
        puts " $lSchematicNameStr"
        set lPagesIter [$lSchematic NewPagesIter $lStatus]
        # get the first page
        set lPage [$lPagesIter NextPage $lStatus]
        while {$lPage!=$lNullObj} {
            set lPageName [DboTclHelper_sMakeCString]
            set lStatus [$lPage GetName $lPageName]
            set lPageNameStr [DboTclHelper_sGetConstCharPtr $lPageName]
            wrlog " $lPageNameStr"
            puts " $lPageNameStr"
            set lPartInstsIter [$lPage NewPartInstsIter $lStatus]
            # get the first part inst
            set lInst [$lPartInstsIter NextPartInst $lStatus]
            while {$lInst!=$lNullObj} {
                # dynamic cast from DboPartInst to DboPlacedInst
                set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
                if {$lPlacedInst != $lNullObj} {
                    set lReferenceName [DboTclHelper_sMakeCString]
                    $lPlacedInst GetReference $lReferenceName
                    set lReferenceDesignator [DboTclHelper_sMakeCString]
                    $lPlacedInst GetReferenceDesignator $lReferenceDesignator
                    set lReferenceNameStr [DboTclHelper_sGetConstCharPtr $lReferenceName]
                    set lReferenceDesignatorStr [DboTclHelper_sGetConstCharPtr $lReferenceDesignator]
                    if {$lReferenceNameStr eq "DD3"} {
                        puts " $lReferenceNameStr $lReferenceDesignatorStr"
                        wrlog " $lReferenceNameStr $lReferenceDesignatorStr"
                        OPage $lSchematicNameStr $lPageNameStr
                        set lIter [$lPlacedInst NewPinsIter $lStatus]
                        # get the first pin of the part
                        set lPin [$lIter NextPin $lStatus]
                        # iterate of all pins
                        while {$lPin != $lNullObj} {
                            set lPinNumber [DboTclHelper_sMakeCString]
                            set lStatus [$lPin GetPinNumber $lPinNumber]
                            set lPinNumberStr [DboTclHelper_sGetConstCharPtr $lPinNumber]
                            set pAlteraNet [::Pin2Part::GetAlteraNet $::Pin2Part::SplitNetlist $lPinNumberStr]
                            set lNet [$lPin GetNet $lStatus]
                            if {$lNet != $lNullObj} {
                                set lNetName [DboTclHelper_sMakeCString]
                                set lStatus [$lNet GetNetName $lNetName]
                                set lNetNameStr [DboTclHelper_sGetConstCharPtr $lNetName]
                                if {[string toupper $pAlteraNet] ne $lNetNameStr} {
                                    set lWire [$lPin GetWire $lStatus]
                                    if {$lWire != $lNullObj} {
                                        if {$pAlteraNet eq "NC"} {
                                            # delete wire
                                            ::Pin2Part::DeleteNetOfPin $lWire
                                            puts " $lPinNumberStr $lNetNameStr delete"
                                            wrlog " $lPinNumberStr $lNetNameStr delete"
                                        } else {
                                            ::Pin2Part::ModifyNetOfPin $lWire $lNet $pAlteraNet
                                            # delete wire
                                            # ::Pin2Part::DeleteNetOfPin $lWire
                                            # ::Pin2Part::AddNetToPin $lPin $pAlteraNet
                                            # set lStatus [$lNet SetName [DboTclHelper_sMakeCString $pAlteraNet]]
                                            wrlog " $lPinNumberStr $pAlteraNet $lNetNameStr reuse"
                                            puts " $lPinNumberStr $pAlteraNet $lNetNameStr reuse"
                                        }
                                    }
                                } else {
                                    wrlog " $lPinNumberStr $pAlteraNet $lNetNameStr OK"
                                    puts " $lPinNumberStr $pAlteraNet $lNetNameStr OK"
                                }
                            } elseif {$pAlteraNet ne "NC"} {
                                # add wire & net
                                ::Pin2Part::AddNetToPin $lPin $pAlteraNet
                                puts " $lPinNumberStr $pAlteraNet add"
                                wrlog " $lPinNumberStr $pAlteraNet add"
                            } else {
                                puts " $lPinNumberStr NC"
                            }
                            # get the next pin of the part
                            set lPin [$lIter NextPin $lStatus]
                        }
                        delete_DboPartInstPinsIter $lIter
                    }
                }
                set lInst [$lPartInstsIter NextPartInst $lStatus]
            }
            delete_DboPagePartInstsIter $lPartInstsIter
            set lPage [$lPagesIter NextPage $lStatus]
        }
        delete_DboSchematicPagesIter $lPagesIter
        # get the next schematic view
        set lView [$lSchematicIter NextView $lStatus]
    }
    delete_DboLibViewsIter $lSchematicIter

    $lStatus -delete
}
