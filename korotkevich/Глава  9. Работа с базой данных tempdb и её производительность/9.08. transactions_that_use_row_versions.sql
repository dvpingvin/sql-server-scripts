/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

SELECT TOP 5
at.transaction_id
,at.elapsed_time_seconds
,at.session_id
,s.login_time
,s.login_name
,s.host_name
,s.program_name
,s.last_request_start_time
,s.last_request_end_time
,er.status
,er.wait_type
,er.wait_time
,er.blocking_session_id
,er.last_wait_type
,st.text AS [SQL]
FROM
sys.dm_tran_active_snapshot_database_transactions at WITH (NOLOCK)
JOIN sys.dm_exec_sessions s WITH (NOLOCK) on
at.session_id = s.session_id
LEFT JOIN sys.dm_exec_requests er WITH (NOLOCK) on
at.session_id = er.session_id
OUTER APPLY
sys.dm_exec_sql_text(er.sql_handle) st
ORDER BY
at.elapsed_time_seconds DESC;
