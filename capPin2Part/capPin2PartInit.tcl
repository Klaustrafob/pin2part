# Script to auto load Pin2PartApp package

proc Pin2PartAppLaunch {args} {
    if {[catch {package require capPin2PartApp}]} {
    }
}

Pin2PartAppLaunch
