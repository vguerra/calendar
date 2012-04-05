<master>
<property name="title">Calendars</property>
<property name="context">Calendar</property>

<table width="95%" border="1" cellpadding="1" cellspacing="0">
<tr><td nowrap="1" align="center" bgcolor="lavender" colspan="2">
<b>Import iCalendar File</b></td></tr>
<tr><td valign="top" colspan=2><br>
You are going to import a calendar items into the calendar named 
<b>@calendar_name@</b> in the iCal format.
Please select the file with the calendar items from your system 
using the "browse" button  below, and select the calendar item type 
from the dropdown box. Then click Upload. 
<br><br>
</tr>

<tr><td>
<form enctype="multipart/form-data" method="POST" action="import-confirm">
<table border="0">
<tr>
<td align="right"><br>iCalendar filename :&nbsp;</td>
<td><br><input type="file" name="upload_file" size="20">
<input type='hidden' name='calendar_id' value='@calendar_id@'>
</tr>

<tr>
<td align="right">Item Type:&nbsp;</td>
<td>@item_type_field;noquote@
</td>
</tr>

<tr>
<td>&nbsp;</td>
<td><font size=-1>Use the "Browse..." button to locate your .ics file, 
    then click "Open". </font></td>
</tr>

<tr>
<td></td>
<td><input type=submit value="Upload">
</td>
</tr>

</table>
</form>
</td></tr>
</table>

</if>
