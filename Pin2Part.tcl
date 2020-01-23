# type in capture command window "source [file normalize {A:\Heap\Pin2Part.tcl}]"

set lNullObj NULL
set LogFileName 			[file normalize {A:\Heap\Pin2Part.log}]
set LogFile      			[open $LogFileName w+]

set AlteraPinFileName 	[file normalize {A:\Heap\ROIC\output_files\ROICx11.pin}]
set AllteraPinFile      [open $AlteraPinFileName r]
set AlteraNetlist    	[read $AllteraPinFile ]
set SplitNetlist  		[split $AlteraNetlist "\n"]

proc NetNameUni {pNetName} {
	if { [expr {($pNetName eq "GXB_GND*") || ($pNetName eq "GND+")}] } {
		return "GND"
	} elseif { [expr {
		  ($pNetName eq "DNU") ||
		  ($pNetName eq "RESERVED_INPUT_WITH_WEAK_PULLUP") ||
		  ($pNetName eq "GXB_NC")  ||
		  ($pNetName eq "~ALTERA_DATA0~ / RESERVED_INPUT") ||
		  ($pNetName eq "~ALTERA_CLKUSR~ / RESERVED_INPUT") ||
		  ($pNetName eq "~ALTERA_nCEO~ / RESERVED_OUTPUT_OPEN_DRAIN") ||
		  ($pNetName eq "GNDSENSE") ||
		  ($pNetName eq "VCCLSENSE")}] } {
		return "NC"
	} else {
		regsub -all {\(n\)} $pNetName {n} uni_net
		#regsub -all {\.} $uni_net {_} uni_net
		regsub -all {\[} $uni_net {} uni_net
		regsub -all {\]} $uni_net {} uni_net
		return $uni_net
	}
}

proc GetAlteraNet { Netlist PinNumber } {
	foreach quartus_string [lindex $Netlist] {
		set split_quartus_string [split $quartus_string :]
		set current_pin [string trim [lindex $split_quartus_string 1]]
		if {$current_pin eq $PinNumber} {
			set current_net [string trim [lindex $split_quartus_string 0]]
			return [NetNameUni $current_net]
		}
	}
}

proc AddNetToPin {pSchematicNameStr pPageNameStr pPin pAlias lStatus} {
	set WireLength 12
	# dependet of Page Grid Refrence
	set UnitFactor 0.12
	
	#получить начальные координаты
	set lStartPoint [$pPin GetOffsetStartPoint $lStatus]
	set lStartPointX [expr [DboTclHelper_sGetCPointX $lStartPoint]* $UnitFactor]
	set lStartPointY [expr [DboTclHelper_sGetCPointY $lStartPoint]* $UnitFactor]
	#puts "Start: $lStartPointX , $lStartPointY"

	#получить координаты конечной точки
	set lHotSpotPoint [$pPin GetOffsetHotSpot $lStatus]
	set lHotSpotPointX [expr [DboTclHelper_sGetCPointX $lHotSpotPoint]* $UnitFactor]
	set lHotSpotPointY [expr [DboTclHelper_sGetCPointY $lHotSpotPoint]* $UnitFactor]
	#puts "HotSpotPointY: $lHotSpotPointX , $lHotSpotPointY"

	#Направление линии
	set offsetX 0

	if {$lHotSpotPointX > $lStartPointX} {
		set offsetX $WireLength
	} elseif {$lHotSpotPointX < $lStartPointX} {
		set offsetX [expr -$WireLength]
	}

	#open page for drawing
	OPage $pSchematicNameStr $pPageNameStr
	ZoomAll
	PlaceWire $lHotSpotPointX $lHotSpotPointY [expr $lHotSpotPointX+$offsetX] $lHotSpotPointY
	PlaceNetAlias [expr $lHotSpotPointX + $offsetX/2 - $WireLength/3] $lHotSpotPointY $pAlias
}

proc ModifyNetOfPin {pSchematicNameStr pPageNameStr pPin pWire pAlteraNet pStatus} {
	set lAliasIter [$pWire NewAliasesIter $pStatus]
	#get the first alias of wire
	set lAlias [$lAliasIter NextAlias $pStatus]
	set lNullObj NULL
	set IsAlias FALSE
	while { $lAlias!=$lNullObj} {
		set pReplacedAliasCStr [DboTclHelper_sMakeCString $pAlteraNet]
		set pStatus [$lAlias SetName $pReplacedAliasCStr]
		set IsAlias TRUE
		#get the next alias of wire
		set lAlias [$lAliasIter NextAlias $pStatus]
	}
	delete_DboWireAliasesIter $lAliasIter
	
	if { !$IsAlias} {
		set lState [$pWire SetColor 4]
	}
}

