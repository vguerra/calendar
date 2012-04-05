ad_page_contract {
    
    Viewing Calendar Information. Currently offers list, day, week, month view.
    
    @author Dirk Gomez (openacs@dirkgomez.de)
    @author Ben Adida (ben@openforce.net)
    @creation-date May 29, 2002
    @cvs-id $Id$
} {
    {view {[parameter::get -parameter DefaultView -default day]}}
    {date ""}
    {sort_by ""}
    {start_date ""}
    {list_of_calendar_ids:optional}
    {period_days:integer {[parameter::get -parameter ListView_DefaultPeriodDays -default 31]}}
} -validate {
    valid_date -requires { date } {
        if {![string equal $date ""]} {
            if {[catch {set date [clock format [clock scan $date] -format "%Y-%m-%d"]} err]} {
                ad_complain "Your input was not valid. It has to be in the form YYYYMMDD."
            }
        }
    }
}

set package_id [ad_conn package_id]
set user_id [ad_conn user_id]

set ad_conn_url [ad_conn url]

set export [ns_queryget export]

if {$export == "print"} {
    set view "list"
}

set return_url [ad_urlencode [ad_return_url]]
set add_item_url [export_vars -base "cal-item-new" {{return_url [ad_return_url]} view date}]

set admin_p [permission::permission_p -object_id $package_id -privilege calendar_admin]

set show_calendar_name_p [parameter::get -parameter Show_Calendar_Name_p -default 1]

set date [calendar::adjust_date -date $date]

if {$view == "list"} {
    if {[empty_string_p $start_date]} {
        set start_date $date
    }

    set ansi_list [split $start_date "- "]
    set ansi_year [lindex $ansi_list 0]
    set ansi_month [string trimleft [lindex $ansi_list 1] "0"]
    set ansi_day [string trimleft [lindex $ansi_list 2] "0"]
    set end_date [dt_julian_to_ansi [expr [dt_ansi_to_julian $ansi_year $ansi_month $ansi_day ] + $period_days]]

    if {![info exists list_of_calendar_ids]} {
    # the following query sets calendar_name and calendar_id
	set calendars [db_list_of_lists calendar_info_from_package_id "
      select calendar_id, calendar_name from calendars where
      (package_id in ([join [calendar::get_ancestor_package_ids $package_id] ,]) and private_p = 'f') or (private_p = 't' and owner_id = :user_id)"]
    } else {
	set calendar_ids [join $list_of_calendar_ids ,]
	set calendars [db_list_of_lists calendar_info "
      select calendar_id, calendar_name from calendars where
      calendar_id in ($calendar_ids)
    "]
    }
    set list_of_calendar_ids [list]
    set calendar_names [list]
   set publish_calendar read
    foreach tuple $calendars {
	foreach {calendar_id calendar_name} $tuple break
        lappend list_of_calendar_ids $calendar_id
	set create_p [ad_permission_p $calendar_id cal_item_create]
	if {$create_p && $publish_calendar eq "read"} {
           set publish_calendar $calendar_id
           lappend calendar_names "$calendar_name (c)"
	} else {
           lappend calendar_names $calendar_name
	}
    }
#    set calendar_name [join $calendar_names ", "]
     set calendar_name "[_ calendar-portlet.Download_subscribe]"
}
set calendar_personal_p [calendar::personal_p -calendar_id [lindex [lindex [calendar::calendar_list -package_id $package_id  ] 0] 1] ]

set notification_chunk [notification::display::request_widget \
                            -type calendar_notif \
                            -object_id $package_id \
                            -pretty_name [ad_conn instance_name] \
                            -url [ad_conn url] \
                           ]

# Header stuff
template::head::add_css -href "/resources/calendar/calendar.css" -media all 
template::head::add_css -alternate -href "/resources/calendar/calendar-hc.css" -title "highContrast"

ad_return_template 
