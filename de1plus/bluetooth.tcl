
package require de1_comms
package provide de1_bluetooth 1.0

## Scales
### Generics

proc scale_enable_lcd {} {
	if {$::settings(scale_type) == "atomaxskale"} {
		skale_enable_lcd
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_enable_lcd
	}
}

proc scale_disable_lcd {} {
	if {$::settings(scale_type) == "atomaxskale"} {
		skale_disable_lcd
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_disable_lcd
	}
}

proc scale_timer_start {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_timer_start
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_timer_start
	} elseif {$::settings(scale_type) == "felicita"} {
		felicita_start_timer
	}
}

proc scale_timer_stop {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_timer_stop
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_timer_stop
	} elseif {$::settings(scale_type) == "felicita"} {
		felicita_stop_timer
	}
}

proc scale_timer_off {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_timer_off
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_timer_off
	} elseif {$::settings(scale_type) == "felicita"} {
		felicita_reset_timer
	}
}

proc scale_tare {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_tare
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_tare
	} elseif {$::settings(scale_type) == "acaiascale"} {
		acaia_tare
	} elseif {$::settings(scale_type) == "felicita"} {
		felicita_tare
	} elseif {$::settings(scale_type) == "hiroiajimmy"} {
		hiroia_tare
	}
	
}

proc scale_enable_weight_notifications {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		scale_enable_weight_notifications
	} elseif {$::settings(scale_type) == "decentscale"} {
		decentscale_enable_notifications
	} elseif {$::settings(scale_type) == "acaiascale"} {
		acaia_enable_weight_notifications
	} elseif {$::settings(scale_type) == "felicita"} {
		felicita_enable_weight_notifications
	} elseif {$::settings(scale_type) == "hiroiajimmy"} {
		hiroia_enable_weight_notifications
	}
}

proc scale_enable_button_notifications {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_enable_button_notifications
	} elseif {$::settings(scale_type) == "decentscale"} {
		# nothing
	}
}

proc scale_enable_grams {} {

	if {$::settings(scale_type) == "atomaxskale"} {
		skale_enable_grams
	} elseif {$::settings(scale_type) == "decentscale"} {
		#nothing
	}
}

proc handle_new_weight_from_scale { sensorweight scale_refresh_rate } {

	if { $::settings(scale_stop_at_half_shot) == 1} {
		set sensorweight [expr $sensorweight * 2]
	}

	if {$sensorweight < 0 && $::de1_num_state($::de1(state)) == "Idle"} {

		if {$::settings(tare_only_on_espresso_start) != 1} {

			# one second after the negative weights have stopped, automatically do a tare
			if {[info exists ::scheduled_scale_tare_id] == 1} {
				after cancel $::scheduled_scale_tare_id
			}
			set ::scheduled_scale_tare_id [after 1000 scale_tare]
		}
	}

	set multiplier1 0.95
	if {$::de1(scale_weight) == ""} {
		set ::de1(scale_weight) 0
	}
	set diff 0
	set diff [expr {abs($::de1(scale_weight) - $sensorweight)}]
	

	#if {$::de1_num_state($::de1(state)) == "Idle"} 
	if {$::de1_num_state($::de1(state)) == "Espresso" && ($::de1(substate) == $::de1_substate_types_reversed(pouring) || $::de1(substate) == $::de1_substate_types_reversed(preinfusion)) } {
		# john 5/11/18 hard set this to 5% weighting, until we're sure these other methods work well.
		set multiplier1 0.95
		#if {$diff > 10} {
			#set multiplier1 0.90
		#}
	} else {
		# no smoothing when the machine is idle or not pouring/preinfusion 
		set multiplier1 0
	}

		#set multiplier1 0.9

	#msg "sensorweight: $sensorweight / diff:$diff / multiplier1:$multiplier1"

	#set multiplier1 0

	set multiplier2 [expr {1.0 - $multiplier1}];
	set thisweight [expr {($::de1(scale_weight) * $multiplier1) + ($sensorweight * $multiplier2)}]


	# a much less smoothed, more raw weight, with lower latency
	set multiplier1r 0.5
	set multiplier2r [expr {1.0 - $multiplier1r}];
	set thisrawweight [expr {1.0 * ($::de1(scale_sensor_weight) * $multiplier1r) + ($sensorweight * $multiplier2r)}]

	if {$diff != 0} {
		#msg "Diff: [round_to_two_digits $diff] - mult: [round_to_two_digits $multiplier1] - wt [round_to_two_digits $thisweight] - sen [round_to_two_digits $sensorweight]"
	}

	# 10hz refresh rate on weight means should 10x the weight change to get a change-per-second
	set flow [expr { 1.0 * $scale_refresh_rate * ($thisweight - $::de1(scale_weight)) }]
	set flow_raw [expr { 1.0 * $scale_refresh_rate * ($thisrawweight - $::de1(scale_sensor_weight)) }]

	#set flow [expr {($::de1(scale_weight_rate) * $multiplier1) + ($tempflow * $multiplier2)}]
	if {$flow < 0} {
		set flow 0
	}

	set ::de1(scale_weight_rate) [round_to_two_digits $flow]
	set ::de1(scale_weight_rate_raw) [round_to_two_digits $flow_raw]
	
	set ::de1(scale_weight) [round_to_two_digits $thisweight]
	set ::de1(scale_sensor_weight) [round_to_two_digits $thisrawweight]
	#msg "weight received: $thisweight : flow: $flow"


	# (beta) stop shot-at-weight feature
	if {$::de1_num_state($::de1(state)) == "Espresso" && ($::de1(substate) == $::de1_substate_types_reversed(pouring) || $::de1(substate) == $::de1_substate_types_reversed(preinfusion) || $::de1(substate) == $::de1_substate_types_reversed(ending)) } {
		
		if {$::de1(scale_sensor_weight) > $::de1(final_water_weight)} {
			set ::de1(final_water_weight) $thisweight
			set ::settings(drink_weight) [round_to_one_digits $::de1(final_water_weight)]
		}

		# john 1/18/19 support added for advanced shots stopping on weight, just like other shots
		# john improve 5/2/19 with a separate (much higher value) weight option for advanced shots
		set target_shot_weight $::settings(final_desired_shot_weight)
		if {$::settings(settings_profile_type) == "settings_2c"} {
			set target_shot_weight $::settings(final_desired_shot_weight_advanced)
		}

		if {$target_shot_weight != "" && $target_shot_weight > 0} {

			# damian found:
			# > after you hit the stop button, the remaining liquid that will end up in the cup is equal to about 2.6 seconds of the current flow rate, minus a 0.4 g adjustment
			set lag_time_calibration [expr {$::de1(scale_weight_rate) * $::settings(stop_weight_before_seconds) }]
			#msg "lag_time_calibration: $lag_time_calibration | target_shot_weight: $target_shot_weight | thisweight: $thisweight | scale_autostop_triggered: $::de1(scale_autostop_triggered) | timer: [espresso_timer]"

			if {$::de1(scale_autostop_triggered) == 0 && [round_to_one_digits $thisweight] > [round_to_one_digits [expr {$target_shot_weight - $lag_time_calibration}]]} {	

				if {[espresso_timer] < 5} {
					# bad idea to tare during preinfusion, problem is there might not be a puck, so we remove the first 5 seconds of weight by doing this.
					# scale_tare 
				} else {
					msg "Weight based Espresso stop was triggered at ${thisweight}g > ${target_shot_weight}g "
					start_idle
					say [translate {Stop}] $::settings(sound_button_in)
					borg toast [translate "Espresso weight reached"]


					# immediately set the DE1 state as if it were idle so that we don't repeatedly ask the DE1 to stop as we still get weight increases. There might be a slight delay between asking the DE1 to stop and it stopping.
					set ::de1(scale_autostop_triggered) 1

					# let a few seconds elapse after the shot stop command was given and keep updating the final shot weight number
					for {set t 0} {$t < [expr {1000 * $::settings(seconds_after_espresso_stop_to_continue_weighing)}]} { set t [expr {$t + 1000}]} {
						after $t after_shot_weight_hit_update_final_weight
					}
					}
			}
		}
	} elseif { ( $::de1_num_state($::de1(state)) == "Espresso" || $::de1_num_state($::de1(state)) == "HotWater" ) && ( $::de1(substate) == $::de1_substate_types_reversed(heating) || $::de1(substate) == $::de1_substate_types_reversed(stabilising) || $::de1(substate) == $::de1_substate_types_reversed(final heating) )} {
		if {$::de1(scale_weight) > 10} {
			# if a cup was added during the warmup stage, about to make an espresso, then tare automatically
			scale_tare
		}
	} elseif { $::de1_num_state($::de1(state)) == "HotWater" && ($::de1(substate) == $::de1_substate_types_reversed(pouring) || $::de1(substate) == $::de1_substate_types_reversed(preinfusion) || $::de1(substate) == $::de1_substate_types_reversed(ending)) } {
		# "hot water: stop on weight" feature. Works with the scale, so it's more accurate.
		# lets assume clean, filtered delicious water actually has a density of 1

		# ignore first few seconds of pour as it can generate a lot of noise on the scale and trigger a false stop
		if {[water_pour_timer] > 2.5 && $::settings(water_stop_on_scale) == 1} {
			set water_offset_calibration  1.0
			set target_water_weight [expr {$::settings(water_volume) - $water_offset_calibration}]
			set current_calibrated_water_weight [round_to_one_digits $target_water_weight ]
			set current_water_weight [round_to_one_digits $thisweight]

			msg "target_water_weight = $target_water_weight, current_weight = $current_water_weight current_calibrated_water_weight = $current_calibrated_water_weight"
			if {$::de1(scale_autostop_triggered) == 0 \
				&&  $current_water_weight > $current_calibrated_water_weight } {
					msg "Weight based Hot Water stop was triggered at ${thisweight}g > ${target_water_weight}g "
					start_idle
					say [translate {Stop}] $::settings(sound_button_in)
					borg toast [translate "Water weight reached"]
					set ::de1(scale_autostop_triggered) 1
					#load_settings
			}
		}
	}
}

