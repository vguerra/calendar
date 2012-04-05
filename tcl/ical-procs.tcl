# 
# Gebrauchsanwleitung: 
# - auf "My Calendar", "List" Ansicht, am Ende der Liste: url zum Subskribierten/Dowload vom Kalender
# - URL bspw: http://localhost:8241/ical/2273/dotlrn.ics?user_id=601&calendar_id_list=2273%202500%203278%202273
# - URL von MyLearn enthält Hauptkalender (hier 2273) und Liste der Kalender (bei Communities oft nur 1 Kalender) 
# - Guter Startpunkt "CalDAV instproc GET" (GET request vom WebDav / CalDAV)
# Testen: 
#   - Listing im Browser: an url "&plain=1" anhängen (ändert content-type auf plain/text)
#   - Thunderbird/Lightning: 
#      * New Calendar -> On the Network -> iCalender (ICS): URL von dotlrn eintragen
#      * Es gibt dort nun auch CalDAV als Option (vermutlich zum Testen gut geeignet)

ad_library {
    Utility functions for syncing Calendar with ical
    
    @author neumann@wu-wien.ac.at
    @creation-date April, 2012
}

::xotcl::Object ::calendar::ical -ad_doc {
  The Object ::calendar::ical provides the methods for 
  importing and exporting single or multiple calendar items
  in the ical format (see rfc 2445). Currently only the part
  of ical is implemented, which is used by the mozilla
  calendar (sunbird, or the xul-file for thunderbird or 
  firefox).

  @author Gustaf Neumann
  @cvs-id $Id:$
}
# 
# xql handling: use the specified xql file
#
::calendar::ical set xql dbqd.calendar.tcl.ical
::calendar::ical proc sql name {
  return [my set xql].$name
}

#
# The class CalItem is used for keeping calendar items
#
Class ::calendar::ical::CalItem -parameter {
  {title ""}
  {uid ""}
  {dtstamp ""}
  {dtstart ""}
  {dtend ""}
  {duration 0}
  {r_error 0}
  {description ""}
  {recurrence_options}
  {recurrence_id}
  {calendar_name}
  {last-modified}
}  -ad_doc {
  The Class ::calendar::ical:CalItem provides means for creating 
  in-memory calendar items. It is used for example to provide the
  contents of an ical-file in an easy accessible manner.

  @author Gustaf Neumann
}

::calendar::ical::CalItem ad_instproc -private set_time {
  name date time utc
} {
  Convert specified date and time and set the appropriate instance
  variable.
} {
  set clock [::xo::ical date_time_to_clock $date $time $utc]
  my $name [::xo::ical clock_to_oacstime $clock]
}

::calendar::ical::CalItem ad_instproc -private get_opaque {} {
  Return the attribute/value pairs of the stored opaque values
  if the ical entry.
} {
  set values [list]
  foreach var [::calendar::ical set opaque_tags] {
    if {[my exists $var]} {
      lappend values $var [my set $var]
    }
  }
  return $values
}

