<if @calendars:rowcount@ gt 0>
<div class="calendar-tools cal-options">
#calendar.Calendars#:
<ul>
<multiple name="calendars">
<li> @calendars.calendar_name@<br />
<if @calendars.calendar_admin_p@ true>
	<small>
  [<a href="@base_url@calendar-item-types?calendar_id=@calendars.calendar_id@" title="#calendar.Manage_Item_Types#">#calendar.Manage_Item_Types#</a>]
	</small>
</if>
</li>
</multiple>
</ul>
</div>
</if>