#### Atomax Skale
proc skale_timer_start {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot start timer"
		return
	}

	set timeron [binary decode hex "DD"]
	userdata_append "Skale : timer start" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $timeron] 0

}

proc skale_enable_button_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot enable button notifications"
		return
	}


	userdata_append "enable Skale button notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF82) $::cinstance($::de1(cuuid_skale_EF82))] 1
}


proc skale_enable_grams {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set grams [binary decode hex "03"]

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot enable grams"
		return
	}

	userdata_append "Skale : enable grams" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $grams] 1
}

proc skale_enable_lcd {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set screenon [binary decode hex "ED"]
	set displayweight [binary decode hex "EC"]

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot enable LCD"
		return
	}

	userdata_append "Skale : enable LCD" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $screenon] 0
	userdata_append "Skale : display weight on LCD" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $displayweight] 0

}

proc skale_disable_lcd {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set screenoff [binary decode hex "EE"]

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot disable LCD"
		return
	}

	userdata_append "Skale : disable LCD" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $screenoff] 0
}

proc skale_timer_stop {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set tare [binary decode hex "D1"]

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot stop timer"
		return
	}

	userdata_append "Skale: timer stop" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $tare] 0
}

proc skale_timer_off {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set tare [binary decode hex "D0"]

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot off timer"
		return
	}

	userdata_append "Skale: timer off" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $tare] 0
}

proc skale_tare {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}
	set tare [binary decode hex "10"]
	set ::de1(scale_weight) 0
	set ::de1(scale_weight_rate_raw) 0

	# if this was a scheduled tare, indicate that the tare has completed
	unset -nocomplain ::scheduled_scale_tare_id

	#set ::de1(final_espresso_weight) 0

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot tare"
		return
	}

	userdata_append "Skale: tare" [list ble write $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $tare] 0
}

proc skale_enable_weight_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "atomaxskale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_skale))] == ""} {
		msg "Skale not connected, cannot enable weight notifications"
		return
	}

	userdata_append "enable Skale weight notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_skale) $::sinstance($::de1(suuid_skale)) $::de1(cuuid_skale_EF81) $::cinstance($::de1(cuuid_skale_EF81))] 1
}


#### Felicita
proc felicita_enable_weight_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "felicita"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_felicita))] == ""} {
		error "Felicita Scale not connected, cannot enable weight notifications"
		return
	}

	userdata_append "enable felicita scale weight notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_felicita) $::sinstance($::de1(suuid_felicita)) $::de1(cuuid_felicita) $::cinstance($::de1(cuuid_felicita))] 1
}

proc felicita_tare {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "felicita"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_felicita))] == ""} {
		error "Felicita Scale not connected, cannot send tare cmd"
		return
	}

	set tare [binary decode hex "54"]

	userdata_append "felicita tare" [list ble write $::de1(scale_device_handle) $::de1(suuid_felicita) $::sinstance($::de1(suuid_felicita)) $::de1(cuuid_felicita) $::cinstance($::de1(cuuid_felicita)) $tare] 0
	# The tare is not yet confirmed to us, we can therefore assume it worked out
	set ::de1(scale_autostop_triggered) 0
}

proc felicita_reset_timer {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "felicita"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_felicita))] == ""} {
		error "Felicita Scale not connected, cannot send timer cmd"
		return
	}

	set tare [binary decode hex "43"]

	userdata_append "felicita timer reset" [list ble write $::de1(scale_device_handle) $::de1(suuid_felicita) $::sinstance($::de1(suuid_felicita)) $::de1(cuuid_felicita) $::cinstance($::de1(cuuid_felicita)) $tare] 0
}
proc felicita_start_timer {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "felicita"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_felicita))] == ""} {
		error "Felicita Scale not connected, cannot send timer cmd"
		return
	}

	set tare [binary decode hex "52"]

	userdata_append "felicita timer start" [list ble write $::de1(scale_device_handle) $::de1(suuid_felicita) $::sinstance($::de1(suuid_felicita)) $::de1(cuuid_felicita) $::cinstance($::de1(cuuid_felicita)) $tare] 0
}
proc felicita_stop_timer {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "felicita"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_felicita))] == ""} {
		error "Felicita Scale not connected, cannot send timer cmd"
		return
	}

	set tare [binary decode hex "53"]

	userdata_append "felicita timer stop" [list ble write $::de1(scale_device_handle) $::de1(suuid_felicita) $::sinstance($::de1(suuid_felicita)) $::de1(cuuid_felicita) $::cinstance($::de1(cuuid_felicita)) $tare] 0
}

proc felicita_parse_response { value } {
	if {[string bytelength $value] >= 9} {
		binary scan $value cucua1a6 h1 h2 sign weight
		if {[info exists weight] && $h1 == 1 && $h2 == 2 } {
			set weight [ scan $weight %d ]
			if {$weight == ""} { return }
			if {$sign == "-"} {
				set weight [expr $weight * -1]
			}
			handle_new_weight_from_scale [expr $weight / 100.0] 10
		}
	}
}