::calendar::ical::CalItem ad_instproc update {
  {-import:boolean false}
  {-create_calendar_id}
  {-create_cal_item_permission_p:boolean true}
  {-write_calendar_ids}
  {-item_type_id}
} {
  This method inserts or updates a calendar item. If there
  is already a cal_item for this uid, we perform an update on the
  original calendar. If it does not exists, we perform an insert
  in the specified calendar (create_calendar_id)
  @param import when import is set, the updated will be performed; otherwise only a check
  @param create_calendar_id place where new calendar items are added to
  @param create_cal_item_permission_p do we have the permission the create calendar items
  @param write_calendar_ids calendar_ids, to which we can write (e.g. update entry)
  @param item_type_id optional type_id for added items
} {
  my instvar r_status cal_item_id action
  my instvar uid title
  if {[my r_error]} {
    set r_status "INVALID"
  } elseif { [my exists recurrence_options] } { 
    set r_status [my recurrence_options]
  } else {
    set r_status "NO"
  }

  set cal_item_list [list]
  set cal_item_calendar_id 0
  db_foreach [calendar::ical sql cal_item_ids_from_uid] {} {
    lappend cal_item_list $cal_item_id
    set cal_item_calendar_id $calendar_id
  }
  set cal_item_id [lindex $cal_item_list 0]
  #my log "lookup returned '$cal_item_id' for $uid, $cal_item_calendar_id, create_calendar_id = $create_calendar_id"

  set ignore [expr {$title eq ""}]
  if {!$ignore} {
    set ignore [expr {$import && $cal_item_id eq "" 
	      && !$create_cal_item_permission_p}]
  }
  if {!$ignore} {
    set ignore [expr {$import && $cal_item_id ne "" 
	      && [lsearch -exact $write_calendar_ids $calendar_id] == -1}]
  }

  ## we are inserting the oacs calendar name into the title on display;
  ## therefore we have to remove this here again
  regsub -all {\(.*\)} $title "" title
  set title [string trimright $title]

  set action ""
  if {$ignore} {
    set action "ignore"
  } elseif {$import && $cal_item_id eq ""} {
    set cal_item_id [calendar::item::new \
			 -start_date [my dtstart] \
			 -end_date [my dtend] \
			 -name $title \
			 -description [my description] \
			 -calendar_id $create_calendar_id \
			 -cal_uid $uid \
			 -ical_vars [my get_opaque] \
  			 -item_type_id $item_type_id]
    if { [my exists recurrence_options] } {
      # Set up the recurrence
      eval calendar::item::add_recurrence -cal_item_id $cal_item_id \
	  [my recurrence_options]
    }
    set action created
  } elseif {$import && $cal_item_id ne ""} {
    # edit_all_p updates the recurrence only partly! should be fixed
    if {[my exists last-modified]} {
      acs_object::get -object_id $cal_item_id -array object_props
      set oacs_stamp [::xo::ical clock_to_utc [clock scan $object_props(last_modified_ansi)]]
      if {$oacs_stamp > [my last-modified]} {
	my log "+++ ical: last-modified no modification, ignoring update of $uid"
	set action ignore
	return
      }
    } else {
      # no last-modified field. the mozialla semantics seems to be
      # that this means, the entry is not modified.
      #my log "+++ ical: no last-modified for $uid"
      set action ignore
      return
    }
    calendar::item::edit \
	-cal_item_id $cal_item_id \
	-start_date [my dtstart] \
	-end_date [my dtend] \
	-name $title \
	-description [my description] \
	-calendar_id $cal_item_calendar_id \
	-edit_all_p 1 \
	-ical_vars [my get_opaque] \
	-cal_uid $uid \
	-item_type_id $item_type_id
    set action updated
  } elseif {$cal_item_id eq ""} {
    set action new
  } else {
    set action update
  }
}

