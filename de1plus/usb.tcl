package provide de1_usb 1.0

proc usb_scan_devices {} {
	set devices [usbserial]
	foreach {device} $devices {
		append_to_de1_list $device "DE1" "usb"
	}
	if {$::scanning == 1} {
		after 200 usb_scan_devices
	}
}


proc usb_connect_to_de1 {} {
	msg "usb_connect_to_de1"

	if {$::settings(connectivity) != "usb" || $::settings(bluetooth_address) == "" } {
		error "usb_connect_to_de1 called but connectivity wrong: $::settings(connectivity) $::settings(bluetooth_address)"
		return
	}

	if {$::currently_connecting_de1_handle != 0} {
		catch {
			close $::currently_connecting_de1_handle
		}
		set ::currently_connecting_de1_handle 0
	}

	catch {
		msg "initiating USB connection to  $::settings(bluetooth_address)"
		set ::currently_connecting_de1_handle [usbserial $::settings(bluetooth_address)]
	}

	if {$::currently_connecting_de1_handle > 0} {
		usb_connect_handler $::settings(bluetooth_address)
	} else {
		msg "usb connect failed"
	}
}


proc usb_connect_handler {usb_path} {
	msg "usb_connect_handler"

	set ::de1(device_handle) $::currently_connecting_de1_handle
	set ::currently_connecting_de1_handle 0

	# install readable event handler
	fileevent $::de1(device_handle) readable [list usb_channel_read_handler $::de1(device_handle)]
	fconfigure $::de1(device_handle) -mode 115200,n,8,1
	chan configure $::de1(device_handle) -translation {auto lf}
	chan configure $::de1(device_handle) -buffering line
	chan configure $::de1(device_handle) -blocking 0

	de1_connect_handler $::de1(device_handle) "$usb_path" "DE1" "usb"
}

proc usb_channel_read_handler {channel} {
	if { [catch {set inString [gets $channel]} ] || ![de1_is_connected]} {
		msg "failure during channel read - handling disconnect"
		de1_disconnect_handler
		return
	}

	# TODO(REED) maybe check for chan blocking

	if {![regexp -nocase {^\[[A-R]\]([0-9A-F][0-9A-F])+$} $inString]} {
		msg "Dropping invalid message: $inString"
		return
	}

    set serial_handle [string index $inString 1]
    set inHexStr [string range $inString 3 end]
    set inHex [binary format H* $inHexStr]

    msg [format "DE1 sent: %s %s" $serial_handle $inHexStr]

	set command_name $::de1_serial_handles_to_command_names($serial_handle)
    de1_event_handler $command_name $inHex
}


proc usb_close_de1 {} {
    catch {
		close $::de1(device_handle)
	}
	set ::de1(device_handle) 0
}

proc de1_usb {action command_name {data ""}} {

	set command_handle $::de1_command_names_to_serial_handles($command_name)
	if {$action == "read" || $action == "enable"} {
		set serial_str "<+$command_handle>\n"
		puts -nonewline $::de1(device_handle) $serial_str
	} elseif {$action == "disable"} {
		set serial_str "<-$command_handle>\n"
		puts -nonewline $::de1(device_handle) $serial_str
	} elseif {$action == "write"} {
		set data_str [binary encode hex $data]
		set serial_str "<$command_handle>$data_str\n"
		puts -nonewline $::de1(device_handle) $serial_str
	} else {
		msg "Unknown communication action: $action $command_name"
	}
	# we don't want buffering to delay sending our messages, so force flush 
	flush $::de1(device_handle)

	# we don't get an explicit ack, but we're done now
	msg "de1_comm sent: $serial_str"
	set ::de1(wrote) 0		
	return 1
}