#### Hiroia Jimmy
proc hiroia_enable_weight_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "hiroiajimmy"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_hiroiajimmy))] == ""} {
		error "Hiroia Jimmy Scale not connected, cannot enable weight notifications"
		return
	}

	userdata_append "enable hiroiajimmy scale weight notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_hiroiajimmy) $::sinstance($::de1(suuid_hiroiajimmy)) $::de1(cuuid_hiroiajimmy_status) $::cinstance($::de1(cuuid_hiroiajimmy_status))] 1
}

proc hiroia_tare {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "hiroiajimmy"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_hiroiajimmy))] == ""} {
		error "Hiroia Jimmy Scale not connected, cannot send tare cmd"
		return
	}

	set tare [binary decode hex "0700"]

	userdata_append "hiroiajimmy tare" [list ble write $::de1(scale_device_handle) $::de1(suuid_hiroiajimmy) $::sinstance($::de1(suuid_hiroiajimmy)) $::de1(cuuid_hiroiajimmy_cmd) $::cinstance($::de1(cuuid_hiroiajimmy_cmd)) $tare] 0
	# The tare is not yet confirmed to us, we can therefore assume it worked out
	set ::de1(scale_autostop_triggered) 0
}

proc hiroia_parse_response { value } {
	if {[string bytelength $value] >= 7} {
		append value [binary decode hex 00]
		binary scan $value cucucucui h1 h2 h3 h4 weight

		if {[info exists weight]} {
			if {$weight >= 8388608} {
				set weight [expr (0xFFFFFF - $weight) * -1]
			}
			handle_new_weight_from_scale [expr $weight / 10.0] 10
		} else {
			error "weight non exist"
		}
	}
}


#### Acaia
set ::acaia_command_buffer ""

proc acaia_encode {msgType payload} {

	set HEADER1 [binary decode hex "EF"];
	set HEADER2 [binary decode hex "DD"];
	set TYPE [binary decode hex $msgType];

	# TODO calculate checksum instead of hardcofig it
	set data "$HEADER1${HEADER2}${TYPE}[binary decode hex $payload]"
	return $data
}

proc acaia_tare {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "acaiascale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_acaia_ips))] == ""} {
		error "Acaia Scale not connected, cannot send tare cmd"
		return
	}

	set tare [acaia_encode 04  0000000000000000000000000000000000]

	userdata_append "send acaia tare" [list ble write $::de1(scale_device_handle) $::de1(suuid_acaia_ips) $::sinstance($::de1(suuid_acaia_ips)) $::de1(cuuid_acaia_ips_age) $::cinstance($::de1(cuuid_acaia_ips_age)) $tare] 1

	# The tare is not yet confirmed to us, we can therefore assume it worked out
	set ::de1(scale_autostop_triggered) 0
}

proc acaia_send_heartbeat {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "acaiascale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_acaia_ips))] == ""} {
		error "Acaia Scale not connected, cannot send heartbeat"
		return
	}
	set heartbeat [acaia_encode 00 02000200]

	userdata_append "send acaia heartbeat" [list ble write $::de1(scale_device_handle) $::de1(suuid_acaia_ips) $::sinstance($::de1(suuid_acaia_ips)) $::de1(cuuid_acaia_ips_age) $::cinstance($::de1(cuuid_acaia_ips_age)) $heartbeat] 1

	if { $::settings(force_acaia_heartbeat) == 1 } {
		after 3000 acaia_send_heartbeat
	}
}

proc acaia_send_ident {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "acaiascale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_acaia_ips))] == ""} {
		error "Acaia Scale not connected, cannot send app ident"
		return
	}

	set ident [acaia_encode 0B 3031323334353637383930313233349A6D]

	userdata_append "send acaia ident" [list ble write $::de1(scale_device_handle) $::de1(suuid_acaia_ips) $::sinstance($::de1(suuid_acaia_ips)) $::de1(cuuid_acaia_ips_age) $::cinstance($::de1(cuuid_acaia_ips_age)) $ident] 1
}

proc acaia_send_config {} {

	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "acaiascale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_acaia_ips))] == ""} {
		error "Acaia Scale not connected, cannot send app config"
		return
	}

	set ident [acaia_encode 0C 0900010102020503041506]


	userdata_append "send acaia comfig" [list ble write $::de1(scale_device_handle) $::de1(suuid_acaia_ips) $::sinstance($::de1(suuid_acaia_ips)) $::de1(cuuid_acaia_ips_age) $::cinstance($::de1(cuuid_acaia_ips_age)) $ident] 1

}


proc acaia_enable_weight_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "acaiascale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_acaia_ips))] == ""} {
		error "Acaia Scale not connected, cannot enable weight notifications"
		return
	}

	userdata_append "enable acaia scale weight notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_acaia_ips) $::sinstance($::de1(suuid_acaia_ips)) $::de1(cuuid_acaia_ips_age) $::cinstance($::de1(cuuid_acaia_ips_age))] 1
}

proc acaia_parse_response { value } {

	append ::acaia_command_buffer $value

	if {[string bytelength $::acaia_command_buffer] > 4} {
		# 0xEF
		set HEADER1 239
		# 0xDD
		set HEADER2 221

		binary scan $::acaia_command_buffer cucucucucuicucu \
			h1 h2 msgtype len event_type weight unit neg
		if { [info exists h1] && [info exists h2] && [info exists len]} {
			if { ($h1 == $HEADER1) && ($h2 == $HEADER2) \
				&& [info exists neg] \
				&& $msgtype == 12 && $event_type == 5 } {
				# we have valid data, extract it
				set calulated_weight [expr {$weight / pow(10.0, $unit)}]
				set is_negative [expr {$neg > 1.0}]
				if {$is_negative} {
					set calulated_weight [expr {$calulated_weight * -1.0}]
				}
				set sensorweight $calulated_weight
				handle_new_weight_from_scale $sensorweight 10
			}
			if { [string bytelength $::acaia_command_buffer] >= $len } {
				set ::acaia_command_buffer ""
			}
		}
	}
}

#### Decent Scale


# cmdtype is either 0x0A for LED (cmddata 00=off, 01=on), or 0x0F for tare (cmdata = incremented char counter for each TARE use)
proc decent_scale_calc_xor {cmdtype cmdddata} {
	set xor [format %02X [expr {0x03 ^ $cmdtype ^ $cmdddata ^ 0x00 ^ 0x00 ^ 0x00}]]
	msg "decent_scale_calc_xor for '$cmdtype' '$cmdddata' is '$xor'"
	return $xor
}

proc decent_scale_calc_xor4 {cmdtype cmdddata1 cmdddata2} {
	set xor [format %02X [expr {0x03 ^ $cmdtype ^ $cmdddata1 ^ $cmdddata2 ^ 0x00 ^ 0x00}]]
	msg "decent_scale_calc_xor4 for '$cmdtype' '$cmdddata1' '$cmdddata2' is '$xor'"
	return $xor
}

proc decent_scale_make_command {cmdtype cmdddata {cmddata2 {}} } {
	msg "decent_scale_make_command $cmdtype $cmdddata $cmddata2"
	if {$cmddata2 == ""} {
		msg "1 part decent scale command"
		set hex [subst {03${cmdtype}${cmdddata}000000[decent_scale_calc_xor "0x$cmdtype" "0x$cmdddata"]}]
		#set hex2 [subst {03${cmdtype}${cmdddata}000000[decent_scale_calc_xor4 "0x$cmdtype" "0x$cmdddata" "0x00"]}]
		#msg "compare hex '$hex' to '$hex2'"
	} else {
		msg "2 part decent scale command"
		set hex [subst {03${cmdtype}${cmdddata}${cmddata2}0000[decent_scale_calc_xor4 "0x$cmdtype" "0x$cmdddata" "0x$cmddata2"]}]
	}
	msg "hex is '$hex' for '$cmdtype' '$cmdddata' '$cmddata2'"
	return [binary decode hex $hex]
}

