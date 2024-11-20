/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/

SELECT *
FROM sys.dm_db_log_info(DB_ID());
SELECT
COUNT(*) as [VLF Count]
,MIN(vlf_size_mb) as [Min VLF Size (MB)]
,MAX(vlf_size_mb) as [Max VLF Size (MB)]
,AVG(vlf_size_mb) as [Avg VLF Size (MB)]
FROM sys.dm_db_log_info(DB_ID());
