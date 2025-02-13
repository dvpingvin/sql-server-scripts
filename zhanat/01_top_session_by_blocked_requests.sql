set nocount on
select count(*) as amount_exec_request from  sys.dm_exec_requests

select top 10
session_id,
sum(blocking_session_id) as amount_blocked_requests_desc
from sys.dm_exec_requests where session_id > 50
group by session_id
order by 2 desc;

select
n.session_id as [SID],
db_name(n.database_id) as [Database],
n.blocking_session_id as [Blocking SID],
n.wait_type,
i.original_login_name as [Login],
n.total_elapsed_time as [Duration],
i.host_name as [Host name],
i.client_interface_name,
i.status,
cast(i.login_time as smalldatetime) as [Login Time],
i.program_name as [Program],
cast(n.start_time as smalldatetime) as [Start Request],
n.wait_time,
n.cpu_time,
n.wait_resource,
n.status as [Status],
user_name(n.user_id) as [User],
n.open_transaction_count,
n.percent_complete,
n.task_address,
n.command as [Command],
replace(replace(s.text,char(10),''), char(13), '') as [Request Text]
from sys.dm_exec_sessions as i join sys.dm_exec_requests as n on i.session_id = n.session_id
cross apply sys.dm_exec_sql_text(n.sql_handle) as s where n.session_id in
	(select a.ses_id from (select top 10
	session_id as ses_id,
	sum(blocking_session_id) as amount_blocked_requests_desc
	from sys.dm_exec_requests where session_id > 50
	group by session_id
	order by 2 desc) a)
order by cpu_time desc
