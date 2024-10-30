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
/* Группируется статистика по похожим запросам (у них одинаковый hash)      */
/* При этом выбирается один случайный запрос/хэш из группы                  */
/* SQL Server не кэширует планы, если используется предложение RECOMPILE    */
/* Если план не попал в кэш, его здесь не будет                             */
/* Планы являются расчётными, не содержат фактические показатели выполнения */
/* Чтобы получить последний фактический план выполнения, замени             */
/*   sys.dm_exec_text_query_plan на sys.dm_exec_query_plan_stats            */
/* Перезапуск служб SQL Server приводит к очистке кэша планов               */
/* Для старых версий может потребоваться удалить неподдерживаемые столбцы   */
/****************************************************************************/

;WITH Data
AS
(
SELECT TOP 50
qs.query_hash
,COUNT(*) as [Plan Count]
,MIN(qs.creation_time) AS [Cached Time]
,MAX(qs.last_execution_time) AS [Last Exec Time]
,SUM(qs.execution_count) AS [Exec Cnt]
,SUM(qs.total_logical_reads) AS [Total Reads]
,SUM(qs.total_logical_writes) AS [Total Writes]
,SUM(qs.total_worker_time / 1000) AS [Total Worker Time]
,SUM(qs.total_elapsed_time / 1000) AS [Total Elapsed Time]
,SUM(qs.total_rows) AS [Total Rows]
,SUM(qs.total_physical_reads) AS [Total Physical Reads]
,SUM(qs.total_grant_kb) AS [Total Grant KB]
,SUM(qs.total_used_grant_kb) AS [Total Used Grant KB]
,SUM(qs.total_ideal_grant_kb) AS [Total Ideal Grant KB]
,SUM(qs.total_columnstore_segment_reads)
AS [Total CSI Segments Read]
,MAX(qs.max_dop) AS [Max DOP]
,SUM(qs.total_spills) AS [Total Spills]
FROM
sys.dm_exec_query_stats qs WITH (NOLOCK)
GROUP BY
qs.query_hash
ORDER BY
SUM((qs.total_logical_reads + qs.total_logical_writes) /
qs.execution_count) DESC
)
SELECT
d.[Cached Time]
,d.[Last Exec Time]
,d.[Plan Count]
,sql_plan.SQL
,sql_plan.[Query Plan]
,d.[Exec Cnt]
,CONVERT(DECIMAL(10,5),
IIF(datediff(second,d.[Cached Time], d.[Last Exec Time]) = 0,
NULL,
1.0 * d.[Exec Cnt] /
datediff(second,d.[Cached Time], d.[Last Exec Time])
)
) AS [Exec Per Second]
,(d.[Total Reads] + d.[Total Writes]) / d.[Exec Cnt] AS [Avg IO]
,(d.[Total Worker Time] / d.[Exec Cnt] / 1000) AS [Avg CPU(ms)]
,d.[Total Reads]
,d.[Total Writes]
,d.[Total Worker Time]
,d.[Total Elapsed Time]
,d.[Total Rows]
,d.[Total Rows] / d.[Exec Cnt] AS [Avg Rows]
,d.[Total Physical Reads]
,d.[Total Physical Reads] / d.[Exec Cnt] AS [Avg Physical Reads]
,d.[Total Grant KB]
,d.[Total Grant KB] / d.[Exec Cnt] AS [Avg Grant KB]
,d.[Total Used Grant KB]
,d.[Total Used Grant KB] / d.[Exec Cnt] AS [Avg Used Grant KB]
,d.[Total Ideal Grant KB]
,d.[Total Ideal Grant KB] / d.[Exec Cnt] AS [Avg Ideal Grant KB]
,d.[Total CSI Segments Read]
,d.[Total CSI Segments Read] / d.[Exec Cnt] AS [AVG CSI Segments Read]
,d.[Max DOP]
,d.[Total Spills]
,d.[Total Spills] / d.[Exec Cnt] AS [Avg Spills]
FROM
Data d
CROSS APPLY
(
SELECT TOP 1
SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
((
CASE qs.statement_end_offset
WHEN -1 THEN DATALENGTH(qt.text)
ELSE qs.statement_end_offset
END - qs.statement_start_offset)/2)+1
) AS SQL
,TRY_CONVERT(XML,qp.query_plan) AS [Query Plan]
FROM
sys.dm_exec_query_stats qs
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
OUTER APPLY sys.dm_exec_text_query_plan
(
qs.plan_handle
,qs.statement_start_offset
,qs.statement_end_offset
) qp
WHERE
qs.query_hash = d.query_hash AND ISNULL(qt.text,'') <> ''
) sql_plan
ORDER BY
[Avg IO] DESC
OPTION (RECOMPILE, MAXDOP 1);
