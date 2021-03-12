package provide de1_shotfile 1.0

package require huddle
package require json
package require de1_profile 2.0

namespace eval ::shot {

    variable last {}
    variable new_shot_handlers {}

    namespace eval current {
        
    }

    proc init {} {
        ::register_state_change_handler Espresso Idle ::shot::create_new
    }

    proc create_new {ignored_old ignored_new} {
        if {[espresso_elapsed length] < 5 || [espresso_pressure length] < 5} {
            return
        }

        msg -INFO [namespace current] "processing new espresso shot"

        update_last

        if {$::settings(should_save_history) == 1} {
            persist
        }
    }

    proc register_new_shot_handler {handler} {
        variable new_shot_handlers
        lappend new_shot_handlers $handler
    }

    proc update_last {} {
        variable new_shot_handlers
        if {[info exists ::settings(espresso_clock)] != 1} {
            # in theory, this should never occur.
            msg -WARN "This espresso's start time was not recorded. Possibly we didn't get the bluetooth message of state change to espresso."
            set ::settings(espresso_clock) [clock seconds]
        }
        
        set clock $::settings(espresso_clock)
        set date [clock format $clock]
        set app_version [package version de1app]

        set pressure [huddle create \
            pressure [huddle list {*}[espresso_elapsed range 0 end]] \
            goal [huddle list {*}[espresso_pressure_goal range 0 end]] \
            delta [huddle list {*}[espresso_pressure_delta range 0 end]] \
            delta_negative [huddle list {*}[espresso_flow_delta_negative range 0 end]] \
        ]

        set flow [huddle create \
            flow [huddle list {*}[espresso_flow range 0 end]] \
            by_weight [huddle list {*}[espresso_flow_weight range 0 end]] \
            by_weight_raw [huddle list {*}[espresso_flow_weight_raw range 0 end]] \
            goal [huddle list {*}[espresso_flow_goal range 0 end]] \
        ]

        set temperature [huddle create \
            basket [huddle list {*}[espresso_temperature_basket range 0 end]] \
            mix [huddle list {*}[espresso_temperature_mix range 0 end]] \
            goal [huddle list {*}[espresso_temperature_goal range 0 end]] \
        ]

        set totals [huddle create \
            weight [huddle list {*}[espresso_weight range 0 end]] \
            water_dispensed [huddle list {*}[espresso_water_dispensed range 0 end]] \
        ]

        set resistance [huddle create \
            resistance [huddle list {*}[espresso_resistance range 0 end]] \
            by_weight [huddle list {*}[espresso_resistance_weight range 0 end]] \
        ]

        set app_data [huddle create \
            settings [huddle create {*}[array get ::settings]] \
            machine_state [huddle create {*}[array get ::DE1]] \
        ]

        set app_specifics [huddle create \
            app_name "DE1App" \
            app_version $app_version \
            data $app_data \
        ]

        ::profile::sync_from_legacy

        set espresso_data [huddle create \
            version 2 \
            date $date \
            timestamp $clock \
            elapsed [huddle list {*}[espresso_elapsed range 0 end]] \
            pressure $pressure \
            flow $flow \
            temperature $temperature \
            totals $totals \
            resistance $resistance \
            state_change [huddle list {*}[espresso_state_change range 0 end]] \
            profile $::profile::current \
            app $app_specifics \
        ]

        set ::shot::last $espresso_data

        foreach handler $new_shot_handlers {
            after idle after 0 eval {*}$handler
        }
    }

    proc last_clock {} {
        return [huddle get_stripped $::shot::last timestamp]
    }

    proc persist {} {
        set espresso_data [huddle jsondump $::shot::last]
        set fn "[homedir]/history_v2/[clock format [last_clock] -format "%Y%m%dT%H%M%S"].json"
        write_file $fn $espresso_data
        msg -INFO [namespace current] "Saved this espresso to history"
    }
}