/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

;WITH SpaceUsagePages
AS
(
SELECT
ss.session_id
,ss.user_objects_alloc_page_count +
ISNULL(SUM(ts.user_objects_alloc_page_count),0)
AS [user_alloc_page_count]
,ss.user_objects_dealloc_page_count +
ISNULL(SUM(ts.user_objects_dealloc_page_count),0)
AS [user_dealloc_page_count]
,ss.user_objects_deferred_dealloc_page_count
AS [user_deferred_page_count]
,ss.internal_objects_alloc_page_count +
ISNULL(SUM(ts.internal_objects_alloc_page_count),0)
AS [internal_alloc_page_count]
,ss.internal_objects_dealloc_page_count +
ISNULL(SUM(ts.internal_objects_dealloc_page_count),0)
AS [internal_dealloc_page_count]
FROM
sys.dm_db_session_space_usage ss WITH (NOLOCK) LEFT JOIN
sys.dm_db_task_space_usage ts WITH (NOLOCK) ON
ss.session_id = ts.session_id
GROUP BY
ss.session_id
,ss.user_objects_alloc_page_count
,ss.user_objects_dealloc_page_count
,ss.internal_objects_alloc_page_count
,ss.internal_objects_dealloc_page_count
,ss.user_objects_deferred_dealloc_page_count
)
,SpaceUsage
AS
(
SELECT
session_id
,CONVERT(DECIMAL(12,3),
([user_alloc_page_count] - [user_dealloc_page_count]) / 128.
) AS [user_used_mb]
,CONVERT(DECIMAL(12,3),
([internal_alloc_page_count] - [internal_dealloc_page_count]) / 128.
) AS [internal_used_mb]
,CONVERT(DECIMAL(12,3),user_deferred_page_count / 128.)
AS [user_deferred_used_mb]
FROM
SpaceUsagePages
)
SELECT
su.session_id
,su.user_used_mb
,su.internal_used_mb
,su.user_deferred_used_mb
,su.user_used_mb + su.internal_used_mb AS [space_used_mb]
,es.open_transaction_count
,es.login_time
,es.original_login_name
,es.host_name
,es.program_name
,er.status as [request_status]
,er.start_time
,CONVERT(DECIMAL(21,3),er.total_elapsed_time / 1000.) AS [duration]
,er.cpu_time
,ib.event_info as [buffer]
,er.wait_type
,er.wait_time
,er.wait_resource
,er.blocking_session_id
FROM
SpaceUsage su
LEFT JOIN sys.dm_exec_requests er WITH (NOLOCK) ON
su.session_id = er.session_id
LEFT JOIN sys.dm_exec_sessions es WITH (NOLOCK) ON
su.session_id = es.session_id
OUTER APPLY
sys.dm_exec_input_buffer(es.session_id, er.request_id) ib
WHERE
su.user_used_mb + su.internal_used_mb >= 50
ORDER BY
[space_used_mb] DESC
OPTION (RECOMPILE);
