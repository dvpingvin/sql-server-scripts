/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Показывает 50 запросов с самым интенсивным вводом-выводом                */
/* Дата и время в хранилище запросов представлена типом datetimeoffset      */
/* Хранилище запросов появилось в SQL Server 2016                           */
/****************************************************************************/

SELECT TOP 50
q.query_id, qt.query_sql_text, qp.plan_id, qp.query_plan
,SUM(rs.count_executions) AS [Execution Cnt]
,CONVERT(INT,SUM(rs.count_executions *
(rs.avg_logical_io_reads + avg_logical_io_writes)) /
SUM(rs.count_executions)) AS [Avg IO]
,CONVERT(INT,SUM(rs.count_executions *
(rs.avg_logical_io_reads + avg_logical_io_writes))) AS [Total IO]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_cpu_time) /
SUM(rs.count_executions)) AS [Avg CPU]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_cpu_time)) AS [Total CPU]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_duration) /
SUM(rs.count_executions)) AS [Avg Duration]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_duration))
AS [Total Duration]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_physical_io_reads) /
SUM(rs.count_executions)) AS [Avg Physical Reads]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_physical_io_reads))
AS [Total Physical Reads]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_query_max_used_memory) /
SUM(rs.count_executions)) AS [Avg Memory Grant Pages]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_query_max_used_memory))
AS [Total Memory Grant Pages]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_rowcount) /
SUM(rs.count_executions)) AS [Avg Rows]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_rowcount)) AS [Total Rows]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_dop) /
SUM(rs.count_executions)) AS [Avg DOP]
,CONVERT(INT,SUM(rs.count_executions * rs.avg_dop)) AS [Total DOP]
FROM
sys.query_store_query q WITH (NOLOCK)
JOIN sys.query_store_plan qp WITH (NOLOCK) ON
q.query_id = qp.query_id
JOIN sys.query_store_query_text qt WITH (NOLOCK) ON
q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats rs WITH (NOLOCK) ON
qp.plan_id = rs.plan_id
JOIN sys.query_store_runtime_stats_interval rsi WITH (NOLOCK) ON
rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE
rsi.end_time >= DATEADD(DAY,-1,SYSDATETIMEOFFSET())
GROUP BY
q.query_id, qt.query_sql_text, qp.plan_id, qp.query_plan
ORDER BY
[Avg IO] DESC
OPTION (MAXDOP 1, RECOMPILE);
