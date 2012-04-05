<?xml version="1.0"?>

<queryset>
<fullquery name="select_recurrence">      
<querytext>
select 
   recurrence_id, 
   recurrences.interval_type, 
   interval_name,
   every_nth_interval, 
   days_of_week, 
   recur_until
from 
   recurrences, 
   recurrence_interval_types
where 
   recurrence_id= :recurrence_id
   and recurrences.interval_type = recurrence_interval_types.interval_type
</querytext>
</fullquery>

<fullquery name="select_portal_parameter">
<querytext>
  select 
    value 
  from  
    portal_pages, 
    portal_element_map, 
    portal_element_parameters 
  where 
    portal_id = :portal_id 
    and portal_pages.page_id = portal_element_map.page_id 
    and portal_element_map.name = 'calendar_portlet' 
    and portal_element_parameters.element_id = portal_element_map.element_id 
    and key = :portal_key
</querytext>
</fullquery>

<fullquery name="select_calendar_ids_from_calendar_ids">
<querytext>
  select calendar_id from calendars where 
  package_id in (
    select package_id from calendars where calendar_id in ($calendar_ids)
  ) and (private_p = 'f' or owner_id = :user_id)
</querytext>
</fullquery>

<fullquery name="select_calendars_from_package_id">
<querytext>
  select 
    calendar_id,
    calendar_name,
    owner_id,
    private_p
  from  
    calendars
  where 
    package_id = :package_id
    and (private_p = 'f' or owner_id = :user_id)
</querytext>
</fullquery>


<fullquery name="select_calendars_from_package_id">
<querytext>
  select 
    calendar_name,
    owner_id,
    private_p
  from  
    calendars
  where 
    calendar_id in ($calendar_ids)
</querytext>
</fullquery>

<fullquery name="cal_item_ids_from_uid">
<querytext>
select 
  cal_item_id,
  on_which_calendar as calendar_id
from 
  cal_uids, 
  acs_activities a, 
  acs_events e,
  cal_items
where 
  cal_uid = :uid 
  and on_which_activity = e.activity_id 
  and e.activity_id = a.activity_id
  and cal_item_id = e.event_id
</querytext>
</fullquery>

</queryset>
