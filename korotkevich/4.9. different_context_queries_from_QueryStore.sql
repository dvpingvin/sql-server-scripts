/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Показывает запросы, которые раздувают кэш планов,                        */
/* т.е. создают несколько планов выполнения из-за разных настроек контекста */
/* Обычно это происходит в двух случаях:                                    */
/* - в сеансах используются разные парамтеры SET                            */
/* - запросы ссылаются на объекты без имен схем                             */
/* Дата и время в хранилище запросов представлена типом datetimeoffset      */
/* Хранилище запросов появилось в SQL Server 2016                           */
/****************************************************************************/

SELECT
q.query_id, qt.query_sql_text
,COUNT(DISTINCT q.context_settings_id) AS [Context Setting Cnt]
,COUNT(DISTINCT qp.plan_id) AS [Plan Count]
FROM
sys.query_store_query q WITH (NOLOCK)
JOIN sys.query_store_query_text qt WITH (NOLOCK) ON
q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan qp WITH (NOLOCK) ON
q.query_id = qp.query_id
GROUP BY
q.query_id, qt.query_sql_text
HAVING
COUNT(DISTINCT q.context_settings_id) > 1
ORDER BY
COUNT(DISTINCT q.context_settings_id)
OPTION (MAXDOP 1, RECOMPILE);
