#!/usr/bin/env tclsh

# Script to build package index file
#
# Usage: run this script from 'tclsh' or 'bash'

set package_name {capPin2Part}

puts " pkg_mkIndex $package_name"
pkg_mkIndex -verbose $package_name

puts ""
puts "Press 'Enter' to continue ..."
gets stdin
