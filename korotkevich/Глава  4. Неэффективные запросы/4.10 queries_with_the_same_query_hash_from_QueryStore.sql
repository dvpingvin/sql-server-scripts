/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Показывает все запросы с одинаковым query_hash                           */
/* (по умолчанию отображается один случайно выбранный запрос)               */
/* Дата и время в хранилище запросов представлена типом datetimeoffset      */
/* Хранилище запросов появилось в SQL Server 2016                           */
/****************************************************************************/

;WITH Queries(query_hash, [Query Count], [Exec Count], qtid)
AS
(
SELECT TOP 100
q.query_hash
,COUNT(DISTINCT q.query_id)
,SUM(rs.count_executions)
,MIN(q.query_text_id)
FROM
sys.query_store_query q WITH (NOLOCK)
JOIN sys.query_store_plan qp WITH (NOLOCK) ON
q.query_id = qp.query_id
JOIN sys.query_store_runtime_stats rs WITH (NOLOCK) ON
qp.plan_id = rs.plan_id
GROUP BY
q.query_hash
HAVING
COUNT(DISTINCT q.query_id) > 1
)
SELECT
q.query_hash
,qt.query_sql_text AS [Sample SQL]
,q.[Query Count]
,q.[Exec Count]
FROM
Queries q CROSS APPLY
(
SELECT TOP 1 qt.query_sql_text
FROM sys.query_store_query_text qt WITH (NOLOCK)
WHERE qt.query_text_id = q.qtid
) qt
ORDER BY
[Query Count] DESC, [Exec Count] DESC
OPTION(MAXDOP 1, RECOMPILE);
