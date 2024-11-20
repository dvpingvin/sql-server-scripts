/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

-- SQL Server 2016 SP2 и более поздние версии
SELECT
DB_NAME(database_id) AS [DB]
,database_id
,reserved_page_count
,CONVERT(DECIMAL(12,3),reserved_space_kb / 1024.)
AS [Reserved Space (MB)]
FROM
sys.dm_tran_version_store_space_usage WITH (NOLOCK)
OPTION (RECOMPILE);

-- SQL Server 2014 и более ранние версии. Менее точные результаты
SELECT
DB_NAME(database_id) AS [DB]
,database_id
,CONVERT(DECIMAL(12,3),
SUM(record_length_first_part_in_bytes +
record_length_second_part_in_bytes) / 1024. / 1024.
) AS [Version Store (MB)]
FROM
sys.dm_tran_version_store WITH (NOLOCK)
GROUP BY
database_id
OPTION (RECOMPILE, MAXDOP 1);
