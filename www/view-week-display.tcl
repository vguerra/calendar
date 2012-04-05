#Expects:
#  date (required but empty string okay): YYYY-MM-DD
#  show_calendar_name_p (optional): 0 or 1
#  url_stub_callback (optional): 

#Display constants, should match up with default styles in calendar.css.
set day_width 70
set width_units px
set hour_height_inside 43
set hour_height_sep 3
set hour_height_units px
set event_bump_delta 25

set time_of_day_width 70
set event_left_base 0
set day_left_base 0
set previous_intervals [list]

set adjusted_start_display_hour 9
set adjusted_end_display_hour 21

for {set i 0} {$i < 10} {incr i} {
    #defaults
    set day_width_$i $day_width
}

if {[info exists url_stub_callback]} {
    # This parameter is only set if this file is called from .LRN.
    # This way I make sure that for the time being this adp/tcl
    # snippet is backwards-compatible.
    set portlet_mode_p 1
} else {
    set portlet_mode_p 0 
}

set current_date $date

if {[info exists portlet_mode_p] && $portlet_mode_p} {
    set event_url_template "\${url_stub}cal-item-view?show_cal_nav=0&return_url=[ad_urlencode "../"]&action=edit&cal_item_id=\$item_id"
    set url_stub_callback "calendar_portlet_display::get_url_stub"
    set page_num_formvar [export_form_vars page_num]
    set page_num_urlvar "&page_num=$page_num"
} else {
    set event_url_template "cal-item-view?cal_item_id=\$item_id"
    set url_stub_callback ""
    set page_num_formvar ""
    set page_num_urlvar ""
    set base_url ""
}

if { ![info exists show_calendar_name_p] } {
    set show_calendar_name_p 1
}

if {[exists_and_not_null calendar_id_list]} {
    set calendars_clause [db_map dbqd.calendar.www.views.openacs_in_portal_calendar] 
} else {
    set calendars_clause [db_map dbqd.calendar.www.views.openacs_calendar] 
}

if {[empty_string_p $date]} {
    # Default to todays date in the users (the connection) timezone
    set server_now_time [dt_systime]
    set user_now_time [lc_time_system_to_conn $server_now_time]
    set date [lc_time_fmt $user_now_time "%x"]
}

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]

set start_date $date

# Convert date from user timezone to system timezone
#set system_start_date [lc_time_conn_to_system "$date 00:00:00"]

set first_day_of_week [lc_get firstdayofweek]
set first_us_weekday [lindex [lc_get -locale en_US day] $first_day_of_week]
set last_us_weekday [lindex [lc_get -locale en_US day] [expr [expr $first_day_of_week + 6] % 7]]

db_1row select_weekday_info {}
db_1row select_week_info {}
    
set current_weekday 0

#s/item_id/url
multirow create items \
    event_name \
    event_url \
    description \
    calendar_name \
    weekday \
    status_summary \
    start_date \
    day_of_week \
    start_date_weekday \
    start_time \
    end_time \
    no_time_p \
    add_url \
    day_url \
    style_class \
    top \
    height \
    left \
    num_attachments

# Convert date from user timezone to system timezone
set first_weekday_of_the_week_tz [lc_time_conn_to_system "$first_weekday_of_the_week 00:00:00"]
set last_weekday_of_the_week_tz [lc_time_conn_to_system "$last_weekday_of_the_week 00:00:00"]

set order_by_clause " order by to_char(start_date, 'J'), to_char(start_date,'HH24:MI')"
set interval_limitation_clause [db_map dbqd.calendar.www.views.week_interval_limitation]
set additional_limitations_clause ""
set additional_select_clause " , (to_date(start_date::text,'YYYY-MM-DD HH24:MI:SS')  - to_date(:first_weekday_of_the_week_tz,         'YYYY-MM-DD HH24:MI:SS')) as day_of_week"
if { [exists_and_not_null cal_system_type] } {
    append additional_limitations_clause " and system_type = :cal_system_type "
}

set loop_day_of_week 0
set max_bumps 0
set all_day_events 0