proc tare_counter_incr {} {
	if {[info exists ::decent_scale_tare_counter] != 1} {
		set ::decent_scale_tare_counter 253
	} elseif {$::decent_scale_tare_counter >= 255} {
		set ::decent_scale_tare_counter 0
	} else {
		incr ::decent_scale_tare_counter
	}
}

proc decent_scale_tare_cmd {} {
	tare_counter_incr
	set cmd [decent_scale_make_command "0F" [format %02X $::decent_scale_tare_counter]]
	return $cmd
}

proc decentscale_enable_notifications {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "decentscale"} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decent scale not connected, cannot enable weight notifications"
		return
	}

	userdata_append "enable decent scale weight notifications" [list ble enable $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_read) $::cinstance($::de1(cuuid_decentscale_read))] 1
}

proc decentscale_enable_lcd {} {
	if {$::de1(scale_device_handle) == 0} {
		return
	}
	set screenon [decent_scale_make_command 0A 01 01]
	msg "decent scale screen on: '[convert_string_to_hex $screenon]' '$screenon'"
	userdata_append "decentscale : enable LCD" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $screenon] 0
}

proc decentscale_disable_lcd {} {
	if {$::de1(scale_device_handle) == 0} {
		return
	}
	set screenoff [decent_scale_make_command 0A 00 00]

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decentscale not connected, cannot disable LCD"
		return
	}

	userdata_append "decentscale : disable LCD" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $screenoff] 0
}

proc decentscale_timer_start {} {
	if {$::de1(scale_device_handle) == 0} {
		msg "decentscale_timer_start - no scale_device_handle"
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decentscale not connected, cannot start timer"
		return
	}

	set timerreset [decent_scale_make_command 0B 02 00]
	msg "decent scale timer reset: '$timerreset'"
	userdata_append "decentscale : timer reset" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $timerreset]

	msg "decentscale_timer_start"
	set timeron [decent_scale_make_command 0B 03 00]
	msg "decent scale timer on: [convert_string_to_hex $timeron] '$timeron'"
	userdata_append "decentscale : timer on" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $timeron] 0

}

proc decentscale_timer_stop {} {

	if {$::de1(scale_device_handle) == 0} {
		return
	}
	set tare [binary decode hex "D1"]

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decentscale not connected, cannot stop timer"
		return
	}

	msg "decentscale_timer_stop"

	set timeroff [decent_scale_make_command 0B 00 00]
	msg "decent scale timer stop: '$timeroff'"
	userdata_append "decentscale : timer off" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $timeroff] 0

	# cmd not yet implemented
	#userdata_append "decentscale: timer stop" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_skale_EF80) $::cinstance($::de1(cuuid_skale_EF80)) $tare]
}

proc decentscale_timer_off {} {

	if {$::de1(scale_device_handle) == 0} {
		return
	}

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decentscale not connected, cannot off timer"
		return
	}


	set timeroff [decent_scale_make_command 0B 02 00]
	msg "decent scale timer off: '$timeroff'"
	userdata_append "decentscale : timer off" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $timeroff] 0
}

proc decentscale_tare {} {
	if {$::de1(scale_device_handle) == 0 || $::settings(scale_type) != "decentscale"} {
		return
	}
	set tare [binary decode hex "10"]
	set ::de1(scale_weight) 0
	set ::de1(scale_weight_rate) 0
	set ::de1(scale_weight_rate_raw) 0

	# if this was a scheduled tare, indicate that the tare has completed
	unset -nocomplain ::scheduled_scale_tare_id

	if {[ifexists ::sinstance($::de1(suuid_decentscale))] == ""} {
		msg "decent scale not connected, cannot tare"
		return
	}

	set tare [decent_scale_tare_cmd]

	userdata_append "decentscale : tare" [list ble write $::de1(scale_device_handle) $::de1(suuid_decentscale) $::sinstance($::de1(suuid_decentscale)) $::de1(cuuid_decentscale_write) $::cinstance($::de1(cuuid_decentscale_write)) $tare] 0
}

proc close_all_ble_and_exit {} {
	msg "close_all_ble_and_exit"
	if {$::scanning  == 1} {
		catch {
			ble stop $::ble_scanner
		}
	}

	msg "Closing de1"
	if {$::de1(device_handle) != 0} {
		catch {
			ble close $::de1(device_handle)
		}
	}

	msg "Closing scale"
	if {$::de1(scale_device_handle) != 0} {
		catch {
			ble close $::de1(scale_device_handle)
		}
	}


	catch {
		if {$::settings(ble_unpair_at_exit) == 1} {
			#ble unpair $::de1(de1_address)
			#ble unpair $::settings(bluetooth_address)
		}
	}

	#after 2000 exit
	exit 0
}

proc app_exit {} {

	tcl_introspection
	close_log_file

	if {$::android != 1} {
		close_all_ble_and_exit
	}

	# john 1/15/2020 this is a bit of a hack to work around a firmware bug in 7C24F200 that has the fan turn on during sleep, if the fan threshold is set > 0
	set_fan_temperature_threshold 0

	set ::exit_app_on_sleep 1
	start_sleep

	# fail-over, if the DE1 doesn't to to sleep
	set since_last_ping [expr {[clock seconds] - $::de1(last_ping)}]
	if {$since_last_ping > 10} {
		# wait less time for the fail-over if we don't have any temperature pings from the DE1
		after 1000 close_all_ble_and_exit
	} else {
		after 5000 close_all_ble_and_exit
	}

	after 5000 { .can itemconfigure $::message_button_label -text [translate "Quit"] }


	after 10000 "exit 0"
}





proc de1_read_hotwater {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read de1 hot water/steam" [list de1_ble read "ShotSettings"] 1
}

proc de1_read_shot_header {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot header" [list de1_ble read "HeaderWrite"] 1
}
proc de1_read_shot_frame {} {
	#if {$::de1(device_handle) == "0"} {
	#	msg "error: de1 not connected"
	#	return
	#}

	userdata_append "read shot frame" [list de1_ble read "FrameWrite"] 1
}

proc remove_null_terminator {instr} {
	set pos [string first "\x00" $instr]
	if {$pos == -1} {
		return $instr
	}

	incr pos -1
	return [string range $instr 0 $pos]
}

proc android_8_or_newer {} {

	if {$::android != 1} {
		msg "android_8_or_newer reports: not android (0)"
		return 0
	}

	catch {
		set x [borg osbuildinfo]
		#msg "osbuildinfo: '$x'"
		array set androidprops $x
		msg [array get androidprops]
		msg "Android release reported: '$androidprops(version.release)'"
	}
	set test 0
	catch {
		# john note: Android 7 behaves like 8
		set test [expr {$androidprops(version.release) >= 7}]
	}
	#msg "Is this Android 8 or newer? '$test'"
	return $test

	#msg "android_8_or_newer failed and reports: 0"
	#return 0
}


set ::ble_scanner {}
catch  {
	# this will fail if this package has been loaded before "proc android_specific_stubs {}" has been run
	set ::ble_scanner [ble scanner de1_ble_handler]
}
set ::scanning -1

