# type in capture command window "source [file normalize {D:\pin2part\Pin2Part.tcl}]"

set lNullObj NULL
set lStatus [DboState]

set LogFileName 			[file normalize {D:\pin2part\Pin2Part.log}]
set LogFile      			[open $LogFileName w+]

set AlteraPinFileName 	[file normalize {D:\ImWork\FPGA\xd_readout\output_files\xd_readout.pin}]
set AllteraPinFile      [open $AlteraPinFileName r]
set AlteraNetlist    	[read $AllteraPinFile ]
set SplitNetlist  		[split $AlteraNetlist "\n"]

proc NetNameUni {pNetName pStandard} {
	if { [expr {($pNetName eq "GXB_GND*") || ($pNetName eq "GND+")} || [regexp {GNDA+} $pNetName match]] } {
		return "GND"
	} elseif { [expr {
		  ($pNetName eq "") ||
		  ($pNetName eq "DNU") ||
		  ($pNetName eq "RESERVED_INPUT_WITH_WEAK_PULLUP") ||
		  ($pNetName eq "GXB_NC")  ||
		  ($pNetName eq "~ALTERA_DATA0~ / RESERVED_INPUT") ||
		  ($pNetName eq "~ALTERA_CLKUSR~ / RESERVED_INPUT") ||
		  ($pNetName eq "~ALTERA_nCEO~ / RESERVED_OUTPUT_OPEN_DRAIN") ||
		  ($pNetName eq "GNDSENSE") ||
		  ($pNetName eq "VCCLSENSE")}] } {
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

proc GetAlteraNet { Netlist PinNumber } {
	foreach quartus_string [lindex $Netlist] {
		set split_quartus_string [split $quartus_string :]
		set current_pin [string trim [lindex $split_quartus_string 1]]
		if {$current_pin eq $PinNumber} {
			set current_net [string trim [lindex $split_quartus_string 0]]
			set current_standard [string trim [lindex $split_quartus_string 3]]
			return [NetNameUni $current_net $current_standard]
		}
	}
}

proc AddNetToPin {pPin pAlias} {
	set lStatus [DboState]
	set lWireLength 12
	# dependet of Page Grid Refrence
	set UnitFactor 0.12
	
	#Get starting coordinates
	set lStartPoint [$pPin GetOffsetStartPoint $lStatus]
	set lStartPointX [expr [DboTclHelper_sGetCPointX $lStartPoint]* $UnitFactor]
	set lStartPointY [expr [DboTclHelper_sGetCPointY $lStartPoint]* $UnitFactor]
	#puts "Start: $lStartPointX , $lStartPointY"

	#Get endpoint coordinates
	set lHotSpotPoint [$pPin GetOffsetHotSpot $lStatus]
	set lHotSpotPointX [expr [DboTclHelper_sGetCPointX $lHotSpotPoint]* $UnitFactor]
	set lHotSpotPointY [expr [DboTclHelper_sGetCPointY $lHotSpotPoint]* $UnitFactor]
	#puts "HotSpotPointY: $lHotSpotPointX , $lHotSpotPointY"


    if {$lHotSpotPointX > $lStartPointX} {
		PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX+$lWireLength] $lHotSpotPointY
		PlaceNetAlias [expr $lHotSpotPointX+3] $lHotSpotPointY $pAlias
    } elseif {$lHotSpotPointX < $lStartPointX} {
        PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX-$lWireLength] $lHotSpotPointY
		PlaceNetAlias [expr $lHotSpotPointX-$lWireLength+1] $lHotSpotPointY $pAlias
    }
	
	$lStatus -delete
}

proc ModifyNetOfPin {pPin pWire pNet pAlteraNet} {
	set lStatus [DboState]
	set lAliasIter [$pWire NewAliasesIter $lStatus]
	#get the first alias of wire
	set lAlias [$lAliasIter NextAlias $lStatus]
	set lNullObj NULL
	set lStatus [$pNet SetName [DboTclHelper_sMakeCString $pAlteraNet]]
	while {$lAlias!=$lNullObj} {
		set pReplacedAliasCStr [DboTclHelper_sMakeCString $pAlteraNet]
		set lStatus [$lAlias SetName $pReplacedAliasCStr]
		#get the next alias of wire
		set lAlias [$lAliasIter NextAlias $lStatus]
	}
	delete_DboWireAliasesIter $lAliasIter
	$lStatus -delete
}

proc DeleteNetOfPin {pWire} {
	set lStatus [DboState]
	UnSelectAll
	set ID [$pWire GetId $lStatus]
	SelectObjectById $ID
	Delete
	$lStatus -delete
}