db_foreach dbqd.calendar.www.views.select_items {} {
    # Convert from system timezone to user timezone
    set ansi_start_date [lc_time_system_to_conn $ansi_start_date]
    set ansi_end_date [lc_time_system_to_conn $ansi_end_date]

    set start_date_weekday [lc_time_fmt $ansi_start_date "%A"]

    set start_date [lc_time_fmt $ansi_start_date "%x"]
    set end_date [lc_time_fmt $ansi_end_date "%x"]

    set start_time [lc_time_fmt $ansi_start_date "%X"]
    set end_time [lc_time_fmt $ansi_end_date "%X"]

    scan [lc_time_fmt $ansi_start_date "%H"] %d start_hour
    scan [lc_time_fmt $ansi_end_date "%H"] %d end_hour

    set ansi_this_date [dt_julian_to_ansi [expr $first_weekday_julian + $current_weekday]]

    if { $start_time eq $end_time } {
        set no_time_p t
    } else {
        set no_time_p f
    }

    # In case we need to dispatch to a different URL (ben)
    if {![empty_string_p $url_stub_callback]} {
        # Cache the stuff
        if {![info exists url_stubs($calendar_id)]} {
            set url_stubs($calendar_id) [$url_stub_callback $calendar_id]
        }
        
        set url_stub $url_stubs($calendar_id)
    }

    if { $day_of_week != $loop_day_of_week } {
        set day_width_$loop_day_of_week [expr ($day_width) + (($max_bumps+$all_day_events) * $event_bump_delta) + 5]
        set event_left_base 0
        for {set i 0} {$i < $day_of_week} {incr i} {
            incr event_left_base [set day_width_$i]
        }
        set loop_day_of_week $day_of_week
        set all_day_events 0
        set max_bumps 0
        set previous_intervals [list]
    }
    
    if { $no_time_p } {
        #All day event
        set top_hour 0
        set top_minutes 0
        set bottom_hour 24
        set bottom_minutes 0
    } else {

        set top_hour $start_hour
        set top_minutes $start_minutes
        set bottom_hour $end_hour
        set bottom_minutes $end_minutes

        if { $start_hour < $adjusted_start_display_hour && \
                 [string equal \
                      [string range $ansi_start_date 0 9] \
                      [string range $ansi_end_date 0 9]] } {
            set adjusted_start_display_hour $start_hour
        }

        if { $end_hour > $adjusted_end_display_hour && \
                 [string equal \
                      [string range $ansi_start_date 0 9] \
                      [string range $ansi_end_date 0 9]] } {
            set adjusted_end_display_hour $end_hour
        }

    }

    set top [expr ($top_hour * ($hour_height_inside+$hour_height_sep)) \
                 + ($top_minutes*$hour_height_inside/60)]
    set bottom [expr ($bottom_hour * ($hour_height_inside+$hour_height_sep)) \
                    + ($bottom_minutes*$hour_height_inside/60)]
    set height [expr $bottom - $top - 3]

    set left $event_left_base

    set start_seconds [clock scan $ansi_start_date]
    set end_seconds [clock scan $ansi_end_date]

    #Assumption: for any given day we will loop through all-day events
    #before looping through regular events.
    set bumps 0
    if { $no_time_p } {
        #All-day event.
        incr event_left_base $event_bump_delta
        incr all_day_events
    } else {
        #Regular event.
        set name "$name ($start_time - $end_time)"
        foreach {previous_start previous_end} $previous_intervals {
            if { ($start_seconds >= $previous_start && $start_seconds < $previous_end) || ($previous_start >= $start_seconds && $previous_start < $end_seconds) } {
                incr bumps
            }
        }
        if { $bumps > $max_bumps } {
            set max_bumps $bumps
        }
    }
    incr top [expr $bumps*5]
    incr left [expr $bumps*$event_bump_delta]

    multirow append items \
        "$name" \
        [subst $event_url_template] \
        $description \
        $calendar_name \
        $start_date_weekday \
        $status_summary \
        $start_date \
        $day_of_week \
        $start_date_weekday \
        $start_time \
        $end_time \
        $no_time_p \
        "?view=day&date=$ansi_start_date&page_num_urlvar" \
        "${base_url}cal-item-new?date=${ansi_this_date}&start_time=&end_time=" \
        "calendar-Item" \
        $top \
        $height \
        $left \
	$num_attachments 

    set current_weekday $day_of_week

    lappend previous_intervals $start_seconds $end_seconds

}

# Set day width for the final iteration of the loop
set day_width_$loop_day_of_week [expr ($day_width) + (($max_bumps+$all_day_events) * $event_bump_delta) + 5]

