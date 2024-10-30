/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Статистика выполнения запросов на основе планов выполения в кэше         */
/* Статистика берётся за период между cached_time и last_execution_plan     */
/* SQL Server не кэширует планы, если используется предложение RECOMPILE    */
/* Если план не попал в кэш, его здесь не будет                             */
/* Планы являются расчётными, не содержат фактические показатели выполнения */
/* Чтобы получить последний фактический план выполнения, замени             */
/*   sys.dm_exec_text_query_plan на sys.dm_exec_query_plan_stats            */
/* Перезапуск служб SQL Server приводит к очистке кэша планов               */
/* Для старых версий может потребоваться удалить неподдерживаемые столбцы   */
/****************************************************************************/

;WITH Queries
AS
(
SELECT TOP 50
qs.creation_time AS [Cached Time]
,qs.last_execution_time AS [Last Exec Time]
,qs.execution_count AS [Exec Cnt] -- количество запусков запроса считается за период между первым и последним выполнениями
,CONVERT(DECIMAL(10,5),
IIF
(
DATEDIFF(SECOND,qs.creation_time, qs.last_execution_time) = 0
,NULL
,1.0 * qs.execution_count /
DATEDIFF(SECOND,qs.creation_time, qs.last_execution_time)
)
) AS [Exec Per Second] -- среднее количество запусков за период между первым и последним выполнениями
,(qs.total_logical_reads + qs.total_logical_writes) /
qs.execution_count AS [Avg IO] -- средняя нагрузка ввода-вывода на один запуск
,(qs.total_worker_time / qs.execution_count / 1000) -- среднее время на один запуск в мс (total_worker_time в микросекундах)
AS [Avg CPU(ms)]
,qs.total_logical_reads AS [Total Reads]
,qs.last_logical_reads AS [Last Reads]
,qs.total_logical_writes AS [Total Writes]
,qs.last_logical_writes AS [Last Writes]
,qs.total_worker_time / 1000 AS [Total Worker Time] -- в мс (total_worker_time в микросекундах)
,qs.last_worker_time / 1000 AS [Last Worker Time] -- в мс (last_worker_time в микросекундах)
,qs.total_elapsed_time / 1000 AS [Total Elapsed Time] -- в мс (total_worker_time в микросекундах)
,qs.last_elapsed_time / 1000 AS [Last Elapsed Time] -- в мс (last_elapsed_time в микросекундах)
,qs.total_rows AS [Total Rows]
,qs.last_rows AS [Last Rows]
,qs.total_rows / qs.execution_count AS [Avg Rows]
,qs.total_physical_reads AS [Total Physical Reads]
,qs.last_physical_reads AS [Last Physical Reads]
,qs.total_physical_reads / qs.execution_count
AS [Avg Physical Reads]
,qs.total_grant_kb AS [Total Grant KB]
,qs.last_grant_kb AS [Last Grant KB]
,(qs.total_grant_kb / qs.execution_count)
AS [Avg Grant KB]
,qs.total_used_grant_kb AS [Total Used Grant KB]
,qs.last_used_grant_kb AS [Last Used Grant KB]
,(qs.total_used_grant_kb / qs.execution_count)
AS [Avg Used Grant KB]
,qs.total_ideal_grant_kb AS [Total Ideal Grant KB]
,qs.last_ideal_grant_kb AS [Last Ideal Grant KB]
,(qs.total_ideal_grant_kb / qs.execution_count)
AS [Avg Ideal Grant KB]
,qs.total_columnstore_segment_reads
AS [Total CSI Segments Read]
,qs.last_columnstore_segment_reads
AS [Last CSI Segments Read]
,(qs.total_columnstore_segment_reads / qs.execution_count)
AS [AVG CSI Segments Read]
,qs.max_dop AS [Max DOP]
,qs.total_spills AS [Total Spills]
,qs.last_spills AS [Last Spills]
,(qs.total_spills / qs.execution_count) AS [Avg Spills]
,qs.statement_start_offset
,qs.statement_end_offset
,qs.plan_handle
,qs.sql_handle
FROM
sys.dm_exec_query_stats qs WITH (NOLOCK)
ORDER BY
[Avg IO] DESC -- в зависимости от компонента, нагрузку на который мы хотим уменьшить
)
SELECT
SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
((
CASE qs.statement_end_offset
WHEN -1 THEN DATALENGTH(qt.text)
ELSE qs.statement_end_offset
END - qs.statement_start_offset)/2)+1) AS SQL
,TRY_CONVERT(xml,qp.query_plan) AS [Query Plan]
,qs.*
FROM
Queries qs
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
OUTER APPLY
sys.dm_exec_text_query_plan -- можно заменить на sys.dm_exec_query_plan_stats, чтобы получить последний фактический план выполнения
(
qs.plan_handle
,qs.statement_start_offset
,qs.statement_end_offset
) qp
OPTION (RECOMPILE, MAXDOP 1);
