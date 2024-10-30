/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Этот код работает в версиях SQL Server 2016 и новее.                     */
/* Статистика выполнения функций на основе планов выполения в кэше          */
/* Статистика берётся за период между cached_time и last_execution_plan     */
/* Если план не попал в кэш, его здесь не будет                             */
/* Перезапуск служб SQL Server приводит к очистке кэша планов               */
/* Для старых версий может потребоваться удалить неподдерживаемые столбцы   */
/****************************************************************************/

SELECT TOP 50
IIF (ps.database_id = 32767,
'mssqlsystemresource',
DB_NAME(ps.database_id)
) AS [DB]
,OBJECT_NAME(
ps.object_id,
IIF(ps.database_id = 32767, 1, ps.database_id)
) AS [Proc Name]
,ps.type_desc AS [Type]
,ps.cached_time AS [Cached Time]
,ps.last_execution_time AS [Last Exec Time]
,qp.query_plan AS [Plan]
,ps.execution_count AS [Exec Count]
,CONVERT(DECIMAL(10,5),
IIF(datediff(second,ps.cached_time, ps.last_execution_time) = 0,
NULL,
1.0 * ps.execution_count /
datediff(second,ps.cached_time, ps.last_execution_time)
)
) AS [Exec Per Second]
,(ps.total_logical_reads + ps.total_logical_writes) /
ps.execution_count AS [Avg IO]
,(ps.total_worker_time / ps.execution_count / 1000)
AS [Avg CPU(ms)]
,ps.total_logical_reads AS [Total Reads]
,ps.last_logical_reads AS [Last Reads]
,ps.total_logical_writes AS [Total Writes]
,ps.last_logical_writes AS [Last Writes]
,ps.total_worker_time / 1000 AS [Total Worker Time]
,ps.last_worker_time / 1000 AS [Last Worker Time]
,ps.total_elapsed_time / 1000 AS [Total Elapsed Time]
,ps.last_elapsed_time / 1000 AS [Last Elapsed Time]
,ps.total_physical_reads AS [Total Physical Reads]
,ps.last_physical_reads AS [Last Physical Reads]
,ps.total_physical_reads / ps.execution_count AS [Avg Physical Reads]
FROM
sys.dm_exec_function_stats ps WITH (NOLOCK)
CROSS APPLY sys.dm_exec_query_plan(ps.plan_handle) qp
ORDER BY
[Avg IO] DESC
OPTION (RECOMPILE, MAXDOP 1);
