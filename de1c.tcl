#!/usr/local/bin/tclsh

cd "[file dirname [info script]]/"
source "pkgIndex.tcl"

set de1(has_flowmeter) 1
set settings(creator) 1
set ::de1(de1_address) "C1:80:A7:32:CD:A3"
package require de1_creatormain
de1_creator_ui_startup