proc check_if_initial_connect_didnt_happen_quickly {} {
	msg "check_if_initial_connect_didnt_happen_quickly"
	# on initial startup, if a direct connection to DE1 doesn't work quickly, start a scan instead
	set ble_scan_started 0
	if {$::de1(device_handle) == 0 } {
		#msg "check_if_initial_connect_didnt_happen_quickly ::de1(device_handle) == 0"
		catch {
			ble close $::currently_connecting_de1_handle
		}
		catch {
			set ::currently_connecting_de1_handle 0
		}
		set ble_scan_started 1
	} else {
		msg "DE1 device handle is $::de1(device_handle)"
	}

	if {$::settings(scale_bluetooth_address) != "" && $::de1(scale_device_handle) == 0} {
		msg "on initial startup, if a direct connection to scale doesn't work quickly, start a scan instead"
		catch {
			ble close $::currently_connecting_scale_handle
		}
		catch {
			set ::currently_connecting_scale_handle 0
		}
		set ble_scan_started 1
	}


	if {$ble_scan_started == 1} {
		scanning_restart
	}


}


set ::currently_connecting_de1_handle 0
proc ble_connect_to_de1 {} {
	msg "ble_connect_to_de1"
	#return

	if {$::android != 1} {
		msg "simulated DE1 connection"
		set ::de1(connect_time) [clock seconds]
		set ::de1(last_ping) [clock seconds]

		msg "Connected to fake DE1"
		set ::de1(device_handle) 1

		set do_mmr_binary_test 0
		if {$do_mmr_binary_test == 1} {
			# example binary string containing binary version string
			set version_value "\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51\x02\x04\x00\xA4\x0A\x6E\xD0\x68\x51"
			set ::de1(version) [array get arr2]
			set v [de1_version_string]

			set mmr_test "\x0C\x80\x00\x08\x14\x05\x00\x00\x03\x00\x00\x00\x71\x04\x00\x00\x00\x00\x00\x00"
			msg [array get arr3]

			#set mmr_test "\x0C\x80\x00\x08\x14\x05\x00\x00\x03\x00\x00\x00\x71\x04\x00\x00\x00\x00\x00\x00"
			parse_binary_mmr_read_int $mmr_test arr4
			msg [array get arr4]

			msg "MMRead: CPU board model: '[ifexists arr4(Data0)]'"
			msg "MMRead: machine model:  '[ifexists arr4(Data1)]'"
			msg "MMRead: firmware version number: '[ifexists arr4(Data2)]'"

			set ::settings(cpu_board_model) [ifexists arr4(Data0)]
			set ::settings(machine_model) [ifexists arr4(Data1)]
			set ::settings(firmware_version_number) [ifexists arr4(Data2)]
		}

		return
	}

	if {$::settings(bluetooth_address) == "" || $::settings(connectivity) != "ble" } {
		# if no bluetooth address set, then don't try to connect
		return ""
	}

	set ::de1(connect_time) 0
	set ::de1(scanning) 0

	if {$::de1(device_handle) != "0"} {
		catch {
			msg "disconnecting from DE1"
			ble close $::de1(device_handle)
			set ::de1(device_handle) "0"
			after 1000 comms_connect_to_de1
		}
		catch {
			#ble unpair $::settings(bluetooth_address)
		}
	}
	set ::de1(device_handle) 0

	set ::de1_name "DE1"
	if {[catch {
		set ::currently_connecting_de1_handle [ble connect [string toupper $::settings(bluetooth_address)] de1_ble_handler false]
		msg "Connecting to DE1 on $::settings(bluetooth_address)"
		set retcode 1
	} err] != 0} {
		if {$err == "unsupported"} {
			after 5000 [list info_page [translate "Bluetooth is not on"] [translate "Ok"]]
		}
		msg "Failed to start to BLE connect to DE1 because: '$err'"
		set retcode 0
	}
	return $retcode


	#msg "Failed to start to BLE connect to DE1 for some reason"
	#return 0

}

set ::currently_connecting_scale_handle 0
proc ble_connect_to_scale {} {

	if {$::de1(scale_device_handle) != 0} {
		msg "Already connected to scale, don't try again"
		return
	}

	#if {[ifexists ::currently_connecting_de1_handle] != 0} {
		#msg "Currently connecting to DE1, don't try to connect to the scale right now"
		#return
	#}


	if {[ifexists ::de1(in_fw_update_mode)] == 1} {
		msg "in_fw_update_mode : ble_connect_to_scale"
		return
	}


	if {$::settings(scale_bluetooth_address) == ""} {
		msg "No Scale BLE address in settings, so not connecting to it"
		return
	}

	if {$::currently_connecting_scale_handle != 0} {
		msg "Already trying to connect to Scale, so don't try again"
		return
	}

	set do_this 0
	if {$do_this == 1} {
		if {$::de1(scale_device_handle) != "0"} {
			msg "Scale already connected, so disconnecting before reconnecting to it"
			#return
			catch {
				#ble close $::de1(scale_device_handle)
			}

			catch {
				set ::de1(scale_device_handle) 0
				set ::de1(cmdstack) {};
				set ::currently_connecting_scale_handle 0
				after 1000 ble_connect_to_scale
				# when the scale disconnect message occurs, this proc will get re-run and a connection attempt will be made
				return
			}

		}
	}

	if {[catch {
		set ::currently_connecting_scale_handle [ble connect [string toupper $::settings(scale_bluetooth_address)] de1_ble_handler false]
		msg "Connecting to scale on $::settings(scale_bluetooth_address)"
		set retcode 0
	} err] != 0} {
		set ::currently_connecting_scale_handle 0
		set retcode 1
		msg "Failed to start to BLE connect to scale because: '$err'"
	}
	return $retcode

}

proc append_to_scale_bluetooth_list {address name type} {
	#msg "Sca $address"

	set ::scale_types($address) $type

	foreach { entry } $::scale_bluetooth_list {
		if { [dict get $entry address] eq $address} {
			return
		}
	}

	if { $name == "" } {
		set name $type
	}

	set newlist $::scale_bluetooth_list
	lappend newlist [dict create address $address name $name type $type]

	msg "Scan found Skale or Decent Scale: $address ($type)"
	set ::scale_bluetooth_list $newlist
	catch {
		fill_ble_scale_listbox
	}
}

# mmr_read used
proc later_new_de1_connection_setup {} {
	# less important stuff, also some of it is dependent on BLE version

	if {[ifexists ::de1(in_fw_update_mode)] == 1} {
		msg "in_fw_update_mode : later_new_de1_connection_setup skipped"
		return
	}


	msg "later_new_de1_connection_setup"
	de1_enable_mmr_notifications


	de1_enable_state_notifications
	get_ghc_is_installed
	de1_send_shot_frames
	set_fan_temperature_threshold $::settings(fan_threshold)
	de1_send_steam_hotwater_settings
	de1_send_waterlevel_settings
	get_3_mmr_cpuboard_machinemodel_firmwareversion
	de1_enable_water_level_notifications
	de1_enable_state_notifications
	de1_enable_temp_notifications

	set_heater_tweaks
		#

	#get_heater_tweaks
	#get_heater_voltage


	#if {$::settings(heater_voltage) == ""} {
	#}


	after 5000 read_de1_state
	after 7000 get_heater_voltage
	after 9000 de1_enable_temp_notifications
	after 11000 de1_enable_state_notifications

}

proc de1_ble {action command_name {data ""}} {

	if {[ifexists ::sinstance($::de1(suuid))] == ""} {
			msg "DE1 not connected, cannot send BLE command $command_name"
			return
	}

	eval set current_cuuid $::de1_command_names_to_cuuids($command_name)
	if {$action == "read" || $action == "enable" || $action == "disable"} {
		return [ble $action $::de1(device_handle) $::de1(suuid) $::sinstance($::de1(suuid)) $current_cuuid $::cinstance($current_cuuid)]
	} elseif {$action == "write"} {
		return [ble $action $::de1(device_handle) $::de1(suuid) $::sinstance($::de1(suuid)) $current_cuuid $::cinstance($current_cuuid) $data]
	} else {
		error "Unknown communication action: $action $command_name"
		return 0
	}
}

