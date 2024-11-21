select count(*) as amount_locks from sys.syslockinfo;

select top 10 req_spid, count(req_spid) as amount_of_locks from sys.syslockinfo
group by req_spid
order by 2 desc;

--select top 10 * from sys.syslockinfo
--where rsc_dbid = 11

select top 10 rsc_dbid as database_id, rsc_objid as id_object, rsc_type , count(rsc_objid) as amount_of_locks_on_object from sys.syslockinfo
where rsc_dbid > 4
group by rsc_dbid, rsc_objid, rsc_type
order by 4 desc;


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
(select b.id_session from (
select top 10 req_spid as id_session, count(req_spid) amount_of_locks_from_session from sys.syslockinfo
where rsc_objid in ( select a.id_object from (
select top 10 rsc_dbid as database_id, rsc_objid as id_object, rsc_type , count(rsc_objid) as amount_of_locks_on_object from sys.syslockinfo
where rsc_dbid > 4
group by rsc_dbid, rsc_objid, rsc_type
order by 4 desc
)a)
and rsc_dbid = 5
group by req_spid
order by 2 desc)b)
order by cpu_time desc;
