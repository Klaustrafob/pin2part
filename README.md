# Part2Pin

Export Altera pin-file to Cadence Capture part

# Using

## Download

Clone Git repository `git clone https://github.com/Klaustrafob/pin2part.git`

## Installation

Installation(or make links for development)

Run **install.ps1** script, which
- copy **capPin2Part** directory to Capture tcl-scripts directory: <Cadence_Installation>\tools\capture\tclscripts\
- creates link in <Cadence_Installation>\tools\capture\tclscripts\capAutoLoad

### Make links

For development this project: run script install2dev.bat from the project root directory

## Run

- open Cadence Capture
- select Schematic Page
- select Menu/Accessory/Pin2Part/Launch
- select Quartus pin-file
- enter reference
- Press RUN
