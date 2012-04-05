
ad_page_contract {
    
    Uploading of iCal files
    
    @author Jamie Hill (jamie@emotive.com.au)
    @author Gustaf Neumann (neumann@wu-wien.ac.at)
    
    @creation-date Nov 11, 2002
} {
    {calendar_id ""}
}

if {$calendar_id eq ""} {
  set calendar_list [calendar::calendar_list]
  set calendar_id [lindex $calendar_list 0 1]
  set calendar_name [lindex $calendar_list 0 0]
} else {
  calendar::get -calendar_id $calendar_id -array calinfo
  set calendar_name $calinfo(calendar_name)
}

set item_types [calendar::get_item_types -calendar_id $calendar_id]
set item_type_field [::template::widget::menu item_type_id \
			 $item_types [list ""] item_type_id]
