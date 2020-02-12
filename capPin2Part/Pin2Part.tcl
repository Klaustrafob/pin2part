package require debug_log

package provide Pin2Part 1.0


namespace eval ::Pin2Part {
    set SplitNetlist ""
	# page unit mm
	set UnitFactor 0.12
	# page unit inc
	#set UnitFactor 0.01
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
	unset AlteraPinFileName AllteraPinFile AlteraNetlist SplitNetlist
}

proc ::Pin2Part::CustomNet {pNetName} {
    if {[expr {	
				($pNetName eq {GXB_GND*}) ||
				($pNetName eq {GND+}) ||
				[regexp {GNDA+} $pNetName match]}]} {
        return {GND}
    } elseif {[expr {
                     ($pNetName eq {}) ||
                     ($pNetName eq {DNU}) ||
                     ($pNetName eq {RESERVED_INPUT_WITH_WEAK_PULLUP}) ||
                     ($pNetName eq {GXB_NC})  ||
                     ($pNetName eq {~ALTERA_DATA0~ / RESERVED_INPUT}) ||
                     ($pNetName eq {~ALTERA_CLKUSR~ / RESERVED_INPUT}) ||
                     ($pNetName eq {~ALTERA_nCEO~ / RESERVED_OUTPUT_OPEN_DRAIN}) ||
                     ($pNetName eq {GNDSENSE}) ||
					 ($pNetName eq {NIO_PULLUP}) ||
                     ($pNetName eq {VCCLSENSE})}]} {
        return {NC}
	} elseif {$pNetName eq {AS_DATA0, ASDO}} {
		return {ASDO}
	} elseif {$pNetName eq {altera_reserved_tdo}} {
		return {TDO}
	} elseif {$pNetName eq {altera_reserved_tdi}} {
		return {TDI}
	} elseif {$pNetName eq {altera_reserved_tck}} {
		return {TCK}
	} elseif {$pNetName eq {altera_reserved_tms}} {
		return {TMS}
	} else {
		return $pNetName
	}
}


proc ::Pin2Part::NetNameUni {pNetName pStandard} {
	set pNetName [::Pin2Part::CustomNet $pNetName]
	if {[expr {($pStandard eq "LVDS") || ($pStandard eq "High Speed Differential I/O")}]} {
        set Negativ [regexp {\(n\)+} $pNetName match]
        regsub -all -- {\(n\)} $pNetName {} pNetName
        if {$Negativ} {
            set Polarity "n"
        } else {
            set Polarity "p"
        }

		set EndSymbol [string index $pNetName end]
        #set IsVector [regexp {\[+} $pNetName match]
        #regsub -all -- {\]} $pNetName {} pNetName
        set pNetName [string toupper $pNetName]
        if {$EndSymbol eq "\]"} {
            set pos [string last "\[" $pNetName]
            set pNetName [string replace $pNetName $pos $pos $Polarity]
			#regsub -all -- {\[} $pNetName {} pNetName
			unset pos
        } else {
            set pNetName "$pNetName$Polarity"
        }
		unset Negativ Polarity EndSymbol
    } else {
        set pNetName [string toupper $pNetName]
    }
	regsub -all -- {\]} $pNetName {} pNetName
    regsub -all -- {\[} $pNetName {} pNetName
    regsub -all -- {\)} $pNetName {} pNetName
    regsub -all -- {\(} $pNetName {} pNetName
	regsub -all -- {\.} $pNetName {_} pNetName
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
		unset split_quartus_string current_pin
    }
}