proc de1_ble_handler { event data } {
	#msg "de1 ble_handler '$event' [convert_string_to_hex $data]"
	#set ::de1(wrote) 0

	set ::settings(ble_debug) 0
	if {$::settings(ble_debug) == 1} {
		msg "ble event: $event $data"
	}

	set previous_wrote 0
	set previous_wrote [ifexists ::de1(wrote)]
	#set ::de1(wrote) 0

	#set ::de1(last_ping) [clock seconds]

	dict with data {

		if {[ifexists state] != "scanning"} {
			#msg "de1b ble_handler $event $data"
		} else {
			#msg "scanning $event $data"
		}

		switch -- $event {
			msg "-- device '$name' found at address $address"
			scan {
				#msg "-- device $name found at address $address ($data)"
				if {[string first DE1 $name] != -1} {
					append_to_de1_list $address $name "ble"
					if {$address == $::settings(bluetooth_address)} {
						if {$::currently_connecting_de1_handle == 0} {
							msg "Not currently connecting to DE1, so trying now"
							comms_connect_to_de1
						}
					}
				} elseif {[string first Skale $name] != -1} {
					append_to_scale_bluetooth_list $address $name "atomaxskale"

					if {$address == $::settings(scale_bluetooth_address)} {
						if {$::currently_connecting_scale_handle == 0} {
							msg "Not currently connecting to scale, so trying now"
							ble_connect_to_scale
						}
					}

				} elseif {[string first "Decent Scale" $name] != -1} {
					append_to_scale_bluetooth_list $address $name "decentscale"

					if {$address == $::settings(scale_bluetooth_address)} {
						if {$::currently_connecting_scale_handle == 0} {
							msg "Not currently connecting to scale, so trying now"
							ble_connect_to_scale
						}
					}
				} elseif {[string first "FELICITA" $name] != -1} {
					append_to_scale_bluetooth_list $address $name "felicita"

					if {$address == $::settings(scale_bluetooth_address)} {
						if {$::currently_connecting_scale_handle == 0} {
							msg "Not currently connecting to scale, so trying now"
							ble_connect_to_scale
						}
					}
 				} elseif {[string first "HIROIA JIMMY" $name] != -1} {
					append_to_scale_bluetooth_list $address $name "hiroiajimmy"

					if {$address == $::settings(scale_bluetooth_address)} {
						if {$::currently_connecting_scale_handle == 0} {
							msg "Not currently connecting to scale, so trying now"
							ble_connect_to_scale
						}
					}
 				} elseif {[string first "ACAIA" $name] != -1 \
 					|| [string first "LUNAR" $name]    != -1 \
 					|| [string first "PROCH" $name]    != -1 } {

					if { [string first "PROCH" $name] != -1 } {
						set ::settings(force_acaia_heartbeat) 1
					}
 					append_to_scale_bluetooth_list $address $name "acaiascale"

					if {$address == $::settings(scale_bluetooth_address)} {
						if {$::currently_connecting_scale_handle == 0} {
							msg "Not currently connecting to scale, so trying now"
							ble_connect_to_scale
						}
					}
				} else {
					#msg "-- device $name found at address $address ($data)"
				}
			}
			connection {
				if {$state eq "disconnected"} {
					if {$address == $::settings(bluetooth_address)} {
						# fall back to scanning

						de1_disconnect_handler $handle

					} elseif {$address == $::settings(scale_bluetooth_address)} {

					#set ::de1(scale_type) ""

						set ::de1(wrote) 0
						msg "$::settings(scale_type) disconnected $data"
						#catch {
							ble close $handle
						#}

						# if the skale connection closed in the currentl one, then reset it
						if {$handle == $::de1(scale_device_handle)} {
							set ::de1(scale_device_handle) 0
						}

						if {$::currently_connecting_scale_handle == 0} {
							#ble_connect_to_scale
						}

						catch {
							ble close $::currently_connecting_scale_handle
						}

						set ::currently_connecting_scale_handle 0

						# john 1-11-19 automatic reconnection attempts eventually kill the bluetooth stack on android 5.1
						# john might want to make this happen automatically on Android 8, though. For now, it's a setting, which might
						# eventually get auto-set as per the current Android version, if we can trust that to give us a reliable BLE stack.
						if {$::settings(automatically_ble_reconnect_forever_to_scale) == 1} {
							ble_connect_to_scale
						}

					}
				} elseif {$state eq "scanning"} {
					set ::scanning 1
					msg "scanning"
				} elseif {$state eq "idle"} {
					#ble stop $::ble_scanner
					if {$::scanning > 0} {

						if {$::de1(device_handle) == 0 && $::currently_connecting_de1_handle == 0} {
							comms_connect_to_de1
						}
					}
					set ::scanning 0
				} elseif {$state eq "discovery"} {
					#msg "discovery"
				} elseif {$state eq "connected"} {

					if {$::de1(device_handle) == 0 && $address == $::settings(bluetooth_address)} {
						msg "de1 connected $event $data"


						de1_connect_handler $handle $address "DE1" "ble"

						if {$::de1(scale_device_handle) != 0} {
							# if we're connected to both the scale and the DE1, stop scanning (or if there is not scale to connect to and we're connected to the de1)
							stop_scanner
						}


					} elseif {$::de1(scale_device_handle) == 0 && $address == $::settings(scale_bluetooth_address)} {
						#append_to_scale_bluetooth_list $address [ifexists ::scale_types($address)]
						#append_to_scale_bluetooth_list $address $::settings(scale_type)

						set ::de1(wrote) 0
						set ::de1(scale_device_handle) $handle

						# resend the hotwater settings, because now we can stop on weight
						after 7000 de1_send_steam_hotwater_settings

						msg "scale '$::settings(scale_type)' connected $::de1(scale_device_handle) $handle - $event $data"
						if {$::settings(scale_type) == ""} {
							msg "blank scale type found, reset to atomaxskale"
							set ::settings(scale_type) "atomaxskale"
						}

						#set ::de1(scale_type) [ifexists ::scale_types($address)]
						if {$::settings(scale_type) == "decentscale"} {
							append_to_scale_bluetooth_list $address $::settings(scale_bluetooth_name) "decentscale"
							#after 500 decentscale_enable_lcd
							decentscale_tare
							
							after 1000 decentscale_enable_lcd
							#after 2000 decentscale_timer_start
							after 3000 decentscale_enable_notifications
							#after 4000 decentscale_timer_stop
							#after 5000 decentscale_timer_off

						} elseif {$::settings(scale_type) == "atomaxskale"} {
							append_to_scale_bluetooth_list $address $::settings(scale_bluetooth_name) "atomaxskale"
							#set ::de1(scale_type) "atomaxskale"
							skale_enable_lcd
							after 1000 skale_enable_weight_notifications
							after 2000 skale_enable_button_notifications
							after 3000 skale_enable_lcd
						} elseif {$::settings(scale_type) == "felicita"} {
							append_to_scale_bluetooth_list $address $::settings(scale_bluetooth_name) "felicita"
							after 2000 felicita_enable_weight_notifications
						} elseif {$::settings(scale_type) == "hiroiajimmy"} {
							append_to_scale_bluetooth_list $address $::settings(scale_bluetooth_name) "hiroiajimmy"
							after 200 hiroia_enable_weight_notifications
						} elseif {$::settings(scale_type) == "acaiascale"} {
							append_to_scale_bluetooth_list $address $::settings(scale_bluetooth_name) "acaiascale"
							acaia_send_ident
							after 500 acaia_send_config
							after 1000 acaia_enable_weight_notifications
							after 4000 acaia_send_heartbeat
						} else {
							error "unknown scale: '$::settings(scale_type)'"
						}
						set ::currently_connecting_scale_handle 0

						if {$::de1(device_handle) != 0} {
							# if we're connected to both the scale and the DE1, stop scanning
							stop_scanner
						}


					} else {
						msg "doubled connection notification from $address, already connected with $address"
						#ble close $handle
					}


				} else {
					msg "unknown connection msg: $data"
				}
			}
			transaction {
				msg "ble transaction result $event $data"
			}

			characteristic {
				#.t insert end "${event}: ${data}\n"
				#if {[string first A001 $data] != -1} {
					#msg "de1 characteristic $state: ${event}: ${data}"
				#}
				#if {[string first 83 $data] != -1} {
				#	msg "de1 characteristic $state: ${event}: ${data}"
				#}
				#msg "characteristic $state: ${event}: ${data}"
				#msg "connected to de1 with $handle "
				if {$state eq "discovery"} {
					# save the mapping because we now need it for Android 7
					set ::cinstance($cuuid) $cinstance
					set ::sinstance($suuid) $sinstance
				} elseif {$state eq "connected"} {

					if {$access eq "r" || $access eq "c"} {
						#msg "rc: $data"
						if {$access eq "r"} {
							set ::de1(wrote) 0
							run_next_userdata_cmd
						}
							#set ::de1(wrote) 0
							#run_next_userdata_cmd

						#msg "Received from DE1: '[remove_null_terminator $value]'"
						# change notification or read request
						#de1_ble_new_value $cuuid $value
						# change notification or read request
						#de1_ble_new_value $cuuid $value
						if {$suuid eq $::de1(suuid) \
							&& [info exists ::de1_cuuids_to_command_names($cuuid)]} {
							eval set command_name $::de1_cuuids_to_command_names($cuuid)
							de1_event_handler $command_name [dict get $data value]
							return
						} elseif {$cuuid eq $::de1(cuuid_decentscale_writeback)} {
							# decent scale
							parse_decent_scale_recv $value vals
							#msg "decentscale: '[array get vals]'"

							#set sensorweight [expr {$t1 / 10.0}]

						} elseif {$cuuid eq $::de1(cuuid_skale_EF81)} {
							# Atomax scale
							binary scan $value cus1cu t0 t1 t2 t3 t4 t5
							set sensorweight [expr {$t1 / 10.0}]
							handle_new_weight_from_scale $sensorweight 10

						} elseif {$cuuid eq $::de1(cuuid_decentscale_read)} {
							# decent scale
							parse_decent_scale_recv $value weightarray

							if {[ifexists weightarray(command)] == [expr 0x0F] && [ifexists weightarray(data6)] == [expr 0xFE]} {
								# tare cmd success is a msg back to us with the tare in 'command', and a byte6 of 0xFE
								msg "- decent scale: tare confirmed"

								set ::de1(scale_weight) 0

								# after a tare, we can now use the autostop mechanism
								set ::de1(scale_autostop_triggered) 0

								return
							} elseif {[ifexists weightarray(command)] == 0xAA} {									
								msg "Decentscale BUTTON $weightarray(data3) pressed"
								if {[ifexists $weightarray(data3)] == 1} {
									# button 1 "O" pressed
									decentscale_tare
								} elseif {[ifexists $weightarray(data3)] == 2} {
									# button 2 "[]" pressed
								}
							} elseif {[ifexists weightarray(command)] != ""} {
								msg "scale command received: [array get weightarray]"

							}

							if {[info exists weightarray(weight)] == 1} {
								set sensorweight [expr {$weightarray(weight) / 10.0}]
								#msg "decent scale: ${sensorweight}g [array get weightarray] '[convert_string_to_hex $value]'"
								#msg "decentscale recv read: '[convert_string_to_hex $value]'"
								handle_new_weight_from_scale $sensorweight 10
							} else {
								msg "decent scale recv: [array get weightarray]"
							}
						} elseif {$cuuid eq $::de1(cuuid_acaia_ips_age)} {
							# acaia scale
							acaia_parse_response $value
						} elseif {$cuuid eq $::de1(cuuid_felicita)} {
							# felicita scale
							felicita_parse_response $value
						} elseif {$cuuid eq $::de1(cuuid_hiroiajimmy_status)} {
							# hiroia jimmy scale
							hiroia_parse_response $value
						} elseif {$cuuid eq $::de1(cuuid_skale_EF82)} {
							set t0 {}
							#set t1 {}
							binary scan $value cucucucucucu t0 t1
							msg "- Skale button pressed: $t0 : DE1 state: $::de1(state) = $::de1_num_state($::de1(state)) "

							if {$t0 == 1} {
								scale_tare
							} elseif {$t0 == 2} {
								if {$::settings(scale_button_starts_espresso) == 1} {
									 if {$::de1_num_state($::de1(state)) == "Espresso"} {
										say [translate {Stop}] $::settings(sound_button_in)
										start_idle
									} else {
										say [translate {Espresso}] $::settings(sound_button_in)
										start_espresso
									}
								}
							}

						} else {
							msg "Confirmed unknown read from DE1 $cuuid: '$value'"
						}

						#set ::de1(wrote) 0

					} elseif {$access eq "w"} {
						set ::de1(wrote) 0
						run_next_userdata_cmd

						if {$cuuid eq $::de1(cuuid_05)} {
							# MMR read
							#msg "MMR read: '[convert_string_to_hex $value]'"

							msg "MMR recv write-back: '[convert_string_to_hex $value]'"

						} elseif {$cuuid eq $::de1(cuuid_10)} {
							parse_binary_shotframe $value arr3
							msg "Confirmed shot frame written to DE1: '$value' : [array get arr3]"
						} elseif {$cuuid eq $::de1(cuuid_11)} {
							parse_binary_water_level $value arr2
							msg "water level write confirmed [string length $value] bytes: $value  : [array get arr2]"
						} elseif {$cuuid eq $::de1(cuuid_decentscale_writeback)} {
							#parse_binary_water_level $value arr2
							msg "scale write confirmed [string length $value] bytes: $value"
						} elseif {$cuuid eq $::de1(cuuid_skale_EF80)} {
							set tare [binary decode hex "10"]
							set grams [binary decode hex "03"]
							set screenon [binary decode hex "ED"]
							set displayweight [binary decode hex "EC"]
							if {$value == $tare } {
								msg "- Skale: tare confirmed"

								# after a tare, we can now use the autostop mechanism
								set ::de1(scale_autostop_triggered) 0
								set ::de1(scale_weight) 0

							} elseif {$value == $grams } {
								msg "- Skale: grams confirmed"
							} elseif {$value == $screenon } {
								msg "- Skale: screen on confirmed"
							} elseif {$value == $displayweight } {
								msg "- Skale: display weight confirmed"
							} else {
								msg "- Skale write received: $value vs '$tare'"
							}
						} else {
							if {$address == $::settings(bluetooth_address)} {
								if {$cuuid eq $::de1(cuuid_02)} {
									parse_state_change $value arr
									msg "Confirmed state change written to DE1: '[array get arr]'"
								} elseif {$cuuid eq $::de1(cuuid_06)} {
									if {$::de1(currently_erasing_firmware) == 1 && $::de1(currently_updating_firmware) == 0} {
										# erase ack received
										#set ::de1(currently_erasing_firmware) 0
										msg "firmware erase write ack recved: [string length $value] bytes: $value : [array get arr2]"
									} elseif {$::de1(currently_erasing_firmware) == 0 && $::de1(currently_updating_firmware) == 1} {

										msg "firmware write ack recved: [string length $value] bytes: $value : [array get arr2]"
										firmware_upload_next
									} else {
										msg "MMR write ack: [string length $value] bytes: [convert_string_to_hex $value ] : $value : [array get arr2]"
									}
								} elseif {$cuuid eq $::de1(cuuid_09) && $::de1(currently_erasing_firmware) == 1} {
									msg "fw request to erase sent"
									#msg "fw request to erase sent, now starting send"
									#write_firmware_now
								} else {
									msg "Confirmed wrote to $cuuid of DE1: '$value'"
								}
							} elseif {$address == $::settings(scale_bluetooth_address)} {
								msg "Confirmed wrote to $cuuid of $::settings(scale_type): '$value'"
							} else {
								msg "Confirmed wrote to $cuuid of unknown device: '$value'"
							}
						}

						#set ::de1(wrote) 0

						# change notification or read request
						#de1_ble_new_value $cuuid $value

					} else {
						msg "weird characteristic received: $data"
					}

					#run_next_userdata_cmd
					#run_next_userdata_cmd
				}
			}
			service {
				msg "de1 service $event $data"
				#if {$suuid == "0000180A-0000-1000-8000-00805F9B34FB"} {
				#	set ::scale_types($address) "atomaxskale"
				#	msg "atomaxskale FOUND $suuid"
				#} elseif {$suuid == "83CDC3D4-3BA2-13FC-CC5E-106C351A9352"} {
				#	set ::scale_types($address) "decentscale"
				#	msg "decentscale FOUND $suuid"
				#}

			}
			descriptor {
				#msg "de1 descriptor $state: ${event}: ${data}"
				if {$state eq "connected"} {

					if {$access eq "w"} {
						if {$cuuid eq $::de1(cuuid_0D)} {
							msg "Confirmed: BLE temperature notifications: $data"
						} elseif {$cuuid eq $::de1(cuuid_0E)} {
							msg "Confirmed: BLE state change notifications"
						} elseif {$cuuid eq $::de1(cuuid_12)} {
							msg "Confirmed: BLE calibration notifications"
						} elseif {$cuuid eq $::de1(cuuid_05)} {
							msg "Confirmed: BLE MMR write: [convert_string_to_hex $data]"
						} elseif {$cuuid eq $::de1(cuuid_11)} {
							msg "Confirmed: water level write: $data"
						} else {
							msg "DESCRIPTOR UNKNOWN WRITE confirmed: $data"
						}

						set ::de1(wrote) 0
						run_next_userdata_cmd
					} else {
						msg "de1 unknown descriptor $state: ${event}: ${data}"
					}

					set run_this 0

					if {$run_this == 1} {
						#set cmds [lindex [ble userdata $handle] 0]
						set lst [ble userdata $handle]
						set cmds [unshift lst]
						ble userdata $handle $lst
						msg "$cmds"
						if {$cmds ne {}} {
							set cmd [lindex $cmds 0]
							set cmds [lrange $cmds 1 end]
							{*}[lindex $cmd 1]
							ble userdata $handle $cmds
						}
					}
				} else {
					#msg "de1 descriptor $event $data"
				}

			}

			default {
				msg "ble unknown callback $event $data"
			}
		}
	}

	#run_next_userdata_cmd

	#msg "exited event"
}

