<?xml version="1.0"?>

<queryset>
<fullquery name="select_calendars">
<querytext>
  select 
    value 
  from  
    portal_pages, 
    portal_element_map, 
    portal_element_parameters 
   where 
    portal_id = $portal_id 
    and portal_pages.page_id = portal_element_map.page_id 
    and portal_element_map.name = 'calendar_portlet' 
    and portal_element_parameters.element_id = portal_element_map.element_id 
    and key = 'calendar_id'
</querytext>
</fullquery>
</queryset>