proc ::Pin2Part::AddNetToPin {pPin pAlias Color} {
    set lStatus [DboState]
    set lWireLength [expr 1.2*10]
    # Get starting coordinates
    set lStartPoint [$pPin GetOffsetStartPoint $lStatus]
    set lStartPointX [expr [DboTclHelper_sGetCPointX $lStartPoint]* $::Pin2Part::UnitFactor]
    set lStartPointY [expr [DboTclHelper_sGetCPointY $lStartPoint]* $::Pin2Part::UnitFactor]
    # puts "Start: $lStartPointX , $lStartPointY"

    # Get endpoint coordinates
    set lHotSpotPoint [$pPin GetOffsetHotSpot $lStatus]
    set lHotSpotPointX [expr [DboTclHelper_sGetCPointX $lHotSpotPoint]* $::Pin2Part::UnitFactor]
    set lHotSpotPointY [expr [DboTclHelper_sGetCPointY $lHotSpotPoint]* $::Pin2Part::UnitFactor]
    # puts "HotSpotPointY: $lHotSpotPointX , $lHotSpotPointY"

    if {$lHotSpotPointY == $lStartPointY} {
        if {$lHotSpotPointX > $lStartPointX} {
			if { [catch {PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX+$lWireLength] $lHotSpotPointY} lResult] } {
				return $lResult
			}
			if { [catch {PlaceNetAlias [expr $lHotSpotPointX+3] $lHotSpotPointY "pAlias"} lResult] } {
				return $lResult
			}
        } elseif {$lHotSpotPointX < $lStartPointX} {
			if { [catch {$lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX-$lWireLength] $lHotSpotPointY} lResult] } {
				return $lResult
			}
			if { [catch {PlaceNetAlias [expr $lHotSpotPointX-$lWireLength] $lHotSpotPointY "pAlias"} lResult] } {
				return $lResult
			}
        }
		set lWire [$pPin GetWire $lStatus]
        if {$lWire != {NULL}} {
			::Pin2Part::ModifyNetOfPin $lWire $pAlias $Color
		}
		unset lWire
    }
	unset lWireLength lStartPoint lStartPointX lStartPointY lHotSpotPoint lHotSpotPointX lHotSpotPointY
    $lStatus -delete
	return 0
}


proc ::Pin2Part::ModifyNetOfPin {pWire pAlias Color} {
    set lStatus [DboState]
	set pWire [DboWireToDboWireScalar $pWire]
	if {$pWire!={NULL}} {
		set lAliasIter [$pWire NewAliasesIter $lStatus]
		# get the first alias of wire
		set lAlias [$lAliasIter NextAlias $lStatus]
		if {$lAlias=={NULL}} {
			set lStatus [$pWire SetColor $Color]
		} else {
			while {$lAlias!={NULL}} {
				UnSelectAll
				set ID [$lAlias GetId $lStatus]
				SelectObjectById $ID
				SetProperty {Name} $pAlias
				SetColor $Color
				UnSelectAll
				unset ID
				# get the next alias of wire
				set lAlias [$lAliasIter NextAlias $lStatus]
			}
		}
		unset lAlias
		delete_DboWireAliasesIter $lAliasIter
	}
	unset 
    $lStatus -delete
}


proc ::Pin2Part::DeleteNetOfPin {pWire} {
    set lStatus [DboState]
    UnSelectAll
    set ID [$pWire GetId $lStatus]
    SelectObjectById $ID
    Delete
	unset ID
    $lStatus -delete
}


