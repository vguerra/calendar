
# /packages/calendar/www/cal-item-create.tcl

ad_page_contract {
    
    Creation of new recurrence for cal item
    
    @author Ben Adida (ben@openforce.net)
    @creation-date 10 Mar 2002
    @cvs-id $Id$
} {
    cal_item_id
    every_n
    interval_type
    recur_until:array
    days_of_week:multiple
    {return_url "./"}
}


# Verify permission
ad_require_permission $cal_item_id cal_item_write

# Get basic information about the event. We need the start date
calendar::item::get -cal_item_id $cal_item_id -array cal_item

set start_date $cal_item(start_date)
set end_date [calendar::make_datetime [array get recur_until]]

if {![calendar::item::dates_valid_p -start_date $start_date -end_date $end_date]} {
    ad_return_complaint 1 [_ calendar.start_date_before_end_date]
    ad_script_abort
}

# Set up the recurrence
calendar::item::add_recurrence \
    -cal_item_id $cal_item_id \
    -interval_type $interval_type \
    -every_n $every_n \
    -days_of_week $days_of_week \
    -recur_until [calendar_make_datetime [array get recur_until]]

ad_returnredirect $return_url
