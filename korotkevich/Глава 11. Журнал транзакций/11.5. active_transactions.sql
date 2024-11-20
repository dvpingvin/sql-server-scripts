/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

SELECT
dt.database_id
,DB_NAME(dt.database_id) as [DB]
,st.session_id
,CASE at.transaction_state
WHEN 0 THEN 'Not Initialized'
WHEN 1 THEN 'Not Started'
WHEN 2 THEN 'Active'
WHEN 3 THEN 'Ended (R/O)'
WHEN 4 THEN 'Commit Initialize'
WHEN 5 THEN 'Prepared'
WHEN 6 THEN 'Committed'
WHEN 7 THEN 'Rolling Back'
WHEN 8 THEN 'Rolled Back'
END AS [State]
,at.transaction_begin_time
,es.login_name
,ec.client_net_address
,ec.connect_time
,dt.database_transaction_log_bytes_used
,dt.database_transaction_log_bytes_reserved
,er.status
,er.wait_type
,er.last_wait_type
,sql.text AS [SQL]
FROM
sys.dm_tran_database_transactions dt WITH (NOLOCK)
JOIN sys.dm_tran_session_transactions st WITH (NOLOCK) ON
dt.transaction_id = st.transaction_id
JOIN sys.dm_tran_active_transactions at WITH (NOLOCK) ON
dt.transaction_id = at.transaction_id
JOIN sys.dm_exec_sessions es WITH (NOLOCK) ON
st.session_id = es.session_id
JOIN sys.dm_exec_connections ec WITH (NOLOCK) ON
st.session_id = ec.session_id
LEFT OUTER JOIN sys.dm_exec_requests er WITH (NOLOCK) ON
st.session_id = er.session_id
CROSS APPLY
sys.dm_exec_sql_text(ec.most_recent_sql_handle) sql
ORDER BY
dt.database_transaction_begin_time;
