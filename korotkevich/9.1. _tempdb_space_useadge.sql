/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

SELECT
CONVERT(DECIMAL(12,3),
SUM(user_object_reserved_page_count) / 128.
) AS [User Objects (MB)]
,CONVERT(DECIMAL(12,3),
SUM(internal_object_reserved_page_count) / 128.
) AS [Internal Objects (MB)]
,CONVERT(DECIMAL(12,3),
SUM(version_store_reserved_page_count) / 128.
) AS [Version Store (MB)]
,CONVERT(DECIMAL(12,3),
SUM(unallocated_extent_page_count) / 128.
) AS [Free Space (MB)]
FROM
tempdb.sys.dm_db_file_space_usage WITH (NOLOCK);
