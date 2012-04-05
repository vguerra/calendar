
ad_page_contract {
  script to recieve ical files and insert 
  calendar items into the database

  @author Jamie Hill (jamie@emotive.com.au)
  @author Gustaf Neumann (neumann@wu-wien.ac.at)
  @creation-date Nov 11, 2002
} {
  upload_file:notnull,trim,optional
  upload_file.tmpfile:tmpfile,optional
  {import ""}
  {ical_text ""}
  {calendar_id ""}
  {item_type_id ""}
} -properties {
  total_items:onevalue
  ical_text:onevalue
  calendar_id:onevalue
  calendar_type_id:onevalue
}

set out ""
set import [expr {$import ne ""}]

template::list::create \
    -name calendar_items \
    -no_data "No Calendar items found " \
    -elements {
      itemnr {
        label "Item"
      }
      action {
	label "Action"
      }
      start_date {
        label "Start Date"
      }
      end_date {
        label "End Date"
      }
      recurring {
        label "Recurring"
      }
      title {
        label "Title"
      }
      view {
        label ""
	link_url_col view_url
      }
      cmd {
        label "command"
	hide_p 1
      }
    }

# cmd left in for the time being as an alternative for the textarea ...

multirow create calendar_items \
    itemnr action start_date end_date recurring title view view_url cmd

if {[info exists upload_file.tmpfile]} {
  set fid [open ${upload_file.tmpfile} r]
  set ical_text [read $fid]
  close $fid
  #set out "from file"
} else {
  #set out "from text"
}

if {$import && $calendar_id eq ""} {
  set calendar_list [calendar::calendar_list]
  set calendar_id [lindex $calendar_list 0 1]
}

set create_permission_p [ad_permission_p $calendar_id cal_item_create]
set write_calendar_ids [::calendar::ical write_calendar_ids \
			    -permission cal_item_write \
			    -user_id $user_id [list calendar_id]]

set created 0
set ignored 0

set items [::calendar::ical parse $ical_text]
foreach item $items {
  $item instvar r_status cal_item_id action

  $item update -import $import \
      -create_calendar_id $calendar_id \
      -create_cal_item_permission_p $create_permission_p \
      -write_calendar_ids $write_calendar_ids \
      -item_type_id $item_type_id

  switch $action {
    ignore {incr ignored}
    created {incr created}
  }
  
  set cmd ""
  if {$cal_item_id ne ""} {
    set label "view"
    set url "../cal-item-view?cal_item_id=$cal_item_id" 
  } else {
    set label ""
    set url ""
  }
  multirow append calendar_items \
      [$item uid] $action \
      [$item dtstart] [$item dtend] \
      $r_status [$item title] \
      $label $url \
      $cmd
  $item destroy
}

#append out "set system::timezone [lang::system::timezone]<br>"
#append out "set conn::timezone [lang::conn::timezone]<br>"
#append out "offset [lang::system::timezone_utc_offset]"

set nr_items [llength $items]
set total_items "$nr_items item[expr {$nr_items == 1 ? {} : {s}}] processed ("
if {$import} {
  append total_items "$created created, " \
      [expr {$nr_items-($created+$ignored)}] " updated, " \
      "$ignored ignored, "
}
  append total_items "$::calendar::ical::error_count errors)."

append total_items "
    $out
    calendar_id = '$calendar_id'<p>
"