::calendar::ical ad_proc -private header {cal_name} {
  Return the header of the ical file.
} {
  return "BEGIN:VCALENDAR\r\nX-WR-CALNAME:$cal_name\r\nPRODID:-//OpenACS//OpenACS 6.0 MIMEDIR//EN\r\nVERSION:2.0\r\nMETHOD:PUBLISH\r\n"
}
::calendar::ical ad_proc footer {} {
  Return the footer of the ical file.
} {
  return "END:VCALENDAR\r\n"
}
::calendar::ical ad_proc format_recurrence { 
  {-recurrence_id:required}
} {
  Return the recurrence specification in form of an ical RRULE.
  @param recurrence_id is the unique id of the recurrence item.
} {
  if {$recurrence_id eq ""} {return ""}

  set recur_rule "RRULE:FREQ="
  db_1row [my sql select_recurrence] {} -column_array recurrence

  switch -glob $recurrence(interval_name) {
    day      { append recur_rule "DAILY" }
    week     { append recur_rule "WEEKLY" }
    *month*  { append recur_rule "MONTHLY"}
    year     { append recur_rule "YEARLY"}
  }

  if { $recurrence(interval_name) eq "week" && 
       ![empty_string_p $recurrence(days_of_week)] } {
    #DRB: Standard indicates ordinal week days are OK, but Outlook
    #only takes two-letter abbreviation form.
    
    set week_list [list "SU" "MO" "TU" "WE" "TH" "FR" "SA" "SU"]
    set rec_list [list]
    foreach day [split $recurrence(days_of_week) " "] {
      append rec_list [lindex $week_list $day]
    }
    append recur_rule ";BYDAY=" [join $rec_list ,]
  }

  if {$recurrence(every_nth_interval) ne ""} {
    append recur_rule ";INTERVAL=$recurrence(every_nth_interval)"
  }
    
  if {$recurrence(recur_until) ne ""} {
    set stamp [string range $recurrence(recur_until) 0 18]
    append recur_rule ";UNTIL=" [::xo::ical clock_to_utc [clock scan $stamp]]
  }
  return "$recur_rule\r\n"
}

::calendar::ical ad_proc delete_calendar_items { 
  {-calendar_ids}
  {-item_type_id}
  {-start_date}
  uids
} {
  Delete the activities of an calendar from a the
  current point in time (or the specified time).
  @param calendar_ids is the list of calendar from which acvities are deleted
  @param delete only activities of the given item type **NOT DONE*
  @param uids is the list of uids which schould no be deleted
} {
  if {![info exists start_date]} {
    set start_date [::xo::ical clock_to_oacstime [expr {[clock seconds] - (60*60*24)}]]
  }
  db_foreach  check_delete_cal_items "
             select cal_uid, name
             from cal_items, cal_uids, 
             acs_events e join timespans s on (e.timespan_id = s.timespan_id)
             join time_intervals t on (s.interval_id = t.interval_id)
             where on_which_calendar in ([join $calendar_ids ,])
             and e.event_id = cal_item_id 
             and activity_id = on_which_activity 
             and start_date > :start_date
             and cal_uid not in ([join $uids ,])
          " {
	    my log "ICAL DELETE $cal_uid, $name"
	  }
     db_dml put_delete_cal_items "
         delete from acs_activities where activity_id in (
           select activity_id from cal_items, cal_uids, 
           acs_events e join timespans s on (e.timespan_id = s.timespan_id)
           join time_intervals t on (s.interval_id = t.interval_id)
           where on_which_calendar in ([join $calendar_ids ,])
           and e.event_id = cal_item_id 
           and activity_id = on_which_activity 
           and start_date > :start_date
           and cal_uid not in ([join $uids ,])
        )"
}