proc calibration_ble_received {value} {

	#calibration_ble_received $value
	parse_binary_calibration $value arr2
	#msg "calibration data received [string length $value] bytes: $value  : [array get arr2]"

	set varname ""
	if {[ifexists arr2(CalTarget)] == 0} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_flow"
		} else {
			set varname	"calibration_flow"
		}
	} elseif {[ifexists arr2(CalTarget)] == 1} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_pressure"
		} else {
			set varname	"calibration_pressure"
		}
	} elseif {[ifexists arr2(CalTarget)] == 2} {
		if {[ifexists arr2(CalCommand)] == 3} {
			set varname	"factory_calibration_temperature"
		} else {
			set varname	"calibration_temperature"
		}
	}

	if {$varname != ""} {
		# this BLE characteristic receives packets both for notifications of reads and writes, but also the real current value of the calibration setting
		if {[ifexists arr2(WriteKey)] == 0} {
			msg "$varname value received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2]"
			set ::de1($varname) $arr2(MeasuredVal)
		} else {
			msg "$varname NACK received [string length $value] bytes: [convert_string_to_hex $value] $value : [array get arr2] "
		}
	} else {
		msg "unknown calibration data received [string length $value] bytes: $value  : [array get arr2]"
	}

}

proc enable_de1_reconnect {} {
	msg "enable_de1_reconnect"
	set ::de1(disable_de1_reconnect) 1
	comms_connect_to_de1
}