proc ::Pin2Part::Draw {reference} {
    set lStatus [DboState]
    set AddColor 2
	set ModifyColor 4
    set lSession $::DboSession_s_pDboSession
    DboSession -this $lSession
    set lDesign [$lSession GetActiveDesign]
    if {$lDesign == {NULL}} {
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
    while {$lView != {NULL}} {
        # dynamic cast from DboView to DboSchematic
        set lSchematic [DboViewToDboSchematic $lView]
        set lSchematicName [DboTclHelper_sMakeCString]
        set lStatus [$lSchematic GetName $lSchematicName]
        set lSchematicNameStr [DboTclHelper_sGetConstCharPtr $lSchematicName]
        wrlog "	$lSchematicNameStr"
        puts "	$lSchematicNameStr"
        set lPagesIter [$lSchematic NewPagesIter $lStatus]
        # get the first page
        set lPage [$lPagesIter NextPage $lStatus]
        while {$lPage!={NULL}} {
            set lPageName [DboTclHelper_sMakeCString]
            set lStatus [$lPage GetName $lPageName]
            set lPageNameStr [DboTclHelper_sGetConstCharPtr $lPageName]
            wrlog "		$lPageNameStr"
            puts "		$lPageNameStr"
            set lPartInstsIter [$lPage NewPartInstsIter $lStatus]
            # get the first part inst
            set lInst [$lPartInstsIter NextPartInst $lStatus]
            while {$lInst!={NULL}} {
                # dynamic cast from DboPartInst to DboPlacedInst
                set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
                if {$lPlacedInst != {NULL}} {
                    set lReferenceName [DboTclHelper_sMakeCString]
                    $lPlacedInst GetReference $lReferenceName
                    set lReferenceDesignator [DboTclHelper_sMakeCString]
                    $lPlacedInst GetReferenceDesignator $lReferenceDesignator
                    set lReferenceNameStr [DboTclHelper_sGetConstCharPtr $lReferenceName]
                    set lReferenceDesignatorStr [DboTclHelper_sGetConstCharPtr $lReferenceDesignator]
                    if {$lReferenceNameStr eq $reference} {
                        puts "			$reference $lReferenceDesignatorStr"
                        wrlog "			$reference $lReferenceDesignatorStr"
                        OPage $lSchematicNameStr $lPageNameStr
                        set lIter [$lPlacedInst NewPinsIter $lStatus]
                        # get the first pin of the part
                        set lPin [$lIter NextPin $lStatus]
                        # iterate of all pins
                        while {$lPin != {NULL}} {
                            set lPinNumber [DboTclHelper_sMakeCString]
                            set lStatus [$lPin GetPinNumber $lPinNumber]
                            set lPinNumberStr [DboTclHelper_sGetConstCharPtr $lPinNumber]
                            set pAlteraNet [::Pin2Part::GetAlteraNet $::Pin2Part::SplitNetlist $lPinNumberStr]
                            set lNet [$lPin GetNet $lStatus]
                            if {$lNet != {NULL}} {
                                set lNetName [DboTclHelper_sMakeCString]
                                set lStatus [$lNet GetNetName $lNetName]
                                set lNetNameStr [DboTclHelper_sGetConstCharPtr $lNetName]
                                if {[string toupper $pAlteraNet] ne [string toupper $lNetNameStr]} {
                                    set lWire [$lPin GetWire $lStatus]
                                    if {$lWire != {NULL}} {
                                        if {$pAlteraNet eq "NC"} {
                                            # delete wire
                                            ::Pin2Part::DeleteNetOfPin $lWire
                                            puts "				$lPinNumberStr $lNetNameStr delete"
                                            wrlog "				$lPinNumberStr $lNetNameStr delete"
                                        } else {
											# modify net
											if { [catch {::Pin2Part::ModifyNetOfPin $lWire $pAlteraNet $ModifyColor} lResult] } {
												return $lResult
											}
                                            wrlog "				$lPinNumberStr $pAlteraNet $lNetNameStr reuse"
                                            puts "				$lPinNumberStr $pAlteraNet $lNetNameStr reuse"
                                        }
										unset lWire
                                    }
                                } else {
                                    wrlog "				$lPinNumberStr $pAlteraNet $lNetNameStr match"
                                    puts "				$lPinNumberStr $pAlteraNet $lNetNameStr match"
                                }
								unset lNetNameStr lNetName
                            } elseif {$pAlteraNet ne "NC"} {
                                # add wire & net
                                ::Pin2Part::AddNetToPin $lPin $pAlteraNet $AddColor
                                puts "				$lPinNumberStr $pAlteraNet add"
                                wrlog "				$lPinNumberStr $pAlteraNet add"
                            } else {
                                puts "				$lPinNumberStr NC"
                            }
							unset lNet pAlteraNet lPinNumberStr lPinNumber
                            # get the next pin of the part
                            set lPin [$lIter NextPin $lStatus]
                        }
						unset lPin
                        delete_DboPartInstPinsIter $lIter
                    }
					unset lReferenceDesignatorStr lReferenceNameStr lReferenceDesignator lReferenceName
                }
				unset lPlacedInst
                set lInst [$lPartInstsIter NextPartInst $lStatus]
            }
			unset lInst lPageNameStr lPageName
            delete_DboPagePartInstsIter $lPartInstsIter
            set lPage [$lPagesIter NextPage $lStatus]
        }
		unset lPage lSchematicNameStr lSchematicName lSchematic
        delete_DboSchematicPagesIter $lPagesIter
        # get the next schematic view
        set lView [$lSchematicIter NextView $lStatus]
    }
	unset lView lDesignNameStr lDesignName lDesign lSession 
    delete_DboLibViewsIter $lSchematicIter
    $lStatus -delete
	UnSelectAll
}