proc DeleteNetOfPin {pSchematicNameStr pPageNameStr pWire pStatus} {
	OPage $pSchematicNameStr $pPageNameStr
	ZoomAll
	set ID [$pWire GetId $pStatus]
	SelectObjectById $ID
	Delete
}


#set PinNumber "AG27"
#puts [GetAlteraNet $SplitNetlist $PinNumber]


set lStatus [DboState]

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

set lSchematicName [DboTclHelper_sMakeCString]
set lPageName [DboTclHelper_sMakeCString]
set lValue [DboTclHelper_sMakeCString]
set lPinNumber [DboTclHelper_sMakeCString]
set lNetName [DboTclHelper_sMakeCString]	


set lSchematicIter [$lDesign NewViewsIter $lStatus $::IterDefs_SCHEMATICS]
#get the first schematic view
set lView [$lSchematicIter NextView $lStatus]
while { $lView != $lNullObj} {
	#dynamic cast from DboView to DboSchematic
	set lSchematic [DboViewToDboSchematic $lView]
	set lStatus [$lSchematic GetName $lSchematicName]
	set lSchematicNameStr [DboTclHelper_sGetConstCharPtr $lSchematicName]
	puts  $LogFile $lSchematicNameStr
	puts $lSchematicNameStr
	set lPagesIter [$lSchematic NewPagesIter $lStatus]
	#get the first page
	set lPage [$lPagesIter NextPage $lStatus]
	while {$lPage!=$lNullObj} {
		set lStatus [$lPage GetName $lPageName]
		set lPageNameStr [DboTclHelper_sGetConstCharPtr $lPageName]
		puts $LogFile $lPageNameStr
		puts $lPageNameStr
		set lPartInstsIter [$lPage NewPartInstsIter $lStatus]
		#get the first part inst
		set lInst [$lPartInstsIter NextPartInst $lStatus]
		while {$lInst!=$lNullObj} {
			#dynamic cast from DboPartInst to DboPlacedInst
			set lPlacedInst [DboPartInstToDboPlacedInst $lInst]
			if {$lPlacedInst != $lNullObj} {
				$lPlacedInst GetPartValue $lValue
				set PartValueStr [DboTclHelper_sGetConstCharPtr $lValue]
				if {$PartValueStr eq "10CL016YF484C6G"} {
					set lIter [$lPlacedInst NewPinsIter $lStatus]
					#get the first pin of the part
					set lPin [$lIter NextPin $lStatus]
					# iterate of all pins
					#set nPin 0
					while {$lPin != $lNullObj } {
						#set nPin [expr $nPin + 1]
						set lStatus [$lPin GetPinNumber $lPinNumber]
						set lPinNumberStr [DboTclHelper_sGetConstCharPtr $lPinNumber]
						set pAlteraNet [GetAlteraNet $SplitNetlist $lPinNumberStr]
						set lNet [$lPin GetNet $lStatus]
						puts $lPinNumberStr
						if {$lNet != $lNullObj } {
							set lStatus [$lNet GetNetName $lNetName]
							set lNetNameStr [DboTclHelper_sGetConstCharPtr $lNetName]
							if {$lNetNameStr ne $pAlteraNet} {
								set lWire [$lPin GetWire $lStatus]
								if {$lWire != $lNullObj } {
									if { $pAlteraNet eq "NC"} {
										# delete wire
										puts $LogFile [concat $lPinNumberStr " " $lNetNameStr " delete "]
										close $LogFile
										puts [concat $lPinNumberStr " " $lNetNameStr " delete "]
										DeleteNetOfPin $lSchematicNameStr $lPageNameStr $lWire $lStatus
										set lStatus  [$lPage MarkModified]
										set LogFile  [open $LogFileName a+]
									} else {
										#rename net
										puts $LogFile [concat $lPinNumberStr " " $pAlteraNet " " $lNetNameStr " reuse" ]
										close $LogFile
										puts [concat $lPinNumberStr " " $pAlteraNet " " $lNetNameStr " reuse" ]
										ModifyNetOfPin $lSchematicNameStr $lPageNameStr $lPin $lWire $pAlteraNet $lStatus
										set lStatus  [$lPage MarkModified]
										set LogFile  [open $LogFileName a+]
									}
								}
							} else {
								puts $LogFile "$lPinNumberStr $pAlteraNet  $lNetNameStr OK"
								puts "$lPinNumberStr $pAlteraNet  $lNetNameStr OK"
							}
						} elseif {$pAlteraNet ne "NC"} {
							# add wire & net
							puts $LogFile [concat $lPinNumberStr " " $pAlteraNet " add " ]
							close $LogFile
							puts [concat $lPinNumberStr " " $pAlteraNet " add " ]
							AddNetToPin $lSchematicNameStr $lPageNameStr $lPin $pAlteraNet $lStatus
							set lStatus  [$lPage MarkModified]
							set LogFile  [open $LogFileName a+]
						}
						puts "$lPinNumberStr NC"
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

