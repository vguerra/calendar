<master>
<property name="title">Calendars</property>
<property name="context">Calendar</property>

<table width="95%" border=1 cellpadding=1 cellspacing=0>
<tr><td nowrap align=center bgcolor=lavender>
<b>Calendar Import Confirmation</b></td></tr>
<tr><td valign="top"><br><b>Processed Calendar Items:<br>
<listtemplate name="calendar_items"></listtemplate>
<p>
@total_items;noquote@
<p>
<form action="ical-import-confirm" method="POST">
<textarea name="ical_text" rows="20" cols="80">@ical_text@</textarea><br>
<input type='hidden' name='calendar_id' value='@calendar_id@'>
<input type='hidden' name='item_type_id' value='@item_type_id@'>
<input type="submit"  value="Check">
<input type="submit" name="import" value="Import">
</form>
</if>