proc disable_de1_reconnect {} {
	msg "disable_de1_reconnect"
	set ::de1(disable_de1_reconnect) 1
}

proc after_shot_weight_hit_update_final_weight {} {

	if {$::de1(scale_sensor_weight) > $::de1(final_water_weight)} {
		# if the current scale weight is more than the final weight we have on record, then update the final weight
		set ::de1(final_water_weight) $::de1(scale_sensor_weight)
		set ::settings(drink_weight) [round_to_one_digits $::de1(final_water_weight)]
	}

}

proc fast_write_open {fn parms} {
	set f [open $fn $parms]
	fconfigure $f -blocking 0
	fconfigure $f -buffersize 1000000
	return $f
}


proc scanning_state_text {} {
	if {$::scanning == 1} {
		return [translate "Searching"]
	}

	if {$::currently_connecting_de1_handle != 0} {
		return [translate "Connecting"]
	}

	if {[expr {$::de1(connect_time) + 5}] > [clock seconds]} {
		return [translate "Connected"]
	}

	#return [translate "Tap to select"]
	if {[ifexists ::de1_needs_to_be_selected] == 1 || [ifexists ::scale_needs_to_be_selected] == 1} {
		return [translate "Tap to select"]
	}

	return [translate "Search"]
}

proc scanning_restart {} {
	if {$::scanning == 1} {
		return
	}
	if {$::android != 1} {

		# insert enough dummy devices to overfill the list, to test whether scroll bars are working
		set ::de1_device_list [list [dict create address "12:32:16:18:90" name "ble3" type "ble"] [dict create address "10.1.1.20" name "wifi1" type "wifi"] [dict create address "12:32:56:78:91" name "dummy_ble2" type "ble"] [dict create address "12:32:56:78:92" name "dummy_ble3" type "ble"] [dict create address "ttyS0" name "dummy_usb" type "usb"] [dict create address "192.168.0.1" name "dummy_wifi2" type "wifi"]]
		set ::scale_bluetooth_list [list [dict create address "51:32:56:78:90" name "ACAIAxxx" type "ble"] [dict create address "92:32:56:78:90" name "Skale2" type "ble"] [dict create address "12:32:56:78:92" name "ACAIA2xxx" type "ble"] [dict create address "12:32:56:78:93" name "Skale2b" type "ble"] ]

		set ::scale_types(12:32:56:78:90) "decentscale"
		set ::scale_types(32:56:78:90:12) "decentscale"
		set ::scale_types(56:78:90:12:32) "atomaxskale"

		after 200 fill_ble_scale_listbox
		after 400 fill_ble_listbox

		set ::scanning 1
		after 3000 { set scanning 0 }
		return
	} else {
		# only scan for a few seconds
		after 10000 { stop_scanner }
	}

	set ::scanning 1
	ble start $::ble_scanner
}