#Now correct the top attribute for the adjusted start.
#if { $adjusted_start_display_hour != 0 } 
ds_comment "testing"
set num_items [multirow size items]
for {set i 1} {$i <= $num_items } {incr i} {
    if { [multirow get items $i no_time_p] } {
	multirow set items $i height \
	    [expr ($adjusted_end_display_hour-$adjusted_start_display_hour+1)*($hour_height_inside+$hour_height_sep)]
    } elseif {$adjusted_start_display_hour != 0} {
	set currval [multirow get items $i top]
	multirow set items $i top \
	    [expr $currval - ($adjusted_start_display_hour*($hour_height_inside+$hour_height_sep))]
    }
}

# Navigation Bar
set dates "[lc_time_fmt $first_weekday_date "%q"] - [lc_time_fmt $last_weekday_date "%q"]"
if {$portlet_mode_p} {
    set previous_week_url "?$page_num_urlvar&view=week&date=[ad_urlencode [dt_julian_to_ansi [expr $first_weekday_julian - 7]]]\#calendar"
    set next_week_url "?$page_num_urlvar&view=week&date=[ad_urlencode [dt_julian_to_ansi [expr $first_weekday_julian + 7]]]\#calendar"
} else {
    set previous_week_url "?view=week&date=[ad_urlencode [dt_julian_to_ansi [expr $first_weekday_julian - 7]]]\#calendar"
    set next_week_url "?view=week&date=[ad_urlencode [dt_julian_to_ansi [expr $first_weekday_julian + 7]]]\#calendar"
}

#Calendar grid.
set grid_start $adjusted_start_display_hour
set grid_first_hour [lc_time_fmt "$current_date $grid_start:00:00" "%X"]
set grid_hour $grid_start
set grid_first_date "x"
incr grid_start

multirow create grid hour
for { set grid_hour $grid_start } { $grid_hour <= $adjusted_end_display_hour } { incr grid_hour } {
    set localized_grid_hour [lc_time_fmt "$current_date $grid_hour:00:00" "%X"]
    multirow append grid $localized_grid_hour
}
set week_start_month [lc_time_fmt $first_weekday_date "%B"]
set week_start_day [lc_time_fmt $first_weekday_date "%d"]
set week_start_year [lc_time_fmt $first_weekday_date "%Y"]
set week_end_month [lc_time_fmt $last_weekday_date "%B"]
set week_end_day [lc_time_fmt $last_weekday_date "%d"]
set week_end_year [lc_time_fmt $last_weekday_date "%Y"]

set week_days [lc_get abday]
set first_weekday_date_secs [clock scan "-24 hours" -base [clock scan "1 day" -base [clock scan $first_weekday_date]]]
set next_week [clock format [expr $first_weekday_date_secs + (7*86400)] -format "%Y-%m-%d"]
set last_week [clock format [expr $first_weekday_date_secs - (7*86400)] -format "%Y-%m-%d"]

multirow create days_of_week width day_short monthday weekday_date weekday_url day_num

set nav_url_base [ad_conn url]?[export_vars -url -entire_form -exclude {date view}]

for {set i 0} {$i < 7} {incr i} {
    set weekday_secs [expr $first_weekday_date_secs + ($i*86400)]
    set trimmed_month \
        [string trimleft [clock format $weekday_secs -format "%m"] 0]
    set trimmed_day \
        [string trimleft [clock format $weekday_secs -format "%d"] 0]
    set weekday_date [clock format $weekday_secs -format "%Y-%m-%d"]
    set weekday_url [export_vars -base [ad_conn url] -url -entire_form {{view day} {date $weekday_date}}]
    #TODO: localize_me
    set weekday_monthday "$trimmed_month/$trimmed_day"
    set i_day [expr { [expr { $i + $first_day_of_week }] % 7 }]
    multirow append days_of_week [set day_width_$i] [lindex $week_days $i_day] $weekday_monthday $weekday_date $weekday_url $i
}

set week_width $time_of_day_width
for {set i 0} {$i < 7} {incr i} {
    incr week_width [set day_width_$i]
}

if { [info exists export] && [string equal $export print] } {
    set print_html [template::adp_parse [acs_root_dir]/packages/calendar/www/view-print-display [list &items items show_calendar_name_p $show_calendar_name_p]]
    ns_return 200 text/html $print_html
    ad_script_abort
}
