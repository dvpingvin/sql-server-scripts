/****************************************************************************/
/*         SQL Server Advanced Troubleshooting and Performance Tuning       */
/*         O'Reilly, 2022. ISBN-13: 978-1098101923 ISBN-10: 1098101928      */
/*                                                                          */
/*                  Written by Dmitri V. Korotkevitch                       */
/*                      https://aboutsqlserver.com                          */
/*                        dk@aboutsqlserver.com                             */
/****************************************************************************/
/* Подсказка для старых версий SQL Server                                   */
/* В столбце wait_resource первая число перед ":" это database_id.          */
/* Значение 2 соответствует базе tempdb.                                    */
/****************************************************************************/

-- SQL Server 2005-2017
SELECT
wt.session_id
,wt.wait_type
,er.wait_resource
,er.wait_time
FROM
sys.dm_os_waiting_tasks wt WITH (NOLOCK)
JOIN sys.dm_exec_requests er WITH (NOLOCK) ON
wt.session_id = er.session_id
WHERE
wt.wait_type LIKE 'PAGELATCH%'
OPTION (MAXDOP 1, RECOMPILE);
-- SQL Server 2019 и более поздние версии
SELECT
wt.session_id
,wt.wait_type
,er.wait_resource
,er.wait_time
,pi.database_id
,pi.file_id
,pi.page_id
,pi.object_id
,OBJECT_NAME(pi.object_id,pi.database_id) as [object]
,pi.index_id
,pi.page_type_desc
FROM
sys.dm_os_waiting_tasks wt WITH (NOLOCK)
JOIN sys.dm_exec_requests er WITH (NOLOCK) ON
wt.session_id = er.session_id
CROSS APPLY
sys.fn_PageResCracker(er.page_resource) pc
CROSS APPLY
sys.dm_db_page_info(pc.db_id,pc.file_id
,pc.page_id,'DETAILED') pi
WHERE
wt.wait_type LIKE 'PAGELATCH%'
OPTION (MAXDOP 1, RECOMPILE);