::calendar::ical ad_proc calendar_ids_with_permissions {
  {-user_id} 
  {-permission cal_item_write} 
  calendar_id_list
} {
  Determine the subset of the calendar_ids where the specified
  user has the specified rights
} {
  set ids [join $calendar_id_list ", "]
  return [db_list select_calendars_with_permissions "
    select calendar_id from calendars 
    where acs_permission__permission_p(calendar_id, :user_id, :permission)='t'
    and calendar_id in ($ids);
  "]
}

::calendar::ical ad_proc format_calendar { 
  {-with_recurrences_p:boolean true}
  {-cal_name "oacs"}
  {-package_id}
  {-user_id}
  {-period_days}
  {-calendar_id_list}
  {-item_type_id ""}
  {-full_calendar_id 0}
} {
  This method returns an ical file for the entries of the specified 
  calendars.

  @param cal_name ist the calendar name as it appears in an (external) 
    ical browser
  @param user_id the user_id used for permission checking and potentially to determine the calendar
  @param period_days the number of days for which the calendar is generated
  @param calendar_id_list list of calendar ids which should be (partly) downloaded
  @param full_calendar_id id of the calendar, which should be completely downloaded

} {

  set sort_by start_date

  # this is currently probably not the best solution: when the full_calendar_id
  # is specified, the intention is that the main calendar is completely 
  # returned (ical accesses the calendar via webdav). It would be sufficient
  # when only the main calendar is downloaded completely
  set full_calendar [expr {$full_calendar_id != 0}]

  set start_date [ns_fmttime [ns_time] "%Y-%m-%d 00:00"]
  set end_date [ns_fmttime [expr {[ns_time] + 60*60*24*$period_days}] "%Y-%m-%d 00:00"]
  set interval_limitation_clause [db_map dbqd.calendar.www.views.list_interval_limitation]

  if {$full_calendar} {
    set interval_limitation_clause "(($interval_limitation_clause) or ci.on_which_calendar = :full_calendar_id)"
  } 
  
  if {[exists_and_not_null calendar_id_list]} {
    set calendars_clause [db_map dbqd.calendar.www.views.openacs_in_portal_calendar] 
  } else {
    set calendars_clause [db_map dbqd.calendar.www.views.openacs_calendar] 
  }

  set order_by_clause " order by $sort_by"
  set additional_limitations_clause ""
  
  set additional_select_clause \
	", recurrence_id
         , coalesce(e.description, a.description) as description
	 , coalesce(e.activity_id, a.activity_id) as activity_id "

  if {$item_type_id ne ""} {
    append additional_select_clause ", ci.item_type_id = $item_type_id"
  }

  set ics [my header $cal_name]
  #
  # We could rewrite the "standard" query from oacs such we do not
  # need inefficient nested sql loops (we could handle creation and 
  # modification date as well as recurrences in one sql query)

#     select   to_char(start_date, 'YYYY-MM-DD HH24:MI:SS') as ansi_start_date,
#              to_char(end_date, 'YYYY-MM-DD HH24:MI:SS') as ansi_end_date,
#              to_number(to_char(start_date,'HH24'),'90') as start_hour,
#              to_number(to_char(end_date,'HH24'),'90') as end_hour,
#              to_number(to_char(end_date,'MI'),'90') as end_minutes,
#              coalesce(e.name, a.name) as name,
#              coalesce(e.status_summary, a.status_summary) as status_summary,
#              e.event_id as item_id,
#              cit.type as item_type,
#              cals.calendar_id,
#              cals.calendar_name
#              $additional_select_clause
#     from     acs_activities a,
#              acs_events e,
#              timespans s,
#              time_intervals t,
#              calendars cals,
#              cal_items ci left join
#              cal_item_types cit on cit.item_type_id = ci.item_type_id
#     where    e.timespan_id = s.timespan_id
#     and      s.interval_id = t.interval_id
#     and      e.activity_id = a.activity_id
#     and      $interval_limitation_clause
#     and      ci.cal_item_id= e.event_id
#     and      cals.calendar_id = ci.on_which_calendar
#     and      e.event_id = ci.cal_item_id
#     $additional_limitations_clause
#     $calendars_clause
#     $order_by_clause


  db_foreach dbqd.calendar.www.views.select_items {} {
    # Timezonize
    set ansi_start_date [lc_time_system_to_conn $ansi_start_date]
    set ansi_end_date   [lc_time_system_to_conn $ansi_end_date]

    # Replace message key with actual string if necessary
    if {[regexp {\#(.+)\#} $calendar_name _ key]} {
      set calendar_name [_ $key]
    }

    # Provide default for certain ical variables, which might also be
    # overwritten by the calendar application, which are not part of
    # the OpenACS calendar data model. These and some additional variables
    # are kept in the ical_vars of the cal_uids table.
    array set ICAL_VARS {
      CLASS PUBLIC 
      TRANSP OPAQUE 
      LOCATION "Not Listed" 
      SEQUENCE 0 
      PRIORITY 5
    }
    set ICAL_VARS(summary) "$name ($calendar_name)"
    set ICAL_VARS(description) $description

    # Obtain creation_date and last_modified since this is not
    # included in the main query. On the longer range, it should go
    # there. 
    acs_object::get -object_id $item_id -array prop
    
    # Create VEVENT with main date entries
    set vevent [::xo::ical::VEVENT new -destroy_on_cleanup \
		    -creation_date $prop(creation_date_ansi) \
		    -last_modified $prop(last_modified_ansi) \
		    -dtstart $ansi_start_date \
		    -is_day_item [dt_no_time_p -start_time $ansi_start_date -end_time $ansi_end_date] \
		    -formatted_recurrences [my format_recurrence -recurrence_id $recurrence_id] \
		    -dtend $ansi_end_date]

    if {[info exists done(a-$activity_id)]} {
      $vevent destroy
      continue
    } else {
      set done(a-$activity_id) 1
    }

    # Get the unique id and the opaque ical vars from the db
    if {[db_0or1row [my sql cal_uid_from_activity_id] {
      select cal_uid, ical_vars from cal_uids 
      where on_which_activity = :activity_id
    } ]} {
      # Pass the opaque vars to the predefined vars, maybe overwrite
      # some of these.
      array set ICAL_VARS $ical_vars
    } else {
      # If there is nothing recorded, set defaults and update the db
      set cal_uid [::xo::ical clock_to_utc \
		       [clock seconds]]-$activity_id@[ns_info hostname]
      set ical_vars ""
      set f dbqd.calendar.tcl.cal-item-procs
      db_dml $f.calendar::item::new.insert_cal_uid {}
    }
    $vevent uid $cal_uid
    
    # Copy ical vars to the vevent structure ...
    foreach {attribute value} [array get ICAL_VARS] {
      $vevent set [string tolower $attribute] $value
    }
    # ... and format according to the ical rules
    append ics [$vevent as_ical]
    $vevent destroy
  }

  append ics [my footer]
  return $ics
}

# The following tags are handled in the ical parser; the values are
# placed into the ical_vars of cal_uids.
::calendar::ical set opaque_tags {CATEGORIES CLASS COMMENT GEO 
  LOCATION PERCENT-COMPLETE PRIORITY RESOURCES STATUS SEQUENCE URL 
  OPAQUE-ALARM
}

::calendar::ical ad_proc parse { 
  text 
} {
  Parse the ical file passed in as string an output a list
  of CalItem objects. The items specified in opaque_tags
  are passed as opaque values (these are not shown in
  oacs, but output when the calendar item is requested
  in cal format.

  @param text the text do be parsed
} {
  my set error_count 0
  set parse_error 0
  set in_valarm 0
  set in_vevent 0
  set item_list [list]
  set opaque_re ^([join [my set opaque_tags] |]):(.*)$
  set prefix ""
  regsub -all "\n " $text "" text
  regsub -all "\r" $text "" text
  foreach line [split $text \n] {
    my log "ICAL processing: <$line>"
    if {$in_valarm} {
      # treat everything in an valarm as opaque for the time being
      if { [regexp {^END:VALARM.*$} $line] } {
	# end of valarm section
	set in_valarm 0
	$item append OPAQUE-ALARM $line\r\n
      } else {
	$item append OPAQUE-ALARM $line\r\n
      }
    } elseif { [regexp $opaque_re $line _ tag value] } {
      # we do not handle these in oacs yet, but we set set these 
      # already into the item to make future extensions easier
      $item set $tag [::xo::ical ical_to_text $value]
    } elseif { [regexp {^BEGIN:VEVENT.*$} $line] } {
      # reset values
      set in_valarm 0
      set in_vevent 1
      set r_error 0
      set item [::calendar::ical::CalItem new]
      lappend item_list $item
      
    } elseif { [regexp {^BEGIN:VALARM.*$} $line] } {
      # begin of valarm section
      set in_valarm 1
      $item set OPAQUE-ALARM $line\r\n
    } elseif { $in_vevent && [regexp {^SUMMARY[^:]*:(.*)$} $line _ title] } {
      $item title [::xo::ical ical_to_text $title]
    } elseif { $in_vevent && [regexp {^(DTSTAMP|UID|LAST-MODIFIED)[^:]*:(.*)$}\
				  $line _ field entry] } {
      $item [string tolower $field] $entry
    } elseif { $in_vevent && [regexp {^DTSTART(\;TZID.*)?:([0-9]+)T+([0-9]+)(Z?).*$} \
		    $line _ dummytz date time utc] } {
      
      if {[string length $date] != 8 || [string length $time] != 6} {
	set parse_error 1
      } else {
	$item set_time dtstart $date $time [expr {$utc ne ""}]
      } 
      
    } elseif { $in_vevent && 
	       [regexp {^DTSTART.+DATE[^:]*:([0-9]+).*$} $line _ date] } {
      
      if {[string length $date] != 8} {
	set parse_error 1
      } else {
	$item set_time dtstart $date "0000" 0
      }
    } elseif { $in_vevent &&
	       [regexp {^DTEND(\;TZID.*)?[^:]*:([0-9]+)T+([0-9]+)(Z?).*$} \
		    $line _ dummytz date time utc] } {
      if {[string length $date] != 8 || [string length $time] != 6} {
	set parse_error 1
      } else {
	$item set_time dtend $date $time [expr {$utc ne ""}]
      } 
    } elseif { $in_vevent && 
	       [regexp {^DTEND.+?DATE[^:]*:([0-9]+).*$} $line _ date ] } {
      
      if {[string length $date] != 8} {
	set parse_error 1
      } else {
	$item set_time dtend $date "0000" 0
      }
    } elseif {$in_vevent && 
	      [regexp {^DURATION[^:]*:P(.*)$} $line _ duration] } {
      if {[regexp {^([0-9]+)W(.*)$} $duration _ units duration]} {
	set units [string trimleft $units 0]
	$item incr duration [expr {$units*24*3600*7}]
      }
      if {[regexp {([0-9]+)D(.*)$} $duration _ units duration]} {
	set units [string trimleft $units 0]
	$item incr duration [expr {$units*24*3600}]
      }
      if {[regexp {([0-9]+)H(.*)$} $duration _ units duration]} {
	set units [string trimleft $units 0]
	$item incr duration [expr {$units*3600}]
      }	
      if {[regexp {([0-9]+)M(.*)$} $duration _ units duration]} {
	set units [string trimleft $units 0]
	$item incr duration [expr {$units*60}]
      }
      if {[regexp {([0-9]+)S(.*)$} $duration _ units duration]} {
	set units [string trimleft $units 0]
	$item incr duration $units*60
      }
      
    } elseif {$in_vevent && 
	      [regexp {^DESCRIPTION.*:(.*)$} $line _ desc] } {
      $item description [::xo::ical ical_to_text $desc]
      
    } elseif { $in_vevent && 
	       [regexp {^RRULE[^:]*:(.*)$} $line _ recurrule] } {
      set r_freq ""
      set every_n 1
      set r_error 0
      set r_until ""
      set days_of_week ""
      set r_count 0
      foreach rval [split $recurrule ";"] {
	if { [regexp {^FREQ\=+(.*)$} $rval _ freqval] } {
	  switch $freqval {
	    DAILY   { set r_freq "day" }
	    WEEKLY  { set r_freq "week" }
	    MONTHLY { set r_freq "month_by_day"}
	    YEARLY  { set r_freq "year"}
	    default { set r_error 1 }
	  }
	} elseif { [regexp {^COUNT=(.*)$} $rval _ countval] } {
	  set r_count $countval
	} elseif { [regexp {^UNTIL=([0-9]+)(T([0-9]+)Z?)?$} $rval \
			_ untildate untiltime] } {
	  if {$untiltime eq ""} {set untiltime 000000}
	  set r_until "[string range $untildate 0 3]-[string range $untildate 4 5]-[string range $untildate 6 7] [string range $untiltime 0 1]:[string range $untiltime 2 3]"
	} elseif { [regexp {^INTERVAL\=+(.*)$} $rval _ intval] } {
	  set every_n $intval
	} elseif { [regexp {^BYDAY\=+(.*)$} $rval _ bydayval] } {
	  # set days of week list
	  foreach dayval [split $bydayval ","] {
	    switch $dayval {
	      SU { lappend days_of_week "0" }
	      MO { lappend days_of_week "1" }
	      TU { lappend days_of_week "2" }
	      WE { lappend days_of_week "3" }
	      TH { lappend days_of_week "4" }
	      FR { lappend days_of_week "5" }
	      SA { lappend days_of_week "6" }
	    }
	  }
	} elseif { [regexp {^BYMONTHDAY\=+(.*)$} $rval _ bymonthdayval] } {
	  # set month_by_date
	  set r_freq "month_by_date"
	} else {
	  # other rules dont work with OpenACS recurrence model
	}
	#check we can make this rule, else ignore
      }
      
      # calculate r_until based on COUNT (which is unsupported by OACS)
      # if UNTIL and COUNT not set, unlimited event, so skip.
      if { $r_until == "" && $r_freq != "" && $r_count > 0 } {
	# current date + r_count * r_freq * every_n (/ num_days)
	# set num seconds per frequency
	switch $r_freq {
	  day           { set r_freq_amount 86400 }
	  week          { set r_freq_amount 604800 }
	  month_by_day  { set r_freq_amount 2419200 }
	  month_by_date { set r_freq_amount 2678400 }
	  year          { set r_freq_amount 31449600 }
	}
	# start date is count=1, so adjust count
	set r_count [expr {$r_count - 1}]
	set r_extra [expr {$r_count * $r_freq_amount * $every_n}]
	if { $r_freq == "week" && [llength $days_of_week] > 0} {
	  set r_extra [expr {$r_extra / [llength $days_of_week]}]
	}
	set r_until [::xo::ical clock_to_oacstime \
			 [expr {[clock scan [$item dtstart]] + $r_extra}]]
      }
      # test values to make sure they are valid
      if { !$r_error && $r_freq != ""} {
	# no error, so do recurrence
	$item recurrence_options \
	    [list -interval_type $r_freq -every_n $every_n]
	if {$days_of_week ne ""} {
	  $item lappend recurrence_options -days_of_week $days_of_week
	}
	if {$r_until ne ""} {
	  $item lappend recurrence_options -recur_until $r_until
	}
      }
      
    } elseif { $in_vevent && [regexp {^END:VEVENT.*$} $line] } {
      set in_vevent 0

      if {[$item dtend] eq ""} {
	set end_clock [clock scan [$item dtstart]]
	incr end_clock [$item duration]
	$item dtend [::xo::ical clock_to_oacstime $end_clock]
      }

      if {$parse_error != 1} {
	$item r_error $r_error
	# now, the calendar item is done
	my cal_item_done $item

      } else {
	incr error_count
      }
      
    } else {
      # Ignore unused ical lines
      my log "ICAL ignoring: <$line>"
    }
  }
  return $item_list
}

::calendar::ical ad_proc cal_item_done { 
  item 
} {
  a calenar item was parsed; this method can be overloaded
  for extensions requiring the parsed calendar items
} {
}

::calendar::ical proc unknown args {
  my log "+++ calendar::ical unknown method <$args>"
}



namespace eval ::calendar::ical {
  #
  # Subclass ::xo::ProtocolHander for CalDAV
  #

  Class create CalDAV -superclass ::xo::ProtocolHandler -parameter {
    {url /ical/}
  }
  
  CalDAV instproc GET {} {
    my log "ical_dav::handle_request [self proc] method user_id [my set user_id] query '[ns_conn query]'"
    set cal_name         [ns_queryget cal_name dotlrn]
    set package_id       [ns_queryget package_id 0]
    set calendar_id_list [ns_queryget calendar_id_list "0"]
    set item_type_id     [ns_queryget item_type_id ""]
    set period_days      [ns_queryget period_days 30]
    set full             [ns_queryget full 1]
    set calendar_id      [ns_queryget calendar_id 0]
    if {$calendar_id == 0} {
      # If a calendar is published under iCal (Mac OS X) we have to
      # take the kalendar id from the url, since we can't pass query params
      regexp {/([0-9]+)/} [my set uri] _ calendar_id
    }
    if {$calendar_id_list eq "0"} {
      set calendar_id_list [list $calendar_id]
    }
    set full_calendar_id [expr {$full ? $calendar_id : 0}]
    set ics [::calendar::ical format_calendar \
		 -cal_name $cal_name \
		 -package_id $package_id \
		 -user_id [my set user_id] \
		 -calendar_id_list $calendar_id_list \
		 -item_type_id $item_type_id \
		 -full_calendar_id $full_calendar_id \
		 -period_days $period_days]
    ns_return 200 [expr {[ns_queryget plain 0] ? "text/plain" : "text/calendar"}] $ics
  }

  CalDAV instproc PUT {} {
    my log "ical_dav::handle_request [self proc] method user_id [my set user_id] query '[ns_conn query]'"
    my log "ical_dav::handle_request content: [ns_conn content]"
    set calendar_id_list [ns_queryget calendar_id_list 0]
    set calendar_id      [ns_queryget upload_calendar_id 0]
    set item_type_id     [ns_queryget item_type_id ""]
    if {!$calendar_id} {
      # if a calendar is published under ical (mac os x) we have to
      # take the kalendar id from the uri, since we can't pass query params
      regexp {/([0-9]+)/} [my set uri] _ calendar_id
    }
    if {$calendar_id_list eq "0"} {set calendar_id_list [list $calendar_id]}
    
    set create_permission_p [ad_permission_p $calendar_id cal_item_create]
    set write_calendar_ids [::calendar::ical calendar_ids_with_permissions \
				-permission cal_item_write \
				-user_id [my set user_id] $calendar_id_list]
    my log "ids=<$calendar_id_list> write_calendar_ids=<$write_calendar_ids>"
    if {[llength $write_calendar_ids] == 0} {
      foreach item $items { $item destroy }
      ns_return 403 text/plain "no permissions to write to calendar"
    } else {

      set items [::calendar::ical parse [ns_conn content]]
      foreach item $items {
	lappend uids '[$item uid]'
	$item update -import true \
	    -create_calendar_id $calendar_id \
	    -create_cal_item_permission_p $create_permission_p \
	    -write_calendar_ids $write_calendar_ids \
	    -item_type_id $item_type_id
	$item destroy
      }
      
      ::calendar::ical delete_calendar_items \
	  -calendar_ids $write_calendar_ids \
	  $uids
      ns_return 201 text/plain "[llength items] items processed"
    }
  }

  CalDAV instproc PROPFIND {} {
    # A minimal definition for PROPFIND. Extend if necessary.
    my log "PROPFIND [ns_conn content]"
    ns_return 204 text/xml {<?xml version="1.0" encoding="utf-8" ?>}
  }

  #
  # Implement more WebDav methods like DELETE, COPY, MOVE, MKCOL,
  # LOCK, UNLOCK if neccessary
}

#
# Finally create handler object
#
namespace eval ::calendar::ical {

  # Create an instance of the the webdav handler for calendar
  
  CalDAV create ::calendar::ical::dav
}