set lSession $::DboSession_s_pDboSession
DboSession -this $lSession
set lDesign [$lSession GetActiveDesign]
if { $lDesign == $lNullObj} {
	set lError [DboTclHelper_sMakeCString "Active design not found"]
	DboState_WriteToSessionLog $lError
	return
}
set lDesignName [DboTclHelper_sMakeCString]
set lStatus [$lDesign GetName $lDesignName]
set lDesignNameStr [DboTclHelper_sGetConstCharPtr $lDesignName]
puts $LogFile $lDesignNameStr
puts $lDesignNameStr

set lSchematicIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
#get the first schematic view
set lView [$lSchematicIter NextView $lStatus]
while { $lView != $lNullObj} {
	#dynamic cast from DboView to DboSchematic
	set lSchematic [DboViewToDboSchematic $lView]
	set lSchematicName [DboTclHelper_sMakeCString]
	set lStatus [$lSchematic GetName $lSchematicName]
	set lSchematicNameStr [DboTclHelper_sGetConstCharPtr $lSchematicName]
	puts $LogFile "	$lSchematicNameStr"
	puts "	$lSchematicNameStr"
	set lPagesIter [$lSchematic NewPagesIter $lStatus]
	#get the first page
	set lPage [$lPagesIter NextPage $lStatus]
	while {$lPage!=$lNullObj} {
		set lPageName [DboTclHelper_sMakeCString]
		set lStatus [$lPage GetName $lPageName]
		set lPageNameStr [DboTclHelper_sGetConstCharPtr $lPageName]
		puts "		$LogFile $lPageNameStr"
		puts "		$lPageNameStr"
		set lPartInstsIter [$lPage NewPartInstsIter $lStatus]
		#get the first part inst
		set lInst [$lPartInstsIter NextPartInst $lStatus]
		while {$lInst!=$lNullObj} {
			#dynamic cast from DboPartInst to DboPlacedInst
			set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
			if {$lPlacedInst != $lNullObj} {
				set lReferenceName [DboTclHelper_sMakeCString]
				$lPlacedInst GetReference $lReferenceName
				set lReferenceDesignator [DboTclHelper_sMakeCString]
				$lPlacedInst GetReferenceDesignator $lReferenceDesignator
				set lReferenceNameStr [DboTclHelper_sGetConstCharPtr $lReferenceName]
				set lReferenceDesignatorStr [DboTclHelper_sGetConstCharPtr $lReferenceDesignator]
				if {$lReferenceNameStr eq "DD3"} {
					puts "			$lReferenceNameStr	$lReferenceDesignatorStr"
					puts $LogFile "			$lReferenceNameStr	$lReferenceDesignatorStr"
					OPage $lSchematicNameStr $lPageNameStr
					set lIter [$lPlacedInst NewPinsIter $lStatus]
					#get the first pin of the part
					set lPin [$lIter NextPin $lStatus]
					# iterate of all pins
					while {$lPin != $lNullObj } {
						set lPinNumber [DboTclHelper_sMakeCString]
						set lStatus [$lPin GetPinNumber $lPinNumber]
						set lPinNumberStr [DboTclHelper_sGetConstCharPtr $lPinNumber]
						set pAlteraNet [GetAlteraNet $SplitNetlist $lPinNumberStr]
						set lNet [$lPin GetNet $lStatus]
						if {$lNet != $lNullObj } {
							set lNetName [DboTclHelper_sMakeCString]	
							set lStatus [$lNet GetNetName $lNetName]
							set lNetNameStr [DboTclHelper_sGetConstCharPtr $lNetName]
							if {[string toupper $pAlteraNet] ne $lNetNameStr} {
								set lWire [$lPin GetWire $lStatus]
								if {$lWire != $lNullObj } {
									if { $pAlteraNet eq "NC"} {
										# delete wire
										DeleteNetOfPin $lWire
										puts "				$lPinNumberStr $lNetNameStr delete"
										puts $LogFile "				$lPinNumberStr $lNetNameStr delete"										
									} else {
										# delete wire
										DeleteNetOfPin $lWire
										AddNetToPin $lPin $pAlteraNet
										set lStatus [$lNet SetName [DboTclHelper_sMakeCString $pAlteraNet]]
										puts $LogFile "				$lPinNumberStr $pAlteraNet $lNetNameStr reuse"
										puts "				$lPinNumberStr $pAlteraNet $lNetNameStr reuse"										
									}
								}
							} else {
								puts $LogFile "				$lPinNumberStr $pAlteraNet  $lNetNameStr OK"
								puts "				$lPinNumberStr $pAlteraNet  $lNetNameStr OK"
							}
						} elseif {$pAlteraNet ne "NC"} {
							# add wire & net
							AddNetToPin $lPin $pAlteraNet
							puts "				$lPinNumberStr $pAlteraNet add"
							puts $LogFile "				$lPinNumberStr $pAlteraNet add"
						} else {
							puts "				$lPinNumberStr NC"
						}
						#get the next pin of the part
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
	#get the next schematic view
	set lView [$lSchematicIter NextView $lStatus]
}
delete_DboLibViewsIter $lSchematicIter

close $LogFile
$lStatus -delete

