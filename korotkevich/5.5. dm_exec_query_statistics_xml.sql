/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Этот код работает в версиях SQL Server 2016 и новее.                     */
/* Для более старых версий можно удалить столбец ep.dop.                    */
/* Для версий ниже, чем SQL Server 2012, удалите функцию TRY_CONVERT.       */
/* Получать план с помощью sys.dm_exec_text_query_plan — ресурсоемко.       */
/* Закомментируйте ее, если сервер работает с большой нагрузкой.            */
/****************************************************************************/

SELECT
er.session_id
,er.request_id
,DB_NAME(er.database_id) as [database]
,er.start_time
,CONVERT(DECIMAL(21,3),er.total_elapsed_time / 1000.) AS [duration]
,er.cpu_time
,SUBSTRING(
qt.text,
(er.statement_start_offset / 2) + 1,
((CASE er.statement_end_offset
WHEN -1 THEN DATALENGTH(qt.text)
ELSE er.statement_end_offset
END - er.statement_start_offset) / 2) + 1
) AS [statement]
,er.status
,er.wait_type
,er.wait_time
,er.wait_resource
,er.blocking_session_id
,er.last_wait_type
,er.reads
,er.logical_reads
,er.writes
,er.granted_query_memory
,er.dop
,er.row_count
,er.percent_complete
,es.login_time
,es.original_login_name
,es.host_name
,es.program_name
,c.client_net_address
,ib.event_info AS [buffer]
,qt.text AS [sql]
,p.query_plan
FROM
sys.dm_exec_requests er WITH (NOLOCK)
OUTER APPLY sys.dm_exec_input_buffer(er.session_id, er.request_id) ib
OUTER APPLY sys.dm_exec_sql_text(er.sql_handle) qt
OUTER APPLY sys.dm_exec_query_statistics_xml(er.session_id) p
LEFT JOIN sys.dm_exec_connections c WITH (NOLOCK) ON
er.session_id = c.session_id
LEFT JOIN sys.dm_exec_sessions es WITH (NOLOCK) ON
er.session_id = es.session_id
WHERE
er.status <> 'background'
AND er.session_id > 50
ORDER BY
er.cpu_time desc
OPTION (RECOMPILE, MAXDOP 1);
